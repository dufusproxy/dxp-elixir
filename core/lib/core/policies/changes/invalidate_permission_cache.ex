defmodule Core.Policies.Changes.InvalidatePermissionCache do
  @moduledoc """
  Ash change to invalidate permission cache on mutations.

  This change should be added to Permission and AssetLink resources
  to ensure the cache stays consistent when permissions or inheritance chains change.
  """

  use Ash.Resource.Change

  @doc """
  Invalidate permission cache for a permission mutation.
  """
  def invalidate_permission_cache do
    {__MODULE__, []}
  end

  @impl true
  def init(opts), do: {:ok, opts}

  @impl true
  def change(changeset, _opts, _context) do
    Ash.Changeset.after_action(changeset, fn _changeset, result ->
      # Invalidate cache entries related to this change
      invalidate_cache_for_result(result)
      {:ok, result}
    end)
  end

  @impl true
  def atomic(_changeset, _opts, _context) do
    # Return :not_atomic because cache invalidation cannot be done atomically
    # We need the actual record with IDs to invalidate the cache
    {:not_atomic, "Cache invalidation requires the final record with IDs"}
  end

  # Private functions

  defp invalidate_cache_for_result(result) do
    case result do
      %{__struct__: Core.Assets.Permission} ->
        # Permission mutation - invalidate for this actor and asset
        Core.Policies.PermissionCache.invalidate_permission(
          result.principal_id,
          result.asset_id
        )

      %{__struct__: Core.Assets.AssetLink} ->
        # AssetLink mutation - invalidate for the child asset
        # because the inheritance chain may have changed
        Core.Policies.PermissionCache.invalidate_asset(result.child_id)

      _ ->
        :ok
    end
  end
end
