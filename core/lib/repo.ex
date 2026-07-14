defmodule Core.Repo do
  @moduledoc """
  AshPostgres repo for the Core application.
  """
  use AshPostgres.Repo,
    otp_app: :core

  def min_pg_version do
    %Version{major: 16, minor: 0, patch: 0}
  end

  def installed_extensions do
    ["ash-functions", "uuid-ossp"]
  end
end
