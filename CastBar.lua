
local function EnsureTextOverlay(f)
    -- Create an overlay frame above the StatusBar so mover texts are always visible.
    if not f.textOverlay then
        f.textOverlay = CreateFrame("Frame", nil, f)
        f.textOverlay:SetAllPoints(f.bar or f)
        local lvl = 0
        if f.bar and f.bar.GetFrameLevel then
            lvl = f.bar:GetFrameLevel()
        else
            lvl = f:GetFrameLevel()
        end
        f.textOverlay:SetFrameLevel(lvl + 10)
        f.textOverlay:SetFrameStrata("DIALOG")
    end
    f.textOverlay:Show()
    return f.textOverlay
end

local function EnsureMoverText(f)
    -- Center mover text (shown only while unlocked)
    local overlay = EnsureTextOverlay(f)

    -- Older builds may have created these FontStrings on f (behind the StatusBar). FontStrings cannot be re-parented,
    -- so if the parent is wrong we recreate them on the overlay.
    if f.dragText and f.dragText.GetParent and f.dragText:GetParent() ~= overlay then
        f.dragText:Hide()
        f.dragText = nil
    end

    if not f.dragText then
        f.dragText = overlay:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        f.dragText:SetPoint("CENTER", overlay, "CENTER", 0, 0)
        f.dragText:SetJustifyH("CENTER")
    end

    f.dragText:SetFontObject("GameFontHighlightSmall")
    if f.dragText.SetDrawLayer then f.dragText:SetDrawLayer("OVERLAY", 7) end
    f.dragText:SetAlpha(1)

    return f.dragText
end


local function EnsureUnitLabel(f)
    local overlay = EnsureTextOverlay(f)

    if f.unitLabel and f.unitLabel.GetParent and f.unitLabel:GetParent() ~= overlay then
        f.unitLabel:Hide()
        f.unitLabel = nil
    end

    if not f.unitLabel then
        f.unitLabel = overlay:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        f.unitLabel:SetPoint("TOPLEFT", overlay, "TOPLEFT", 6, -4)
        f.unitLabel:SetJustifyH("LEFT")
        f.unitLabel:SetTextColor(0.80, 0.86, 0.98, 1.0)
    end

    f.unitLabel:SetFontObject("GameFontNormalSmall")
    if f.unitLabel.SetDrawLayer then f.unitLabel:SetDrawLayer("OVERLAY", 7) end
    f.unitLabel:SetAlpha(1)

    return f.unitLabel
end


-- ============================================================================
-- Mover preview (namespaced to avoid scope collisions)
-- ============================================================================
local function PCB_ShowMover(f)
    f:Show()

    if f.bar then
        f.bar:SetMinMaxValues(0, 1)
        f.bar:SetValue(0.75)
    end

    -- Clear normal cast texts; mover uses dragText + unitLabel
    if f.spellText then f.spellText:SetText("") end
    if f.timeText then f.timeText:SetText("") end

    local overlay = EnsureTextOverlay(f)


    if not f.pcbTextBg then
        f.pcbTextBg = overlay:CreateTexture(nil, "BACKGROUND")
        f.pcbTextBg:SetAllPoints(overlay)
        f.pcbTextBg:SetColorTexture(0, 0, 0, 0.35)
        f.pcbTextBg:Hide()
    end

    local dt = EnsureMoverText(f)
    dt:SetText("Drag to move")
    if f.pcbTextBg then f.pcbTextBg:Show() end
    dt:Show()

    local ul = EnsureUnitLabel(f)
    local key = f.key or ""
    local label = key:upper()
    if key == "player" then label = "PLAYER"
    elseif key == "target" then label = "TARGET"
    elseif key == "focus" then label = "FOCUS"
    end
    ul:SetText(label)
    ul:Show()

    if f.icon then
        f.icon:SetTexture(nil)
        f.icon:SetShown(false)
    end
    if f.shield then f.shield:SetShown(false) end
    if f.safeZone then f.safeZone:SetShown(false) end
    if f.spark then f.spark:SetShown(false) end
end

local function PCB_HideMover(f)
    if f.dragText then
        f.dragText:SetText("")
        f.dragText:Hide()
    end
    if f.pcbTextBg then f.pcbTextBg:Hide() end
    if f.unitLabel then
        f.unitLabel:SetText("")
        f.unitLabel:Hide()
    end
end

