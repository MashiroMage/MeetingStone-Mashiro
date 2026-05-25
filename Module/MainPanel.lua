MEETINGSTONE_UI_E_POINTS = {}
BuildEnv(...)

local ADDON_SUMMARY = [[
<html>
<body>
<br/>
<h2>  </h2>
</body>
</html>]]

MainPanel = Addon:NewModule(GUI:GetClass('Panel'):New(UIParent), 'MainPanel', 'AceEvent-3.0', 'AceBucket-3.0')

function MainPanel:OnInitialize()
    GUI:Embed(self, 'Refresh', 'Help', 'Blocker')

    self:SetSize(960, 480)
	self:SetText(L['集合石'])
    --self:SetIcon(ADDON_LOGO)
    self:EnableUIPanel(true)
    self:SetTabStyle('BOTTOM')
    self:SetTopHeight(80)
    self:RegisterForDrag('LeftButton')
    self:SetMovable(true)
    self:SetScript('OnDragStart', self.StartMoving)
    self:SetScript('OnDragStop', self.StopMovingOrSizing)
    self:SetClampedToScreen(true)
    _G.MeetingStoneMainPanel = self;
    GUI:RegisterUIPanel(self)
    --self:RegisterEvent("PLAYER_REGEN_DISABLED");
    local scale = Profile:GetSetting('uiscale')
    if (scale == nil or scale < 1.0) then
        scale = 1.0
    end
    self:SetScale(scale)

    self:HookScript("OnHide", function()
        local anchor1, _, anchor2, x, y = self:GetPoint();
        MEETINGSTONE_UI_E_POINTS.x = x
        MEETINGSTONE_UI_E_POINTS.y = y
        MEETINGSTONE_UI_E_POINTS.a1 = anchor1
        MEETINGSTONE_UI_E_POINTS.a2 = anchor2
    end)

    self:HookScript('OnShow', function()
        --C_LFGList.RequestAvailableActivities()
        self:UpdateBlockers()
        self:SendMessage('MEETINGSTONE_OPEN')
        if (MEETINGSTONE_UI_E_POINTS ~= nil and MEETINGSTONE_UI_E_POINTS.x ~= nil) then
            self:ClearAllPoints();
            self:SetPoint(MEETINGSTONE_UI_E_POINTS.a1, UIParent, MEETINGSTONE_UI_E_POINTS.a2, MEETINGSTONE_UI_E_POINTS.x,
                MEETINGSTONE_UI_E_POINTS.y)
        end
    end)

    self:RegisterEvent('AJ_PVE_LFG_ACTION')
    self:RegisterEvent('AJ_PVP_LFG_ACTION', 'AJ_PVE_LFG_ACTION')

    --self.CloseButton:SetScript("OnClick", function() self:Hide(); end)

    PVEFrame:UnregisterEvent('AJ_PVE_LFG_ACTION')
    PVEFrame:UnregisterEvent('AJ_PVP_LFG_ACTION')

    local HelpBlocker = self:NewBlocker('HelpBlocker', 2)
    do
        HelpBlocker:SetCallback('OnCheck', function()
            return Profile:IsNewVersion()
        end)
        HelpBlocker:SetCallback('OnFormat', function(HelpBlocker)
        end)
        HelpBlocker:SetCallback('OnInit', function(HelpBlocker)
            local Icon = HelpBlocker:CreateTexture(nil, 'ARTWORK')
            do
                Icon:SetPoint('TOPLEFT', 50, -50)
                Icon:SetSize(64, 64)
                Icon:SetTexture([[Interface\AddOns\MeetingStone\Media\Mark\0]])
            end

            local Label = HelpBlocker:CreateFontString(nil, 'ARTWORK')
            do
                Label:SetFont(STANDARD_TEXT_FONT, 32, 'OUTLINE')
                Label:SetTextColor(NORMAL_FONT_COLOR.r, NORMAL_FONT_COLOR.g, NORMAL_FONT_COLOR.b)
                Label:SetPoint('LEFT', Icon, 'RIGHT', 0, 0)
                Label:SetText(L['集合石'])
            end

            local Content = HelpBlocker:CreateFontString(nil, 'ARTWORK', 'GameFontDisableLarge')
            do
                Content:SetPoint('TOPLEFT', Icon, 'BOTTOMLEFT', 10, -20)
                Content:SetJustifyH('LEFT')
                Content:SetJustifyV('TOP')
                Content:SetText(L['当前版本：'] .. ADDON_VERSION)
            end

            local SummaryHtml = GUI:GetClass('ScrollSummaryHtml'):New(HelpBlocker)
            do
                SummaryHtml:SetPoint('TOPLEFT', 360, -15)
                SummaryHtml:SetPoint('BOTTOMRIGHT', -20, 20)
                SummaryHtml:SetSpacing('h2', 20)
                SummaryHtml:SetSpacing('h1', 10)
                SummaryHtml:SetText(ADDON_SUMMARY)
            end

            local EnterButton = CreateFrame('Button', nil, HelpBlocker, 'UIPanelButtonTemplate')
            do
                EnterButton:SetPoint('BOTTOMLEFT', 50, 30)
                EnterButton:SetSize(120, 26)
                EnterButton:SetText(L['开始体验'])
                EnterButton:SetScript('OnClick', function()
                    self.newVersionReaded = true
                    Profile:SaveVersion()
                    HelpBlocker:Hide()
                end)
            end

            local HelpButton = CreateFrame('Button', nil, HelpBlocker, 'UIPanelButtonTemplate')
            do
                HelpButton:SetPoint('BOTTOMLEFT', EnterButton, 'TOPLEFT', 0, 10)
                HelpButton:SetSize(120, 26)
                HelpButton:SetText(L['新手指引'])
                HelpButton:SetScript('OnClick', function()
                    self.newVersionReaded = true
                    Profile:SaveVersion()
                    HelpBlocker:Hide()
                    self:SelectPanel(BrowsePanel)
                    self:ShowHelpPlate(BrowsePanel)
                end)
            end

            local SummaryButton = CreateFrame('Button', nil, HelpBlocker, 'UIPanelButtonTemplate')
            do
                SummaryButton:SetPoint('BOTTOMLEFT', HelpButton, 'TOPLEFT', 0, 10)
                SummaryButton:SetSize(120, 26)
                SummaryButton:SetText(L['插件简介'])
                SummaryButton:SetScript('OnClick', function()
                    SummaryHtml:SetText(ADDON_SUMMARY)
                end)
            end

            HelpBlocker.NewVersion = nil
            HelpBlocker.NewVersionFlash = nil
        end)
    end

    self.GameTooltip = GUI:GetClass('Tooltip'):New(self)

    -- 更新地址按钮
    local CopyUpdUrlBtn = CreateFrame('Button', nil, self, 'UIMenuButtonStretchTemplate')
    do
        CopyUpdUrlBtn:SetSize(80, 22)
        CopyUpdUrlBtn:SetPoint('TOPRIGHT', MainPanel, -30, 0)
        CopyUpdUrlBtn:SetText('更新地址')
        CopyUpdUrlBtn:SetNormalFontObject('GameFontNormal')
        CopyUpdUrlBtn:SetHighlightFontObject('GameFontHighlight')

        CopyUpdUrlBtn:SetScript('OnEnter', function()
            local GameTooltip = self.GameTooltip
            GameTooltip:SetOwner(CopyUpdUrlBtn, 'ANCHOR_BOTTOMLEFT')
            GameTooltip:SetText('点击复制更新地址')
            GameTooltip:AddLine('https://mashiromage.online/meetingstone/', 0.4, 0.8, 1, true)
            GameTooltip:Show()
        end)
        CopyUpdUrlBtn:SetScript('OnLeave', function()
            self.GameTooltip:Hide()
        end)
        CopyUpdUrlBtn:SetScript('OnClick', function()
            ApplyUrlButton(CopyUpdUrlBtn, 'https://mashiromage.online/meetingstone/')
        end)
    end
