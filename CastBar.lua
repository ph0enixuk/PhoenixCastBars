local ADDON_NAME, PCB = ...
PCB = PCB or {}

<<<<<<< HEAD
-- LibSharedMedia is initialized in PhoenixCastBars.lua

-- Media resolution
function PCB:ResolveStatusbarTexture()
    local db = self.db or {}
    local key = db.textureKey or "Blizzard"
    if key == "Custom" then
        return db.texturePath or "Interface\\TARGETINGFRAME\\UI-StatusBar"
=======
function PCB:ResolveStatusbarTexture(appearance)
    local db = self.db or {}
    local a = appearance
    local key = (a and not a.useGlobalTexture and a.textureKey) or db.textureKey or "Blizzard"
    if key == "Custom" then
        local path = (a and not a.useGlobalTexture and a.texturePath) or db.texturePath
        return path or "Interface\\TARGETINGFRAME\\UI-StatusBar"
>>>>>>> 9671a60 (Release v0.3.4 / update files)
    end
    if self.LSM and self.LSM.Fetch then
        local path = self.LSM:Fetch("statusbar", key, true)
        if path and path ~= "" then return path end
    end
    return "Interface\\TARGETINGFRAME\\UI-StatusBar"
end

<<<<<<< HEAD
function PCB:ResolveFont()
    local db = self.db or {}
    local key = db.fontKey or "Friz Quadrata (Default)"
    if key == "Custom" then
        return db.fontPath or "Fonts\\FRIZQT__.TTF"
=======
function PCB:ResolveFont(appearance)
    local db = self.db or {}
    local a = appearance
    local key = (a and not a.useGlobalFont and a.fontKey) or db.fontKey or "Friz Quadrata (Default)"
    if key == "Custom" then
        local path = (a and not a.useGlobalFont and a.fontPath) or db.fontPath
        return path or "Fonts\\FRIZQT__.TTF"
>>>>>>> 9671a60 (Release v0.3.4 / update files)
    end
    if self.LSM and self.LSM.Fetch then
        local path = self.LSM:Fetch("font", key, true)
        if path and path ~= "" then return path end
    end
    return "Fonts\\FRIZQT__.TTF"
end

<<<<<<< HEAD
-- Constants
PCB.Bars = PCB.Bars or {}
local BAR_UNITS = { player = "player", target = "target", focus = "focus" }
=======
PCB.Bars = PCB.Bars or {}
local BAR_UNITS = { player = "player", target = "target", focus = "focus" }
local SNAP_THRESHOLD = 15  -- Pixels to snap within for both bar-to-bar and grid snapping
>>>>>>> 9671a60 (Release v0.3.4 / update files)

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

<<<<<<< HEAD
-- Frame construction
=======
-- Forward declaration
local UpdateBar

>>>>>>> 9671a60 (Release v0.3.4 / update files)
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
<<<<<<< HEAD
    f:SetClampedToScreen(true)
    f:SetMovable(true)
    f:EnableMouse(true)
    f:SetScript("OnMouseDown", function(self, btn)
        if btn == "LeftButton" and (not PCB.db.locked) then
=======
    f:SetFrameStrata("MEDIUM")
    f:SetClampedToScreen(true)
    f:SetMovable(true)
    f:EnableMouse(true)
    f:RegisterForDrag("LeftButton")
    f._lastClickTime = 0
    f._snapIndicatorThrottle = 0
    
    f:SetScript("OnMouseDown", function(self, btn)
        if btn == "LeftButton" and (not PCB.db.locked) then
            local now = GetTime()
            -- Check for double-click (within 0.3 seconds)
            if (now - self._lastClickTime) < 0.3 then
                PCB:ResetSinglePosition(key)
                self._lastClickTime = 0
                return
            end
            self._lastClickTime = now
            
            -- Store original position for escape key cancel
            self._dragStartLeft = self:GetLeft()
            self._dragStartBottom = self:GetBottom()
            self._isDragging = true
>>>>>>> 9671a60 (Release v0.3.4 / update files)
            self:StartMoving()
        end
    end)
    f:SetScript("OnMouseUp", function(self)
        self:StopMovingOrSizing()
<<<<<<< HEAD
        PCB:SavePosition(key, self)
    end)
    f:SetScript("OnHide", function(self) self:StopMovingOrSizing() end)

    f.bg = CreateBackdrop(f)

    -- Status bar
=======
        self._dragStartLeft = nil
        self._dragStartBottom = nil
        self._isDragging = false
        PCB:HideSnapIndicator()
        C_Timer.After(0, function()
            -- Check for Shift key to disable snapping
            if not IsShiftKeyDown() then
                -- Only snap to center vertical line (no bar-to-bar snapping)
                PCB:SnapToGrid(key, self)
            end
            PCB:SavePosition(key, self)
        end)
    end)
    f:SetScript("OnHide", function(self) 
        self:StopMovingOrSizing()
        self._dragStartLeft = nil
        self._dragStartBottom = nil
        self._isDragging = false
        PCB:HideSnapIndicator()
    end)
    f:SetScript("OnUpdate", function(self, elapsed)
        if self._isDragging then
            -- Throttle snap indicator updates to every 0.05s
            self._snapIndicatorThrottle = (self._snapIndicatorThrottle or 0) + elapsed
            if self._snapIndicatorThrottle >= 0.05 then
                self._snapIndicatorThrottle = 0
                
                -- Check for escape key (via menu binding)
                if IsKeyDown("ESCAPE") or GameMenuFrame:IsShown() then
                    self:StopMovingOrSizing()
                    self:ClearAllPoints()
                    self:SetPoint("BOTTOMLEFT", UIParent, "BOTTOMLEFT", self._dragStartLeft, self._dragStartBottom)
                    self._dragStartLeft = nil
                    self._dragStartBottom = nil
                    self._isDragging = false
                    PCB:HideSnapIndicator()
                else
                    -- Show snap indicator if in range (and not holding Shift)
                    if not IsShiftKeyDown() then
                        PCB:UpdateSnapIndicator(key, self)
                    else
                        PCB:HideSnapIndicator()
                    end
                end
            end
        elseif self.cast or self.channel or self.empower or self.test then
            UpdateBar(self)
        end
    end)

    f.bg = CreateBackdrop(f)

