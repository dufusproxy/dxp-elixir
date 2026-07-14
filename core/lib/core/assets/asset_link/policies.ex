defmodule Core.Assets.AssetLink.Policies do
  @moduledoc """
  Validation policies for AssetLink to maintain DAG integrity.
  """
  @max_depth 100

  @doc """
  Prevents cycles in the asset DAG by checking if the proposed link would create a cycle.

  For a proposed link (parent_id, child_id):
  - A cycle would exist if parent_id can already reach child_id through existing parent_links
  - This is because parent_id -> child_id would complete the cycle: child_id -> ... -> parent_id -> child_id

  Returns a changeset (either with errors added or the original).
  """
  def prevent_cycles(changeset) do
    parent_id = Ash.Changeset.get_attribute(changeset, :parent_id)
    child_id = Ash.Changeset.get_attribute(changeset, :child_id)

    cond do
      parent_id == child_id ->
        Ash.Changeset.add_error(
          changeset,
          field: :parent_id,
          message: "cannot link an asset to itself"
        )

      reachable?(parent_id, child_id) ->
        Ash.Changeset.add_error(
          changeset,
          field: :parent_id,
          message: "creating this link would create a cycle in the asset graph"
        )

      true ->
        changeset
    end
  end

  @doc """
  Checks if `start_id` can reach `target_id` through parent_links (following parent relationships).
  Uses depth-limited traversal to prevent infinite loops.
  """
  def reachable?(start_id, target_id, visited \\ MapSet.new(), depth \\ 0)

  def reachable?(_start_id, _target_id, _visited, depth) when depth > @max_depth do
    # Depth limit exceeded - assume no cycle to prevent infinite loops
    false
  end

  def reachable?(start_id, target_id, visited, depth) do
    # If we've reached the target, it's reachable
    if start_id == target_id do
      true
    else
      # Prevent revisiting nodes in the current path
      if MapSet.member?(visited, start_id) do
        false
      else
        visited = MapSet.put(visited, start_id)

        # Get all parent links for the current asset
        # These represent edges: current_id <- parent_id
        parent_links = get_parent_links(start_id)

        # Check if any parent can reach the target
        Enum.any?(parent_links, fn link ->
          reachable?(link.parent_id, target_id, visited, depth + 1)
        end)
      end
    end
  end

  # Get parent links for an asset, excluding archived records
  # Returns a list of parent links (empty list if none found or on error)
  defp get_parent_links(asset_id) do
    # Use Ash.read! which respects the sandbox transaction
    # Filter for links where this asset is the child and not archived
    all_links = Ash.read!(Core.Assets.AssetLink, domain: Core.Domain)

    Enum.filter(all_links, fn link ->
      link.child_id == asset_id and link.archived_at == nil
    end)
  rescue
    _ ->
      # On error, return empty list (fail-open for data consistency)
      []
  end
end
