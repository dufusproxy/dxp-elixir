defmodule CoreWeb.Router do
  @moduledoc """
  The main Phoenix router for the DXP.

  This router forwards API requests to the AshJsonApi router.
  """
  use CoreWeb, :router

  # API pipeline (no authentication required)
  pipeline :api do
    plug(:accepts, ["json"])
  end

  # Authenticated API pipeline (requires valid token)
  pipeline :api_authenticated do
    plug(:accepts, ["json"])
    plug(CoreWeb.Plugs.LoadActorFromToken)
  end

  # Forward all API requests to the AshJsonApi router
  forward("/api", CoreWeb.JsonApiRouter)

  # Authentication endpoints
  # POST /auth/login - login with email/password
  post "/auth/login", CoreWeb.AuthController, :login

  # POST /auth/register - create new user account
  post "/auth/register", CoreWeb.AuthController, :create
end
