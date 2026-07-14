defmodule CoreWeb do
  @moduledoc """
  The entrypoint for the Core Web functionality.

  This module provides common functionality for web-related modules.
  """

  @doc """
  The static paths for the application.
  """
  def static_paths, do: ~w(assets fonts images favicon.ico robots.txt)

  def controller do
    quote do
      use Phoenix.Controller,
        namespace: CoreWeb,
        formats: [:json]

      import Plug.Conn
    end
  end

  def router do
    quote do
      use Phoenix.Router,
        helpers: false

      import Plug.Conn
    end
  end

  @doc """
  When used, dispatch to the appropriate controller/view/etc.
  """
  defmacro __using__(which) when is_atom(which) do
    apply(__MODULE__, which, [])
  end
end
