defmodule Core.DataCase do
  @moduledoc """
  This module defines the setup for tests requiring database access.
  """

  use ExUnit.CaseTemplate

  using do
    quote do
      import Core.DataCase
    end
  end

  setup _tags do
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

