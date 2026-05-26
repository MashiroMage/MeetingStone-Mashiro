BuildEnv(...)

local BrowsePanel = Addon:GetModule('BrowsePanel')
local Profile = Addon:GetModule('Profile')
local LfgService = Addon:GetModule('LfgService')

local Dungeons

-- 嗜血/英勇职业（本地过滤用）
local BLOODLUST_CLASSES = { MAGE = true, HUNTER = true, SHAMAN = true, EVOKER = true }
-- 战斗复活职业（本地过滤用）
local BREZ_CLASSES = { PALADIN = true, DEATHKNIGHT = true, DRUID = true, WARLOCK = true }

-- 判断数组是否包含某值，返回 found, index
local function containsValue(array, value)
    for i, v in ipairs(array) do
        if v == value then
            return true, i
        end
    end
    return false, nil
end

local BrowseFilter = Addon:NewModule('BrowseFilter')

function BrowseFilter:OnInitialize()
    if not MEETINGSTONE_UI_DB.IGNORE_LIST then
        MEETINGSTONE_UI_DB.IGNORE_LIST = {}
    end

    if MEETINGSTONE_CHARACTER_DB.Remix then
        Dungeons = { 127, 128, 112, 114, 115, 120, 113, 117, 118, 121, 119, 129, 133 }
    else
        Dungeons = { 370, 399, 400, 401, 9, 52, 133, 302 }
    end
    -- 暴露给 BrowseFilterUI 使用
    BrowseFilter.Dungeons = Dungeons
    BrowseFilter.containsValue = containsValue

    -- 构建职业/专精数据（用于职业专精过滤功能）
    -- 存储结构：MEETINGSTONE_CHARACTER_DB.SPEC_FILTER = { [specID] = false } 表示该专精被过滤
    if not MEETINGSTONE_CHARACTER_DB.SPEC_FILTER then
        MEETINGSTONE_CHARACTER_DB.SPEC_FILTER = {}
    end

    if not MEETINGSTONE_UI_DB.DUNGEON_FILTER then
        MEETINGSTONE_UI_DB.DUNGEON_FILTER = {}
    end

    local classSpecData = {}
    local specNameToId = {}      -- [specName] = specID  （可能被同名覆盖，仅作兼容保留）
    local classSpecNameToId = {} -- [classFile][specName] = specID  （精确匹配）
    for ci = 1, GetNumClasses() do
        local className, classFile, classID = GetClassInfo(ci)
        local numSpecs = GetNumSpecializationsForClassID(classID)
        if numSpecs and numSpecs > 0 then
            local specs = {}
            classSpecNameToId[classFile] = classSpecNameToId[classFile] or {}
            for si = 1, numSpecs do
                local specID, specName, _, specIcon = GetSpecializationInfoForClassID(classID, si)
                if specID then
                    specs[#specs + 1] = { id = specID, name = specName, icon = specIcon }
                    specNameToId[specName] = specID
                    classSpecNameToId[classFile][specName] = specID
                end
            end
            classSpecData[#classSpecData + 1] = {
                id = classID, file = classFile, name = className, specs = specs,
            }
        end
    end
    BrowseFilter.ClassSpecData = classSpecData
    BrowseFilter.SpecNameToId = specNameToId
    BrowseFilter.ClassSpecNameToId = classSpecNameToId

    -- 清理脏数据
    for i = #MEETINGSTONE_UI_DB.IGNORE_LIST, 1, -1 do
        local v = MEETINGSTONE_UI_DB.IGNORE_LIST[i]
        if v.leader == nil then
            table.remove(MEETINGSTONE_UI_DB.IGNORE_LIST, i)
        else
            v.titles = nil
            if v.time == true then v.time = '' end
        end
    end

    table.sort(MEETINGSTONE_UI_DB.IGNORE_LIST, function(a, b)
        if a.time == b.time then return a.leader < b.leader end
        if type(a.time) == type(b.time) and type(a.time) == 'string' then
            return a.time > b.time
        end
        return type(a.time) == 'string'
    end)

    -- 初始化屏蔽索引
    BrowsePanel.IgnoreWithTitle = {}
    BrowsePanel.IgnoreWithLeader = {}
    BrowsePanel.IgnoreLeaderOnly = {}
    for _, v in ipairs(MEETINGSTONE_UI_DB.IGNORE_LIST) do
        if v.t == 1 then
            BrowsePanel.IgnoreWithLeader[v.leader] = true
        elseif v.t == 2 then
            BrowsePanel.IgnoreLeaderOnly[v.leader] = true
        end
    end

    if MEETINGSTONE_UI_DB.IGNORE_TIPS_LOG == nil then
        MEETINGSTONE_UI_DB.IGNORE_TIPS_LOG = true
    end
    if MEETINGSTONE_UI_DB.FILTER_MULTY == nil then
        MEETINGSTONE_UI_DB.FILTER_MULTY = true
    end

    -- 职责过滤
    local function CheckJobsFilter(data, tcount, hcount, dcount, activity, isSeasonDungeon)
        if isSeasonDungeon then
            -- M+ 模式：使用本地 state 键，无过滤时全部通过
            if MEETINGSTONE_UI_DB.FILTER_SAME_CLASS then
                local _, myclass = UnitClass('player')
                for i = 1, activity:GetNumMembers() do
                    local _, class = LfgService:GetSearchResultMemberInfo(activity:GetID(), i)
                    if class == myclass then return false end
                end
            end
            local tankState = MEETINGSTONE_UI_DB.FILTER_TANK_STATE
            local healState = MEETINGSTONE_UI_DB.FILTER_HEALER_STATE
            if tankState == 'has' and data.TANK < tcount then return false end
            if tankState == 'needs' and data.TANK >= tcount then return false end
            if healState == 'has' and data.HEALER < hcount then return false end
            if healState == 'needs' and data.HEALER >= hcount then return false end
            if MEETINGSTONE_UI_DB.FILTER_DAMAGE_MPLUS and data.DAMAGER >= dcount then return false end
            return true
        else
            -- 非 M+ 模式：使用原来的 bool 键
            return (not MEETINGSTONE_UI_DB.FILTER_TANK or data.TANK < tcount)
                and (not MEETINGSTONE_UI_DB.FILTER_HEALTH or data.HEALER < hcount)
                and (not MEETINGSTONE_UI_DB.FILTER_DAMAGE or data.DAMAGER < dcount)
                or false
        end
    end

    -- PVP 职责过滤
    local function CheckPVPJobsFilter(data, hcount, dcount)
        if MEETINGSTONE_UI_DB.FILTER_HEALTH and data.HEALER >= hcount then return false end
        if (MEETINGSTONE_UI_DB.FILTER_TANK or MEETINGSTONE_UI_DB.FILTER_DAMAGE) and data.TANK + data.DAMAGER >= dcount then return false end
        return true
    end

    -- 副本过滤（本地）
    local function CheckDungeonsFilter(activity)
        local filter = MEETINGSTONE_UI_DB.DUNGEON_FILTER
        if not next(filter) then return true end
        return filter[activity:GetGroupID()] == true
    end

    -- 注册活动列表过滤器
    BrowsePanel.ActivityList:RegisterFilter(function(activity, ...)
        local leader = activity:GetLeader()
        if leader == nil then return false end

        if BrowsePanel.IgnoreLeaderOnly[leader] then
            local notInList = true
            for _, v in ipairs(MEETINGSTONE_UI_DB.IGNORE_LIST) do
                if v.leader == leader then
                    notInList = false; break
                end
            end
            if notInList then
                table.insert(MEETINGSTONE_UI_DB.IGNORE_LIST, 1, {
                    leader = leader,
                    time = date('%Y-%m-%d %H:%M', time()),
                    dep = '由指定队长名屏蔽',
                    t = 2,
                })
            end
            return false
        end

        local data = C_LFGList.GetSearchResultMemberCounts(activity:GetID())
        if data then
            local activityItem = BrowsePanel.ActivityDropdown:GetItem()
            if not activityItem then return true end

            local categoryId = activityItem.categoryId
            local activityId = activityItem.activityId

            if activity:IsSelf() or activity:IsAnyFriend() or activity:IsInActivity() or activity:IsApplication() then
                return true
            end

            -- 修复自定义搜索文本时会有不对应的内容出现
            if categoryId ~= activity:GetCategoryID() then return false end

            if activityItem.value == 'mplus' and not CheckDungeonsFilter(activity) then
                return false
            end

            -- 任务1 地下堡121 地下城2 团队3 jjc4 评级9 自定义6
            if categoryId == 2 then
                if not CheckJobsFilter(data, 1, 1, 3, activity, activityItem.value == 'mplus') then return false end
            elseif categoryId == 3 then
                if not CheckJobsFilter(data, 2, 6, 22) then return false end
            elseif categoryId == 4 then
                if activityId == 6 and not CheckPVPJobsFilter(data, 1, 2) then return false end
                if activityId == 7 and not CheckPVPJobsFilter(data, 1, 3) then return false end
            elseif categoryId == 9 then
                if not CheckPVPJobsFilter(data, 3, 7) then return false end
            end
        end

        if Profile:GetEnableIgnoreTitle() then
            local title = activity:GetSummary()
            if BrowsePanel.IgnoreWithTitle[title] then
                if not BrowsePanel.IgnoreWithLeader[leader] then
                    BrowsePanel.IgnoreWithLeader[leader] = true
                    table.insert(MEETINGSTONE_UI_DB.IGNORE_LIST, 1, {
                        leader = leader,
                        time = date('%Y-%m-%d %H:%M', time()),
                        dep = '由指定标题传染屏蔽',
                        t = 1,
                    })
                    if MEETINGSTONE_UI_DB.IGNORE_TIPS_LOG then
                        print('标题 ' .. title .. ' 传染屏蔽 ' .. leader)
                    end
                end
                return false
            end
        end

        if BrowsePanel.IgnoreWithLeader[leader] then return false end

        if MEETINGSTONE_UI_DB['SCORE'] then
            if not activity:GetLeaderScore() or activity:GetLeaderScore() < MEETINGSTONE_UI_DB['SCORE'] then
                return false
            end
        end

        if BrowsePanel.ActivityDropdown:GetText() == activitytypeText1 and BrowsePanel.MDSearchs then
            if not BrowsePanel.MDSearchs[activity:GetName()] then return false end
        end

        local hasBloodlust, hasBrez = false, false
        for i = 1, activity:GetNumMembers() do
            local _, classFile, _, specLocalized = LfgService:GetSearchResultMemberInfo(activity:GetID(), i)
            if specLocalized == '初始' and next(MEETINGSTONE_CHARACTER_DB.SPEC_FILTER) then return false end
            if classFile then
                hasBloodlust = hasBloodlust or BLOODLUST_CLASSES[classFile] or false
                hasBrez      = hasBrez or BREZ_CLASSES[classFile] or false
            end
            -- 职业专精过滤：优先用 classFile+specName 精确匹配，避免同名专精（恢复/奥法等）误筛
            if specLocalized and next(MEETINGSTONE_CHARACTER_DB.SPEC_FILTER) then
                local specID = (classFile and classSpecNameToId[classFile] and classSpecNameToId[classFile][specLocalized])
                    or specNameToId[specLocalized]
                if specID and MEETINGSTONE_CHARACTER_DB.SPEC_FILTER[specID] == false then
                    return false
                end
            end
        end
        -- 嗜血/英勇过滤
        if MEETINGSTONE_UI_DB.FILTER_BLOODLUST_STATE == 'has' and not hasBloodlust then return false end
        if MEETINGSTONE_UI_DB.FILTER_BLOODLUST_STATE == 'needs' and hasBloodlust then return false end
        -- 战斗复活过滤
        if MEETINGSTONE_UI_DB.FILTER_BREZ_STATE == 'has' and not hasBrez then return false end
        if MEETINGSTONE_UI_DB.FILTER_BREZ_STATE == 'needs' and hasBrez then return false end
        -- 屏蔽只缺嗜血队伍：人数=4 且无嗜血职业
        if MEETINGSTONE_UI_DB.FILTER_HIDE_ONLY_NEED_BLOODLUST then
            if activity:GetNumMembers() == 4 and not hasBloodlust then return false end
        end

        return activity:Match(...)
    end)

    -- Remix 模式检测
    local isRemixChecked = false
    local function checkRemix()
        if isRemixChecked then return end
        local isRemix = C_UnitAuras.GetPlayerAuraBySpellID(1213439)
        if isRemix then
            MEETINGSTONE_CHARACTER_DB.Remix = true
            isRemixChecked = true
        else
            MEETINGSTONE_CHARACTER_DB.Remix = false
        end
    end
    local remixChecker = CreateFrame('Frame', nil, UIParent)
    remixChecker:RegisterEvent('PLAYER_ENTERING_WORLD')
    remixChecker:RegisterEvent('ADDON_LOADED')
    remixChecker:RegisterEvent('PLAYER_LOGIN')
    remixChecker:SetScript('OnEvent', checkRemix)

    -- 申请结果通知
    local lfgStatusFrame = CreateFrame('Frame', nil, UIParent)
    lfgStatusFrame:RegisterEvent('LFG_LIST_APPLICATION_STATUS_UPDATED')
    lfgStatusFrame:SetScript('OnEvent', function(_, _, resultid, status, _, title)
        if not resultid or status ~= 'inviteaccepted' then return end
        local info = C_LFGList.GetSearchResultInfo(resultid)
        local activityID
        for _, v in pairs(info.activityIDs) do
            activityID = v; break
        end
        if not activityID then return end
        local name = C_LFGList.GetActivityFullName(activityID) or '未知活动'
        print('>>>> 队伍详情：' .. name .. ' - ' .. (title or ''))
    end)

    BrowsePanel:InitExtension()
end