>>>>>>> 9671a60 (Release v0.3.4 / update files)
    f.bar = CreateFrame("StatusBar", nil, f)
    f.bar:SetAllPoints(f)
    f.bar:SetMinMaxValues(0, 1)
    f.bar:SetValue(0)

    f.bar.bgTex = f.bar:CreateTexture(nil, "BACKGROUND")
    f.bar.bgTex:SetAllPoints(f.bar)
    f.bar.bgTex:SetTexture("Interface\\Buttons\\WHITE8x8")
    f.bar.bgTex:SetVertexColor(0, 0, 0, 0.35)

<<<<<<< HEAD
    -- Safe zone (latency)
=======
>>>>>>> 9671a60 (Release v0.3.4 / update files)
    f.safeZone = f.bar:CreateTexture(nil, "OVERLAY")
    f.safeZone:SetTexture("Interface\\Buttons\\WHITE8x8")
    f.safeZone:SetPoint("TOPRIGHT", f.bar, "TOPRIGHT", 0, 0)
    f.safeZone:SetPoint("BOTTOMRIGHT", f.bar, "BOTTOMRIGHT", 0, 0)
    f.safeZone:SetWidth(0)
    f.safeZone:Hide()

<<<<<<< HEAD
    -- Spark
    f.spark = f.bar:CreateTexture(nil, "OVERLAY")
    f.spark:SetTexture("Interface\\CastingBar\\UI-CastingBar-Spark-Procedural")
    f.spark:SetBlendMode("ADD")
    f.spark:SetSize(16, 28)
    f.spark:Hide()

    -- Icon
=======
    f.spark = f.bar:CreateTexture(nil, "OVERLAY")
    f.spark:SetTexture("Interface\\AddOns\\PhoenixCastBars\\Media\\phoenix_spark.tga")
    f.spark:SetTexCoord(0, 1, 0, 1)
    f.spark:SetVertexColor(1, 1, 1, 1) -- White, fully opaque
    f.spark:SetWidth(4)
    f.spark:SetHeight(f.bar:GetHeight())
        f.spark:SetBlendMode("ADD")
        f.spark:SetAlpha(0.85)
        f.spark:SetDrawLayer("OVERLAY", 7) -- Topmost overlay
        f.spark:Hide() -- Hidden by default, shown by logic

>>>>>>> 9671a60 (Release v0.3.4 / update files)
    f.icon = f:CreateTexture(nil, "OVERLAY")
    f.icon:SetSize(20, 20)
    f.icon:SetPoint("RIGHT", f, "LEFT", -6, 0)
    f.icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)
    f.icon:Hide()

<<<<<<< HEAD
    -- Create overlay frame for text to ensure it appears above everything
=======
    f.shield = f:CreateTexture(nil, "OVERLAY")
    f.shield:SetTexture("Interface\\CastingBar\\UI-CastingBar-Small-Shield")
    f.shield:SetSize(20, 20)
    f.shield:SetPoint("CENTER", f, "LEFT", -3, 0)
    f.shield:Hide()

    -- Text overlay (ensures text renders above all textures)
>>>>>>> 9671a60 (Release v0.3.4 / update files)
    f.textOverlay = CreateFrame("Frame", nil, f)
    f.textOverlay:SetAllPoints(f)
    f.textOverlay:SetFrameLevel(f:GetFrameLevel() + 10)

<<<<<<< HEAD
    -- Texts (create on overlay frame to ensure they appear above bar texture)
=======
>>>>>>> 9671a60 (Release v0.3.4 / update files)
    f.spellText = f.textOverlay:CreateFontString(nil, "OVERLAY")
    f.spellText:SetJustifyH("LEFT")
    f.spellText:SetPoint("LEFT", f.bar, "LEFT", 6, 0)
    local font, size, flags = GameFontHighlightSmall:GetFont()
    f.spellText:SetFont(font, size or 12, flags)

    f.timeText = f.textOverlay:CreateFontString(nil, "OVERLAY")
    f.timeText:SetJustifyH("RIGHT")
    f.timeText:SetPoint("RIGHT", f.bar, "RIGHT", -6, 0)
    f.timeText:SetFont(font, size or 12, flags)

<<<<<<< HEAD
    -- Drag handle (no longer needed, unitLabel will be added by PCB_ShowMover)
=======
    -- Drag text label (visible when frames are unlocked)
>>>>>>> 9671a60 (Release v0.3.4 / update files)
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
<<<<<<< HEAD
local function ResetState(f)
    if not f or not f.bar then return end
=======
local function ResetState(f, force)
    if not f or not f.bar then return end
    -- Don't reset if there's an active cast unless forced
    if not force and (f.cast or f.channel or f.empower) then
        return
    end
    
>>>>>>> 9671a60 (Release v0.3.4 / update files)
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
<<<<<<< HEAD
    if PCB.db and PCB.db.locked then f:Hide() end
=======
    -- Only hide if locked AND not in mover/test mode
    if PCB.db and PCB.db.locked and not f.isMover and not f.test then 
        f:Hide() 
    end
>>>>>>> 9671a60 (Release v0.3.4 / update files)
end

local function SetBarColor(f, mode)
    local db = PCB.db
    local c = (mode == "channel" and db.colorChannel)
        or (mode == "failed" and db.colorFailed)
<<<<<<< HEAD
=======
        or (mode == "success" and db.colorSuccess)
>>>>>>> 9671a60 (Release v0.3.4 / update files)
        or (mode == "noninterrupt" and db.colorNonInterruptible)
        or db.colorCast
    f.bar:SetStatusBarColor(PCB:ColorFromTable(c))
end

local function ApplySpark(f, pct)
<<<<<<< HEAD
    if not PCB.db.showSpark then f.spark:Hide(); return end
    pct = clamp(pct or 0, 0, 1)
    local w = f.bar:GetWidth()
    f.spark:ClearAllPoints()
    f.spark:SetPoint("CENTER", f.bar, "LEFT", w * pct, 0)
=======
    local bdb = PCB.db.bars[f.key]
    if not bdb or not bdb.showSpark then f.spark:Hide(); return end
    pct = clamp(pct or 0, 0, 1)
    local w = f.bar:GetWidth()
    local h = f.bar:GetHeight()
    f.spark:SetWidth(2)
    f.spark:SetHeight(h)
    f.spark:ClearAllPoints()
    local pixelPos = math.floor(w * pct + 0.5)
    f.spark:SetPoint("CENTER", f.bar, "LEFT", pixelPos, 0)
