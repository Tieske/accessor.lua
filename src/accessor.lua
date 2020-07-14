---------------------------------------------------------------------------------------
-- Module to access arbitrary depth table keys.
--
-- Example:
--     local t = {
--       some = {
--         arbitrary = {
--           key = "hello world",
--         }
--       }
--     }
--     local key = "some.arbitrary.key"
--     local accessor = Accessor(t)
--     local value = accessor:get("some.arbitrary.key")
--     assert(value == "hello world")
--
-- For each key a function will be generated. The function will be cached so the
-- 2nd lookup will be faster.
--
-- **Warning**:
-- make sure to protect yourself from unlimited cache growth! Check `lua_cache`.
--
-- Design use case: looking up user provided keys in json http bodies. The keys
-- are the same for each request, the bodies different.
--
-- @copyright (c) 2020-2020 Thijs Schreijer
-- @license see [LICENSE file](https://github.com/Tieske/accessor.lua/blob/master/LICENSE)
-- @name accessor.lua
-- @class module


local Accessor = {}
Accessor.__index = Accessor



local BAD_ACCESSOR = "Bad accessor string '%s'; %s"



local function prefix_key(key)
  if key:sub(1,1) ~= "[" and key:sub(1,1) ~= "." then
    return "." .. key
  end
  return key
end

--- Constructor, creates a new accessor object.
-- The options table supports the following fields:
--
-- * `source` (optional, defaults to an empty table)
--   a table in which the keys will be looked up by default by the
--   newly created accessor object
-- * `cache` (optional, defaults to a new `lua_cache` instance)
--   a cache object to store the generated lookup functions, see
--   `lua_cache` for the required interface
-- @param options (optional) options table
-- @return accessor object
function Accessor.new(options)
  options = options or {}
  local self = setmetatable({}, Accessor)

  self.source_table = options.source or {}
  self.cache = options.cache or self.lua_cache()

  return self
end

--- Returns a new table based cache.
-- Minimal cache implementation interface compatible with resty-lru caches.
-- This cache is table based and will allow unlimited growth. If used with
-- OpenResty then use the compatible OpenResty LRU cache when calling `new`.
--
-- A cache should implement the following methods:
--
--     ok = cache:set(key, value)
--     value = cache(key)
--
-- @return a new cache object
function Accessor.lua_cache()
  local my_cache = {}
  return {
    get = function(self, key)
      return my_cache[key]
    end,
    set = function(self, key, value)
      my_cache[key] = value
      return true
    end,
  }
end

--- Returns the source table.
-- This is the table provided as `options.source` to `new`.
-- @return source table
function Accessor:get_source()
  return self.source_table
end


--- Validate a user provided key.
-- Checks whether the key generates a proper function.
-- @param element (string) the key to validate
-- @return `true` or `nil+error`
-- @usage
-- assert(accessor:("this[2].is.valid['as a key'].right"))  -- ok
-- assert(accessor:("this is not"))                         -- fails
function Accessor:validate_key(element)
  if type(element) ~= "string" then
    return nil, "key must be a string"
  end
  local func, err
  -- no sandboxing required, since we're only compiling, and not executing
  if loadstring then -- before Lua 5.2 and LuaJIT
    func, err = loadstring([[return t]] .. prefix_key(element))
  else               -- Lua 5.2 and later
    func, err = load([[return t]] .. prefix_key(element))
  end
  if not func then
    return nil, BAD_ACCESSOR:format(tostring(element), tostring(err))
  end
  return true
end


--- Gets a value from the table.
-- @param element (string) the key to lookup (if not a string, then the return value will be `nil`)
-- @param source_table (optional table, defaults to the `accessor` default table)
-- @return the value or `nil+error`
-- @usage
-- local t = { hello = { world = "tieske" } }
-- local accessor = Accessor({ source = t })
-- print(accessor:get("hello.world"))          --> "tieske"
-- print(t.does_not_exist.world)               --> error!
-- print(accessor:get("does_not_exist.world")) --> "nil, a lookup error"
--
-- local t2 = { hello = { world = "someone" } }
-- print(accessor:get("hello.world", t2))      --> "someone"
--
-- -- NOTE: when doing the lookup in t2, the same 'accessor' is used, which means
-- -- it uses the same functions cache, so the 2nd lookup uses the function generated
-- -- by the first lookup, despite it being used on a different table.
-- -- So there is no need to create accessor objects for each table.
function Accessor:get(element, source_table)
  if type(element) ~= "string" then return end
  local getter = self.cache:get("get:" .. element)
  if not getter then
    local err
    if setfenv then -- Lua before 5.2, and LuaJIT
      getter, err = loadstring([[
        local pcall = pcall
        setfenv(1, {})  -- sandbox this to be a bit safer
        local f = function(t) return t]] .. prefix_key(element) .. [[ end
        return function(source_table)
          local ok, result = pcall(f, source_table)
          if ok then return result end
          return nil, result
        end
      ]],
      "Getter for '" .. element .."'")   -- chunk name for debugging
    else  -- Lua 5.2 and later
      getter, err = load([[
        local f = function(t) return t]] .. prefix_key(element) .. [[ end
        return function(source_table)
          local ok, result = pcall(f, source_table)
          if ok then return result end
          return nil, result
        end
      ]],
      "Getter for '" .. element .."'",  -- chunk name for debugging
      "t",                              -- text only, no binary loading
      { pcall = pcall })                -- almost empty ENV, to sandbox
    end

    if getter then
      getter = getter()
    else
      err = BAD_ACCESSOR:format(tostring(element), tostring(err))
      getter = function() return nil, err end
    end

    self.cache:set("get:" .. element, getter)
  end

  return getter(source_table or self.source_table)
end


--- Creates a proxy table for automatic lookups.
-- A proxy table is a new (empty) table with an `__index` meta-method that will
-- first do a regular lookup in the source table, and if that fails, it will
-- retry with an 'accessor' lookup.
--
-- Because this creates a new proxy table, it will not alter the original
-- metatable or methods (see also `create_index` as an alternative).
--
-- NOTE: where a regular `get` call would return a `nil+error`, this proxy
-- will only return `nil`. This is because the `__index` metamethod only has a
-- single return value, and hence will drop the error string.
-- @param source_table (optional table, defaults to the `accessor` default table)
-- @return a new proxy table
-- @usage
-- local t = { hello = { world = "tieske" } }
-- local p = Accessor({ source = t }):create_proxy()
-- assert(t ~= p)  -- they are different tables
--
-- print("regular: ", p.hello.world)       --> "regular: tieske"
-- print("accessor: ", p["hello.world"]    --> "accessor: tieske"
function Accessor:create_proxy(source_table)
  source_table = source_table or self.source_table
  return setmetatable({}, {
    __index = function(_, key)
      local v = source_table[key]
      if v ~= nil then
        return v
      end
      -- note: __index will not return the 2nd/error return value
      return self:get(key, source_table)
    end,
  })
end


--- Adds an `__index` meta-method for automatic lookups.
-- Returns the source table. The table will have its metatable replaced by a new
-- one with only an `__index` method. So if a lookup fails, it will
-- retry with an 'accessor' lookup.
--
-- This modifies the original table, but is more performant than a proxy table
-- (see `create_proxy` as an alternative).
--
-- NOTE: where a regular `get` call would return a `nil+error`, this table
-- will only return `nil`. This is because the `__index` metamethod only has a
-- single return value, and hence will drop the error string.
-- @param source_table (optional table, defaults to the `accessor` default table)
-- @return the source table, with a new meta-table (existing one will be replaced)
-- @usage
-- local t = { hello = { world = "tieske" } }
-- local p = Accessor({ source = t }):create_proxy()
-- assert(t == p)  -- they are the same tables
--
-- print("regular: ", p.hello.world)       --> "regular: tieske"
-- print("accessor: ", p["hello.world"]    --> "accessor: tieske"
function Accessor:create_index(source_table)
  source_table = source_table or self.source_table
  return setmetatable(source_table, {
    __index = function(_, key)
      -- note: __index will not return the 2nd/error return value
      return self:get(key, source_table)
    end,
  })
end



setmetatable(Accessor, {
  __call = function(self, ...)
    return self.new(...)
  end
})

return Accessor
