defmodule Xerion.MixProject do
  use Mix.Project

  def project do
    [
      app: :xerion,
      version: "0.1.0",
      elixir: "~> 1.18",
      start_permanent: Mix.env() == :prod,
      deps: deps()
    ]
  end

  def application do
    [
      extra_applications: [:logger],
      mod: {Xerion.Application, []}
    ]
  end

  defp deps do
    [
      {:plug, "~> 1.15"},
      {:plug_cowboy, "~> 2.6"},
      {:jason, "~> 1.4"},
      {:httpoison, "~> 2.2"},
      {:eqrcode, "~> 0.2.0"},
      {:dotenv, "~> 3.0"}
    ]
  end
end
