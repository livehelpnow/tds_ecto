defmodule Elixir.Ecto.Integration.MigratorTest.Migration48 do
  use Ecto.Migration


  def up do
    update &[48|&1]
  end

  def down do
    update &List.delete(&1, 48)
  end

  defp update(fun) do
    Process.put(:migrations, fun.(Process.get(:migrations) || []))
  end
end
