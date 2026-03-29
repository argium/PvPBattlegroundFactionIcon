-- Shared test helpers for busted specs that exercise real WoW addon source files.
-- Provides minimal WoW API stubs so source files can be loaded outside the game client.

local TestHelpers = {}

--- Captures the current values of the listed global names so they can be restored later.
---@param names string[]
---@return table<string, any>
function TestHelpers.CaptureGlobals(names)
    local captured = {}
    for _, name in ipairs(names) do
        captured[name] = _G[name]
    end
    return captured
end

--- Restores globals previously captured by CaptureGlobals.
---@param captured table<string, any>
function TestHelpers.RestoreGlobals(captured)
    for name, value in pairs(captured) do
        _G[name] = value
    end
end

--- Loads a Lua chunk by path, asserting on failure.
---@param path string
---@param errMsg string?
---@return function chunk
function TestHelpers.LoadChunk(path, errMsg)
    local chunk, err = loadfile(path)
    assert(chunk, (errMsg or "Failed to load") .. ": " .. tostring(err))
    return chunk
end

--- Installs a minimal LibStub stub into _G that supports NewLibrary and retrieval.
function TestHelpers.SetupLibStub()
    local libs = {}
    local LibStub = setmetatable({}, {
        __call = function(self, name, _)
            return libs[name]
        end,
    })
    function LibStub:NewLibrary(name, minor)
        if libs[name] and (libs[name]._minor or 0) >= (minor or 0) then
            return nil
        end
        local lib = libs[name] or {}
        lib._minor = minor
        libs[name] = lib
        return lib, 0
    end
    function LibStub:GetLibrary(name)
        return libs[name]
    end
    _G.LibStub = LibStub
    return LibStub
end

--- Installs a minimal WoW frame stub factory into _G.CreateFrame.
---@return table[] createdFrames list that collects every frame created
function TestHelpers.SetupCreateFrame()
    local createdFrames = {}
    _G.CreateFrame = function(frameType, name, parent, template)
        local f = {
            _type = frameType,
            _name = name,
            _parent = parent,
            _template = template,
            _points = {},
            _scripts = {},
            _size = { w = 0, h = 0 },
            _shown = true,
            _movable = false,
            _clamped = false,
            _textures = {},
            _events = {},
        }
        function f:SetSize(w, h) self._size = { w = w, h = h } end
        function f:GetSize() return self._size.w, self._size.h end
        function f:SetWidth(w) self._size.w = w end
        function f:SetHeight(h) self._size.h = h end
        function f:SetMovable(v) self._movable = v end
        function f:SetClampedToScreen(v) self._clamped = v end
        function f:EnableMouse() end
        function f:RegisterForDrag() end
        function f:SetPoint(point, ...) self._points[#self._points + 1] = { point = point, args = { ... } } end
        function f:ClearAllPoints() self._points = {} end
        function f:GetPoint(idx)
            local p = self._points[idx or 1]
            if p then return p.point, p.args[1], p.args[2], p.args[3] or 0, p.args[4] or 0 end
            return "CENTER", nil, "CENTER", 0, 0
        end
        function f:Show() self._shown = true end
        function f:Hide() self._shown = false end
        function f:IsShown() return self._shown end
        function f:SetShown(v) self._shown = not not v end
        function f:SetScript(name, fn) self._scripts[name] = fn end
        function f:GetScript(name) return self._scripts[name] end
        function f:RegisterEvent(event) self._events[event] = true end
        function f:UnregisterEvent(event) self._events[event] = nil end
        function f:StartMoving() end
        function f:StopMovingOrSizing() end
        function f:SetAllPoints() end
        function f:CreateTexture(_, layer)
            local tex = {
                _layer = layer,
                _shown = true,
                _points = {},
            }
            function tex:SetPoint(point, ...) self._points[#self._points + 1] = { point = point, args = { ... } } end
            function tex:ClearAllPoints() self._points = {} end
            function tex:SetAllPoints() end
            function tex:SetTexCoord() end
            function tex:SetTexture(t) self._texture = t end
            function tex:SetColorTexture(r, g, b, a) self._color = { r = r, g = g, b = b, a = a } end
            function tex:Show() self._shown = true end
            function tex:Hide() self._shown = false end
            function tex:SetShown(v) self._shown = not not v end
            function tex:IsShown() return self._shown end
            self._textures[#self._textures + 1] = tex
            return tex
        end
        createdFrames[#createdFrames + 1] = f
        return f
    end
    return createdFrames
end

return TestHelpers
