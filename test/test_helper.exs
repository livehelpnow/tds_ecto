Logger.configure(level: :error)
ExUnit.start exclude: [:assigns_id_type, :array_type, :case_sensitive]

Application.put_env(:ecto, :lock_for_update, "FOR UPDATE")
Application.put_env(:ecto, :primary_key_type, :id)

# Basic test repo
Code.require_file "../deps/ecto/integration_test/support/repo.exs", __DIR__
Code.require_file "../deps/ecto/integration_test/support/models.exs", __DIR__
Code.require_file "../deps/ecto/integration_test/support/migration.exs", __DIR__

alias Ecto.Integration.TestRepo

Application.put_env(:ecto, TestRepo,
  adapter: Tds.Ecto,
  filter_null_on_unique_indexes: true,
  url: "ecto://mssql:mssql@mssql.local/ecto_test",
  pool: Ecto.Adapters.SQL.Sandbox)

defmodule Ecto.Integration.TestRepo do
  use Ecto.Integration.Repo,
    otp_app: :ecto
end

# Pool repo for transaction and lock tests
alias Ecto.Integration.PoolRepo

Application.put_env(:ecto, PoolRepo,
  adapter: Tds.Ecto,
  filter_null_on_unique_indexes: true,
  url: "ecto://mssql:mssql@mssql.local/ecto_test",
  size: 10)

defmodule Ecto.Integration.PoolRepo do
  use Ecto.Integration.Repo,
    otp_app: :ecto

    def lock_for_update, do: "WITH(UPDLOCK)"
end

defmodule Ecto.Integration.Case do
  use ExUnit.CaseTemplate

  using do
    quote do
      import unquote(__MODULE__)
      require TestRepo

      import Ecto.Query
      alias Ecto.Integration.TestRepo
      alias Ecto.Integration.Post
      alias Ecto.Integration.Comment
      alias Ecto.Integration.Permalink
      alias Ecto.Integration.User
      alias Ecto.Integration.Custom
      alias Ecto.Integration.Barebone
    end
  end

  setup_all do
    Ecto.Adapters.SQL.begin_test_transaction(TestRepo, [])
    on_exit fn -> Ecto.Adapters.SQL.rollback_test_transaction(TestRepo, []) end
    :ok
  end

  setup do
    #Ecto.Adapters.SQL.begin_test_transaction(TestRepo, [])
    Ecto.Adapters.SQL.restart_test_transaction(TestRepo, [])
    #on_exit fn -> Ecto.Adapters.SQL.rollback_test_transaction(TestRepo, []) end
    :ok
  end
end


:erlang.system_flag :backtrace_depth, 50
# Load support models and migration


Code.require_file "../deps/ecto/integration_test/sql/lock.exs", __DIR__
Code.require_file "../deps/ecto/integration_test/sql/migration.exs", __DIR__
Code.require_file "../deps/ecto/integration_test/sql/escape.exs", __DIR__
Code.require_file "../deps/ecto/integration_test/cases/repo.exs", __DIR__
Code.require_file "../deps/ecto/integration_test/cases/type.exs", __DIR__
Code.require_file "../deps/ecto/integration_test/cases/pool.exs", __DIR__
Code.require_file "../deps/ecto/integration_test/cases/preload.exs", __DIR__
Code.require_file "../deps/ecto/integration_test/cases/interval.exs", __DIR__


# Load up the repository, start it, and run migrations
_   = Ecto.Storage.down(TestRepo)
:ok = Ecto.Storage.up(TestRepo)

{:ok, _pid} = TestRepo.start_link
{:ok, _pid} = PoolRepo.start_link

:ok = Ecto.Migrator.up(TestRepo, 0, Ecto.Integration.Migration, log: false)
