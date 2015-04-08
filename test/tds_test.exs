Code.require_file "../deps/ecto/integration_test/support/types.exs", __DIR__

defmodule Tds.Ecto.TdsTest do
  use ExUnit.Case, async: true
  use Ecto.Migration
  
  alias Tds.Ecto.Connection, as: SQL

  test "create table with column options" do
    create = {:create, table(:posts),
               [{:add, :name, :string, [default: "Untitled", size: 20, null: false]},
                {:add, :price, :decimal, [unique: true, precision: 15, scale: 14, default: {:fragment, "PI()"}]},
                {:add, :on_hand, :integer, [default: 0, null: true]},
                {:add, :is_active, :boolean, [default: true]},
                {:add, :slug, :text, [null: false]}]}
                
    assert SQL.execute_ddl(create, nil) == """
    CREATE TABLE [posts] ([name] nvarchar(20) DEFAULT 'Untitled' NOT NULL,
    [price] decimal(15,14) DEFAULT PI() NULL,
    [on_hand] integer DEFAULT 0 NULL,
    [is_active] bit DEFAULT 1 NULL,
    [slug] nvarchar(max) NOT NULL,
    CONSTRAINT uc_price UNIQUE ([price]))
    """ |> String.strip |> String.replace("\n", " ")
  end

end

