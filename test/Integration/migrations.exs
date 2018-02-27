defmodule Tds.EctoTest.Integration.Migrations do
  
  defmodule CreateItemsTable do
    use Ecto.Migration

    def change() do
      create table(:items) do
        add :title, :string, size: 400, null: false
        add :title_bin, :varchar, size: 400, null: true
        add :in_stock, :integer, null: false, default: 0
        add :price, :decimal, precision: 10, scale: 4
      end
    end
  end
end