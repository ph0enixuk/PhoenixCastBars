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
    self._inited = true
end

function Options:Open()
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
