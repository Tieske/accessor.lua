local Accessor = require("accessor")


describe("Accessor class", function()

  describe("'new'", function()

    it("creates an instance", function()
      assert.equal(Accessor, getmetatable(Accessor.new()))
    end)
    it("has a short call on the module table", function()
      assert.equal(Accessor, getmetatable(Accessor()))
    end)
  end)


  describe("'get_source'", function()
    local source = {}
    local accessor = Accessor.new({source = source})

    it("returns source", function()
      assert.equal(source, accessor:get_source())
    end)
  end)


  describe("'validate_key'", function()
    local accessor = Accessor()

    it("properly prefixes keys", function()
      assert.is_true(accessor:validate_key("hello.world"))
      assert.is_true(accessor:validate_key(".hello.world"))
    end)
    it("properly prefixes bracketed keys", function()
      assert.is_true(accessor:validate_key("[1][2]"))
    end)
    it("returns nil+err on non-string keys", function()
      local v, err = accessor:validate_key(true)
      assert.is_nil(v)
      assert.equal("key must be a string", err)
    end)
    it("returns nil+error on a key-compile error", function()
      local v, err = accessor:validate_key("'Hello world'['end of the world']")
      assert.is_nil(v)
      assert.matches("^Bad accessor string '", err)
    end)

  end)


  describe("'get'", function()
    local source = {
      hello = {
        world = "tieske",
      },
      [1] = {
        [2] = 3,
      },
      ["Hello world"] = {
        ["end of the world"] = "Not today",
      }
    }
    local accessor = Accessor({source = source})

    it("properly prefixes keys", function()
      assert.equal("tieske", accessor:get("hello.world"))
      assert.equal("tieske", accessor:get(".hello.world"))
    end)
    it("properly prefixes bracketed keys", function()
      assert.equal(3, accessor:get("[1][2]"))
      assert.equal("Not today", accessor:get("['Hello world']['end of the world']"))
    end)
    it("returns nil on non-string keys", function()
      local v, err = accessor:get(true)
      assert.is_nil(v)
      assert.is_nil(err)
    end)
    it("returns nil non-existing sub-key", function()
      local v, err = accessor:get("[1][3]")
      assert.is_nil(v)
      assert.is_nil(err)
    end)
    it("returns nil+error on a key-compile error", function()
      local v, err = accessor:get("'Hello world'['end of the world']")
      assert.is_nil(v)
      assert.matches("^Bad accessor string '", err)
    end)
    it("returns nil+error on a injected code error", function()
      local v, err = accessor:get("a - (function() return hello_sucker * 1 end)()")
      assert.is_nil(v)
      assert.matches("hello_sucker", err)
    end)
    it("returns nil+error on indexing a non-table value", function()
      local v, err = accessor:get("[1][2][3]")
      assert.is_nil(v)
      assert.matches("attempt to index", err)
    end)
    it("looks up in the optional table if provided", function()
      assert.equal("tieske", accessor:get("by.world", { by = { world = "tieske" } }))
    end)

  end)


  describe("'create_proxy'", function()
    local source = {
      hello = {
        world = "tieske",
      },
    }
    local accessor = Accessor({source = source})
    local proxy = accessor:create_proxy()

    it("allows plain and accessor access", function()
      assert.equal("tieske", proxy.hello.world)
      assert.equal("tieske", proxy["hello.world"])
    end)
    it("creates a proxy table", function()
      assert.Not.equal(accessor:get_source(), proxy)
    end)
    it("uses optional source table if provided", function()
      local proxy2 = accessor:create_proxy({
        hello = {
          world = "not tieske",
        },
      })
      assert.equal("not tieske", proxy2.hello.world)
      assert.equal("not tieske", proxy2["hello.world"])
    end)

  end)


  describe("'create_index'", function()
    local source = {
      hello = {
        world = "tieske",
      },
    }
    local accessor = Accessor({source = source})
    local index = accessor:create_index()

    it("allows plain and accessor access", function()
      assert.equal("tieske", index.hello.world)
      assert.equal("tieske", index["hello.world"])
    end)
    it("modifies the source table", function()
      assert.equal(accessor:get_source(), index)
    end)
    it("uses optional source table if provided", function()
      local index2 = accessor:create_index({
        hello = {
          world = "not tieske",
        },
      })
      assert.equal("not tieske", index2.hello.world)
      assert.equal("not tieske", index2["hello.world"])
    end)

  end)

end)

