defmodule Core.Policies.HasAssetPermission do
  @moduledoc """
  Policy check module for resolving effective permission levels via DAG inheritance.

  This module implements matrix-style Read/Write/Admin permission model where:
  - Permissions are granted per asset to principals (users/groups)
  - Permissions are inherited down the asset DAG
  - Nearest explicit grant on the primary-parent chain wins

  ## Algorithm

  1. Check if there's a direct permission grant for the actor on the asset
  2. If not, walk up the primary-parent chain (following :primary link_type)
  3. Return the first explicit grant found, or nil if none exists

  ## Cache

  Resolved permissions are cached in Core.Policies.PermissionCache to keep
  authorization off the render hot path.

  ## Usage

      # In Ash policies
      policies do
        policy action_type(:read) do
          authorize_if {Core.Policies.HasAssetPermission, level: :read}
        end

        policy action_type(:create) do
          authorize_if {Core.Policies.HasAssetPermission, level: :write}
        end
      end
  """

  use Ash.Policy.Check

  @impl true
  def describe(opts) do
    case Keyword.get(opts, :level) do
      nil -> "has_asset_permission"
      level -> "has_asset_permission:#{level}"
    end
  end

  @impl true
  def strict_check(actor, data, opts) do
    level = Keyword.fetch!(opts, :level)

    case get_actor_id(actor) do
      nil ->
        # No actor, no permission
        {:error, :no_actor_given}

      actor_id ->
        # Get asset ID from data
        asset_id = get_asset_id(data)

        if is_nil(asset_id) do
          # Can't determine asset ID
          {:error, :no_asset_id}
        else
          # Check permission via cache
          case Core.Policies.PermissionCache.get(actor_id, asset_id) do
            {:ok, nil} ->
              # No permission found
              false

            {:ok, effective_level} ->
              # Check if effective level meets required level
              level_meets?(effective_level, level)

            :error ->
              # Cache miss or error, fall back to direct check
              check_permission_direct(actor_id, asset_id, level)
          end
        end
    end
  end

  @impl true
  def auto_filter(_actor, _data, _opts) do
    # For filtering, we need to find assets where the actor has permission
    # This is more complex and may require a different approach
    # For now, we'll return :unknown to indicate we can't filter at the data layer
    :unknown
  end

  @doc """
  Get the effective permission level for an actor on an asset.
  Returns {:ok, level} where level is :read, :write, :admin, or nil.
  """
  def effective_permission(actor_id, asset_id) do
    case Core.Policies.PermissionCache.get(actor_id, asset_id) do
      {:ok, _} = result ->
        result

      :error ->
        # Cache miss, compute and cache
        level = compute_effective_permission(actor_id, asset_id)
        Core.Policies.PermissionCache.put(actor_id, asset_id, level)
        {:ok, level}
    end
  end

  @doc """
  Check if a given level meets or exceeds a required level.
  """
  def level_meets?(effective_level, required_level) do
    effective_index = level_index(effective_level)
    required_index = level_index(required_level)

    effective_index >= required_index
  end

  # Private functions

  defp get_actor_id(%{id: actor_id}), do: actor_id
  defp get_actor_id(_), do: nil

  defp get_asset_id(%{id: asset_id}), do: asset_id
  defp get_asset_id(%resource{} = data) when is_atom(resource) do
    # For Ash records, get the id
    Map.get(data, :id)
  end
  defp get_asset_id(_), do: nil

  defp check_permission_direct(actor_id, asset_id, required_level) do
    case compute_effective_permission(actor_id, asset_id) do
      nil -> false
      effective_level -> level_meets?(effective_level, required_level)
    end
  end

  @doc """
  Compute the effective permission level by walking the primary-parent chain.
  This is the core DAG inheritance algorithm.
  """
  def compute_effective_permission(actor_id, asset_id) do
    compute_effective_permission(actor_id, asset_id, %MapSet{})
  end

  defp compute_effective_permission(actor_id, asset_id, visited) do
    # Prevent infinite loops from circular references
    if MapSet.member?(visited, asset_id) do
      nil
    else
      visited = MapSet.put(visited, asset_id)

      # First, check for a direct grant on this asset
      case direct_grant(actor_id, asset_id) do
        nil ->
          # No direct grant, walk up the primary-parent chain
          case primary_parent_id(asset_id) do
            nil ->
              # Reached the top of the chain with no grant
              nil

            parent_id ->
              # Recursively check parent
              compute_effective_permission(actor_id, parent_id, visited)
          end

        level ->
          # Found a grant, return it
          level
      end
    end
  end

  # Get the primary parent ID for an asset
  defp primary_parent_id(asset_id) do
    query =
      Core.Assets.AssetLink
      |> Ash.Query.for_read(:read)
      |> Ash.Query.filter(
        child_id == ^asset_id and link_type == :primary
      )
      |> Ash.Query.limit(1)

    case Ash.read(query, authorize?: false) do
      {:ok, [link]} when not is_nil(link) ->
        link.parent_id

      _ ->
        nil
    end
  rescue
    _ -> nil
  end

  # Get direct grant for an actor on an asset
  defp direct_grant(actor_id, asset_id) do
    query =
      Core.Assets.Permission
      |> Ash.Query.for_read(:read)
      |> Ash.Query.filter(
        asset_id == ^asset_id and principal_id == ^actor_id
      )
      |> Ash.Query.limit(1)

    case Ash.read(query, authorize?: false) do
      {:ok, [permission]} when not is_nil(permission) ->
        permission.level

      _ ->
        nil
    end
  rescue
    _ -> nil
  end

  # Get the numeric index for a permission level
  defp level_index(:read), do: 0
  defp level_index(:write), do: 1
  defp level_index(:admin), do: 2
  defp level_index(_), do: -1
end
