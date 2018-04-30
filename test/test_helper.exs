Logger.configure(level: :info)

ExUnit.start(
  exclude: [
    :assigns_id_type,
    :array_type,
    :case_sensitive,
    :modify_foreign_key_on_update,
    :modify_foreign_key_on_delete,
    :uses_usec,
    :lock_for_update,
    # NOTE: there is bug with transaction timout, it works bt error is not returned Repo transaction function
    :disconnect_on_transaction_timout,
    # TODO: floats
    :primitive_types
  ]
)

Application.put_env(:ecto, :lock_for_update, "FOR UPDATE")
Application.put_env(:ecto, :primary_key_type, :id)
Application.put_env(:ecto, :async_integration_tests, false)

# Basic test repo
Code.require_file("./integration/support/types.exs", __DIR__)
Code.require_file("./integration/support/repo.exs", __DIR__)
Code.require_file("./integration/support/schemas.exs", __DIR__)
Code.require_file("./integration/support/migration.exs", __DIR__)

pool =
  case System.get_env("ECTO_POOL") || "poolboy" do
    "poolboy" -> DBConnection.Poolboy
    "sbroker" -> DBConnection.Sojourn
  end

alias Ecto.Integration.TestRepo

Application.put_env(
  :ecto,
  TestRepo,
  filter_null_on_unique_indexes: true,
  adapter: Tds.Ecto,
  hostname: System.get_env("SQL_HOSTNAME") || "localhost",
  username: System.get_env("SQL_USERNAME") || "sa",
  password: System.get_env("SQL_PASSWORD") || "some!Password",
  database: "ecto_test",
  pool: Ecto.Adapters.SQL.Sandbox,
  ownership_pool: pool,
  set_allow_snapshot_isolation: :on
)

defmodule Ecto.Integration.TestRepo do
  use Ecto.Integration.Repo, otp_app: :ecto
end

alias Ecto.Integration.PoolRepo

Application.put_env(
  :ecto,
  PoolRepo,
  adapter: Tds.Ecto,
  pool: pool,
  hostname: System.get_env("SQL_HOSTNAME") || "localhost",
  username: System.get_env("SQL_USERNAME") || "sa",
  password: System.get_env("SQL_PASSWORD") || "some!Password",
  database: "ecto_test",
  max_restarts: 20,
  max_seconds: 10,
  pool_size: 10,
  set_allow_snapshot_isolation: :on
)

defmodule Ecto.Integration.PoolRepo do
  use Ecto.Integration.Repo, otp_app: :ecto

  def create_prefix(prefix) do
    "create schema #{prefix}"
  end

  def drop_prefix(prefix) do
    "drop schema #{prefix}"
  end
end

defmodule Ecto.Integration.Case do
  use ExUnit.CaseTemplate

  alias Ecto.Integration.TestRepo

  setup do
    :ok = Ecto.Adapters.SQL.Sandbox.checkout(TestRepo)
  end
end

# :debugger.start()
# :int.ni(Tds.Ecto)
# :int.break(Tds.Ecto, 164)

:dbg.tracer()
:dbg.p(:all, :c)
# :dbg.tpl(Tds.Types, :decode_decimal, :x)

:erlang.system_flag(:backtrace_depth, 50)

{:ok, _} = Tds.Ecto.ensure_all_started(TestRepo, :temporary)
{:ok, _} = Tds.Ecto.ensure_all_started(PoolRepo, :temporary)

_ = Tds.Ecto.storage_down(TestRepo.config())
:ok = Tds.Ecto.storage_up(TestRepo.config())

{:ok, _pid} = TestRepo.start_link()
{:ok, _pid} = PoolRepo.start_link()

:ok = Ecto.Migrator.up(TestRepo, 0, Ecto.Integration.Migration, log: false)
Ecto.Adapters.SQL.Sandbox.mode(TestRepo, :manual)

# :dbg.stop_clear()

Process.flag(:trap_exit, true)
