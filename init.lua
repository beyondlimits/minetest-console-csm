local modname = minetest.get_current_modname()

local color                = minetest.get_color_escape_sequence
local colorize             = minetest.colorize
local concat               = table.concat
local display_chat_message = minetest.display_chat_message
local dump                 = dump
local error                = error
local find                 = string.find
local format               = string.format
local getmetatable         = getmetatable
local insert               = table.insert
local ipairs               = ipairs
local loadfile             = loadfile
local loadstirng           = loadstring
local pairs                = pairs
local pcall                = pcall
local rep                  = string.rep
local select               = select
local setfenv              = setfenv -- TODO: polyfill for Lua >= 5.1
local sort                 = table.sort
local tonumber             = tonumber
local type                 = type

local mode = false
local indent_size
local max_depth
local sb

local handlers = {}
local bucket_order = {'boolean', 'number', 'string'}

local color_unknown   = color('#C99')
local color_nil       = color('#CCC')
local color_boolean   = color('#9CF')
local color_number    = color('#FF9')
local color_string    = color('#9FF')
local color_function  = color('#9F9')
local color_thread    = color('#9FC')
local color_table     = color('#99F')
local color_metatable = color('#FC9')
local color_muted     = color('#999')
local color_userdata  = color('#F99')

local check_metatable
local dump_userdata

if getmetatable then
	function check_metatable(value)
		if getmetatable(value) ~= nil then
			insert(sb, color_metatable)
			insert(sb, ' contains metatable')
		end
	end
else
	function check_metatable()
		-- no operation
	end
end


local function dump_value(depth, value, full)
	local t = type(value)
	if handlers[t] == nil then
		insert(sb, color_unknown)
		insert(sb, t)
	else
		return handlers[t](depth, value, full)
	end
end

local function dump_nil(depth, value)
	insert(sb, color_nil)
	insert(sb, 'nil')
end;

local function dump_boolean(depth, value)
	insert(sb, color_boolean)
	insert(sb, dump(value))
end

local function dump_number(depth, value)
	insert(sb, color_number)
	insert(sb, dump(value))
end

local function dump_string(depth, value)
	insert(sb, color_string)
	insert(sb, dump(value))
end

local function dump_function(depth, value)
	insert(sb, color_function)
	insert(sb, 'function')
end

local function dump_thread(depth, value)
	insert(sb, color_thread)
	insert(sb, 'thread')
end

local function dump_table_elements(depth, indent, value, keys)
	for k, v in pairs(keys) do
		insert(sb, indent)
		dump_value(depth, v, false)
		insert(sb, color_muted)
		insert(sb, ' = ')
		dump_value(depth, value[v], true)
		insert(sb, '\n')
	end
end

local function dump_table_expanded(depth, value)
	local indent = rep(' ', depth * indent_size)
	local buckets = {}
	local keys = {}

	for k, v in pairs(bucket_order) do
		buckets[v] = {}
	end

	for k, v in pairs(value) do
		insert(buckets[type(k)] or keys, k)
	end

	for k, v in pairs(buckets) do
		sort(v)
	end

	insert(sb, color_table)
	insert(sb, '{')
	check_metatable(value)
	insert(sb, '\n')

	for k, v in pairs(bucket_order) do
		dump_table_elements(depth, indent, value, buckets[v])
	end

	dump_table_elements(depth, indent, value, keys)

	insert(sb, rep(' ', (depth - 1) * indent_size))
	insert(sb, color_table)
	insert(sb, '}')
end

local function dump_table(depth, value, full)
	if full and depth < max_depth then
		dump_table_expanded(depth + 1, value)
	else
		insert(sb, color_table)
		insert(sb, 'table')
		check_metatable(value)
	end
end

if getmetatable then
	function dump_userdata(depth, value, full)
		insert(sb, color_userdata)
		insert(sb, 'userdata ')

		if full and depth < max_depth then
			dump_table_expanded(depth + 1, getmetatable(value))
		end
	end
else
	function dump_userdata()
		insert(sb, color_userdata)
		insert(sb, 'userdata')
	end
end

handlers['nil']      = dump_nil
handlers.boolean     = dump_boolean
handlers.number      = dump_number
handlers.string      = dump_string
handlers.userdata    = dump_userdata
handlers['function'] = dump_function
handlers.thread      = dump_thread
handlers.table       = dump_table

