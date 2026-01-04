-- Faction icons
local factionIcons = {
    [0] = "Interface\\Icons\\UI_HordeIcon", -- Horde
    [1] = "Interface\\Icons\\Ui_alliance_7legionmedal", -- Alliance
}

local frame = nil
local icon = nil
local currentFaction = nil -- Currently displayed faction

local ADDON_NAME = "PvPBattlegroundFactionIcon"
local FRAME_NAME = "FactionIconFrame"
local DEFAULT_ICON_SIZE = 48

-- SavedVariables
PvPBattlegroundFactionIconDB = PvPBattlegroundFactionIconDB or {}
if type(PvPBattlegroundFactionIconDB.size) ~= "number" or PvPBattlegroundFactionIconDB.size <= 0 then
    PvPBattlegroundFactionIconDB.size = DEFAULT_ICON_SIZE
    PvPBattlegroundFactionIconDB.position = nil
end
if PvPBattlegroundFactionIconDB.position ~= nil and type(PvPBattlegroundFactionIconDB.position) ~= "table" then
    PvPBattlegroundFactionIconDB.position = nil
end
if type(PvPBattlegroundFactionIconDB.debug) ~= "boolean" then
    PvPBattlegroundFactionIconDB.debug = false
end

local function info(msg)
    print(ADDON_NAME .. ": |cffcfcfcf" .. tostring(msg) .. "|r")
end

local function verbose(msg)
    if PvPBattlegroundFactionIconDB.debug then
        print(ADDON_NAME .. " (debug): |cffcfcfcf" .. tostring(msg) .. "|r")
    end
end

local function GetSavedIconSize()
    local size = tonumber(PvPBattlegroundFactionIconDB and PvPBattlegroundFactionIconDB.size)
    if not size or size <= 0 then
        return DEFAULT_ICON_SIZE
    end
    return size
end

    -- Save the frame's position
local function SavePosition()
    assert(frame, "Frame not initialized")
    local point, _, _, x, y = frame:GetPoint()
    PvPBattlegroundFactionIconDB.position = { x = x, y = y }
end

-- Load the frame's position
local function LoadPosition()
    assert(frame, "Frame not initialized")
    frame:ClearAllPoints()
    if PvPBattlegroundFactionIconDB.position and type(PvPBattlegroundFactionIconDB.position.x) == "number" and type(PvPBattlegroundFactionIconDB.position.y) == "number" then
        frame:SetPoint("CENTER", UIParent, "CENTER", PvPBattlegroundFactionIconDB.position.x, PvPBattlegroundFactionIconDB.position.y)
        verbose("Loaded position: x=" .. tostring(PvPBattlegroundFactionIconDB.position.x) .. ", y=" .. tostring(PvPBattlegroundFactionIconDB.position.y))
    else
        frame:SetPoint("CENTER", UIParent, "CENTER")
        verbose("No saved position, using default center position")
    end
end

local function ApplyIconSize()
    assert(frame, "Frame not initialized")
    verbose("Applying icon size")

    local size = GetSavedIconSize()
    frame:SetSize(size, size)
    if icon then
        icon:SetAllPoints()
    end
end

-- Ensure the frame exists
local function EnsureFrameExists()
    if not frame then
        verbose("Creating frame")
        frame = CreateFrame("Frame", FRAME_NAME, UIParent)
        local size = GetSavedIconSize()
        frame:SetSize(size, size)
        frame:SetMovable(true)
        frame:EnableMouse(true)
        frame:RegisterForDrag("LeftButton")
        frame:SetScript("OnDragStart", function(self)
            if not (IsControlKeyDown() and IsShiftKeyDown()) then return end
            self._pbfiIsMoving = true
            self:StartMoving()
        end)
        frame:SetScript("OnDragStop", function(self)
            if self._pbfiIsMoving then
                self:StopMovingOrSizing()
                self._pbfiIsMoving = false
                SavePosition()
            end
        end)
        frame:SetScript("OnHide", function(self)
            if self._pbfiIsMoving then
                self:StopMovingOrSizing()
                self._pbfiIsMoving = false
            end
        end)

        frame:Hide()
        ApplyIconSize()
    end

    if not icon then
        verbose("Creating icon texture")
        icon = frame:CreateTexture(nil, "ARTWORK")
        icon:SetAllPoints()
    end
