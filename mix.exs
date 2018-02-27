defmodule TDS.Ecto.Mixfile do
  use Mix.Project

  @version "2.0.8"

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
      {:ecto, ">= 2.0.0"},
      {:tds, "~> 1.0"},
      {:ex_doc, ">= 0.0.0", only: :dev},
      {:poison, ">= 0.0.0", only: :test}
    ]
  end

  defp description() do
    """
    Ecto 2 Adapter for Microsoft SQL Server
    """
  end

  defp package do
    [ name: "tds_ecto",
      files: ["lib", "mix.exs", "README*"],
      maintainers: ["Justin Schneck", "Eric Witchin", "Milan Jaric"],
      licenses: ["Apache 2.0"],
      links: %{"Github" => "https://github.com/livehelpnow/tds_ecto"}]
  end
end
