<<<<<<< HEAD
local _pcbToggleHooked = false

-- Add scrollbar to long dropdown lists
local function PCB_EnsureDropDownScrollHook()
    if _pcbToggleHooked then return end
    _pcbToggleHooked = true
    hooksecurefunc("ToggleDropDownMenu", function(level)
        level = level or 1
        local listFrame = _G["DropDownList" .. level]
        if not listFrame then return end
        local maxButtons = listFrame.PCB_maxButtons or UIDROPDOWNMENU_MAXBUTTONS or 15
        local numButtons = listFrame.numButtons or 0
        if numButtons > maxButtons then
            local firstBtn = _G["DropDownList" .. level .. "Button1"]
            local btnHeight = (firstBtn and firstBtn:GetHeight()) or 16
            local padding = 24
            listFrame:SetHeight((btnHeight * maxButtons) + padding)

            local scrollbar = listFrame.PCB_ScrollBar
            if not scrollbar then
                scrollbar = CreateFrame("Slider", listFrame:GetName() .. "PCBScrollBar", listFrame)
                scrollbar:SetOrientation("VERTICAL")
                scrollbar:SetPoint("TOPRIGHT", listFrame, "TOPRIGHT", -4, -12)
                scrollbar:SetPoint("BOTTOMRIGHT", listFrame, "BOTTOMRIGHT", -4, 12)
                scrollbar:SetWidth(16)
                scrollbar:SetMinMaxValues(0, 1)
                scrollbar:SetValueStep(1)
                scrollbar:SetObeyStepOnDrag(true)
                
                -- Create thumb texture
                local thumb = scrollbar:CreateTexture(nil, "OVERLAY")
                thumb:SetTexture("Interface\\Buttons\\UI-ScrollBar-Knob")
                thumb:SetSize(16, 24)
                scrollbar:SetThumbTexture(thumb)
                
                listFrame.PCB_ScrollBar = scrollbar
            end

            local scrollbarWidth = 20
            local btnH = btnHeight
            
            -- Manually position buttons instead of using ScrollFrame to avoid mouse tracking issues
            -- Buttons remain children of listFrame so hovering scrollbar doesn't close dropdown
            local function UpdateButtonPositions(scrollOffset)
                scrollOffset = math.floor(scrollOffset or 0)
                local nb = listFrame.numButtons or 0
                local maxScroll = math.max(0, nb - maxButtons)
                -- Clamp scroll offset to valid range
                if scrollOffset < 0 then scrollOffset = 0 end
                if scrollOffset > maxScroll then scrollOffset = maxScroll end
                
                listFrame.PCB_ScrollOffset = scrollOffset
                
                if scrollbar then
                    pcall(function()
                        scrollbar:SetMinMaxValues(0, maxScroll)
                        scrollbar:SetValue(scrollOffset)
                        if maxScroll > 0 then
                            scrollbar:Show()
                        else
                            scrollbar:Hide()
                        end
                    end)
                end
                
                -- Show/hide and position buttons based on scroll offset to create a scrolling window
                for i = 1, nb do
                    local btn = _G[listFrame:GetName() .. "Button" .. i]
                    if btn then
                        local visiblePos = i - scrollOffset
                        if visiblePos >= 1 and visiblePos <= maxButtons then
                            btn:ClearAllPoints()
                            btn:SetPoint("TOPLEFT", listFrame, "TOPLEFT", 12, -((visiblePos - 1) * btnH) - 12)
                            btn:SetPoint("RIGHT", listFrame, "RIGHT", -(scrollbarWidth + 4), 0)
                            btn:Show()
                        else
                            btn:Hide()
                        end
                    end
                end
            end

            -- Hook scripts only once to avoid duplicate handlers
            if not listFrame.PCB_Hooked then
                listFrame.PCB_Hooked = true
                
                listFrame:EnableMouseWheel(true)

                if scrollbar and scrollbar.SetScript then
                    scrollbar:SetScript("OnValueChanged", function(self, value)
                        UpdateButtonPositions(value)
                    end)
                end

                listFrame:HookScript("OnShow", function(self)
                    UpdateButtonPositions(0)
                end)

                -- Use SetScript to consume mousewheel events and prevent propagation to parent frames
                listFrame:SetScript("OnMouseWheel", function(self, delta)
                    local currentOffset = listFrame.PCB_ScrollOffset or 0
                    local newOffset = currentOffset - delta
                    UpdateButtonPositions(newOffset)
                end)

                listFrame.PCB_UpdateButtons = UpdateButtonPositions
            else
                local currentOffset = listFrame.PCB_ScrollOffset or 0
                UpdateButtonPositions(currentOffset)
            end

            UpdateButtonPositions(0)
        else
            listFrame:SetHeight((numButtons * (listFrame.ButtonHeight or 16)) + 24)
            if listFrame.PCB_ScrollBar then
                listFrame.PCB_ScrollBar:Hide()
            end
            for i = 1, numButtons do
                local btn = _G[listFrame:GetName() .. "Button" .. i]
                if not btn then break end
                btn:Show()
                btn:ClearAllPoints()
                btn:SetPoint("TOPLEFT", listFrame, "TOPLEFT", 12, -((i-1) * (btn:GetHeight() or 16)) - 12)
                btn:SetPoint("RIGHT", listFrame, "RIGHT", -12, 0)
            end
        end
    end)
end

local function PCB_ClampDropDown(dd, maxButtons)
    if not dd or dd.PCB_Clamped then return end
    dd.PCB_Clamped = true
    maxButtons = maxButtons or 15
    if UIDropDownMenu_SetMaxVisibleButtons then
        UIDropDownMenu_SetMaxVisibleButtons(dd, maxButtons)
    end
    -- Store max buttons on list frames so ToggleDropDownMenu hook can read it
    if dd and dd:GetName() then
        for lvl = 1, 3 do
            local lf = _G["DropDownList" .. lvl]
            if lf then lf.PCB_maxButtons = maxButtons end
        end
    end
    PCB_EnsureDropDownScrollHook()
end

local ADDON_NAME, PCB = ...
PCB.Options = PCB.Options or {}
local Options = PCB.Options

local LSM
local function InitializeLSM()
    if LSM then return end
    if not LibStub then return end
    LSM = LibStub("LibSharedMedia-3.0", true)
    if not LSM then return end
    -- Register callback to refresh UI when new media is registered
    pcall(function()
        if LSM.RegisterCallback then
            LSM.RegisterCallback(LSM, "LibSharedMedia_Registered", function() if Options and Options.panel and Options.panel.Refresh then Options.panel:Refresh() end end)
        elseif LSM.callbacks and LSM.callbacks.RegisterCallback then
            LSM.callbacks:RegisterCallback("LibSharedMedia_Registered", function() if Options and Options.panel and Options.panel.Refresh then Options.panel:Refresh() end end)
        end
    end)
end

local function BuildLSMChoices(kind, includeCustom)
    InitializeLSM()
    if not LSM then return {} end

    local mediaList = LSM:List(kind)
    local choices = {}
    for _, name in ipairs(mediaList) do
        local path = LSM:Fetch(kind, name, true)
        if kind == "statusbar" then
            if path and path ~= "" then
                local entry = { name = name, value = name }
                entry.path = path
                table.insert(choices, entry)
            end
        else
            local entry = { name = name, value = name }
            if path and path ~= "" then
                if kind == "font" then entry.fontPath = path else entry.path = path end
            end
            table.insert(choices, entry)
        end
    end
    table.sort(choices, function(a, b) return a.name < b.name end)

    if kind == "statusbar" then
        table.insert(choices, 1, { name = "Blizzard (Default)", value = "Blizzard" })
    elseif kind == "font" then
        table.insert(choices, 1, { name = "Friz Quadrata (Default)", value = "Friz Quadrata (Default)" })
    end

    if includeCustom then
        table.insert(choices, { name = "Custom path...", value = "Custom" })
    end

    return choices
end

local COL1_X      = 32
local COL2_X      = 280
local LABEL_W     = 120
local CONTROL_W   = 220
local ROW_H       = 42
local SECTION_GAP = 18

local _ddCounter  = 0

local function MakeControlName(prefix, label)
    _ddCounter = _ddCounter + 1
    label = tostring(label or "Control"):gsub("[^%w]", "")
    return (prefix or "PhoenixCastBars") .. label .. _ddCounter
end

local function clamp(v, a, b)
    if type(v) ~= "number" then return a end
    if v < a then return a end
    if v > b then return b end
    return v
end

local function SafeApply()
    if PCB and PCB.ApplyAll then PCB:ApplyAll() end
end

-- Apply custom fonts to dropdown buttons for preview
local _pcbFontHooked = false
local function EnsureFontPreviewHook()
    if _pcbFontHooked then return end
    if not UIDropDownMenu_AddButton then return end
    _pcbFontHooked = true
    hooksecurefunc("UIDropDownMenu_AddButton", function(info, level)
        level = level or 1
        local listFrame = _G["DropDownList" .. level]
        if not listFrame or not listFrame.numButtons then return end
        local idx = listFrame.numButtons
        local btn = _G["DropDownList" .. level .. "Button" .. idx]
        if not btn then return end
        -- If this list was assigned a maxButtons target, clamp initial population immediately
        if listFrame.PCB_maxButtons and not listFrame.PCB_Populated then
            listFrame.PCB_Populated = true
            local maxButtons = listFrame.PCB_maxButtons or 15
            local nb = listFrame.numButtons or 0
            if nb > maxButtons then
                local btnH = (btn:GetHeight()) or 16
                listFrame:SetHeight((btnH * maxButtons) + 10)
                for ii = maxButtons + 1, nb do
                    local b = _G[listFrame:GetName() .. "Button" .. ii]
                    if b and b.Hide then pcall(b.Hide, b) end
                end
            end
        end
        local fs = btn.GetFontString and btn:GetFontString()
        if not fs then return end
        -- Skip statusbar/icon rendering for font preview rows
        if info and info._pcbFontPath then
            if btn.PCB_StatusbarPreview then btn.PCB_StatusbarPreview:Hide() end
            if btn.icon then btn.icon:Hide() end
            return
        else
            pcall(function()
                if fs.SetFont then
                    local dface, dsize, dflags = nil, nil, nil
                    if GameFontHighlightSmall and GameFontHighlightSmall.GetFont then
                        dface, dsize, dflags = GameFontHighlightSmall:GetFont()
                    end
                    if dface then
                        fs:SetFont(dface, dsize or 12, dflags)
                    elseif fs.SetFontObject then
                        fs:SetFontObject(GameFontHighlightSmall)
                    end
                end
                if btn.PCB_StatusbarPreview then btn.PCB_StatusbarPreview:Hide() end
                if btn.icon then btn.icon:Show() end
            end)
        end
    end)
end

-- Render statusbar textures as full-width previews in dropdown
local _pcbStatusbarHooked = false
local function EnsureStatusbarPreviewHook()
    if _pcbStatusbarHooked then return end
    if not UIDropDownMenu_AddButton then return end
    _pcbStatusbarHooked = true
    hooksecurefunc("UIDropDownMenu_AddButton", function(info, level)
        level = level or 1
        local listFrame = _G["DropDownList" .. level]
        if not listFrame or not listFrame.numButtons then return end
        local idx = listFrame.numButtons
        local btn = _G["DropDownList" .. level .. "Button" .. idx]
        if not btn then return end
        -- If this list was assigned a maxButtons target, clamp initial population immediately
        if listFrame.PCB_maxButtons and not listFrame.PCB_Populated then
            listFrame.PCB_Populated = true
            local maxButtons = listFrame.PCB_maxButtons or 15
            local nb = listFrame.numButtons or 0
            if nb > maxButtons then
                local btnH = (btn:GetHeight()) or 16
                listFrame:SetHeight((btnH * maxButtons) + 10)
                for ii = maxButtons + 1, nb do
                    local b = _G[listFrame:GetName() .. "Button" .. ii]
                    if b and b.Hide then pcall(b.Hide, b) end
                end
            end
        end

        if PCB and PCB._pcbCurrentDropDownLabel == "Font" then
            if btn.PCB_StatusbarPreview then btn.PCB_StatusbarPreview:Hide() end
            -- Clear background textures but preserve the check icon
            pcall(function()
                for _, r in ipairs({btn:GetRegions()}) do
                    if r and r.GetObjectType and r:GetObjectType() == "Texture" and r.SetAlpha then
                        local texName = r:GetName()
                        -- Preserve Check/UnCheck icons and button textures
                        if texName and (texName:find("Check") or texName:find("NormalTexture") or texName:find("HighlightTexture") or texName:find("PushedTexture")) then
                            -- Keep this texture
                        else
                            r:SetAlpha(0)
                        end
                    end
                end
            end)
            -- Ensure highlight texture is properly configured for hover
            local highlight = _G[btn:GetName() .. "Highlight"]
            if highlight and highlight.SetAlpha then
                highlight:SetAlpha(0.4)
            end
            return
        end
        
        -- Clear background textures for all dropdowns except Castbar texture, but preserve the check icon
        if PCB and PCB._pcbCurrentDropDownLabel ~= "Castbar texture" then
            pcall(function()
                for _, r in ipairs({btn:GetRegions()}) do
                    if r and r.GetObjectType and r:GetObjectType() == "Texture" and r.SetAlpha then
                        local texName = r:GetName()
                        -- Preserve Check/UnCheck icons and button textures
                        if texName and (texName:find("Check") or texName:find("NormalTexture") or texName:find("HighlightTexture") or texName:find("PushedTexture")) then
                            -- Keep this texture
                        else
                            r:SetAlpha(0)
                        end
                    end
                end
            end)
            -- Ensure check icon is visible
            if btn.icon then btn.icon:Show() end
            -- Ensure highlight texture is properly configured for hover
            local highlight = _G[btn:GetName() .. "Highlight"]
            if highlight and highlight.SetAlpha then
                highlight:SetAlpha(0.4)
            end
        end
        
        local normalText = _G[btn:GetName() .. "NormalText"]
        if normalText then
            pcall(function()
                if normalText.SetFont then
                    local dface, dsize, dflags = nil, nil, nil
                    if GameFontHighlightSmall and GameFontHighlightSmall.GetFont then
                        dface, dsize, dflags = GameFontHighlightSmall:GetFont()
                    end
                    if dface then
                        normalText:SetFont(dface, dsize or 12, dflags)
                    elseif normalText.SetFontObject then
                        normalText:SetFontObject(GameFontHighlightSmall)
                    end
                end
            end)
        end
        if not info or not info._pcbStatusbarPath then
            if btn.PCB_StatusbarPreview then btn.PCB_StatusbarPreview:Hide() end
            if btn._pcbFontPreview then btn._pcbFontPreview:Hide() end
            if btn.icon then btn.icon:Show() end
            local fs = btn.GetFontString and btn:GetFontString()
            if fs then
                pcall(function()
                    if fs.SetFont then
                        local dface, dsize, dflags = nil, nil, nil
                        if GameFontHighlightSmall and GameFontHighlightSmall.GetFont then
                            dface, dsize, dflags = GameFontHighlightSmall:GetFont()
                        end
                        if dface then
                            fs:SetFont(dface, dsize or 12, dflags)
                        elseif fs.SetFontObject then
                            fs:SetFontObject(GameFontHighlightSmall)
                        end
                    end
                end)
            end
            return
        end
        level = level or 1
        local listFrame = _G["DropDownList" .. level]
        if not listFrame or not listFrame.numButtons then return end
        local idx = listFrame.numButtons
        local btn = _G["DropDownList" .. level .. "Button" .. idx]
        if not btn then return end

        local fs = btn.GetFontString and btn:GetFontString()
        if fs then
            pcall(function()
                if fs.SetFont then
                    local dface, dsize, dflags = nil, nil, nil
                    if GameFontHighlightSmall and GameFontHighlightSmall.GetFont then
                        dface, dsize, dflags = GameFontHighlightSmall:GetFont()
                    end
                    if dface then
                        fs:SetFont(dface, dsize or 12, dflags)
                    elseif fs.SetFontObject then
                        fs:SetFontObject(GameFontHighlightSmall)
                    end
                end
            end)
        end

        if btn.icon then btn.icon:Hide() end
        if btn._pcbFontPreview then
            pcall(function()
                btn._pcbFontPreview:Hide()
                if btn._pcbFontPreview.SetText then btn._pcbFontPreview:SetText("") end
            end)
        end
        local tex = btn._pcbStatusbarPreview
        if not tex then
            tex = btn:CreateTexture(nil, "BACKGROUND", nil, 0)
            btn._pcbStatusbarPreview = tex
            tex:SetPoint("LEFT", btn, "LEFT", 24, 1)
            tex:SetPoint("RIGHT", btn, "RIGHT", -8, 1)
            tex:SetPoint("TOP", btn, "TOP", 0, -2)
            tex:SetPoint("BOTTOM", btn, "BOTTOM", 0, 2)
        end
        tex:SetTexture(info._pcbStatusbarPath)
        tex:SetAlpha(1)
        tex:Show()

        if fs then
            pcall(function()
                if fs.SetText then fs:SetText(info and info.text or "") end
                if fs.SetFont then
                    local dface, dsize, dflags = nil, nil, nil
                    if GameFontHighlightSmall and GameFontHighlightSmall.GetFont then
                        dface, dsize, dflags = GameFontHighlightSmall:GetFont()
                    end
                    if dface then
                        fs:SetFont(dface, dsize or 12, dflags)
                    elseif fs.SetFontObject then
                        fs:SetFontObject(GameFontHighlightSmall)
                    end
                end
            end)
            fs:ClearAllPoints()
            fs:SetPoint("LEFT", btn, "LEFT", 30, 0)
            fs:SetPoint("RIGHT", btn, "RIGHT", -10, 0)
            fs:SetJustifyH("LEFT")
        end
    end)
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
    local s = CreateFrame("Slider", MakeControlName("PhoenixCastBarsOptionsSlider"), parent, "OptionsSliderTemplate")
    s:SetPoint("TOPLEFT", parent, "TOPLEFT", x, y)
    s:SetMinMaxValues(minVal, maxVal)
    s:SetValueStep(step)
    s:SetObeyStepOnDrag(true)
    s:SetWidth(width or CONTROL_W)
    s.tooltipText = tooltip or ""
    local textFS = s.Text or _G[s:GetName().."Text"]
    local lowFS  = s.Low  or _G[s:GetName().."Low"]
    local highFS = s.High or _G[s:GetName().."High"]
    if textFS then textFS:SetText(label) end
    if lowFS  then lowFS:SetText(tostring(minVal)) end
    if highFS then highFS:SetText(tostring(maxVal)) end
    local updating = false
    local valueFS = s:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
    valueFS:SetPoint("TOP", s, "BOTTOM", 0, -6)
    valueFS:SetWidth(width or CONTROL_W)
    valueFS:SetJustifyH("CENTER")
    -- Format slider value for display (whole numbers or 1 decimal)
    local function formatVal(v)
        if type(v) ~= "number" then return tostring(v) end
        if v == math.floor(v) then return tostring(v) end
        return string.format("%.1f", v)
    end

    s:SetScript("OnValueChanged", function(_, v)
        if updating then return end
        setter(v)
        if valueFS and valueFS.SetText then valueFS:SetText(formatVal(v)) end
        SafeApply()
    end)
    s.Refresh = function()
        updating = true
        local v = getter()
        if type(v) ~= "number" then v = minVal end
        v = clamp(v, minVal, maxVal)
        s:SetValue(v)
        if valueFS and valueFS.SetText then valueFS:SetText(formatVal(v)) end
        updating = false
    end
    return s
