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
