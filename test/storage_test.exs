defmodule Tds.Ecto.StorageTest do
  use ExUnit.Case, async: true

  alias Tds.Ecto

  def params do
    [ database: "storage_mgt",
      pool: Ecto.Adapters.SQL.Sandbox,
      hostname: System.get_env("SQL_HOSTNAME") || "localhost",
      username: System.get_env("SQL_USERNAME") || "sa",
      password: System.get_env("SQL_PASSWORD") || "some!Password",]
  end

  def wrong_params() do
    Keyword.merge params(),
      [username: "randomuser",
       password: "password1234"]
  end

  def drop_database(params) do
    database = params[:database]
    run_sqlcmd(params, "DROP DATABASE [#{database}];", ["-d", "master"])
  end

  def create_database(params) do
    database = params[:database]
    run_sqlcmd(params, "CREATE DATABASE [#{database}];", ["-d", "master"])
  end

  def create_posts(params) do
    run_sqlcmd(params, "CREATE TABLE posts (title nvarchar(20));", ["-d", params[:database]])
  end

  def run_sqlcmd(params, sql, args \\ []) do
    args = [
      "-U", params[:username], 
      "-P", params[:password],
      "-H", params[:hostname],
      "-Q", ~s(#{sql}) | args]
    # IO.puts(Enum.map_join(args, " ", &"#{&1}"))
    System.cmd "sqlcmd", args
  end

  # setup do
  #   on_exit fn -> drop_database end
  #   :ok
  # end
  
  test "storage up (twice in a row)" do
    assert :ok == Tds.Ecto.storage_up(params())
    assert {:error, :already_up} == Tds.Ecto.storage_up(params())
    {_, 0} = drop_database(params())
  end

  test "storage down (twice in a row)" do
    {_, 0} = create_database(params())
    assert :ok == Tds.Ecto.storage_down(params())
    assert {:error, :already_down} == Tds.Ecto.storage_down(params())
  end
  
  test "storage up and down (wrong credentials)" do
    refute Tds.Ecto.storage_up(wrong_params()) == :ok
    {_, 0} = create_database(params())
    refute Tds.Ecto.storage_down(wrong_params()) == :ok
    {_, 0} = drop_database(params())
  end
end