local function PCB_SetMoverMode(f, enabled)
    f.isMover = enabled and true or false
    if f.isMover then
        PCB_ShowMover(f)
    else
        PCB_HideMover(f)
    end
end


local ShowMover, HideMover -- forward declarations
local SetMoverMode -- forward declaration

-- CastBar.lua
-- Implements Quartz-like cast bars (player/target/focus) with Phoenix styling.

local ADDON_NAME, PCB = ...

PCB.Bars = PCB.Bars or {}

-- Units we support
local BAR_UNITS = {
    player = "player",
    target = "target",
    focus  = "focus",
}

-- Spellcast events we care about
local EVENTS = {
    "UNIT_SPELLCAST_START",
    "UNIT_SPELLCAST_STOP",
    "UNIT_SPELLCAST_FAILED",
    "UNIT_SPELLCAST_INTERRUPTED",
    "UNIT_SPELLCAST_DELAYED",
    "UNIT_SPELLCAST_CHANNEL_START",
    "UNIT_SPELLCAST_CHANNEL_STOP",
    "UNIT_SPELLCAST_CHANNEL_UPDATE",
    "UNIT_SPELLCAST_INTERRUPTIBLE",
    "UNIT_SPELLCAST_NOT_INTERRUPTIBLE",
    "PLAYER_TARGET_CHANGED",
    "PLAYER_FOCUS_CHANGED",
    "PLAYER_ENTERING_WORLD",
    "UNIT_SPELLCAST_SUCCEEDED", -- used to clear some edge cases
    "UNIT_SPELLCAST_EMPOWER_START",
    "UNIT_SPELLCAST_EMPOWER_UPDATE",
    "UNIT_SPELLCAST_EMPOWER_STOP",
}

local function msToSec(ms) return ms and (ms / 1000) or 0 end

local function clamp(v, lo, hi)
    if v < lo then return lo end
    if v > hi then return hi end
    return v
end

-- ============================================================
-- Frame construction
-- ============================================================
local function CreateBackdrop(parent)
    local bg = CreateFrame("Frame", nil, parent, BackdropTemplateMixin and "BackdropTemplate" or nil)
    bg:SetPoint("TOPLEFT", parent, "TOPLEFT", -2, 2)
    bg:SetPoint("BOTTOMRIGHT", parent, "BOTTOMRIGHT", 2, -2)
    bg:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8x8",
        edgeFile = "Interface\\Buttons\\WHITE8x8",
        edgeSize = 1,
        insets = { left = 1, right = 1, top = 1, bottom = 1 },
    })
    bg:SetBackdropColor(0.06, 0.06, 0.08, 0.85)
    bg:SetBackdropBorderColor(0.20, 0.20, 0.25, 0.95)
    return bg
end

