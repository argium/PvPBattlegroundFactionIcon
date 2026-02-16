local _, ns = ...

-- Faction icons
local factionIcons = {
    [0] = "Interface\\Icons\\pvpcurrency-honor-horde", -- Horde
    [1] = "Interface\\Icons\\Ui_alliance_7legionmedal", -- Alliance
}

local frame = nil
local icon = nil
local border = nil
local currentFaction = nil -- Currently displayed faction

-- Faction colors for border (RGB 0-1)
local factionColors = {
    [0] = { r = 0.8, g = 0.1, b = 0.1 }, -- Horde (red)
    [1] = { r = 0.1, g = 0.4, b = 0.8 }, -- Alliance (blue)
}

local ADDON_NAME = "PvPBattlegroundFactionIcon"
local ADDON_NAME_COLOURED = ns.ColorUtil.GradientText("PvP Battleground Faction Icon", "c80404", "9a09ba", "274bff")
local FRAME_NAME = "FactionIconFrame"
local DEFAULT_ICON_SIZE = 48
local BORDER_SIZE = 3

local UpdateIcon -- Forward declaration

local function info(msg)
    print(ADDON_NAME_COLOURED .. ": " .. tostring(msg))
end

local function verbose(msg)
    if PvPBattlegroundFactionIconDB.debug then
        print(ADDON_NAME_COLOURED .. " (debug): " .. tostring(msg))
    end
end

local function GetSavedIconSize()
    local size = tonumber(PvPBattlegroundFactionIconDB and PvPBattlegroundFactionIconDB.size)
    if not size or size <= 0 then
        return DEFAULT_ICON_SIZE
    end
    return size
end

-- Save the frame's position (including anchor point)
local function SavePosition()
    assert(frame, "Frame not initialized")
    local point, _, _, x, y = frame:GetPoint()
    PvPBattlegroundFactionIconDB.position = { point = point, x = x, y = y }
end

-- Load the frame's position
local function LoadPosition()
    assert(frame, "Frame not initialized")
    frame:ClearAllPoints()
    local pos = PvPBattlegroundFactionIconDB.position
    if pos and type(pos.x) == "number" and type(pos.y) == "number" then
        local point = type(pos.point) == "string" and pos.point or "CENTER"
        frame:SetPoint(point, UIParent, point, pos.x, pos.y)
        verbose("Loaded position: point=" .. point .. ", x=" .. tostring(pos.x) .. ", y=" .. tostring(pos.y))
    else
        frame:SetPoint("CENTER", UIParent, "CENTER")
        verbose("No saved position, using default center position")
    end
end

local function ApplyIconSize()
    assert(frame, "Frame not initialized")
    verbose("Applying icon size")

    local size = GetSavedIconSize()
    frame:SetSize(size + BORDER_SIZE * 2, size + BORDER_SIZE * 2)
    if icon then
        icon:ClearAllPoints()
        icon:SetPoint("TOPLEFT", frame, "TOPLEFT", BORDER_SIZE, -BORDER_SIZE)
        icon:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -BORDER_SIZE, BORDER_SIZE)
        UpdateIcon(true)
        C_Timer.After(5, function()
            UpdateIcon()
        end)
    end
    if border then
        border:SetAllPoints(frame)
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
        icon:SetPoint("TOPLEFT", frame, "TOPLEFT", BORDER_SIZE, -BORDER_SIZE)
        icon:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -BORDER_SIZE, BORDER_SIZE)
        -- Zoom in slightly to hide the icon's built-in border
        icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    end

    if not border then
        verbose("Creating border texture")
        border = frame:CreateTexture(nil, "BACKGROUND")
        border:SetAllPoints(frame)
        border:SetColorTexture(1, 1, 1, 1) -- Default white, will be updated
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
    info("Hold Ctrl+Shift and drag the icon to reposition it.")
    info("/pbfi size <number> - Set icon size (current: " .. tostring(GetSavedIconSize()) .. ")")
    info("/pbfi reset - Reset icon position to default")
    info("/pbfi debug - Toggle debug mode (current: " .. tostring(PvPBattlegroundFactionIconDB.debug) .. ")")
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
UpdateIcon = function(force)
    assert(frame, "Frame not initialized")
    assert(icon, "Icon not initialized")

    -- Check if the player is in a battleground
    if not force and not IsInBattleground() then
        frame:Hide()
        currentFaction = nil
        verbose("Not in battleground, hiding icon")
        return
    end

    -- Get the player's faction/team for the active match
    local faction = GetMatchFaction()

    if not faction and force then
        faction = UnitFactionGroup("player") == "Horde" and 0 or 1
        verbose("Force update: using player faction " .. tostring(faction))
    end

    if faction and factionIcons[faction] then
        if currentFaction ~= faction then
            icon:SetTexture(factionIcons[faction])
            -- Update border color to match faction
            if border and factionColors[faction] then
                local c = factionColors[faction]
                border:SetColorTexture(c.r, c.g, c.b, 1)
                verbose("Updated border color for faction: " .. tostring(faction))
            end
            currentFaction = faction
            verbose("Updated icon to faction: " .. tostring(faction))
        end
        frame:Show()
        return
    else
        verbose("No valid faction detected (" .. tostring(faction) .. "), hiding icon")
        frame:Hide()
        currentFaction = nil
    end
end

-- Validate and initialize SavedVariables (called once from ADDON_LOADED)
local function InitSavedVars()
    PvPBattlegroundFactionIconDB = PvPBattlegroundFactionIconDB or {}
    local db = PvPBattlegroundFactionIconDB
    if type(db.size) ~= "number" or db.size <= 0 then
        db.size = DEFAULT_ICON_SIZE
        db.position = nil
    end
    if db.position ~= nil and type(db.position) ~= "table" then
        db.position = nil
    end
    if type(db.debug) ~= "boolean" then
        db.debug = false
    end
end

-- Event handler
local function OnEvent(self, event, ...)
    if event == "PLAYER_ENTERING_WORLD" then
        if not PvPBattlegroundFactionIconDB.position then
            info("Hold Ctrl+Shift and drag the icon to reposition it.")
            info("Use /pbfi size <number> to change the icon size, or /pbfi reset to restore the default position.")
        end
        C_Timer.After(0.1, function()
            UpdateIcon()
        end)
    elseif event == "ZONE_CHANGED_NEW_AREA"
        or event == "PLAYER_LEAVING_WORLD" or event == "UPDATE_BATTLEFIELD_STATUS" then
        C_Timer.After(0.1, function()
            UpdateIcon()
        end)
    elseif event == "ADDON_LOADED" then
        local addonName = ...
        if addonName == ADDON_NAME then
            InitSavedVars()
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
    f:RegisterEvent("UPDATE_BATTLEFIELD_STATUS")
    f:RegisterEvent("ADDON_LOADED")
    f:SetScript("OnEvent", OnEvent)
end

-- Start the addon
Initialize()
