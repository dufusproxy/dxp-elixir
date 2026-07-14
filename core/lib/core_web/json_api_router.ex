defmodule CoreWeb.JsonApiRouter do
  @moduledoc """
  The AshJsonApi router for the DXP API.

  This router serves the JSON:API endpoints for all Ash resources.
  """
  use AshJsonApi.Router,
    domains: [Core.Domain],
    open_api: "/openapi",
    json_schema: "/json_schema",
    prefix: "/api/v1"
end