local function CreateCastBarFrame(key)
    local f = CreateFrame("Frame", "PhoenixCastBars_" .. key, UIParent)
    f:SetClampedToScreen(true)
    f:SetMovable(true)

    -- PCB_SAFE_DRAG: robust mover behavior (prevents frames "sticking" to the mouse)
    -- Dragging requires ALT to avoid accidental grabs while clicking UI.
    f:SetScript("OnDragStart", function(self) end)
    f:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
    end)
    f:SetScript("OnMouseUp", function(self)
        self:StopMovingOrSizing()
    end)
    f:SetScript("OnHide", function(self)
        self:StopMovingOrSizing()
    end)
    f:EnableMouse(true)

    f.bg = CreateBackdrop(f)

    -- Status bar
    f.bar = CreateFrame("StatusBar", nil, f)
    f.bar:SetPoint("TOPLEFT", f, "TOPLEFT", 0, 0)
    f.bar:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", 0, 0)
    f.bar:SetMinMaxValues(0, 1)
    f.bar:SetValue(0)

    f.bar.bgTex = f.bar:CreateTexture(nil, "BACKGROUND")
    f.bar.bgTex:SetAllPoints(f.bar)
    f.bar.bgTex:SetTexture("Interface\\Buttons\\WHITE8x8")
    f.bar.bgTex:SetVertexColor(0, 0, 0, 0.35)

    -- Safe zone (latency) - player only (but we create for all for simplicity)
    f.safeZone = f.bar:CreateTexture(nil, "ARTWORK")
    f.safeZone:SetTexture("Interface\\Buttons\\WHITE8x8")
    f.safeZone:SetPoint("TOPRIGHT", f.bar, "TOPRIGHT", 0, 0)
    f.safeZone:SetPoint("BOTTOMRIGHT", f.bar, "BOTTOMRIGHT", 0, 0)
    f.safeZone:SetWidth(0)
    f.safeZone:Hide()

    -- Spark
    f.spark = f.bar:CreateTexture(nil, "OVERLAY")
    f.spark:SetTexture("Interface\\CastingBar\\UI-CastingBar-Spark")
    f.spark:SetBlendMode("ADD")
    f.spark:SetWidth(16)
    f.spark:SetHeight(28)
    f.spark:Hide()

    -- Icon
    f.icon = f:CreateTexture(nil, "OVERLAY")
    f.icon:SetSize(20, 20)
    f.icon:SetPoint("RIGHT", f, "LEFT", -6, 0)
    f.icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)
    f.icon:Hide()

    -- Spell name
    f.spellText = f.bar:CreateFontString(nil, "OVERLAY")
    f.spellText:SetJustifyH("LEFT")
    f.spellText:SetPoint("LEFT", f.bar, "LEFT", 6, 0)
    -- Ensure a font is set immediately to avoid "Font not set" errors
    do
        local font, size, flags = GameFontHighlightSmall:GetFont()
        f.spellText:SetFont(font, size or 12, flags)
    end

    -- Time
    f.timeText = f.bar:CreateFontString(nil, "OVERLAY")
    f.timeText:SetJustifyH("RIGHT")
    f.timeText:SetPoint("RIGHT", f.bar, "RIGHT", -6, 0)
    do
        local font, size, flags = GameFontHighlightSmall:GetFont()
        f.timeText:SetFont(font, size or 12, flags)
    end

    -- Drag handle overlay (visible when unlocked)
    f.dragText = f:CreateFontString(nil, "OVERLAY")
    f.dragText:SetPoint("CENTER", f, "CENTER", 0, 0)
    do
        local font, size, flags = GameFontNormal:GetFont()
        f.dragText:SetFont(font, (size or 12) + 2, flags)
    end
    f.dragText:SetTextColor(1, 1, 1, 0.6)
    f.dragText:Hide()

    -- Mover: drag logic (cannot get "stuck" to cursor)
    f:SetScript("OnMouseDown", function(self, button)
        if button ~= "LeftButton" then return end
        if PCB.db and PCB.db.locked then return end
        -- Require ALT to prevent accidental grabs while clicking UI
        if not IsAltKeyDown() then return end
        self._pcbMoving = true
        self:StartMoving()
    end)

    f:SetScript("OnMouseUp", function(self, button)
        if button ~= "LeftButton" then return end
        if self._pcbMoving then
            self._pcbMoving = nil
            self:StopMovingOrSizing()
            PCB:SavePosition(key, self)
        end
    end)

    -- Safety stop: if a Lua error happens mid-drag (or mouseup occurs elsewhere), never stay attached to cursor.
    f:SetScript("OnUpdate", function(self)
        if self._pcbMoving and not IsMouseButtonDown("LeftButton") then
            self._pcbMoving = nil
            self:StopMovingOrSizing()
        end
    end)

    f:Hide()
    
    f.unitLabel = f:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    f.unitLabel:SetPoint("TOPLEFT", f.bg or f, "TOPLEFT", 6, -4)
    f.unitLabel:Hide()

return f
end

-- ============================================================
-- Cast state & updates
-- ============================================================
local function ResetState(f)
    f.cast = nil
    f.channel = nil
    f.empower = nil

    f.bar:SetValue(0)
    f.timeText:SetText("")
    f.spellText:SetText("")
    f.icon:Hide()
    f.spark:Hide()
    f.safeZone:Hide()
    if f.shield then f.shield:Hide() end

    -- When locked, keep bars hidden while idle. When unlocked, we allow a mover preview.
    if PCB.db and PCB.db.locked then
        f:Hide()
    end
    if f.shield then f.shield:Hide() end
    f:Hide()
end