>>>>>>> 9671a60 (Release v0.3.4 / update files)
    f.spark:Show()
end

local function UpdateTexts(f, remaining, duration)
    local db = PCB.db
<<<<<<< HEAD
    f.spellText:SetText((db.showSpellName and f.spellName) or "")
    if db.showTime and remaining and duration and duration > 0 then
        f.timeText:SetFormattedText("%.1f / %.1f", remaining, duration)
=======
    local bdb = db.bars[f.key]
    f.spellText:SetText((bdb and bdb.showSpellName and f.spellName) or "")
    if bdb and bdb.showTime and remaining and duration and duration > 0 then
        f.timeText:SetFormattedText("%.1f", remaining)
>>>>>>> 9671a60 (Release v0.3.4 / update files)
    else
        f.timeText:SetText("")
    end
end

local function UpdateSafeZone_Player(f, duration)
    local db = PCB.db
<<<<<<< HEAD
    if not db.showLatency or f.unit ~= "player" or not f.cast then
=======
    local bdb = db.bars[f.key]
    if not bdb or not bdb.showLatency or f.unit ~= "player" or not f.cast then
>>>>>>> 9671a60 (Release v0.3.4 / update files)
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
<<<<<<< HEAD
    if not db.showInterruptShield then f.shield:Hide(); return end
    f.shield:SetShown(f.notInterruptible)
end

local function UpdateBar(f)
    if not f:IsShown() then return end
    local now = GetTime()
=======
    local bdb = db.bars[f.key]
    if not bdb or not bdb.showInterruptShield then f.shield:Hide(); return end
    f.shield:SetShown(f.notInterruptible)
end

UpdateBar = function(f)
    if f.unit and UnitExists(f.unit) and UnitIsDead(f.unit) then
        if f.cast or f.channel or f.empower then
            ResetState(f, true)
        end
        return
    end
    
    if f.cast or f.channel or f.empower then
        if not f:IsShown() then
            f:Show()
        end
    end
    
    local now = GetTime()
-- Test mode dummy cast (loops continuously until test mode is disabled)
if f.test then
    local now = GetTime()
    local elapsed = now - (f.test.start or now)
    local duration = f.test.dur or 3.0
    -- Loop the cast when it reaches the end
    while elapsed >= duration do
        f.test.start = f.test.start + duration
        elapsed = elapsed - duration
    end
    f.bar:SetMinMaxValues(0, duration)
    f.bar:SetValue(elapsed)
    ApplySpark(f, elapsed / duration)
    local bdb = PCB.db.bars[f.key]
    if bdb and bdb.showIcon then
        f.icon:SetTexture(f.test.icon)
        f.icon:Show()
    else
        f.icon:Hide()
    end
    f.spellName = f.test.name
    f.notInterruptible = f.test.notInterruptible
    SetBarColor(f, false, false)
    f.safeZone:Hide()
    UpdateInterruptShield(f)
    UpdateTexts(f, duration - elapsed, duration)
    f:Show()
    return
end
>>>>>>> 9671a60 (Release v0.3.4 / update files)

    if f.cast then
        local startT = msToSec(f.cast.startTimeMS)
        local endT   = msToSec(f.cast.endTimeMS)
        local duration = endT - startT
        local elapsed = now - startT
        local remaining = endT - now
<<<<<<< HEAD
        if duration <= 0 or remaining <= 0 then ResetState(f); return end
=======
        if duration <= 0 or remaining < -0.1 then
            ResetState(f, true)
            return
        end
>>>>>>> 9671a60 (Release v0.3.4 / update files)
        f.bar:SetMinMaxValues(0, duration)
        f.bar:SetValue(elapsed)
        ApplySpark(f, elapsed / duration)
        UpdateSafeZone_Player(f, duration)
        UpdateInterruptShield(f)
<<<<<<< HEAD
        UpdateTexts(f, remaining, duration)
=======
        UpdateTexts(f, remaining > 0 and remaining or 0, duration)
        f:Show()
>>>>>>> 9671a60 (Release v0.3.4 / update files)
        return
    end

    if f.channel then
        local startT = msToSec(f.channel.startTimeMS)
        local endT   = msToSec(f.channel.endTimeMS)
        local duration = endT - startT
        local remaining = endT - now
        local elapsed = duration - remaining
<<<<<<< HEAD
        if duration <= 0 or remaining <= 0 then ResetState(f); return end
=======
        if duration <= 0 or remaining < -0.1 then
            ResetState(f, true)
            return
        end
>>>>>>> 9671a60 (Release v0.3.4 / update files)
        f.bar:SetMinMaxValues(0, duration)
        f.bar:SetValue(remaining)
        ApplySpark(f, 1 - (elapsed / duration))
        f.safeZone:Hide()
        UpdateInterruptShield(f)
<<<<<<< HEAD
        UpdateTexts(f, remaining, duration)
=======
        UpdateTexts(f, remaining > 0 and remaining or 0, duration)
        f:Show()
>>>>>>> 9671a60 (Release v0.3.4 / update files)
        return
    end

    if f.empower then
        local startT = msToSec(f.empower.startTimeMS)
        local endT   = msToSec(f.empower.endTimeMS)
        local duration = endT - startT
        local elapsed = now - startT
        local remaining = endT - now
<<<<<<< HEAD
        if duration <= 0 or remaining <= 0 then ResetState(f); return end
=======
        if duration <= 0 or remaining < -0.1 then
            ResetState(f, true)
            return
        end
>>>>>>> 9671a60 (Release v0.3.4 / update files)
        f.bar:SetMinMaxValues(0, duration)
        f.bar:SetValue(elapsed)
        ApplySpark(f, elapsed / duration)
        f.safeZone:Hide()
        UpdateInterruptShield(f)
<<<<<<< HEAD
        UpdateTexts(f, remaining, duration)
=======
        UpdateTexts(f, remaining > 0 and remaining or 0, duration)
        f:Show()
>>>>>>> 9671a60 (Release v0.3.4 / update files)
        return
    end
end

-- Event handlers
local function StartCast(f, unit, castGUID)
    local name, text, texture, startTimeMS, endTimeMS, isTradeSkill, castID, notInterruptible, spellID =
        UnitCastingInfo(unit)
