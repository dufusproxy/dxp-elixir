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

    :ok
  end
end

