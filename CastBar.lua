local ADDON_NAME, PCB = ...
PCB = PCB or {}

-- LibSharedMedia is initialized in PhoenixCastBars.lua

-- Media resolution
function PCB:ResolveStatusbarTexture()
    local db = self.db or {}
    local key = db.textureKey or "Blizzard"
    if key == "Custom" then
        return db.texturePath or "Interface\\TARGETINGFRAME\\UI-StatusBar"
    end
    if self.LSM and self.LSM.Fetch then
        local path = self.LSM:Fetch("statusbar", key, true)
        if path and path ~= "" then return path end
    end
    return "Interface\\TARGETINGFRAME\\UI-StatusBar"
end

function PCB:ResolveFont()
    local db = self.db or {}
    local key = db.fontKey or "Friz Quadrata (Default)"
    if key == "Custom" then
        return db.fontPath or "Fonts\\FRIZQT__.TTF"
    end
    if self.LSM and self.LSM.Fetch then
        local path = self.LSM:Fetch("font", key, true)
        if path and path ~= "" then return path end
    end
    return "Fonts\\FRIZQT__.TTF"
end

-- Constants
PCB.Bars = PCB.Bars or {}
local BAR_UNITS = { player = "player", target = "target", focus = "focus" }

local EVENTS = {
    "UNIT_SPELLCAST_START", "UNIT_SPELLCAST_STOP", "UNIT_SPELLCAST_FAILED",
    "UNIT_SPELLCAST_INTERRUPTED", "UNIT_SPELLCAST_DELAYED", "UNIT_SPELLCAST_SENT",
    "UNIT_SPELLCAST_CHANNEL_START", "UNIT_SPELLCAST_CHANNEL_STOP", "UNIT_SPELLCAST_CHANNEL_UPDATE",
    "UNIT_SPELLCAST_INTERRUPTIBLE", "UNIT_SPELLCAST_NOT_INTERRUPTIBLE",
    "PLAYER_TARGET_CHANGED", "PLAYER_FOCUS_CHANGED", "PLAYER_ENTERING_WORLD",
    "UNIT_SPELLCAST_SUCCEEDED", "UNIT_SPELLCAST_EMPOWER_START", "UNIT_SPELLCAST_EMPOWER_UPDATE",
    "UNIT_SPELLCAST_EMPOWER_STOP", "VEHICLE_UPDATE",
}

local function msToSec(ms) return ms and (ms / 1000) or 0 end
local function clamp(v, lo, hi)
    if v < lo then return lo end
    if v > hi then return hi end
    return v
end

