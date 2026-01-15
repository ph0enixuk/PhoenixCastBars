-- PhoenixCastBars.lua
-- Core addon bootstrap for PhoenixCastBars (Retail).
-- Provides DB defaults, slash commands, shared helpers, and module wiring.

local ADDON_NAME, PCB = ...

PCB.name = ADDON_NAME
PCB.version = "0.2.0"


-- ============================================================
-- Blizzard Cast Bar Suppression
-- ============================================================
PCB._blizzardBars = PCB._blizzardBars or {}

local function GetBlizzardCastBars()
    -- Retail 11.2.7 cast bar frames (player/target/focus + vehicle/override variants)
    return {
        _G.PlayerCastingBarFrame,          -- Player
        _G.TargetFrameSpellBar,            -- Target
        _G.FocusFrameSpellBar,             -- Focus
        _G.PetCastingBarFrame,             -- Pet (optional)

        _G.VehicleCastingBarFrame,         -- Vehicle casts (some mount/vehicle states)
        _G.OverrideActionBarSpellBar,      -- Override action bar spell bar (vehicles/possess)
    }
end

function PCB:DisableBlizzardCastBars()
    for _, bar in ipairs(GetBlizzardCastBars()) do
        if bar and not self._blizzardBars[bar] then
            -- Cache original functions/scripts so we can restore live if user unticks the option.
            self._blizzardBars[bar] = {
                Show = bar.Show,
                RegisterEvent = bar.RegisterEvent,
                RegisterUnitEvent = bar.RegisterUnitEvent,
                UnregisterEvent = bar.UnregisterEvent,
                UnregisterAllEvents = bar.UnregisterAllEvents,
                onShow = bar:GetScript("OnShow"),
                onEvent = bar:GetScript("OnEvent"),
            }

            -- Stop updates and prevent it being re-enabled by other UI systems.
            bar:UnregisterAllEvents()
            bar:SetScript("OnEvent", nil)

            -- Force-hide on any attempted show.
            bar:SetScript("OnShow", function(selfFrame) selfFrame:Hide() end)
            bar:Hide()

            -- Block re-registering events while PhoenixCastBars is enabled.
            bar.RegisterEvent = function() end
            bar.RegisterUnitEvent = function() end

            -- Redirect Show() to Hide() so direct calls won't bring it back.
            bar.Show = bar.Hide
        end
    end
end

function PCB:EnableBlizzardCastBars()
    for bar, info in pairs(self._blizzardBars or {}) do
        if bar and info then
            -- Restore original methods/scripts.
            bar.Show = info.Show
            bar.RegisterEvent = info.RegisterEvent
            bar.RegisterUnitEvent = info.RegisterUnitEvent
            bar.UnregisterEvent = info.UnregisterEvent
            bar.UnregisterAllEvents = info.UnregisterAllEvents
            bar:SetScript("OnShow", info.onShow)
            bar:SetScript("OnEvent", info.onEvent)

            -- Let Blizzard manage visibility again.
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

-- Re-apply suppression on common lifecycle events because Blizzard may create/show frames after login.
PCB._blizzBarWatcher = PCB._blizzBarWatcher or CreateFrame("Frame")
PCB._blizzBarWatcher:UnregisterAllEvents()
PCB._blizzBarWatcher:RegisterEvent("PLAYER_ENTERING_WORLD")
PCB._blizzBarWatcher:RegisterEvent("UI_SCALE_CHANGED")
PCB._blizzBarWatcher:RegisterEvent("ADDON_LOADED") -- catch Blizzard UI modules loading after us
PCB._blizzBarWatcher:RegisterUnitEvent("UNIT_SPELLCAST_START", "player", "vehicle")
PCB._blizzBarWatcher:RegisterUnitEvent("UNIT_SPELLCAST_CHANNEL_START", "player", "vehicle")
PCB._blizzBarWatcher:SetScript("OnEvent", function(_, event, arg1)
    if PCB and PCB.db and PCB.db.hideBlizzardCastBars then
        -- Only care about Blizzard UI modules; still safe if arg1 is nil.
        if event ~= "ADDON_LOADED" or (type(arg1) == "string" and arg1:match("^Blizzard_")) then
            PCB:DisableBlizzardCastBars()
        end
    end
end)


