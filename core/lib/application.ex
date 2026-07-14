defmodule Core.Application do
  @moduledoc """
  The Core Application entry point.
  """
  use Application

  @impl Application
  def start(_type, _args) do
    children = [
      Core.Repo,
      {Phoenix.PubSub, name: Core.PubSub},
      Core.Policies.PermissionCache
    ]

    opts = [strategy: :one_for_one, name: Core.Supervisor]
    Supervisor.start_link(children, opts)
  end
end
