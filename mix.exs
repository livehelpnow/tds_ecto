defmodule TDS.Ecto.Mixfile do
  use Mix.Project

  def project do
    [
      app: :tds_ecto,
      version: "1.0.2",
      elixir: "~> 1.0",
      deps: deps,
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
      {:ecto, "~> 2.0.0-rc"},
      {:tds, git: "https://0o0@bitbucket.org/livehelpnow/tds.git", branch: "ecto2"},
      {:poison, only: :test}
    ]
  end

  defp description do
    """
    MSSQL / TDS Adapter for Ecto.
    """
  end

  defp package do
    [maintainers: ["Justin Schneck"],
     licenses: ["Apache 2.0"],
     links: %{"Github" => "https://github.com/livehelpnow/tds_ecto"}]
  end
end