<<<<<<< HEAD
    if not name then ResetState(f); return end
=======
    if not name then
        ResetState(f, true)
        return
    end
>>>>>>> 9671a60 (Release v0.3.4 / update files)

    f.cast = { startTimeMS = startTimeMS, endTimeMS = endTimeMS, spellID = spellID }
    f.channel = nil
    f.empower   = nil
    f.spellName = name
    f.notInterruptible = notInterruptible

<<<<<<< HEAD
    if PCB.db.showIcon and texture then
=======
    local bdb = PCB.db.bars[f.key]
    if bdb and bdb.showIcon and texture then
>>>>>>> 9671a60 (Release v0.3.4 / update files)
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
<<<<<<< HEAD
    if not name then ResetState(f); return end
=======
    if not name then
        ResetState(f, true)
        return
    end
>>>>>>> 9671a60 (Release v0.3.4 / update files)

    f.channel = { startTimeMS = startTimeMS, endTimeMS = endTimeMS, spellID = spellID }
    f.cast = nil
    f.empower = nil
    f.spellName = name
    f.notInterruptible = notInterruptible

<<<<<<< HEAD
    if PCB.db.showIcon and texture then
=======
    local bdb = PCB.db.bars[f.key]
    if bdb and bdb.showIcon and texture then
>>>>>>> 9671a60 (Release v0.3.4 / update files)
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
<<<<<<< HEAD
    if not name then ResetState(f); return end
=======
    if not name then
        ResetState(f, true)
        return
    end
>>>>>>> 9671a60 (Release v0.3.4 / update files)

    f.empower = { startTimeMS = startTimeMS, endTimeMS = endTimeMS, spellID = spellID }
    f.cast = nil
    f.channel = nil
    f.spellName = name
    f.notInterruptible = notInterruptible

<<<<<<< HEAD
    if PCB.db.showIcon and texture then
=======
    local bdb = PCB.db.bars[f.key]
    if bdb and bdb.showIcon and texture then
>>>>>>> 9671a60 (Release v0.3.4 / update files)
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
<<<<<<< HEAD
    if not f:IsShown() then return end
    if failed then
        SetBarColor(f, "failed")
        f.timeText:SetText("")
        C_Timer.After(0.4, function() if f and f:IsShown() then ResetState(f) end end)
    else
        ResetState(f)
    end
=======
    if not f.cast and not f.channel and not f.empower then
        return
    end
    
    if failed then
        SetBarColor(f, "failed")
        f.timeText:SetText("")
        C_Timer.After(0.4, function() if f and f:IsShown() then
            ResetState(f, true)
        end end)
        return
    end
    
    local now = GetTime()
    local remaining = 0
    
    if f.cast then
        local endT = msToSec(f.cast.endTimeMS)
        remaining = endT - now
    elseif f.channel then
        local endT = msToSec(f.channel.endTimeMS)
        remaining = endT - now
    elseif f.empower then
        local endT = msToSec(f.empower.endTimeMS)
        remaining = endT - now
    end
    
    -- Prevent premature resets from redundant/early stop events
    if remaining > 0.1 then
        return
    end
    
    -- Flash success color briefly
    SetBarColor(f, "success")
    C_Timer.After(0.3, function() 
        if f and f:IsShown() then
            ResetState(f, true)
        end 
    end)
>>>>>>> 9671a60 (Release v0.3.4 / update files)
end

local function RefreshFromUnit(f, unit)
    if unit == f.unit then
        if UnitCastingInfo(unit) then
            StartCast(f, unit)
        elseif UnitChannelInfo(unit) then
            StartChannel(f, unit)
<<<<<<< HEAD
        else
            ResetState(f)
=======
>>>>>>> 9671a60 (Release v0.3.4 / update files)
        end
    end
end

-- Public methods
function PCB:CreateBars()
    for key, unit in pairs(BAR_UNITS) do
        if not self.Bars[key] then
            local f = CreateCastBarFrame(key)
<<<<<<< HEAD
            f:SetScript("OnUpdate", function(_, _) UpdateBar(f) end)
=======
>>>>>>> 9671a60 (Release v0.3.4 / update files)
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
<<<<<<< HEAD
            if not f or not self.db.bars[f.key].enabled then
                if f then ResetState(f) end
                return
=======
            if not f then return end
            if not self.db.bars[f.key].enabled then
                if event == "UNIT_SPELLCAST_START" or event == "UNIT_SPELLCAST_CHANNEL_START" or event == "UNIT_SPELLCAST_EMPOWER_START" then
                    return
                end
>>>>>>> 9671a60 (Release v0.3.4 / update files)
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
<<<<<<< HEAD
                        if self.db.showIcon and texture then
=======
                        local bdb = self.db.bars[f.key]
                        if bdb and bdb.showIcon and texture then
>>>>>>> 9671a60 (Release v0.3.4 / update files)
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
<<<<<<< HEAD
                        if self.db.showIcon and texture then
=======
                        local bdb = self.db.bars[f.key]
                        if bdb and bdb.showIcon and texture then
>>>>>>> 9671a60 (Release v0.3.4 / update files)
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
<<<<<<< HEAD
            elseif event == "UNIT_SPELLCAST_SUCCEEDED" then
                C_Timer.After(0, function() if f then RefreshFromUnit(f, unit) end end)
=======
            -- UNIT_SPELLCAST_SUCCEEDED is redundant - STOP event handles cast completion
            -- elseif event == "UNIT_SPELLCAST_SUCCEEDED" then
            --     C_Timer.After(0, function() if f then RefreshFromUnit(f, unit) end end)
>>>>>>> 9671a60 (Release v0.3.4 / update files)
            elseif event == "UNIT_SPELLCAST_EMPOWER_START" then
                StartEmpower(f, unit)
            elseif event == "UNIT_SPELLCAST_EMPOWER_UPDATE" then
                if f.empower then
                    local name, _, texture, startTimeMS, endTimeMS, _, _, notInterruptible = UnitCastingInfo(unit)
                    if name then
                        f.empower.startTimeMS = startTimeMS
                        f.empower.endTimeMS = endTimeMS
                        f.notInterruptible = notInterruptible
<<<<<<< HEAD
                        if self.db.showIcon and texture then
