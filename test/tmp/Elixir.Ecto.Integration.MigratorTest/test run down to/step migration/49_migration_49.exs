defmodule Elixir.Ecto.Integration.MigratorTest.Migration49 do
  use Ecto.Migration


  def up do
    update &[49|&1]
  end

  def down do
    update &List.delete(&1, 49)
  end

  defp update(fun) do
    Process.put(:migrations, fun.(Process.get(:migrations) || []))
  end
end
