local _, ns = ...

local LibEditMode = LibStub("LibEditMode")

-- Faction icons
local factionIcons = {
    [0] = "Interface\\Icons\\pvpcurrency-honor-horde", -- Horde
    [1] = "Interface\\Icons\\Ui_alliance_7legionmedal", -- Alliance
}

-- Faction colors for border (RGB 0-1)
local factionColors = {
    [0] = { r = 0.8, g = 0.1, b = 0.1 }, -- Horde (red)
    [1] = { r = 0.1, g = 0.4, b = 0.8 }, -- Alliance (blue)
}

local ADDON_NAME = "PvPBattlegroundFactionIcon"
local ADDON_NAME_COLOURED = ns.ColorUtil.Sparkle("PvP Battleground Faction Icon", "c80404", "9a09ba", "274bff")
local FRAME_NAME = "FactionIconFrame"
local DEFAULT_ICON_SIZE = 48
local DEFAULT_SHOW_BORDER = true
local BORDER_SIZE = 3
local MIN_ICON_SIZE = 16
local MAX_ICON_SIZE = 128
local DEFAULT_POSITION = { point = "CENTER", x = 0, y = 0 }

local frame, icon, border, currentFaction
local lastEvent = "not received"
local lastUpdateReason = "not updated"
local lastVisibilityReason = "not set"
local isRegisteredWithEditMode = false

local IsInBattleground -- Forward declaration
local UpdateIcon -- Forward declaration

local function info(msg)
    print(ADDON_NAME_COLOURED .. ": " .. tostring(msg))
end

local function verbose(msg)
    if PvPBattlegroundFactionIconDB and PvPBattlegroundFactionIconDB.debug then
        print(ADDON_NAME_COLOURED .. " (debug): " .. tostring(msg))
    end
end

-- Per-layout saved variable accessors

local function copyPosition(position)
    if type(position) ~= "table" then
        return nil
    end

    return {
        point = position.point,
        x = position.x,
        y = position.y,
    }
end

local function CopyLayoutSettings(source)
    local data = {}

    if not source then
        return data
    end

    local squareSize = tonumber(source.squareSize)
    if squareSize and squareSize > 0 then
        data.squareSize = squareSize
    end

    if source.showBorder ~= nil then
        data.showBorder = not not source.showBorder
    end

    data.position = copyPosition(source.position)
    return data
end

local function MergeMissingLayoutSettings(target, seed)
    if not target or not seed then
        return false
    end

    local changed = false
    local squareSize = tonumber(target.squareSize)
    if not squareSize or squareSize <= 0 then
        local seedSquareSize = tonumber(seed.squareSize)
        if seedSquareSize and seedSquareSize > 0 then
            target.squareSize = seedSquareSize
            changed = true
        end
    end

    if target.showBorder == nil and seed.showBorder ~= nil then
        target.showBorder = not not seed.showBorder
        changed = true
    end

    if target.position == nil then
        local copiedPosition = copyPosition(seed.position)
        if copiedPosition then
            target.position = copiedPosition
            changed = true
        end
    end

    return changed
end

