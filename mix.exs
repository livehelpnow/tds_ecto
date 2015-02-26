defmodule TDS.Ecto.Mixfile do
  use Mix.Project

  def project do
    [app: :tds_ecto,
     version: "0.1.5",
     elixir: "~> 1.0",
     deps: deps(Mix.env)]
  end

  # Configuration for the OTP application
  #
  # Type `mix help compile.app` for more information
  def application do
    [applications: [:tds]]
  end

  defp deps(:prod) do
    [
      {:ecto, github: "elixir-lang/ecto"},
      {:tds, "~> 0.1"}
    ]
  end
 
  defp deps(_) do
    [
      {:ecto, github: "elixir-lang/ecto"},
      {:tds, github: "livehelpnow/tds"}
    ]
  end
end
