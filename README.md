# Tds.Ecto

MSSQL / TDS Adapter for Ecto

## Example
```elixir
# In your config/config.exs file
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
  use Ecto.Model

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

## Usage

Add Tds as a dependency in your `mix.exs` file.

```elixir
def deps do
  [{:tds_ecto, "~> 0.1"}]
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

For additional information on usage please see the documentation for [Ecto](http://hexdocs.pm/ecto).

## Data Type Mapping

	MSSQL             	Ecto
	----------        	------
	nvarchar          	:string
	varchar			  	:binary
	char              	:binary
	varbinary		  	:binary
	float             	:float
	decimal           	:decimal
	integer 		  	:integer
	bit 			  	:boolean
	uniqueidentifier  	:uuid
	datetime		  	:datetime
	date			  	:date
	time 			  	:time


## Contributing

To contribute you need to compile Tds from source and test it:

```
$ git clone https://github.com/livehelpnow/tds_ecto.git
$ cd tds_ecto
$ mix test
```

The tests require an addition to your hosts file to connect to your sql server database.

<IP OF SQL SERVER>	mssql.local

Additionally SQL authentication needs to be used for connecting and testing. Add the user `test_user` with access to the database `test_db`. See one of the test files for the connection information and port number.

## License

   Copyright 2014 LiveHelpNow

   Licensed under the Apache License, Version 2.0 (the "License");
   you may not use this file except in compliance with the License.
   You may obtain a copy of the License at

       http://www.apache.org/licenses/LICENSE-2.0

   Unless required by applicable law or agreed to in writing, software
   distributed under the License is distributed on an "AS IS" BASIS,
   WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
   See the License for the specific language governing permissions and
   limitations under the License.
