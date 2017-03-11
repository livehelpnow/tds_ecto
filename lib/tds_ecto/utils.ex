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

  defmacro if_index_exists(condition, index_name, table_name) do
    quote do
      if(unquote(condition)) do
        ["IF EXISTS (SELECT name FROM sys.indexes WHERE name = N'", 
         Tds.Ecto.Utils.as_string(unquote(index_name)), 
         "' AND object_id = OBJECT_ID(N'",
         Tds.Ecto.Utils.as_string(unquote(table_name)), 
         "')) "]
      else
        []
      end  
    end
  end

  defmacro if_index_not_exists(condition, index_name, table_name) do
    quote do
      if(unquote(condition)) do
        ["IF NOT EXISTS (SELECT name FROM sys.indexes WHERE name = N'", 
         Tds.Ecto.Utils.as_string(unquote(index_name)), 
         "' AND object_id = OBJECT_ID(N'",
         Tds.Ecto.Utils.as_string(unquote(table_name)), 
         "')) "]
      else
        []
      end  
    end
  end

  def as_string(atom) when is_atom(atom), do: Atom.to_string(atom)
  def as_string(str), do: str
end
