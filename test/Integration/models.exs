defmodule Tds.EctoTest.Integration.Models do

  defmodule Item do
    use Ecto.Integration.Schema
    
    schema "items" do
      field :title, :string
      field :in_stock, :integer
      field :price, :decimal
    end
  end
end