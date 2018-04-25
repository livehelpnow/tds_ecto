defmodule Elixir.Ecto.Integration.MigratorTest.Migration54 do
  use Ecto.Migration


  def up do
    update &[54|&1]
  end

  def down do
    update &List.delete(&1, 54)
  end

  defp update(fun) do
    Process.put(:migrations, fun.(Process.get(:migrations) || []))
  end
end
