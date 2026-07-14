defmodule Core.DataCase do
  @moduledoc """
  This module defines the setup for tests requiring database access.
  """

  use ExUnit.CaseTemplate

  using do
    quote do
      import Core.DataCase

      # The default Ecto repo
      alias Core.Repo

      # Import Ash test helpers
      import Ash.Test

      # Each test runs in its own transaction
      setup tags do
        :ok = Ecto.Adapters.SQL.Sandbox.checkout(Core.Repo)
      end
    end
  end

  setup _tags do
    # Ensure sandbox mode is set to shared for this process
    Ecto.Adapters.SQL.Sandbox.mode(Core.Repo, :manual)

    Core.DataCase.setup_ash()

    :ok
  end

  @doc """
  Sets up Ash for testing.
  """
  def setup_ash do
    # Start the repo
    Core.Repo.start_link()

    # Start pubsub and cache - use start_supervised! with proper restart strategy
    # to avoid issues with multiple test cases
    case Process.whereis(Core.PubSub) do
      nil ->
        start_supervised!({Phoenix.PubSub, [name: Core.PubSub]})
      _pid ->
        :ok
    end

    case Process.whereis(Core.Policies.PermissionCache) do
      nil ->
        start_supervised!(Core.Policies.PermissionCache)
      _pid ->
        :ok
    end

    :ok
  end

  @doc """
  Creates a test actor with admin permissions.
  """
  def test_admin(actor_id \\ nil) do
    actor_id = actor_id || Ecto.UUID.generate()

    %{
      id: actor_id,
      role: :admin
    }
  end

  @doc """
  Creates a test actor and grants admin permission on an asset.
  """
  def grant_admin_permission(asset_id, actor_id \\ nil) do
    actor = test_admin(actor_id)

    Ash.create!(
      Ash.Changeset.for_create(
        Core.Assets.Permission,
        :create,
        %{
          asset_id: asset_id,
          principal_id: actor.id,
          principal_type: :user,
          level: :admin
        },
        authorize?: false
      )
    )

    actor
  end
end

