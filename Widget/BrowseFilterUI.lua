BuildEnv(...)

local BrowsePanel = Addon:GetModule('BrowsePanel')
local BrowseFilter = Addon:GetModule('BrowseFilter')
local MainPanel = Addon:GetModule('MainPanel')
local Profile = Addon:GetModule('Profile')

-- 从 BrowseFilter 取共享工具（在 OnInitialize 之后可用，此处方法体内引用即可）
local function containsValue(array, value)
    for i, v in ipairs(array) do
        if v == value then
            return true, i
        end
    end
    return false, nil
end

-- 过滤器按钮（顶栏）
function BrowsePanel:CreateSeasonFilter()
    if self.RefreshButton then
        self.RefreshButton:SetPoint('TOPRIGHT', MainPanel, 'TOPRIGHT', -180, -38)
    end
    if self.AdvButton then
        self.AdvButton:SetPoint('LEFT', self.RefreshButton, 'RIGHT', 80, 0)
    end

    local ExSearchButton = CreateFrame('Button', nil, self, 'UIMenuButtonStretchTemplate')

    local function onFilterButtonClick()
        local activityItem = self.ActivityDropdown:GetItem()
        if not activityItem then
            self.ExFilterPanel:SetShown(not self.ExFilterPanel:IsShown())
            return
        end
        if activityItem.value == 'mplus' then
            self.BlzFilterPanel:SetShown(not self.BlzFilterPanel:IsShown())
            self.ExFilterPanel:SetShown(false)
        else
            self.ExFilterPanel:SetShown(not self.ExFilterPanel:IsShown())
            self.BlzFilterPanel:SetShown(false)
        end
        self.AdvFilterPanel:SetShown(false)
    end

    do
        GUI:Embed(ExSearchButton, 'Tooltip')
        ExSearchButton:SetTooltipAnchor('ANCHOR_RIGHT')
        ExSearchButton:SetTooltip('过滤器')
        ExSearchButton:SetSize(83, 31)
        ExSearchButton:SetPoint('LEFT', self.RefreshButton, 'RIGHT', 0, 0)
        ExSearchButton:SetText('过滤器')
        ExSearchButton:SetNormalFontObject('GameFontNormal')
        ExSearchButton:SetHighlightFontObject('GameFontHighlight')
        ExSearchButton:SetDisabledFontObject('GameFontDisable')

        if Profile:IsProfileKeyNew('advShine', 60200.09) then
            local Shine = GUI:GetClass('ShineWidget'):New(ExSearchButton)
            do
                Shine:SetPoint('TOPLEFT', 5, -5)
                Shine:SetPoint('BOTTOMRIGHT', -5, 5)
            end
            ExSearchButton.Shine = Shine
            ExSearchButton:SetScript('OnClick', function()
                ExSearchButton:SetScript('OnClick', onFilterButtonClick)
                ExSearchButton:GetScript('OnClick')(ExSearchButton)
            end)
        else
            ExSearchButton:SetScript('OnClick', onFilterButtonClick)
        end
    end
    self.ExSearchButton = ExSearchButton
end

