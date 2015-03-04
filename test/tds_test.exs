Code.require_file "../deps/ecto/integration_test/support/types.exs", __DIR__

defmodule Tds.Ecto.TdsTest do
  use ExUnit.Case, async: true
  use Ecto.Migration

  import Ecto.Query
  import Ecto
  alias Tds.Ecto.Connection, as: SQL

  alias Ecto.Queryable
  alias Ecto.Query.Planner

  defmodule Model do
    use Ecto.Model

    schema "model" do
      field :x, :integer
      field :y, :integer

      has_many :comments, Ecto.Adapters.PostgresTest.Model2,
        references: :x,
        foreign_key: :z
      has_one :permalink, Ecto.Adapters.PostgresTest.Model3,
        references: :y,
        foreign_key: :id
    end
  end

  defmodule Model2 do
    use Ecto.Model

    schema "model2" do
      belongs_to :post, Ecto.Adapters.PostgresTest.Model,
        references: :x,
        foreign_key: :z
    end
  end

  defmodule Model3 do
    use Ecto.Model

    schema "model3" do
      field :list1, {:array, :string}
      field :list2, {:array, :integer}
      field :binary, :binary
    end
  end

  defp normalize(query) do
    {query, _params} = Planner.prepare(query, %{})
    Planner.normalize(query, %{}, [])
  end

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

