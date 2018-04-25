use Mix.Config

config :logger, level: :info

config :ecto, lock_for_update: true

config :tds_ecto,
  opts: [
    hostname: "localhost",
    username: "sa",
    password: System.get_env("SQL_PASSWORD") || "some!Password",
    database: "test"
  ]