=======
                        local bdb = self.db.bars[f.key]
                        if bdb and bdb.showIcon and texture then
>>>>>>> 9671a60 (Release v0.3.4 / update files)
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

<<<<<<< HEAD
=======
-- Grid system for snapping
function PCB:CreateGrid()
    -- Destroy existing grid if it exists
    if self.gridFrame then
        self.gridFrame:Hide()
        for _, line in ipairs(self.gridFrame.lines or {}) do
            line:Hide()
            line:SetTexture(nil)
        end
        self.gridFrame.lines = nil
        self.gridFrame = nil
    end
    
    local gridFrame = CreateFrame("Frame", nil, UIParent)  -- Use anonymous frame so it recreates properly
    gridFrame:SetAllPoints(UIParent)
    gridFrame:SetFrameStrata("BACKGROUND")
    gridFrame:Hide()
    
    local gridSize = 25  -- pixels between grid lines
    local screenWidth = UIParent:GetWidth()
    local screenHeight = UIParent:GetHeight()
    local centerX = screenWidth / 2
    local centerY = screenHeight / 2
    
    gridFrame.lines = {}
    
    for x = centerX + gridSize, screenWidth, gridSize do
        local roundedX = math.floor(x + 0.5)
        local line = gridFrame:CreateTexture(nil, "BACKGROUND")
        line:SetTexture("Interface\\Buttons\\WHITE8x8")
        line:SetColorTexture(0.5, 0.5, 0.5, 0.3)
        -- Make line thick if it's close to a 125 pixel interval from center
        local offset = math.abs(roundedX - centerX)
        local remainder = offset % 125
        if remainder < 1 or remainder > 124 then
            line:SetSize(2, screenHeight)
            line:SetColorTexture(0.6, 0.6, 0.6, 0.4)
        else
            line:SetSize(1, screenHeight)
        end
        line:SetPoint("BOTTOMLEFT", UIParent, "BOTTOMLEFT", roundedX, 0)
        table.insert(gridFrame.lines, line)
    end
    
    for x = centerX - gridSize, 0, -gridSize do
        local roundedX = math.floor(x + 0.5)
        local line = gridFrame:CreateTexture(nil, "BACKGROUND")
        line:SetTexture("Interface\\Buttons\\WHITE8x8")
        line:SetColorTexture(0.5, 0.5, 0.5, 0.3)
        -- Make line thick if it's close to a 125 pixel interval from center
        local offset = math.abs(roundedX - centerX)
        local remainder = offset % 125
        if remainder < 1 or remainder > 124 then
            line:SetSize(2, screenHeight)
            line:SetColorTexture(0.6, 0.6, 0.6, 0.7)
        else
            line:SetSize(1, screenHeight)
        end
        line:SetPoint("BOTTOMLEFT", UIParent, "BOTTOMLEFT", roundedX, 0)
        table.insert(gridFrame.lines, line)
    end
    
    for y = centerY + gridSize, screenHeight, gridSize do
        local roundedY = math.floor(y + 0.5)
        local line = gridFrame:CreateTexture(nil, "BACKGROUND")
        line:SetTexture("Interface\\Buttons\\WHITE8x8")
        line:SetColorTexture(0.5, 0.5, 0.5, 0.3)
        -- Make line thick if it's close to a 125 pixel interval from center
        local offset = math.abs(roundedY - centerY)
        local remainder = offset % 125
        if remainder < 1 or remainder > 124 then
            line:SetSize(screenWidth, 2)
            line:SetColorTexture(0.6, 0.6, 0.6, 0.4)
        else
            line:SetSize(screenWidth, 1)
        end
        line:SetPoint("BOTTOMLEFT", UIParent, "BOTTOMLEFT", 0, roundedY)
        table.insert(gridFrame.lines, line)
    end
    
    for y = centerY - gridSize, 0, -gridSize do
        local roundedY = math.floor(y + 0.5)
        local line = gridFrame:CreateTexture(nil, "BACKGROUND")
        line:SetTexture("Interface\\Buttons\\WHITE8x8")
        line:SetColorTexture(0.5, 0.5, 0.5, 0.3)
        -- Make line thick if it's close to a 125 pixel interval from center
        local offset = math.abs(roundedY - centerY)
        local remainder = offset % 125
        if remainder < 1 or remainder > 124 then
            line:SetSize(screenWidth, 2)
            line:SetColorTexture(0.6, 0.6, 0.6, 0.4)
        else
            line:SetSize(screenWidth, 1)
        end
        line:SetPoint("BOTTOMLEFT", UIParent, "BOTTOMLEFT", 0, roundedY)
        table.insert(gridFrame.lines, line)
    end
    
    -- Thick center crosshair
    local centerLineV = gridFrame:CreateTexture(nil, "ARTWORK")
    centerLineV:SetTexture("Interface\\Buttons\\WHITE8x8")
    centerLineV:SetColorTexture(0.7, 0.7, 0.7, 0.8)
    centerLineV:SetSize(2, screenHeight)
    centerLineV:SetPoint("BOTTOMLEFT", UIParent, "BOTTOMLEFT", centerX - 1, 0)
    table.insert(gridFrame.lines, centerLineV)
    
    local centerLineH = gridFrame:CreateTexture(nil, "ARTWORK")
    centerLineH:SetTexture("Interface\\Buttons\\WHITE8x8")
    centerLineH:SetColorTexture(0.7, 0.7, 0.7, 0.8)
    centerLineH:SetSize(screenWidth, 2)
    centerLineH:SetPoint("BOTTOMLEFT", UIParent, "BOTTOMLEFT", 0, centerY - 1)
    table.insert(gridFrame.lines, centerLineH)
    
    self.gridFrame = gridFrame
    self.gridSize = gridSize
    self.gridCenterX = centerX
    self.gridCenterY = centerY
end

function PCB:ShowGrid()
    if not self.gridFrame then
        self:CreateGrid()
    end
    if self.gridFrame then
        self.gridFrame:Show()
    end
end

function PCB:HideGrid()
    if self.gridFrame then
        self.gridFrame:Hide()
    end
end