end

function MainPanel:OnEnable()
    C_LFGList.RequestAvailableActivities()
end

function MainPanel:AJ_PVE_LFG_ACTION()
    Addon:ShowModule('MainPanel')
    MainPanel:SelectPanel(BrowsePanel)
end

function MainPanel:OpenActivityTooltip(activity, tooltip)
    -- local tooltip = self.tooltip
    if not tooltip then
        tooltip = self.GameTooltip
        tooltip:SetOwner(self, 'ANCHOR_NONE')
        tooltip:SetPoint('TOPLEFT', self, 'TOPRIGHT', 1, -10)
    end
    -- tooltip:SetOwner(self, 'ANCHOR_NONE')
    -- tooltip:SetPoint('TOPLEFT', self, 'TOPRIGHT', 1, -10)
    tooltip:AddHeader(activity:GetName(), 1, 1, 1)
    
    if activity:GetGeneralPlaystyle() then
        tooltip:AddLine( GEMERALPLAYSTYLE[activity:GetGeneralPlaystyle()], GREEN_FONT_COLOR.r, GREEN_FONT_COLOR.g, GREEN_FONT_COLOR.b , true)
    end    

    tooltip:AddLine(activity:GetSummary(), 1, 1, 1, true)

    if activity:GetComment() then
        tooltip:AddLine(activity:GetComment(), GRAY_FONT_COLOR.r, GRAY_FONT_COLOR.g, GRAY_FONT_COLOR.b, true)
    end

    tooltip:AddSepatator()

    if activity:GetLeader() then
        -- local prefix = ""
        -- if activity:GetCrossFactionListing() then
        -- local faction
        -- if activity:GetLeaderFactionGroup() == 0 then
        -- faction = "horde"
        -- elseif activity:GetLeaderFactionGroup() == 1 then
        -- faction = "alliance"
        -- end
        -- if faction then
        -- prefix = format("|TInterface/FriendsFrame/PlusManz-%s:28:28:0:0|t", faction)
        -- --prefix = format("|Tinterface/battlefieldframe/battleground-%s:32:32:0:0|t", faction)
        -- --prefix = format("|Tinterface/icons/pvpcurrency-honor-%s:0:0:0:0|t", faction)
        -- end
        -- end
        tooltip:AddLine(format(LFG_LIST_TOOLTIP_LEADER, activity:GetLeaderText()))

        if activity:GetLeaderItemLevel() then
            tooltip:AddLine(format(L['队长物品等级：|cffffffff%s|r'], activity:GetLeaderItemLevel()))
        end
        if activity:GetLeaderHonorLevel() then
            tooltip:AddLine(format(L['队长荣誉等级：|cffffffff%s|r'], activity:GetLeaderHonorLevel()))
        end

        local pvpRating = activity:GetLeaderPvpRating() or 0
        if pvpRating > 0 then
            tooltip:AddLine(format(L['队长PvP 等级：|cffffffff%s|r'], pvpRating))
        end

        local score = activity:GetLeaderScore() or 0
        if activity:IsMythicPlusActivity() or score > 0 then
            local color = GetDungeonScoreRarityColor(score)
            tooltip:AddLine(format(L['队长大秘评分：%s'], color:WrapTextInColorCode(score)))
            local info = activity:GetLeaderScoreInfo()
            if info and info.mapScore and info.mapScore > 0 then
                local color = GetSpecificDungeonOverallScoreRarityColor(info.mapScore)
                local levelText = format(info.finishedSuccess and "|cff00ff00%d层|r" or "|cff7f7f7f%d层|r",
                    info.bestRunLevel or 0)
                tooltip:AddLine(format("队长当前副本: %s / %s", color:WrapTextInColorCode(info.mapScore), levelText))
            else
                tooltip:AddLine(format("队长当前副本: |cff7f7f7f 无信息|r"))
            end
        end
        tooltip:AddSepatator()
    end

    -- if activity:GetCrossFactionListing() then
    -- tooltip:AddLine(L["|cff00ff00跨阵营队伍|r"])
    -- end
    if activity:GetItemLevel() > 0 then
        tooltip:AddLine(format(LFG_LIST_TOOLTIP_ILVL, activity:GetItemLevel()))
    end
    if activity:IsUseHonorLevel() and activity:GetHonorLevel() > 0 then
        tooltip:AddLine(format(LFG_LIST_TOOLTIP_HONOR_LEVEL, activity:GetHonorLevel()))
    end
    if activity:GetVoiceChat() then
        tooltip:AddLine(format(L['语音聊天：|cffffffff%s|r'], activity:GetVoiceChat()), nil, nil, nil, true)
    end
    if activity:GetAge() > 0 then
        tooltip:AddLine(string.format(LFG_LIST_TOOLTIP_AGE, SecondsToTime(activity:GetAge(), false, false, 1, false)))
    end
    --2022-11-17
    if activity:GetDisplayType() == Enum.LFGListDisplayType.ClassEnumerate then
        tooltip:AddSepatator()
        tooltip:AddLine(string.format(LFG_LIST_TOOLTIP_MEMBERS_SIMPLE, activity:GetNumMembers()))
        for i = 1, activity:GetNumMembers() do
            local role, class, classLocalized, specLocalized = LfgService:GetSearchResultMemberInfo(activity:GetID(), i)
            local classColor                                 = RAID_CLASS_COLORS[class] or NORMAL_FONT_COLOR
            tooltip:AddLine(string.format(LFG_LIST_TOOLTIP_CLASS_ROLE, classLocalized, specLocalized or _G[role]),
                classColor.r,
                classColor.g, classColor.b)
        end
    else
        -- Modification begin
        -- Display Raid/Party Roles,code from PGF addon
        local roles = {}
        local classInfo = {}
        for i = 1, activity:GetNumMembers() do
            local role, class, classLocalized, specLocalized = LfgService:GetSearchResultMemberInfo(activity:GetID(), i)
            if (class) then
                classInfo[class .. specLocalized] = {
                    name = classLocalized,
                    color = RAID_CLASS_COLORS[class] or NORMAL_FONT_COLOR,
                    spec = specLocalized
                }
                if not roles[role] then roles[role] = {} end
                if not roles[role][class .. specLocalized] then roles[role][class .. specLocalized] = 0 end
                roles[role][class .. specLocalized] = roles[role][class .. specLocalized] + 1
            end
        end

        for role, classes in pairs(roles) do
            tooltip:AddLine(_G[role] .. ": ")
            for classAndspec, count in pairs(classes) do
                local text = "   "
                if count > 1 then text = text .. count .. " " else text = text .. "   " end
                text = text ..
                    "|c" ..
                    classInfo[classAndspec].color.colorStr ..
                    classInfo[classAndspec].name .. " - " .. classInfo[classAndspec].spec .. "|r "
                tooltip:AddLine(text)
            end
        end
        -- Modification end
        local memberCounts = C_LFGList.GetSearchResultMemberCounts(activity:GetID())
        if memberCounts then
            tooltip:AddSepatator()
            tooltip:AddLine(string.format(LFG_LIST_TOOLTIP_MEMBERS, activity:GetNumMembers(), memberCounts.TANK,
                memberCounts.HEALER, memberCounts.DAMAGER))
        end
    end

    if activity:IsAnyFriend() and activity:GetNumMembers() ~= 0 then
        tooltip:AddSepatator()
        tooltip:AddLine(LFG_LIST_TOOLTIP_FRIENDS_IN_GROUP)
        tooltip:AddLine(LFGListSearchEntryUtil_GetFriendList(activity:GetID()), 1, 1, 1, true)
    end

    local progressions = GetRaidProgressionData(activity:GetActivityID(), activity:GetCustomID())
    local progressionValue = activity:GetLeaderProgression()
    local completedEncounters = C_LFGList.GetSearchResultEncounterInfo(activity:GetID())
    if progressions and progressionValue then
        tooltip:AddSepatator()
        tooltip:AddDoubleLine(L['副本进度/经验：'], activity:GetShortName())
        for i, v in ipairs(progressions) do
            local color = activity:IsBossKilled(v.name) and RED_FONT_COLOR or GREEN_FONT_COLOR
            tooltip:AddDoubleLine(v.name, GetProgressionTex(progressionValue, i), color.r, color.g, color.b)
        end
    elseif completedEncounters and #completedEncounters > 0 then
        tooltip:AddSepatator()
        tooltip:AddLine(LFG_LIST_BOSSES_DEFEATED)
        for i = 1, #completedEncounters do
            tooltip:AddLine(completedEncounters[i], RED_FONT_COLOR.r, RED_FONT_COLOR.g, RED_FONT_COLOR.b)
        end
    end

    if activity:IsDelisted() then
        tooltip:AddSepatator()
        tooltip:AddLine(LFG_LIST_ENTRY_DELISTED, RED_FONT_COLOR.r, RED_FONT_COLOR.g, RED_FONT_COLOR.b, true)
    end

    local version = activity:GetVersion()
    if version then
        tooltip:AddDoubleLine(' ', GetFullVersion(version), 1, 1, 1, 0.5, 0.5, 0.5)
    end

    -- if RaiderIO and RaiderIO.GetProfile and Profile:GetEnableRaiderIO() then
    --     RaiderIOService:appendRaiderIOData(activity:GetLeader(), activity:GetLeaderScore(), tooltip)
    -- end

    --[=[@debug@
    if activity:IsMeetingStone() then
        local source = activity:GetSource() or 1
        tooltip:AddLine(
            source == 0 and '单体' or source == 1 and '大脚' or source == 2 and '有爱' or source == 4 and '多玩' or
                source == 8 and 'EUI')
    end

    tooltip:AddLine('ID: ' .. activity:GetID())
    tooltip:AddLine('Loot: ' .. tostring(activity:GetLoot()))
    tooltip:AddLine('Mode: ' .. tostring(activity:GetMode()))
    --@end-debug@]=]

    tooltip:Show()
