if Code.ensure_loaded?(Tds.Connection) do
  defmodule Tds.Ecto.Connection do
    @moduledoc false

    @default_port System.get_env("MSSQLPORT") || 1433

    @behaviour Ecto.Adapters.Connection
    @behaviour Ecto.Adapters.SQL.Query

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
          %Ecto.Query.Tagged{value: value, type: type} when type in [:binary_id, :uuid] ->
            cond do
              value == nil -> {nil, :binary}
              String.length(value) > 16 ->
                {:ok, value} = Ecto.UUID.cast(value)
                {value, :string}
              true ->
                {uuid(value), :binary}
            end
          %Ecto.Query.Tagged{value: value, type: type} ->
            {value, type}
          %{__struct__: _} = value -> {value, nil}
          %{} = value -> {json_library.encode!(value), :string}
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
      case :unicode.characters_to_binary(value, :utf8, {:utf16, :little}) do
        {:error, _, _} -> {value, :binary}
        val -> {val, nil}
      end
    end

    defp param({_,_,_} = value), do: {value, :date}
    defp param(value) when value == true, do: {1, :boolean}
    defp param(value) when value == false, do: {0, :boolean}
    defp param(value), do: {value, nil}

    defp json_library do
      Application.get_env(:ecto, :json_library)
    end

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

    alias Ecto.Query
    alias Ecto.Query.SelectExpr
    alias Ecto.Query.QueryExpr
    alias Ecto.Query.JoinExpr

    def all(query) do
      sources = create_names(query)

      from     = from(sources, query.lock)
      select   = select(query, sources)
      join     = join(query, sources)
      where    = where(query, sources)
      group_by = group_by(query, sources)
      having   = having(query, sources)
      order_by = order_by(query, sources)

      offset   = offset(query, sources)

      if (query.offset != nil and query.order_bys == []), do: error!(query, "ORDER BY is mandatory to use OFFSET")
      assemble([select, from, join, where, group_by, having, order_by, offset])
    end

    def update_all(query) do
      sources = create_names(query)
      {table, name, _model} = elem(sources, 0)

      update = "UPDATE #{name}"
      fields = update_fields(query, sources)
      from   = "FROM #{table} AS #{name}"
      join   = join(query, sources)
      where  = where(query, sources)

      assemble([update, "SET", fields, from, join, where])
    end

    def delete_all(query) do
      sources = create_names(query)
      {table, name, _model} = elem(sources, 0)

      delete = "DELETE #{name}"
      from   = "FROM #{table} AS #{name}"
      join   = join(query, sources)
      where  = where(query, sources)

      assemble([delete, from, join, where])
    end

    def insert(prefix, table, fields, returning) do
      values =
        if fields == [] do
          returning(returning, "INSERTED") <>
          "DEFAULT VALUES"
        else
          "(" <> Enum.map_join(fields, ", ", &quote_name/1) <> ")" <>
          " " <> returning(returning, "INSERTED") <>
          "VALUES (" <> Enum.map_join(1..length(fields), ", ", &"@#{&1}") <> ")"
        end
      "INSERT INTO #{quote_table(prefix, table)} " <> values
    end

    def update(prefix, table, fields, filters, returning) do
      {fields, count} = Enum.map_reduce fields, 1, fn field, acc ->
        {"#{quote_name(field)} = @#{acc}", acc + 1}
      end

      {filters, _count} = Enum.map_reduce filters, count, fn field, acc ->
        {"#{quote_name(field)} = @#{acc}", acc + 1}
      end
      "UPDATE #{quote_table(prefix, table)} SET " <> Enum.join(fields, ", ") <>
      " " <> returning(returning, "INSERTED") <>
        "WHERE " <> Enum.join(filters, " AND ")
    end

    def delete(prefix, table, filters, returning) do
      {filters, _} = Enum.map_reduce filters, 1, fn field, acc ->
        {"#{quote_name(field)} = @#{acc}", acc + 1}
      end

      "DELETE FROM #{quote_table(prefix, table)}" <>
      " " <> returning(returning,"DELETED") <> "WHERE " <> Enum.join(filters, " AND ")
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

    defp select(%Query{select: %SelectExpr{fields: fields}, distinct: []} = query, sources) do
      "SELECT " <> limit(query, sources) <> Enum.map_join(fields, ", ", &expr(&1, sources, query))
    end

    defp select(%Query{select: %SelectExpr{fields: fields}} = query, sources) do
      "SELECT " <>
        distinct(query, sources) <>
        limit(query, sources) <>
        Enum.map_join(fields, ", ", &expr(&1, sources, query))
    end

    defp distinct(%Query{distinct: nil}, _sources), do: ""
    defp distinct(%Query{distinct: %QueryExpr{expr: true}}, _sources),  do: "DISTINCT "
    defp distinct(%Query{distinct: %QueryExpr{expr: false}}, _sources), do: ""
    defp distinct(%Query{distinct: %QueryExpr{expr: _exprs}} = query, _sources) do
      error!(query, "MSSQL does not allow expressions in distinct")
    end

    defp from(sources, lock) do
      {table, name, _model} = elem(sources, 0)
      "FROM #{table} AS #{name}" <> lock(lock) |> String.strip
    end

    defp update_fields(%Query{updates: updates} = query, sources) do
      for(%{expr: expr} <- updates,
          {op, kw} <- expr,
          {key, value} <- kw,
          do: update_op(op, key, value, sources, query)) |> Enum.join(", ")
    end

    defp update_op(:set, key, value, sources, query) do
      {_table, name, _model} = elem(sources, 0)
      name <> "." <> quote_name(key) <> " = " <> expr(value, sources, query)
    end

    defp update_op(:inc, key, value, sources, query) do
      {_table, name, _model} = elem(sources, 0)
      quoted = quote_name(key)
      name <> "." <> quoted <> " = " <> name <> "." <> quoted <> " + " <> expr(value, sources, query)
    end

    defp update_op(command, _key, _value, _sources, query) do
      error!(query, "Unknown update operation #{inspect command} for MSSQL")
    end

    defp join(%Query{joins: []}, _sources), do: nil
    defp join(%Query{joins: joins, lock: lock} = query, sources) do
      Enum.map_join(joins, " ", fn
        %JoinExpr{on: %QueryExpr{expr: expr}, qual: qual, ix: ix} ->
          {table, name, _model} = elem(sources, ix)

          on   = expr(expr, sources, query)
          qual = join_qual(qual)

          "#{qual} JOIN #{table} AS #{name} " <> lock(lock) <> "ON " <> on
      end)
    end

    defp join_qual(:inner), do: "INNER"
    defp join_qual(:left),  do: "LEFT OUTER"
    defp join_qual(:right), do: "RIGHT OUTER"
    defp join_qual(:full),  do: "FULL OUTER"

    defp where(%Query{wheres: wheres} = query, sources) do
      boolean("WHERE", wheres, sources, query)
    end

    defp having(%Query{havings: havings} = query, sources) do
      boolean("HAVING", havings, sources, query)
    end

    defp group_by(%Query{group_bys: group_bys} = query, sources) do
      exprs =
        Enum.map_join(group_bys, ", ", fn
          %QueryExpr{expr: expr} ->
            Enum.map_join(expr, ", ", &expr(&1, sources, query))
        end)

      case exprs do
        "" -> nil
        _  -> "GROUP BY " <> exprs
      end
    end

    defp order_by(%Query{order_bys: order_bys} = query, sources) do
      exprs =
        Enum.map_join(order_bys, ", ", fn
          %QueryExpr{expr: expr} ->
            Enum.map_join(expr, ", ", &order_by_expr(&1, sources, query))
        end)

      case exprs do
        "" -> nil
        _  -> "ORDER BY " <> exprs
      end
    end

    defp order_by_expr({dir, expr}, sources, query) do
      str = expr(expr, sources, query)
      case dir do
        :asc  -> str
        :desc -> str <> " DESC"
      end
    end

    defp limit(%Query{limit: nil}, _sources), do: ""
    defp limit(%Query{limit: %QueryExpr{expr: expr}} = query, sources) do
      "TOP(" <> expr(expr, sources, query) <> ") "
    end

    defp offset(%Query{offset: nil}, _sources), do: nil
    defp offset(%Query{offset: %Ecto.Query.QueryExpr{expr: expr}} = query, sources) do
      "OFFSET " <> expr(expr, sources, query) <> " ROW"
    end

    defp lock(nil), do: ""
    defp lock(lock_clause), do: " #{lock_clause} "

    defp boolean(_name, [], _sources, _query), do: nil
    defp boolean(name, query_exprs, sources, query) do
      name <> " " <>
        Enum.map_join(query_exprs, " AND ", fn
          %QueryExpr{expr: expr} ->
            "(" <> expr(expr, sources, query) <> ")"
        end)
    end

    defp expr({:^, [], [ix]}, _sources, _query) do
      "@#{ix+1}"
    end

    defp expr({{:., _, [{:&, _, [idx]}, field]}, _, []}, sources, _query) when is_atom(field) do
      {_, name, _} = elem(sources, idx)
      "#{name}.#{quote_name(field)}"
    end

    defp expr({:&, _, [idx]}, sources, query) do
      {table, name, model} = elem(sources, idx)
      unless model do
        error!(query, "MSSQL requires a model when using selector #{inspect name} but " <>
                             "only the table #{inspect table} was given. Please specify a model " <>
                             "or specify exactly which fields from #{inspect name} you desire")
      end
      fields = model.__schema__(:fields)
      Enum.map_join(fields, ", ", &"#{name}.#{quote_name(&1)}")
    end

    defp expr({:in, _, [_left, []]}, _sources, _query) do
      "0=1"
    end

    defp expr({:in, _, [left, right]}, sources, query) when is_list(right) do
      args = Enum.map_join right, ",", &expr(&1, sources, query)
      expr(left, sources, query) <> " IN (" <> args <> ")"
    end

    defp expr({:in, _, [left, {:^, _, [ix, length]}]}, sources, query) do
      args = Enum.map_join ix+1..ix+length, ",", &"@#{&1}"
      expr(left, sources, query) <> " IN (" <> args <> ")"
    end

    defp expr({:in, _, [left, right]}, sources, query) do
      expr(left, sources, query) <> " IN (" <> expr(right, sources, query) <> ")"
    end

    defp expr({:is_nil, _, [arg]}, sources, query) do
      "#{expr(arg, sources, query)} IS NULL"
    end

    defp expr({:not, _, [expr]}, sources, query) do
      "NOT (" <> expr(expr, sources, query) <> ")"
    end

    defp expr({:fragment, _, [kw]}, _sources, query) when is_list(kw) or tuple_size(kw) == 3 do
      error!(query, "MSSQL adapter does not support keyword or interpolated fragments")
    end

    defp expr({:fragment, _, parts}, sources, query) do
      Enum.map_join(parts, "", fn
        {:raw, part}  -> part
        {:expr, expr} -> expr(expr, sources, query)
      end)
    end

    defp expr({:datetime_add, _, [datetime, count, interval]}, sources, query) do
      "CAST(DATEADD(" <>
        interval <> ", " <> interval_count(count, sources, query) <> ", " <> expr(datetime, sources, query) <>
        ") AS datetime2)"
    end

    defp expr({:date_add, _, [date, count, interval]}, sources, query) do
      "CAST(DATEADD(" <>
        interval <> ", " <> interval_count(count, sources, query) <> ", CAST(" <> expr(date, sources, query) <> " AS datetime2)" <>
        ") AS date)"
    end

    defp expr({fun, _, args}, sources, query) when is_atom(fun) and is_list(args) do
      case handle_call(fun, length(args)) do
        {:binary_op, op} ->
          [left, right] = args
          op_to_binary(left, sources, query) <>
          " #{op} "
          <> op_to_binary(right, sources, query)

        {:fun, fun} ->
          "#{fun}(" <> Enum.map_join(args, ", ", &expr(&1, sources, query)) <> ")"
      end
    end

    defp expr(list, sources, query) when is_list(list) do
      Enum.map_join(list, ", ", &expr(&1, sources, query))
    end

    defp expr(string, _sources, _query) when is_binary(string) do
      hex = string
        |> :unicode.characters_to_binary(:utf8, {:utf16, :little})
        |> Base.encode16(case: :lower)
      "CONVERT(nvarchar(max), 0x#{hex})"
    end

    defp expr(%Decimal{} = decimal, _sources, _query) do
      Decimal.to_string(decimal, :normal)
    end

    defp expr(%Ecto.Query.Tagged{value: binary, type: :binary}, _sources, _query) when is_binary(binary) do
      hex = Base.encode16(binary, case: :lower)
      "0x#{hex}"
    end

    defp expr(%Ecto.Query.Tagged{value: binary, type: :uuid}, _sources, _query) when is_binary(binary) do
      if String.contains?(binary, "-"), do: {:ok, binary} = Ecto.UUID.dump(binary)
      uuid(binary)
    end

    defp expr(%Ecto.Query.Tagged{value: other, type: type}, sources, query) do
      "CAST(#{expr(other, sources, query)} AS #{column_type(type, [])})"
    end

    defp expr(nil, _sources, _query),   do: "NULL"
    defp expr(true, _sources, _query),  do: "1"
    defp expr(false, _sources, _query), do: "0"

    defp expr(literal, _sources, _query) when is_binary(literal) do
      "'#{escape_string(literal)}'"
    end

    defp expr(literal, _sources, _query) when is_integer(literal) do
      String.Chars.Integer.to_string(literal)
    end

    defp expr(literal, _sources, _query) when is_float(literal) do
      String.Chars.Float.to_string(literal)
    end

    defp op_to_binary({op, _, [_, _]} = expr, sources, query) when op in @binary_ops do
      "(" <> expr(expr, sources, query) <> ")"
    end

    defp op_to_binary(expr, sources, query) do
      expr(expr, sources, query)
    end

    defp interval_count(count, _sources, _query) when is_integer(count) do
      String.Chars.Integer.to_string(count)
    end

    defp interval_count(count, _sources, _query) when is_float(count) do
      :erlang.float_to_binary(count, [:compact, decimals: 16])
    end

    defp interval_count(count, sources, query) do
      expr(count, sources, query)
    end

    defp returning([], _verb),
      do: ""
    defp returning(returning, verb) do
      "OUTPUT " <> Enum.map_join(returning, ", ", fn(arg) -> "#{verb}.#{quote_name(arg)}" end) <> " "
    end

    # Brute force find unique name
    # defp unique_name(names, name, counter) do
    #   counted_name = name <> Integer.to_string(counter)
    #   if Enum.any?(names, fn {_, n, _} -> n == counted_name end) do
    #     unique_name(names, name, counter + 1)
    #   else
    #     counted_name
    #   end
    # end

    defp create_names(%{prefix: prefix, sources: sources}) do
      create_names(prefix, sources, 0, tuple_size(sources)) |> List.to_tuple()
    end

    defp create_names(prefix, sources, pos, limit) when pos < limit do
      {table, model} = elem(sources, pos)
      name = String.first(table) <> Integer.to_string(pos)
      [{quote_table(prefix, table), name, model}|
        create_names(prefix, sources, pos + 1, limit)]
    end

    defp create_names(_prefix, _sources, pos, pos) do
      []
    end

    # DDL

    alias Ecto.Migration.Table
    alias Ecto.Migration.Index
    alias Ecto.Migration.Reference

    @drops [:drop, :drop_if_exists]
    @creates [:create, :create_if_not_exists]

    def ddl_exists(%Table{name: name}) do
      "SELECT * FROM information_schema.tables t WHERE t.table_name = '#{escape_string(to_string(name))}'"
    end

    def ddl_exists(%Index{name: name}) do
      "SELECT * FROM sys.indexes i WHERE i.name = '#{escape_string(to_string(name))}'"
    end

    def execute_ddl(_, _ \\ nil)

    def execute_ddl({command, %Table{}=table, columns}, _repo) when command in @creates do
      options = options_expr(table.options)
      unique_columns = Enum.reduce(columns, [], fn({_,name,type,opts}, acc) ->
        if Keyword.get(opts, :unique) != nil, do: List.flatten([{name, type}|acc]), else: acc
      end)
      unique_constraints = unique_columns
        |> Enum.map_join(", ", &unique_expr/1)
      prefix = if command == :create_if_not_exists, do: "IF NOT EXISTS (" <> ddl_exists(table) <> ") BEGIN ", else: ""
      postfix = if command == :create_if_not_exists, do: "END", else: ""
      prefix <>
      "CREATE TABLE #{quote_name(table.name)} (#{column_definitions(table, columns)}" <>
      if length(unique_columns) > 0, do: ", #{unique_constraints})", else: ")" <>
      options <> postfix
    end

    def execute_ddl({command, %Table{name: name} = table}, _repo) when command in @drops do
      prefix = if command == :drop_if_exists, do: "IF EXISTS (" <> ddl_exists(table) <> ") BEGIN ", else: ""
      postfix = if command == :drop_if_exists, do: "END", else: ""
      prefix <> "DROP TABLE #{quote_name(name)}" <> postfix
    end

    def execute_ddl({:alter, %Table{}=table, changes}, _repo) do
      Enum.map_join(changes, "; ", fn(change) ->
        "ALTER TABLE #{quote_name(table.name)} #{column_change(table, change)}"
      end)
    end

    def execute_ddl({:rename, %Table{}=current_table, %Table{}=new_table}, _repo) do
      "EXEC sp_rename '#{current_table.name}', '#{new_table.name}'"
    end

    def execute_ddl({:rename, %Table{}=current_table, current_column, new_column}, _repo) do
      "EXEC sp_rename '#{current_table.name}.#{current_column}', '#{new_column}', 'COLUMN'"
    end

    def execute_ddl({command, %Index{}=index}, repo) when command in @creates do

      filter =
      if (repo.config[:filter_null_on_unique_indexes] == true and index.unique) do
        " WHERE #{Enum.map_join(index.columns, " AND ", fn(column) -> "#{column} IS NOT NULL" end)}"
      else
        ""
      end
      prefix = if command == :create_if_not_exists, do: "IF NOT EXISTS (" <> ddl_exists(index) <> ") BEGIN ", else: ""
      postfix = if command == :create_if_not_exists, do: "END", else: ""
      assemble([prefix, "CREATE#{if index.unique, do: " UNIQUE"} INDEX",
                quote_name(index.name), " ON ", quote_name(index.table),
                " (#{Enum.map_join(index.columns, ", ", &index_expr/1)})",
                filter, postfix])
    end

    def execute_ddl({command, %Index{}=index}, _repo) do
      prefix = if command == :drop_if_exists, do: "IF EXISTS (" <> ddl_exists(index) <> ") BEGIN", else: ""
      postfix = if command == :drop_if_exists, do: "END", else: ""
      assemble([prefix, "DROP INDEX", quote_name(index.name), " ON ", quote_name(index.table), postfix])
    end

    def execute_ddl(default, _repo) when is_binary(default), do: default

    def execute_ddl(keyword, _repo) when is_list(keyword),
      do: error!(nil, "MSSQL adapter does not support keyword lists in execute")

    defp column_definitions(table, columns) do
      Enum.map_join(columns, ", ", &column_definition(table, &1))
    end

    defp column_definition(table, {:add, name, %Reference{} = ref, opts}) do
      assemble([
        quote_name(name), reference_column_type(ref.type, opts), column_options(opts),
        reference_expr(ref, table, name)
      ])
    end

    defp column_definition(_table, {:add, name, type, opts}) do
      assemble([quote_name(name), column_type(type, opts), column_options(opts), serial_expr(type)])
    end

    # defp column_changes(table, columns) do
    #   Enum.map_join(columns, ", ", &column_change(table, &1))
    # end

    defp column_change(table, {:add, name, %Reference{} = ref, opts}) do
      assemble([
        "ADD COLUMN", quote_name(name), reference_column_type(ref.type, opts), column_options(opts),
        reference_expr(ref, table, name)
      ])
    end

    defp column_change(_table, {:add, name, type, opts}) do
      assemble(["ADD", quote_name(name), column_type(type, opts), column_options(opts)])
    end

    defp column_change(table, {:modify, name, %Reference{} = ref, _opts}) do
        constraint_expr(ref, table, name)
    end

    defp column_change(_table, {:modify, name, type, opts}) do
      assemble(["ALTER COLUMN", quote_name(name), column_type(type, opts), column_options(opts)])
    end

    defp column_change(_table, {:remove, name}), do: "DROP COLUMN #{quote_name(name)}"

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
      "CONSTRAINT uc_#{name} UNIQUE (#{quote_name(name)})"
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

    defp options_expr(nil),
      do: ""
    defp options_expr(keyword) when is_list(keyword),
      do: error!(nil, "MSSQL adapter does not support keyword lists in :options")
    defp options_expr(options),
      do: " #{options}"

    # defp column_type(%Reference{} = ref, opts) do
    #   "#{reference_column_type(ref.type, opts)} FOREIGN KEY (opts) REFERENCES " <>
    #   "#{quote_name(ref.table)}(#{quote_name(ref.column)})" <>
    #   reference_on_delete(ref.on_delete)
    # end

    defp column_type({:array, _type}, _opts),
      do: raise "Array column type is not supported for MSSQL"
    defp column_type(:uuid, _opts), do: "uniqueidentifier"
    defp column_type(:binary_id, _opts), do: "uniqueidentifier"
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
        type == :map    -> "nvarchar(max)"
        type == :text   -> "nvarchar(max)"
        type == :binary -> "varbinary(max)"
        type == :boolean -> "bit"
        true            -> "#{type_name}"
      end
    end

    defp reference_expr(%Reference{} = ref, table, name),
      do: "CONSTRAINT #{reference_name(ref, table, name)} FOREIGN KEY (#{name}) " <>
          "REFERENCES #{quote_name(ref.table)}(#{quote_name(ref.column)})" <>
          reference_on_delete(ref.on_delete)

    defp constraint_expr(%Reference{} = ref, table, name),
      do: "ADD CONSTRAINT #{reference_name(ref, table, name)} " <>
          "FOREIGN KEY (#{quote_name(name)}) " <>
          "REFERENCES #{quote_name(ref.table)}(#{quote_name(ref.column)})" <>
          reference_on_delete(ref.on_delete)

    defp reference_name(%Reference{name: nil}, table, column),
      do: quote_name("#{table.name}_#{column}_fkey")
    defp reference_name(%Reference{name: name}, _table, _column),
      do: quote_name(name)

    defp reference_column_type(:serial, _opts), do: "bigint"
    defp reference_column_type(type, opts), do: column_type(type, opts)

    defp reference_on_delete(:nilify_all), do: " ON DELETE SET NULL"
    defp reference_on_delete(:delete_all), do: " ON DELETE CASCADE"
    defp reference_on_delete(_), do: ""

    ## Helpers
    defp quote_table(nil, name),
      do: quote_name(name)

    defp quote_table(prefix, name),
      do: quote_name(prefix) <> "." <> quote_name(name)

    defp quote_name(name) when is_atom(name),
      do: quote_name(Atom.to_string(name))

    defp quote_name(name),
      do: "[#{name}]"

    defp assemble(list) do
      list
      |> List.flatten
      |> Enum.filter(&(&1 != nil))
      |> Enum.join(" ")
    end

    defp escape_string(value) when is_binary(value) do
      :binary.replace(value, "'", "''", [:global])
    end

    defp ecto_to_db(:id),         do: "integer"
    defp ecto_to_db(:binary_id),  do: "uniqueidentifier"
    defp ecto_to_db(:string),     do: "nvarchar"
    defp ecto_to_db(:binary),     do: "varbinary"
    defp ecto_to_db(:datetime),   do: "datetime2"
    defp ecto_to_db(:map),        do: "nvarchar"
    defp ecto_to_db(:boolean),    do: "bit"
    defp ecto_to_db(other),       do: Atom.to_string(other)

    def uuid(<<v1::32, v2::16, v3::16, v4::64>>) do
      <<v1::little-signed-32, v2::little-signed-16, v3::little-signed-16, v4::signed-64>>
    end

    defp error!(nil, message) do
      raise ArgumentError, message
    end

    defp error!(query, message) do
      raise Ecto.QueryError, query: query, message: message
    end
  end
end
