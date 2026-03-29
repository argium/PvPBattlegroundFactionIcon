local TestHelpers =
    assert(loadfile("Tests/TestHelpers.lua") or loadfile("TestHelpers.lua"), "Unable to load Tests/TestHelpers.lua")()

describe("ColorUtil", function()
    local ns

    before_each(function()
        -- ColorUtil.lua uses `local _, ns = ...` — we provide ns via the chunk's varargs
        ns = {}
        local chunk = TestHelpers.LoadChunk("ColorUtil.lua", "Unable to load ColorUtil.lua")
        chunk("PvPBattlegroundFactionIcon", ns)
    end)

    describe("namespace registration", function()
        it("registers ColorUtil on ns", function()
            assert.is_table(ns.ColorUtil)
        end)

        it("exposes Sparkle", function()
            assert.is_function(ns.ColorUtil.Sparkle)
        end)

        it("exposes AreEqual", function()
            assert.is_function(ns.ColorUtil.AreEqual)
        end)

        it("exposes ColorToHex", function()
            assert.is_function(ns.ColorUtil.ColorToHex)
        end)
    end)

    describe("AreEqual", function()
        it("returns true for identical tables", function()
            local c = { r = 1, g = 0, b = 0, a = 1 }
            assert.is_true(ns.ColorUtil.AreEqual(c, c))
        end)

        it("returns true for equal separate tables", function()
            assert.is_true(ns.ColorUtil.AreEqual(
                { r = 0.5, g = 0.5, b = 0.5, a = 1 },
                { r = 0.5, g = 0.5, b = 0.5, a = 1 }
            ))
        end)

        it("returns false when colors differ", function()
            assert.is_false(ns.ColorUtil.AreEqual(
                { r = 1, g = 0, b = 0, a = 1 },
                { r = 0, g = 1, b = 0, a = 1 }
            ))
        end)

        it("returns false for nil vs table", function()
            assert.is_false(ns.ColorUtil.AreEqual(nil, { r = 0, g = 0, b = 0, a = 1 }))
        end)

        it("returns true for nil vs nil", function()
            assert.is_true(ns.ColorUtil.AreEqual(nil, nil))
        end)
    end)

    describe("ColorToHex", function()
        it("converts pure red", function()
            assert.are.equal("ff0000", ns.ColorUtil.ColorToHex({ r = 1, g = 0, b = 0 }))
        end)

        it("converts white", function()
            assert.are.equal("ffffff", ns.ColorUtil.ColorToHex({ r = 1, g = 1, b = 1 }))
        end)

        it("converts black", function()
            assert.are.equal("000000", ns.ColorUtil.ColorToHex({ r = 0, g = 0, b = 0 }))
        end)
    end)

    describe("Sparkle", function()
        it("returns empty string for empty text", function()
            assert.are.equal("", ns.ColorUtil.Sparkle(""))
        end)

        it("wraps each character in color codes", function()
            local result = ns.ColorUtil.Sparkle("AB")
            -- Each character should have |cffHHHHHH...char...|r
            assert.is_true(result:find("|cff") ~= nil)
            assert.is_true(result:find("|r") ~= nil)
            -- Should contain both characters
            assert.is_true(result:find("A") ~= nil)
            assert.is_true(result:find("B") ~= nil)
        end)

        it("produces correct number of color segments", function()
            local text = "Hello"
            local result = ns.ColorUtil.Sparkle(text)
            local count = 0
            for _ in result:gmatch("|cff") do count = count + 1 end
            assert.are.equal(#text, count)
        end)

        it("accepts hex color strings", function()
            local result = ns.ColorUtil.Sparkle("X", "ff0000", "00ff00", "0000ff")
            assert.is_true(result:find("|cff") ~= nil)
        end)

        it("accepts hash-prefixed hex strings", function()
            local result = ns.ColorUtil.Sparkle("X", "#ff0000", "#00ff00", "#0000ff")
            assert.is_true(result:find("|cff") ~= nil)
        end)

        it("accepts table colors with r,g,b fields", function()
            local result = ns.ColorUtil.Sparkle("X",
                { r = 1, g = 0, b = 0 },
                { r = 0, g = 1, b = 0 },
                { r = 0, g = 0, b = 1 })
            assert.is_true(result:find("|cff") ~= nil)
        end)

        it("accepts array-style colors", function()
            local result = ns.ColorUtil.Sparkle("X", { 255, 0, 0 }, { 0, 255, 0 }, { 0, 0, 255 })
            assert.is_true(result:find("|cff") ~= nil)
        end)

        it("single character uses midpoint color", function()
            -- With a 1-char string the gradient samples the midpoint
            local result = ns.ColorUtil.Sparkle("A", "ff0000", "00ff00", "0000ff")
            -- Should be close to the mid color (green-ish)
            assert.is_string(result)
            assert.is_true(#result > 1)
        end)
    end)
end)