end

local FACTION_STRINGS = { [0] = '|cff00ff00' .. FACTION_HORDE .. '|r', [1] = '|cff00ff00' .. FACTION_ALLIANCE .. '|r' };

function MainPanel:OpenApplicantTooltip(applicant)
    local GameTooltip = self.GameTooltip
    local name = applicant:GetName()
    local class = applicant:GetClass()
    local level = applicant:GetLevel()
    local localizedClass = applicant:GetLocalizedClass()
    local itemLevel = applicant:GetItemLevel()
    local comment = applicant:GetMsg()
    local useHonorLevel = applicant:IsUseHonorLevel()
    local specId = applicant:GetSpecID()

    

    GameTooltip:SetOwner(self, 'ANCHOR_NONE')
    GameTooltip:SetPoint('TOPLEFT', self, 'TOPRIGHT', 0, 0)

    if name then
        local classTextColor = RAID_CLASS_COLORS[class]
        GameTooltip:AddHeader(name, classTextColor.r, classTextColor.g, classTextColor.b)
        local classSpecializationName = localizedClass
        if specId then
            local specName = GetSpecNameBySpecID(specId)
            if specName then
                classSpecializationName = CLUB_FINDER_LOOKING_FOR_CLASS_SPEC:format(specName, classSpecializationName)
            end
        end    
        GameTooltip:AddLine(string.format(UNIT_TYPE_LEVEL_TEMPLATE, level, classSpecializationName), 1, 1, 1)
    else
        GameTooltip:AddHeader(UnitName('none'), NORMAL_FONT_COLOR.r, NORMAL_FONT_COLOR.g, NORMAL_FONT_COLOR.b)
    end
    GameTooltip:AddLine(string.format(LFG_LIST_ITEM_LEVEL_CURRENT, itemLevel), 1, 1, 1)
    if useHonorLevel then
        GameTooltip:AddLine(string.format(LFG_LIST_HONOR_LEVEL_CURRENT_PVP, applicant:GetHonorLevel()), 1, 1, 1)
    end

    if U1AddDonatorTitle then
        U1AddDonatorTitle(GameTooltip, name)
    end

    local score = applicant:GetDungeonScore() or 0
    if applicant:IsMythicPlusActivity() or score > 0 then
        local color = GetDungeonScoreRarityColor(score)
        GameTooltip:AddLine(format(L['大秘评分：%s'], color:WrapTextInColorCode(score)))
        local info = applicant:GetBestDungeonScore()
        if info and info.mapScore and info.mapScore > 0 then
            local color = GetSpecificDungeonOverallScoreRarityColor(info.mapScore)
            local levelText = format(info.finishedSuccess and "|cff00ff00%d层|r" or "|cff7f7f7f%d层|r",
                info.bestRunLevel or 0)
            GameTooltip:AddLine(format("当前副本: %s / %s", color:WrapTextInColorCode(info.mapScore), levelText))
        else
            GameTooltip:AddLine(format("当前副本: |cff7f7f7f 无信息|r"))
        end
    end

    if comment and comment ~= '' then
        GameTooltip:AddLine(' ')
        GameTooltip:AddLine(comment, GREEN_FONT_COLOR.r, GREEN_FONT_COLOR.g, GREEN_FONT_COLOR.b, true)
    end

    -- Add statistics
    local stats = C_LFGList.GetApplicantMemberStats(applicant:GetID(), applicant:GetIndex()) or {}
    do
        for k, v in pairs(stats) do
            if v == 0 then
                stats[k] = nil
            end
        end
    end

    if next(stats) then
        GameTooltip:AddSepatator()
        GameTooltip:AddLine(LFG_LIST_PROVING_GROUND_TITLE)

        for _, _v in ipairs(PROVING_GROUND_DATA) do
            for i, v in ipairs(_v) do
                if stats[v.id] then
                    GameTooltip:AddLine(v.text)
                    break
                end
            end
        end
    end

    -- Add Progression
    local activityID = applicant:GetActivityID()
    local progressions = RAID_PROGRESSION_LIST[activityID]
    local progressionValue = applicant:GetProgression()
    local activity = CreatePanel:GetCurrentActivity()
    if progressions and progressionValue then
        GameTooltip:AddSepatator()
        GameTooltip:AddDoubleLine(L['副本经验：'], activity:GetName())
        for i, v in ipairs(progressions) do
            GameTooltip:AddDoubleLine(v.name, GetProgressionTex(progressionValue, i), 1, 1, 1)
        end
    end

    if RaiderIOService and RaiderIO and RaiderIO.GetProfile and Profile:GetEnableRaiderIO() then
        RaiderIOService:appendRaiderIOData(applicant:GetName(), applicant:GetDungeonScore(), GameTooltip)
    end

    GameTooltip:Show()
end

function MainPanel:CloseTooltip()
    self.GameTooltip:Hide()
end

function MainPanel:OpenRecentPlayerTooltip(player)
    local manager = player:GetManager()
    local tooltip = self.GameTooltip
    tooltip:SetOwner(self, 'ANCHOR_NONE')
    tooltip:SetPoint('TOPLEFT', self, 'TOPRIGHT', 1, -10)

    tooltip:SetText(manager:GetName())
    tooltip:AddLine(player:GetNameText())
    tooltip:AddLine(player:GetNotes(), 1, 1, 1, true)
    tooltip:Show()
end
function GetSpecNameBySpecID(specID, playerSex)
	playerSex = playerSex or UnitSex("player");
	if playerSex then
		return select(2, GetSpecializationInfoByID(specID, playerSex));
	end
	return "";
end