defmodule CoreWeb.Endpoint do
  @moduledoc """
  The Phoenix Endpoint for the DXP API.

  This serves JSON:API endpoints for content management.
  """
  use Phoenix.Endpoint, otp_app: :core

  # The session will be stored in the cookie and signed,
  # this means its contents can be read but not tampered with.
  # Set :encryption_salt if you would also like the value to be encrypted.
  @session_options [
    store: :cookie,
    key: "_core_key",
    signing_salt: "core",
    same_site: "Lax"
  ]

  # Serve at "/" the static assets from "priv/static" directory.
  plug Plug.Static,
    at: "/",
    from: :core,
    gzip: false,
    only: CoreWeb.static_paths()

  # Code reloading can be explicitly enabled under the :code_reloader configuration of your
  # endpoint.
  if code_reloading? do
    socket "/phoenix/live_reload/socket", Phoenix.LiveReloader.Socket
    plug Phoenix.LiveReloader
    plug Phoenix.CodeReloader
  end

  plug Plug.RequestId
  plug Plug.Telemetry, event_prefix: [:phoenix, :endpoint]

  # Ensure proper parsing of JSON bodies
  plug Plug.Parsers,
    parsers: [:urlencoded, :multipart, :json],
    pass: ["*/*"],
    json_decoder: Phoenix.json_library()

  plug Plug.MethodOverride
  plug Plug.Head
  plug Plug.Session, @session_options
  plug CoreWeb.Router
end
