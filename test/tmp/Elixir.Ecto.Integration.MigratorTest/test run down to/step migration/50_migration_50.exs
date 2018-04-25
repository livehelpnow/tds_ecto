defmodule Elixir.Ecto.Integration.MigratorTest.Migration50 do
  use Ecto.Migration


  def up do
    update &[50|&1]
  end

  def down do
    update &List.delete(&1, 50)
  end

  defp update(fun) do
    Process.put(:migrations, fun.(Process.get(:migrations) || []))
  end
end
