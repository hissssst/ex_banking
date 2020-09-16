defmodule ExBanking.MixProject do
  use Mix.Project

  def project do
    [
      app:               :ex_banking,
      version:           "0.1.0",
      elixir:            "~> 1.10",
      start_permanent:   Mix.env() == :prod,

      dialyzer:          dialyzer(),
      deps:              deps(),
      preferred_cli_env: preferred_cli_env(),
      test_coverage:     test_coverage()
    ]
  end

  def application do
    [
      extra_applications: [:logger],
      mod: {ExBanking.Application, []}
    ]
  end

  defp dialyzer do
    [
      plt_add_deps: :apps_direct,
      plt_core_path: "priv/plts",
      plt_file: {:no_warn, "priv/plts/dialyzer.plt"}
    ]
  end

  defp test_coverage do
    [
      tool: ExCoveralls
    ]
  end

  defp preferred_cli_env do
    [
      credo:              :test,
      dialyzer:           :test,
      coveralls:          :test
    ]
  end

  defp deps do
    [
      # CI deps
      {:dialyxir,    "~> 1.0",  only: [:dev, :test], runtime: false},
      {:credo,       "~> 1.4",  only: [:dev, :test], runtime: false},
      {:excoveralls, "~> 0.13", only: :test},

      # Actual deps
      {:pathex, "~> 0.3"},
      {:core,   "~> 0.14.1"}
    ]
  end
end
