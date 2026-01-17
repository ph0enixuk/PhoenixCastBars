local ADDON_NAME, PCB = ...

PCB.name     = ADDON_NAME
PCB.version = "0.2.30"
PCB.LSM      = LibStub and LibStub("LibSharedMedia-3.0", true) or nil

-- Blizzard cast-bar suppression
PCB._blizzardBars = {}

local function GetBlizzardCastBars()
    return {
        PlayerCastingBarFrame,
        TargetFrameSpellBar,
        FocusFrameSpellBar,
        PetCastingBarFrame,
        VehicleCastingBarFrame,
        OverrideActionBarSpellBar,
    }
end

function PCB:DisableBlizzardCastBars()
    for _, bar in ipairs(GetBlizzardCastBars()) do
        if bar and not self._blizzardBars[bar] then
            self._blizzardBars[bar] = {
                Show = bar.Show,
                RegisterEvent = bar.RegisterEvent,
                RegisterUnitEvent = bar.RegisterUnitEvent,
                UnregisterEvent = bar.UnregisterEvent,
                UnregisterAllEvents = bar.UnregisterAllEvents,
                onShow = bar:GetScript("OnShow"),
                onEvent = bar:GetScript("OnEvent"),
            }
            bar:UnregisterAllEvents()
            bar:SetScript("OnEvent", nil)
            bar:SetScript("OnShow", function(self) self:Hide() end)
            bar.Show = bar.Hide
            bar.RegisterEvent = function() end
            bar.RegisterUnitEvent = function() end
            bar:Hide()
        end
    end
end

function PCB:EnableBlizzardCastBars()
    for bar, info in pairs(self._blizzardBars) do
        if bar and info then
            bar.Show = info.Show
            bar.RegisterEvent = info.RegisterEvent
            bar.RegisterUnitEvent = info.RegisterUnitEvent
            bar.UnregisterEvent = info.UnregisterEvent
            bar.UnregisterAllEvents = info.UnregisterAllEvents
            bar:SetScript("OnShow", info.onShow)
            bar:SetScript("OnEvent", info.onEvent)
            bar:Show()
        end
    end
    wipe(self._blizzardBars)
end

function PCB:UpdateBlizzardCastBars()
    if self.db and self.db.hideBlizzardCastBars then
        self:DisableBlizzardCastBars()
    else
        self:EnableBlizzardCastBars()
    end
end

-- watcher
PCB._blizzBarWatcher = CreateFrame("Frame")
PCB._blizzBarWatcher:RegisterEvent("PLAYER_ENTERING_WORLD")
PCB._blizzBarWatcher:RegisterEvent("UI_SCALE_CHANGED")
PCB._blizzBarWatcher:RegisterEvent("ADDON_LOADED")
PCB._blizzBarWatcher:RegisterUnitEvent("UNIT_SPELLCAST_START", "player", "vehicle")
PCB._blizzBarWatcher:RegisterUnitEvent("UNIT_SPELLCAST_CHANNEL_START", "player", "vehicle")
PCB._blizzBarWatcher:SetScript("OnEvent", function(_, event, arg1)
    if PCB and PCB.db and PCB.db.hideBlizzardCastBars then
        if event ~= "ADDON_LOADED" or (type(arg1) == "string" and arg1:match("^Blizzard_")) then
            PCB:DisableBlizzardCastBars()
        end
    end
end)

