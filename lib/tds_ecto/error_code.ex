defmodule Tds.Ecto.ErrorCode do
  @external_resource errcodes_path = Path.join(__DIR__, "errorcodes.txt")

  errcodes =
    for line <- File.stream!(errcodes_path) do
      [type, code, regex] = String.split(line, ",", trim: true)
      type = String.to_atom(type)
      code = code |> String.trim()
      regex = String.replace_trailing(regex, "\n", "")

      if code == nil do
        raise CompileError, "Error code must be integer value"
      end

      {code, {type, regex}}
    end

  Enum.group_by(errcodes, &elem(&1, 0), &elem(&1, 1))
  |> Enum.map(fn {code, type_regexes} ->
    {error_code, ""} = Integer.parse(code)

    def get_constraint_violations(unquote(error_code), message) do
      constraint_checks =
        Enum.map(unquote(type_regexes), fn {key, val} ->
          {key, Regex.compile!(val)}
        end)

      extract = fn {key, test}, acc ->
        concatenate_match = fn [match], acc -> [{key, match} | acc] end

        case Regex.scan(test, message, capture: :all_but_first) do
          [] -> acc
          matches -> Enum.reduce(matches, acc, concatenate_match)
        end
      end

      Enum.reduce(constraint_checks, [], extract)
    end
  end)

  def get_constraint_violations(_, _) do
    []
  end
end
