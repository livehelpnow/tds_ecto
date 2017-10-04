use Mix.Config

config :logger, level: :info

config :tds_ecto,
  opts: [
    hostname: "localhost",
    username: "sa",
    password: System.get_env("SQL_PASSWORD") || "some!Password",
    database: "test"
  ]

