defmodule TDS.Ecto.Mixfile do
  use Mix.Project

  def project do
    [
      app: :tds_ecto,
      version: "0.2.4",
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

  defp deps do
    [

    ]
  end

  defp deps(:test) do
    [
      {:ecto, "~> 0.12.0-rc"},
      {:tds, github: "livehelpnow/tds"}
    ] ++ deps
  end

  defp deps(_) do
    [
      {:ecto, "~> 0.12.0-rc"},
      {:tds, "~> 0.2"}
    ] ++ deps
  end



  defp description do
    """
    MSSQL / TDS Adapter for Ecto.
    """
  end

  defp package do
    [contributors: ["Justin Schneck"],
     licenses: ["Apache 2.0"],
     links: %{"Github" => "https://github.com/livehelpnow/tds_ecto"}]
  end
end
