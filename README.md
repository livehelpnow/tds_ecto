# Tds.Ecto (Ecto v2)

MSSQL / TDS Adapter for Ecto2

[![Build Status][appveyor-img]][appveyor] [![Hex Version][hex-img]][hex]

[appveyor-img]: https://ci.appveyor.com/api/projects/status/g59ocaellinuig7g?svg=true
[appveyor]: https://ci.appveyor.com/project/mjaric/tds-ecto-jpd3h
[hex-img]: https://img.shields.io/hexpm/v/tds_ecto.svg
[hex]: https://hex.pm/packages/tds_ecto

## Example
```elixir
# In your config/config.exs file add MSSQL connection options
# By default it use port 1433, different port can be specified with
# port: 1434
# option and named instance with
# instance: "instance_name"
config :my_app, Repo,
  database: "ecto_simple",
  username: "mssql",
  password: "mssql",
  hostname: "localhost"

# In your application code
defmodule Repo do
  use Ecto.Repo,
    otp_app: :my_app,
    adapter: Tds.Ecto
end

defmodule Weather do
  use Ecto.Schema

  schema "weather" do
    field :city     # Defaults to type :string
    field :temp_lo, :integer
    field :temp_hi, :integer
    field :prcp,    :float, default: 0.0
  end
end

defmodule Simple do
  import Ecto.Query

  def sample_query do
    query = from w in Weather,
          where: w.prcp > 0 or is_nil(w.prcp),
         select: w
    Repo.all(query)
  end
end
```

Also, if you need to map table to schema other than [dbo], simple use @schema_prefix "your_schema", eg:

```
defmodule Invoices.Invoice do
  use Ecto.Schema

  @schema_prefix :invoices
  schema "invoices" do
    field :due_date, :datetime
    field :sum, :float
  end
end
```

## Usage

Add Tds as a dependency in your `mix.exs` file.

```elixir
def deps do
  [{:tds_ecto, "~> 2.2"}]
end
```

You should also update your applications list to include both projects:
```elixir
def application do
  [applications: [:logger, :tds_ecto, :ecto]]
end
```

To use the adapter in your repo:
```elixir
defmodule MyApp.Repo do
  use Ecto.Repo,
    otp_app: :my_app,
    adapter: Tds.Ecto
end
```

tds_ecto relies on pattern matching against error messages to extract constraint names.
If your SQL server is not configured to English as its default language you may add an `after_connect` hook to your repo and set English as the language for Ecto connections.

```elixir
def after_connect(conn) do
  Tds.Ecto.Connection.query(conn, "SET LANGUAGE English", [], [])
end
```

For additional information on usage please see the documentation for [Ecto](http://hexdocs.pm/ecto).

## Data Type Mapping

    MSSQL             	Ecto/Tds.Ecto
    ----------        	------
    nvarchar            :string
    varchar             Tds.VarChar
    char                :binary
    varbinary           :binary
    float               :float
    decimal             :decimal
    integer             :integer
    bit                 :boolean
    uniqueidentifier    :uuid
    datetime            :datetime
    date                :date
    time                :time



## Contributing

To contribute you need to compile Tds from source and test it:

```
$ git clone https://github.com/livehelpnow/tds_ecto.git
$ cd tds_ecto
$ mix test
```

Tests will try to connect to `localhost` using `sa` as username with predefined password `mssql`, but you can set environment variables to override any, like so: `SQL_USERNAME=myuser; SQL_PASSWORD=mypassword; SQL_HOSTNAME=sqlserver.local; mix test` or if you are using windows then `SET SQL_USERNAME=myuser && SET SQL_PASSWORD=mypassword && SET SQL_HOSTNAME=sqlserver.local && mix test`. Please note that tests will run againes default sql server instance.

Additionally SQL authentication needs to be used for connecting and testing.If you override default test settings, make sure either that yor user has sysadmin privilegies to add the user `test_user` with access to the database `test_db`, or simply add manualy test_user on your server. See one of the test files for the connection information and port number.

## License

   Copyright 2014, 2015, 2016, 2017 LiveHelpNow

   Licensed under the Apache License, Version 2.0 (the "License");
   you may not use this file except in compliance with the License.
   You may obtain a copy of the License at

       http://www.apache.org/licenses/LICENSE-2.0

   Unless required by applicable law or agreed to in writing, software
   distributed under the License is distributed on an "AS IS" BASIS,
   WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
   See the License for the specific language governing permissions and
   limitations under the License.
