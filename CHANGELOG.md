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