defmodule Elixir.Ecto.Integration.MigratorTest.Migration53 do
  use Ecto.Migration


  def up do
    update &[53|&1]
  end

  def down do
    update &List.delete(&1, 53)
  end

  defp update(fun) do
    Process.put(:migrations, fun.(Process.get(:migrations) || []))
  end
end
