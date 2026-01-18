local ADDON_NAME, PCB = ...

<<<<<<< HEAD
PCB.name     = ADDON_NAME
PCB.version = "0.2.30"
PCB.LSM      = LibStub and LibStub("LibSharedMedia-3.0", true) or nil
=======
function PCB:Print(msg)
    msg = tostring(msg or "")
    if DEFAULT_CHAT_FRAME and DEFAULT_CHAT_FRAME.AddMessage then
        DEFAULT_CHAT_FRAME:AddMessage("|cff33ff99PhoenixCastBars:|r " .. msg)
    else
        print("PhoenixCastBars: " .. msg)
    end
end

PCB.name     = ADDON_NAME
PCB.version = "0.3.4"
PCB.LSM      = LibStub and LibStub("LibSharedMedia-3.0", true) or nil
PCB.LDBIcon  = LibStub and LibStub("LibDBIcon-1.0", true) or nil
>>>>>>> 9671a60 (Release v0.3.4 / update files)

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
<<<<<<< HEAD
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
=======
        if bar then
            local isAlreadyDisabled = (bar.Show == bar.Hide)
            
            if not isAlreadyDisabled then
                if not self._blizzardBars[bar] then
                    self._blizzardBars[bar] = {
                        Show = bar.Show,
                        RegisterEvent = bar.RegisterEvent,
                        RegisterUnitEvent = bar.RegisterUnitEvent,
                        UnregisterEvent = bar.UnregisterEvent,
                        UnregisterAllEvents = bar.UnregisterAllEvents,
                        onShow = bar:GetScript("OnShow"),
                        onEvent = bar:GetScript("OnEvent"),
                    }
                end
                
                bar:UnregisterAllEvents()
                bar:SetScript("OnEvent", nil)
                bar:SetScript("OnShow", function(self) self:Hide() end)
                bar.Show = bar.Hide
                bar.RegisterEvent = function() end
                bar.RegisterUnitEvent = function() end
                bar:Hide()
            end
>>>>>>> 9671a60 (Release v0.3.4 / update files)
        end
    end
end

function PCB:EnableBlizzardCastBars()
<<<<<<< HEAD
=======
    -- If bars were never disabled, nothing to restore - they're already enabled
    if not next(self._blizzardBars) then
        return
    end
    
>>>>>>> 9671a60 (Release v0.3.4 / update files)
    for bar, info in pairs(self._blizzardBars) do
        if bar and info then
            bar.Show = info.Show
            bar.RegisterEvent = info.RegisterEvent
            bar.RegisterUnitEvent = info.RegisterUnitEvent
            bar.UnregisterEvent = info.UnregisterEvent
            bar.UnregisterAllEvents = info.UnregisterAllEvents
            bar:SetScript("OnShow", info.onShow)
            bar:SetScript("OnEvent", info.onEvent)
<<<<<<< HEAD
            bar:Show()
        end
    end
    wipe(self._blizzardBars)
=======
            
            local unit = nil
            if bar == PlayerCastingBarFrame then
                unit = "player"
            elseif bar == TargetFrameSpellBar then
                unit = "target"
            elseif bar == FocusFrameSpellBar then
                unit = "focus"
            elseif bar == PetCastingBarFrame then
                unit = "pet"
            end
            
            if unit then
                bar:RegisterUnitEvent("UNIT_SPELLCAST_START", unit)
                bar:RegisterUnitEvent("UNIT_SPELLCAST_FAILED", unit)
                bar:RegisterUnitEvent("UNIT_SPELLCAST_STOP", unit)
                bar:RegisterUnitEvent("UNIT_SPELLCAST_INTERRUPTED", unit)
                bar:RegisterUnitEvent("UNIT_SPELLCAST_DELAYED", unit)
                bar:RegisterUnitEvent("UNIT_SPELLCAST_CHANNEL_START", unit)
                bar:RegisterUnitEvent("UNIT_SPELLCAST_CHANNEL_UPDATE", unit)
                bar:RegisterUnitEvent("UNIT_SPELLCAST_CHANNEL_STOP", unit)
                bar:RegisterUnitEvent("UNIT_SPELLCAST_INTERRUPTIBLE", unit)
                bar:RegisterUnitEvent("UNIT_SPELLCAST_NOT_INTERRUPTIBLE", unit)
            end
        end
    end
    
    -- Keep _blizzardBars table intact for future enable/disable toggles
