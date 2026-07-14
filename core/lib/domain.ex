defmodule Core.Domain do
  @moduledoc """
  The main Ash domain for the Core application.
  This domain aggregates all resources for the DXP platform.
  """
  use Ash.Domain

  resources do
    resource(Core.Resources.Tenant)
  end
end
