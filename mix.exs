defmodule TDS.Ecto.Mixfile do
  use Mix.Project

  def project do
    [
      app: :tds_ecto,
      version: "0.2.0-dev",
      elixir: "~> 1.0",
      deps: deps(Mix.env),
      description: description,
      package: package
   ]
  end

  # Configuration for the OTP application
  #
  # Type `mix help compile.app` for more information
  def application do
    [applications: [:tds, :ecto]]
  end

  defp deps(:prod) do
    [
      {:ecto, "~> 0.9"},
      {:tds, "~> 0.2"}
    ]
  end
 
  defp deps(_) do
    [
      {:ecto, github: "elixir-lang/ecto"},
      {:tds, github: "livehelpnow/tds"}
    ]
  end

  defp description do
    "TDS Adapter for Ecto."
  end

  defp package do
    [contributors: ["Justin Schneck"],
     licenses: ["Apache 2.0"],
     links: %{"Github" => "https://github.com/livehelpnow/tds_ecto"}]
  end
end
