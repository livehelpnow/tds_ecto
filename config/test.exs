use Mix.Config

config :logger, level: :info

config :ecto, lock_for_update: true
config :ecto, async_integration_tests: false

config :tds_ecto,
  opts: [
    hostname: System.get_env("SQL_HOSTNAME") || "localhost",
    username: "sa",
    password: System.get_env("SQL_PASSWORD") || "some!Password",
    database: "test",
    set_allow_snapshot_isolation: :on
  ]