-- Defaults
local defaults = {
    hideBlizzardCastBars = true,
    locked = true,
    texture = "Interface\\TARGETINGFRAME\\UI-StatusBar",
    font = "Fonts\\FRIZQT__.TTF",
    fontSize = 12,
    outline = "OUTLINE",
    showIcon = true,
    showSpark = true,
    showTime = true,
    showSpellName = true,
    showLatency = true,
    showInterruptShield = true,
    colorCast = { r = 0.24, g = 0.56, b = 0.95, a = 1.0 },
    colorChannel = { r = 0.35, g = 0.90, b = 0.55, a = 1.0 },
    colorFailed = { r = 0.85, g = 0.25, b = 0.25, a = 1.0 },
    colorNonInterruptible = { r = 0.85, g = 0.75, b = 0.25, a = 1.0 },
    safeZoneColor = { r = 1.0, g = 0.2, b = 0.2, a = 0.35 },
    bars = {
        player = {
            enabled = true,
            width = 260, height = 18,
            point = "CENTER", relPoint = "CENTER", x = 0, y = -180,
            alpha = 1.0, scale = 1.0,
            appearance = {
                useGlobalTexture = true, useGlobalFont = true, useGlobalFontSize = true, useGlobalOutline = true,
                texture = nil, font = nil, fontSize = nil, outline = nil,
            },
        },
        target = {
            enabled = true,
            width = 240, height = 16,
            point = "CENTER", relPoint = "CENTER", x = 0, y = -140,
            alpha = 1.0, scale = 1.0,
            appearance = {
                useGlobalTexture = true, useGlobalFont = true, useGlobalFontSize = true, useGlobalOutline = true,
                texture = nil, font = nil, fontSize = nil, outline = nil,
            },
        },
        focus = {
            enabled = false,
            width = 240, height = 16,
            point = "CENTER", relPoint = "CENTER", x = 0, y = -110,
            alpha = 1.0, scale = 1.0,
            appearance = {
                useGlobalTexture = true, useGlobalFont = true, useGlobalFontSize = true, useGlobalOutline = true,
                texture = nil, font = nil, fontSize = nil, outline = nil,
            },
        },
    },
}

local function deepcopy(src)
    if type(src) ~= "table" then return src end
    local out = {}
    for k, v in pairs(src) do out[k] = deepcopy(v) end
    return out
end

local function mergeDefaults(dst, src)
    for k, v in pairs(src) do
        if type(v) == "table" then
            if type(dst[k]) ~= "table" then dst[k] = {} end
            mergeDefaults(dst[k], v)
        elseif dst[k] == nil then
            dst[k] = v
        end
    end
end

function PCB:RegisterMedia()
    if not self.LSM or not self.LSM.Register then return end

    -- Register custom textures
    self.LSM:Register("statusbar", "Phoenix CastBar", "Interface\\AddOns\\PhoenixCastBars\\Media\\Phoenix_CastBar.tga")
    self.LSM:Register("statusbar", "Phoenix Feather", "Interface\\AddOns\\PhoenixCastBars\\Media\\Phoenix_Feather.tga")

    -- Refresh when new media is registered by other addons
    self.LSM.RegisterCallback(self, "LibSharedMedia_Registered", function(_, mediatype)
        if mediatype == "statusbar" or mediatype == "font" then
            self:ApplyAll()
        end
    end)
end

function PCB:InitDB()
    if type(PhoenixCastBarsDB) ~= "table" then
        PhoenixCastBarsDB = deepcopy(defaults)
    else
        mergeDefaults(PhoenixCastBarsDB, defaults)
    end
    self.db = PhoenixCastBarsDB

    -- Migrate old path-based keys to new Key/Path system
    if self.db.texture and not self.db.textureKey then
        if type(self.db.texture) == "string" and (self.db.texture:find("\\") or self.db.texture:find("/")) then
            self.db.textureKey = "Custom"
            self.db.texturePath = self.db.texture
        else
            self.db.textureKey = self.db.texture
        end
    end
    if self.db.font and not self.db.fontKey then
        if type(self.db.font) == "string" and (self.db.font:find("\\") or self.db.font:find("/")) then
            self.db.fontKey = "Custom"
            self.db.fontPath = self.db.font
        else
            self.db.fontKey = self.db.font
        end
    end

    self.db.textureKey = self.db.textureKey or "Blizzard"
    self.db.fontKey    = self.db.fontKey or "Friz Quadrata (Default)"
    self.db.texturePath = self.db.texturePath or "Interface\\TARGETINGFRAME\\UI-StatusBar"
    self.db.fontPath    = self.db.fontPath or "Fonts\\FRIZQT__.TTF"

    -- Keep legacy fields happy
    self.db.texture = (self.db.textureKey == "Custom") and self.db.texturePath or self.db.textureKey
    self.db.font    = (self.db.fontKey == "Custom") and self.db.fontPath or self.db.fontKey