>>>>>>> 9671a60 (Release v0.3.4 / update files)
end

function PCB:UpdateBlizzardCastBars()
    if self.db and self.db.hideBlizzardCastBars then
        self:DisableBlizzardCastBars()
    else
        self:EnableBlizzardCastBars()
    end
end

<<<<<<< HEAD
-- watcher
=======
-- Background watcher to re-disable Blizzard bars when they try to reappear
>>>>>>> 9671a60 (Release v0.3.4 / update files)
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
<<<<<<< HEAD
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
=======
    colorCast = { r = 0.24, g = 0.56, b = 0.95, a = 1.0 },
    colorChannel = { r = 0.35, g = 0.90, b = 0.55, a = 1.0 },
    colorFailed = { r = 0.85, g = 0.25, b = 0.25, a = 1.0 },
    colorSuccess = { r = 0.25, g = 0.90, b = 0.35, a = 1.0 },
    colorNonInterruptible = { r = 0.85, g = 0.75, b = 0.25, a = 1.0 },
    safeZoneColor = { r = 1.0, g = 0.2, b = 0.2, a = 0.35 },
    minimapButton = {
        show = true,
        angle = 220,
    },
>>>>>>> 9671a60 (Release v0.3.4 / update files)
    bars = {
        player = {
            enabled = true,
            width = 260, height = 18,
            point = "CENTER", relPoint = "CENTER", x = 0, y = -180,
            alpha = 1.0, scale = 1.0,
<<<<<<< HEAD
=======
            showIcon = true,
            showSpark = true,
            showTime = true,
            showSpellName = true,
            showLatency = true,
            showInterruptShield = true,
>>>>>>> 9671a60 (Release v0.3.4 / update files)
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
<<<<<<< HEAD
=======
            showIcon = true,
            showSpark = true,
            showTime = true,
            showSpellName = true,
            showInterruptShield = true,
>>>>>>> 9671a60 (Release v0.3.4 / update files)
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
<<<<<<< HEAD
=======
            showIcon = true,
            showSpark = true,
            showTime = true,
            showSpellName = true,
            showInterruptShield = true,
>>>>>>> 9671a60 (Release v0.3.4 / update files)
            appearance = {
                useGlobalTexture = true, useGlobalFont = true, useGlobalFontSize = true, useGlobalOutline = true,
                texture = nil, font = nil, fontSize = nil, outline = nil,
            },
        },
    },
}

<<<<<<< HEAD
=======

-- =========================================================
-- Profiles (per-character / per-spec) + Export/Import
-- =========================================================
-- SavedVariables root schema:
-- PhoenixCastBarsDB = {
--   profileMode = "character"|"spec",
--   profiles = { [profileName] = <settings table> },
--   chars = { [charKey] = { profile = "Default", specProfiles = { [specID] = "Default" } } },
-- }

local DB_SCHEMA_VERSION = 1

>>>>>>> 9671a60 (Release v0.3.4 / update files)
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

<<<<<<< HEAD
=======
local function GetCharKey()
    local name = UnitName("player") or "Unknown"
    local realm = GetRealmName() or "Realm"
    realm = realm:gsub("%s+", "")
    return name .. "-" .. realm
end

local function GetCurrentSpecID()
    local specIndex = GetSpecialization and GetSpecialization()
    if not specIndex or specIndex == 0 then return nil end
    local specID = select(1, GetSpecializationInfo(specIndex))
    return specID
end

