defmodule Elixir.Ecto.Integration.MigratorTest.Migration47 do
  use Ecto.Migration


  def up do
    update &[47|&1]
  end

  def down do
    update &List.delete(&1, 47)
  end

  defp update(fun) do
    Process.put(:migrations, fun.(Process.get(:migrations) || []))
  end
end