-- ============================================================
-- SavedVariables / Defaults
-- ============================================================
local defaults = {
    hideBlizzardCastBars = true,

    profile = {
        locked = false,

        -- Global appearance
        texture = "Interface\\TARGETINGFRAME\\UI-StatusBar",
        font = "Fonts\\FRIZQT__.TTF",
        fontSize = 12,
        outline = "OUTLINE", -- "", "OUTLINE", "THICKOUTLINE"

        showIcon = true,
        showSpark = true,
        showTime = true,
        showSpellName = true,
        showLatency = true, -- player only
        showInterruptShield = true, -- show not-interruptible indicator

        -- Colors
        colorCast = { r = 0.24, g = 0.56, b = 0.95, a = 1.0 },
        colorChannel = { r = 0.35, g = 0.90, b = 0.55, a = 1.0 },
        colorFailed = { r = 0.85, g = 0.25, b = 0.25, a = 1.0 },
        colorNonInterruptible = { r = 0.85, g = 0.75, b = 0.25, a = 1.0 },
        safeZoneColor = { r = 1.0, g = 0.2, b = 0.2, a = 0.35 },

        -- Per-bar settings
        bars = {
            player = {
                enabled = true,
                width = 260,
                height = 18,
                point = "CENTER",
                relPoint = "CENTER",
                x = 0,
                y = -180,
                alpha = 1.0,
                scale = 1.0,
            },
            target = {
                enabled = true,
                width = 240,
                height = 16,
                point = "CENTER",
                relPoint = "CENTER",
                x = 0,
                y = -140,
                alpha = 1.0,
                scale = 1.0,
            },
            focus = {
                enabled = false,
                width = 240,
                height = 16,
                point = "CENTER",
                relPoint = "CENTER",
                x = 0,
                y = -110,
                alpha = 1.0,
                scale = 1.0,
            },
        },
    },
}

local function deepcopy(src)
    if type(src) ~= "table" then return src end
    local out = {}
    for k, v in pairs(src) do
        out[k] = deepcopy(v)
    end
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

function PCB:InitDB()
    if type(PhoenixCastBarsDB) ~= "table" then
        PhoenixCastBarsDB = deepcopy(defaults)
    else
        mergeDefaults(PhoenixCastBarsDB, defaults)
    end

    -- For now, single-profile design (simple + robust).
    PCB.db = PhoenixCastBarsDB.profile
end

-- ============================================================
-- Printing
-- ============================================================
function PCB:Print(msg)
    DEFAULT_CHAT_FRAME:AddMessage(("|cff66c0ffPhoenixCastBars|r: %s"):format(tostring(msg)))
end

-- ============================================================
-- Helpers
-- ============================================================
function PCB:ApplyFont(fs)
    if not fs then return end
    local db = self.db
    local flags = db.outline or "OUTLINE"
    if flags == "NONE" then flags = "" end
    fs:SetFont(db.font, db.fontSize, flags)
end

function PCB:ColorFromTable(t)
    return t.r or 1, t.g or 1, t.b or 1, t.a or 1
end

-- ============================================================
-- Slash commands
-- ============================================================
local function SlashHandler(msg)
    msg = (msg or ""):lower():gsub("^%s+", ""):gsub("%s+$", "")
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
    else
        -- Open Blizzard Settings / Interface Options panel.
        if PCB.Options and PCB.Options.Open then
            PCB.Options:Open()
        else
            PCB:Print("Options UI not yet available. Try /reload.")
        end
    end
end

SLASH_PHOENIXCASTBARS1 = "/pcb"
SlashCmdList["PHOENIXCASTBARS"] = SlashHandler

-- ============================================================
-- Events / Lifecycle
-- ============================================================
local f = CreateFrame("Frame")
f:RegisterEvent("ADDON_LOADED")
f:RegisterEvent("PLAYER_LOGIN")

f:SetScript("OnEvent", function(_, event, arg1)
    if event == "ADDON_LOADED" and arg1 == ADDON_NAME then
        PCB:InitDB()
    elseif event == "PLAYER_LOGIN" then
        if PCB.UpdateCheck and PCB.UpdateCheck.Init then PCB.UpdateCheck:Init() end
        -- Create cast bars
        PCB:CreateBars()
        if PCB.Options and PCB.Options.Init then PCB.Options:Init() end
        PCB:ApplyAll()
        PCB:Print(("Loaded v%s. Type /pcb to open settings."):format(PCB.version))
    end
end)