-- Profile serialization for export/import. Supports nil, boolean, number, string, and table (with string/number keys only).
-- Avoids loadstring for security; provides stable key ordering for consistent export strings.
local function SerializeValue(v, out)
    local t = type(v)
    if t == "nil" then
        out[#out+1] = "n"
    elseif t == "boolean" then
        out[#out+1] = v and "b1" or "b0"
    elseif t == "number" then
        out[#out+1] = "d"
        out[#out+1] = tostring(v)
        out[#out+1] = ";"
    elseif t == "string" then
        out[#out+1] = "s"
        out[#out+1] = tostring(#v)
        out[#out+1] = ":"
        out[#out+1] = v
    elseif t == "table" then
        out[#out+1] = "t"
        local keys = {}
        for k in pairs(v) do keys[#keys+1] = k end
        table.sort(keys, function(a,b) return tostring(a) < tostring(b) end)
        for i=1,#keys do
            local k = keys[i]
            SerializeValue(k, out)
            SerializeValue(v[k], out)
        end
        out[#out+1] = "e"
    else
        out[#out+1] = "n"
    end
end

local function SerializeTable(tbl)
    local out = {}
    SerializeValue(tbl, out)
    return table.concat(out)
end

local function DeserializeValue(s, i)
    local tag = s:sub(i,i)
    if tag == "n" then
        return nil, i+1
    elseif tag == "b" then
        local v = s:sub(i+1,i+1) == "1"
        return v, i+2
    elseif tag == "d" then
        local j = s:find(";", i+1, true)
        if not j then return nil, #s+1 end
        local num = tonumber(s:sub(i+1, j-1))
        return num, j+1
    elseif tag == "s" then
        local colon = s:find(":", i+1, true)
        if not colon then return "", #s+1 end
        local len = tonumber(s:sub(i+1, colon-1)) or 0
        local start = colon+1
        local stop = start + len - 1
        local str = s:sub(start, stop)
        return str, stop+1
    elseif tag == "t" then
        local tbl = {}
        i = i+1
        while i <= #s do
            if s:sub(i,i) == "e" then
                return tbl, i+1
            end
            local k; k, i = DeserializeValue(s, i)
            local v; v, i = DeserializeValue(s, i)
            if k ~= nil then
                tbl[k] = v
            end
        end
        return tbl, #s+1
    end
    return nil, #s+1
end

local function DeserializeTable(s)
    if type(s) ~= "string" or s == "" then return nil end
    local v, idx = DeserializeValue(s, 1)
    if idx <= #s then
    end
    if type(v) ~= "table" then return nil end
    return v
end

function PCB:ExportProfile(profileName)
    self:InitDB()
    local name = profileName or self.dbRoot and self.dbRoot._activeProfile or "Default"
    if not self.dbRoot or not self.dbRoot.profiles or not self.dbRoot.profiles[name] then return nil end
    local payload = {
        schema = DB_SCHEMA_VERSION,
        profile = name,
        data = self.dbRoot.profiles[name],
    }
    return "PCBPROFILE1|" .. SerializeTable(payload)
end

function PCB:ImportProfile(str, newName)
    self:InitDB()
    if type(str) ~= "string" then return false, "Invalid import string." end
    local prefix, body = str:match("^(PCBPROFILE1|PCBPROFILE0)%|(.*)$")
    if not prefix or not body then return false, "Invalid import string." end
    local payload = DeserializeTable(body)
    if not payload or type(payload.data) ~= "table" then return false, "Import data could not be parsed." end
    local name = newName or payload.profile or "Imported"
    name = tostring(name):sub(1, 32)
    self.dbRoot.profiles[name] = payload.data
    return true, name
end

function PCB:SetProfileMode(mode)
    self:InitDB()
    if mode ~= "character" and mode ~= "spec" then return end
    self.dbRoot.profileMode = mode
    self:SelectActiveProfile()
end

function PCB:GetProfileMode()
    self:InitDB()
    return self.dbRoot.profileMode or "character"
end

function PCB:EnsureProfile(name)
    self.dbRoot.profiles[name] = self.dbRoot.profiles[name] or deepcopy(defaults)
end

function PCB:GetActiveProfileName()
    self:InitDB()
    return self.dbRoot._activeProfile or "Default"
end

function PCB:SetActiveProfileName(name)
    self:InitDB()
    if not self.dbRoot.profiles[name] then return end
    local charKey = GetCharKey()
    self.dbRoot.chars[charKey] = self.dbRoot.chars[charKey] or { profile = "Default", specProfiles = {} }
    local c = self.dbRoot.chars[charKey]
    if self:GetProfileMode() == "spec" then
        local specID = GetCurrentSpecID()
        if specID then
            c.specProfiles[specID] = name
        else
            c.profile = name
        end
    else
        c.profile = name
    end
    self:SelectActiveProfile()
end

function PCB:ResetProfile()
    self:InitDB()
    local profileName = self:GetActiveProfileName()
    if profileName then
        self.dbRoot.profiles[profileName] = deepcopy(defaults)
        self:SelectActiveProfile()
        self:ApplyAll()
    end
end

function PCB:SelectActiveProfile()
    local charKey = GetCharKey()
    self.dbRoot.chars[charKey] = self.dbRoot.chars[charKey] or { profile = "Default", specProfiles = {} }
    local c = self.dbRoot.chars[charKey]
    local mode = self:GetProfileMode()
    local profileName = c.profile or "Default"
    if mode == "spec" then
        local specID = GetCurrentSpecID()
        if specID and c.specProfiles and c.specProfiles[specID] then
            profileName = c.specProfiles[specID]
        end
    end
    if not self.dbRoot.profiles[profileName] then
        profileName = "Default"
        self:EnsureProfile(profileName)
    end
    self.dbRoot._activeProfile = profileName
    self.db = self.dbRoot.profiles[profileName]
end

>>>>>>> 9671a60 (Release v0.3.4 / update files)
function PCB:RegisterMedia()
    if not self.LSM or not self.LSM.Register then return end

    -- Register custom textures
    self.LSM:Register("statusbar", "Phoenix CastBar", "Interface\\AddOns\\PhoenixCastBars\\Media\\Phoenix_CastBar.tga")
    self.LSM:Register("statusbar", "Phoenix Feather", "Interface\\AddOns\\PhoenixCastBars\\Media\\Phoenix_Feather.tga")

    -- Refresh when new media is registered by other addons
    self.LSM.RegisterCallback(self, "LibSharedMedia_Registered", function(_, mediatype)
        if mediatype == "statusbar" or mediatype == "font" then
<<<<<<< HEAD
            self:ApplyAll()
=======
            if self.ApplyAll then
                self:ApplyAll()
            end
>>>>>>> 9671a60 (Release v0.3.4 / update files)
        end
    end)
end

function PCB:InitDB()
<<<<<<< HEAD
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
=======
if self._initDB then return end
self._initDB = true
    -- Migrate legacy flat DB into profile schema
    if type(PhoenixCastBarsDB) ~= "table" then
        PhoenixCastBarsDB = { schema = DB_SCHEMA_VERSION, profileMode = "character", profiles = { Default = deepcopy(defaults) }, chars = {} }
    end
    -- Detect legacy schema (flat keys like hideBlizzardCastBars)
    if PhoenixCastBarsDB.hideBlizzardCastBars ~= nil then
        local legacy = PhoenixCastBarsDB
        PhoenixCastBarsDB = { schema = DB_SCHEMA_VERSION, profileMode = "character", profiles = { Default = legacy }, chars = {} }
    end
    PhoenixCastBarsDB.schema = PhoenixCastBarsDB.schema or DB_SCHEMA_VERSION
    PhoenixCastBarsDB.profiles = PhoenixCastBarsDB.profiles or { Default = deepcopy(defaults) }
    PhoenixCastBarsDB.chars = PhoenixCastBarsDB.chars or {}
    -- Ensure Default profile exists and has defaults merged
    PhoenixCastBarsDB.profiles.Default = PhoenixCastBarsDB.profiles.Default or deepcopy(defaults)
    mergeDefaults(PhoenixCastBarsDB.profiles.Default, defaults)
    self.dbRoot = PhoenixCastBarsDB
    self:SelectActiveProfile()
    -- Migrate old path-based keys inside active profile
    local db = self.db
    if db.texture and not db.textureKey then
        if type(db.texture) == "string" and (db.texture:find("\\") or db.texture:find("/")) then
            db.textureKey = "Custom"; db.texturePath = db.texture
        else
            db.textureKey = db.texture
        end
    end
    if db.font and not db.fontKey then
        if type(db.font) == "string" and (db.font:find("\\") or db.font:find("/")) then
            db.fontKey = "Custom"; db.fontPath = db.font
        else
            db.fontKey = db.font
        end
    end
    db.textureKey = db.textureKey or "Blizzard"
    db.fontKey    = db.fontKey or "Friz Quadrata (Default)"
    db.texturePath = db.texturePath or "Interface\\TARGETINGFRAME\\UI-StatusBar"
    db.fontPath    = db.fontPath or "Fonts\\FRIZQT__.TTF"
    db.texture = (db.textureKey == "Custom") and db.texturePath or db.textureKey
    db.font    = (db.fontKey == "Custom") and db.fontPath or db.fontKey
    self._initDB = false

>>>>>>> 9671a60 (Release v0.3.4 / update files)
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

<<<<<<< HEAD
=======
function PCB:CreateMinimapButton()
    if not self.LDBIcon then
        self:Print("LibDBIcon not loaded - minimap button unavailable")
        return
    end
    
    -- Create LibDataBroker data object
    local LDB = LibStub("LibDataBroker-1.1", true)
    if not LDB then
        self:Print("LibDataBroker not loaded - minimap button unavailable")
        return
    end
    
    self.minimapLDB = LDB:NewDataObject("PhoenixCastBars", {
        type = "launcher",
        text = "PhoenixCastBars",
        icon = "Interface\\AddOns\\PhoenixCastBars\\Media\\Phoenix_Feather.tga",
        OnClick = function(_, button)
            if button == "LeftButton" then
                if PCB.Options and PCB.Options.Open then
                    PCB.Options:Open()
                end
            elseif button == "RightButton" then
                PCB.db.locked = not PCB.db.locked
                PCB:ApplyAll()
                PCB:Print(PCB.db.locked and "Frames locked." or "Frames unlocked. Drag to move.")
            end
        end,
        OnTooltipShow = function(tooltip)
            if not tooltip or not tooltip.AddLine then return end
            tooltip:SetText("PhoenixCastBars", 1, 1, 1)
            tooltip:AddLine("Left-click to open options", 0.2, 1, 0.2)
            tooltip:AddLine("Right-click to toggle lock", 0.2, 1, 0.2)
        end,
    })
    
    -- Register with LibDBIcon
    self.LDBIcon:Register("PhoenixCastBars", self.minimapLDB, self.db.minimapButton)
    self:UpdateMinimapButton()
end

function PCB:UpdateMinimapButton()
    if not self.LDBIcon then return end
    
    if self.db and self.db.minimapButton and self.db.minimapButton.show then
        self.LDBIcon:Show("PhoenixCastBars")
    else
        self.LDBIcon:Hide("PhoenixCastBars")
    end
end

>>>>>>> 9671a60 (Release v0.3.4 / update files)
-- Slash
local function SlashHandler(msg)
    msg = strtrim(strlower(msg or ""))
    if msg == "lock" or msg == "locked" then
        PCB.db.locked = true
<<<<<<< HEAD
        PCB:ApplyAll()
        PCB:Print("Frames locked.")
    elseif msg == "unlock" then
        PCB.db.locked = false
        PCB:ApplyAll()
=======
        if PCB.ApplyAll then
            PCB:ApplyAll()
        end
        PCB:Print("Frames locked.")
    elseif msg == "unlock" then
        PCB.db.locked = false
        if PCB.ApplyAll then
            PCB:ApplyAll()
        end
>>>>>>> 9671a60 (Release v0.3.4 / update files)
        PCB:Print("Frames unlocked. Drag to move.")
    elseif msg == "reset" then
        PhoenixCastBarsDB = nil
        ReloadUI()
<<<<<<< HEAD
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
=======
    elseif msg == "resetpos" or msg == "resetpositions" then
        if PCB.ResetPositions then
            PCB:ResetPositions()
            PCB:Print("All cast bar positions reset to defaults.")
        end
    elseif msg == "test" then
        if PCB.SetTestMode then
            local newState = not PCB.testMode
            PCB:SetTestMode(newState)
            PCB:Print(newState and "Test mode enabled" or "Test mode disabled")
        end
>>>>>>> 9671a60 (Release v0.3.4 / update files)
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
<<<<<<< HEAD
        -- Diagnostic: print addon metadata and whether it's listed by the client
=======
        -- Diagnostic: Lists addon registration info for troubleshooting
>>>>>>> 9671a60 (Release v0.3.4 / update files)
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
<<<<<<< HEAD
        -- Ensure the options module is initialized and attempt to open it
        if PCB.Options and PCB.Options.Open then
            PCB.Options:Open()
        else
            PCB:Print("Options UI loading… please run /pcb again in a moment.")
=======
        if PCB.Options and PCB.Options.Open then
            PCB.Options:Open()
        else
            PCB:Print("Options UI failed to open. It may not be loaded yet.")
>>>>>>> 9671a60 (Release v0.3.4 / update files)
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
<<<<<<< HEAD
=======
        PCB:CreateMinimapButton()
>>>>>>> 9671a60 (Release v0.3.4 / update files)
        if PCB.Options and PCB.Options.Init then PCB.Options:Init() end
        PCB:ApplyAll()
        PCB:Print(("Loaded v%s. Type /pcb to open settings."):format(PCB.version))
    end
end)
