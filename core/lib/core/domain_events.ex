defmodule Core.DomainEvents do
  @moduledoc """
  Domain events system for the DXP.

  This module publishes events for all Ash actions to Phoenix PubSub topics.
  Events can be consumed by AshOban workers for indexing, derivatives, cache invalidation, and webhooks.
  """

  @doc """
  Publish a domain event for a resource action.
  """
  def publish(resource, action, record, actor, changeset \\ nil) do
    event = %{
      topic: topic(resource),
      resource: resource,
      action: action,
      record: record,
      actor_id: actor_id(actor),
      changeset: changeset,
      timestamp: DateTime.utc_now()
    }

    # Broadcast the event - ignore any errors from PubSub
    _ = Phoenix.PubSub.broadcast(Core.PubSub, topic(resource), {resource, event})

    # Return ok event for consistency
    {:ok, event}
  end

  @doc """
  Subscribe to domain events for a specific resource.
  """
  def subscribe(resource) do
    Phoenix.PubSub.subscribe(Core.PubSub, topic(resource))
  end

  @doc """
  Subscribe to all domain events.
  """
  def subscribe_all() do
    Phoenix.PubSub.subscribe(Core.PubSub, "domain_events:*")
  end

  @doc """
  Unsubscribe from domain events for a specific resource.
  """
  def unsubscribe(resource) do
    Phoenix.PubSub.unsubscribe(Core.PubSub, topic(resource))
  end

  @doc """
  Get the topic for a resource.
  """
  def topic(resource) when is_atom(resource) do
    "domain_events:#{resource}"
  end

  def topic(resource) when is_binary(resource) do
    "domain_events:#{resource}"
  end

  defp actor_id(nil), do: nil
  defp actor_id(%{id: id}), do: id
  defp actor_id(actor) when is_map(actor), do: Map.get(actor, :id, Map.get(actor, "id"))
end
