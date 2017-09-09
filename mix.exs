defmodule TDS.Ecto.Mixfile do
  use Mix.Project

  @version "2.0.0-alpha.2"

  def project do
    [
      app: :tds_ecto,
      version: @version,
      elixir: "~> 1.0",
      deps: deps(),
      description: description(),
      package: package()
   ]
  end

  # Configuration for the OTP application
  #
  # Type `mix help compile.app` for more information
  def application do
    [applications: [:tds, :ecto]]
  end

  defp deps() do
    [
      {:ecto, "~> 2.1"},
      #{:tds, path: "../tds"},
      {:tds, github: "livehelpnow/tds", branch: "master"},
      {:poison, ">= 0.0.0", only: :test}
    ]
  end

  defp description() do
    """
    MSSQL / TDS Adapter v#{@version} for Ecto.
    """
  end

  defp package do
    [maintainers: ["Justin Schneck"],
     licenses: ["Apache 2.0"],
     links: %{"Github" => "https://github.com/livehelpnow/tds_ecto"}]
  end
end
