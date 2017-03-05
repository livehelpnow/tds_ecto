defmodule Tds.Ecto.Utils do
  # types 
  # "U" - table, 
  # "C", "PK", "UQ", "F ", "D "" - constraints
  defmacro if_object_exists(condition, name, type, do: statement) do
    quote do
      if (unquote(condition)) do
        ["IF (OBJECT_ID(N'", unquote(name),"', '", unquote(type) ,"') IS NOT NULL) BEGIN ",
          unquote(statement),
          " END; "]
      else
        []
      end   
    end
  end
end