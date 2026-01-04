-- Faction icons
local factionIcons = {
    [0] = "Interface\\Icons\\ui_hordeicon-round", -- Horde
    [1] = "Interface\\Icons\\ui-allianceicon", -- Alliance
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

local function verbose(msg)
    -- Uncomment the next line to enable verbose logging
    print(ADDON_NAME .. " (verbose): |cffcfcfcf" .. tostring(msg) .. "|r")
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
    if PvPBattlegroundFactionIconDB.position and type(PvPBattlegroundFactionIconDB.position.x) == "number" and type(PvPBattlegroundFactionIconDB.position.y) == "number" then
        frame:SetPoint("CENTER", UIParent, "CENTER", PvPBattlegroundFactionIconDB.position.x, PvPBattlegroundFactionIconDB.position.y)
        verbose("Loaded position: x=" .. tostring(PvPBattlegroundFactionIconDB.position.x) .. ", y=" .. tostring(PvPBattlegroundFactionIconDB.position.y))
    else
        frame:SetPoint("CENTER", UIParent, "CENTER")
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
            self:StartMoving()
        end)
        frame:SetScript("OnDragStop", function(self)
            if self:IsMoving() then
                self:StopMovingOrSizing()
                SavePosition()
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


local function PrintUsage()
    verbose("/pbfi <number> - set icon size (current: " .. tostring(GetSavedIconSize()) .. ")")
end

-- Check if the player is in a battleground
local function IsInBattleground()
    local isInInstance, instanceType = IsInInstance()
    return isInInstance and (instanceType == "pvp" or instanceType == "ratedbg")
end

local function GetMatchFaction()
    if C_PvP and C_PvP.GetActiveMatchFaction then
        local faction = C_PvP.GetActiveMatchFaction()
        if faction == 0 or faction == 1 then
            verbose("Detected match faction: " .. tostring(faction))
            return faction
        end
    end

    verbose("Falling back to UnitFactionGroup")
    local factionGroup = UnitFactionGroup("player")
    if factionGroup == "Horde" then
        return 0
    elseif factionGroup == "Alliance" then
        return 1
    end

    return nil
end

-- Update the faction icon
local function UpdateIcon()
    assert(frame, "Frame not initialized")
    assert(icon, "Icon not initialized")

    -- Check if the player is in a battleground
    if not IsInBattleground() then
        frame:Hide()
        currentFaction = nil
        return
    end

    -- Get the player's faction/team for the active match
    local faction = GetMatchFaction()

    if faction and factionIcons[faction] then
        if currentFaction ~= faction then
            icon:SetTexture(factionIcons[faction])
            currentFaction = faction
        end
        frame:Show()
        return
    end

    frame:Hide()
    currentFaction = nil
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
            -- EnsureFrameExists()
            verbose(ADDON_NAME .. " loaded. Use /pbfi <size> to set icon size.")
            ApplyIconSize()
            LoadPosition()
            UpdateIcon()
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

    local newSize = tonumber(msg)
    if not newSize or newSize <= 0 then
        PrintUsage()
        return
    end

    PvPBattlegroundFactionIconDB.size = newSize
    ApplyIconSize()
    verbose("PvP Battleground Faction Icon size set to " .. tostring(newSize))
end

-- Initialize the addon
local f = CreateFrame("Frame")
local function Initialize()
    EnsureFrameExists()
    f:RegisterEvent("PLAYER_ENTERING_WORLD")
    f:RegisterEvent("ZONE_CHANGED_NEW_AREA")
    f:RegisterEvent("PLAYER_LEAVING_WORLD")
    f:RegisterEvent("ADDON_LOADED")
    f:SetScript("OnEvent", OnEvent)
end

-- Start the addon
Initialize()