-- Lock button UI
function PCB:CreateLockButton()
    if self.lockButton then return end
    
    local frame = CreateFrame("Frame", "PhoenixCastBars_LockUI", UIParent, "BackdropTemplate")
    frame:SetSize(320, 120)
    frame:SetPoint("TOP", UIParent, "TOP", 0, -150)
    frame:SetFrameStrata("HIGH")
    frame:Hide()
    
    -- Background
    frame:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8x8",
        edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
        edgeSize = 32,
        insets = { left = 11, right = 12, top = 12, bottom = 11 }
    })
    frame:SetBackdropColor(0, 0, 0, 0.5)
    frame:SetBackdropBorderColor(1, 1, 1, 1)
    
    -- Title header bar
    local header = CreateFrame("Frame", nil, frame, "BackdropTemplate")
    header:SetSize(150, 30)
    header:SetPoint("TOP", frame, "TOP", 0, 10)
    header:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8x8",
        edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
        edgeSize = 16,
        insets = { left = 5, right = 5, top = 5, bottom = 5 }
    })
    header:SetBackdropColor(0, 0, 0, 0.8)
    header:SetBackdropBorderColor(1, 1, 1, 1)
    
    -- Title text
    local title = header:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    title:SetPoint("CENTER", header, "CENTER", 0, 0)
    title:SetText("PhoenixCastBars")
    title:SetTextColor(1, 0.82, 0, 1)
    
    -- Instructions
    local text = frame:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
    text:SetPoint("TOP", frame, "TOP", 0, -28)
    text:SetText("Bars unlocked. Move them now and click Lock\nwhen you are done.")
    text:SetJustifyH("CENTER")

    local btn = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
    btn:SetSize(120, 25)
    btn:SetPoint("BOTTOM", frame, "BOTTOM", 0, 15)
    btn:SetText("Lock")
    btn:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_TOP")
        GameTooltip:SetText("Lock Frames", 1, 1, 1)
        GameTooltip:AddLine("Locks all cast bars in place and hides the positioning grid.", nil, nil, nil, true)
        GameTooltip:Show()
    end)
    btn:SetScript("OnLeave", function(self)
        GameTooltip:Hide()
    end)
    btn:SetScript("OnClick", function()
        PCB.db.locked = true
        PCB:ApplyAll()
        frame:Hide()
    end)
    
    self.lockButton = frame
end

function PCB:ShowLockButton()
    self:CreateLockButton()
    self.lockButton:Show()
end

function PCB:HideLockButton()
    if self.lockButton then
        self.lockButton:Hide()
    end
end

function PCB:SnapToGrid(key, frame)
    -- Skip grid snapping if bar was already snapped to another bar
    if frame._wasSnapped then
        frame._wasSnapped = nil
        return
    end
    
    local gridSize = self.gridSize or 25
    
    local left = frame:GetLeft()
    local bottom = frame:GetBottom()
    local width = frame:GetWidth()
    local height = frame:GetHeight()
    
    if not left or not bottom then return end
    
    local frameTopCenterX = left + (width / 2)
    local frameTopCenterY = bottom + height
    
    -- Grid center (thick vertical line)
    local gridCenterX = self.gridCenterX or (UIParent:GetWidth() / 2)
    
    -- Only snap to center vertical line (not grid lines)
    local SNAP_THRESHOLD = 15
    local distanceToCenter = math.abs(frameTopCenterX - gridCenterX)
    
    if distanceToCenter < SNAP_THRESHOLD then
        -- Snap to center line
        frame:ClearAllPoints()
        frame:SetPoint("TOP", UIParent, "BOTTOMLEFT", gridCenterX, frameTopCenterY)
    end
end