-- Frame construction
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
    f:EnableMouse(true)
    f:SetScript("OnMouseDown", function(self, btn)
        if btn == "LeftButton" and (not PCB.db.locked) then
            self:StartMoving()
        end
    end)
    f:SetScript("OnMouseUp", function(self)
        self:StopMovingOrSizing()
        PCB:SavePosition(key, self)
    end)
    f:SetScript("OnHide", function(self) self:StopMovingOrSizing() end)

    f.bg = CreateBackdrop(f)

    -- Status bar
    f.bar = CreateFrame("StatusBar", nil, f)
    f.bar:SetAllPoints(f)
    f.bar:SetMinMaxValues(0, 1)
    f.bar:SetValue(0)

    f.bar.bgTex = f.bar:CreateTexture(nil, "BACKGROUND")
    f.bar.bgTex:SetAllPoints(f.bar)
    f.bar.bgTex:SetTexture("Interface\\Buttons\\WHITE8x8")
    f.bar.bgTex:SetVertexColor(0, 0, 0, 0.35)

    -- Safe zone (latency)
    f.safeZone = f.bar:CreateTexture(nil, "OVERLAY")
    f.safeZone:SetTexture("Interface\\Buttons\\WHITE8x8")
    f.safeZone:SetPoint("TOPRIGHT", f.bar, "TOPRIGHT", 0, 0)
    f.safeZone:SetPoint("BOTTOMRIGHT", f.bar, "BOTTOMRIGHT", 0, 0)
    f.safeZone:SetWidth(0)
    f.safeZone:Hide()

    -- Spark
    f.spark = f.bar:CreateTexture(nil, "OVERLAY")
    f.spark:SetTexture("Interface\\CastingBar\\UI-CastingBar-Spark-Procedural")
    f.spark:SetBlendMode("ADD")
    f.spark:SetSize(16, 28)
    f.spark:Hide()

    -- Icon
    f.icon = f:CreateTexture(nil, "OVERLAY")
    f.icon:SetSize(20, 20)
    f.icon:SetPoint("RIGHT", f, "LEFT", -6, 0)
    f.icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)
    f.icon:Hide()

    -- Create overlay frame for text to ensure it appears above everything
    f.textOverlay = CreateFrame("Frame", nil, f)
    f.textOverlay:SetAllPoints(f)
    f.textOverlay:SetFrameLevel(f:GetFrameLevel() + 10)

    -- Texts (create on overlay frame to ensure they appear above bar texture)
    f.spellText = f.textOverlay:CreateFontString(nil, "OVERLAY")
    f.spellText:SetJustifyH("LEFT")
    f.spellText:SetPoint("LEFT", f.bar, "LEFT", 6, 0)
    local font, size, flags = GameFontHighlightSmall:GetFont()
    f.spellText:SetFont(font, size or 12, flags)

    f.timeText = f.textOverlay:CreateFontString(nil, "OVERLAY")
    f.timeText:SetJustifyH("RIGHT")
    f.timeText:SetPoint("RIGHT", f.bar, "RIGHT", -6, 0)
    f.timeText:SetFont(font, size or 12, flags)

    -- Drag handle (no longer needed, unitLabel will be added by PCB_ShowMover)
    f.dragText = f.textOverlay:CreateFontString(nil, "OVERLAY")
    f.dragText:SetPoint("CENTER", f, "CENTER", 0, 0)
    local font2, size2, flags2 = GameFontNormal:GetFont()
    f.dragText:SetFont(font2, (size2 or 12) + 2, flags2)
    f.dragText:SetTextColor(1, 1, 1, 0.6)
    f.dragText:Hide()

    f:Hide()
    f.key = key
    f.unit = BAR_UNITS[key]
    return f
end

-- Cast state & updates
local function ResetState(f)
    if not f or not f.bar then return end
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
    if PCB.db and PCB.db.locked then f:Hide() end
end

local function SetBarColor(f, mode)
    local db = PCB.db
    local c = (mode == "channel" and db.colorChannel)
        or (mode == "failed" and db.colorFailed)
        or (mode == "noninterrupt" and db.colorNonInterruptible)
        or db.colorCast
    f.bar:SetStatusBarColor(PCB:ColorFromTable(c))
end

local function ApplySpark(f, pct)
    if not PCB.db.showSpark then f.spark:Hide(); return end
    pct = clamp(pct or 0, 0, 1)
    local w = f.bar:GetWidth()
    f.spark:ClearAllPoints()
    f.spark:SetPoint("CENTER", f.bar, "LEFT", w * pct, 0)
    f.spark:Show()
end

local function UpdateTexts(f, remaining, duration)
    local db = PCB.db
    f.spellText:SetText((db.showSpellName and f.spellName) or "")
    if db.showTime and remaining and duration and duration > 0 then
        f.timeText:SetFormattedText("%.1f / %.1f", remaining, duration)
    else
        f.timeText:SetText("")
    end
end

local function UpdateSafeZone_Player(f, duration)
    local db = PCB.db
    if not db.showLatency or f.unit ~= "player" or not f.cast then
        f.safeZone:Hide(); return
    end
    local sent = f.cast.sentTime
    local startMS = f.cast.startTimeMS or 0
    local latencyMS = startMS - (sent or 0)
    if latencyMS <= 0 or duration <= 0 then f.safeZone:Hide(); return end
    local pct = clamp(msToSec(latencyMS) / duration, 0, 1)
    f.safeZone:SetWidth(f.bar:GetWidth() * pct)
    f.safeZone:SetVertexColor(PCB:ColorFromTable(db.safeZoneColor))
    f.safeZone:Show()
end

