defmodule Tds.Ecto.StorageTest do
  use ExUnit.Case, async: true

  alias Tds.Ecto

  def params do
    [database: "storage_mgt",
    pool: Ecto.Adapters.SQL.Sandbox,
     username: "mssql",
     password: "mssql",
     hostname: "localhost"]
  end

  def wrong_params do
    Keyword.merge params(),
      [username: "randomuser",
       password: "password1234"]
  end

  def drop_database do
    database = params()[:database]
    run_sqlcmd("DROP DATABASE [#{database}];")
  end

  def create_database do
    database = params()[:database]
    run_sqlcmd("CREATE DATABASE [#{database}];")
  end

  def create_posts do
    run_sqlcmd("CREATE TABLE posts (title nvarchar(20));", ["-d", params()[:database]])
  end

  def run_sqlcmd(sql, args \\ []) do
    args = [
      "-U", params()[:username], 
      "-P", params()[:password],
      "-H", params()[:hostname], 
      "-Q", ~s(#{sql}) | args]
    # IO.puts(Enum.map_join(args, " ", &"#{&1}"))
    System.cmd "sqlcmd", args
  end

  # setup do
  #   on_exit fn -> drop_database end
  #   :ok
  # end
  
  test "storage up (twice in a row)" do
    assert Tds.Ecto.storage_up(params()) == :ok
    assert Tds.Ecto.storage_up(params()) == {:error, :already_up}
  after
    drop_database()
  end

  test "storage down (twice in a row)" do
    create_database()
    assert Tds.Ecto.storage_down(params()) == :ok
    assert Tds.Ecto.storage_down(params()) == {:error, :already_down}
  end
  
  # test "storage up and down (wrong credentials)" do
  #   refute Tds.Ecto.storage_up(wrong_params()) == :ok
  #   create_database()
  #   refute Tds.Ecto.storage_down(wrong_params()) == :ok
  # after
  #   drop_database()
  # end
end
