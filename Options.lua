-- PhoenixCastBars Options (Retail + Legacy compatible)
-- Hotfix: panel is now scrollable inside Blizzard Settings / AddOns.

local ADDON_NAME, PCB = ...
local Options = {}
PCB.Options = Options

local DEFAULT_TEXTURE = "Interface\\TARGETINGFRAME\\UI-StatusBar"
local DEFAULT_FONT    = "Fonts\\FRIZQT__.TTF"

-- Layout constants (tuned for Blizzard Settings panel width)
local COL1_X      = 24
local COL2_X      = 380
local LABEL_W     = 150
local CONTROL_W   = 240
local ROW_H       = 34
local SECTION_GAP = 18

local _sliderCounter = 0

local function SafeApply()
    if PCB and PCB.ApplyAll then
        PCB:ApplyAll()
    end
end

local function EnsureDB()
    PCB.db = PCB.db or {}
    
    if PCB.db.hideBlizzardCastBars == nil then PCB.db.hideBlizzardCastBars = true end
PCB.db.bars = PCB.db.bars or {}
    PCB.db.bars.player = PCB.db.bars.player or {}
    PCB.db.bars.target = PCB.db.bars.target or {}
    PCB.db.bars.focus  = PCB.db.bars.focus  or {}
end

local function CreateHeader(parent, text, x, y)
    local fs = parent:CreateFontString(nil, "ARTWORK", "GameFontHighlightLarge")
    fs:SetPoint("TOPLEFT", parent, "TOPLEFT", x, y)
    fs:SetText(text)
    return fs
end

local function CreateLabel(parent, text, x, y)
    local fs = parent:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
    fs:SetPoint("TOPLEFT", parent, "TOPLEFT", x, y)
    fs:SetWidth(LABEL_W)
    fs:SetJustifyH("LEFT")
    fs:SetText(text)
    return fs
end

local function CreateCheckbox(parent, label, tooltip, x, y, getter, setter)
    local cb = CreateFrame("CheckButton", nil, parent, "InterfaceOptionsCheckButtonTemplate")
    cb:SetPoint("TOPLEFT", parent, "TOPLEFT", x, y)
    cb.Text:SetText(label)
    cb.tooltipText = tooltip or ""
    cb:SetScript("OnClick", function(self)
        setter(self:GetChecked() and true or false)
        SafeApply()
    end)
    cb.Refresh = function()
        cb:SetChecked(getter() and true or false)
    end
    return cb
end

local function CreateNamedSlider(parent, label, tooltip, x, y, minVal, maxVal, step, width, getter, setter)
    _sliderCounter = _sliderCounter + 1
    local name = "PhoenixCastBarsOptionsSlider" .. _sliderCounter

    local s = CreateFrame("Slider", name, parent, "OptionsSliderTemplate")
    s:SetPoint("TOPLEFT", parent, "TOPLEFT", x, y)
    s:SetMinMaxValues(minVal, maxVal)
    s:SetValueStep(step)
    s:SetObeyStepOnDrag(true)
    s:SetWidth(width or CONTROL_W)
    s.tooltipText = tooltip or ""

    local textFS = s.Text or _G[name .. "Text"] or _G[s:GetName() .. "Text"]
    local lowFS  = s.Low  or _G[name .. "Low"]  or _G[s:GetName() .. "Low"]
    local highFS = s.High or _G[name .. "High"] or _G[s:GetName() .. "High"]

    if textFS then textFS:SetText(label) end
    if lowFS then lowFS:SetText(tostring(minVal)) end
    if highFS then highFS:SetText(tostring(maxVal)) end

    local updating = false
    s:SetScript("OnValueChanged", function(self, v)
        if updating then return end
        setter(v)
        SafeApply()
    end)

    s.Refresh = function()
        updating = true
        local v = getter()
        if type(v) ~= "number" then v = minVal end
        if v < minVal then v = minVal end
        if v > maxVal then v = maxVal end
        s:SetValue(v)
        updating = false
    end

    return s
end

