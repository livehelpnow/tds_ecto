#v2.2.1
* Fixing transaction handling (ecto cast_assoc rollsback twice if more than one rpc call is executed in single transaction/change/assoc)

#v2.2.0
## Breaking Changes
UUID/UNIQUEIDENTIFER column is now stored AS IS in database, meaning that compatibility with Ecto.UUID is broken, 
if you are using `tds_ecto` please use Tds.UUID to encode/decode value to its sting representation. MSSQL has its way of 
parsing binary UUID value into string representation as following string illustration:

  Ecto.UUID string representation:
  `f72f71ce-ee18-4db3-74d9-f5662a7691b8`

  MSSQL string representation:
  `ce712ff7-18ee-b34d-74d9-f5662a7691b8`

To allow other platforms to interprect corectly uuids we had to introduce 
`Tds.UUID` in `tds_ecto` library and `Tds.Types.UUID` in `tds` both are trying to 
keep binary storage in valid byte order so each platform can corectly decode it into string.
So far unique identifiers were and will be returned in resultset as binary, if you need to convert it into 
formatted string, use `Tds.Types.UUID.parse(<<_::128>>=uuid)` to get that string. 
It is safe to call this function several times since it will not fail if value is valid uuid string,
it will just return same value. But if value do not match `<<_::128>>` or 
`<<a::32, ?-, b::16, ?-, c::16, ?- d::16, ?-, e::48>>` it will throw runtime error. 

If you are using `tds_ecto` :uuid, :binary_id, and Tds.UUID are types you want to use in your models.
For any of those 3 types auto encode/decode will be performed.

Since there was a bug where in some cases old version of `tds_ecto` library 
could not detemine if binary is of uuid type, it interpeted such values as raw binary which caused some issues when non elixir apps interpreted that binary in wrong string format. This was ok as long as parsed string values were not shared between elixir and other platforms trough e.g. json messages, but if they did, this could be a problem where other app is not kapable to find object which missparsed uuid value.

#v2.1.0
* Introducing Tds.VarChar type, use in migration `:varchar` as field type and in schema `Tds.VarChar` as field type.

# v2.0.7
* fixing issue when inserting data with decimal columns see issue #57

# v2.0.3 (v2.0.2)
* Fixing failed test when schemaless query is executed without specified columns in projection

# v1.0.6 (v1.0.2)
* Integrated upstream changes
* Add default expression to alter tables too.

# v1.0.4 (v1.0.2)
* Integrated upstream changes

# v1.0.3
* Bug fixes
  * Rollbacks for columns with defaults is now working.
  * Forwards for columns with defaults is now working.

# v1.0.2
* Bug Fixes
  * fixed limit

# v1.0.1
* Bug Fixes
  * Allow prefixes in DDL
  * Fixed issue when using `count` and `distinct`
  * Better constraint matching
  * Fixed boolean literals in where clauses

# v1.0.0
* Enhancements
  * Updated to ecto 1.0.0

# v0.6.0
* Enhancements
  * Updated to ecto 0.16.0

# v0.5.0
* Enhancements
  * Updated to ecto 0.15.0

# v0.4.0
* Enhancements
  * Updated to ecto 0.14.1

# v0.3.2
* Enhancements
  * Lock down tds

# v0.3.1
* Enhancements
  * Updated tds to 0.4.0

# v0.3.0
* Enhancements
  * Updated to ecto 0.13.0


# v0.2.5
* Enhancements
  * Updated Ecto to 0.12.1
  * Added support for map type
  * Added support for binary_id

# v0.2.4
* Enhancements
  * Updated Ecto to 0.11

# v0.2.3
* Bug Fixes
  * Changed tablename quoting to allow for schema

# v0.2.2
* Enhancements
  * Updated Ecto version

# v0.2.1
* Bug Fixes
  * Use datetime2 when time struct usec > 0

# v0.2.0
* Bug Fixes
  * Parsing null uuid's would break String check
  * Allow references to be set for other primary key types
  * Allow distincts on booleans

# v0.1.5
* Bug Fixes
  * Ecto.UUID tagged types were failing to be type checked in tds

* Enhancements
  * Added support for UNIQUE in column definitions

# v0.1.4
* Bug Fixes
  * Added :tds to application list

# v0.1.3
* Bug Fixes
  * Fixing deps issue with Hex

# v0.1.2
* Bug Fixes
  * Added lock to join/2

# v0.1.1
* Bug Fixes
  * Fixed limit: to map TOP in SELECT

# v0.1.0 (2015-02-13)
* Enhancements
  * Updated Deps


# v0.0.1 (2015-02-12)
* First Release
