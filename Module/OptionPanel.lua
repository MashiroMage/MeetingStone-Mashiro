-- OptionPanel.lua
-- Custom settings panel - hand-written UI, no AceConfigDialog dependency

BuildEnv(...)

SettingPanel = Addon:NewModule(CreateFrame('Frame', nil, MainPanel), 'SettingPanel', 'AceEvent-3.0', 'AceTimer-3.0')

local BINDING_KEY = 'MEETINGSTONE_TOGGLE'
local IsAddOnLoaded = C_AddOns and C_AddOns.IsAddOnLoaded or IsAddOnLoaded

-- =====================================================================
-- Layout helper: stacks widgets top-to-bottom inside a parent frame
-- =====================================================================
local function NewLayout(parent, paddingLeft, paddingRight)
    local pL = paddingLeft or 0
    local pR = paddingRight or 0
    local y   = 0
    local obj = {}

    -- Section header with separator line
    function obj:Section(title)
        if y < 0 then y = y - 6 end

        local line = parent:CreateTexture(nil, 'BACKGROUND')
        line:SetPoint('TOPLEFT',  pL, y)
        line:SetPoint('TOPRIGHT', pR, y)
        line:SetHeight(1)
        line:SetColorTexture(1, 0.82, 0, 0.35)

        local fs = parent:CreateFontString(nil, 'ARTWORK', 'GameFontNormal')
        fs:SetTextColor(1, 0.82, 0)
        fs:SetPoint('TOPLEFT', pL + 2, y - 3)
        fs:SetText(title)
        y = y - 20
    end

    -- Native CheckButton toggle; returns the CheckButton widget
    function obj:Toggle(label, getter, setter, indent)
        local ind = indent or 0

        local cb = CreateFrame('CheckButton', nil, parent)
        cb:SetSize(18, 18)
        cb:SetPoint('TOPLEFT', pL + ind, y)
        cb:SetNormalTexture([[Interface\Buttons\UI-CheckBox-Up]])
        cb:SetPushedTexture([[Interface\Buttons\UI-CheckBox-Down]])
        cb:SetHighlightTexture([[Interface\Buttons\UI-CheckBox-Highlight]])
        cb:SetCheckedTexture([[Interface\Buttons\UI-CheckBox-Check]])
        cb:SetDisabledCheckedTexture([[Interface\Buttons\UI-CheckBox-Check-Disabled]])

        local fs = parent:CreateFontString(nil, 'ARTWORK', 'GameFontHighlightSmall')
        fs:SetPoint('LEFT', cb, 'RIGHT', 3, 0)
        fs:SetText(label)
        cb:SetFontString(fs)
        cb:SetChecked(getter())
        cb:SetScript('OnClick', function(self) setter(self:GetChecked()) end)

        y = y - 20
        return cb
    end

    -- Slider with label on top and value display; returns the Slider widget
    function obj:Slider(label, minVal, maxVal, step, getter, setter)
        local lbl = parent:CreateFontString(nil, 'ARTWORK', 'GameFontHighlightSmall')
        lbl:SetPoint('TOPLEFT', pL, y)
        lbl:SetText(label)
        y = y - 14

        local slider = CreateFrame('Slider', nil, parent, 'OptionsSliderTemplate')
        slider:SetPoint('TOPLEFT', pL + 8, y)
        slider:SetPoint('TOPRIGHT', pR - 8, y)
        slider:SetHeight(18)
        slider:SetMinMaxValues(minVal, maxVal)
        slider:SetValueStep(step)
        slider:SetObeyStepOnDrag(true)

        local curVal = getter()
        slider:SetValue(curVal)
        slider.Low:SetText(tostring(minVal))
        slider.High:SetText(tostring(maxVal))
        slider.Text:SetText(format('%.1f', curVal))

        slider:SetScript('OnValueChanged', function(self, value)
            local rounded = math.floor(value / step + 0.5) * step
            rounded = math.floor(rounded * 10 + 0.5) / 10
            self.Text:SetText(format('%.1f', rounded))
            setter(rounded)
        end)

        y = y - 36
        return slider
    end

    -- Keybinding row: label + button capturing keypress; returns the Button widget
    function obj:KeyBinding(label, getKey)
        local lbl = parent:CreateFontString(nil, 'ARTWORK', 'GameFontHighlightSmall')
        lbl:SetPoint('TOPLEFT', pL, y - 2)
        lbl:SetText(label)

        local btn = CreateFrame('Button', nil, parent, 'UIPanelButtonTemplate')
        btn:SetSize(120, 22)
        btn:SetPoint('LEFT', lbl, 'RIGHT', 6, 0)

        local function updateText()
            local key = getKey()
            btn:SetText(key and GetBindingText(key) or L['未绑定'])
        end
        updateText()

        btn:SetScript('OnClick', function(self)
            self:SetText('...')
            self:EnableKeyboard(true)
            self:SetPropagateKeyboardInput(false)
            self:SetScript('OnKeyDown', function(self, key)
                if key == 'LSHIFT' or key == 'RSHIFT' or key == 'LCTRL' or key == 'RCTRL'
                   or key == 'LALT' or key == 'RALT' then
                    return
                end
                if key == 'ESCAPE' then
                    self:SetScript('OnKeyDown', nil)
                    self:EnableKeyboard(false)
                    updateText()
                    return
                end
                local fullKey = (IsShiftKeyDown() and 'SHIFT-' or '')
                             .. (IsControlKeyDown() and 'CTRL-' or '')
                             .. (IsAltKeyDown() and 'ALT-' or '')
                             .. key
                local action = GetBindingAction(fullKey)
                local function doSet()
                    for _, k in ipairs({ GetBindingKey(BINDING_KEY) }) do
                        SetBinding(k, nil)
                    end
                    SetBinding(fullKey, BINDING_KEY)
                    SaveBindings(GetCurrentBindingSet())
                end
                self:SetScript('OnKeyDown', nil)
                self:EnableKeyboard(false)
                if action ~= '' and action ~= BINDING_KEY then
                    local bindName = _G['BINDING_NAME_' .. action] or action
                    GUI:CallMessageDialog(
                        L['按键已绑定到|cffffd100%s|r，你确定要覆盖吗？']:format(bindName),
                        function(result) if result then doSet() end updateText() end)
                else
                    doSet()
                    updateText()
                end
            end)
        end)

        y = y - 24
        return btn
    end

    -- Full-width button row; returns the Button widget
    function obj:Button(label, onClick, confirmMsg)
        local btn = CreateFrame('Button', nil, parent, 'UIPanelButtonTemplate')
        btn:SetHeight(22)
        btn:SetPoint('TOPLEFT', pL, y)
        btn:SetPoint('TOPRIGHT', pR, y)
        btn:SetText(label)
        btn:SetScript('OnClick', function()
            if confirmMsg then
                GUI:CallMessageDialog(confirmMsg, function(result)
                    if result then onClick() end
                end)
            else
                onClick()
            end
        end)
        y = y - 26
        return btn
    end

    function obj:Space(h) y = y - (h or 4) end
    function obj:GetY()   return y end

    return obj