end

local function ResetPosition()
    EnsureFrameExists()
    if frame and frame.StopMovingOrSizing then
        frame:StopMovingOrSizing()
    end
    PvPBattlegroundFactionIconDB.position = nil
    LoadPosition()
    info("Position reset to default")
end


local function PrintUsage()
    info("Usage: /pbfi size <number> | /pbfi debug | /pbfi reset")
    info("Current size: " .. tostring(GetSavedIconSize()) .. ", debug: " .. tostring(PvPBattlegroundFactionIconDB.debug))
end

-- Check if the player is in a battleground
local function IsInBattleground()
    local isInInstance, instanceType = IsInInstance()
    return isInInstance and (instanceType == "pvp" or instanceType == "ratedbg")
end

local function GetMatchFaction()
    local faction = GetBattlefieldArenaFaction()
    if faction and factionIcons[faction] then
        return faction
    else
        local factionGrp, _ = UnitFactionGroup("player")
        if factionGrp == "Horde" then return 0 else return 1 end
    end
end

-- Update the faction icon
local function UpdateIcon()
    assert(frame, "Frame not initialized")
    assert(icon, "Icon not initialized")

    -- Check if the player is in a battleground
    if not IsInBattleground() then
        frame:Hide()
        currentFaction = nil
        verbose("Not in battleground, hiding icon")
        return
    end

    -- Get the player's faction/team for the active match
    local faction = GetMatchFaction()

    if faction and factionIcons[faction] then
        if currentFaction ~= faction then
            icon:SetTexture(factionIcons[faction])
            currentFaction = faction
            verbose("Updated icon to faction: " .. tostring(faction))
        end
        frame:Show()
        return
    else
        verbose("No valid faction detected (".. tostring(faction) .. "), hiding icon")
        frame:Hide()
        currentFaction = nil
    end
end

-- Event handler
local function OnEvent(self, event, ...)
    if event == "PLAYER_ENTERING_WORLD" or event == "ZONE_CHANGED_NEW_AREA" or event == "PLAYER_LEAVING_WORLD" then
        C_Timer.After(0.1, function()
            UpdateIcon()
        end)
    elseif event == "ADDON_LOADED" then
        local addonName = ...
        if addonName == ADDON_NAME then
            EnsureFrameExists()
            ApplyIconSize()
            LoadPosition()
            UpdateIcon()
            verbose(ADDON_NAME .. " loaded. Use /pbfi <size> to set icon size.")
        end
    end
end

-- Slash command: /pbfi <size>
SLASH_PBFI1 = "/pbfi"
SlashCmdList["PBFI"] = function(msg)
    msg = (msg or ""):match("^%s*(.-)%s*$")
    if msg == "" then
        PrintUsage()
        return
    end

    local cmd, rest = msg:match("^(%S+)%s*(.-)%s*$")
    cmd = cmd and cmd:lower() or ""

    if cmd == "size" then
        local newSize = tonumber(rest)
        if not newSize or newSize <= 0 then
            PrintUsage()
            return
        end

        PvPBattlegroundFactionIconDB.size = newSize
        ApplyIconSize()
        info("Icon size set to " .. tostring(newSize))
        return
    end

    if cmd == "debug" then
        PvPBattlegroundFactionIconDB.debug = not PvPBattlegroundFactionIconDB.debug
        info("Debug is now " .. tostring(PvPBattlegroundFactionIconDB.debug))
        return
    end

    if cmd == "reset" or cmd == "resetpos" or cmd == "resetposition" then
        ResetPosition()
        return
    end

    PrintUsage()
end

-- Initialize the addon
local f = CreateFrame("Frame")
local function Initialize()
    f:RegisterEvent("PLAYER_ENTERING_WORLD")
    f:RegisterEvent("ZONE_CHANGED_NEW_AREA")
    f:RegisterEvent("PLAYER_LEAVING_WORLD")
    f:RegisterEvent("ADDON_LOADED")
    f:SetScript("OnEvent", OnEvent)
end

-- Start the addon
Initialize()
