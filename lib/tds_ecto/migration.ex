defmodule Tds.Ecto.Migration do

  alias Ecto.Migration.{Table, Index, Reference, Constraint}

  def execute_ddl({command, %Table{} = table, columns}) when command in [:create, :create_if_not_exists] do
    table_structure =
      case column_definitions(table, columns) ++ pk_definitions(columns, ", CONSTRAINT [PK_#{table.prefix}_#{table.name}] ") do
        [] -> []
        list -> [?\s, ?(, list, ?)]
      end

    [[if_table_not_exists(command == :create_if_not_exists, table.name, table.prefix),
      "CREATE TABLE ",
      quote_table(table.prefix, table.name),
      table_structure,
      engine_expr(table.engine),
      options_expr(table.options),
      if_do(command == :create_if_not_exists, "END ")]]
  end

  def execute_ddl({command, %Table{} = table}) when command in [:drop, :drop_if_exists] do
    [[if_table_exists(command == :drop_if_exists, table.name, table.prefix),
      "DROP TABLE ",
      quote_table(table.prefix, table.name),
      if_do(command == :drop_if_exists, "END ")]]
  end

  def execute_ddl({:alter, %Table{} = table, changes}) do
    [["ALTER TABLE ", quote_table(table.prefix, table.name), ?\s,
      column_changes(table, changes),
      pk_definitions(changes, ", ADD CONSTRAINT [PK_#{table.prefix}_#{table.name}] ")]]
  end

  def execute_ddl({:create, %Index{} = index}) do
    if index.where do
      error!(nil, "MySQL adapter does not support where in indexes")
    end

    [["CREATE", if_do(index.unique, " UNIQUE"), " INDEX ",
      quote_name(index.name),
      " ON ",
      quote_table(index.prefix, index.table), ?\s,
      ?(, intersperse_map(index.columns, ", ", &index_expr/1), ?),
      if_do(index.using, [" USING ", to_string(index.using)]),
      if_do(index.concurrently, " LOCK=NONE")]]
  end

  def execute_ddl({:create_if_not_exists, %Index{}}),
    do: error!(nil, "MySQL adapter does not support create if not exists for index")

  def execute_ddl({:create, %Constraint{check: check}}) when is_binary(check),
    do: error!(nil, "MySQL adapter does not support check constraints")
  def execute_ddl({:create, %Constraint{exclude: exclude}}) when is_binary(exclude),
    do: error!(nil, "MySQL adapter does not support exclusion constraints")

  def execute_ddl({:drop, %Index{} = index}) do
    [["DROP INDEX ",
      quote_name(index.name),
      " ON ", quote_table(index.prefix, index.table),
      if_do(index.concurrently, " LOCK=NONE")]]
  end

  def execute_ddl({:drop, %Constraint{}}),
    do: error!(nil, "MySQL adapter does not support constraints")

  def execute_ddl({:drop_if_exists, %Index{}}),
    do: error!(nil, "MySQL adapter does not support drop if exists for index")

  def execute_ddl({:rename, %Table{} = current_table, %Table{} = new_table}) do
    [["RENAME TABLE ", quote_table(current_table.prefix, current_table.name),
      " TO ", quote_table(new_table.prefix, new_table.name)]]
  end

  def execute_ddl({:rename, _table, _current_column, _new_column}) do
    error!(nil, "MySQL adapter does not support renaming columns")
  end

  def execute_ddl(string) when is_binary(string), do: [string]

  def execute_ddl(keyword) when is_list(keyword),
    do: error!(nil, "MySQL adapter does not support keyword lists in execute")

  defp pk_definitions(columns, prefix) do
    pks =
      for {_, name, _, opts} <- columns,
          opts[:primary_key],
          do: name

    case pks do
      [] -> []
      _  -> [[prefix, "PRIMARY KEY CLUSTERED (", intersperse_map(pks, ", ", &quote_name/1), ?)]]
    end
  end

  defp column_definitions(table, columns) do
    intersperse_map(columns, ", ", &column_definition(table, &1))
  end

  defp column_definition(table, {:add, name, %Reference{} = ref, opts}) do
    [quote_name(name), ?\s, reference_column_type(ref.type, opts),
     column_options(opts), reference_expr(ref, table, name)]
  end

  defp column_definition(_table, {:add, name, type, opts}) do
    [quote_name(name), ?\s, column_type(type, opts), column_options(opts)]
  end

  defp column_changes(table, columns) do
    intersperse_map(columns, ", ", &column_change(table, &1))
  end

  defp column_change(table, {:add, name, %Reference{} = ref, opts}) do
    ["ADD ", quote_name(name), ?\s, reference_column_type(ref.type, opts),
     column_options(opts), constraint_expr(ref, table, name)]
  end

  defp column_change(_table, {:add, name, type, opts}) do
    ["ADD ", quote_name(name), ?\s, column_type(type, opts), column_options(opts)]
  end

  defp column_change(table, {:modify, name, %Reference{} = ref, opts}) do
    ["MODIFY ", quote_name(name), ?\s, reference_column_type(ref.type, opts),
     column_options(opts), constraint_expr(ref, table, name)]
  end

  defp column_change(_table, {:modify, name, type, opts}) do
    ["MODIFY ", quote_name(name), ?\s, column_type(type, opts), column_options(opts)]
  end

  defp column_change(_table, {:remove, name}), do: ["DROP ", quote_name(name)]

  defp column_options(opts) do
    default = Keyword.fetch(opts, :default)
    null    = Keyword.get(opts, :null)
    [default_expr(default), null_expr(null)]
  end

  defp null_expr(false), do: " NOT NULL"
  defp null_expr(true), do: " NULL"
  defp null_expr(_), do: []

  defp default_expr({:ok, nil}),
    do: " DEFAULT NULL"
  defp default_expr({:ok, literal}) when is_binary(literal),
    do: [" DEFAULT '", escape_string(literal), ?']
  defp default_expr({:ok, literal}) when is_number(literal) or is_boolean(literal),
    do: [" DEFAULT ", to_string(literal)]
  defp default_expr({:ok, {:fragment, expr}}),
    do: [" DEFAULT ", expr]
  defp default_expr(:error),
    do: []

  defp index_expr(literal) when is_binary(literal),
    do: literal
  defp index_expr(literal), do: quote_name(literal)

  defp engine_expr(storage_engine),
    do: [" ENGINE = ", String.upcase(to_string(storage_engine || "INNODB"))]

  defp options_expr(nil),
    do: []
  defp options_expr(keyword) when is_list(keyword),
    do: error!(nil, "MySQL adapter does not support keyword lists in :options")
  defp options_expr(options),
    do: [?\s, to_string(options)]

  defp column_type(type, opts) do
    size      = Keyword.get(opts, :size)
    precision = Keyword.get(opts, :precision)
    scale     = Keyword.get(opts, :scale)
    type_name = ecto_to_db(type)

    cond do
      size            -> [type_name, ?(, to_string(size), ?)]
      precision       -> [type_name, ?(, to_string(precision), ?,, to_string(scale || 0), ?)]
      type == :string -> [type_name, "(255)"]
      true            -> type_name
    end
  end

  defp constraint_expr(%Reference{} = ref, table, name),
    do: [", ADD CONSTRAINT ", reference_name(ref, table, name),
         " FOREIGN KEY (", quote_name(name), ?),
         " REFERENCES ", quote_table(table.prefix, ref.table),
         ?(, quote_name(ref.column), ?),
         reference_on_delete(ref.on_delete), reference_on_update(ref.on_update)]

  defp reference_expr(%Reference{} = ref, table, name),
    do: [", CONSTRAINT ", reference_name(ref, table, name),
         " FOREIGN KEY (", quote_name(name), ?),
         " REFERENCES ", quote_table(table.prefix, ref.table),
         ?(, quote_name(ref.column), ?),
         reference_on_delete(ref.on_delete), reference_on_update(ref.on_update)]

  defp reference_name(%Reference{name: nil}, table, column),
    do: quote_name("#{table.name}_#{column}_fkey")
  defp reference_name(%Reference{name: name}, _table, _column),
    do: quote_name(name)

  defp reference_column_type(:serial, _opts), do: "BIGINT UNSIGNED"
  defp reference_column_type(:bigserial, _opts), do: "BIGINT UNSIGNED"
  defp reference_column_type(type, opts), do: column_type(type, opts)

  defp reference_on_delete(:nilify_all), do: " ON DELETE SET NULL"
  defp reference_on_delete(:delete_all), do: " ON DELETE CASCADE"
  defp reference_on_delete(_), do: []

  defp reference_on_update(:nilify_all), do: " ON UPDATE SET NULL"
  defp reference_on_update(:update_all), do: " ON UPDATE CASCADE"
  defp reference_on_update(_), do: []

  ## Helpers

  defp get_source(query, sources, ix, source) do
    {expr, name, _schema} = elem(sources, ix)
    {expr || paren_expr(source, sources, query), name}
  end

  defp quote_name(name)
  defp quote_name(name) when is_atom(name),
    do: quote_name(Atom.to_string(name))
  defp quote_name(name) do
    if String.contains?(name, "[") or String.contains?(name, "]") do
      error!(nil, "bad field name #{inspect name} '[' and ']' are not permited")
    end

    [?[, name, ?]]
  end

  defp quote_table(nil, name),    do: quote_table(name)
  defp quote_table(prefix, name), do: [quote_table(prefix), ?., quote_table(name)]

  defp quote_table(name) when is_atom(name),
    do: quote_table(Atom.to_string(name))
  defp quote_table(name) do
    if String.contains?(name, "[") or String.contains?(name, "]") do
      error!(nil, "bad table name #{inspect name} '[' and ']' are not permited")
    end
    [?[, name, ?]]
  end

  defp intersperse_map(list, separator, mapper, acc \\ [])
  defp intersperse_map([], _separator, _mapper, acc),
    do: acc
  defp intersperse_map([elem], _separator, mapper, acc),
    do: [acc | mapper.(elem)]
  defp intersperse_map([elem | rest], separator, mapper, acc),
    do: intersperse_map(rest, separator, mapper, [acc, mapper.(elem), separator])

  defp if_do(condition, value) do
    if condition, do: value, else: []
  end

  defp escape_string(value) when is_binary(value) do
    value
    |> :binary.replace("'", "''", [:global])
  end

  defp ecto_cast_to_db(type, query), do: ecto_to_db(type, query)

  defp ecto_to_db(type, query \\ nil)
  defp ecto_to_db({:array, _}, query),
    do: error!(query, "Array type is not supported by TDS")
  defp ecto_to_db(:id, _query),             do: "bigint"
  defp ecto_to_db(:serial, _query),         do: "int"
  defp ecto_to_db(:bigserial, _query),      do: "bigint"
  defp ecto_to_db(:binary_id, _query),      do: "uniqueidentifier"
  defp ecto_to_db(:boolean, _query),        do: "bit"
  defp ecto_to_db(:string, _query),         do: "nvarchar"
  defp ecto_to_db(:float, _query),          do: "float"
  defp ecto_to_db(:binary, _query),         do: "varbinary"
  defp ecto_to_db(:uuid, _query),           do: "uniqueidentifier"
  defp ecto_to_db({:map, :string}, _query), do: "nvarchar"
  defp ecto_to_db(:utc_datetime, _query),   do: "datetime2"
  defp ecto_to_db(:naive_datetime, _query), do: "datetime"
  defp ecto_to_db(other, _query),           do: Atom.to_string(other)

  defp error!(nil, message) do
    raise ArgumentError, message
  end
  defp error!(query, message) do
    raise Ecto.QueryError, query: query, message: message
  end

  defp if_table_not_exists(condition, name, prefix \\ "dbo") do
    if condition do
      query_segment = ["IF NOT EXISTS ( ",
                       "SELECT * ",
                       "FROM [INFORMATION_SCHEMA].[TABLES] info ",
                       "WHERE info.[TABLE_NAME] = '#{name}' ",
                       "AND info.[TABLE_SCHEMA] = '#{prefix}' ",
                       ") BEGIN "]
      Enum.map_join(query_segment, "", &"#{&1}")
    else
      []
    end
  end

  defp if_table_exists(condition, name, prefix \\ "dbo") do
    if condition do
      query_segment = ["IF EXISTS ( ",
                       "SELECT * ",
                       "FROM [INFORMATION_SCHEMA].[TABLES] info ",
                       "WHERE info.[TABLE_NAME] = '#{name}' ",
                       "AND info.[TABLE_SCHEMA] = '#{prefix}' ",
                       ") BEGIN "]
      Enum.map_join(query_segment, "", &"#{&1}")
    else
      []
    end
  end

  def uuid(<<v1::32, v2::16, v3::16, v4::64>>) do
    <<v1::little-signed-32, v2::little-signed-16, v3::little-signed-16, v4::signed-64>>
  end

  

end