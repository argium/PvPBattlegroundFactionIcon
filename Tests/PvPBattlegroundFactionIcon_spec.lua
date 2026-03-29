local TestHelpers =
    assert(loadfile("Tests/TestHelpers.lua") or loadfile("TestHelpers.lua"), "Unable to load Tests/TestHelpers.lua")()

describe("PvPBattlegroundFactionIcon", function()
    local originalGlobals
    local createdFrames
    local printedMessages

    -- Minimal stubs for WoW APIs the addon touches at load time
    local function setupWoWStubs(options)
        options = options or {}
        createdFrames = TestHelpers.SetupCreateFrame()
        TestHelpers.SetupLibStub()
        printedMessages = {}

        -- LibEditMode stub
        local libEditModeFrames = {}
        local libEditModeSettings = {}
        local libEditModeCallbacks = {}
        local LibEditMode = {
            SettingType = { Slider = 0, Checkbox = 1 },
            _frames = libEditModeFrames,
            _settings = libEditModeSettings,
            _callbacks = libEditModeCallbacks,
        }
        local activeLayout = options.activeLayout or "Modern"
        local isInEditMode = false
        function LibEditMode:GetActiveLayoutName() return activeLayout end
        function LibEditMode:IsInEditMode() return isInEditMode end
        function LibEditMode:SetEditMode(value) isInEditMode = not not value end
        function LibEditMode:AddFrame(frame, cb, default, name)
            self._frames[#self._frames + 1] = { frame = frame, callback = cb, default = default, name = name }
        end
        function LibEditMode:AddFrameSettings(frame, settings)
            self._settings[frame] = settings
        end
        function LibEditMode:RegisterCallback(event, cb)
            self._callbacks[event] = self._callbacks[event] or {}
            self._callbacks[event][#self._callbacks[event] + 1] = cb
        end

        -- Make LibStub return it
        local origLibStub = _G.LibStub
        _G.LibStub = function(name)
            if name == "LibEditMode" then return LibEditMode end
            return origLibStub(name)
        end

        -- WoW globals
        _G.UIParent = { GetSize = function() return 1920, 1080 end }
        _G.IsInInstance = function() return false, "none" end
        _G.GetBattlefieldArenaFaction = function() return nil end
        _G.UnitFactionGroup = function() return "Horde" end
        _G.C_EditMode = {
            GetLayouts = function()
                return {
                    layouts = options.layouts or {},
                }
            end,
        }
        _G.C_Timer = { After = function(_, fn) fn() end }
        _G.InCombatLockdown = function() return false end
        _G.SOUNDKIT = { IG_MAINMENU_OPTION_CHECKBOX_ON = 1 }
        _G.EditModeManagerFrame = nil
        _G.SlashCmdList = _G.SlashCmdList or {}
        _G.PvPBattlegroundFactionIconDB = options.savedVariables
        _G.print = function(...)
            local parts = {}
            for i = 1, select("#", ...) do
                parts[i] = tostring(select(i, ...))
            end
            printedMessages[#printedMessages + 1] = table.concat(parts, " ")
        end

        return LibEditMode
    end

    local function loadAddon()
        local ns = {}
        local colorChunk = TestHelpers.LoadChunk("ColorUtil.lua")
        colorChunk("PvPBattlegroundFactionIcon", ns)

        local mainChunk = TestHelpers.LoadChunk("PvPBattlegroundFactionIcon.lua")
        mainChunk("PvPBattlegroundFactionIcon", ns)
    end

    local function fireEvent(eventName, ...)
        for i = #createdFrames, 1, -1 do
            local f = createdFrames[i]
            if f._events[eventName] and f._scripts["OnEvent"] then
                f._scripts["OnEvent"](f, eventName, ...)
                break
            end
        end
    end

    local function bootAddon(options)
        local LibEditMode = setupWoWStubs(options)
        loadAddon()
        fireEvent("ADDON_LOADED", "PvPBattlegroundFactionIcon")
        return LibEditMode
    end

    local function getRegisteredSettings(libEditMode)
        for _, settings in pairs(libEditMode._settings) do
            return settings
        end
    end

    local function getCreatedFrameByName(name)
        for _, f in ipairs(createdFrames) do
            if f._name == name then
                return f
            end
        end
    end

    setup(function()
        originalGlobals = TestHelpers.CaptureGlobals({
            "CreateFrame", "LibStub", "UIParent", "IsInInstance",
            "GetBattlefieldArenaFaction", "UnitFactionGroup", "C_EditMode", "C_Timer",
            "InCombatLockdown", "SOUNDKIT", "EditModeManagerFrame",
            "SlashCmdList", "PvPBattlegroundFactionIconDB", "print",
            "SLASH_PBFI1",
        })
    end)

    teardown(function()
        TestHelpers.RestoreGlobals(originalGlobals)
    end)

    describe("fresh install (no saved variables)", function()
        local LibEditMode

        before_each(function()
            LibEditMode = bootAddon()
        end)

        it("initializes DB with layouts table", function()
            assert.is_table(_G.PvPBattlegroundFactionIconDB)
            assert.is_table(_G.PvPBattlegroundFactionIconDB.layouts)
        end)

        it("sets debug to false", function()
            assert.is_false(_G.PvPBattlegroundFactionIconDB.debug)
        end)

        it("registers frame with LibEditMode", function()
            assert.are.equal(1, #LibEditMode._frames)
            assert.are.equal("PvP Faction Icon", LibEditMode._frames[1].name)
        end)

        it("registers slider and checkbox settings", function()
            local settings = getRegisteredSettings(LibEditMode)
            assert.is_table(settings)
            assert.are.equal(2, #settings)
            assert.are.equal("Size", settings[1].name)
            assert.are.equal("Show Border", settings[2].name)
        end)

        it("anchors the frame even before layout callbacks run", function()
            local addonFrame = getCreatedFrameByName("FactionIconFrame")
            assert.is_table(addonFrame._points[1])
            assert.are.equal("CENTER", addonFrame._points[1].point)
        end)
    end)

    describe("legacy migration", function()
        it("migrates root-level size and position into all known layouts", function()
            bootAddon({
                activeLayout = "Personal (PVP)",
                layouts = {
                    { layoutName = "Personal (PVP)" },
                    { layoutName = "Battlegrounds" },
                },
                savedVariables = {
                    size = 64,
                    position = { point = "TOPLEFT", x = 100, y = -50 },
                    debug = true,
                },
            })

            local db = _G.PvPBattlegroundFactionIconDB
            assert.is_nil(db.size)
            assert.is_nil(db.position)
            assert.is_true(db.debug) -- preserved at root

            assert.is_table(db.layouts.Modern)
            assert.are.equal(64, db.layouts.Modern.squareSize)
            assert.are.equal("TOPLEFT", db.layouts.Modern.position.point)
            assert.are.equal(100, db.layouts.Modern.position.x)

            assert.is_table(db.layouts.Classic)
            assert.are.equal(64, db.layouts.Classic.squareSize)

            assert.is_table(db.layouts["Personal (PVP)"])
            assert.are.equal("TOPLEFT", db.layouts["Personal (PVP)"].position.point)
            assert.are.equal(-50, db.layouts["Personal (PVP)"].position.y)

            assert.is_table(db.layouts["Battlegrounds"])
            assert.are.equal(64, db.layouts["Battlegrounds"].squareSize)
        end)

        it("handles missing position gracefully", function()
            bootAddon({
                savedVariables = { size = 32 },
            })

            local db = _G.PvPBattlegroundFactionIconDB
            assert.are.equal(32, db.layouts.Modern.squareSize)
            assert.is_nil(db.layouts.Modern.position)
        end)

        it("backfills missing fields for partially migrated custom layouts", function()
            bootAddon({
                activeLayout = "Personal (PVP)",
                layouts = {
                    { layoutName = "Personal (PVP)" },
                },
                savedVariables = {
                    size = 64,
                    position = { point = "TOPLEFT", x = 100, y = -50 },
                    layouts = {
                        ["Personal (PVP)"] = {},
                    },
                },
            })

            local layout = _G.PvPBattlegroundFactionIconDB.layouts["Personal (PVP)"]
            assert.are.equal(64, layout.squareSize)
            assert.is_true(layout.showBorder)
            assert.are.equal("TOPLEFT", layout.position.point)
            assert.are.equal(100, layout.position.x)
            assert.are.equal(-50, layout.position.y)
        end)

        it("does not overwrite existing layout data", function()
            bootAddon({
                savedVariables = {
                    size = 64,
                    layouts = {
                        Modern = { squareSize = 80, showBorder = false },
                    },
                },
            })

            assert.are.equal(80, _G.PvPBattlegroundFactionIconDB.layouts.Modern.squareSize)
            assert.is_false(_G.PvPBattlegroundFactionIconDB.layouts.Modern.showBorder)
            -- Classic should get populated from migration
            assert.are.equal(64, _G.PvPBattlegroundFactionIconDB.layouts.Classic.squareSize)
        end)
    end)

    describe("per-layout settings", function()
        local LibEditMode

        before_each(function()
            LibEditMode = bootAddon()
        end)

        it("size getter returns default when no layout data", function()
            assert.are.equal(48, getRegisteredSettings(LibEditMode)[1].get("Modern"))
        end)

        it("size setter updates layout data", function()
            getRegisteredSettings(LibEditMode)[1].set("Modern", 72, false)
            assert.are.equal(72, _G.PvPBattlegroundFactionIconDB.layouts.Modern.squareSize)
        end)

        it("showBorder getter returns default when no layout data", function()
            assert.is_true(getRegisteredSettings(LibEditMode)[2].get("Modern"))
        end)

        it("showBorder setter updates layout data", function()
            getRegisteredSettings(LibEditMode)[2].set("Modern", false)
            assert.is_false(_G.PvPBattlegroundFactionIconDB.layouts.Modern.showBorder)
        end)
    end)

    describe("slash commands", function()
        before_each(function()
            bootAddon()
        end)

        it("toggles debug", function()
            assert.is_false(_G.PvPBattlegroundFactionIconDB.debug)
            _G.SlashCmdList["PBFI"]("debug")
            assert.is_true(_G.PvPBattlegroundFactionIconDB.debug)
            _G.SlashCmdList["PBFI"]("debug")
            assert.is_false(_G.PvPBattlegroundFactionIconDB.debug)
        end)

        it("does not error on empty input", function()
            assert.has_no.errors(function()
                _G.SlashCmdList["PBFI"]("")
            end)
        end)

        it("prints diagnostics on demand", function()
            _G.SlashCmdList["PBFI"]("diag")

            local output = table.concat(printedMessages, "\n")
            assert.is_true(output:find("Diagnostics %(slash command%)") ~= nil)
            assert.is_true(output:find("registered=") ~= nil)
            assert.is_true(output:find("visibilityReason=") ~= nil)
        end)
    end)

    describe("edit mode visibility", function()
        local LibEditMode

        before_each(function()
            LibEditMode = bootAddon()
        end)

        it("keeps the icon visible during edit mode and restores normal logic on exit", function()
            local addonFrame = getCreatedFrameByName("FactionIconFrame")
            assert.is_false(addonFrame._shown)

            LibEditMode:SetEditMode(true)
            fireEvent("PLAYER_ENTERING_WORLD")
            assert.is_true(addonFrame._shown)

            LibEditMode:SetEditMode(false)
            fireEvent("PLAYER_ENTERING_WORLD")
            assert.is_false(addonFrame._shown)
        end)
    end)
end)
