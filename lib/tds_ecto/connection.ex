if Code.ensure_loaded?(Tds.Connection) do
  defmodule Tds.Ecto.Connection do
    @moduledoc false

    @default_port System.get_env("MSSQLPORT") || 1433
    @behaviour Ecto.Adapters.SQL.Connection

    def connect(opts) do
      opts = opts 
        |> Keyword.put_new(:port, @default_port)
      Tds.Connection.start_link(opts)
    end

    def disconnect(conn) do
      try do
        Tds.Connection.stop(conn)
      catch
        :exit, {:noproc, _} -> :ok
      end
      :ok
    end

    def query(conn, sql, params, opts) do
      {params, _} = Enum.map_reduce params, 1, fn(param, acc) ->

        {value, type} = case param do
          %Ecto.Query.Tagged{value: value, type: :boolean} -> 
              value = if value == true, do: 1, else: 0
              {value, :boolean}
          %Ecto.Query.Tagged{value: value, type: :binary} -> 
            type = if value == "", do: :string, else: :binary
            {value, type}
          %Ecto.Query.Tagged{value: {{y,m,d},{hh,mm,ss,us}}, type: :datetime} -> 

            cond do
              us > 0 -> {{{y,m,d},{hh,mm,ss, us}}, :datetime2}
              true -> {{{y,m,d},{hh,mm,ss}}, :datetime}
            end
          %Ecto.Query.Tagged{value: value, type: :uuid} ->
            cond do
              value == nil -> {nil, :binary}
              String.contains?(value, "-") -> 
                {:ok, value} = Ecto.UUID.cast(value)
                {value, :string}
              true -> 
                {uuid(value), :binary}
            end
          %Ecto.Query.Tagged{value: value, type: type} -> 
            {value, type}
          value -> 
            param(value)
        end
        {%Tds.Parameter{name: "@#{acc}", value: value, type: type}, acc + 1}
      end
      case Tds.Connection.query(conn, sql, params, opts) do
        {:ok, %Tds.Result{} = result} ->
          {:ok, Map.from_struct(result)}
        {:error, %Tds.Error{}} = err  -> err
      end
    end

    defp param(value) when is_binary(value) do
      value = value
        |> :unicode.characters_to_binary(:utf8, {:utf16, :little})
      {value, nil}
    end
    defp param(value) when value == true, do: {1, :boolean}
    defp param(value) when value == false, do: {0, :boolean}
    defp param(value), do: {value, nil}
    ## Transaction

    def begin_transaction do
      "BEGIN TRANSACTION"
    end

    def rollback do
      "ROLLBACK TRANSACTION"
    end

    def commit do
      "COMMIT TRANSACTION"
    end

    def savepoint(savepoint) do
      "SAVE TRANSACTION " <> savepoint
    end

    def rollback_to_savepoint(savepoint) do
      "ROLLBACK TRANSACTION " <> savepoint <> ";" <> savepoint(savepoint)

    end

    ## Query

    alias Ecto.Query.SelectExpr
    alias Ecto.Query.QueryExpr
    alias Ecto.Query.JoinExpr

    def all(query) do
      sources = create_names(query)

      from     = from(sources, query.lock)
      select   = select(query.select, query.limit, query.distinct, sources)
      join     = join(query.joins, sources, query.lock)
      where    = where(query.wheres, sources)
      group_by = group_by(query.group_bys, sources)
      having   = having(query.havings, sources)
      order_by = order_by(query.order_bys, sources)
      
      offset   = offset(query.offset, sources)
      # lock     = lock(query.lock)
      
      # unlock   = unlock(query.lock)

      assemble([select, from, join, where, group_by, having, order_by, offset])
    end

    def update_all(query, values) do
      sources = create_names(query)
      {table, name, _model} = elem(sources, 0)

      zipped_sql = Enum.map_join(values, ", ", fn {field, expr} ->
        "#{quote_name(field)} = #{expr(expr, sources)}"
      end)

      where = where(query.wheres, sources)
      where = if where, do: " " <> where, else: ""
      # fields = Enum.map(values, fn {field, value} -> 
      #   field
      # end)
      "UPDATE #{name} " <>
        "SET " <> zipped_sql <> " FROM #{quote_table_name(table)} AS #{name} " <> 
        where
    end

    def delete_all(query) do
      sources = create_names(query)
      {table, name, _model} = elem(sources, 0)

      where = where(query.wheres, sources)
      where = if where, do: " " <> where, else: ""
      "DELETE #{name} FROM #{quote_table_name(table)} AS #{name}" <> where
    end

    def insert(table, fields, returning) do
      values =
        if fields == [] do
          returning(returning, "INSERTED") <>
          " DEFAULT VALUES"
        else
          "(" <> Enum.map_join(fields, ", ", &quote_name/1) <> ") " <>
          returning(returning, "INSERTED") <>
          "VALUES (" <> Enum.map_join(1..length(fields), ", ", &"@#{&1}") <> ")"
        end
      "INSERT INTO #{quote_table_name(table)} " <> values
    end

    def update(table, fields, filters, returning) do
      {fields, count} = Enum.map_reduce fields, 1, fn field, acc ->
        {"#{quote_name(field)} = @#{acc}", acc + 1}
      end

      {filters, _count} = Enum.map_reduce filters, count, fn field, acc ->
        {"#{quote_name(field)} = @#{acc}", acc + 1}
      end
      "UPDATE #{quote_table_name(table)} SET " <> Enum.join(fields, ", ") <> returning(returning, "INSERTED") <>
        " WHERE " <> Enum.join(filters, " AND ")
    end

    def delete(table, filters, returning) do
      {filters, _} = Enum.map_reduce filters, 1, fn field, acc ->
        {"#{quote_name(field)} = @#{acc}", acc + 1}
      end

      "DELETE FROM #{quote_table_name(table)}" <> 
      returning(returning,"DELETED") <> " WHERE " <> Enum.join(filters, " AND ")
    end

    ## Query generation

    binary_ops =
      [==: "=", !=: "!=", <=: "<=", >=: ">=", <:  "<", >:  ">",
       and: "AND", or: "OR",
       ilike: "ILIKE", like: "LIKE"]

    @binary_ops Keyword.keys(binary_ops)

    Enum.map(binary_ops, fn {op, str} ->
      defp handle_call(unquote(op), 2), do: {:binary_op, unquote(str)}
    end)

    defp handle_call(fun, _arity), do: {:fun, Atom.to_string(fun)}

    defp select(%SelectExpr{fields: fields}, limit, [], sources) do
      #IO.inspect limit
      "SELECT " <> limit(limit, sources) <> Enum.map_join(fields, ", ", &expr(&1, sources)) 
    end

    defp select(%SelectExpr{fields: fields}, limit, distinct, sources) do
      "SELECT " <>
        distinct(distinct, sources) <>
        limit(limit, sources) <>
        Enum.map_join(fields, ", ", &expr(&1, sources))
    end

    defp distinct(nil, _sources), do: ""
    defp distinct(%QueryExpr{expr: true}, _sources),  do: "DISTINCT "
    defp distinct(%QueryExpr{expr: false}, _sources), do: ""
    defp distinct(%QueryExpr{expr: _exprs}, _sources) do
      raise "MSSQL does not allow expressions in distinct"
    end

    defp from(sources, lock) do
      {table, name, _model} = elem(sources, 0)
      "FROM #{quote_table_name(table)} AS #{name} " <> lock(lock)
    end

    defp join([], _sources, _lock), do: nil
    defp join(joins, sources, lock) do
      Enum.map_join(joins, " ", fn
        %JoinExpr{on: %QueryExpr{expr: expr}, qual: qual, ix: ix} ->
          {table, name, _model} = elem(sources, ix)

          on   = expr(expr, sources)
          qual = join_qual(qual)

          "#{qual} JOIN #{quote_table_name(table)} AS #{name} " <> lock(lock) <> " ON " <> on
      end)
    end

    defp join_qual(:inner), do: "INNER"
    defp join_qual(:left),  do: "LEFT OUTER"
    defp join_qual(:right), do: "RIGHT OUTER"
    defp join_qual(:full),  do: "FULL OUTER"

    defp where(wheres, sources) do
      boolean("WHERE", wheres, sources)
    end

    defp having(havings, sources) do
      boolean("HAVING", havings, sources)
    end

    defp group_by(group_bys, sources) do
      exprs =
        Enum.map_join(group_bys, ", ", fn
          %QueryExpr{expr: expr} ->
            Enum.map_join(expr, ", ", &expr(&1, sources))
        end)

      case exprs do
        "" -> nil
        _  -> "GROUP BY " <> exprs
      end
    end

    defp order_by(order_bys, sources) do
      exprs =
        Enum.map_join(order_bys, ", ", fn
          %QueryExpr{expr: expr} ->
            Enum.map_join(expr, ", ", &order_by_expr(&1, sources))
        end)

      case exprs do
        "" -> nil
        _  -> "ORDER BY " <> exprs
      end
    end

    defp order_by_expr({dir, expr}, sources) do
      str = expr(expr, sources)
      case dir do
        :asc  -> str
        :desc -> str <> " DESC"
      end
    end

    defp limit(nil, _sources), do: ""
    defp limit(%Ecto.Query.QueryExpr{expr: expr}, sources) do
      "TOP(" <> expr(expr, sources) <> ") "
    end

    defp offset(nil, _sources), do: nil
    defp offset(%Ecto.Query.QueryExpr{expr: expr}, sources) do
      "OFFSET " <> expr(expr, sources)
    end

    defp lock(nil), do: ""
    defp lock(lock_clause), do: lock_clause

    defp boolean(_name, [], _sources), do: nil
    defp boolean(name, query_exprs, sources) do
      name <> " " <>
        Enum.map_join(query_exprs, " AND ", fn
          %QueryExpr{expr: expr} ->
            "(" <> expr(expr, sources) <> ")"
        end)
    end

    defp expr({:^, [], [ix]}, _sources) do
      "@#{ix+1}"
    end

    defp expr({{:., _, [{:&, _, [idx]}, field]}, _, []}, sources) when is_atom(field) do
      {_, name, _} = elem(sources, idx)
      "#{name}.#{quote_name(field)}"
    end

    defp expr({:&, _, [idx]}, sources) do
      {_table, name, model} = elem(sources, idx)
      fields = model.__schema__(:fields)
      Enum.map_join(fields, ", ", &"#{name}.#{quote_name(&1)}")
    end

    defp expr({:in, _, [_left, []]}, _sources) do
      "0=1"
    end

    defp expr({:in, _, [left, right]}, sources) when is_list(right) do
      args = Enum.map_join right, ",", &expr(&1, sources)
      expr(left, sources) <> " IN (" <> args <> ")"
    end

    defp expr({:in, _, [left, {:^, _, [ix, length]}]}, sources) do
      args = Enum.map_join ix+1..ix+length, ",", &"@#{&1}"
      expr(left, sources) <> " IN (" <> args <> ")"
    end

    defp expr({:is_nil, _, [arg]}, sources) do
      "#{expr(arg, sources)} IS NULL"
    end

    defp expr({:not, _, [expr]}, sources) do
      "NOT (" <> expr(expr, sources) <> ")"
    end

    defp expr({:fragment, _, parts}, sources) do
      Enum.map_join(parts, "", fn
        part when is_binary(part) -> part
        expr -> expr(expr, sources)
      end)
    end

    defp expr({fun, _, args}, sources) when is_atom(fun) and is_list(args) do
      case handle_call(fun, length(args)) do
        {:binary_op, op} ->
          [left, right] = args
          op_to_binary(left, sources) <>
          " #{op} "
          <> op_to_binary(right, sources)

        {:fun, fun} ->
          "#{fun}(" <> Enum.map_join(args, ", ", &expr(&1, sources)) <> ")"
      end
    end

    defp expr(list, sources) when is_list(list) do
      Enum.map_join(list, ", ", &expr(&1, sources))
    end

    defp expr(string, _sources) when is_binary(string) do
      hex = string
        |> :unicode.characters_to_binary(:utf8, {:utf16, :little})
        |> Base.encode16(case: :lower)
      "CONVERT(nvarchar(max), 0x#{hex})"
    end

    defp expr(%Ecto.Query.Tagged{value: binary, type: :binary}, _sources) when is_binary(binary) do
      hex = Base.encode16(binary, case: :lower)
      "0x#{hex}"
    end

    defp expr(%Ecto.Query.Tagged{value: binary, type: :uuid}, _sources) when is_binary(binary) do
      if String.contains?(binary, "-"), do: {:ok, binary} = Ecto.UUID.dump(binary)
      uuid(binary)
    end

    defp expr(%Ecto.Query.Tagged{value: other}, sources) do
      expr(other, sources)
    end

    defp expr(nil, _sources),   do: "NULL"
    defp expr(true, _sources),  do: "1"
    defp expr(false, _sources), do: "0"

    defp expr(literal, _sources) when is_binary(literal) do
      "'#{escape_string(literal)}'"
    end

    defp expr(literal, _sources) when is_integer(literal) do
      String.Chars.Integer.to_string(literal)
    end

    defp expr(literal, _sources) when is_float(literal) do
      String.Chars.Float.to_string(literal)
    end

    defp op_to_binary({op, _, [_, _]} = expr, sources) when op in @binary_ops do
      "(" <> expr(expr, sources) <> ")"
    end

    defp op_to_binary(expr, sources) do
      expr(expr, sources)
    end

    defp returning([], _verb),
      do: ""
    defp returning(returning, verb) do 
      " OUTPUT " <> Enum.map_join(returning, ", ", fn(arg) -> "#{verb}.#{quote_name(arg)} " end)
    end

    defp create_names(query) do
      sources = query.sources |> Tuple.to_list
      Enum.reduce(sources, [], fn {table, model}, names ->
        name = unique_name(names, String.first(table), 0)
        [{table, name, model}|names]
      end) |> Enum.reverse |> List.to_tuple
    end

    # Brute force find unique name
    defp unique_name(names, name, counter) do
      counted_name = name <> Integer.to_string(counter)
      if Enum.any?(names, fn {_, n, _} -> n == counted_name end) do
        unique_name(names, name, counter + 1)
      else
        counted_name
      end
    end

    # DDL

    alias Ecto.Migration.Table
    alias Ecto.Migration.Index
    alias Ecto.Migration.Reference

    def ddl_exists(%Table{name: name}) do
      """
      SELECT count(1) FROM information_schema.tables t
       WHERE t.table_name = '#{escape_string(to_string(name))}'
      """
    end

    def ddl_exists(%Index{name: name}) do
      """
      SELECT count(1) FROM sys.indexes i
       WHERE i.name = '#{escape_string(to_string(name))}'
      """
    end
    def execute_ddl(_), do: nil
    def execute_ddl({:create, %Table{}=table, columns}, _repo) do
      unique_columns = Enum.reduce(columns, [], fn({_,name,type,opts}, acc) ->  
        if Keyword.get(opts, :unique) != nil, do: List.flatten([{name, type}|acc]), else: acc
      end)
      unique_constraints = unique_columns
        |> Enum.map_join(", ", &unique_expr/1)
      "CREATE TABLE #{quote_table_name(table.name)} (#{column_definitions(columns)}" <>
      if length(unique_columns) > 0, do: ", #{unique_constraints})", else: ")"
    end

    def execute_ddl({:drop, %Table{name: name}}, _repo) do
      "DROP TABLE #{quote_table_name(name)}"
    end

    def execute_ddl({:alter, %Table{}=table, changes}, _repo) do
      Enum.map_join(changes, "; ", fn(change) -> 
        "ALTER TABLE #{quote_table_name(table.name)} #{column_change(change)}"
      end)
    end

    def execute_ddl({:create, %Index{}=index}, repo) do

      filter = 
      if (repo.config[:filter_null_on_unique_indexes] == true and index.unique) do
        " WHERE #{Enum.map_join(index.columns, " AND ", fn(column) -> "#{column} IS NOT NULL" end)}"
      else 
        ""
      end
      assemble(["CREATE#{if index.unique, do: " UNIQUE"} INDEX",
                quote_table_name(index.name), " ON ", quote_table_name(index.table),
                " (#{Enum.map_join(index.columns, ", ", &index_expr/1)})",
                filter])
    end

    def execute_ddl({:drop, %Index{}=index}, _repo) do
      assemble(["DROP INDEX", quote_table_name(index.name), " ON ", quote_table_name(index.table)])
    end

    def execute_ddl(default, _repo) when is_binary(default), do: default

    defp column_definitions(columns) do
      Enum.map_join(columns, ", ", &column_definition/1)
    end

    defp column_definition({:add, name, type, opts}) do
      assemble([quote_name(name), column_type(type, opts), column_options(opts), serial_expr(type)])
    end

    # defp column_changes(columns) do
    #   Enum.map_join(columns, ", ", &column_change/1)
    # end

    defp column_change({:add, name, type, opts}) do
      assemble(["ADD", quote_name(name), column_type(type, opts), column_options(opts)])
    end

    defp column_change({:modify, name, type, opts}) do
      assemble(["ALTER COLUMN", quote_name(name), column_type(type, opts)])
    end

    defp column_change({:remove, name}), do: "DROP COLUMN #{quote_name(name)}"

    defp column_options(opts) do
      default = Keyword.get(opts, :default)
      null    = Keyword.get(opts, :null)
      pk      = Keyword.get(opts, :primary_key)
      if pk == true, do: null = false
      [default_expr(default), null_expr(null), pk_expr(pk)]
    end

    defp pk_expr(true), do: "PRIMARY KEY"
    defp pk_expr(_), do: nil

    defp serial_expr(:serial), do: "IDENTITY"
    defp serial_expr(_), do: nil

    defp unique_expr({_name, type}) when type in [:string, :text] do
      raise "UNIQUE Indexes are not allowed on string types"
    end
    defp unique_expr({name, _type}) when is_atom(name) do
      "CONSTRAINT uc_#{name} UNIQUE (#{quote_table_name(name)})"
    end
    defp unique_expr(_), do: ""

    defp null_expr(false), do: "NOT NULL"
    defp null_expr(true), do: "NULL"
    defp null_expr(_), do: "NULL"

    defp default_expr(nil),
      do: nil
    defp default_expr(boolean) when boolean == true or boolean == false,
      do: "DEFAULT #{if boolean == true, do: 1, else: 0}"
    defp default_expr(literal) when is_binary(literal),
      do: "DEFAULT '#{escape_string(literal)}'"
    defp default_expr(literal) when is_number(literal),
      do: "DEFAULT #{literal}"
    defp default_expr({:fragment, expr}),
      do: "DEFAULT #{expr}"

    defp index_expr(literal) when is_binary(literal),
      do: literal
    defp index_expr(literal),
      do: literal

    defp column_type(%Reference{} = ref, opts) do
      "#{reference_column_type(ref.type, opts)} REFERENCES " <>
      "#{quote_name(ref.table)}(#{quote_name(ref.column)})"
    end
    defp column_type({:array, _type}, _opts),
      do: raise "Array column type is not supported for MSSQL"
    defp column_type(:uuid, _opts), do: "uniqueidentifier"
    defp column_type(type, opts) do
      pk        = Keyword.get(opts, :primary_key)
      size      = Keyword.get(opts, :size)
      precision = Keyword.get(opts, :precision)
      scale     = Keyword.get(opts, :scale)
      type_name = ecto_to_db(type)

      cond do
        type == :serial -> "bigint"
        pk == true      -> "bigint"
        size            -> "#{type_name}(#{size})"
        precision       -> "#{type_name}(#{precision},#{scale || 0})"
        type == :string -> "nvarchar(255)"
        type == :text   -> "nvarchar(max)"
        type == :binary -> "varbinary(max)"
        type == :boolean -> "bit"
        true            -> "#{type_name}"
      end
    end


    defp reference_column_type(:serial, _opts), do: "bigint"
    defp reference_column_type(type, opts), do: column_type(type, opts)

    ## Helpers

    defp quote_name(name), do: "[#{name}]"
    defp quote_table_name(name) do
      "#{name}"
        |> String.split(".")
        |> Enum.map(&quote_name/1)
        |> Enum.join(".")
    end

    defp assemble(list) do
      list
      |> List.flatten
      |> Enum.filter(&(&1 != nil))
      |> Enum.join(" ")
    end

    defp escape_string(value) when is_binary(value) do
      :binary.replace(value, "'", "''", [:global])
    end

    defp ecto_to_db(:string),     do: "nvarchar"
    defp ecto_to_db(:binary),     do: "varbinary"
    defp ecto_to_db(:boolean),    do: "bit"
    defp ecto_to_db(other),       do: Atom.to_string(other)

    defp uuid(binary) do
      <<
       p1::binary-size(1),
       p2::binary-size(1), 
       p3::binary-size(1), 
       p4::binary-size(1), 
       p5::binary-size(1), 
       p6::binary-size(1), 
       p7::binary-size(1), 
       p8::binary-size(1), 
       p9::binary-size(1), 
       p10::binary-size(1), 
       p11::binary-size(1), 
       p12::binary-size(1), 
       p13::binary-size(1), 
       p14::binary-size(1), 
       p15::binary-size(1), 
       p16::binary-size(1)>> = binary

       p4 <> p3 <> p2 <>p1 <> p6 <> p5 <> p8 <> p7 <> p9 <> p10 <> p11 <> p12 <> p13 <> p14 <> p15 <> p16
    end
  end
end