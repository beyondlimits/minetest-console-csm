# minetest-console-csm

Minetest mod which transforms chat window into [REPL](https://en.wikipedia.org/wiki/Read%E2%80%93eval%E2%80%93print_loop).

For convenience, these variables are available in the scope of the REPL:

- `_` - last result
- `_e` - last error

Additionally, these tables are imported:

- `string`
- `table`
- `math`
- `minetest`

There are helper functions available:

- `hint(table, pattern)` - Returns a table with all keys of `table` matching `pattern` (same format as in `string.find`). If `table` is omitted, it searches within all imported tables.
- `clear()` - Clears the chat window (by spamming a lot of empty lines).
- `echo(message)` - Sends message to the player (alias of `display_chat_message`).
- `load(name)` - Loads a script from the `scripts` directory into function. Extension `.lua` is added automatically. The arguments passed to the returned function are obtained via `...` (e.g. `local x, y, z = ...`) within a script. Convenience variables and imported tables apply to scripts as well.
- `run(name, arg1, arg2, ...)` - Equivalent to `load(name)(arg1, arg2, ...)`. Arguments are of course optional.
- `count(table)` - Returns the number of elements in `table`. The function was added since neither `#` nor `table.getn` work properly with associative tables.
- `keys(table)` - Returns all keys of `table`. Resulting table is numerically indexed.
- `values(table)` - Returns all values of `table`. Resulting table is numerically indexed.
- `extend(table, other, ...)` - Merges one or more tables into `table` and returns `table`. To return new table instead of modifying, use it like `extend({}, table, other, ...)`.
- `filter(table, callback)` - For every element of `table` calls `callback(value, key)` and returns only elements for which `callback` returns `true` or true-like value.
- `pack(...)` - Packs provided arguments into table. Resulting table contains key `n` which is the number of provided arguments. Supposed to be equivalent of `table.pack` in Lua >= 5.2.

These variables can be set to adjust display of tables:
- `indent_size` - Indent size in spaces. When not set, defaults to `4`.
- `max_depth` - Maximum depth of nested tables. When this limit is hit, REPL displays `table` instead of table contents. When not set, defaults to `1`.

REPL is toggled using `.console` command.
