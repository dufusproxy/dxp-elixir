defmodule CoreWeb.Router do
  @moduledoc """
  The main Phoenix router for the DXP.

  This router forwards API requests to the AshJsonApi router.
  """
  use CoreWeb, :router

  # API pipeline
  pipeline :api do
    plug(:accepts, ["json"])
  end

  # Forward all API requests to the AshJsonApi router
  forward("/api", CoreWeb.JsonApiRouter)
end
