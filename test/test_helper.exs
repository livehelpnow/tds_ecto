Logger.configure(level: :info)

ExUnit.start exclude: [:assigns_id_type, :array_type, :case_sensitive]

Application.put_env(:ecto, :lock_for_update, "FOR UPDATE")
Application.put_env(:ecto, :primary_key_type, :id)
Application.put_env(:ecto, :async_integration_tests, false)

# Basic test repo
Code.require_file "../deps/ecto/integration_test/support/repo.exs", __DIR__
Code.require_file "../deps/ecto/integration_test/support/types.exs", __DIR__
Code.require_file "../deps/ecto/integration_test/support/schemas.exs", __DIR__
Code.require_file "../deps/ecto/integration_test/support/migration.exs", __DIR__

pool =
  case System.get_env("ECTO_POOL") || "poolboy" do
    "poolboy" -> DBConnection.Poolboy
    "sbroker" -> DBConnection.Sojourn
  end

alias Ecto.Integration.TestRepo

Application.put_env(:ecto, TestRepo,
  filter_null_on_unique_indexes: true,
  adapter: Tds.Ecto,
  hostname: System.get_env("SQL_HOSTNAME") || "localhost",
  username: System.get_env("SQL_USERNAME") || "sa",
  password: System.get_env("SQL_PASSWORD") || "some!Password",
  database: "ecto_test",
  pool: Ecto.Adapters.SQL.Sandbox,
  pool_size: 10,
  ownership_pool: pool)

defmodule Ecto.Integration.TestRepo do
  use Ecto.Integration.Repo,
    otp_app: :ecto
end

alias Ecto.Integration.PoolRepo


Application.put_env(:ecto, PoolRepo,
  adapter: Tds.Ecto,
  pool: pool,
  hostname: System.get_env("SQL_HOSTNAME") || "localhost",
  username: System.get_env("SQL_USERNAME") || "sa",
  password: System.get_env("SQL_PASSWORD") || "some!Password",
  database: "ecto_test",
  pool_size: 10)

defmodule Ecto.Integration.PoolRepo do
  use Ecto.Integration.Repo, otp_app: :ecto

  def create_prefix(prefix) do
    "create database #{prefix}"
  end

  def drop_prefix(prefix) do
    "drop database #{prefix}"
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

# :dbg.tracer()
# :dbg.p(:all,:c)
# :dbg.tpl(Tds.Protocol, :_, :x)

:erlang.system_flag :backtrace_depth, 50

{:ok, _} = Tds.Ecto.ensure_all_started(TestRepo, :temporary)

_   = Tds.Ecto.storage_down(TestRepo.config)
:ok = Tds.Ecto.storage_up(TestRepo.config)

{:ok, _pid} = TestRepo.start_link
{:ok, _pid} = PoolRepo.start_link
:ok = Ecto.Migrator.up(TestRepo, 0, Ecto.Integration.Migration, log: false)
Ecto.Adapters.SQL.Sandbox.mode(TestRepo, :manual)

# :dbg.stop_clear()

Process.flag(:trap_exit, true)
