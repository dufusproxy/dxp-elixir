defmodule Core.DomainEvents.PublishDomainEvent do
  @moduledoc """
  An Ash change that publishes domain events for all resource actions.

  This change publishes events to Phoenix PubSub after actions are completed.
  Events can be consumed by AshOban workers for indexing, derivatives, cache invalidation, and webhooks.
  """

  use Ash.Resource.Change

  @doc """
  Publish domain events for the current action.
  """
  def publish_domain_event(opts \\ []) do
    {__MODULE__, opts}
  end

  @impl true
  def init(opts), do: {:ok, opts}

  @impl true
  def change(changeset, _opts, context) do
    Ash.Changeset.after_action(changeset, fn changeset, result ->
      publish_event(changeset, result, context)
    end)
  end

  @impl true
  def atomic(_changeset, _opts, _context) do
    # This change cannot be atomic because we need the actual record to publish events
    {:not_atomic, "Domain event publishing requires the final record with IDs"}
  end

  defp publish_event(changeset, record, context) when is_struct(record) do
    resource = changeset.resource
    action_name = changeset.action.name
    actor = Map.get(context, :actor)

    # Determine action type from action name
    action_type = cond do
      action_name in [:create, :bulk_create] -> :create
      action_name in [:update, :bulk_update] -> :update
      action_name in [:destroy, :bulk_destroy] -> :destroy
      true -> :unknown
    end

    # Publish domain event - wrap in try/rescue to ensure it doesn't break the transaction
    try do
      _ = Core.DomainEvents.publish(resource, action_type, record, actor, changeset)
    rescue
      e ->
        # Log the error but don't fail the transaction
        require Logger
        Logger.warning("Failed to publish domain event: #{inspect(e)}")
    end

    {:ok, record}
  end

  defp publish_event(_changeset, result, _context), do: result
end