local function UpdateInterruptShield(f)
    if not f.shield then return end
    local db = PCB.db
    if not db.showInterruptShield then f.shield:Hide(); return end
    f.shield:SetShown(f.notInterruptible)
end

local function UpdateBar(f)
    if not f:IsShown() then return end
    local now = GetTime()

    if f.cast then
        local startT = msToSec(f.cast.startTimeMS)
        local endT   = msToSec(f.cast.endTimeMS)
        local duration = endT - startT
        local elapsed = now - startT
        local remaining = endT - now
        if duration <= 0 or remaining <= 0 then ResetState(f); return end
        f.bar:SetMinMaxValues(0, duration)
        f.bar:SetValue(elapsed)
        ApplySpark(f, elapsed / duration)
        UpdateSafeZone_Player(f, duration)
        UpdateInterruptShield(f)
        UpdateTexts(f, remaining, duration)
        return
    end

    if f.channel then
        local startT = msToSec(f.channel.startTimeMS)
        local endT   = msToSec(f.channel.endTimeMS)
        local duration = endT - startT
        local remaining = endT - now
        local elapsed = duration - remaining
        if duration <= 0 or remaining <= 0 then ResetState(f); return end
        f.bar:SetMinMaxValues(0, duration)
        f.bar:SetValue(remaining)
        ApplySpark(f, 1 - (elapsed / duration))
        f.safeZone:Hide()
        UpdateInterruptShield(f)
        UpdateTexts(f, remaining, duration)
        return
    end

    if f.empower then
        local startT = msToSec(f.empower.startTimeMS)
        local endT   = msToSec(f.empower.endTimeMS)
        local duration = endT - startT
        local elapsed = now - startT
        local remaining = endT - now
        if duration <= 0 or remaining <= 0 then ResetState(f); return end
        f.bar:SetMinMaxValues(0, duration)
        f.bar:SetValue(elapsed)
        ApplySpark(f, elapsed / duration)
        f.safeZone:Hide()
        UpdateInterruptShield(f)
        UpdateTexts(f, remaining, duration)
        return
    end
end

-- Event handlers
local function StartCast(f, unit, castGUID)
    local name, text, texture, startTimeMS, endTimeMS, isTradeSkill, castID, notInterruptible, spellID =
        UnitCastingInfo(unit)
    if not name then ResetState(f); return end

    f.cast = { startTimeMS = startTimeMS, endTimeMS = endTimeMS, spellID = spellID }
    f.channel = nil
    f.empower   = nil
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

    -- latency capture
    if unit == "player" and f._pendingSentTime then
        f.cast.sentTime = f._pendingSentTime
        f._pendingSentTime = nil
    end
end

local function StartChannel(f, unit)
    local name, text, texture, startTimeMS, endTimeMS, isTradeSkill, notInterruptible, spellID =
        UnitChannelInfo(unit)
    if not name then ResetState(f); return end

    f.channel = { startTimeMS = startTimeMS, endTimeMS = endTimeMS, spellID = spellID }
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
    local name, text, texture, startTimeMS, endTimeMS, isTradeSkill, castID, notInterruptible, spellID =
        UnitCastingInfo(unit)
    if not name then ResetState(f); return end

    f.empower = { startTimeMS = startTimeMS, endTimeMS = endTimeMS, spellID = spellID }
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
        C_Timer.After(0.4, function() if f and f:IsShown() then ResetState(f) end end)
    else
        ResetState(f)
    end
end

local function RefreshFromUnit(f, unit)
    if unit == f.unit then
        if UnitCastingInfo(unit) then
            StartCast(f, unit)
        elseif UnitChannelInfo(unit) then
            StartChannel(f, unit)
        else
            ResetState(f)
        end
    end
end