ShowMover = function(f)
    f:Show()

    if f.bar then
        f.bar:SetMinMaxValues(0, 1)
        f.bar:SetValue(0.75)
    end

    -- Clear normal cast text; mover uses dragText + unitLabel
    if f.spellText then f.spellText:SetText("") end
    if f.timeText then f.timeText:SetText("") end

    local overlay = EnsureTextOverlay(f)


    if not f.pcbTextBg then
        f.pcbTextBg = overlay:CreateTexture(nil, "BACKGROUND")
        f.pcbTextBg:SetAllPoints(overlay)
        f.pcbTextBg:SetColorTexture(0, 0, 0, 0.35)
        f.pcbTextBg:Hide()
    end

    local dt = EnsureMoverText(f)
    dt:SetText("Drag to move")
    if f.pcbTextBg then f.pcbTextBg:Show() end
    dt:Show()

    local ul = EnsureUnitLabel(f)
    local key = f.key or ""
    local label = key:upper()
    if key == "player" then label = "PLAYER"
    elseif key == "target" then label = "TARGET"
    elseif key == "focus" then label = "FOCUS"
    end
    ul:SetText(label)
    ul:Show()

    if f.icon then
        f.icon:SetTexture(nil)
        f.icon:SetShown(false)
    end
    if f.shield then f.shield:SetShown(false) end
    if f.safeZone then f.safeZone:SetShown(false) end
    if f.spark then f.spark:SetShown(false) end
end

local function SetBarColor(f, mode)
    local db = PCB.db
    local c
    if mode == "channel" then
        c = db.colorChannel
    elseif mode == "failed" then
        c = db.colorFailed
    elseif mode == "noninterrupt" then
        c = db.colorNonInterruptible
    else
        c = db.colorCast
    end
    f.bar:SetStatusBarColor(PCB:ColorFromTable(c))
end

local function ApplySpark(f, pct)
    if not PCB.db.showSpark then
        f.spark:Hide()
        return
    end

    pct = clamp(pct or 0, 0, 1)
    local w = f.bar:GetWidth()
    local x = w * pct

    f.spark:ClearAllPoints()
    f.spark:SetPoint("CENTER", f.bar, "LEFT", x, 0)
    f.spark:Show()
end

local function UpdateTexts(f, remaining, duration)
    local db = PCB.db

    if db.showSpellName then
        f.spellText:SetText(f.spellName or "")
    else
        f.spellText:SetText("")
    end

    if db.showTime then
        if remaining and duration and duration > 0 then
            f.timeText:SetFormattedText("%.1f / %.1f", remaining, duration)
        else
            f.timeText:SetText("")
        end
    else
        f.timeText:SetText("")
    end
end

local function UpdateSafeZone_Player(f, duration)
    local db = PCB.db
    if not db.showLatency or f.unit ~= "player" or not f.cast then
        f.safeZone:Hide()
        return
    end

    -- Determine latency in seconds using SENT timestamp if available.
    local sent = f.cast.sentTime
    if not sent or duration <= 0 then
        f.safeZone:Hide()
        return
    end

    local startMS = f.cast.startTimeMS or 0
    local latencyMS = startMS - sent
    if latencyMS <= 0 then
        f.safeZone:Hide()
        return
    end

    local pct = clamp(msToSec(latencyMS) / duration, 0, 1)
    local w = f.bar:GetWidth()
    f.safeZone:SetWidth(w * pct)
    f.safeZone:SetVertexColor(PCB:ColorFromTable(db.safeZoneColor))
    f.safeZone:Show()
end

local function UpdateInterruptShield(f)
    if not f or not f.shield then return end
    local db = PCB.db
    if not db.showInterruptShield then
        if f.shield then f.shield:Hide() end
        return
    end

    local ni = f.notInterruptible
    if ni then
        f.shield:Show()
    else
        if f.shield then f.shield:Hide() end
    end
end