end

-- Helpers
function PCB:Print(msg)
    DEFAULT_CHAT_FRAME:AddMessage(("|cff66c0ffPhoenixCastBars|r: %s"):format(tostring(msg)))
end

function PCB:ColorFromTable(t)
    return t.r or 1, t.g or 1, t.b or 1, t.a or 1
end

function PCB:ApplyFont(fs)
    if not fs then return end
    local db = self.db
    local flags = db.outline or "OUTLINE"
    if flags == "NONE" then flags = "" end
    fs:SetFont(db.font, db.fontSize, flags)
end

-- Slash
local function SlashHandler(msg)
    msg = strtrim(strlower(msg or ""))
    if msg == "lock" or msg == "locked" then
        PCB.db.locked = true
        PCB:ApplyAll()
        PCB:Print("Frames locked.")
    elseif msg == "unlock" then
        PCB.db.locked = false
        PCB:ApplyAll()
        PCB:Print("Frames unlocked. Drag to move.")
    elseif msg == "reset" then
        PhoenixCastBarsDB = nil
        ReloadUI()
    elseif msg == "test" then
        for _, f in pairs(PCB.Bars) do
            f.cast = {
                startTimeMS = GetTime() * 1000,
                endTimeMS   = (GetTime() + 3) * 1000,
                spellID     = 133,
                sentTime    = GetTime() * 1000 - 150,
            }
            f.spellName = "Test Cast"
            f.notInterruptible = false
            f.icon:SetTexture(136235)
            f.icon:Show()
            f:Show()
        end
        PCB:Print("Test cast bars shown for 3 sec.")
    elseif msg == "media" then
        if PCB.LSM then
            PCB:Print("Available textures:")
            for _, name in ipairs(PCB.LSM:List("statusbar")) do
                PCB:Print("  - " .. name)
            end
            PCB:Print("Available fonts:")
            for _, name in ipairs(PCB.LSM:List("font")) do
                PCB:Print("  - " .. name)
            end
        else
            PCB:Print("LibSharedMedia not loaded")
        end
    elseif msg == "list" then
        -- Diagnostic: print addon metadata and whether it's listed by the client
        local num = GetNumAddOns()
        PCB:Print(("GetNumAddOns() = %d"):format(num))
        for i = 1, num do
            local name, title = GetAddOnInfo(i)
            if name == ADDON_NAME or title == ADDON_NAME or title == "PhoenixCastBars" then
                PCB:Print(("Found at index %d: name=%s title=%s"):format(i, tostring(name), tostring(title)))
            end
        end
        local title = GetAddOnMetadata(ADDON_NAME, "Title") or "<nil>"
        local interface = GetAddOnMetadata(ADDON_NAME, "Interface") or "<nil>"
        PCB:Print(("Metadata: Title=%s Interface=%s"):format(title, interface))
    else
        -- Ensure the options module is initialized and attempt to open it
        if PCB.Options and PCB.Options.Open then
            PCB.Options:Open()
        else
            PCB:Print("Options UI loading… please run /pcb again in a moment.")
        end
    end
end

SLASH_PHOENIXCASTBARS1 = "/pcb"
SlashCmdList["PHOENIXCASTBARS"] = SlashHandler

-- Bootstrap
local f = CreateFrame("Frame")
f:RegisterEvent("ADDON_LOADED")
f:RegisterEvent("PLAYER_LOGIN")
f:SetScript("OnEvent", function(_, event, arg1)
    if event == "ADDON_LOADED" and arg1 == ADDON_NAME then
        PCB:InitDB()
        PCB:RegisterMedia()
    elseif event == "PLAYER_LOGIN" then
        if PCB.UpdateCheck and PCB.UpdateCheck.Init then PCB.UpdateCheck:Init() end
        PCB:CreateBars()
        if PCB.Options and PCB.Options.Init then PCB.Options:Init() end
        PCB:ApplyAll()
        PCB:Print(("Loaded v%s. Type /pcb to open settings."):format(PCB.version))
    end
end)
