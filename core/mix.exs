defmodule Core.MixProject do
  use Mix.Project

  def project do
    [
      app: :core,
      version: "0.1.0",
      elixir: "~> 1.18",
      start_permanent: Mix.env() == :prod,
      deps: deps()
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      extra_applications: [:logger],
      mod: {Core.Application, []}
    ]
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      {:ash, "~> 3.29"},
      {:ash_postgres, "~> 2.0"},
      {:ash_paper_trail, "~> 0.6"},
      {:ash_archival, "~> 2.0"},
      {:ash_state_machine, "~> 0.2"},
      {:ash_oban, "~> 0.8"},
      {:ash_json_api, "~> 1.0"},
      {:ash_authentication, "~> 4.0"},
      {:assent, "~> 0.2"},
      {:oban, "~> 2.19"},
      {:phoenix, "~> 1.7"},
      {:phoenix_pubsub, "~> 2.1"},
      {:phoenix_live_dashboard, "~> 0.8", only: :dev},
      {:phoenix_live_reload, "~> 1.5", only: :dev},
      {:jason, "~> 1.4"},
      {:stream_data, "~> 1.0"},
      {:picosat_elixir, "~> 0.2"},
      {:yamerl, "~> 0.10"},
      {:ex_json_schema, "~> 0.10"},
      {:igniter, "~> 0.6", only: [:dev, :test]},
      {:credo, "~> 1.7", only: [:dev, :test], runtime: false},
      {:ex_doc, "~> 0.37", only: [:dev, :test], runtime: false}
    ]
  end
end
