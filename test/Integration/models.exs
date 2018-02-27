defmodule Tds.EctoTest.Integration.Models do

  defmodule Item do
    use Ecto.Integration.Schema
    
    schema "items" do
      field :title, :string
      field :title_bin, Tds.VarChar, size: 400 
      field :in_stock, :integer
      field :price, :decimal
    end
  end
end