local function CreateDropdown(parent, label, tooltip, x, y, choices, getter, setter)
    CreateLabel(parent, label, x, y + 6)

    local dd = CreateFrame("Frame", nil, parent, "UIDropDownMenuTemplate")
    dd:SetPoint("TOPLEFT", parent, "TOPLEFT", x + LABEL_W - 10, y + 10)
    UIDropDownMenu_SetWidth(dd, CONTROL_W)
    dd.tooltipText = tooltip or ""

    local function OnClick(self)
        setter(self.value)
        UIDropDownMenu_SetSelectedValue(dd, self.value)
        UIDropDownMenu_SetText(dd, self.text)
        SafeApply()
    end

    UIDropDownMenu_Initialize(dd, function(_, level)
        local current = getter()
        for i = 1, #choices do
            local info = UIDropDownMenu_CreateInfo()
            info.text = choices[i].name
            info.value = choices[i].value
            info.func = OnClick
            info.checked = (current == choices[i].value)
            UIDropDownMenu_AddButton(info, level)
        end
    end)

    dd.Refresh = function()
        local v = getter()
        for i = 1, #choices do
            if choices[i].value == v then
                UIDropDownMenu_SetSelectedValue(dd, v)
                UIDropDownMenu_SetText(dd, choices[i].name)
                return
            end
        end
        UIDropDownMenu_SetSelectedValue(dd, v)
        UIDropDownMenu_SetText(dd, tostring(v))
    end

    return dd
end

local function CreateScrollableCanvas(panel)
    -- Blizzard Settings "canvas" does not automatically scroll; we provide our own scrollframe.
    local scroll = CreateFrame("ScrollFrame", nil, panel, "UIPanelScrollFrameTemplate")
    scroll:SetPoint("TOPLEFT", panel, "TOPLEFT", 0, 0)
    scroll:SetPoint("BOTTOMRIGHT", panel, "BOTTOMRIGHT", -28, 0) -- leave room for scrollbar

    local content = CreateFrame("Frame", nil, scroll)
    content:SetPoint("TOPLEFT", scroll, "TOPLEFT", 0, 0)
    content:SetSize(1, 1) -- will be resized after layout
    scroll:SetScrollChild(content)

    panel._scroll = scroll
    panel._content = content
    return content
end