local function GetKnownLayoutNames()
    local layoutNames = {}
    local seen = {}

    local function addLayoutName(layoutName)
        if type(layoutName) ~= "string" or layoutName == "" or seen[layoutName] then
            return
        end

        seen[layoutName] = true
        layoutNames[#layoutNames + 1] = layoutName
    end

    addLayoutName("Modern")
    addLayoutName("Classic")
    addLayoutName(LibEditMode:GetActiveLayoutName())

    if C_EditMode and C_EditMode.GetLayouts then
        local ok, layoutInfo = pcall(C_EditMode.GetLayouts)
        if ok and type(layoutInfo) == "table" and type(layoutInfo.layouts) == "table" then
            for _, layout in ipairs(layoutInfo.layouts) do
                addLayoutName(layout and layout.layoutName)
            end
        end
    end

    return layoutNames
end

local function GetSeedLayoutData(layoutName)
    local layouts = PvPBattlegroundFactionIconDB and PvPBattlegroundFactionIconDB.layouts
    if not layouts then
        return nil
    end

    for _, fallbackLayoutName in ipairs({ "Modern", "Classic" }) do
        if fallbackLayoutName ~= layoutName and layouts[fallbackLayoutName] then
            return layouts[fallbackLayoutName]
        end
    end

    for existingLayoutName, data in pairs(layouts) do
        if existingLayoutName ~= layoutName then
            return data
        end
    end
end

local function GetLayoutData(layoutName)
    layoutName = layoutName or LibEditMode:GetActiveLayoutName()
    if not layoutName then return nil end
    local layouts = PvPBattlegroundFactionIconDB and PvPBattlegroundFactionIconDB.layouts
    return layouts and layouts[layoutName]
end

local function EnsureLayoutData(layoutName)
    layoutName = layoutName or LibEditMode:GetActiveLayoutName()
    assert(layoutName, "No active layout")

    local layouts = PvPBattlegroundFactionIconDB.layouts
    local data = layouts[layoutName]
    local seed = GetSeedLayoutData(layoutName)

    if not data then
        data = CopyLayoutSettings(seed)
        layouts[layoutName] = data

        if seed then
            verbose("Initialized layout '" .. tostring(layoutName) .. "' from existing saved settings")
        else
            verbose("Initialized layout '" .. tostring(layoutName) .. "' with defaults")
        end
    elseif MergeMissingLayoutSettings(data, seed) then
        verbose("Backfilled missing settings for layout '" .. tostring(layoutName) .. "'")
    end

    return data
end

local function GetSquareSize(layoutName)
    local data = GetLayoutData(layoutName)
    local size = data and tonumber(data.squareSize)
    if not size or size <= 0 then return DEFAULT_ICON_SIZE end
    return size
end

local function GetShowBorder(layoutName)
    local data = GetLayoutData(layoutName)
    if data and data.showBorder ~= nil then
        return not not data.showBorder
    end
    return DEFAULT_SHOW_BORDER
end

local function SetFrameVisibility(shouldShow, reason)
    lastVisibilityReason = reason

    if shouldShow then
        frame:Show()
    else
        frame:Hide()
    end
end

local function PrintDiagnostics(context)
    local layoutName = LibEditMode:GetActiveLayoutName()
    local data = GetLayoutData(layoutName)
    local point, relativePoint, x, y
    local width, height

    if frame then
        point, _, relativePoint, x, y = frame:GetPoint()
        width, height = frame:GetSize()
    end

    info("Diagnostics (" .. tostring(context or "manual") .. ")")
    info(
        "event=" .. tostring(lastEvent)
            .. ", updateReason=" .. tostring(lastUpdateReason)
            .. ", visibilityReason=" .. tostring(lastVisibilityReason)
    )
    info(
        "editMode=" .. tostring(LibEditMode:IsInEditMode())
            .. ", layout=" .. tostring(layoutName)
            .. ", battleground=" .. tostring(IsInBattleground())
            .. ", registered=" .. tostring(isRegisteredWithEditMode)
    )
    info(
        "frameExists=" .. tostring(frame ~= nil)
            .. ", frameShown=" .. tostring(frame and frame:IsShown())
            .. ", currentFaction=" .. tostring(currentFaction)
            .. ", size=" .. tostring(width)
            .. "x" .. tostring(height)
    )
    info(
        "framePoint=" .. tostring(point)
            .. ", relativePoint=" .. tostring(relativePoint)
            .. ", x=" .. tostring(x)
            .. ", y=" .. tostring(y)
    )
    info(
        "layoutSize=" .. tostring(GetSquareSize(layoutName))
            .. ", showBorder=" .. tostring(GetShowBorder(layoutName))
            .. ", storedPoint=" .. tostring(data and data.position and data.position.point)
            .. ", storedX=" .. tostring(data and data.position and data.position.x)
            .. ", storedY=" .. tostring(data and data.position and data.position.y)
    )
end

-- Frame appearance

local function ApplyAppearance()
    if not frame then return end

    local size = GetSquareSize()
    local showBorder = GetShowBorder()

    frame:SetSize(size, size)

    if icon then
        icon:ClearAllPoints()
        if showBorder then
            icon:SetPoint("TOPLEFT", frame, "TOPLEFT", BORDER_SIZE, -BORDER_SIZE)
            icon:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -BORDER_SIZE, BORDER_SIZE)
        else
            icon:SetAllPoints(frame)
        end
    end

    if border then
        border:SetShown(showBorder)
        border:SetAllPoints(frame)
    end

    verbose("Applied appearance: size=" .. size .. ", showBorder=" .. tostring(showBorder))
end

local function LoadPosition()
    assert(frame, "Frame not initialized")
    frame:ClearAllPoints()

    local activeLayoutName = LibEditMode:GetActiveLayoutName()
    local data = activeLayoutName and EnsureLayoutData(activeLayoutName) or GetLayoutData()
    local pos = data and data.position
    if pos and type(pos.x) == "number" and type(pos.y) == "number" then
        local point = type(pos.point) == "string" and pos.point or "CENTER"
        frame:SetPoint(point, UIParent, point, pos.x, pos.y)
        verbose("Loaded position: point=" .. point .. ", x=" .. tostring(pos.x) .. ", y=" .. tostring(pos.y))
    else
        frame:SetPoint("CENTER", UIParent, "CENTER")
        verbose("No saved position, using default center position")
    end
end

-- Frame creation