-- for clearing chat window
local bunch_of_lfs = string.rep('\n', 500)

-- table.extend
local function extend(table, other, ...)
	if other == nil then
		return table
	end
	for k, v in pairs(other) do
		table[k] = v
	end
	return extend(table, ...)
end

-- table.pack
-- TODO: may conflict with Lua >= 5.1
local function pack(...)
	return {n = select('#', ...), ...}
end

local common = {
	-- Clears the chat window
	clear = function()
		display_chat_message(bunch_of_lfs)
	end,

	-- table.count
	count = function(table)
		local n = 0
		for k, v in pairs(table) do
			n = n + 1
		end
		return n
	end,

	echo = display_chat_message,

	-- table.extend
	extend = extend,

	-- table.filter
	filter = function(table, callback)
		local t = {}
		for k, v in pairs(table) do
			if callback(v, k) then
				t[k] = v
			end
		end
		return result
	end,

	-- table.keys
	keys = function(table)
		local t = {}
		for k, v in pairs(table) do
			insert(t, k)
		end
		return t
	end,

	-- table.pack
	pack = pack,

	-- table.values
	values = function(table)
		local t = {}
		for k, v in pairs(table) do
			insert(t, v)
		end
		return t
	end,
}

-- imports to allow using set_node, sin, write etc.
-- without the need to reference table directly.
-- TODO: optimize access?
local imports = {
	common,
	_G,
	string,
	table,
	math,
	minetest,
}

-- player environment
local env = setmetatable({}, {
	-- function for import resolution
	__index = function(table, index)
		local result

		for i, import in ipairs(imports) do
			local result = import[index]
			if result ~= nil then
				return result
			end
		end
	end
})

-- Returns a table with all keys of given table
-- matching the given pattern. If no table provided,
-- it searches for keys in all imports.
function common.hint(table, pattern)
	local result = {}
	if pattern == nil then
		pattern = table
		table = {}
		for i, import in ipairs(imports) do
			for key, value in pairs(import) do
				if find(key, pattern) then
					table[key] = value
				end
			end
		end
		for key, value in pairs(table) do
			insert(result, key)
		end
	else
		if type(table) ~= 'table' then
			error('Table expected')
		end
		for key, value in pairs(table) do
			if find(key, pattern) then
				insert(result, key)
			end
		end
	end
	sort(result)
	return result
end

-- Loads a script into the function with env being the player env
local function load(name)
	local result, err = loadfile(modname .. ':scripts/' .. name .. '.lua')

	if err then
		error(err)
	end

	return setfenv(result, env)
end

common.load = load

-- Runs a script from scripts directory, using load function above
function common.run(name, ...)
	return load(name)(...)
end

minetest.register_chatcommand('console', {
	params = '',
	description = 'Toggle console mode',
	func = function()
		mode = not mode
		return true, format('Console mode is now %s.', mode and 'enabled' or 'disabled')
	end
})

local register_on_sending_chat_message =
	minetest.register_on_sending_chat_message
		or minetest.register_on_sending_chat_messages

register_on_sending_chat_message(function(message)
	if not mode then
		return
	end

	display_chat_message(']' .. message)

	-- try with "return" first to obtain value returned
	-- (e.g. player enters "me:getpos()")
	local f, err = loadstring('return ' .. message)

	if f == nil then
		-- likely a syntax error - try again without 'return' keyword
		-- (e.g. player enters "for k, v in ...")
		f, err = loadstring(message)
	end

	if f == nil then
		-- it was real error then
		display_chat_message(colorize('#F93', err))
		return true
	end

	f = pack(pcall(setfenv(f, env)))

	indent_size = tonumber(env.indent_size) or 4
	max_depth = tonumber(env.max_depth) or 1

	local result = {}

	for i = 2, f.n do
		sb = {}
		dump_value(0, f[i], true)
		result[i - 1] = concat(sb)
	end

	sb = nil

	result = concat(result, colorize('#999', ', '));

	if f[1] then
		env._ = f[2] -- last result
		display_chat_message(result)
	else
		env._e = f[2]
		display_chat_message(colorize('#F93', 'ERROR: ' .. result))
	end

	return true
end)
