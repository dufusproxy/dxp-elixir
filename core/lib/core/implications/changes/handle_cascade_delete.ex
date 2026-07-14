defmodule Core.Implications.Changes.HandleCascadeDelete do
  @moduledoc """
  Ash change that handles cascade deletion of implied assets.

  This change runs in a `before_action` hook on destroy actions to handle
  the `on_delete` behavior for each implication:
  * `:cascade` - Delete the implied asset
  * `:convert_to_redirect` - Convert to redirect (for URL assets)
  * `:orphan` - Leave as-is (becomes independent)
  * `:block` - Prevent deletion if implied asset exists

  ## Options

  * `:implications` - List of implication configurations from the DSL
  * `:resource` - The source resource module

  ## Implementation Notes

  For each implication:
  1. Find all implied assets of that type linked to the source
  2. Apply the `on_delete` behavior
  3. Handle errors appropriately based on behavior type
  """
  use Ash.Resource.Change

  @impl true
  def init(opts) do
    with true <- Keyword.keyword?(opts),
         {:ok, implications} when is_list(implications) <- Keyword.fetch(opts, :implications),
         {:ok, resource} when is_atom(resource) <- Keyword.fetch(opts, :resource) do
      {:ok, opts}
    else
      _ -> {:error, "expected :implications and :resource options"}
    end
  end

  @impl true
  def change(changeset, opts, _context) do
    # Only run on destroy actions
    if changeset.action_type == :destroy do
      Ash.Changeset.before_action(changeset, fn changeset ->
        handle_implied_assets_deletion(changeset, opts[:implications])
      end)
    else
      changeset
    end
  end

  defp handle_implied_assets_deletion(changeset, implications) do
    source_asset = changeset.data
    tenant = Ash.Changeset.get_attribute(changeset, :tenant_id)

    # For each implication, handle the on_delete behavior
    Enum.reduce(implications, changeset, fn implication, acc ->
      case handle_implication_deletion(source_asset, implication, tenant) do
        :ok ->
          acc

        {:error, error} ->
          Ash.Changeset.add_error(acc, error)
      end
    end)
  end

  defp handle_implication_deletion(source_asset, implication, tenant) do
    case find_implied_assets(source_asset, implication.asset_type, tenant) do
      {:ok, []} ->
        # No implied assets found, nothing to do
        :ok

      {:ok, implied_assets} ->
        # Apply on_delete behavior to each implied asset
        handle_assets_behavior(implied_assets, source_asset, implication.on_delete, tenant)

      {:error, error} ->
        {:error, error}
    end
  end

  defp find_implied_assets(source_asset, asset_type, tenant) do
    # Query to find assets of this type that have this source as a parent
    # We query AssetLink directly to find child assets
    case Ash.read(
           Core.Assets.AssetLink
           |> Ash.Query.filter(parent_id == ^source_asset.id),
           tenant: tenant
         ) do
      {:ok, links} ->
        # Get the child asset IDs
        child_ids = Enum.map(links, & &1.child_id)

        # Now query for assets of the specified type
        case Ash.read(
               Core.Assets.Asset
               |> Ash.Query.filter(type == ^asset_type and id in ^child_ids),
               tenant: tenant
             ) do
          {:ok, assets} -> {:ok, assets}
          {:error, error} -> {:error, error}
        end

      {:error, error} ->
        {:error, error}
    end
  rescue
    error ->
      {:error, error}
  end

  defp handle_assets_behavior(implied_assets, _source, :cascade, tenant) do
    # Delete all implied assets
    results =
      Enum.map(implied_assets, fn asset ->
        Ash.destroy(asset, action: :destroy, tenant: tenant)
      end)

    case Enum.find(results, fn result -> result != :ok end) do
      nil -> :ok
      error -> error
    end
  end

  defp handle_assets_behavior(_implied_assets, _source, :orphan, _tenant) do
    # Do nothing - assets become independent
    # In the future, we might want to delete the AssetLink but keep the asset
    :ok
  end

  defp handle_assets_behavior(implied_assets, _source, :convert_to_redirect, tenant) do
    # Convert URL assets to redirects
    results =
      Enum.map(implied_assets, fn asset ->
        if asset.type == :url do
          # Convert URL to redirect
          # For now, we'll just delete the URL since we don't have a redirect asset type yet
          Ash.destroy(asset, action: :destroy, tenant: tenant)
        else
          # Fallback to cascade for non-URL assets
          Ash.destroy(asset, action: :destroy, tenant: tenant)
        end
      end)

    case Enum.find(results, fn result -> result != :ok end) do
      nil -> :ok
      error -> error
    end
  end

  defp handle_assets_behavior(implied_assets, _source, :block, _tenant) do
    # Block deletion if implied assets exist
    if Enum.empty?(implied_assets) do
      :ok
    else
      {:error,
       "Cannot delete asset with implied assets that have :block on_delete behavior. Found #{length(implied_assets)} implied asset(s)."}
    end
  end
end