local function EnsureFrameExists()
    if not frame then
        verbose("Creating frame")
        frame = CreateFrame("Frame", FRAME_NAME, UIParent)
        frame:SetSize(DEFAULT_ICON_SIZE, DEFAULT_ICON_SIZE)
        frame:SetPoint(DEFAULT_POSITION.point, UIParent, DEFAULT_POSITION.point, DEFAULT_POSITION.x, DEFAULT_POSITION.y)
        frame:SetMovable(true)
        frame:SetClampedToScreen(true)
        frame:Hide()
    end

    if not icon then
        verbose("Creating icon texture")
        icon = frame:CreateTexture(nil, "ARTWORK")
        icon:SetPoint("TOPLEFT", frame, "TOPLEFT", BORDER_SIZE, -BORDER_SIZE)
        icon:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -BORDER_SIZE, BORDER_SIZE)
        icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    end

    if not border then
        verbose("Creating border texture")
        border = frame:CreateTexture(nil, "BACKGROUND")
        border:SetAllPoints(frame)
        border:SetColorTexture(1, 1, 1, 1)
    end
end

-- Battleground logic

IsInBattleground = function()
    local isInInstance, instanceType = IsInInstance()
    return isInInstance and (instanceType == "pvp" or instanceType == "ratedbg")
end

local function GetMatchFaction()
    local faction = GetBattlefieldArenaFaction()
    if faction and factionIcons[faction] then
        return faction
    end
    local factionGrp = UnitFactionGroup("player")
    return factionGrp == "Horde" and 0 or 1
end

UpdateIcon = function(force, reason)
    assert(frame, "Frame not initialized")
    assert(icon, "Icon not initialized")

    lastUpdateReason = reason or lastUpdateReason

    local activeLayoutName = LibEditMode:GetActiveLayoutName()
    if activeLayoutName and not GetLayoutData(activeLayoutName) then
        EnsureLayoutData(activeLayoutName)
        LoadPosition()
        ApplyAppearance()
    end

    local shouldShowForEditMode = force or LibEditMode:IsInEditMode()

    if not shouldShowForEditMode and not IsInBattleground() then
        SetFrameVisibility(false, "not in battleground")
        currentFaction = nil
        verbose("Not in battleground, hiding icon")
        return
    end

    local faction = GetMatchFaction()

    if faction and factionIcons[faction] then
        if currentFaction ~= faction then
            icon:SetTexture(factionIcons[faction])
            if border and factionColors[faction] then
                local c = factionColors[faction]
                border:SetColorTexture(c.r, c.g, c.b, 1)
                verbose("Updated border color for faction: " .. tostring(faction))
            end
            currentFaction = faction
            verbose("Updated icon to faction: " .. tostring(faction))
        end
        SetFrameVisibility(true, shouldShowForEditMode and "edit mode or forced display" or "battleground display")
    else
        verbose("No valid faction detected (" .. tostring(faction) .. "), hiding icon")
        SetFrameVisibility(false, "no valid faction")
        currentFaction = nil
    end
end

-- Saved variables

local function MigrateLegacyData()
    local db = PvPBattlegroundFactionIconDB
    db.layouts = db.layouts or {}

    local legacySize = tonumber(db.size)
    local legacyPos = db.position
    if legacySize or legacyPos then
        local legacyLayoutSettings = {
            squareSize = (legacySize and legacySize > 0) and legacySize or DEFAULT_ICON_SIZE,
            showBorder = DEFAULT_SHOW_BORDER,
            position = legacyPos,
        }

        for _, layoutName in ipairs(GetKnownLayoutNames()) do
            db.layouts[layoutName] = db.layouts[layoutName] or {}
            MergeMissingLayoutSettings(db.layouts[layoutName], legacyLayoutSettings)
        end

        db.size = nil
        db.position = nil
        verbose("Migrated legacy size/position into per-layout data")
    end
end

local function InitSavedVars()
    PvPBattlegroundFactionIconDB = PvPBattlegroundFactionIconDB or {}
    local db = PvPBattlegroundFactionIconDB
    if type(db.debug) ~= "boolean" then
        db.debug = false
    end
    MigrateLegacyData()
end