end

local function CreateDropdown(parent, label, tooltip, x, y, widthOrChoices, choicesOrGetter, getterOrSetter, setter)
    local width, choices, getter
    if type(widthOrChoices) == "number" then
        width, choices, getter, setter = widthOrChoices, choicesOrGetter, getterOrSetter, setter
    else
        width, choices, getter, setter = CONTROL_W, widthOrChoices, choicesOrGetter, getterOrSetter
    end
    CreateLabel(parent, label, x, y + 6)
    local dd = CreateFrame("Frame", MakeControlName("PhoenixCastBars", label .. "DropDown"), parent, "UIDropDownMenuTemplate")
    dd:SetPoint("TOPLEFT", parent, "TOPLEFT", x + LABEL_W - 10, y + 10)
    UIDropDownMenu_SetWidth(dd, width)
    EnsureFontPreviewHook()
    EnsureStatusbarPreviewHook()
    dd.tooltipText = tooltip or ""
    dd.Icon = dd:CreateTexture(nil, "ARTWORK")
    dd.Icon:SetPoint("RIGHT", dd, "RIGHT", -22, 0)
    dd.Icon:SetSize(18, 18)
    local function OnClick(self)
        setter(self.value)
        UIDropDownMenu_SetSelectedValue(dd, self.value)
        UIDropDownMenu_SetText(dd, self.text)
        -- Call Refresh to ensure text is properly visible
        if dd.Refresh then
            dd.Refresh()
        end
        SafeApply()
    end
    UIDropDownMenu_Initialize(dd, function(_, level)
        PCB._pcbCurrentDropDownLabel = label
	local _maxButtons = (label == "Font" or label == "Castbar texture") and 10 or 15
	PCB_ClampDropDown(dd, _maxButtons)
local current = getter()
        local choicesTbl = type(choices) == "function" and choices() or choices or {}
        if label == "Castbar texture" then
            -- Filter out entries without valid texture paths
            local filtered = {}
            for _, e in ipairs(choicesTbl) do
                if e and e.path and type(e.path) == "string" and e.path ~= "" then
                    table.insert(filtered, e)
                end
            end
            choicesTbl = filtered

        end
        for i = 1, #choicesTbl do
            local e = choicesTbl[i]
            if not (label == "Castbar texture" and (not e or not e.path or type(e.path) ~= "string" or e.path == "")) then
                local info = UIDropDownMenu_CreateInfo()
                info.text = choicesTbl[i].name
                info.value = choicesTbl[i].value
            if label == "Castbar texture" then
                info.fontObject = GameFontHighlight
            else
                info.fontObject = GameFontHighlightSmall
            end
            info.func = OnClick
            info.checked = (current == choicesTbl[i].value)
            if choicesTbl[i].path and type(choicesTbl[i].path) == "string" and choicesTbl[i].path ~= "" then
                info._pcbStatusbarPath = choicesTbl[i].path
            elseif choicesTbl[i].fontPath and type(choicesTbl[i].fontPath) == "string" and choicesTbl[i].fontPath ~= "" then
                info._pcbFontPath = choicesTbl[i].fontPath
                info._pcbIsFont = true
                info._pcbStatusbarPath = nil
                info.icon = nil
            end

            if label == "Castbar texture" then
                -- Double-check texture path with LSM to prevent font entries appearing as textures
                local confirmedPath = nil
                if LSM and LSM.Fetch then
                    confirmedPath = LSM:Fetch("statusbar", info.value, true)
                end
                if confirmedPath and type(confirmedPath) == "string" and confirmedPath ~= "" then
                    info._pcbStatusbarPath = confirmedPath
                else
                    info._pcbStatusbarPath = nil
                end
                if info._pcbIsFont then
                    info._pcbStatusbarPath = nil
                end
            end
                if label == "Castbar texture" then
                    if info._pcbStatusbarPath or info.value == "Blizzard" or info.value == "Custom" then
                        UIDropDownMenu_AddButton(info, level)
                    end
                else
                    UIDropDownMenu_AddButton(info, level)
                end
            end
        end
        if label == "Font" then
            local listFrame = _G["DropDownList" .. (level or 1)]
            if listFrame and listFrame.numButtons and #choicesTbl > 0 then
                local endIdx = listFrame.numButtons
                local startIdx = math.max(1, endIdx - #choicesTbl + 1)
                for idx = startIdx, endIdx do
                    local btn = _G["DropDownList" .. (level or 1) .. "Button" .. idx]
                    local entryIndex = idx - startIdx + 1
                    local entry = choicesTbl[entryIndex]
                    if btn then
                        -- Always hide statusbar preview for font dropdowns
                        if btn.PCB_StatusbarPreview then btn.PCB_StatusbarPreview:Hide() end
                        
                        local fs = btn.GetFontString and btn:GetFontString()
                        if fs and entry and entry.fontPath and type(entry.fontPath) == "string" and entry.fontPath ~= "" then
                            local curFont, curSize, curFlags = fs:GetFont()
                            pcall(function() fs:SetFont(entry.fontPath, curSize or 12, curFlags) end)
                            -- Create overlay fontstring to display font preview above any texture
                            pcall(function()
                                if btn._pcbFontPreview then
                                    btn._pcbFontPreview:SetText(choicesTbl[entryIndex].name)
                                    btn._pcbFontPreview:SetFont(entry.fontPath, curSize or 12, curFlags)
                                    btn._pcbFontPreview:Show()
                                else
                                    local over = btn:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
                                    btn._pcbFontPreview = over
                                    over:SetPoint("LEFT", btn, "LEFT", 30, 0)
                                    over:SetPoint("RIGHT", btn, "RIGHT", -10, 0)
                                    over:SetJustifyH("LEFT")
                                    over:SetText(choicesTbl[entryIndex].name)
                                    over:SetFont(entry.fontPath, curSize or 12, curFlags)
                                end
                                -- Clear statusbar textures to prevent bleeding through font preview
                                if btn.PCB_StatusbarPreview then
                                    btn.PCB_StatusbarPreview:Hide()
                                    pcall(function()
                                        if btn.PCB_StatusbarPreview.SetTexture then btn.PCB_StatusbarPreview:SetTexture(nil) end
                                        if btn.PCB_StatusbarPreview.SetColorTexture then btn.PCB_StatusbarPreview:SetColorTexture(0,0,0,0) end
                                        if btn.PCB_StatusbarPreview.SetAlpha then btn.PCB_StatusbarPreview:SetAlpha(0) end
                                    end)
                                end
                                -- clear the original button fontstring to avoid duplicate text
                                if fs.SetText then fs:SetText("") end
                            end)
                        else
                            -- Default font with no fontPath - ensure text displays properly without textures
                            if fs and entry then
                                pcall(function()
                                    fs:SetText(entry.name or "")
                                    if fs.SetFontObject then
                                        fs:SetFontObject(GameFontHighlightSmall)
                                    end
                                end)
                            end
                        end
                    end
                end
            end
        end
        PCB._pcbCurrentDropDownLabel = nil
    end)
    dd.Refresh = function()
        local v = getter()
        local choicesTbl = type(choices) == "function" and choices() or choices or {}
        for i = 1, #choicesTbl do
            if choicesTbl[i].value == v then
                UIDropDownMenu_SetSelectedValue(dd, v)
                UIDropDownMenu_SetText(dd, choicesTbl[i].name)
                local ddText = _G[dd:GetName() .. "Text"]
                if ddText then
                    -- Ensure text is visible
                    ddText:Show()
                    ddText:SetAlpha(1)
                    if ddText.SetFontObject then
                        if label == "Castbar texture" then
                            ddText:SetFontObject(GameFontHighlight)
                        else
                            ddText:SetFontObject(GameFontHighlightSmall)
                        end
                    end
                end
                -- hide icon for Font dropdowns; only texture dropdowns show a preview icon
                if label == "Font" then
                    if dd.Icon then dd.Icon:Hide() end
                else
                    if choicesTbl[i].path and dd.Icon then
                        dd.Icon:SetTexture(choicesTbl[i].path)
                        dd.Icon:Show()
                    elseif dd.Icon then
                        dd.Icon:Hide()
                    end
                end
                return
            end
        end
        UIDropDownMenu_SetSelectedValue(dd, v)
        UIDropDownMenu_SetText(dd, tostring(v))
        local ddText = _G[dd:GetName() .. "Text"]
        if ddText and ddText.SetFontObject then
            if label == "Castbar texture" then
                ddText:SetFontObject(GameFontHighlight)
            else
                ddText:SetFontObject(GameFontHighlightSmall)
            end
        end
        if dd.Icon then dd.Icon:Hide() end
    end
    return dd
end

local function CreateScrollableCanvas(panel)
    local scroll = CreateFrame("ScrollFrame", nil, panel, "UIPanelScrollFrameTemplate")
    scroll:SetPoint("TOPLEFT", panel, "TOPLEFT", 0, 0)
    scroll:SetPoint("BOTTOMRIGHT", panel, "BOTTOMRIGHT", -28, 0)
    local content = CreateFrame("Frame", nil, scroll)
    content:SetPoint("TOPLEFT", scroll, "TOPLEFT", 0, 0)
    content:SetSize(1, 1)
    scroll:SetScrollChild(content)
    panel._scroll = scroll
    panel._content = content
    return content
end

-- Panel construction
local function BuildPanel()
    EnsureDB()

    local panel = CreateFrame("Frame", "PhoenixCastBarsOptionsPanel", UIParent)
    panel.name = "PhoenixCastBars"
    if Settings and Settings.RegisterCanvasLayoutCategory and Settings.RegisterAddOnCategory then
        local category = Settings.RegisterCanvasLayoutCategory(panel, panel.name)
        Settings.RegisterAddOnCategory(category)
        Options._categoryID = category:GetID()
    elseif InterfaceOptions_AddCategory then
        InterfaceOptions_AddCategory(panel)
    end

    local root = CreateScrollableCanvas(panel)
    local COL1 = 16
    local COL2 = COL1 + 280

    -- title
    local title = root:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
    title:SetPoint("TOPLEFT", root, "TOPLEFT", COL1, -8)
    title:SetText(("PhoenixCastBars v%s"):format(PCB.version or "?"))

    -- textures / fonts / outlines
    local TEXTURES = function() return BuildLSMChoices("statusbar", true) end
    -- Do not show a "Custom path..." entry for fonts to avoid non-font rows
    local FONTS = function() return BuildLSMChoices("font", false) end
    local OUTLINES = {
        { name = "Outline", value = "OUTLINE" },
        { name = "Thick Outline", value = "THICKOUTLINE" },
        { name = "None", value = "" },
    }

    local y = -18

    -- Media
    CreateHeader(root, "Media", COL1, y - 10); y = y - (ROW_H + 6)
    local ddTex = CreateDropdown(root, "Castbar texture", "Select the castbar statusbar texture.", COL1, y, TEXTURES,
        function()
            return PCB.db.textureKey or "Blizzard"
        end,
        function(v)
            PCB.db.textureKey = v
        end)
    y = y - ROW_H

    local ddFont = CreateDropdown(root, "Font", "Select the font used for castbar text.", COL1, y, FONTS,
        function()
            return PCB.db.fontKey or "Friz Quadrata (Default)"
        end,
        function(v)
            PCB.db.fontKey = v
        end)
    y = y - ROW_H

    local ddOutline = CreateDropdown(root, "Font outline", "Select text outline style.", COL1, y, OUTLINES,
        function() return PCB.db.outline or "OUTLINE" end,
        function(v) PCB.db.outline = v end)
    y = y - ROW_H

    local fontSize = CreateNamedSlider(root, "Font size", "Size of the cast bar font.", COL1, y + 2, 8, 20, 1, CONTROL_W,
        function() return PCB.db.fontSize or 12 end,
        function(v) PCB.db.fontSize = v end)
    y = y - (ROW_H + SECTION_GAP)

    -- General
    CreateHeader(root, "General", COL1, y); y = y - (ROW_H - 20)
    local g1y, g2y = y, y
    local cbLocked = CreateCheckbox(root, "Lock frames", "When enabled, frames cannot be dragged.", COL1, g1y,
        function() return PCB.db.locked end,
        function(v) PCB.db.locked = v end)
    g1y = g1y - 28
    local cbHideBlizz = CreateCheckbox(root, "Hide Blizzard cast bars", "Hides the default Blizzard player/target/focus cast bars while PhoenixCastBars is enabled.", COL1, g1y,
        function() return PCB.db.hideBlizzardCastBars end,
        function(v) PCB.db.hideBlizzardCastBars = v end)
    g1y = g1y - 28
    local cbSpellName = CreateCheckbox(root, "Show spell name", "Shows the spell name on the cast bar.", COL1, g1y,
        function() return PCB.db.showSpellName end,
        function(v) PCB.db.showSpellName = v end)
    g1y = g1y - 28
    local cbLatency = CreateCheckbox(root, "Show latency (player)", "Shows input latency safe-zone (player casts only).", COL1, g1y,
        function() return PCB.db.showLatency end,
        function(v) PCB.db.showLatency = v end)
    g1y = g1y - 28
    local cbIcon = CreateCheckbox(root, "Show spell icon", "Displays the spell icon to the left of the cast bar.", COL2, g2y,
        function() return PCB.db.showIcon end,
        function(v) PCB.db.showIcon = v end)
    g2y = g2y - 28
    local cbSpark = CreateCheckbox(root, "Show spark", "Shows a spark indicator on the cast bar.", COL2, g2y,
        function() return PCB.db.showSpark end,
        function(v) PCB.db.showSpark = v end)
    g2y = g2y - 28
    local cbTime = CreateCheckbox(root, "Show time", "Shows remaining / total time on the cast bar.", COL2, g2y,
        function() return PCB.db.showTime end,
        function(v) PCB.db.showTime = v end)
    g2y = g2y - 28
    local cbShield = CreateCheckbox(root, "Show interrupt shield", "Shows a shield indicator when the cast is not interruptible.", COL2, g2y,
        function() return PCB.db.showInterruptShield end,
        function(v) PCB.db.showInterruptShield = v end)
    g2y = g2y - 28
    y = math.min(g1y, g2y) - SECTION_GAP

    -- Bars
    CreateHeader(root, "Bars", COL1, y); y = y - (ROW_H - 20)
    local b1y, b2y = y, y
    local cbPlayer = CreateCheckbox(root, "Enable Player bar", "", COL1, b1y,
        function() return PCB.db.bars.player.enabled end,
        function(v) PCB.db.bars.player.enabled = v end)
    b1y = b1y - 28
    local cbFocus = CreateCheckbox(root, "Enable Focus bar", "", COL1, b1y,
        function() return PCB.db.bars.focus.enabled end,
        function(v) PCB.db.bars.focus.enabled = v end)
    b1y = b1y - 28
    local cbTarget = CreateCheckbox(root, "Enable Target bar", "", COL2, b2y,
        function() return PCB.db.bars.target.enabled end,
        function(v) PCB.db.bars.target.enabled = v end)
    b2y = b2y - 28
    y = math.min(b1y, b2y) - 10

    -- Actions
    y = y - SECTION_GAP
    CreateHeader(root, "Actions", COL1, y); y = y - (ROW_H - 20)
    local reset = CreateFrame("Button", nil, root, "UIPanelButtonTemplate")
    reset:SetPoint("TOPLEFT", root, "TOPLEFT", COL1, y)
    reset:SetText("Reset (Reload UI)")
    reset:SetWidth(160)
    reset:SetScript("OnClick", function() ReloadUI() end)

    -- size scroll child
    root:SetHeight((-y) + 80)
    root:SetWidth(1)

    -- panel refresh
    panel.Refresh = function()
        EnsureDB()
        ddTex.Refresh(); ddFont.Refresh(); ddOutline.Refresh(); fontSize:Refresh()
        cbLocked.Refresh(); cbHideBlizz.Refresh(); cbIcon.Refresh(); cbSpark.Refresh()
        cbSpellName.Refresh(); cbTime.Refresh(); cbLatency.Refresh(); cbShield.Refresh()
        cbPlayer.Refresh(); cbTarget.Refresh(); cbFocus.Refresh()
    end
    panel:SetScript("OnShow", panel.Refresh)

    Options.panel = panel
end

    -- Public API
function Options:Init()
    if self._inited then return end
    local ok, err = pcall(BuildPanel)
    if not ok then
        if PCB and PCB.Print then PCB:Print("Options BuildPanel error: " .. tostring(err)) end
        return
    end
=======
local ADDON_NAME, PCB = ...
local Options = {}
PCB.Options = Options

local optionsFrame = nil
local selectedCategory = "general"

function Options:Init()
    if self._inited then return end
    
    if not PCB.db then 
        PCB:InitDB()
    end
    
    PCB:Print("Options initialized. Use |cff00d1ff/pcb|r to open options")
>>>>>>> 9671a60 (Release v0.3.4 / update files)
    self._inited = true
end

function Options:Open()
<<<<<<< HEAD
    if not self._inited and self.Init then
        self:Init()
    end
    if not self.panel then
        -- Build immediately as a last resort
        local ok, err = pcall(BuildPanel)
        if not ok and PCB and PCB.Print then
            PCB:Print("Options BuildPanel error: " .. tostring(err))
        end
    end
    if not self.panel then
        return
    end

    -- Prefer legacy opener if present (works even when Settings UI is the front-end)
    if InterfaceOptionsFrame_OpenToCategory then
        InterfaceOptionsFrame_OpenToCategory(self.panel)
        InterfaceOptionsFrame_OpenToCategory(self.panel)
        return
    end

    if Settings and Settings.OpenToCategory and Options._categoryID then
        Settings.OpenToCategory(Options._categoryID)
        return
    end

    if InterfaceOptionsFrame then
        InterfaceOptionsFrame:Show()
    end
end
=======
    if not self._inited then 
        self:Init() 
    end
    
    if optionsFrame and optionsFrame:IsShown() then
        optionsFrame:Hide()
        return
    end
    
    if not optionsFrame then
        optionsFrame = CreateFrame("Frame", "PhoenixCastBarsOptionsFrame", UIParent)
        optionsFrame:SetFrameStrata("HIGH")
        optionsFrame:SetWidth(700)
        optionsFrame:SetHeight(600)
        optionsFrame:SetPoint("CENTER", UIParent, "CENTER")
        
        local bg = optionsFrame:CreateTexture(nil, "BACKGROUND")
        bg:SetAllPoints(optionsFrame)
        bg:SetColorTexture(0.05, 0.05, 0.1, 1)
        
        optionsFrame:SetMovable(true)
        optionsFrame:EnableMouse(true)
        optionsFrame:RegisterForDrag("LeftButton")
        optionsFrame:SetScript("OnDragStart", function(self) self:StartMoving() end)
        optionsFrame:SetScript("OnDragStop", function(self) self:StopMovingOrSizing() end)
        
        local title = optionsFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
        title:SetPoint("TOPLEFT", 10, -10)
        title:SetText("PhoenixCastBars Options")
        
        local versionText = optionsFrame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        versionText:SetPoint("TOPRIGHT", -35, -10)
        versionText:SetText("v" .. (PCB.version or "0.0.0"))
        versionText:SetTextColor(0.6, 0.6, 0.6, 1)
        
        local closeBtn = CreateFrame("Button", nil, optionsFrame)
        closeBtn:SetWidth(25)
        closeBtn:SetHeight(25)
        closeBtn:SetPoint("TOPRIGHT", -5, -5)
        local closeBg = closeBtn:CreateTexture(nil, "BACKGROUND")
        closeBg:SetAllPoints(closeBtn)
        closeBg:SetColorTexture(1, 0.2, 0, 1)
        local closeText = closeBtn:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        closeText:SetAllPoints(closeBtn)
        closeText:SetText("X")
        closeBtn:SetScript("OnClick", function() optionsFrame:Hide() end)
        
        local sidebar = CreateFrame("Frame", nil, optionsFrame)
        sidebar:SetWidth(150)
        sidebar:SetHeight(550)
        sidebar:SetPoint("TOPLEFT", 10, -35)
        
        local sidebarBg = sidebar:CreateTexture(nil, "BACKGROUND")
        sidebarBg:SetAllPoints(sidebar)
        sidebarBg:SetColorTexture(0.1, 0.1, 0.15, 1)
        
        local content = CreateFrame("Frame", nil, optionsFrame)
        content:SetWidth(520)
        content:SetHeight(550)
        content:SetPoint("TOPLEFT", 170, -35)
        
        local contentBg = content:CreateTexture(nil, "BACKGROUND")
        contentBg:SetAllPoints(content)
        contentBg:SetColorTexture(0, 0, 0, 0.8)
        
        local scrollFrame = CreateFrame("ScrollFrame", nil, content, "UIPanelScrollFrameTemplate")
        scrollFrame:SetPoint("TOPLEFT", content, "TOPLEFT", 0, 0)
        scrollFrame:SetPoint("BOTTOMRIGHT", content, "BOTTOMRIGHT", -20, 0)
        
        local scrollContent = CreateFrame("Frame", nil, scrollFrame)
        scrollContent:SetWidth(480)
        scrollContent:SetHeight(500)  -- Set initial height
        scrollFrame:SetScrollChild(scrollContent)
        
        optionsFrame.sidebar = sidebar
        optionsFrame.scrollContent = scrollContent
        optionsFrame.scrollFrame = scrollFrame
        optionsFrame.categoryButtons = {}
        optionsFrame.contentWidgets = {}  -- Track created widgets for cleanup
        
        local categories = {
            general = {
                name = "General",
                options = {
                    { type = "checkboxpair", label1 = "Lock Frames", key1 = "locked", label2 = "Hide Blizzard Cast Bars", key2 = "hideBlizzardCastBars" },
                    { type = "checkboxbutton", label = "Show Minimap Button", key = "minimapButton.show", buttonLabel = "Toggle Test Mode", onClick = "toggleTestMode" },
                    { type = "space" },
                    { type = "lsmdropdown", label = "Castbar Texture", key = "textureKey", mediaType = "statusbar" },
                    { type = "lsmdropdown", label = "Font", key = "fontKey", mediaType = "font" },
                    { type = "outlinedropdown", label = "Font Outline", key = "outline" },
                    { type = "space" },
                    { type = "slider", label = "Font Size", key = "fontSize", min = 8, max = 20, step = 1 },
                    { type = "colorpickergrid", pickers = {
                        { label = "Regular Cast", key = "colorCast" },
                        { label = "Channeled Cast", key = "colorChannel" },
                        { label = "Uninterruptible Cast", key = "colorNonInterruptible" },
                        { label = "Successful Cast", key = "colorSuccess" },
                        { label = "Failed/Interrupted", key = "colorFailed" },
                        { label = "Latency Indicator", key = "safeZoneColor" },
                    }},
                }
            },
            profiles = {
                name = "Profiles",
                options = {
                    { type = "description", text = "You can change the active database profile, so you can have different settings for every character.\nReset the current profile back to its default values, in case your configuration is broken, or you simply want to start over." },
                    { type = "button", label = "Reset Profile", onClick = "resetProfile" },
                    { type = "label", text = "Current Profile: %s", getValue = "currentProfile" },
                    { type = "space" },
                    { type = "description", text = "You can either create a new profile by entering a name in the editbox, or choose one of the already existing profiles." },
                    { type = "editbox", label = "New", placeholder = "Profile name", key = "newProfile" },
                    { type = "dropdown", label = "Existing Profiles", key = "existingProfile" },
                    { type = "space" },
                    { type = "checkbox", label = "Enable spec profiles", tooltip = "When enabled, your profile will be set to the specified profile when you change specialization.", key = "profileMode", isProfileMode = "spec" },
                    { type = "space" },
                    { type = "description", text = "Copy the settings from one existing profile into the currently active profile." },
                    { type = "dropdown", label = "Copy from", key = "copyProfile" },
                    { type = "space" },
                    { type = "description", text = "Delete existing and unused profiles from the database to save space, and cleanup the SavedVariables file." },
                    { type = "dropdown", label = "Delete a Profile", key = "deleteProfile" },
                }
            },
            player = {
                name = "Player Bar",
                options = {
                    { type = "checkbox", label = "Enable Player Bar", key = "bars.player.enabled" },
                    { type = "space" },
                    { type = "slidergrid", sliders = {
                        { label = "Width", key = "bars.player.width", min = 100, max = 500, step = 10 },
                        { label = "Height", key = "bars.player.height", min = 10, max = 50, step = 1 },
                        { label = "Alpha", key = "bars.player.alpha", min = 0, max = 1, step = 0.05 },
                        { label = "Scale", key = "bars.player.scale", min = 0.5, max = 2.0, step = 0.1 },
                    }},
                    { type = "space" },
                    { type = "checkbox", label = "Enable Texture Override", key = "bars.player.enableTextureOverride" },
                                { type = "lsmdropdown", label = "", key = "bars.player.textureKey", mediaType = "statusbar", allowBlank = true, visibleIf = function() return PCB.db.bars.player.enableTextureOverride end },
                    { type = "checkbox", label = "Enable Font Override", key = "bars.player.enableFontOverride" },
                                { type = "lsmdropdown", label = "", key = "bars.player.fontKey", mediaType = "font", allowBlank = true, visibleIf = function() return PCB.db.bars.player.enableFontOverride end },
                    { type = "checkbox", label = "Enable Outline Override", key = "bars.player.enableOutlineOverride" },
                                { type = "outlinedropdown", label = "", key = "bars.player.outline", allowBlank = true, visibleIf = function() return PCB.db.bars.player.enableOutlineOverride end },
                    { type = "space" },
                    { type = "twocolumngrid", items = {
                        { type = "checkbox", label = "Show Spell Name", key = "bars.player.showSpellName" },
                        { type = "checkbox", label = "Show Spell Icon", key = "bars.player.showIcon" },
                        { type = "checkbox", label = "Show Spark", key = "bars.player.showSpark" },
                        { type = "checkbox", label = "Show Time", key = "bars.player.showTime" },
                        { type = "checkbox", label = "Show Latency", key = "bars.player.showLatency" },
                    }},
                }
            },
            target = {
                name = "Target Bar",
                options = {
                    { type = "checkbox", label = "Enable Target Bar", key = "bars.target.enabled" },
                    { type = "space" },
                    { type = "slidergrid", sliders = {
                        { label = "Width", key = "bars.target.width", min = 100, max = 500, step = 1 },
                        { label = "Height", key = "bars.target.height", min = 10, max = 50, step = 1 },
                        { label = "Alpha", key = "bars.target.alpha", min = 0, max = 1, step = 0.05 },
                        { label = "Scale", key = "bars.target.scale", min = 0.5, max = 2.0, step = 0.1 },
                    }},
                    { type = "space" },
                    { type = "checkbox", label = "Enable Texture Override", key = "bars.target.enableTextureOverride" },
                                { type = "lsmdropdown", label = "", key = "bars.target.textureKey", mediaType = "statusbar", allowBlank = true, visibleIf = function() return PCB.db.bars.target.enableTextureOverride end },
                    { type = "checkbox", label = "Enable Font Override", key = "bars.target.enableFontOverride" },
                                { type = "lsmdropdown", label = "", key = "bars.target.fontKey", mediaType = "font", allowBlank = true, visibleIf = function() return PCB.db.bars.target.enableFontOverride end },
                    { type = "checkbox", label = "Enable Outline Override", key = "bars.target.enableOutlineOverride" },
                                { type = "outlinedropdown", label = "", key = "bars.target.outline", allowBlank = true, visibleIf = function() return PCB.db.bars.target.enableOutlineOverride end },
                    { type = "space" },
                    { type = "twocolumngrid", items = {
                        { type = "checkbox", label = "Show Spell Name", key = "bars.target.showSpellName" },
                        { type = "checkbox", label = "Show Spell Icon", key = "bars.target.showIcon" },
                        { type = "checkbox", label = "Show Spark", key = "bars.target.showSpark" },
                        { type = "checkbox", label = "Show Time", key = "bars.target.showTime" },
                        { type = "checkbox", label = "Show Interrupt Shield", key = "bars.target.showInterruptShield" },
                    }},
                }
            },
            focus = {
                name = "Focus Bar",
                options = {
                    { type = "checkbox", label = "Enable Focus Bar", key = "bars.focus.enabled" },
                    { type = "space" },
                    { type = "slidergrid", sliders = {
                        { label = "Width", key = "bars.focus.width", min = 100, max = 500, step = 10 },
                        { label = "Height", key = "bars.focus.height", min = 10, max = 50, step = 1 },
                        { label = "Alpha", key = "bars.focus.alpha", min = 0, max = 1, step = 0.05 },
                        { label = "Scale", key = "bars.focus.scale", min = 0.5, max = 2.0, step = 0.1 },
                    }},
                    { type = "space" },
                    { type = "checkbox", label = "Enable Texture Override", key = "bars.focus.enableTextureOverride" },
                                { type = "lsmdropdown", label = "", key = "bars.focus.textureKey", mediaType = "statusbar", allowBlank = true, visibleIf = function() return PCB.db.bars.focus.enableTextureOverride end },
                    { type = "checkbox", label = "Enable Font Override", key = "bars.focus.enableFontOverride" },
                                { type = "lsmdropdown", label = "", key = "bars.focus.fontKey", mediaType = "font", allowBlank = true, visibleIf = function() return PCB.db.bars.focus.enableFontOverride end },
                    { type = "checkbox", label = "Enable Outline Override", key = "bars.focus.enableOutlineOverride" },
                                { type = "outlinedropdown", label = "", key = "bars.focus.outline", allowBlank = true, visibleIf = function() return PCB.db.bars.focus.enableOutlineOverride end },
                    { type = "space" },
                    { type = "twocolumngrid", items = {
                        { type = "checkbox", label = "Show Spell Name", key = "bars.focus.showSpellName" },
                        { type = "checkbox", label = "Show Spell Icon", key = "bars.focus.showIcon" },
                        { type = "checkbox", label = "Show Spark", key = "bars.focus.showSpark" },
                        { type = "checkbox", label = "Show Time", key = "bars.focus.showTime" },
                        { type = "checkbox", label = "Show Interrupt Shield", key = "bars.focus.showInterruptShield" },
                    }},
                }
            },
        }
        
        -- Helper functions for nested database access
        local function GetValue(db, key)
            local keys = {strsplit(".", key)}
            local val = db
            for _, k in ipairs(keys) do
                if type(val) ~= "table" then return nil end
                val = val[k]
            end
            return val
        end
        
        local function SetValue(db, key, value)
            local keys = {strsplit(".", key)}
            local val = db
            for i = 1, #keys - 1 do
                if type(val[keys[i]]) ~= "table" then
                    val[keys[i]] = {}
                end
                val = val[keys[i]]
            end
            val[keys[#keys]] = value
        end
        
        -- Helper function to add a checkbox
        local function AddCheckbox(parent, label, dbKey, y, isProfileMode)
            local cb = CreateFrame("CheckButton", nil, parent, "UICheckButtonTemplate")
            cb:SetPoint("TOPLEFT", 10, y)
            
            local text = cb:CreateFontString(nil, "OVERLAY", "GameFontNormal")
            text:SetPoint("LEFT", cb, "RIGHT", 5, 0)
            text:SetText(label)
            
            if isProfileMode then
                -- Special handling for profile mode (radio button behavior)
                local targetMode = isProfileMode -- "character" or "spec"
                cb:SetChecked(PCB:GetProfileMode() == targetMode)
                cb:SetScript("OnClick", function(self)
                    if self:GetChecked() then
                        PCB:SetProfileMode(targetMode)
                        -- Update the other profile checkboxes
                        for _, widget in ipairs(optionsFrame.contentWidgets) do
                            if widget ~= cb and widget.profileMode then
                                widget:SetChecked(false)
                            end
                        end
                    else
                        -- Don't allow unchecking - one must always be selected
                        self:SetChecked(true)
                    end
                    if PCB.ApplyAll then PCB:ApplyAll() end
                end)
                cb.profileMode = targetMode  -- Mark this as a profile mode checkbox
            else
                cb:SetChecked(GetValue(PCB.db, dbKey) or false)
                cb:SetScript("OnClick", function(self)
                    SetValue(PCB.db, dbKey, self:GetChecked())
                    if dbKey == "minimapButton.show" and PCB.UpdateMinimapButton then
                        PCB:UpdateMinimapButton()
                    end
                    if PCB.ApplyAll then PCB:ApplyAll() end
                    if optionsFrame and optionsFrame.UpdateContent then optionsFrame.UpdateContent(selectedCategory) end
                end)
            end
            
            return cb
        end
        
        -- Helper function to add two checkboxes side-by-side
        local function AddCheckboxPair(parent, label1, dbKey1, label2, dbKey2, y)
            local container = CreateFrame("Frame", nil, parent)
            container:SetPoint("TOPLEFT", 10, y)
            container:SetSize(480, 25)
            
            -- First checkbox
            local cb1 = CreateFrame("CheckButton", nil, container, "UICheckButtonTemplate")
            cb1:SetPoint("TOPLEFT", 0, 0)
            
            local text1 = cb1:CreateFontString(nil, "OVERLAY", "GameFontNormal")
            text1:SetPoint("LEFT", cb1, "RIGHT", 5, 0)
            text1:SetText(label1)
            
            cb1:SetChecked(GetValue(PCB.db, dbKey1) or false)
            cb1:SetScript("OnClick", function(self)
                SetValue(PCB.db, dbKey1, self:GetChecked())
                if PCB.ApplyAll then PCB:ApplyAll() end
                if optionsFrame and optionsFrame.UpdateContent then optionsFrame.UpdateContent(selectedCategory) end
            end)
            
            -- Second checkbox (positioned to the right)
            local cb2 = CreateFrame("CheckButton", nil, container, "UICheckButtonTemplate")
            cb2:SetPoint("LEFT", cb1, "RIGHT", 150, 0)
            
            local text2 = cb2:CreateFontString(nil, "OVERLAY", "GameFontNormal")
            text2:SetPoint("LEFT", cb2, "RIGHT", 5, 0)
            text2:SetText(label2)
            
            cb2:SetChecked(GetValue(PCB.db, dbKey2) or false)
            cb2:SetScript("OnClick", function(self)
                SetValue(PCB.db, dbKey2, self:GetChecked())
                if PCB.ApplyAll then PCB:ApplyAll() end
                if optionsFrame and optionsFrame.UpdateContent then optionsFrame.UpdateContent(selectedCategory) end
            end)
            
            return container
        end
        
        -- Helper function to add a checkbox with a button on the same row
        local function AddCheckboxButton(parent, label, dbKey, buttonLabel, onClick, y)
            local container = CreateFrame("Frame", nil, parent)
            container:SetPoint("TOPLEFT", 10, y)
            container:SetSize(480, 25)
            
            -- Checkbox on the left
            local cb = CreateFrame("CheckButton", nil, container, "UICheckButtonTemplate")
            cb:SetPoint("TOPLEFT", 0, 0)
            
            local text = cb:CreateFontString(nil, "OVERLAY", "GameFontNormal")
            text:SetPoint("LEFT", cb, "RIGHT", 5, 0)
            text:SetText(label)
            
            cb:SetChecked(GetValue(PCB.db, dbKey) or false)
            cb:SetScript("OnClick", function(self)
                SetValue(PCB.db, dbKey, self:GetChecked())
                if dbKey == "minimapButton.show" and PCB.UpdateMinimapButton then
                    PCB:UpdateMinimapButton()
                end
                if PCB.ApplyAll then PCB:ApplyAll() end
                if optionsFrame and optionsFrame.UpdateContent then optionsFrame.UpdateContent(selectedCategory) end
            end)
            
            -- Button on the right
            local btn = CreateFrame("Button", nil, container, "UIPanelButtonTemplate")
            btn:SetWidth(140)
            btn:SetHeight(22)
            btn:SetPoint("LEFT", cb, "RIGHT", 150, 0)
            btn:SetText(buttonLabel)
            
            if onClick == "toggleTestMode" then
                btn:SetScript("OnClick", function()
                    if PCB.SetTestMode then
                        local newState = not PCB.testMode
                        PCB:SetTestMode(newState)
                        PCB:Print(newState and "Test mode enabled" or "Test mode disabled")
                    end
                end)
            end
            
            return container
        end

            -- Helper function to add a simple dropdown (used for profiles)
            local function AddDropdown(parent, label, y, key)
                local container = CreateFrame("Frame", nil, parent)
                container:SetPoint("TOPLEFT", 10, y)
                container:SetSize(400, 24)

                local labelText = container:CreateFontString(nil, "OVERLAY", "GameFontNormal")
                labelText:SetPoint("TOPLEFT", 0, 0)
                labelText:SetText(label)
                container.labelText = labelText

                local dropdown = CreateFrame("Button", nil, container)
                dropdown:SetWidth(180)
                dropdown:SetHeight(24)
                dropdown:SetPoint("LEFT", 120, 0)

                local bg = dropdown:CreateTexture(nil, "BACKGROUND")
                bg:SetAllPoints()
                bg:SetColorTexture(0.15, 0.15, 0.15, 1)

                local border = dropdown:CreateTexture(nil, "ARTWORK")
                border:SetPoint("TOPLEFT", 1, -1)
                border:SetPoint("BOTTOMRIGHT", -1, 1)
                border:SetColorTexture(0.25, 0.25, 0.25, 1)

                local text = dropdown:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
                text:SetPoint("LEFT", 8, 0)
                text:SetPoint("RIGHT", -20, 0)
                text:SetJustifyH("LEFT")
                text:SetTextColor(1, 1, 1, 1)

                local arrowBtn = CreateFrame("Button", nil, dropdown)
                arrowBtn:SetSize(16, 16)
                arrowBtn:SetPoint("RIGHT", -4, 0)
                arrowBtn:SetNormalTexture("Interface\\ChatFrame\\UI-ChatIcon-ScrollDown-Up")
                arrowBtn:SetPushedTexture("Interface\\ChatFrame\\UI-ChatIcon-ScrollDown-Down")
                arrowBtn:SetHighlightTexture("Interface\\Buttons\\UI-Common-MouseHilight", "ADD")

                dropdown:SetScript("OnEnter", function() border:SetColorTexture(0.35, 0.35, 0.35, 1) end)
                dropdown:SetScript("OnLeave", function() border:SetColorTexture(0.25, 0.25, 0.25, 1) end)

                local menu = CreateFrame("Frame", nil, dropdown, "BackdropTemplate")
                menu:SetFrameStrata("HIGH")
                menu:SetBackdrop({
                    bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
                    edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
                    tile = true, tileSize = 32, edgeSize = 32,
                    insets = { left = 11, right = 12, top = 12, bottom = 11 }
                })
                menu:SetWidth(200)
                menu:SetPoint("TOP", dropdown, "BOTTOM", 0, -4)
                menu:Hide()

                local menuButtons = {}

                local function GetProfiles()
                    local profiles = {}
                    local playerName = UnitName("player")
                    local realmName = GetRealmName()
                    local _, className = UnitClass("player")

                    if playerName and realmName then
                        local charProfile = playerName .. " - " .. realmName
                        table.insert(profiles, charProfile)
                    end
                    if realmName then
                        table.insert(profiles, realmName)
                    end
                    if className then
                        table.insert(profiles, className)
                    end

                    if PCB.dbRoot and PCB.dbRoot.profiles then
                        for name in pairs(PCB.dbRoot.profiles) do
                            local exists = false
                            for _, p in ipairs(profiles) do
                                if p == name then exists = true; break end
                            end
                            if not exists then table.insert(profiles, name) end
                        end
                    end

                    table.sort(profiles, function(a, b)
                        if a == "Default" then return true end
                        if b == "Default" then return false end
                        return a < b
                    end)

                    return profiles
                end

                local function UpdateDropdown()
                    for _, btn in ipairs(menuButtons) do
                        btn:Hide()
                        btn:SetParent(nil)
                    end
                    menuButtons = {}

                    local profiles = GetProfiles()
                    local currentProfile = PCB:GetActiveProfileName()

                    if key == "existingProfile" then
                        text:SetText(currentProfile or "Default")
                    elseif key == "copyProfile" or key == "deleteProfile" then
                        text:SetText("Select...")
                    end

                    local function GetCharKey()
                        local name = UnitName("player") or "Unknown"
                        local realm = GetRealmName() or "Realm"
                        realm = realm:gsub("%s+", "")
                        return name .. " - " .. realm
                    end

                    local charKey = GetCharKey()

                    for i, profileName in ipairs(profiles) do
                        local btn = CreateFrame("Button", nil, menu)
                        btn:SetWidth(180)
                        btn:SetHeight(20)
                        btn:SetPoint("TOP", menu, "TOP", 0, -10 - (i-1) * 20)

                        local btnBg = btn:CreateTexture(nil, "BACKGROUND")
                        btnBg:SetAllPoints()
                        btnBg:SetColorTexture(0.2, 0.2, 0.2, 0.8)

                        local check = btn:CreateTexture(nil, "OVERLAY")
                        check:SetSize(16, 16)
                        check:SetPoint("LEFT", 5, 0)
                        check:SetTexture("Interface\\Buttons\\UI-CheckBox-Check")
                        if profileName == currentProfile then check:Show() else check:Hide() end

                        local function ToTitleCase(str)
                            return str:gsub("(%a)([%w_']*)", function(first, rest) return first:upper() .. rest:lower() end)
                        end

                        local btnText = btn:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
                        btnText:SetPoint("LEFT", 25, 0)
                        btnText:SetText(ToTitleCase(profileName))
                        if profileName == currentProfile then btnText:SetTextColor(1, 0.82, 0, 1) else btnText:SetTextColor(1,1,1,1) end

                        btn:SetScript("OnEnter", function() btnBg:SetColorTexture(0.4, 0.4, 0.4, 1) end)
                        btn:SetScript("OnLeave", function() btnBg:SetColorTexture(0.2, 0.2, 0.2, 0.8) end)
                        btn:SetScript("OnClick", function()
                            if key == "existingProfile" then
                                if not PCB.dbRoot.profiles[profileName] then
                                    PCB:EnsureProfile(profileName)
                                    PCB:Print("Created new profile: " .. profileName)
                                end
                                PCB:SetActiveProfileName(profileName)
                                PCB:Print("Switched to profile: " .. profileName)
                                text:SetText(profileName)
                                if PCB.ApplyAll then PCB:ApplyAll() end
                            elseif key == "copyProfile" then
                                local currentName = PCB:GetActiveProfileName()
                                if profileName ~= currentName and PCB.dbRoot.profiles[profileName] then
                                    PCB.dbRoot.profiles[currentName] = deepcopy(PCB.dbRoot.profiles[profileName])
                                    PCB:SelectActiveProfile()
                                    PCB:Print("Copied settings from " .. profileName)
                                    if PCB.ApplyAll then PCB:ApplyAll() end
                                end
                            elseif key == "deleteProfile" then
                                if profileName ~= "Default" and profileName ~= currentProfile and PCB.dbRoot.profiles[profileName] then
                                    PCB.dbRoot.profiles[profileName] = nil
                                    PCB:Print("Deleted profile: " .. profileName)
                                    UpdateDropdown()
                                else
                                    PCB:Print("Cannot delete Default, currently active profile, or non-existent profile")
                                end
                            end
                            menu:Hide()
                        end)

                        table.insert(menuButtons, btn)
                    end

                    menu:SetHeight(math.max(40, 20 + #profiles * 20))
                end

                local function ToggleMenu()
                    UpdateDropdown()
                    if menu:IsShown() then menu:Hide() else menu:Show() end
                end

                dropdown:SetScript("OnClick", ToggleMenu)
                arrowBtn:SetScript("OnClick", ToggleMenu)

                UpdateDropdown()
                return container
            end
        
        -- Helper function to add a slider
        local function AddSlider(parent, label, dbKey, y, minVal, maxVal, stepVal)
            local slider = CreateFrame("Slider", nil, parent, "OptionsSliderTemplate")
            slider:SetWidth(200)
            slider:SetHeight(20)
            slider:SetPoint("TOPLEFT", 10, y)
            slider:SetMinMaxValues(minVal, maxVal)
            slider:SetValueStep(stepVal)
            slider:SetObeyStepOnDrag(true)
            
            -- Set min/max labels to actual values
            if slider.Low then slider.Low:SetText(tostring(minVal)) end
            if slider.High then slider.High:SetText(tostring(maxVal)) end
            
            -- Label
            local labelText = slider:CreateFontString(nil, "OVERLAY", "GameFontNormal")
            labelText:SetPoint("BOTTOMLEFT", slider, "TOPLEFT", 0, 2)
            labelText:SetText(label)
            
            -- Value display
            local valueText = slider:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
            valueText:SetPoint("BOTTOMRIGHT", slider, "TOPRIGHT", 0, 2)
            
            local currentValue = GetValue(PCB.db, dbKey) or minVal
            slider:SetValue(currentValue)
            valueText:SetText(string.format("%.2f", currentValue))
            
            slider:SetScript("OnValueChanged", function(self, value)
                value = math.floor(value / stepVal + 0.5) * stepVal
                SetValue(PCB.db, dbKey, value)
                valueText:SetText(string.format("%.2f", value))
                if PCB.ApplyAll then PCB:ApplyAll() end
            end)
            
            return slider
        end
        
        -- Helper function to add a 2x2 grid of sliders
        local function AddSliderGrid(parent, y, sliders)
            local container = CreateFrame("Frame", nil, parent)
            container:SetPoint("TOPLEFT", 10, y)
            container:SetSize(480, 120)
            
            -- Create 4 sliders in a 2x2 grid
            for i, sliderData in ipairs(sliders) do
                local slider = CreateFrame("Slider", nil, container, "OptionsSliderTemplate")
                slider:SetWidth(220)
                slider:SetHeight(20)
                
                -- Position: row 1 (top) = i <= 2, row 2 (bottom) = i > 2
                -- Position: col 1 (left) = odd, col 2 (right) = even
                local row = (i <= 2) and 0 or 1
                local col = ((i - 1) % 2)
                local xOffset = col * 240
                local yOffset = row * -60
                
                slider:SetPoint("TOPLEFT", xOffset, yOffset)
                slider:SetMinMaxValues(sliderData.min, sliderData.max)
                slider:SetValueStep(sliderData.step)
                slider:SetObeyStepOnDrag(true)
                
                -- Set min/max labels to actual values
                if slider.Low then slider.Low:SetText(tostring(sliderData.min)) end
                if slider.High then slider.High:SetText(tostring(sliderData.max)) end
                
                -- Label
                local labelText = slider:CreateFontString(nil, "OVERLAY", "GameFontNormal")
                labelText:SetPoint("BOTTOMLEFT", slider, "TOPLEFT", 0, 2)
                labelText:SetText(sliderData.label)
                
                -- Value display
                local valueText = slider:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
                valueText:SetPoint("BOTTOMRIGHT", slider, "TOPRIGHT", 0, 2)
                
                local currentValue = GetValue(PCB.db, sliderData.key) or sliderData.min
                slider:SetValue(currentValue)
                valueText:SetText(string.format("%.2f", currentValue))
                
                slider:SetScript("OnValueChanged", function(self, value)
                    value = math.floor(value / sliderData.step + 0.5) * sliderData.step
                    SetValue(PCB.db, sliderData.key, value)
                    valueText:SetText(string.format("%.2f", value))
                    if PCB.ApplyAll then PCB:ApplyAll() end
                end)
            end
            
            return container
        end
        
        -- Helper function to add a description text
        local function AddDescription(parent, text, y)
            local desc = parent:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
            desc:SetPoint("TOPLEFT", 10, y)
            desc:SetPoint("TOPRIGHT", -10, y)
            desc:SetJustifyH("LEFT")
            desc:SetJustifyV("TOP")
            desc:SetText(text)
            desc:SetWordWrap(true)
            desc:SetNonSpaceWrap(false)
            -- Calculate height based on text
            desc:SetHeight(desc:GetStringHeight() + 5)
            return desc
        end
        
        -- Helper function to add a label
        local function AddLabel(parent, text, y, getValue)
            local label = parent:CreateFontString(nil, "OVERLAY", "GameFontNormal")
            label:SetPoint("TOPLEFT", 10, y)
            if getValue == "currentProfile" then
                label:SetText(string.format(text, PCB:GetActiveProfileName() or "Default"))
            else
                label:SetText(text)
            end
            return label
        end
        
        -- Helper function to add a button
        local function AddButton(parent, label, y, onClick)
            local btn = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
            btn:SetWidth(120)
            btn:SetHeight(22)
            btn:SetPoint("TOPLEFT", 10, y)
            btn:SetText(label)
            
            if onClick == "resetProfile" then
                btn:SetScript("OnClick", function()
                    if PCB.ResetProfile then
                        PCB:ResetProfile()
                        PCB:Print("Profile reset to default values.")
                        if PCB.ApplyAll then PCB:ApplyAll() end
                    end
                end)
            elseif onClick == "toggleTestMode" then
                btn:SetScript("OnClick", function()
                    if PCB.SetTestMode then
                        local newState = not PCB.testMode
                        PCB:SetTestMode(newState)
                        PCB:Print(newState and "Test mode enabled" or "Test mode disabled")
                    end
                end)
            end
            
            return btn
        end
        
        -- Helper function to add a color picker
        local function AddColorPicker(parent, label, dbKey, y)
            local container = CreateFrame("Frame", nil, parent)
            container:SetPoint("TOPLEFT", 10, y)
            container:SetSize(400, 30)
            
            local labelText = container:CreateFontString(nil, "OVERLAY", "GameFontNormal")
            labelText:SetPoint("TOPLEFT", 0, -5)
            labelText:SetText(label)
            
            local colorBtn = CreateFrame("Button", nil, container)
            colorBtn:SetWidth(40)
            colorBtn:SetHeight(20)
            colorBtn:SetPoint("LEFT", labelText, "RIGHT", 10, 0)
            
            -- Color swatch background
            local bg = colorBtn:CreateTexture(nil, "BACKGROUND")
            bg:SetAllPoints()
            bg:SetColorTexture(0.15, 0.15, 0.15, 1)
            
            -- Color swatch
            local swatch = colorBtn:CreateTexture(nil, "ARTWORK")
            swatch:SetPoint("TOPLEFT", 2, -2)
            swatch:SetPoint("BOTTOMRIGHT", -2, 2)
            
            -- Border
            local border = colorBtn:CreateTexture(nil, "OVERLAY")
            border:SetColorTexture(1, 1, 1, 0.3)
            border:SetPoint("TOPLEFT", 1, -1)
            border:SetPoint("BOTTOMRIGHT", -1, 1)
            
            -- Update color display
            local function UpdateColor()
                local color = GetValue(PCB.db, dbKey) or {r=1, g=1, b=1, a=1}
                swatch:SetColorTexture(color.r, color.g, color.b, color.a or 1)
            end
            
            UpdateColor()
            
            -- Color picker callback
            local function OnColorChanged(restore)
                local newR, newG, newB, newA
                if restore then
                    newR, newG, newB, newA = unpack(restore)
                else
                    newR, newG, newB = ColorPickerFrame:GetColorRGB()
                    newA = (ColorPickerFrame.GetColorAlpha and ColorPickerFrame:GetColorAlpha()) or 1
                end
                
                SetValue(PCB.db, dbKey, {r = newR, g = newG, b = newB, a = newA})
                UpdateColor()
                if PCB.ApplyAll then PCB:ApplyAll() end
            end
            
            -- Open color picker
            colorBtn:SetScript("OnClick", function()
                local color = GetValue(PCB.db, dbKey) or {r=1, g=1, b=1, a=1}
                local r, g, b, a = color.r or 1, color.g or 1, color.b or 1, color.a or 1
                
                ColorPickerFrame:SetupColorPickerAndShow({
                    r = r,
                    g = g,
                    b = b,
                    opacity = a,
                    hasOpacity = true,
                    swatchFunc = OnColorChanged,
                    opacityFunc = OnColorChanged,
                    cancelFunc = function()
                        OnColorChanged({r, g, b, a})
                    end,
                })
            end)
            
            -- Hover effect
            colorBtn:SetScript("OnEnter", function()
                border:SetColorTexture(1, 1, 1, 0.6)
            end)
            colorBtn:SetScript("OnLeave", function()
                border:SetColorTexture(1, 1, 1, 0.3)
            end)
            
            return container
        end
        
        -- Helper function to add a 2-column grid of color pickers
        local function AddColorPickerGrid(parent, y, pickers)
            local container = CreateFrame("Frame", nil, parent)
            container:SetPoint("TOPLEFT", 10, y)
            container:SetSize(480, 100)
            
            local maxHeight = 0
            
            for i, pickerData in ipairs(pickers) do
                local col = ((i - 1) % 2)  -- 0 for left, 1 for right
                local row = math.floor((i - 1) / 2)
                
                local xOffset = col * 240
                local yOffset = -row * 40
                
                local pickerContainer = CreateFrame("Frame", nil, container)
                pickerContainer:SetPoint("TOPLEFT", xOffset, yOffset)
                pickerContainer:SetSize(220, 30)
                
                local labelText = pickerContainer:CreateFontString(nil, "OVERLAY", "GameFontNormal")
                labelText:SetPoint("TOPLEFT", 0, -5)
                labelText:SetWidth(145)
                labelText:SetJustifyH("LEFT")
                labelText:SetText(pickerData.label)
                
                local colorBtn = CreateFrame("Button", nil, pickerContainer)
                colorBtn:SetWidth(40)
                colorBtn:SetHeight(20)
                colorBtn:SetPoint("TOPLEFT", 155, -3)
                
                -- Color swatch background
                local bg = colorBtn:CreateTexture(nil, "BACKGROUND")
                bg:SetAllPoints()
                bg:SetColorTexture(0.15, 0.15, 0.15, 1)
                
                -- Color swatch
                local swatch = colorBtn:CreateTexture(nil, "ARTWORK")
                swatch:SetPoint("TOPLEFT", 2, -2)
                swatch:SetPoint("BOTTOMRIGHT", -2, 2)
                
                -- Border
                local border = colorBtn:CreateTexture(nil, "OVERLAY")
                border:SetColorTexture(1, 1, 1, 0.3)
                border:SetPoint("TOPLEFT", 1, -1)
                border:SetPoint("BOTTOMRIGHT", -1, 1)
                
                -- Update color display
                local function UpdateColor()
                    local color = GetValue(PCB.db, pickerData.key) or {r=1, g=1, b=1, a=1}
                    swatch:SetColorTexture(color.r, color.g, color.b, color.a or 1)
                end
                
                UpdateColor()
                
                -- Color picker callback
                local function OnColorChanged(restore)
                    local newR, newG, newB, newA
                    if restore then
                        newR, newG, newB, newA = unpack(restore)
                    else
                        newR, newG, newB = ColorPickerFrame:GetColorRGB()
                        newA = (ColorPickerFrame.GetColorAlpha and ColorPickerFrame:GetColorAlpha()) or 1
                    end
                    
                    SetValue(PCB.db, pickerData.key, {r = newR, g = newG, b = newB, a = newA})
                    UpdateColor()
                    if PCB.ApplyAll then PCB:ApplyAll() end
                end
                
                -- Open color picker
                colorBtn:SetScript("OnClick", function()
                    local color = GetValue(PCB.db, pickerData.key) or {r=1, g=1, b=1, a=1}
                    local r, g, b, a = color.r or 1, color.g or 1, color.b or 1, color.a or 1
                    
                    ColorPickerFrame:SetupColorPickerAndShow({
                        r = r,
                        g = g,
                        b = b,
                        opacity = a,
                        hasOpacity = true,
                        swatchFunc = OnColorChanged,
                        opacityFunc = OnColorChanged,
                        cancelFunc = function()
                            OnColorChanged({r, g, b, a})
                        end,
                    })
                end)
                
                -- Hover effect
                colorBtn:SetScript("OnEnter", function()
                    border:SetColorTexture(1, 1, 1, 0.6)
                end)
                colorBtn:SetScript("OnLeave", function()
                    border:SetColorTexture(1, 1, 1, 0.3)
                end)
                
                maxHeight = math.max(maxHeight, (row + 1) * 40)
            end
            
            container:SetHeight(maxHeight)
            return container
        end
        
        -- Helper function to add an editbox
        local function AddEditBox(parent, label, y, placeholder)
            -- Container to hold both label and editbox
            local container = CreateFrame("Frame", nil, parent)
            container:SetPoint("TOPLEFT", 10, y)
            container:SetSize(400, 24)
            
            local labelText = container:CreateFontString(nil, "OVERLAY", "GameFontNormal")
            labelText:SetPoint("TOPLEFT", 0, 0)
            labelText:SetText(label)
            
            local editbox = CreateFrame("EditBox", nil, container, "InputBoxTemplate")
            editbox:SetWidth(180)
            editbox:SetHeight(20)
            editbox:SetPoint("LEFT", labelText, "RIGHT", 10, 0)
            editbox:SetAutoFocus(false)
            editbox:SetScript("OnEnterPressed", function(self)
                local newName = self:GetText()
                if newName and newName ~= "" then
                    if PCB.EnsureProfile then
                        PCB:EnsureProfile(newName)
                        PCB:SetActiveProfileName(newName)
                        PCB:Print("Created and switched to profile: " .. newName)
                        self:SetText("")
                        if PCB.ApplyAll then PCB:ApplyAll() end
                    end
                end
                self:ClearFocus()
            end)
            
            return container
        end
        
        -- Helper function to add a dropdown
        local function AddLSMDropdown(parent, option, y)
            local LSM = PCB.LSM
            local label = option.label
            local dbKey = option.key
            local mediaType = option.mediaType
            if not LSM then
                local fallback = parent:CreateFontString(nil, "OVERLAY", "GameFontNormal")
                fallback:SetPoint("TOPLEFT", 10, y)
                fallback:SetText(label .. ": LibSharedMedia not loaded")
                return fallback
            end

            local container = CreateFrame("Frame", nil, parent)
            container:SetPoint("TOPLEFT", 10, y)
            container:SetSize(400, 24)

            local labelText = container:CreateFontString(nil, "OVERLAY", "GameFontNormal")
            labelText:SetPoint("TOPLEFT", 0, 0)
            labelText:SetWidth(120)
            labelText:SetJustifyH("LEFT")
            labelText:SetText(label)

            container.labelText = labelText

            local dropdown = CreateFrame("Button", nil, container)
            dropdown:SetWidth(180)
            dropdown:SetHeight(24)
            dropdown:SetPoint("LEFT", 120, 0)

            local bg = dropdown:CreateTexture(nil, "BACKGROUND")
            bg:SetAllPoints()
            bg:SetColorTexture(0.15, 0.15, 0.15, 1)

            local border = dropdown:CreateTexture(nil, "ARTWORK")
            border:SetPoint("TOPLEFT", 1, -1)
            border:SetPoint("BOTTOMRIGHT", -1, 1)
            border:SetColorTexture(0.25, 0.25, 0.25, 1)

            local text = dropdown:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
            text:SetPoint("LEFT", 8, 0)
            text:SetPoint("RIGHT", -20, 0)
            text:SetJustifyH("LEFT")
            text:SetTextColor(1, 1, 1, 1)

            local arrowBtn = CreateFrame("Button", nil, dropdown)
            arrowBtn:SetSize(16, 16)
            arrowBtn:SetPoint("RIGHT", -4, 0)
            arrowBtn:SetNormalTexture("Interface\\ChatFrame\\UI-ChatIcon-ScrollDown-Up")
            arrowBtn:SetPushedTexture("Interface\\ChatFrame\\UI-ChatIcon-ScrollDown-Down")
            arrowBtn:SetHighlightTexture("Interface\\Buttons\\UI-Common-MouseHilight", "ADD")

            dropdown:SetScript("OnEnter", function() border:SetColorTexture(0.35, 0.35, 0.35, 1) end)
            dropdown:SetScript("OnLeave", function() border:SetColorTexture(0.25, 0.25, 0.25, 1) end)

            local menu = CreateFrame("Frame", nil, dropdown, "BackdropTemplate")
            menu:SetFrameStrata("HIGH")
            local function GetProfiles()
                local profiles = {}
                
                -- Get character info
                local playerName = UnitName("player")
                local realmName = GetRealmName()
                local _, className = UnitClass("player")
                
                -- Add character-realm profile suggestion
                if playerName and realmName then
                    local charProfile = playerName .. " - " .. realmName
                    table.insert(profiles, charProfile)
                end
                
                -- Add realm profile suggestion
                if realmName then
                    table.insert(profiles, realmName)
                end
                
                -- Add class profile suggestion
                if className then
                    table.insert(profiles, className)
                end
                
                -- Add existing profiles from database
                if PCB.dbRoot and PCB.dbRoot.profiles then
                    for name in pairs(PCB.dbRoot.profiles) do
                        -- Don't duplicate if it already exists
                        local exists = false
                        for _, p in ipairs(profiles) do
                            if p == name then
                                exists = true
                                break
                            end
                        end
                        if not exists then
                            table.insert(profiles, name)
                        end
                    end
                end
                
                -- Sort with Default first
                table.sort(profiles, function(a, b)
                    if a == "Default" then return true end
                    if b == "Default" then return false end
                    return a < b
                end)
                
                return profiles
            end
            
            -- Menu frame
            local menu = CreateFrame("Frame", nil, dropdown, "BackdropTemplate")
            menu:SetFrameStrata("HIGH")
            menu:SetBackdrop({
                bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
                edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
                tile = true, tileSize = 32, edgeSize = 32,
                insets = { left = 11, right = 12, top = 12, bottom = 11 }
            })
            menu:SetWidth(200)
            menu:SetPoint("TOP", dropdown, "BOTTOM", 0, -4)
            menu:Hide()
            
            local menuButtons = {}
            
            local function UpdateDropdown()
                -- Clear old buttons
                for _, btn in ipairs(menuButtons) do
                    btn:Hide()
                    btn:SetParent(nil)
                end
                menuButtons = {}
                
                local profiles = GetProfiles()
                local currentProfile = PCB:GetActiveProfileName()
                
                if key == "existingProfile" then
                    text:SetText(currentProfile or "Default")
                elseif key == "copyProfile" or key == "deleteProfile" then
                    text:SetText("Select...")
                end
                
                -- Get character key for current character
                local function GetCharKey()
                    local name = UnitName("player") or "Unknown"
                    local realm = GetRealmName() or "Realm"
                    realm = realm:gsub("%s+", "")
                    return name .. " - " .. realm
                end
                
                local charKey = GetCharKey()
                
                -- Create menu buttons
                for i, profileName in ipairs(profiles) do
                    local btn = CreateFrame("Button", nil, menu)
                    btn:SetWidth(180)
                    btn:SetHeight(20)
                    btn:SetPoint("TOP", menu, "TOP", 0, -10 - (i-1) * 20)
                    
                    local btnBg = btn:CreateTexture(nil, "BACKGROUND")
                    btnBg:SetAllPoints()
                    btnBg:SetColorTexture(0.2, 0.2, 0.2, 0.8)
                    
                    -- Check icon
                    local check = btn:CreateTexture(nil, "OVERLAY")
                    check:SetSize(16, 16)
                    check:SetPoint("LEFT", 5, 0)
                    check:SetTexture("Interface\\Buttons\\UI-CheckBox-Check")
                    if profileName == currentProfile then
                        check:Show()
                    else
                        check:Hide()
                    end
                    
                    -- Title case function
                    local function ToTitleCase(str)
                        return str:gsub("(%a)([%w_']*)", function(first, rest)
                            return first:upper() .. rest:lower()
                        end)
                    end
                    
                    local btnText = btn:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
                    btnText:SetPoint("LEFT", 25, 0)
                    btnText:SetText(ToTitleCase(profileName))
                    
                    -- Highlight selected profile in gold, others in white
                    if profileName == currentProfile then
                        btnText:SetTextColor(1, 0.82, 0, 1)  -- Gold for selected
                    else
                        btnText:SetTextColor(1, 1, 1, 1)  -- White for others
                    end
                    
                    btn:SetScript("OnEnter", function() btnBg:SetColorTexture(0.4, 0.4, 0.4, 1) end)
                    btn:SetScript("OnLeave", function() btnBg:SetColorTexture(0.2, 0.2, 0.2, 0.8) end)
                    
                    btn:SetScript("OnClick", function()
                        if key == "existingProfile" then
                            -- Ensure the profile exists before switching
                            if not PCB.dbRoot.profiles[profileName] then
                                PCB:EnsureProfile(profileName)
                                PCB:Print("Created new profile: " .. profileName)
                            end
                            PCB:SetActiveProfileName(profileName)
                            PCB:Print("Switched to profile: " .. profileName)
                            text:SetText(profileName)
                            if PCB.ApplyAll then PCB:ApplyAll() end
                        elseif key == "copyProfile" then
                            local currentName = PCB:GetActiveProfileName()
                            if profileName ~= currentName and PCB.dbRoot.profiles[profileName] then
                                PCB.dbRoot.profiles[currentName] = deepcopy(PCB.dbRoot.profiles[profileName])
                                PCB:SelectActiveProfile()
                                PCB:Print("Copied settings from " .. profileName)
                                if PCB.ApplyAll then PCB:ApplyAll() end
                            end
                        elseif key == "deleteProfile" then
                            if profileName ~= "Default" and profileName ~= currentProfile and PCB.dbRoot.profiles[profileName] then
                                PCB.dbRoot.profiles[profileName] = nil
                                PCB:Print("Deleted profile: " .. profileName)
                                UpdateDropdown()
                            else
                                PCB:Print("Cannot delete Default, currently active profile, or non-existent profile")
                            end
                        end
                        menu:Hide()
                    end)
                    
                    table.insert(menuButtons, btn)
                end
                
                menu:SetHeight(math.max(40, 20 + #profiles * 20))
            end
            
            local function ToggleMenu()
                UpdateDropdown()
                if menu:IsShown() then
                    menu:Hide()
                else
                    menu:Show()
                end
            end
            
            dropdown:SetScript("OnClick", ToggleMenu)
            arrowBtn:SetScript("OnClick", ToggleMenu)
            
            -- Hide menu when clicking elsewhere
            menu:SetScript("OnHide", function()
                -- Cleanup
            end)
            
            UpdateDropdown()
            
            return container
        end
        
        -- Helper function to add LSM (LibSharedMedia) dropdown
        local function AddLSMDropdown(parent, option, y)
            local LSM = PCB.LSM
            local label = option.label
            local dbKey = option.key
            local mediaType = option.mediaType
            if not LSM then
                local fallback = parent:CreateFontString(nil, "OVERLAY", "GameFontNormal")
                fallback:SetPoint("TOPLEFT", 10, y)
                fallback:SetText(label .. ": LibSharedMedia not loaded")
                return fallback
            end

            local container = CreateFrame("Frame", nil, parent)
            container:SetPoint("TOPLEFT", 10, y)
            container:SetSize(400, 24)

            local labelText = container:CreateFontString(nil, "OVERLAY", "GameFontNormal")
            labelText:SetPoint("TOPLEFT", 0, 0)
            labelText:SetWidth(120)
            labelText:SetJustifyH("LEFT")
            labelText:SetText(label)

            container.labelText = labelText

            local dropdown = CreateFrame("Button", nil, container)
            dropdown:SetWidth(180)
            dropdown:SetHeight(24)
            dropdown:SetPoint("LEFT", 120, 0)

            local bg = dropdown:CreateTexture(nil, "BACKGROUND")
            bg:SetAllPoints()
            bg:SetColorTexture(0.15, 0.15, 0.15, 1)

            local border = dropdown:CreateTexture(nil, "ARTWORK")
            border:SetPoint("TOPLEFT", 1, -1)
            border:SetPoint("BOTTOMRIGHT", -1, 1)
            border:SetColorTexture(0.25, 0.25, 0.25, 1)

            local text = dropdown:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
            text:SetPoint("LEFT", 8, 0)
            text:SetPoint("RIGHT", -20, 0)
            text:SetJustifyH("LEFT")
            text:SetTextColor(1, 1, 1, 1)

            local arrowBtn = CreateFrame("Button", nil, dropdown)
            arrowBtn:SetSize(16, 16)
            arrowBtn:SetPoint("RIGHT", -4, 0)
            arrowBtn:SetNormalTexture("Interface\\ChatFrame\\UI-ChatIcon-ScrollDown-Up")
            arrowBtn:SetPushedTexture("Interface\\ChatFrame\\UI-ChatIcon-ScrollDown-Down")
            arrowBtn:SetHighlightTexture("Interface\\Buttons\\UI-Common-MouseHilight", "ADD")

            dropdown:SetScript("OnEnter", function() border:SetColorTexture(0.35, 0.35, 0.35, 1) end)
            dropdown:SetScript("OnLeave", function() border:SetColorTexture(0.25, 0.25, 0.25, 1) end)

            local menu = CreateFrame("Frame", nil, dropdown, "BackdropTemplate")
            menu:SetFrameStrata("HIGH")
            menu:SetBackdrop({
                bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
                edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
                tile = true, tileSize = 32, edgeSize = 32,
                insets = { left = 11, right = 12, top = 12, bottom = 11 }
            })
            menu:SetWidth(280)
            menu:SetPoint("TOP", dropdown, "BOTTOM", 0, -4)
            menu:Hide()
            
            -- Create scroll frame for menu
            local scrollFrame = CreateFrame("ScrollFrame", nil, menu)
            scrollFrame:SetPoint("TOPLEFT", 12, -12)
            scrollFrame:SetPoint("BOTTOMRIGHT", -12, 12)
            
            local scrollChild = CreateFrame("Frame", nil, scrollFrame)
            scrollFrame:SetScrollChild(scrollChild)
            scrollChild:SetWidth(256)
            
            -- Enable mouse wheel scrolling
            menu:EnableMouseWheel(true)
            menu:SetScript("OnMouseWheel", function(self, delta)
                local current = scrollFrame:GetVerticalScroll()
                local maxScroll = scrollChild:GetHeight() - scrollFrame:GetHeight()
                if maxScroll > 0 then
                    scrollFrame:SetVerticalScroll(math.max(0, math.min(maxScroll, current - (delta * 20))))
                end
            end)
            
            local menuButtons = {}
            local maxVisibleItems = 7

            local function UpdateLSMDropdown()
                for _, btn in ipairs(menuButtons) do
                    btn:Hide()
                    btn:SetParent(nil)
                end
                menuButtons = {}
                
                local mediaList = LSM:List(mediaType) or {}
                local currentValue = GetValue(PCB.db, dbKey) or "Blizzard"
                text:SetText(currentValue)
                
                local isTexture = (mediaType == "statusbar")
                local isFont = (mediaType == "font")
                local itemHeight = isTexture and 30 or 24
                
                for i, mediaName in ipairs(mediaList) do
                    local btn = CreateFrame("Button", nil, scrollChild)
                    btn:SetWidth(256)
                    btn:SetHeight(itemHeight)
                    btn:SetPoint("TOP", scrollChild, "TOP", 0, -(i-1) * itemHeight)
                    
                    local btnBg = btn:CreateTexture(nil, "BACKGROUND")
                    btnBg:SetAllPoints()
                    btnBg:SetColorTexture(0.2, 0.2, 0.2, 0.8)
                    
                    if isTexture then
                        -- Texture preview bar
                        local texturePath = LSM:Fetch(mediaType, mediaName)
                        local previewBar = btn:CreateTexture(nil, "ARTWORK")
                        previewBar:SetPoint("TOPLEFT", 5, -5)
                        previewBar:SetPoint("TOPRIGHT", -5, -5)
                        previewBar:SetHeight(20)
                        previewBar:SetTexture(texturePath)
                        previewBar:SetVertexColor(0.3, 0.6, 1, 1)
                        
                        -- Font for the name overlaid on texture
                        local fontKey = GetValue(PCB.db, "fontKey") or "Friz Quadrata TT"
                        local fontPath = LSM:Fetch("font", fontKey)
                        local btnText = btn:CreateFontString(nil, "OVERLAY")
                        btnText:SetPoint("CENTER", previewBar, "CENTER", 0, 0)
                        btnText:SetFont(fontPath, 11)
                        btnText:SetText(mediaName)
                        btnText:SetTextColor(1, 1, 1, 1)
                    elseif isFont then
                        -- Font preview using the font itself
                        local fontPath = LSM:Fetch(mediaType, mediaName)
                        local btnText = btn:CreateFontString(nil, "OVERLAY")
                        btnText:SetPoint("LEFT", 5, 0)
                        btnText:SetFont(fontPath, 12)
                        btnText:SetText(mediaName)
                        
                        if mediaName == currentValue then
                            btnText:SetTextColor(1, 0.82, 0, 1)
                        else
                            btnText:SetTextColor(1, 1, 1, 1)
                        end
                    else
                        -- Fallback for other media types
                        local btnText = btn:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
                        btnText:SetPoint("LEFT", 5, 0)
                        btnText:SetText(mediaName)
                        
                        if mediaName == currentValue then
                            btnText:SetTextColor(1, 0.82, 0, 1)
                        else
                            btnText:SetTextColor(1, 1, 1, 1)
                        end
                    end
                    
                    btn:SetScript("OnEnter", function() btnBg:SetColorTexture(0.4, 0.4, 0.4, 1) end)
                    btn:SetScript("OnLeave", function() btnBg:SetColorTexture(0.2, 0.2, 0.2, 0.8) end)
                    btn:SetScript("OnClick", function()
                        SetValue(PCB.db, dbKey, mediaName)
                        text:SetText(mediaName)
                        menu:Hide()
                        if PCB.ApplyAll then PCB:ApplyAll() end
                    end)
                    
                    table.insert(menuButtons, btn)
                end
                
                -- Set scrollChild height based on content
                scrollChild:SetHeight(math.max(1, #mediaList * itemHeight))
                
                -- Set menu height based on visible items
                local visibleItems = math.min(maxVisibleItems, #mediaList)
                menu:SetHeight(visibleItems * itemHeight + 24)
                
                -- Reset scroll position
                scrollFrame:SetVerticalScroll(0)
            end
            
            local function ToggleMenu()
                UpdateLSMDropdown()
                if menu:IsShown() then menu:Hide() else menu:Show() end
            end
            
            dropdown:SetScript("OnClick", ToggleMenu)
            arrowBtn:SetScript("OnClick", ToggleMenu)
            
            UpdateLSMDropdown()

            -- expose internals for external control
            container.dropdown = dropdown
            container.arrowBtn = arrowBtn
            container.text = text
            container.option = option

            -- Apply disabledIf if present
            if option.disabledIf then
                local isDisabled = false
                local ok, res = pcall(option.disabledIf)
                if ok then isDisabled = res end
                dropdown:EnableMouse(not isDisabled)
                arrowBtn:EnableMouse(not isDisabled)
                dropdown:SetAlpha(isDisabled and 0.5 or 1)
                text:SetTextColor(isDisabled and 0.5 or 1, isDisabled and 0.5 or 1, isDisabled and 0.5 or 1, 1)
            end

            return container
        end
        
        -- Helper function to add outline dropdown
        local function AddOutlineDropdown(parent, option, y)
            local outlines = {
                { name = "Outline", value = "OUTLINE" },
                { name = "Thick Outline", value = "THICKOUTLINE" },
                { name = "None", value = "" },
            }
            local label = option.label
            local dbKey = option.key

            local container = CreateFrame("Frame", nil, parent)
            container:SetPoint("TOPLEFT", 10, y)
            container:SetSize(400, 24)

            local labelText = container:CreateFontString(nil, "OVERLAY", "GameFontNormal")
            labelText:SetPoint("TOPLEFT", 0, 0)
            labelText:SetWidth(120)
            labelText:SetJustifyH("LEFT")
            labelText:SetText(label)

            local dropdown = CreateFrame("Button", nil, container)
            dropdown:SetWidth(180)
            dropdown:SetHeight(24)
            dropdown:SetPoint("LEFT", 120, 0)

            local bg = dropdown:CreateTexture(nil, "BACKGROUND")
            bg:SetAllPoints()
            bg:SetColorTexture(0.15, 0.15, 0.15, 1)

            local border = dropdown:CreateTexture(nil, "ARTWORK")
            border:SetPoint("TOPLEFT", 1, -1)
            border:SetPoint("BOTTOMRIGHT", -1, 1)
            border:SetColorTexture(0.25, 0.25, 0.25, 1)

            local text = dropdown:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
            text:SetPoint("LEFT", 8, 0)
            text:SetPoint("RIGHT", -20, 0)
            text:SetJustifyH("LEFT")
            text:SetTextColor(1, 1, 1, 1)

            local arrowBtn = CreateFrame("Button", nil, dropdown)
            arrowBtn:SetSize(16, 16)
            arrowBtn:SetPoint("RIGHT", -4, 0)
            arrowBtn:SetNormalTexture("Interface\\ChatFrame\\UI-ChatIcon-ScrollDown-Up")
            arrowBtn:SetPushedTexture("Interface\\ChatFrame\\UI-ChatIcon-ScrollDown-Down")
            arrowBtn:SetHighlightTexture("Interface\\Buttons\\UI-Common-MouseHilight", "ADD")

            dropdown:SetScript("OnEnter", function() border:SetColorTexture(0.35, 0.35, 0.35, 1) end)
            dropdown:SetScript("OnLeave", function() border:SetColorTexture(0.25, 0.25, 0.25, 1) end)
            
            local menu = CreateFrame("Frame", nil, dropdown, "BackdropTemplate")
            menu:SetFrameStrata("HIGH")
            menu:SetBackdrop({
                bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
                edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
                tile = true, tileSize = 32, edgeSize = 32,
                insets = { left = 11, right = 12, top = 12, bottom = 11 }
            })
            menu:SetWidth(200)
            menu:SetPoint("TOP", dropdown, "BOTTOM", 0, -4)
            menu:Hide()
            
            local menuButtons = {}
            
            local function UpdateOutlineDropdown()
                for _, btn in ipairs(menuButtons) do
                    btn:Hide()
                    btn:SetParent(nil)
                end
                menuButtons = {}
                
                local currentValue = GetValue(PCB.db, dbKey) or "OUTLINE"
                
                -- Find matching name for display
                local displayName = "Outline"
                for _, outline in ipairs(outlines) do
                    if outline.value == currentValue then
                        displayName = outline.name
                        break
                    end
                end
                text:SetText(displayName)
                
                for i, outline in ipairs(outlines) do
                    local btn = CreateFrame("Button", nil, menu)
                    btn:SetWidth(180)
                    btn:SetHeight(20)
                    btn:SetPoint("TOP", menu, "TOP", 0, -10 - (i-1) * 20)
                    
                    local btnBg = btn:CreateTexture(nil, "BACKGROUND")
                    btnBg:SetAllPoints()
                    btnBg:SetColorTexture(0.2, 0.2, 0.2, 0.8)
                    
                    local btnText = btn:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
                    btnText:SetPoint("LEFT", 5, 0)
                    btnText:SetText(outline.name)
                    
                    if outline.value == currentValue then
                        btnText:SetTextColor(1, 0.82, 0, 1)
                    else
                        btnText:SetTextColor(1, 1, 1, 1)
                    end
                    
                    btn:SetScript("OnEnter", function() btnBg:SetColorTexture(0.4, 0.4, 0.4, 1) end)
                    btn:SetScript("OnLeave", function() btnBg:SetColorTexture(0.2, 0.2, 0.2, 0.8) end)
                    btn:SetScript("OnClick", function()
                        SetValue(PCB.db, dbKey, outline.value)
                        text:SetText(outline.name)
                        menu:Hide()
                        if PCB.ApplyAll then PCB:ApplyAll() end
                    end)
                    
                    table.insert(menuButtons, btn)
                end
                
                menu:SetHeight(math.max(40, 20 + #outlines * 20))
            end
            
            local function ToggleMenu()
                UpdateOutlineDropdown()
                if menu:IsShown() then menu:Hide() else menu:Show() end
            end
            
            dropdown:SetScript("OnClick", ToggleMenu)
            arrowBtn:SetScript("OnClick", ToggleMenu)
            
            UpdateOutlineDropdown()

            -- expose internals for external control
            container.dropdown = dropdown
            container.arrowBtn = arrowBtn
            container.text = text
            container.option = option

            -- Apply disabledIf if present
            if option.disabledIf then
                local isDisabled = false
                local ok, res = pcall(option.disabledIf)
                if ok then isDisabled = res end
                dropdown:EnableMouse(not isDisabled)
                arrowBtn:EnableMouse(not isDisabled)
                dropdown:SetAlpha(isDisabled and 0.5 or 1)
                text:SetTextColor(isDisabled and 0.5 or 1, isDisabled and 0.5 or 1, isDisabled and 0.5 or 1, 1)
            end

            return container
        end
        
        -- Helper function to add spacing
        local function AddSpace(parent, y)
            -- Just return a dummy frame for tracking
            local space = CreateFrame("Frame", nil, parent)
            space:SetHeight(1)
            return space
        end
        
        -- Helper function to add a 2-column grid layout for mixed widgets
        local function AddTwoColumnGrid(parent, y, items)
            local container = CreateFrame("Frame", nil, parent)
            container:SetPoint("TOPLEFT", 10, y)
            container:SetSize(480, 100)  -- Will be adjusted based on content
            
            local maxHeight = 0
            local rowHeight = 0
            local currentRow = 0
            
            for i, item in ipairs(items) do
                local col = ((i - 1) % 2)  -- 0 for left column, 1 for right column
                local row = math.floor((i - 1) / 2)
                
                if row ~= currentRow then
                    currentRow = row
                    maxHeight = maxHeight + rowHeight + 10  -- Add row spacing
                    rowHeight = 0
                end
                
                local xOffset = col * 240  -- 240px spacing between columns
                local yOffset = -maxHeight
                
                if item.type == "lsmdropdown" then
                    -- Create LSM dropdown
                    local LSM = PCB.LSM
                    if LSM then
                        local label = container:CreateFontString(nil, "OVERLAY", "GameFontNormal")
                        label:SetPoint("TOPLEFT", xOffset, yOffset)
                        label:SetWidth(220)
                        label:SetText(item.label)
                        
                        local dropdown = CreateFrame("Button", nil, container)
                        dropdown:SetWidth(220)
                        dropdown:SetHeight(24)
                        dropdown:SetPoint("TOPLEFT", xOffset, yOffset - 20)
                        
                        -- Background
                        local bg = dropdown:CreateTexture(nil, "BACKGROUND")
                        bg:SetAllPoints()
                        bg:SetColorTexture(0.15, 0.15, 0.15, 1)
                        
                        -- Border
                        local border = dropdown:CreateTexture(nil, "ARTWORK")
                        border:SetPoint("TOPLEFT", 1, -1)
                        border:SetPoint("BOTTOMRIGHT", -1, 1)
                        border:SetColorTexture(0.25, 0.25, 0.25, 1)
                        
                        -- Text
                        local text = dropdown:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
                        text:SetPoint("LEFT", 8, 0)
                        text:SetPoint("RIGHT", -20, 0)
                        text:SetJustifyH("LEFT")
                        text:SetTextColor(1, 1, 1, 1)
                        
                        -- Arrow button
                        local arrowBtn = CreateFrame("Button", nil, dropdown)
                        arrowBtn:SetSize(16, 16)
                        arrowBtn:SetPoint("RIGHT", -4, 0)
                        arrowBtn:SetNormalTexture("Interface\\ChatFrame\\UI-ChatIcon-ScrollDown-Up")
                        arrowBtn:SetPushedTexture("Interface\\ChatFrame\\UI-ChatIcon-ScrollDown-Down")
                        arrowBtn:SetHighlightTexture("Interface\\Buttons\\UI-Common-MouseHilight", "ADD")
                        
                        -- Highlight
                        dropdown:SetScript("OnEnter", function()
                            border:SetColorTexture(0.35, 0.35, 0.35, 1)
                        end)
                        dropdown:SetScript("OnLeave", function()
                            border:SetColorTexture(0.25, 0.25, 0.25, 1)
                        end)
                        
                        -- Get current value
                        local currentValue = GetValue(PCB.db, item.key)
                        local mediaList = LSM:List(item.mediaType)
                        
                        -- Find current selection
                        for _, mediaName in ipairs(mediaList) do
                            if currentValue == mediaName then
                                text:SetText(mediaName)
                                break
                            end
                        end
                        
                        if text:GetText() == "" then
                            text:SetText(mediaList[1] or "None")
                        end
                        
                        -- Create menu for dropdown
                        local menu = CreateFrame("ScrollFrame", nil, dropdown)
                        menu:SetFrameStrata("HIGH")
                        menu:SetSize(220, 240)
                        menu:SetPoint("TOP", dropdown, "BOTTOM", 0, -4)
                        menu:Hide()
                        
                        local menuChild = CreateFrame("Frame", nil, menu)
                        menuChild:SetWidth(200)
                        menu:SetScrollChild(menuChild)
                        
                        local menuBg = menu:CreateTexture(nil, "BACKGROUND")
                        menuBg:SetAllPoints(menu)
                        menuBg:SetColorTexture(0.1, 0.1, 0.1, 0.95)
                        
                        local menuButtons = {}
                        
                        local function UpdateLSMDropdown()
                            -- Clear old buttons
                            for _, btn in ipairs(menuButtons) do
                                btn:Hide()
                                btn:SetParent(nil)
                            end
                            menuButtons = {}
                            
                            local mediaList = LSM:List(item.mediaType)
                            local currentValue = GetValue(PCB.db, item.key)
                            
                            local itemHeight = (item.mediaType == "statusbar") and 30 or 24
                            local totalHeight = #mediaList * itemHeight
                            menuChild:SetHeight(math.max(totalHeight, 240))
                            
                            for i, mediaName in ipairs(mediaList) do
                                local btn = CreateFrame("Button", nil, menuChild)
                                btn:SetWidth(200)
                                btn:SetHeight(itemHeight)
                                btn:SetPoint("TOP", menuChild, "TOP", 0, -(i-1) * itemHeight)
                                
                                if item.mediaType == "statusbar" then
                                    -- Texture preview
                                    local preview = btn:CreateTexture(nil, "ARTWORK")
                                    preview:SetPoint("TOPLEFT", 5, -5)
                                    preview:SetPoint("BOTTOMRIGHT", -5, 5)
                                    preview:SetTexture(LSM:Fetch("statusbar", mediaName))
                                    preview:SetVertexColor(0.3, 0.6, 1)
                                    
                                    local previewText = btn:CreateFontString(nil, "OVERLAY", "GameFontNormal")
                                    previewText:SetPoint("CENTER", preview, "CENTER")
                                    previewText:SetText(mediaName)
                                    previewText:SetTextColor(1, 1, 1, 1)
                                elseif item.mediaType == "font" then
                                    -- Font preview
                                    local fontPath = LSM:Fetch("font", mediaName)
                                    local fontText = btn:CreateFontString(nil, "OVERLAY")
                                    fontText:SetFont(fontPath, 12)
                                    fontText:SetPoint("LEFT", 10, 0)
                                    fontText:SetText(mediaName)
                                    fontText:SetTextColor(1, 1, 1, 1)
                                end
                                
                                -- Highlight
                                local highlight = btn:CreateTexture(nil, "BACKGROUND")
                                highlight:SetAllPoints()
                                if mediaName == currentValue then
                                    highlight:SetColorTexture(0.3, 0.5, 0.7, 0.5)
                                else
                                    highlight:SetColorTexture(0.2, 0.2, 0.2, 0.5)
                                end
                                
                                btn:SetScript("OnEnter", function()
                                    highlight:SetColorTexture(0.4, 0.6, 0.8, 0.5)
                                end)
                                btn:SetScript("OnLeave", function()
                                    if mediaName == GetValue(PCB.db, item.key) then
                                        highlight:SetColorTexture(0.3, 0.5, 0.7, 0.5)
                                    else
                                        highlight:SetColorTexture(0.2, 0.2, 0.2, 0.5)
                                    end
                                end)
                                
                                btn:SetScript("OnClick", function()
                                    SetValue(PCB.db, item.key, mediaName)
                                    text:SetText(mediaName)
                                    menu:Hide()
                                    UpdateLSMDropdown()
                                    if PCB.ApplyAll then PCB:ApplyAll() end
                                end)
                                
                                table.insert(menuButtons, btn)
                            end
                        end
                        
                        local function ToggleLSMMenu()
                            if menu:IsShown() then
                                menu:Hide()
                            else
                                UpdateLSMDropdown()
                                menu:Show()
                            end
                        end
                        
                        dropdown:SetScript("OnClick", ToggleLSMMenu)
                        arrowBtn:SetScript("OnClick", ToggleLSMMenu)
                        
                        menu:EnableMouseWheel(true)
                        menu:SetScript("OnMouseWheel", function(self, delta)
                            local current = self:GetVerticalScroll()
                            local maxScroll = menuChild:GetHeight() - self:GetHeight()
                            local newScroll = math.max(0, math.min(maxScroll, current - (delta * 20)))
                            self:SetVerticalScroll(newScroll)
                        end)
                        
                        rowHeight = math.max(rowHeight, 50)
                    end
                    
                elseif item.type == "outlinedropdown" then
                    -- Create outline dropdown
                    local label = container:CreateFontString(nil, "OVERLAY", "GameFontNormal")
                    label:SetPoint("TOPLEFT", xOffset, yOffset)
                    label:SetWidth(220)
                    label:SetText(item.label)
                    
                    local dropdown = CreateFrame("Button", nil, container)
                    dropdown:SetWidth(220)
                    dropdown:SetHeight(24)
                    dropdown:SetPoint("TOPLEFT", xOffset, yOffset - 20)
                    
                    -- Background
                    local bg = dropdown:CreateTexture(nil, "BACKGROUND")
                    bg:SetAllPoints()
                    bg:SetColorTexture(0.15, 0.15, 0.15, 1)
                    
                    -- Border
                    local border = dropdown:CreateTexture(nil, "ARTWORK")
                    border:SetPoint("TOPLEFT", 1, -1)
                    border:SetPoint("BOTTOMRIGHT", -1, 1)
                    border:SetColorTexture(0.25, 0.25, 0.25, 1)
                    
                    -- Text
                    local text = dropdown:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
                    text:SetPoint("LEFT", 8, 0)
                    text:SetPoint("RIGHT", -20, 0)
                    text:SetJustifyH("LEFT")
                    text:SetTextColor(1, 1, 1, 1)
                    
                    -- Arrow button
                    local arrowBtn = CreateFrame("Button", nil, dropdown)
                    arrowBtn:SetSize(16, 16)
                    arrowBtn:SetPoint("RIGHT", -4, 0)
                    arrowBtn:SetNormalTexture("Interface\\ChatFrame\\UI-ChatIcon-ScrollDown-Up")
                    arrowBtn:SetPushedTexture("Interface\\ChatFrame\\UI-ChatIcon-ScrollDown-Down")
                    arrowBtn:SetHighlightTexture("Interface\\Buttons\\UI-Common-MouseHilight", "ADD")
                    
                    -- Highlight
                    dropdown:SetScript("OnEnter", function()
                        border:SetColorTexture(0.35, 0.35, 0.35, 1)
                    end)
                    dropdown:SetScript("OnLeave", function()
                        border:SetColorTexture(0.25, 0.25, 0.25, 1)
                    end)
                    
                    local outlineOptions = {"", "OUTLINE", "THICKOUTLINE"}
                    local outlineLabels = {"None", "Outline", "Thick Outline"}
                    
                    local currentValue = GetValue(PCB.db, item.key) or ""
                    for i, val in ipairs(outlineOptions) do
                        if val == currentValue then
                            text:SetText(outlineLabels[i])
                            break
                        end
                    end
                    
                    -- Create menu
                    local menu = CreateFrame("Frame", nil, dropdown)
                    menu:SetFrameStrata("HIGH")
                    menu:SetSize(220, 80)
                    menu:SetPoint("TOP", dropdown, "BOTTOM", 0, -4)
                    menu:Hide()
                    
                    local menuBg = menu:CreateTexture(nil, "BACKGROUND")
                    menuBg:SetAllPoints(menu)
                    menuBg:SetColorTexture(0.1, 0.1, 0.1, 0.95)
                    
                    for i, val in ipairs(outlineOptions) do
                        local btn = CreateFrame("Button", nil, menu)
                        btn:SetWidth(200)
                        btn:SetHeight(24)
                        btn:SetPoint("TOP", menu, "TOP", 0, -4 - (i-1) * 24)
                        
                        local btnText = btn:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
                        btnText:SetPoint("LEFT", 10, 0)
                        btnText:SetText(outlineLabels[i])
                        
                        local highlight = btn:CreateTexture(nil, "BACKGROUND")
                        highlight:SetAllPoints()
                        if val == currentValue then
                            highlight:SetColorTexture(0.3, 0.5, 0.7, 0.5)
                        else
                            highlight:SetColorTexture(0.2, 0.2, 0.2, 0.5)
                        end
                        
                        btn:SetScript("OnEnter", function()
                            highlight:SetColorTexture(0.4, 0.6, 0.8, 0.5)
                        end)
                        btn:SetScript("OnLeave", function()
                            if val == GetValue(PCB.db, item.key) then
                                highlight:SetColorTexture(0.3, 0.5, 0.7, 0.5)
                            else
                                highlight:SetColorTexture(0.2, 0.2, 0.2, 0.5)
                            end
                        end)
                        
                        btn:SetScript("OnClick", function()
                            SetValue(PCB.db, item.key, val)
                            text:SetText(outlineLabels[i])
                            menu:Hide()
                            if PCB.ApplyAll then PCB:ApplyAll() end
                        end)
                    end
                    
                    local function ToggleOutlineMenu()
                        if menu:IsShown() then menu:Hide() else menu:Show() end
                    end
                    
                    dropdown:SetScript("OnClick", ToggleOutlineMenu)
                    arrowBtn:SetScript("OnClick", ToggleOutlineMenu)
                    
                    rowHeight = math.max(rowHeight, 50)
                    
                elseif item.type == "slider" then
                    -- Create slider
                    local slider = CreateFrame("Slider", nil, container, "OptionsSliderTemplate")
                    slider:SetWidth(220)
                    slider:SetHeight(20)
                    slider:SetPoint("TOPLEFT", xOffset, yOffset)
                    slider:SetMinMaxValues(item.min, item.max)
                    slider:SetValueStep(item.step)
                    slider:SetObeyStepOnDrag(true)
                    
                    if slider.Low then slider.Low:SetText(tostring(item.min)) end
                    if slider.High then slider.High:SetText(tostring(item.max)) end
                    
                    local labelText = slider:CreateFontString(nil, "OVERLAY", "GameFontNormal")
                    labelText:SetPoint("BOTTOMLEFT", slider, "TOPLEFT", 0, 2)
                    labelText:SetText(item.label)
                    
                    local valueText = slider:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
                    valueText:SetPoint("BOTTOMRIGHT", slider, "TOPRIGHT", 0, 2)
                    
                    local currentValue = GetValue(PCB.db, item.key) or item.min
                    slider:SetValue(currentValue)
                    valueText:SetText(string.format("%.2f", currentValue))
                    
                    slider:SetScript("OnValueChanged", function(self, value)
                        value = math.floor(value / item.step + 0.5) * item.step
                        SetValue(PCB.db, item.key, value)
                        valueText:SetText(string.format("%.2f", value))
                        if PCB.ApplyAll then PCB:ApplyAll() end
                    end)
                    
                    rowHeight = math.max(rowHeight, 50)
                    
                elseif item.type == "checkbox" then
                    -- Create checkbox
                    local cb = CreateFrame("CheckButton", nil, container, "UICheckButtonTemplate")
                    cb:SetPoint("TOPLEFT", xOffset, yOffset)
                    
                    local text = cb:CreateFontString(nil, "OVERLAY", "GameFontNormal")
                    text:SetPoint("LEFT", cb, "RIGHT", 5, 0)
                    text:SetText(item.label)
                    
                    cb:SetChecked(GetValue(PCB.db, item.key) or false)
                    cb:SetScript("OnClick", function(self)
                        SetValue(PCB.db, item.key, self:GetChecked())
                        if PCB.ApplyAll then PCB:ApplyAll() end
                        if optionsFrame and optionsFrame.UpdateContent then optionsFrame.UpdateContent(selectedCategory) end
                    end)
                    
                    rowHeight = math.max(rowHeight, 25)
                end
            end
            
            -- Final height calculation
            maxHeight = maxHeight + rowHeight + 10
            container:SetHeight(maxHeight)
            
            return container
        end
        
        -- Function to update content when category is clicked
        local function UpdateContent(categoryKey)
            -- Clear previous content widgets
            for _, widget in ipairs(optionsFrame.contentWidgets) do
                if widget.Hide then
                    widget:Hide()
                    widget:SetParent(nil)
                end
            end
            optionsFrame.contentWidgets = {}
            
            selectedCategory = categoryKey
            local category = categories[categoryKey]
            
            if category then
                -- Add category title
                local catTitle = scrollContent:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
                catTitle:SetPoint("TOPLEFT", 10, -10)
                catTitle:SetText(category.name)
                table.insert(optionsFrame.contentWidgets, catTitle)
                
                -- Add options for this category
                local y = -40
                local opts = category.options
                local i = 1
                while i <= #opts do
                    local option = opts[i]
                    local widget

                    -- Evaluate visibleIf if provided; skip this option entirely if it returns false
                    local show = true
                    if option.visibleIf then
                        local ok, val = pcall(option.visibleIf)
                        if ok then show = val else show = false end
                    end

                    -- Inline checkbox + dropdown: if this option is a checkbox and the next option
                    -- is an lsm/outline dropdown with an empty label, render them on one row.
                    local inlined = false
                    local nextOpt = opts[i+1]
                    if show and option.type == "checkbox" and nextOpt and (nextOpt.type == "lsmdropdown" or nextOpt.type == "outlinedropdown") and (nextOpt.label == nil or nextOpt.label == "") then
                        -- Evaluate visibility of nextOpt as well
                        local nextShow = true
                        if nextOpt.visibleIf then
                            local ok2, val2 = pcall(nextOpt.visibleIf)
                            if ok2 then nextShow = val2 else nextShow = false end
                        end
                        if nextShow then
                            -- Create checkbox (returns the CheckButton)
                            local cb = AddCheckbox(scrollContent, option.label, option.key, y, option.isProfileMode)
                            widget = cb
                            table.insert(optionsFrame.contentWidgets, widget)

                            -- Create inline dropdown using existing helper, then reposition and hide its label
                            local dropdownContainer
                            if nextOpt.type == "lsmdropdown" then
                                dropdownContainer = AddLSMDropdown(scrollContent, nextOpt, y)
                            else
                                dropdownContainer = AddOutlineDropdown(scrollContent, nextOpt, y)
                            end
                            -- Position the dropdown to the right of the checkbox
                            dropdownContainer:ClearAllPoints()
                            dropdownContainer:SetPoint("TOPLEFT", cb, "TOPRIGHT", 100, 0)
                            if dropdownContainer.labelText then dropdownContainer.labelText:Hide() end
                            table.insert(optionsFrame.contentWidgets, dropdownContainer)

                            -- Advance past the next option since we've handled it inline
                            inlined = true
                            i = i + 2
                            y = y - 35
                        else
                            -- nextOpt not shown; fall through to normal checkbox handling
                        end
                    end

                    if not inlined then
                        if not show then
                            -- skip creating this widget and do not advance y
                        else
                        if option.type == "description" then
                            widget = AddDescription(scrollContent, option.text, y)
                            y = y - (widget:GetHeight() + 10)
                        elseif option.type == "label" then
                            widget = AddLabel(scrollContent, option.text, y, option.getValue)
                            y = y - 25
                        elseif option.type == "button" then
                            widget = AddButton(scrollContent, option.label, y, option.onClick)
                            y = y - 35
                        elseif option.type == "editbox" then
                            widget = AddEditBox(scrollContent, option.label, y, option.placeholder)
                            y = y - 35
                        elseif option.type == "dropdown" then
                            widget = AddDropdown(scrollContent, option.label, y, option.key)
                            y = y - 35
                        elseif option.type == "lsmdropdown" then
                            widget = AddLSMDropdown(scrollContent, option, y)
                            y = y - 35
                        elseif option.type == "outlinedropdown" then
                            widget = AddOutlineDropdown(scrollContent, option, y)
                            y = y - 35
                        elseif option.type == "checkboxpair" then
                            widget = AddCheckboxPair(scrollContent, option.label1, option.key1, option.label2, option.key2, y)
                            y = y - 35
                        elseif option.type == "checkboxbutton" then
                            widget = AddCheckboxButton(scrollContent, option.label, option.key, option.buttonLabel, option.onClick, y)
                            y = y - 35
                        elseif option.type == "space" then
                            widget = AddSpace(scrollContent, y)
                            y = y - 15
                        elseif option.type == "slidergrid" then
                            widget = AddSliderGrid(scrollContent, y, option.sliders)
                            y = y - 130
                        elseif option.type == "twocolumngrid" then
                            widget = AddTwoColumnGrid(scrollContent, y, option.items)
                            y = y - (widget:GetHeight() + 10)
                        elseif option.type == "slider" then
                            widget = AddSlider(scrollContent, option.label, option.key, y, option.min, option.max, option.step)
                            y = y - 65
                        elseif option.type == "colorpicker" then
                            widget = AddColorPicker(scrollContent, option.label, option.key, y)
                            y = y - 40
                        elseif option.type == "colorpickergrid" then
                            widget = AddColorPickerGrid(scrollContent, y, option.pickers)
                            y = y - (widget:GetHeight() + 10)
                        elseif option.type == "checkbox" then
                            widget = AddCheckbox(scrollContent, option.label, option.key, y, option.isProfileMode)
                            y = y - 35
                        end
                        end
                        if widget then
                            table.insert(optionsFrame.contentWidgets, widget)
                        end
                        i = i + 1
                    end
                end
                
                -- Set scroll content height dynamically based on content
                local contentHeight = math.abs(y) + 20
                scrollContent:SetHeight(math.max(contentHeight, 500))
                scrollFrame:SetVerticalScroll(0)
            end
        end
        
        -- Create category buttons in sidebar (in specific order)
        -- Expose UpdateContent on the optionsFrame so other handlers can trigger a refresh
        optionsFrame.UpdateContent = UpdateContent
        local categoryOrder = {"general", "player", "target", "focus", "profiles"}
        local catY = -10
        for _, catKey in ipairs(categoryOrder) do
            local catData = categories[catKey]
            if catData then
                local btn = CreateFrame("Button", nil, sidebar)
                btn:SetWidth(130)
                btn:SetHeight(25)
                btn:SetPoint("TOPLEFT", 10, catY)
                
                -- Create FontString manually
                local btnText = btn:CreateFontString(nil, "OVERLAY", "GameFontNormal")
                btnText:SetPoint("LEFT", btn, "LEFT", 5, 0)
                btnText:SetText(catData.name)
                btnText:SetTextColor(1, 1, 1)
                btn.__text = btnText
                
                btn:SetScript("OnEnter", function()
                    btnText:SetTextColor(0.7, 0.9, 1)
                end)
                
                btn:SetScript("OnLeave", function()
                    if selectedCategory == catKey then
                        btnText:SetTextColor(0.5, 0.8, 1)
                    else
                        btnText:SetTextColor(1, 1, 1)
                    end
                end)
                
                btn:SetScript("OnClick", function()
                    UpdateContent(catKey)
                    -- Update button text colors
                    for btnKey, btnRef in pairs(optionsFrame.categoryButtons) do
                        if btnKey == catKey then
                            btnRef.btn.__text:SetTextColor(0.5, 0.8, 1)
                        else
                            btnRef.btn.__text:SetTextColor(1, 1, 1)
                        end
                    end
                end)
                
                optionsFrame.categoryButtons[catKey] = { btn = btn }
                
                catY = catY - 30
            end
        end
        
        -- Load initial category
        UpdateContent("general")
        
        -- Highlight the initial selected button (safely)
        if optionsFrame.categoryButtons and optionsFrame.categoryButtons.general then
            optionsFrame.categoryButtons.general.btn.__text:SetTextColor(0.5, 0.8, 1)
        end
    end
    
    optionsFrame:Show()
end




>>>>>>> 9671a60 (Release v0.3.4 / update files)
