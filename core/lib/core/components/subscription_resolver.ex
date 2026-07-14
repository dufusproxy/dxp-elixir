defmodule Core.Components.ComponentSubscription.Resolver do
  @moduledoc """
  Subscription resolution callbacks for ComponentSubscription.

  This module contains after_action hooks for resolving subscription versions
  when subscriptions are created, pinned, or updated.
  """

  alias Core.Components.ComponentResolver

  @doc """
  Resolve subscription after pinning a version.

  Updates the resolved_version_id to point to the pinned version.
  """
  def resolve_pin(_changeset, subscription) do
    case ComponentResolver.update_resolved_version(subscription) do
      {:ok, updated} -> {:ok, updated}
      {:error, reason} -> {:error, reason}
    end
  end

  @doc """
  Resolve subscription after unpinning a version.

  Updates the resolved_version_id based on the version range.
  """
  def resolve_unpin(_changeset, subscription) do
    case ComponentResolver.update_resolved_version(subscription) do
      {:ok, updated} -> {:ok, updated}
      {:error, reason} -> {:error, reason}
    end
  end

  @doc """
  Resolve subscription after changing the version range.

  Updates the resolved_version_id based on the new version range.
  """
  def resolve_range(_changeset, subscription) do
    case ComponentResolver.update_resolved_version(subscription) do
      {:ok, updated} -> {:ok, updated}
      {:error, reason} -> {:error, reason}
    end
  end
end
