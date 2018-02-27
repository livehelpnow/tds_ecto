# Code.require_file "../deps/ecto/integration_test/sql/migration.exs", __DIR__
# Code.require_file "../deps/ecto/integration_test/sql/lock.exs", __DIR__
# Code.require_file "../deps/ecto/integration_test/cases/repo.exs", __DIR__
# Code.require_file "../deps/ecto/integration_test/cases/type.exs", __DIR__
# Code.require_file "../deps/ecto/integration_test/cases/preload.exs", __DIR__
# Code.require_file "../deps/ecto/integration_test/cases/interval.exs", __DIR__

Code.require_file "./integration/models.exs", __DIR__
Code.require_file "./integration/migrations.exs", __DIR__

defmodule Tds.EctoTest.IntegrationTest do
  use    ExUnit.Case
  import Ecto.Migrator 
  import Ecto.Query
  alias  Ecto.Integration.PoolRepo, as: Repo
  alias  Tds.EctoTest.Integration.{Models, Migrations}
  require Logger

  setup do
    :ok = up(Repo, 0, Ecto.Integration.Migration, log: :info)
    :ok = up(Repo, 1, Migrations.CreateItemsTable, log: :info)
  end
  
  #test "should insert new Item with price and stock availability into items table" do
    #assert {:ok, _} = Repo.insert(%Models.Item{title: "Item 1", in_stock: 4, price: 12.34})
    #assert {:ok, _} = Repo.insert(%Models.Item{title: "Item 2", in_stock: 0, price: Decimal.new(12.34)})
  #end

  test "should insert and read back multiline strings" do
    title = "EF\n\rGF"
    title_bin = "VARCHAR"
    price = Decimal.new(0)
    
    model = %Models.Item{
      title: title,
      title_bin: title_bin,
      in_stock: 0,
      price: price
    }

    assert {:ok, _} = Repo.insert(model, timeout: 30_000)
    assert [%{id: 1}=_] = Repo.all(Models.Item)
    assert [%{id: 1}=_] = Models.Item
                    |> where([i], i.title_bin == ^title_bin)
                    |> Repo.all()

    assert [%{id: 1}=_] = Models.Item
                  |> where([i], i.title_bin == "VARCHAR")
                  |> Repo.all()
    
  end
end