function PCB:SnapPosition(key, frame)
    -- Clear flag defensively in case it persisted
    frame._wasSnapped = nil
    
    local snapThreshold = SNAP_THRESHOLD
    
    -- Get current position
    local left = frame:GetLeft()
    local right = frame:GetRight()
    local top = frame:GetTop()
    local bottom = frame:GetBottom()
    
    if not left or not top then return end
    
    local centerX = (left + right) / 2
    local centerY = (top + bottom) / 2
    local width = frame:GetWidth()
    local height = frame:GetHeight()
    
    local bestSnapX, bestSnapY = nil, nil
    local bestDistX, bestDistY = snapThreshold, snapThreshold
    
    -- Check snap to other bars first (higher priority)
    for otherKey, otherFrame in pairs(self.Bars) do
        if otherKey ~= key and otherFrame:IsShown() then
            local oLeft = otherFrame:GetLeft()
            local oRight = otherFrame:GetRight()
            local oTop = otherFrame:GetTop()
            local oBottom = otherFrame:GetBottom()
            
            if oLeft and oTop then
                local oCenterX = (oLeft + oRight) / 2
                local oCenterY = (oTop + oBottom) / 2
                
                -- Snap to horizontal alignment (left edges)
                local distLeft = math.abs(left - oLeft)
                if distLeft < bestDistX then
                    bestDistX = distLeft
                    bestSnapX = oLeft
                end
                
                -- Snap to right edges
                local distRight = math.abs(right - oRight)
                if distRight < bestDistX then
                    bestDistX = distRight
                    bestSnapX = oRight - width
                end
                
                -- Snap to centers
                local distCenterX = math.abs(centerX - oCenterX)
                if distCenterX < bestDistX then
                    bestDistX = distCenterX
                    bestSnapX = oCenterX - (width / 2)
                end
                
                -- Snap to stacking (center bottom of this bar to center top of other bar)
                local distStackBelow = math.abs(bottom - oTop)
                if distStackBelow < snapThreshold then
                    bestDistY = 0
                    bestSnapY = oTop - height
                    bestSnapX = oCenterX - (width / 2)
                end
                
                -- Snap to stacking (center top of this bar to center bottom of other bar)
                local distStackAbove = math.abs(top - oBottom)
                if distStackAbove < snapThreshold then
                    bestDistY = 0
                    bestSnapY = oBottom
                    bestSnapX = oCenterX - (width / 2)
                end
                
                -- Snap to horizontal stacking (right edge of this bar to left edge of other bar)
                local distStackRight = math.abs(right - oLeft)
                if distStackRight < snapThreshold then
                    bestDistX = 0
                    bestSnapX = oLeft - width
                    -- Align based on closest vertical edge
                    local distTop = math.abs(top - oTop)
                    local distBottom = math.abs(bottom - oBottom)
                    local distCenterY = math.abs(centerY - oCenterY)
                    if distTop < distBottom and distTop < distCenterY then
                        bestSnapY = oTop - height
                    elseif distBottom < distCenterY then
                        bestSnapY = oBottom
                    else
                        bestSnapY = oCenterY - (height / 2)
                    end
                end
                
                -- Snap to horizontal stacking (left edge of this bar to right edge of other bar)
                local distStackLeft = math.abs(left - oRight)
                if distStackLeft < snapThreshold then
                    bestDistX = 0
                    bestSnapX = oRight
                    -- Align based on closest vertical edge
                    local distTop = math.abs(top - oTop)
                    local distBottom = math.abs(bottom - oBottom)
                    local distCenterY = math.abs(centerY - oCenterY)
                    if distTop < distBottom and distTop < distCenterY then
                        bestSnapY = oTop - height
                    elseif distBottom < distCenterY then
                        bestSnapY = oBottom
                    else
                        bestSnapY = oCenterY - (height / 2)
                    end
                end
            end
        end
    end
    
    -- Screen dimensions (lower priority, only if no bar snap found)
    if not bestSnapX or not bestSnapY then
        local screenWidth = UIParent:GetWidth()
        local screenHeight = UIParent:GetHeight()
        local screenCenterX = screenWidth / 2
        local screenCenterY = screenHeight / 2
        
        -- Screen horizontal snapping
        if not bestSnapX then
            if math.abs(left) < bestDistX then
                bestSnapX = 0
            elseif math.abs(right - screenWidth) < bestDistX then
                bestSnapX = screenWidth - width
            elseif math.abs(centerX - screenCenterX) < bestDistX then
                bestSnapX = screenCenterX - (width / 2)
            end
        end
        
        -- Screen vertical snapping
        if not bestSnapY then
            if math.abs(top - screenHeight) < bestDistY then
                bestSnapY = screenHeight - height
            elseif math.abs(bottom) < bestDistY then
                bestSnapY = 0
            elseif math.abs(centerY - screenCenterY) < bestDistY then
                bestSnapY = screenCenterY - (height / 2)
            end
        end
    end
    
    -- Apply snapping
    if bestSnapX or bestSnapY then
        frame._wasSnapped = true
        frame:ClearAllPoints()
        frame:SetPoint("BOTTOMLEFT", UIParent, "BOTTOMLEFT", 
                      bestSnapX or left, bestSnapY or bottom)
        
        -- Visual feedback: brief border flash
        if frame.bg then
            local r, g, b, a = frame.bg:GetBackdropBorderColor()
            frame.bg:SetBackdropBorderColor(0.4, 0.8, 1.0, 1.0)
            C_Timer.After(0.15, function()
                if frame and frame.bg then
                    frame.bg:SetBackdropBorderColor(r, g, b, a)
                end
            end)
        end
    else
        -- No snap occurred - check for overlap prevention (with 3px threshold)
        local overlapThreshold = 3
        local hasOverlap = false
        for otherKey, otherFrame in pairs(self.Bars) do
            if otherKey ~= key and otherFrame:IsShown() then
                local oLeft = otherFrame:GetLeft()
                local oRight = otherFrame:GetRight()
                local oTop = otherFrame:GetTop()
                local oBottom = otherFrame:GetBottom()
                
                if oLeft and oTop then
                    -- Check if frames overlap beyond threshold
                    if not (right < (oLeft - overlapThreshold) or left > (oRight + overlapThreshold) or 
                            top < (oBottom - overlapThreshold) or bottom > (oTop + overlapThreshold)) then
                        hasOverlap = true
                        -- Flash red to indicate overlap
                        if frame.bg then
                            local r, g, b, a = frame.bg:GetBackdropBorderColor()
                            frame.bg:SetBackdropBorderColor(1.0, 0.2, 0.2, 1.0)
                            C_Timer.After(0.3, function()
                                if frame and frame.bg then
                                    frame.bg:SetBackdropBorderColor(r, g, b, a)
                                end
                            end)
                        end
                        break
                    end
                end
            end
        end
    end
end

function PCB:UpdateSnapIndicator(key, frame)
    local left = frame:GetLeft()
    local right = frame:GetRight()
    local top = frame:GetTop()
    local bottom = frame:GetBottom()
    
    if not left or not top then return end
    
    local snapThreshold = SNAP_THRESHOLD
    local closestFrame = nil
    local minDist = snapThreshold
    
    -- Find closest bar within snap range
    for otherKey, otherFrame in pairs(self.Bars) do
        if otherKey ~= key and otherFrame:IsShown() then
            local oLeft = otherFrame:GetLeft()
            local oRight = otherFrame:GetRight()
            local oTop = otherFrame:GetTop()
            local oBottom = otherFrame:GetBottom()
            
            if oLeft and oTop then
                local oCenterX = (oLeft + oRight) / 2
                local centerX = (left + right) / 2
                
                -- Check various snap distances
                local dists = {
                    math.abs(bottom - oTop),
                    math.abs(top - oBottom),
                    math.abs(right - oLeft),
                    math.abs(left - oRight),
                    math.abs(centerX - oCenterX)
                }
                
                for _, d in ipairs(dists) do
                    if d < minDist then
                        minDist = d
                        closestFrame = otherFrame
                    end
                end
            end
        end
    end
    
    if closestFrame then
        self:ShowSnapIndicator(frame, closestFrame)
    else
        self:HideSnapIndicator()
    end
end

function PCB:ShowSnapIndicator(frame, targetFrame)
    if not self.snapIndicator then
        local line = UIParent:CreateLine()
        line:SetColorTexture(0.4, 0.8, 1.0, 0.6)
        line:SetThickness(2)
        line:SetDrawLayer("OVERLAY")
        self.snapIndicator = line
    end
    
    local fLeft, fRight = frame:GetLeft(), frame:GetRight()
    local fTop, fBottom = frame:GetTop(), frame:GetBottom()
    local tLeft, tRight = targetFrame:GetLeft(), targetFrame:GetRight()
    local tTop, tBottom = targetFrame:GetTop(), targetFrame:GetBottom()
    
    if fLeft and tLeft then
        local fCenterX, fCenterY = (fLeft + fRight) / 2, (fTop + fBottom) / 2
        local tCenterX, tCenterY = (tLeft + tRight) / 2, (tTop + tBottom) / 2
        
        self.snapIndicator:SetStartPoint("BOTTOMLEFT", UIParent, "BOTTOMLEFT", fCenterX, fCenterY)
        self.snapIndicator:SetEndPoint("BOTTOMLEFT", UIParent, "BOTTOMLEFT", tCenterX, tCenterY)
        self.snapIndicator:Show()
    end