-- 地下城搜索面板（M+ 专用）
function BrowsePanel:CreateBlzFilterPanel()
    local Dungeons = BrowseFilter.Dungeons

    local BlzFilterPanel = CreateFrame('Frame', nil, self, 'SimplePanelTemplate')

    local closeButton = CreateFrame('Button', nil, BlzFilterPanel, 'UIPanelCloseButton')
    do
        closeButton:SetPoint('TOPRIGHT', 0, -1)
    end

    do
        GUI:Embed(BlzFilterPanel, 'Refresh')
        BlzFilterPanel:SetSize(480, 410 + #Dungeons * 15)
        BlzFilterPanel:SetPoint('TOPLEFT', MainPanel, 'TOPRIGHT', 2, -10)
        BlzFilterPanel:SetFrameLevel(self.ActivityList:GetFrameLevel() + 15)
        BlzFilterPanel:EnableMouse(true)
        local Label = BlzFilterPanel:CreateFontString(nil, 'ARTWORK', 'GameFontNormal')
        do
            Label:SetPoint('TOP', 0, -10)
            Label:SetText('赛季地下城搜索')
        end
    end
    self.BlzFilterPanel = BlzFilterPanel
    BlzFilterPanel:SetShown(false)

    local enabled = C_LFGList.GetAdvancedFilter()
    self.MD = {}

    local function saveAdvancedFilter()
        enabled.difficultyNormal = true
        enabled.difficultyHeroic = true
        enabled.difficultyMythic = true
        enabled.difficultyMythicPlus = true
        enabled.generalPlaystyle1 = true
        enabled.generalPlaystyle2 = true
        enabled.generalPlaystyle3 = true
        enabled.generalPlaystyle4 = true
        for i = #enabled.activities, 1, -1 do
            if not containsValue(Dungeons, enabled.activities[i]) then
                table.remove(enabled.activities, i)
            end
        end
        if enabled.needsTank and enabled.hasTank then
            GUI:CallWarningDialog('不能同时选择缺坦克和已有坦克', true, nil)
        end
        if enabled.needsHealer and enabled.hasHealer then
            GUI:CallWarningDialog('不能同时选择缺治疗和已有治疗', true, nil)
        end
        C_LFGList.SaveAdvancedFilter(enabled)
    end


    local function createCheckBox(index, text, checked, value, cbEvent, cbFunc)
        local Box = Addon:GetClass('CheckBox'):New(BlzFilterPanel.Inset)
        Box.Check:SetText(text)
        if index <= #Dungeons then
            if checked then
                Box.Check:GetFontString():SetTextColor(GREEN_FONT_COLOR.r, GREEN_FONT_COLOR.g, GREEN_FONT_COLOR.b, 1)
            else
                Box.Check:GetFontString():SetTextColor(1, 1, 1, 0.5)
            end
        end
        Box.Check:SetChecked(checked)
        Box.dataValue = value
        Box:SetCallback(cbEvent, cbFunc)
        if index == 1 then
            Box:SetPoint('TOPLEFT', 10, -42)
            Box:SetPoint('TOPRIGHT', -10, -42)
        elseif index == #Dungeons + 1 then
            Box:SetPoint('TOPLEFT', self.MD[index - 1], 'BOTTOMLEFT', 0, -10)
            Box:SetPoint('TOPRIGHT', self.MD[index - 1], 'BOTTOMRIGHT', 0, -10)
        else
            Box:SetPoint('TOPLEFT', self.MD[index - 1], 'BOTTOMLEFT')
            Box:SetPoint('TOPRIGHT', self.MD[index - 1], 'BOTTOMRIGHT')
        end
        table.insert(self.MD, Box)
        return Box
    end

    local function createFilterBox(index, text, min, cbEvent, cbFunc)
        local Box = Addon:GetClass('FilterBox'):New(BlzFilterPanel.Inset)
        Box.Check:SetText(text)
        Box.MinBox:SetText(min)
        Box.MinBox:SetMinMaxValues(min, 9999)
        Box.MaxBox:SetText(9999)
        Box.MaxBox:SetMinMaxValues(9999, 9999)
        Box.Text:Hide()
        Box.MaxBox:Hide()
        Box:SetCallback(cbEvent, cbFunc)
        Box:SetPoint('TOPLEFT', self.MD[index - 1], 'BOTTOMLEFT', 0, -10)
        Box:SetPoint('TOPRIGHT', self.MD[index - 1], 'BOTTOMRIGHT', 0, -10)
        table.insert(self.MD, Box)
    end

    local function onRoleCheckChanged(box)
        enabled[box.dataValue] = box.Check:GetChecked()
        saveAdvancedFilter()
    end

    for i, id in ipairs(Dungeons) do
        local name = C_LFGList.GetActivityGroupInfo(id)
        local checked = MEETINGSTONE_UI_DB.DUNGEON_FILTER[id] == true
        createCheckBox(i, name, checked, id, 'OnChanged', function(box)
            if box.Check:GetChecked() then
                MEETINGSTONE_UI_DB.DUNGEON_FILTER[box.dataValue] = true
                box.Check:GetFontString():SetAlpha(1)
            else
                MEETINGSTONE_UI_DB.DUNGEON_FILTER[box.dataValue] = nil
                box.Check:GetFontString():SetAlpha(0.5)
            end
            self.ActivityList:Refresh()
        end)
    end

    createCheckBox(#self.MD + 1, '缺坦克',     enabled.needsTank,    'needsTank',    'OnChanged', onRoleCheckChanged)
    createCheckBox(#self.MD + 1, '缺治疗',     enabled.needsHealer,  'needsHealer',  'OnChanged', onRoleCheckChanged)
    createCheckBox(#self.MD + 1, '缺DPS',      enabled.needsDamage,  'needsDamage',  'OnChanged', onRoleCheckChanged)
    createCheckBox(#self.MD + 1, '已有坦克',   enabled.hasTank,      'hasTank',      'OnChanged', onRoleCheckChanged)
    createCheckBox(#self.MD + 1, '已有治疗',   enabled.hasHealer,    'hasHealer',    'OnChanged', onRoleCheckChanged)

    createFilterBox(#self.MD + 1, LFG_LIST_MINIMUM_RATING, enabled.minimumRating, 'OnChanged', function(box)
        enabled.minimumRating = box.MinBox:GetNumber()
    end)

    local ResetFilterButton = CreateFrame('Button', nil, BlzFilterPanel, 'UIPanelButtonTemplate')
    do
        ResetFilterButton:SetSize(160, 22)
        ResetFilterButton:SetPoint('BOTTOM', BlzFilterPanel, 'BOTTOM', 0, 3)
        ResetFilterButton:SetText('搜索更多队伍')
        ResetFilterButton:SetScript('OnClick', function(button)
            saveAdvancedFilter()
            for i, v in ipairs(self.MD) do
                if i <= #Dungeons then
                    if containsValue(enabled.activities, v.dataValue) then
                        v.Check:GetFontString():SetTextColor(GREEN_FONT_COLOR.r, GREEN_FONT_COLOR.g, GREEN_FONT_COLOR.b, 1)
                    else
                        v.Check:GetFontString():SetTextColor(1, 1, 1, 0.5)
                    end
                end
            end
            button:Disable()
            self:DoSearch()
            C_Timer.After(3, function() button:Enable() end)
        end)
    end
end

-- 组队职责过滤面板
function BrowsePanel:CreateExSearchButton()
    local ExFilterPanel = CreateFrame('Frame', nil, self, 'SimplePanelTemplate')

    local closeButton = CreateFrame('Button', nil, ExFilterPanel, 'UIPanelCloseButton')
    do
        closeButton:SetPoint('TOPRIGHT', 0, -1)
    end

    do
        GUI:Embed(ExFilterPanel, 'Refresh')
        ExFilterPanel:SetSize(200, 180)
        ExFilterPanel:SetPoint('TOPLEFT', MainPanel, 'TOPRIGHT', 2, -10)
        ExFilterPanel:SetFrameLevel(self.ActivityList:GetFrameLevel() + 15)
        ExFilterPanel:EnableMouse(true)
        local Label = ExFilterPanel:CreateFontString(nil, 'ARTWORK', 'GameFontNormal')
        do
            Label:SetPoint('TOPLEFT', 15, -10)
            Label:SetText('组队过滤器')
        end
    end
    self.ExFilterPanel = ExFilterPanel
    ExFilterPanel:SetShown(false)

    local function createMemberFilter(text, DB_Name, tooltip, index)
        if MEETINGSTONE_UI_DB[DB_Name] == nil then
            MEETINGSTONE_UI_DB[DB_Name] = false
        end
        local Box = Addon:GetClass('CheckBox'):New(ExFilterPanel.Inset)
        Box.Check:SetText(text)
        Box.Check:SetChecked(MEETINGSTONE_UI_DB[DB_Name])
        Box:SetPoint('TOPLEFT', 10, 10 - 20 * index)
        Box:SetPoint('TOPRIGHT', -10, 10 - 20 * index)
        Box:SetCallback('OnChanged', function()
            MEETINGSTONE_UI_DB[DB_Name] = not MEETINGSTONE_UI_DB[DB_Name]
            self.ActivityList:Refresh()
        end)
        if tooltip then
            GUI:Embed(Box.Check, 'Tooltip')
            Box.Check:SetTooltip('说明', tooltip)
            Box.Check:SetTooltipAnchor('ANCHOR_BOTTOMRIGHT')
        end
    end

    createMemberFilter('坦克', 'FILTER_TANK',   '隐藏已有坦克职业的队伍，允许多选', 1)
    createMemberFilter('治疗', 'FILTER_HEALTH',  '隐藏已有治疗职业的队伍，允许多选', 2)
    createMemberFilter('输出', 'FILTER_DAMAGE',  '隐藏输出职业满的队伍，允许多选', 3)
    createMemberFilter('多选-"或"条件', 'FILTER_MULTY',
        '上方几项多选时，将过滤出同时满足所有条件的队伍\n' ..
        '而多选的同时再勾选本项后，将过滤出满足勾选的任意一项条件的队伍\n' ..
        '一般而言，用于玩家想同时以多个职责加入队伍的时候\n' ..
        '例如战士想查找缺T或DPS的队伍', 4)
    createMemberFilter('显示屏蔽提示', 'IGNORE_TIPS_LOG',
        '屏蔽了队长或同标题玩家时，聊天框里显示一次提示信息', 5)
end

-- 初始化所有扩展 UI（由 BrowseFilter:OnInitialize 调用）
function BrowsePanel:InitExtension()
    self:CreateSeasonFilter()
    self:CreateBlzFilterPanel()
    self:CreateExSearchButton()
    self:CreateClassSpecFilter()
end

-- 职业专精过滤面板（内嵌在 BlzFilterPanel 右侧列，M+ 专用）
-- 配置按角色保存在 MEETINGSTONE_CHARACTER_DB.SPEC_FILTER
function BrowsePanel:CreateClassSpecFilter()
    local BlzFilterPanel = self.BlzFilterPanel
    local ClassSpecData  = BrowseFilter.ClassSpecData
    local specFilter     = MEETINGSTONE_CHARACTER_DB.SPEC_FILTER
    local inset          = BlzFilterPanel.Inset

    -- 竖分割线
    local vSep = inset:CreateTexture(nil, 'ARTWORK')
    vSep:SetColorTexture(0.5, 0.5, 0.5, 0.35)
    vSep:SetWidth(1)
    vSep:SetPoint('TOP',    inset, 'TOPLEFT',    203, -6)
    vSep:SetPoint('BOTTOM', inset, 'BOTTOMLEFT', 203, 30)

    -- 标题（右列内居中）
    local title = inset:CreateFontString(nil, 'ARTWORK', 'GameFontNormal')
    title:SetPoint('TOPLEFT',  inset, 'TOPLEFT',  211, -8)
    title:SetPoint('TOPRIGHT', inset, 'TOPRIGHT',  -8, -8)
    title:SetText('职业过滤器')
    title:SetJustifyH('CENTER')
    title:SetTextColor(1, 0.82, 0)

    -- 全选按钮（标题下方右对齐）
    local allOnBtn = CreateFrame('Button', nil, inset)
    allOnBtn:SetSize(44, 16)
    allOnBtn:SetPoint('TOPRIGHT', inset, 'TOPRIGHT', -8, -30)
    local allOnTxt = allOnBtn:CreateFontString(nil, 'ARTWORK', 'GameFontNormalSmall')
    allOnTxt:SetAllPoints()
    allOnTxt:SetText('全选')
    allOnTxt:SetTextColor(0.5, 0.8, 1)
    allOnBtn:SetScript('OnEnter', function() allOnTxt:SetTextColor(1, 1, 0.3) end)
    allOnBtn:SetScript('OnLeave', function() allOnTxt:SetTextColor(0.5, 0.8, 1) end)

    -- 标题区底部细分隔线
    local hSep = inset:CreateTexture(nil, 'ARTWORK')
    hSep:SetColorTexture(0.5, 0.5, 0.5, 0.25)
    hSep:SetHeight(1)
    hSep:SetPoint('TOPLEFT',  inset, 'TOPLEFT',  211, -50)
    hSep:SetPoint('TOPRIGHT', inset, 'TOPRIGHT',  -8, -50)

    -- 布局常量
    local COL_X   = 211   -- 右列起始X（inset内偏移）
    local ICON_W  = 24    -- 职业图标边长
    local NAME_W  = 72    -- 职业名固定宽度
    local SPEC_W  = 22    -- 专精图标边长
    local SPEC_G  = 4     -- 专精图标间距
    local ROW_H   = 30    -- 行高
    local ROW_Y0  = -54   -- 第一行Y（标题+全选行+分隔线下方）
    -- spec_x0 = COL_X + ICON_W + 4 + NAME_W = 295
    local SPEC_X0 = COL_X + ICON_W + 4 + NAME_W

    local specButtons = {}  -- specID → button，供批量操作
    local classBtns   = {}  -- 职业按钮列表，供全选重置

    for ci, classData in ipairs(ClassSpecData) do
        local rowY = ROW_Y0 - (ci - 1) * ROW_H

        -- 职业图标 CheckButton
        local classBtn = CreateFrame('CheckButton', nil, inset)
        classBtn:SetSize(ICON_W, ICON_W)
        classBtn:SetPoint('TOPLEFT', inset, 'TOPLEFT', COL_X, rowY)

        local classIconTex = classBtn:CreateTexture(nil, 'ARTWORK')
        classIconTex:SetAllPoints()
        classIconTex:SetTexture([[Interface\GLUES\CHARACTERCREATE\UI-CHARACTERCREATE-CLASSES]])
        if CLASS_ICON_TCOORDS and CLASS_ICON_TCOORDS[classData.file] then
            classIconTex:SetTexCoord(unpack(CLASS_ICON_TCOORDS[classData.file]))
        end

        local classDesatTex = classBtn:CreateTexture(nil, 'OVERLAY')
        classDesatTex:SetAllPoints()
        classDesatTex:SetColorTexture(0, 0, 0, 0.6)
        classDesatTex:Hide()
        classBtn.desatOverlay = classDesatTex

        classBtn:SetScript('OnEnter', function(self)
            GameTooltip:SetOwner(self, 'ANCHOR_RIGHT')
            GameTooltip:SetText(classData.name)
            GameTooltip:Show()
        end)
        classBtn:SetScript('OnLeave', function() GameTooltip:Hide() end)

        -- 职业名标签（带职业颜色）
        local nameLabel = inset:CreateFontString(nil, 'ARTWORK', 'GameFontNormalSmall')
        nameLabel:SetSize(NAME_W, ROW_H)
        nameLabel:SetPoint('LEFT', classBtn, 'RIGHT', 4, 0)
        nameLabel:SetText(classData.name)
        nameLabel:SetJustifyH('LEFT')
        if RAID_CLASS_COLORS and RAID_CLASS_COLORS[classData.file] then
            local c = RAID_CLASS_COLORS[classData.file]
            nameLabel:SetTextColor(c.r, c.g, c.b)
        end

        -- 专精图标按钮
        local specBtns = {}
        for si, spec in ipairs(classData.specs) do
            local specBtn = CreateFrame('CheckButton', nil, inset)
            specBtn:SetSize(SPEC_W, SPEC_W)
            specBtn:SetPoint('TOPLEFT', inset, 'TOPLEFT',
                SPEC_X0 + (si - 1) * (SPEC_W + SPEC_G), rowY + 1)

            local specIconTex = specBtn:CreateTexture(nil, 'ARTWORK')
            specIconTex:SetPoint('TOPLEFT',     2,  -2)
            specIconTex:SetPoint('BOTTOMRIGHT', -2,  2)
            specIconTex:SetTexture(spec.icon)

            local specDesatTex = specBtn:CreateTexture(nil, 'OVERLAY')
            specDesatTex:SetAllPoints()
            specDesatTex:SetColorTexture(0, 0, 0, 0.6)
            specDesatTex:Hide()
            specBtn.desatOverlay = specDesatTex

            local isEnabled = specFilter[spec.id] ~= false
            specBtn:SetChecked(isEnabled)
            if not isEnabled then specBtn.desatOverlay:Show() end

            specBtn:SetScript('OnEnter', function(self)
                GameTooltip:SetOwner(self, 'ANCHOR_RIGHT')
                GameTooltip:SetText(spec.name)
                GameTooltip:Show()
            end)
            specBtn:SetScript('OnLeave', function() GameTooltip:Hide() end)

            local specID = spec.id
            specBtn:SetScript('OnClick', function(self)
                -- 从 specFilter 读取当前状态来切换（不依赖 GetChecked 的自动切换）
                local nowEnabled = (specFilter[specID] == false)  -- 当前被过滤 → 点击后启用
                if nowEnabled then specFilter[specID] = nil else specFilter[specID] = false end
                self:SetChecked(nowEnabled)
                self.desatOverlay:SetShown(not nowEnabled)

                local anyEnabled = false
                for _, sb in ipairs(specBtns) do
                    if sb:GetChecked() then anyEnabled = true; break end
                end
                classBtn:SetChecked(anyEnabled)
                classBtn.desatOverlay:SetShown(not anyEnabled)

                BrowsePanel.ActivityList:Refresh()
            end)

            specButtons[spec.id] = specBtn
            specBtns[#specBtns + 1] = specBtn
        end

        -- 初始化职业按钮状态
        local anyEnabled = false
        for _, sb in ipairs(specBtns) do
            if sb:GetChecked() then anyEnabled = true; break end
        end
        classBtn:SetChecked(anyEnabled)
        classBtn.desatOverlay:SetShown(not anyEnabled)

        -- 职业图标点击：批量切换该职业所有专精
        classBtn:SetScript('OnClick', function(self)
            -- 若该职业有任一专精被过滤则全部启用，否则全部过滤
            local hasFiltered = false
            for _, spec in ipairs(classData.specs) do
                if specFilter[spec.id] == false then hasFiltered = true; break end
            end
            local nowEnabled = hasFiltered
            self:SetChecked(nowEnabled)
            self.desatOverlay:SetShown(not nowEnabled)
            for _, spec in ipairs(classData.specs) do
                if nowEnabled then specFilter[spec.id] = nil else specFilter[spec.id] = false end
                local sb = specButtons[spec.id]
                if sb then
                    sb:SetChecked(nowEnabled)
                    sb.desatOverlay:SetShown(not nowEnabled)
                end
            end
            BrowsePanel.ActivityList:Refresh()
        end)

        classBtns[ci] = { btn = classBtn, specBtns = specBtns, classData = classData }
    end

    -- 全选：清除所有过滤，恢复所有按钮为选中
    allOnBtn:SetScript('OnClick', function()
        for specID in pairs(specFilter) do
            specFilter[specID] = nil
        end
        for _, entry in ipairs(classBtns) do
            entry.btn:SetChecked(true)
            entry.btn.desatOverlay:Hide()
            for _, sb in ipairs(entry.specBtns) do
                sb:SetChecked(true)
                sb.desatOverlay:Hide()
            end
        end
        BrowsePanel.ActivityList:Refresh()
    end)
end

-- 右键活动菜单
function BrowsePanel:ToggleActivityMenu(anchor, activity)
    local usable, reason = self:CheckSignUpStatus(activity)

    GUI:ToggleMenu(anchor, {
        {
            text = activity:GetName(), isTitle = true, notCheckable = true,
        },
        {
            text = '申请加入',
            func = function() self:SignUp(activity) end,
            disabled = not usable or activity:IsDelisted() or activity:IsApplication(),
            tooltipTitle = not (activity:IsDelisted() or activity:IsApplication()) and '申请加入',
            tooltipText = reason,
            tooltipWhileDisabled = true,
            tooltipOnButton = true,
        },
        {
            text = WHISPER_LEADER,
            func = function() ChatFrame_SendTell(activity:GetLeader()) end,
            disabled = not activity:GetLeader(),
            tooltipTitle = not activity:IsApplication() and WHISPER,
            tooltipText = not activity:IsApplication() and LFG_LIST_MUST_SIGN_UP_TO_WHISPER,
            tooltipOnButton = true,
            tooltipWhileDisabled = true,
        },
        {
            text = LFG_LIST_REPORT_GROUP_FOR,
            func = function()
                LFGList_ReportListing(activity:GetID(), activity:GetLeader())
                LFGListSearchPanel_UpdateResultList(LFGListFrame.SearchPanel)
            end,
        },
        {
            text = '屏蔽队长',
            func = function()
                local name = activity:GetLeader()
                BrowsePanel.IgnoreLeaderOnly[name] = true
                if MEETINGSTONE_UI_DB.IGNORE_TIPS_LOG then
                    print(name .. ' 已加入黑名单')
                end
                BrowsePanel.ActivityList:Refresh()
            end,
        },
        {
            text = '屏蔽同标题玩家',
            hidden = function() return not Profile:GetEnableIgnoreTitle() end,
            func = function()
                local title = activity:GetSummary()
                if MEETINGSTONE_UI_DB.IGNORE_TIPS_LOG then
                    print('添加过滤：', title)
                end
                BrowsePanel.IgnoreWithTitle[title] = true
                BrowsePanel.ActivityList:Refresh()
            end,
        },
        {
            text = '复制队长名字',
            func = function()
                local name = activity:GetLeader()
                print(name)
                GUI:CallUrlDialog(name)
            end,
        },
        { text = CANCEL },
    }, 'cursor')
end

-- 获取当前副本过滤状态
function BrowsePanel:GetExSearches()
    local filters = {}
    for _, box in ipairs(self.MD) do
        filters[box.dungeonName] = { enable = not not box.Check:GetChecked() }
    end
    return filters
end