local function RegisterWithEditMode()
    LibEditMode:AddFrame(frame, function(_, layoutName, point, x, y)
        EnsureLayoutData(layoutName).position = { point = point, x = x, y = y }
        verbose("Position saved for layout: " .. tostring(layoutName))
    end, DEFAULT_POSITION, "PvP Faction Icon")
    isRegisteredWithEditMode = true
    verbose("Registered frame with LibEditMode")

    LibEditMode:AddFrameSettings(frame, {
        {
            kind = LibEditMode.SettingType.Slider,
            name = "Size",
            desc = "Size of the icon square in pixels.",
            default = DEFAULT_ICON_SIZE,
            minValue = MIN_ICON_SIZE,
            maxValue = MAX_ICON_SIZE,
            valueStep = 1,
            get = function(layoutName)
                return GetSquareSize(layoutName)
            end,
            set = function(layoutName, value, fromReset)
                EnsureLayoutData(layoutName).squareSize = value
                ApplyAppearance()
                if fromReset then
                    LoadPosition()
                end
            end,
        },
        {
            kind = LibEditMode.SettingType.Checkbox,
            name = "Show Border",
            desc = "Display a faction-colored border around the icon.",
            default = DEFAULT_SHOW_BORDER,
            get = function(layoutName)
                return GetShowBorder(layoutName)
            end,
            set = function(layoutName, value)
                EnsureLayoutData(layoutName).showBorder = not not value
                ApplyAppearance()
            end,
        },
    })

    LibEditMode:RegisterCallback("layout", function(layoutName)
        verbose("Layout changed to: " .. tostring(layoutName))
        EnsureLayoutData(layoutName)
        ApplyAppearance()
        LoadPosition()
        -- Force-show in edit mode so the user can see and drag the frame
        if LibEditMode:IsInEditMode() then
            UpdateIcon(true, "layout callback")
        end
    end)

    LibEditMode:RegisterCallback("create", function(newLayoutName, _, sourceLayoutName)
        if sourceLayoutName then
            local source = GetLayoutData(sourceLayoutName)
            if source then
                PvPBattlegroundFactionIconDB.layouts[newLayoutName] = CopyLayoutSettings(source)
                return
            end
        end
        EnsureLayoutData(newLayoutName)
    end)

    LibEditMode:RegisterCallback("rename", function(oldName, newName)
        local layouts = PvPBattlegroundFactionIconDB.layouts
        if layouts[oldName] then
            layouts[newName] = layouts[oldName]
            layouts[oldName] = nil
        end
    end)

    LibEditMode:RegisterCallback("delete", function(layoutName)
        PvPBattlegroundFactionIconDB.layouts[layoutName] = nil
    end)

    LibEditMode:RegisterCallback("enter", function()
        verbose("Edit Mode enter callback fired")
        UpdateIcon(true, "edit mode enter callback")
        if PvPBattlegroundFactionIconDB and PvPBattlegroundFactionIconDB.debug then
            PrintDiagnostics("edit mode enter")
        end
    end)

    LibEditMode:RegisterCallback("exit", function()
        verbose("Edit Mode exit callback fired")
        UpdateIcon(false, "edit mode exit callback")
    end)
end

-- Slash command

SLASH_PBFI1 = "/pbfi"
SlashCmdList["PBFI"] = function(msg)
    msg = (msg or ""):match("^%s*(.-)%s*$")

    if msg == "debug" then
        PvPBattlegroundFactionIconDB.debug = not PvPBattlegroundFactionIconDB.debug
        info("Debug is now " .. tostring(PvPBattlegroundFactionIconDB.debug))
        return
    end

    if msg == "diag" or msg == "diagnostics" then
        PrintDiagnostics("slash command")
        return
    end

    info("Use Edit Mode (Escape > Edit Mode) to move and configure this addon.")
    info("/pbfi debug - Toggle debug mode (current: " .. tostring(PvPBattlegroundFactionIconDB.debug) .. ")")
    info("/pbfi diag - Print widget diagnostics")
end

-- Event handler

local function QueueIconUpdate(reason)
    C_Timer.After(0.1, function()
        UpdateIcon(false, reason)
    end)
end

local function OnEvent(_, event, ...)
    lastEvent = event
    verbose("Event received: " .. tostring(event))

    if event == "ADDON_LOADED" then
        local addonName = ...
        if addonName == ADDON_NAME then
            InitSavedVars()
            EnsureFrameExists()
            RegisterWithEditMode()
            LoadPosition()
            ApplyAppearance()
            UpdateIcon(false, "ADDON_LOADED")
            verbose(ADDON_NAME .. " loaded.")
        end
    elseif event == "PLAYER_ENTERING_WORLD"
        or event == "ZONE_CHANGED_NEW_AREA"
        or event == "PLAYER_LEAVING_WORLD"
        or event == "UPDATE_BATTLEFIELD_STATUS" then
        QueueIconUpdate(event)
    end
end

-- Bootstrap

local eventFrame = CreateFrame("Frame")
eventFrame:RegisterEvent("ADDON_LOADED")
eventFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
eventFrame:RegisterEvent("ZONE_CHANGED_NEW_AREA")
eventFrame:RegisterEvent("PLAYER_LEAVING_WORLD")
eventFrame:RegisterEvent("UPDATE_BATTLEFIELD_STATUS")
eventFrame:SetScript("OnEvent", OnEvent)