end

function PCB:HideSnapIndicator()
    if self.snapIndicator then
        self.snapIndicator:Hide()
    end
end

function PCB:ResetPositions()
    -- Reset all bars to their default positions
    local defaults = {
        player = { point = "CENTER", relPoint = "CENTER", x = 0, y = -180 },
        target = { point = "CENTER", relPoint = "CENTER", x = 0, y = -140 },
        focus = { point = "CENTER", relPoint = "CENTER", x = 0, y = -110 }
    }
    
    for key, defaultPos in pairs(defaults) do
        if self.db.bars[key] then
            self.db.bars[key].point = defaultPos.point
            self.db.bars[key].relPoint = defaultPos.relPoint
            self.db.bars[key].x = defaultPos.x
            self.db.bars[key].y = defaultPos.y
        end
    end
    
    self:ApplyAll()
end

function PCB:ResetSinglePosition(key)
    -- Reset a single bar to its default position (used by double-click)
    local defaults = {
        player = { point = "CENTER", relPoint = "CENTER", x = 0, y = -180 },
        target = { point = "CENTER", relPoint = "CENTER", x = 0, y = -140 },
        focus = { point = "CENTER", relPoint = "CENTER", x = 0, y = -110 }
    }
    
    local defaultPos = defaults[key]
    if defaultPos and self.db.bars[key] then
        self.db.bars[key].point = defaultPos.point
        self.db.bars[key].relPoint = defaultPos.relPoint
        self.db.bars[key].x = defaultPos.x
        self.db.bars[key].y = defaultPos.y
        self:ApplyBarConfig(key)
    end
end

>>>>>>> 9671a60 (Release v0.3.4 / update files)
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
<<<<<<< HEAD
    local texture = self:ResolveStatusbarTexture()
    local font = self:ResolveFont()
    local fontSize = db.fontSize or 12
    local outline = db.outline or "OUTLINE"
=======
    
    -- Use per-bar overrides if set, otherwise use global settings
    local texture, font, fontSize, outline
    
    -- Texture override
    if b.enableTextureOverride and b.textureKey and b.textureKey ~= "" then
        texture = self:ResolveStatusbarTexture({ textureKey = b.textureKey, useGlobalTexture = false, texturePath = b.texturePath })
    else
        texture = self:ResolveStatusbarTexture()
    end

    -- Font override
    if b.enableFontOverride and b.fontKey and b.fontKey ~= "" then
        font = self:ResolveFont({ fontKey = b.fontKey, useGlobalFont = false, fontPath = b.fontPath })
    else
        font = self:ResolveFont()
    end

    -- Font size (no per-bar override currently, use global)
    fontSize = db.fontSize or 12

    -- Outline override
    if b.enableOutlineOverride and b.outline and b.outline ~= "" then
        outline = b.outline
    else
        outline = db.outline or "OUTLINE"
    end
>>>>>>> 9671a60 (Release v0.3.4 / update files)

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
<<<<<<< HEAD
=======
    
    -- Show/hide lock button and grid based on unlock state
    if unlocked then
        PCB:ShowLockButton()
        PCB:ShowGrid()
    else
        PCB:HideLockButton()
        PCB:HideGrid()
        PCB:HideSnapIndicator()
    end
>>>>>>> 9671a60 (Release v0.3.4 / update files)

    -- enabled state
    if b.enabled then
        RefreshFromUnit(f, f.unit)
        if unlocked and (not f.cast and not f.channel and not f.empower) then
            PCB_SetMoverMode(f, true)
<<<<<<< HEAD
        end
    else
        ResetState(f)
=======
        elseif not unlocked and (not f.cast and not f.channel and not f.empower) then
            -- When locking bars, hide them if there's no active cast
            f:Hide()
        end
    else
        ResetState(f, true)
>>>>>>> 9671a60 (Release v0.3.4 / update files)
    end
end

function PCB:ApplyAll()
<<<<<<< HEAD
=======
    -- Preserve test mode state
    local wasInTestMode = self.testMode
    
>>>>>>> 9671a60 (Release v0.3.4 / update files)
    for key in pairs(BAR_UNITS) do self:ApplyBarConfig(key) end
    -- safe-zone color refresh
    for _, f in pairs(self.Bars) do
        if f.safeZone and f.safeZone:IsShown() then
            f.safeZone:SetVertexColor(self:ColorFromTable(self.db.safeZoneColor))
        end
    end
<<<<<<< HEAD
=======
    -- Update Blizzard cast bars based on setting
    self:UpdateBlizzardCastBars()
    
    -- Restore test mode if it was active
    if wasInTestMode then
        self:SetTestMode(true)
    end
>>>>>>> 9671a60 (Release v0.3.4 / update files)
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
<<<<<<< HEAD
    if f.spark     then f.spark:Hide() end
=======
    if f.spark and not f.test then f.spark:Hide() end
>>>>>>> 9671a60 (Release v0.3.4 / update files)

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
<<<<<<< HEAD
=======
-- ============================================================
-- Test Mode (dummy casts for configuration)
-- ============================================================
function PCB:SetTestMode(enabled)
    self.testMode = enabled and true or false
    if not self.Bars then return end
    for key, f in pairs(self.Bars) do
        if self.testMode then
            -- show enabled bars, start a fake cast
            local bdb = (self.db and self.db.bars and self.db.bars[key]) or nil
            if bdb and bdb.enabled then
                f.test = {
                    start = GetTime(),
                    dur = 3.5,
                    name = "Test Cast",
                    icon = "Interface\\Icons\\INV_Misc_QuestionMark",
                    notInterruptible = false,
                }
                f:Show()
            else
                f.test = nil
                f:Hide()
            end
        else
            f.test = nil
            -- allow normal event-driven visibility to take over; hide if no active cast/channel
            if not f.cast and not f.channel and not f.empower then
                f:Hide()
            end
        end
    end
end
>>>>>>> 9671a60 (Release v0.3.4 / update files)
