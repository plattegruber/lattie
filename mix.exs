defmodule Lattice.MixProject do
  use Mix.Project

  def project do
    [
      app: :lattice,
      version: "0.1.0",
      elixir: "~> 1.14",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      releases: releases()
    ]
  end

  def application do
    [
      extra_applications: [:logger],
      mod: {Lattice.Application, []}
    ]
  end

  defp deps do
    []
  end

  defp releases do
    [
      lattice: [
        applications: [runtime_tools: :permanent]
      ]
    ]
  end
end