local function UpdateBar(f)
    if not f:IsShown() then return end

    local now = GetTime()
    local db = PCB.db

    if f.cast then
        local startT = msToSec(f.cast.startTimeMS)
        local endT = msToSec(f.cast.endTimeMS)
        local duration = endT - startT
        local elapsed = now - startT
        local remaining = (endT - now)

        if duration <= 0 or remaining <= 0 then
            ResetState(f)
            return
        end

        f.bar:SetMinMaxValues(0, duration)
        f.bar:SetValue(elapsed)

        local pct = elapsed / duration
        ApplySpark(f, pct)
        UpdateSafeZone_Player(f, duration)
        UpdateInterruptShield(f)
        UpdateTexts(f, remaining, duration)
        return
    end

    if f.channel then
        local startT = msToSec(f.channel.startTimeMS)
        local endT = msToSec(f.channel.endTimeMS)
        local duration = endT - startT
        local remaining = endT - now
        local elapsed = duration - remaining

        if duration <= 0 or remaining <= 0 then
            ResetState(f)
            return
        end

        f.bar:SetMinMaxValues(0, duration)
        f.bar:SetValue(remaining) -- channel counts down for the bar itself

        local pct = (duration - remaining) / duration
        ApplySpark(f, 1 - pct) -- spark from right-to-left visually
        f.safeZone:Hide() -- latency safe zone not meaningful for channel
        UpdateInterruptShield(f)
        UpdateTexts(f, remaining, duration)
        return
    end

    if f.empower then
        -- Empower casts have stages. We'll treat it like a normal cast with extra stage markers in future.
        local startT = msToSec(f.empower.startTimeMS)
        local endT = msToSec(f.empower.endTimeMS)
        local duration = endT - startT
        local elapsed = now - startT
        local remaining = endT - now

        if duration <= 0 or remaining <= 0 then
            ResetState(f)
            return
        end

        f.bar:SetMinMaxValues(0, duration)
        f.bar:SetValue(elapsed)

        local pct = elapsed / duration
        ApplySpark(f, pct)
        f.safeZone:Hide()
        UpdateInterruptShield(f)
        UpdateTexts(f, remaining, duration)
        return
    end
end

-- ============================================================
-- Event handlers
-- ============================================================
local function StartCast(f, unit, castGUID)
    local name, text, texture, startTimeMS, endTimeMS, isTradeSkill, castID, notInterruptible, spellID =
        UnitCastingInfo(unit)

    if not name then
        ResetState(f)
        return
    end

    f.cast = {
        startTimeMS = startTimeMS,
        endTimeMS = endTimeMS,
        spellID = spellID,
    }
    f.channel = nil
    f.empower = nil

    f.spellName = name
    f.notInterruptible = notInterruptible

    -- Icon
    if PCB.db.showIcon and texture then
        f.icon:SetTexture(texture)
        f.icon:Show()
    else
        f.icon:Hide()
    end

    SetBarColor(f, f.notInterruptible and "noninterrupt" or "cast")
    UpdateInterruptShield(f)

    f:Show()
end

local function StartChannel(f, unit)
    local name, text, texture, startTimeMS, endTimeMS, isTradeSkill, notInterruptible, spellID =
        UnitChannelInfo(unit)

    if not name then
        ResetState(f)
        return
    end

    f.channel = {
        startTimeMS = startTimeMS,
        endTimeMS = endTimeMS,
        spellID = spellID,
    }
    f.cast = nil
    f.empower = nil

    f.spellName = name
    f.notInterruptible = notInterruptible

    if PCB.db.showIcon and texture then
        f.icon:SetTexture(texture)
        f.icon:Show()
    else
        f.icon:Hide()
    end

    SetBarColor(f, f.notInterruptible and "noninterrupt" or "channel")
    UpdateInterruptShield(f)

    f:Show()
end

local function StartEmpower(f, unit)
    if not UnitIsUnit(unit, f.unit) then return end
    local name, text, texture, startTimeMS, endTimeMS, isTradeSkill, castID, notInterruptible, spellID =
        UnitCastingInfo(unit) -- empower still reports in UnitCastingInfo for name/icon, while stages are separate APIs

    -- Empower-specific API is UnitEmpowerStart/Update events + UnitChannelInfo? varies; safest is to use UnitCastingInfo timing here.
    if not name then
        ResetState(f)
        return
    end

    f.empower = {
        startTimeMS = startTimeMS,
        endTimeMS = endTimeMS,
        spellID = spellID,
    }
    f.cast = nil
    f.channel = nil

    f.spellName = name
    f.notInterruptible = notInterruptible

    if PCB.db.showIcon and texture then
        f.icon:SetTexture(texture)
        f.icon:Show()
    else
        f.icon:Hide()
    end

    SetBarColor(f, f.notInterruptible and "noninterrupt" or "cast")
    UpdateInterruptShield(f)

    f:Show()
end

local function StopCasting(f, failed)
    if not f:IsShown() then return end
    if failed then
        SetBarColor(f, "failed")
        f.timeText:SetText("")
        -- Briefly show failed bar then hide
        C_Timer.After(0.4, function()
            if f and f:IsShown() then
                ResetState(f)
            end
        end)
    else
        ResetState(f)
    end
end

local function RefreshFromUnit(f, unit)
    -- Called on target/focus changes and entering world
    if unit == "player" or unit == "target" or unit == "focus" then
        -- Prefer cast over channel
        if UnitCastingInfo(unit) then
            StartCast(f, unit)
        elseif UnitChannelInfo(unit) then
            StartChannel(f, unit)
        else
            ResetState(f)
        end
    end