end

-- =====================================================================
-- Module Init
-- =====================================================================
function SettingPanel:OnInitialize()
    GUI:Embed(self, 'Owner')
    if not NO_SCAN_WORD then
        MainPanel:RegisterPanel(L['设置'], self, 3, 60, 1)
    else
        MainPanel:RegisterPanel(L['设置'], self, 3)
    end

    self.db = Profile:GetCharacterDB()

    -- ----------------------------------------------------------------
    -- Left column: main options (inside a scroll frame)
    -- ----------------------------------------------------------------
    local scrollContainer = CreateFrame('Frame', nil, self)
    if not NO_SCAN_WORD then
        scrollContainer:SetPoint('TOPLEFT', 10, -10)
        scrollContainer:SetPoint('BOTTOM', 0, 10)
        scrollContainer:SetPoint('RIGHT', self, 'CENTER', -5, 0)
    else
        scrollContainer:SetPoint('TOP', 0, -10)
        scrollContainer:SetPoint('BOTTOM', 0, 10)
        scrollContainer:SetWidth(420)
    end

    local scrollFrame = CreateFrame('ScrollFrame', nil, scrollContainer, 'UIPanelScrollFrameTemplate')
    scrollFrame:SetAllPoints(scrollContainer)

    local optFrame = CreateFrame('Frame', nil, scrollFrame)
    scrollFrame:SetScrollChild(optFrame)

    -- Keep scroll child width in sync with the scroll frame (minus scroll bar)
    local function syncOptWidth(sf)
        local w = sf:GetWidth()
        if w > 20 then optFrame:SetWidth(w - 20) end
    end
    scrollFrame:HookScript('OnSizeChanged', syncOptWidth)
    syncOptWidth(scrollFrame)

    local layout = NewLayout(optFrame, 0, 0)

    -- 外观
    layout:Section(L['外观'])

    layout:Toggle(L['显示小地图图标'],
        function() return not self.db.profile.minimap.hide end,
        function(v)
            self.db.profile.minimap.hide = not v
            if v then LibStub('LibDBIcon-1.0'):Show('MeetingStone')
            else      LibStub('LibDBIcon-1.0'):Hide('MeetingStone') end
        end)

    local classicoCb = layout:Toggle(L['显示职业图标'] .. ' |cffff8040[重载]|r',
        function() return Profile:GetGlobalOption('showclassico') end,
        function(v)
            if Profile:SaveGlobalOption('showclassico', v) then
                GUI:CallWarningDialog(L['需要重载UI！'], true, nil, ReloadUI)
            end
        end)

    local showspecicoCb = layout:Toggle(L['显示专精图标'],
        function() return Profile:GetGlobalOption('showspecico') end,
        function(v) Profile:SaveGlobalOption('showspecico', v) end,
        16)

    local showSmRoleIcoCb = layout:Toggle(L['显示小职责图标'],
        function() return Profile:GetGlobalOption('showSmRoleIco') end,
        function(v) Profile:SaveGlobalOption('showSmRoleIco', v) end,
        16)

    local classIcoMsOnlyCb = layout:Toggle(L['只在集合石上显示职业图标'] .. ' |cffff8040[重载]|r',
        function() return Profile:GetGlobalOption('classIcoMsOnly') end,
        function(v)
            if Profile:SaveGlobalOption('classIcoMsOnly', v) then
                GUI:CallWarningDialog(L['需要重载UI！'], true, nil, ReloadUI)
            end
        end,
        16)

    local function updateClassicoSubs()
        local enabled = Profile:GetGlobalOption('showclassico')
        showspecicoCb:SetEnabled(enabled)
        showSmRoleIcoCb:SetEnabled(enabled)
        classIcoMsOnlyCb:SetEnabled(enabled)
    end
    classicoCb:HookScript('OnClick', function() updateClassicoSubs() end)
    updateClassicoSubs()

    layout:Toggle(L['显示队长职业颜色'],
        function() return Profile:GetGlobalOption('enableLeaderColor') end,
        function(v) Profile:SaveGlobalOption('enableLeaderColor', v) end)

    if RaiderIO then
        layout:Toggle(L['显示RaiderIO数据'],
            function() return Profile:GetGlobalOption('enableRaiderIO') end,
            function(v) Profile:SaveGlobalOption('enableRaiderIO', v) end)
    end

    if IsAddOnLoaded('ElvUI_WindTools') then
        layout:Toggle(L['显示Wind职业图标'] .. ' |cffff8040[重载]|r',
            function() return Profile:GetGlobalOption('showWindClassIco') end,
            function(v)
                if Profile:SaveGlobalOption('showWindClassIco', v) then
                    GUI:CallWarningDialog(L['需要重载UI！'], true, nil, ReloadUI)
                end
            end)

        layout:Toggle(L['使用Wind皮肤'] .. ' |cffff8040[重载]|r',
            function() return Profile:GetGlobalOption('useWindSkin') end,
            function(v)
                if Profile:SaveGlobalOption('useWindSkin', v) then
                    GUI:CallWarningDialog(L['需要重载UI！'], true, nil, ReloadUI)
                end
            end)
    end

    if IsAddOnLoaded('NDui_Plus') then
        layout:Toggle(L['使用NDui皮肤增强'] .. ' |cffff8040[重载]|r',
            function() return Profile:GetGlobalOption('useNDuiSkin') end,
            function(v)
                if Profile:SaveGlobalOption('useNDuiSkin', v) then
                    GUI:CallWarningDialog(L['需要重载UI！'], true, nil, ReloadUI)
                end
            end)
    end

    -- 悬浮窗
    layout:Section(L['悬浮窗'])

    local panelCb = layout:Toggle(L['显示悬浮窗'],
        function() return Profile:GetSetting('panel') end,
        function(v) Profile:SetSetting('panel', v) end)

    local panelLockCb = layout:Toggle(L['锁定悬浮窗'],
        function() return Profile:GetSetting('panelLock') end,
        function(v) Profile:SetSetting('panelLock', v) end)

    local globalPosCb = layout:Toggle(L['悬浮窗位置全角色统一'] .. ' |cffff8040[重载]|r',
        function() return Profile:GetGlobalOption('globalPanelPos') end,
        function(v)
            if Profile:SaveGlobalOption('globalPanelPos', v) then
                GUI:CallWarningDialog(L['需要重载UI！'], true, nil, ReloadUI)
            end
        end)

    local function updatePanelSubs()
        local enabled = Profile:GetSetting('panel')
        panelLockCb:SetEnabled(enabled)
        globalPosCb:SetEnabled(enabled)
    end
    panelCb:HookScript('OnClick', function() updatePanelSubs() end)
    updatePanelSubs()

    -- 功能
    layout:Section(L['功能'])

    layout:Toggle(L['启用活动申请提示音'],
        function() return Profile:GetSetting('sound') end,
        function(v) Profile:SetSetting('sound', v) end)

    layout:Toggle(L['活动类型过滤器整合PvP活动'],
        function() return Profile:GetSetting('packedPvp') end,
        function(v) Profile:SetSetting('packedPvp', v) end)

    layout:Toggle(L['启用同标题屏蔽'],
        function() return Profile:GetGlobalOption('enableIgnoreTitle') end,
        function(v) Profile:SaveGlobalOption('enableIgnoreTitle', v) end)

    -- 工具
    layout:Section(L['工具'])

    layout:KeyBinding(L['打开/关闭集合石组团按键设置'],
        function() return GetBindingKey(BINDING_KEY) end)

    layout:Space(2)
    layout:Button(L['清理最近创建及搜索列表'],
        function() Profile:ClearHistory() end,
        L['你确定要清理最近创建及搜索列表吗？'])

    -- Set the scroll child height after all items are added
    optFrame:SetHeight(-layout:GetY() + 10)

    -- ----------------------------------------------------------------
    -- Right column: filter options + spam word list
    -- ----------------------------------------------------------------
    if not NO_SCAN_WORD then
        -- Filter toggles + slider
        local filterFrame = CreateFrame('Frame', nil, self)
        filterFrame:SetPoint('TOPLEFT', self, 'TOP', 5, -10)
        filterFrame:SetPoint('TOPRIGHT', -10, -10)
        filterFrame:SetHeight(110)

        local fLayout = NewLayout(filterFrame, 0, 0)
        fLayout:Section(L['过滤器'])

        fLayout:Toggle(L['启用活动列表关键字过滤'],
            function() return Profile:GetSetting('spamWord') end,
            function(v) Profile:SetSetting('spamWord', v) end)

        local spamLenCb = fLayout:Toggle(L['活动说明字数过滤'],
            function() return Profile:GetSetting('spamLengthEnabled') end,
            function(v) Profile:SetSetting('spamLengthEnabled', v) end)

        local spamLenSlider = fLayout:Slider(L['字数过滤'], 10, MAX_MEETINGSTONE_SUMMARY_LETTERS, 1,
            function() return Profile:GetSetting('spamLength') end,
            function(v) Profile:SetSetting('spamLength', v) end)

        local function updateSpamLen()
            spamLenSlider:SetEnabled(Profile:GetSetting('spamLengthEnabled'))
        end
        spamLenCb:HookScript('OnClick', function() updateSpamLen() end)
        updateSpamLen()

        -- Spam word list
        local SpamWordWidget = GUI:GetClass('TitleWidget'):New(self)
        SpamWordWidget:SetPoint('TOPLEFT', filterFrame, 'BOTTOMLEFT', 0, -10)
        SpamWordWidget:SetPoint('BOTTOMRIGHT', -20, 30)
        SpamWordWidget:SetText(L['关键字过滤'])
        SpamWordWidget:SetBgShown(false)

        local SpamWordInset = CreateFrame('Frame', nil, SpamWordWidget, 'InsetFrameTemplate')
        SpamWordInset:SetPoint('TOPLEFT', 2, -25)
        SpamWordInset:SetPoint('BOTTOMRIGHT', -2, 5)

        local InputSpamWord = Addon:GetClass('InputDialog'):New(UIParent)
        InputSpamWord:SetTitle(L['请输入需要屏蔽的关键字'])
        InputSpamWord:SetCheckBoxLabel(L['正则?'])
        InputSpamWord:SetMaxLetters(50)
        InputSpamWord:SetErrorHandler(function(text)
            return pcall(strmatch, '', text)
        end)
        InputSpamWord:SetCallback('OnSubmit', function(_, text, checked)
            Profile:AddSpamWord({ text = text, pain = not checked and true or nil })
        end)
        InputSpamWord:SetCallback('OnError', function(self)
            self:SetError(L['正则有误，请检查'])
        end)

        local SpamWordList = GUI:GetClass('ListView'):New(SpamWordInset)
        SpamWordList:SetPoint('TOPLEFT', 5, -5)
        SpamWordList:SetPoint('BOTTOMRIGHT', -5, 5)
        SpamWordList:SetItemClass(Addon:GetClass('SpamWordItem'))
        SpamWordList:SetItemHeight(20)
        SpamWordList:SetItemSpacing(2)
        SpamWordList:SetSelectMode('RADIO')
        SpamWordList:SetItemHighlightWithoutChecked(true)
        SpamWordList:SetCallback('OnItemFormatted', function(_, button, data)
            button:SetData(data)
        end)

        local SpamWordAdd = CreateFrame('Button', nil, SpamWordWidget, 'UIPanelButtonTemplate')
        SpamWordAdd:SetPoint('LEFT', SpamWordWidget.Text, 'RIGHT', 0, 0)
        SpamWordAdd:SetSize(50, 22)
        SpamWordAdd:SetText(ADD)
        SpamWordAdd:SetScript('OnClick', function()
            self:AddSpamWord()
        end)

        local SpamWordReset = CreateFrame('Button', nil, SpamWordWidget, 'UIPanelButtonTemplate')
        SpamWordReset:SetPoint('TOPRIGHT', 0, -2)
        SpamWordReset:SetSize(50, 22)
        SpamWordReset:SetText(RESET)
        SpamWordReset:SetScript('OnClick', function()
            GUI:CallMessageDialog(L['确定重置关键字列表？'], function(result)
                if result then Profile:ResetSpamWord() end
            end)
        end)

        local EditDialog = Addon:GetClass('EditDialog'):New(UIParent)
        EditDialog:SetCallback('OnSubmit', function(_, text)
            Profile:ImportSpamWord(text)
        end)

        local SpamWordExport = CreateFrame('Button', nil, SpamWordWidget, 'UIPanelButtonTemplate')
        SpamWordExport:SetPoint('TOPRIGHT', SpamWordWidget, 'BOTTOMRIGHT', 0, 0)
        SpamWordExport:SetSize(50, 22)
        SpamWordExport:SetText(L['导出'])
        SpamWordExport:SetScript('OnClick', function()
            EditDialog:Open(L['导出关键字'], L['点击 Ctrl+A 全选，Ctrl+C 复制'],
                Profile:ExportSpamWord(), false)
        end)

        local SpamWordImport = CreateFrame('Button', nil, SpamWordWidget, 'UIPanelButtonTemplate')
        SpamWordImport:SetPoint('RIGHT', SpamWordExport, 'LEFT', -2, 0)
        SpamWordImport:SetSize(50, 22)
        SpamWordImport:SetText(L['导入'])
        SpamWordImport:SetScript('OnClick', function()
            EditDialog:Open(L['导入关键字'], L['每行一个关键字，"!"开头启用正则'])
        end)

        self.SpamWordList  = SpamWordList
        self.InputSpamWord = InputSpamWord

        self:RegisterMessage('MEETINGSTONE_SPAMWORD_UPDATE', 'RefreshSpamWord')
    end
end

function SettingPanel:OnEnable()
    self:RefreshSpamWord()
end

function SettingPanel:RefreshSpamWord(_, word)
    if NO_SCAN_WORD then return end
    self.SpamWordList:SetItemList(Profile:GetSpamWords())
    self.SpamWordList:Refresh()
    if word then
        self.SpamWordList:SetSelectedItem(word)
        self:ScheduleTimer('UpdateSpamWordScorll', 0.02)
    end
end

function SettingPanel:UpdateSpamWordScorll()
    local index    = self.SpamWordList:GetSelected() or 0
    local maxCount = self.SpamWordList:GetMaxCount()
    if index > maxCount then
        index = index - maxCount + 1
    else
        index = 1
    end
    self.SpamWordList:SetOffset(index)
end

function SettingPanel:AddSpamWord(word)
    local text, enable
    if type(word) == 'table' then
        text   = word.text
        enable = not word.pain
    elseif word then
        text = word
    end
    self.InputSpamWord:Open(text, enable)
end