-- Public methods
function PCB:CreateBars()
    for key, unit in pairs(BAR_UNITS) do
        if not self.Bars[key] then
            local f = CreateCastBarFrame(key)
            f:SetScript("OnUpdate", function(_, _) UpdateBar(f) end)
            self.Bars[key] = f
        end
    end

    -- Global event router
    if not self.eventFrame then
        local ef = CreateFrame("Frame")
        for _, e in ipairs(EVENTS) do ef:RegisterEvent(e) end

        ef:SetScript("OnEvent", function(_, event, unit, ...)
            if event == "PLAYER_TARGET_CHANGED" then
                RefreshFromUnit(self.Bars.target, "target")
                return
            elseif event == "PLAYER_FOCUS_CHANGED" then
                RefreshFromUnit(self.Bars.focus, "focus")
                return
            elseif event == "PLAYER_ENTERING_WORLD" or event == "VEHICLE_UPDATE" then
                RefreshFromUnit(self.Bars.player, "player")
                RefreshFromUnit(self.Bars.target, "target")
                RefreshFromUnit(self.Bars.focus, "focus")
                return
            end

            if type(unit) ~= "string" then return end
            local f = (unit == "player" and self.Bars.player)
                    or (unit == "target" and self.Bars.target)
                    or (unit == "focus" and self.Bars.focus)
            if not f or not self.db.bars[f.key].enabled then
                if f then ResetState(f) end
                return
            end

            if event == "UNIT_SPELLCAST_START" then
                StartCast(f, unit, ...)
            elseif event == "UNIT_SPELLCAST_STOP" then
                StopCasting(f, false)
            elseif event == "UNIT_SPELLCAST_FAILED" or event == "UNIT_SPELLCAST_INTERRUPTED" then
                StopCasting(f, true)
            elseif event == "UNIT_SPELLCAST_DELAYED" then
                if f.cast then
                    local name, _, texture, startTimeMS, endTimeMS, _, _, notInterruptible = UnitCastingInfo(unit)
                    if name then
                        f.cast.startTimeMS = startTimeMS
                        f.cast.endTimeMS = endTimeMS
                        f.notInterruptible = notInterruptible
                        if self.db.showIcon and texture then
                            f.icon:SetTexture(texture)
                            f.icon:Show()
                        end
                    end
                end
            elseif event == "UNIT_SPELLCAST_CHANNEL_START" then
                StartChannel(f, unit)
            elseif event == "UNIT_SPELLCAST_CHANNEL_UPDATE" then
                if f.channel then
                    local name, _, texture, startTimeMS, endTimeMS, _, notInterruptible = UnitChannelInfo(unit)
                    if name then
                        f.channel.startTimeMS = startTimeMS
                        f.channel.endTimeMS = endTimeMS
                        f.notInterruptible = notInterruptible
                        if self.db.showIcon and texture then
                            f.icon:SetTexture(texture)
                            f.icon:Show()
                        end
                    end
                end
            elseif event == "UNIT_SPELLCAST_CHANNEL_STOP" then
                StopCasting(f, false)
            elseif event == "UNIT_SPELLCAST_INTERRUPTIBLE" then
                f.notInterruptible = false
                SetBarColor(f, f.channel and "channel" or "cast")
                UpdateInterruptShield(f)
            elseif event == "UNIT_SPELLCAST_NOT_INTERRUPTIBLE" then
                f.notInterruptible = true
                SetBarColor(f, "noninterrupt")
                UpdateInterruptShield(f)
            elseif event == "UNIT_SPELLCAST_SUCCEEDED" then
                C_Timer.After(0, function() if f then RefreshFromUnit(f, unit) end end)
            elseif event == "UNIT_SPELLCAST_EMPOWER_START" then
                StartEmpower(f, unit)
            elseif event == "UNIT_SPELLCAST_EMPOWER_UPDATE" then
                if f.empower then
                    local name, _, texture, startTimeMS, endTimeMS, _, _, notInterruptible = UnitCastingInfo(unit)
                    if name then
                        f.empower.startTimeMS = startTimeMS
                        f.empower.endTimeMS = endTimeMS
                        f.notInterruptible = notInterruptible
                        if self.db.showIcon and texture then
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

    -- Latency collection
    if not self.latencyFrame then
        local lf = CreateFrame("Frame")
        lf:RegisterEvent("UNIT_SPELLCAST_SENT")
        lf:SetScript("OnEvent", function(_, _, unit, target, castGUID, spellID)
            if unit ~= "player" then return end
            local f = self.Bars.player
            if f then f._pendingSentTime = floor(GetTime() * 1000) end
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

    local ap = b.appearance or {}
    local texture = self:ResolveStatusbarTexture()
    local font = self:ResolveFont()
    local fontSize = db.fontSize or 12
    local outline = db.outline or "OUTLINE"

    -- fallbacks
    if not texture or texture == "" then texture = "Interface\\TARGETINGFRAME\\UI-StatusBar" end
    if not font      or font == ""      then font      = "Fonts\\FRIZQT__.TTF" end
    if not fontSize  then fontSize = 12 end
    if not outline   or outline == ""  then outline = "OUTLINE" end

    f:ClearAllPoints()
    f:SetPoint(b.point, UIParent, b.relPoint, b.x, b.y)
    f:SetSize(b.width, b.height)
    f:SetAlpha(b.alpha or 1)
    f:SetScale(b.scale or 1)

    f.bar:SetStatusBarTexture(texture)
    f.bar:SetStatusBarColor(self:ColorFromTable(db.colorCast))

    -- apply fonts
    local flags = (outline == "NONE" and "") or outline
    f.spellText:SetFont(font, fontSize, flags)
    f.timeText:SetFont(font, fontSize, flags)
    if f.dragText then f.dragText:SetFont(font, fontSize + 2, flags) end

    -- icon size
    local iconSize = (b.height or 18) + 2
    f.icon:SetSize(iconSize, iconSize)

    -- mover mode
    local unlocked = not db.locked
    PCB_SetMoverMode(f, unlocked)
    f:EnableMouse(unlocked)

    -- enabled state
    if b.enabled then
        RefreshFromUnit(f, f.unit)
        if unlocked and (not f.cast and not f.channel and not f.empower) then
            PCB_SetMoverMode(f, true)
        end
    else
        ResetState(f)
    end
end

function PCB:ApplyAll()
    for key in pairs(BAR_UNITS) do self:ApplyBarConfig(key) end
    -- safe-zone color refresh
    for _, f in pairs(self.Bars) do
        if f.safeZone and f.safeZone:IsShown() then
            f.safeZone:SetVertexColor(self:ColorFromTable(self.db.safeZoneColor))
        end
    end
end

-- Mover helpers
function PCB_ShowMover(f)
    f:Show()
    f.bar:SetMinMaxValues(0, 1)
    f.bar:SetValue(0.75)
    if f.spellText then f.spellText:SetText("") end
    if f.timeText  then f.timeText:SetText("")  end
    if f.icon      then f.icon:Hide() end
    if f.shield    then f.shield:Hide() end
    if f.safeZone  then f.safeZone:Hide() end
    if f.spark     then f.spark:Hide() end

    local overlay = f.textOverlay or f
    if not f.pcbTextBg then
        f.pcbTextBg = overlay:CreateTexture(nil, "BACKGROUND")
        f.pcbTextBg:SetAllPoints(overlay)
        f.pcbTextBg:SetColorTexture(0, 0, 0, 0.35)
    end
    f.pcbTextBg:Show()

    if not f.dragText then
        f.dragText = overlay:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        f.dragText:SetPoint("CENTER", overlay, "CENTER", 0, 0)
    end
    f.dragText:SetText("Drag to move")
    f.dragText:Show()

    if not f.unitLabel then
        f.unitLabel = overlay:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        f.unitLabel:SetPoint("TOPLEFT", overlay, "TOPLEFT", 6, -4)
        f.unitLabel:SetTextColor(0.80, 0.86, 0.98, 1.0)
    end
    local label = (f.key == "player" and "PLAYER") or (f.key == "target" and "TARGET") or (f.key == "focus" and "FOCUS") or f.key:upper()
    f.unitLabel:SetText(label)
    f.unitLabel:Show()
end

function PCB_HideMover(f)
    if f.dragText  then f.dragText:Hide()  end
    if f.pcbTextBg then f.pcbTextBg:Hide() end
    if f.unitLabel then f.unitLabel:Hide() end
end

function PCB_SetMoverMode(f, enabled)
    f.isMover = enabled and true or false
    if f.isMover then
        PCB_ShowMover(f)
    else
        PCB_HideMover(f)
    end
end