end

-- ============================================================
-- Public methods
-- ============================================================
function PCB:CreateBars()
    for key, unit in pairs(BAR_UNITS) do
        if not self.Bars[key] then
            local f = CreateCastBarFrame(key)
            f.key = key
            f.unit = unit
            f:SetScript("OnUpdate", function(self, _)
                UpdateBar(self)
            end)
            self.Bars[key] = f
        end
    end

    -- Global event router
    if not self.eventFrame then
        local ef = CreateFrame("Frame")
        for _, e in ipairs(EVENTS) do
            ef:RegisterEvent(e)
        end

        ef:SetScript("OnEvent", function(_, event, unit, castGUID, spellID)
            -- Some events are (event, unit, castGUID, spellID)
            -- Others are (event) only.
            if event == "PLAYER_TARGET_CHANGED" then
                RefreshFromUnit(PCB.Bars.target, "target")
                return
            elseif event == "PLAYER_FOCUS_CHANGED" then
                RefreshFromUnit(PCB.Bars.focus, "focus")
                return
            elseif event == "PLAYER_ENTERING_WORLD" then
                RefreshFromUnit(PCB.Bars.player, "player")
                RefreshFromUnit(PCB.Bars.target, "target")
                RefreshFromUnit(PCB.Bars.focus, "focus")
                return
            end

            if type(unit) ~= "string" then return end

            local f = (unit == "player" and PCB.Bars.player)
                or (unit == "target" and PCB.Bars.target)
                or (unit == "focus" and PCB.Bars.focus)

            if not f then return end
            if not PCB.db.bars[f.key].enabled then
                ResetState(f)
                return
            end

            if event == "UNIT_SPELLCAST_SENT" then
                -- Not registered in EVENTS by default; kept for completeness if you add it.
                return
            end

            if event == "UNIT_SPELLCAST_START" then
                StartCast(f, unit, castGUID)
            elseif event == "UNIT_SPELLCAST_STOP" then
                StopCasting(f, false)
            elseif event == "UNIT_SPELLCAST_FAILED" or event == "UNIT_SPELLCAST_INTERRUPTED" then
                StopCasting(f, true)
            elseif event == "UNIT_SPELLCAST_DELAYED" then
                if f.cast then
                    local name, _, texture, startTimeMS, endTimeMS, _, _, notInterruptible =
                        UnitCastingInfo(unit)
                    if name then
                        f.cast.startTimeMS = startTimeMS
                        f.cast.endTimeMS = endTimeMS
                        f.notInterruptible = notInterruptible
                        if PCB.db.showIcon and texture then
                            f.icon:SetTexture(texture)
                            f.icon:Show()
                        end
                    end
                end
            elseif event == "UNIT_SPELLCAST_CHANNEL_START" then
                StartChannel(f, unit)
            elseif event == "UNIT_SPELLCAST_CHANNEL_UPDATE" then
                if f.channel then
                    local name, _, texture, startTimeMS, endTimeMS, _, notInterruptible =
                        UnitChannelInfo(unit)
                    if name then
                        f.channel.startTimeMS = startTimeMS
                        f.channel.endTimeMS = endTimeMS
                        f.notInterruptible = notInterruptible
                        if PCB.db.showIcon and texture then
                            f.icon:SetTexture(texture)
                            f.icon:Show()
                        end
                    end
                end
            elseif event == "UNIT_SPELLCAST_CHANNEL_STOP" then
                StopCasting(f, false)
            elseif event == "UNIT_SPELLCAST_INTERRUPTIBLE" then
                f.notInterruptible = false
                if f.channel then
                    SetBarColor(f, "channel")
                else
                    SetBarColor(f, "cast")
                end
                UpdateInterruptShield(f)
            elseif event == "UNIT_SPELLCAST_NOT_INTERRUPTIBLE" then
                f.notInterruptible = true
                SetBarColor(f, "noninterrupt")
                UpdateInterruptShield(f)
            elseif event == "UNIT_SPELLCAST_SUCCEEDED" then
                -- Some instant casts can leave stale bars; re-evaluate shortly.
                C_Timer.After(0, function()
                    if f then RefreshFromUnit(f, unit) end
                end)
            elseif event == "UNIT_SPELLCAST_EMPOWER_START" then
                StartEmpower(f, unit)
            elseif event == "UNIT_SPELLCAST_EMPOWER_UPDATE" then
                -- Timing can adjust; just refresh timing from UnitCastingInfo
                if f.empower then
                    local name, _, texture, startTimeMS, endTimeMS, _, _, notInterruptible =
                        UnitCastingInfo(unit)
                    if name then
                        f.empower.startTimeMS = startTimeMS
                        f.empower.endTimeMS = endTimeMS
                        f.notInterruptible = notInterruptible
                        if PCB.db.showIcon and texture then
                            f.icon:SetTexture(texture)
                            f.icon:Show()
                        end
                    end
                end
            elseif event == "UNIT_SPELLCAST_EMPOWER_STOP" then
                StopCasting(f, false)
            end
        end)

        self.eventFrame = ef
    end

    -- Player latency collection via UNIT_SPELLCAST_SENT (only fires for player)
    if not self.latencyFrame then
        local lf = CreateFrame("Frame")
        lf:RegisterEvent("UNIT_SPELLCAST_SENT")
        lf:SetScript("OnEvent", function(_, _, unit, target, castGUID, spellID)
            if unit ~= "player" then return end
            local f = PCB.Bars.player
            if not f then return end
            -- Store SENT time in ms. We apply it when START arrives.
            local t = math.floor(GetTime() * 1000)
            -- If we already have an in-flight cast struct, update it; else store pending.
            f._pendingSentTime = t
        end)
        self.latencyFrame = lf
    end