function Options:Init()
    EnsureDB()

    local panel = CreateFrame("Frame", "PhoenixCastBarsOptionsPanel", UIParent)
    panel.name = "PhoenixCastBars"


    local title = panel:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
    title:SetPoint("TOPLEFT", panel, "TOPLEFT", 16, -16)
    title:SetText(("PhoenixCastBars v%s"):format(PCB.version or "?"))
    -- Register with Settings (Retail) or InterfaceOptions (legacy)
    if Settings and Settings.RegisterCanvasLayoutCategory and Settings.RegisterAddOnCategory then
        local category = Settings.RegisterCanvasLayoutCategory(panel, panel.name)
        Settings.RegisterAddOnCategory(category)
        self._categoryID = category:GetID()
    elseif InterfaceOptions_AddCategory then
        InterfaceOptions_AddCategory(panel)
    end

    local root = CreateScrollableCanvas(panel)

    local TEXTURES = {
        { name = "Blizzard (UI-StatusBar)", value = DEFAULT_TEXTURE },
        { name = "Phoenix (CastBar)", value = "Interface\\AddOns\\PhoenixCastBars\\Media\\Phoenix_CastBar" },
    }

    local FONTS = {
        { name = "Friz Quadrata (Default)", value = DEFAULT_FONT },
        { name = "Arial Narrow", value = "Fonts\\ARIALN.TTF" },
        { name = "Morpheus", value = "Fonts\\MORPHEUS.TTF" },
        { name = "Skurri", value = "Fonts\\SKURRI.TTF" },
    }

    local OUTLINES = {
        { name = "Outline", value = "OUTLINE" },
        { name = "Thick Outline", value = "THICKOUTLINE" },
        { name = "None", value = "" },
    }

    local y = -18

    -- =========================
    -- Media
    -- =========================
    CreateHeader(root, "Media", COL1_X, y); y = y - (ROW_H + 6)

    local ddTex = CreateDropdown(root, "Castbar texture", "Select the castbar statusbar texture.", COL1_X, y, TEXTURES,
        function() return PCB.db.texture or DEFAULT_TEXTURE end,
        function(v) PCB.db.texture = v end
    )
    y = y - ROW_H

    local ddFont = CreateDropdown(root, "Font", "Select the font used for castbar text.", COL1_X, y, FONTS,
        function() return PCB.db.font or DEFAULT_FONT end,
        function(v) PCB.db.font = v end
    )
    y = y - ROW_H

    local ddOutline = CreateDropdown(root, "Font outline", "Select text outline style.", COL1_X, y, OUTLINES,
        function() return PCB.db.outline or "OUTLINE" end,
        function(v) PCB.db.outline = v end
    )
    y = y - ROW_H

    local fontSize = CreateNamedSlider(root, "Font size", "Size of the cast bar font.", COL1_X, y + 2, 8, 20, 1, CONTROL_W,
        function() return PCB.db.fontSize or 12 end,
        function(v) PCB.db.fontSize = v end
    )
    y = y - (ROW_H + SECTION_GAP)

    -- =========================
    -- General (2-column checkboxes)
    -- =========================
    CreateHeader(root, "General", COL1_X, y); y = y - (ROW_H - 4)

    local g1y = y
    local g2y = y

    local cbLocked = CreateCheckbox(root, "Lock frames", "When enabled, frames cannot be dragged.", COL1_X, g1y,
        function() return PCB.db.locked end,
        function(v) PCB.db.locked = v end
    )
    g1y = g1y - 28

    local cbHideBlizz = CreateCheckbox(root, "Hide Blizzard cast bars", "Hides the default Blizzard player/target/focus cast bars while PhoenixCastBars is enabled.", COL1_X, g1y,
        function() return PCB.db.hideBlizzardCastBars end,
        function(v) PCB.db.hideBlizzardCastBars = v end
    )
    g1y = g1y - 28


    local cbSpellName = CreateCheckbox(root, "Show spell name", "Shows the spell name on the cast bar.", COL1_X, g1y,
        function() return PCB.db.showSpellName end,
        function(v) PCB.db.showSpellName = v end
    )
    g1y = g1y - 28

    local cbLatency = CreateCheckbox(root, "Show latency (player)", "Shows input latency safe-zone (player casts only).", COL1_X, g1y,
        function() return PCB.db.showLatency end,
        function(v) PCB.db.showLatency = v end
    )
    g1y = g1y - 28

    local cbIcon = CreateCheckbox(root, "Show spell icon", "Displays the spell icon to the left of the cast bar.", COL2_X, g2y,
        function() return PCB.db.showIcon end,
        function(v) PCB.db.showIcon = v end
    )
    g2y = g2y - 28

    local cbSpark = CreateCheckbox(root, "Show spark", "Shows a spark indicator on the cast bar.", COL2_X, g2y,
        function() return PCB.db.showSpark end,
        function(v) PCB.db.showSpark = v end
    )
    g2y = g2y - 28

    local cbTime = CreateCheckbox(root, "Show time", "Shows remaining / total time on the cast bar.", COL2_X, g2y,
        function() return PCB.db.showTime end,
        function(v) PCB.db.showTime = v end
    )
    g2y = g2y - 28

    local cbShield = CreateCheckbox(root, "Show interrupt shield", "Shows a shield indicator when the cast is not interruptible.", COL2_X, g2y,
        function() return PCB.db.showInterruptShield end,
        function(v) PCB.db.showInterruptShield = v end
    )
    g2y = g2y - 28

    y = math.min(g1y, g2y) - SECTION_GAP

    -- =========================
    -- Bars
    -- =========================
    CreateHeader(root, "Bars", COL1_X, y); y = y - (ROW_H - 4)

    local b1y = y
    local b2y = y

    local cbPlayer = CreateCheckbox(root, "Enable Player bar", "", COL1_X, b1y,
        function() return PCB.db.bars.player.enabled end,
        function(v) PCB.db.bars.player.enabled = v end
    )
    b1y = b1y - 28

    local cbFocus = CreateCheckbox(root, "Enable Focus bar", "", COL1_X, b1y,
        function() return PCB.db.bars.focus.enabled end,
        function(v) PCB.db.bars.focus.enabled = v end
    )
    b1y = b1y - 28

    local cbTarget = CreateCheckbox(root, "Enable Target bar", "", COL2_X, b2y,
        function() return PCB.db.bars.target.enabled end,
        function(v) PCB.db.bars.target.enabled = v end
    )
    b2y = b2y - 28

    y = math.min(b1y, b2y) - 10

    -- Size grid
    local sPlayerW = CreateNamedSlider(root, "Player width", "", COL1_X, y, 60, 420, 1, CONTROL_W,
        function() return PCB.db.bars.player.width or 240 end,
        function(v) PCB.db.bars.player.width = v end
    )
    local sPlayerH = CreateNamedSlider(root, "Player height", "", COL2_X, y, 10, 30, 1, CONTROL_W,
        function() return PCB.db.bars.player.height or 16 end,
        function(v) PCB.db.bars.player.height = v end
    )
    y = y - ROW_H

    local sTargetW = CreateNamedSlider(root, "Target width", "", COL1_X, y, 60, 420, 1, CONTROL_W,
        function() return PCB.db.bars.target.width or 240 end,
        function(v) PCB.db.bars.target.width = v end
    )
    local sTargetH = CreateNamedSlider(root, "Target height", "", COL2_X, y, 10, 30, 1, CONTROL_W,
        function() return PCB.db.bars.target.height or 16 end,
        function(v) PCB.db.bars.target.height = v end
    )
    y = y - ROW_H

    local sFocusW = CreateNamedSlider(root, "Focus width", "", COL1_X, y, 60, 420, 1, CONTROL_W,
        function() return PCB.db.bars.focus.width or 240 end,
        function(v) PCB.db.bars.focus.width = v end
    )
    local sFocusH = CreateNamedSlider(root, "Focus height", "", COL2_X, y, 10, 30, 1, CONTROL_W,
        function() return PCB.db.bars.focus.height or 16 end,
        function(v) PCB.db.bars.focus.height = v end
    )
    y = y - (ROW_H + SECTION_GAP)

    -- =========================
    -- Actions (left aligned)
    -- =========================
    CreateHeader(root, "Actions", COL1_X, y); y = y - (ROW_H - 8)

    local apply = CreateFrame("Button", nil, root, "UIPanelButtonTemplate")
    apply:SetPoint("TOPLEFT", root, "TOPLEFT", COL1_X, y)
    apply:SetText("Apply")
    apply:SetWidth(120)
    apply:SetScript("OnClick", function() SafeApply() end)

    local reset = CreateFrame("Button", nil, root, "UIPanelButtonTemplate")
    reset:SetPoint("LEFT", apply, "RIGHT", 10, 0)
    reset:SetText("Reset (Reload UI)")
    reset:SetWidth(160)
    reset:SetScript("OnClick", function() ReloadUI() end)

    -- Resize scroll child to fit content (padding at bottom)
    root:SetHeight((-y) + 80)
    root:SetWidth(1)

    -- Panel refresh
    panel.Refresh = function()
        EnsureDB()
        ddTex.Refresh(); ddFont.Refresh(); ddOutline.Refresh()
        fontSize:Refresh()

        cbLocked.Refresh(); cbHideBlizz.Refresh(); cbIcon.Refresh(); cbSpark.Refresh(); cbSpellName.Refresh()
        cbTime.Refresh(); cbLatency.Refresh(); cbShield.Refresh()

        cbPlayer.Refresh(); cbTarget.Refresh(); cbFocus.Refresh()

        sPlayerW:Refresh(); sPlayerH:Refresh()
        sTargetW:Refresh(); sTargetH:Refresh()
        sFocusW:Refresh();  sFocusH:Refresh()
    end

    panel:SetScript("OnShow", function()
        if panel.Refresh then panel.Refresh() end
    end)
end

function Options:Open()
    if Settings and Settings.OpenToCategory and self._categoryID then
        Settings.OpenToCategory(self._categoryID)
        return
    end

    if InterfaceOptionsFrame_OpenToCategory then
        InterfaceOptionsFrame_OpenToCategory("PhoenixCastBars")
        InterfaceOptionsFrame_OpenToCategory("PhoenixCastBars")
        return
    end

    if InterfaceOptionsFrame then
        InterfaceOptionsFrame:Show()
    end
end