end

function PCB:SavePosition(key, frame)
    local db = self.db.bars[key]
    if not db or not frame then return end
    local point, _, relPoint, x, y = frame:GetPoint(1)
    db.point, db.relPoint, db.x, db.y = point, relPoint, x, y
end

function PCB:ApplyBarConfig(key)
    local f = self.Bars[key]
    local db = self.db
    local b = db.bars[key]
    if not f or not b then return end

    f:ClearAllPoints()
    f:SetPoint(b.point, UIParent, b.relPoint, b.x, b.y)
    f:SetSize(b.width, b.height)
    f:SetAlpha(b.alpha or 1)
    f:SetScale(b.scale or 1)

    f.bar:SetStatusBarTexture(db.texture)
    f.bar:SetStatusBarColor(self:ColorFromTable(db.colorCast))

    -- Font
    PCB:ApplyFont(f.spellText)
    PCB:ApplyFont(f.timeText)
    PCB:ApplyFont(f.dragText)

    -- Icon sizing to match bar height
    local iconSize = (b.height or 18) + 2
    f.icon:SetSize(iconSize, iconSize)

    -- Drag overlay + mover preview
    local unlocked = (not db.locked)
    -- Use unified mover-mode renderer (handles dragText + unitLabel reliably)
    PCB_SetMoverMode(f, unlocked)
    f:EnableMouse(unlocked)

    -- Enable/disable bar
    if b.enabled then
        -- Refresh state from unit (so it appears mid-cast on reload)
        RefreshFromUnit(f, f.unit)

        -- If not casting/channeling and frames are unlocked, show a mover preview so the user can drag it.
        if (not db.locked) and (not f.cast and not f.channel and not f.empower) then
            -- Only show mover previews for enabled bars.
            local bdb = db.bars and db.bars[f.key]
            if not bdb or bdb.enabled ~= false then
                PCB_ShowMover(f)
            else
                f:Hide()
            end
        end
    else
        ResetState(f)
    end
end

function PCB:ApplyAll()
    -- Apply global + per-frame settings
    for key, _ in pairs(BAR_UNITS) do
        self:ApplyBarConfig(key)
    end

    -- Apply safeZone color immediately if visible
    for _, f in pairs(self.Bars) do
        if f.safeZone and f.safeZone:IsShown() then
            f.safeZone:SetVertexColor(self:ColorFromTable(self.db.safeZoneColor))
        end
    end
end

local origStartCast = StartCast
StartCast = function(f, unit, castGUID)
    origStartCast(f, unit, castGUID)
    if unit == "player" and f.cast and f._pendingSentTime then
        f.cast.sentTime = f._pendingSentTime
        f._pendingSentTime = nil
    end
end


SetMoverMode = function(f, enabled)
    f.isMover = enabled and true or false
    if f.isMover then
        PCB_ShowMover(f)
    else
        PCB_HideMover(f)
    end
end
