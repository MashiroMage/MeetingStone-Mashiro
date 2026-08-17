-- ScanDump.lua: 调试工具，显示副本 Group ID / Activity ID

local function BuildScanText()
    local lines = {}
    local function add(s) lines[#lines + 1] = s end

    -- ① 团队副本 Groups
    add("===== [团本 Groups] category=3 =====")
    local raidGroups = C_LFGList.GetAvailableActivityGroups(3)
    for _, g in ipairs(raidGroups) do
        local name = C_LFGList.GetActivityGroupInfo(g)
        add(string.format("G=%-4d  %s", g, tostring(name)))
    end

    -- ② 团队副本高ID Activities（只看1700以上的新内容）
    add("")
    add("===== [团本新内容 ActID>=1700] =====")
    local raidActs = C_LFGList.GetAvailableActivities(3)
    for _, id in ipairs(raidActs) do
        if id >= 1700 then
            local info = C_LFGList.GetActivityInfoTable(id)
            if info and info.fullName and #info.fullName > 0 then
                add(string.format("ActID=%-5d  G=%-4d  %s",
                    id, info.groupFinderActivityGroupID or 0, info.fullName))
            end
        end
    end

    -- ③ 暴力扫描高ID活动（1900-2200），找新团本/新地下城
    add("")
    add("===== [暴力扫描 ActID 1900-2200，category=任意] =====")
    for id = 1900, 2200 do
        local ok, info = pcall(C_LFGList.GetActivityInfoTable, id)
        if ok and info and info.fullName and #info.fullName > 0 then
            add(string.format("ActID=%-5d  G=%-4d  cat=%-3d  %s",
                id,
                info.groupFinderActivityGroupID or 0,
                info.categoryID or 0,
                info.fullName))
        end
    end

    -- ④ 地下城所有 Groups（找BFA回归副本 诸王之眠/塞塔里斯）
    add("")
    add("===== [地下城 Groups] category=2 =====")
    local dungGroups = C_LFGList.GetAvailableActivityGroups(2)
    for _, g in ipairs(dungGroups) do
        local name = C_LFGList.GetActivityGroupInfo(g)
        add(string.format("G=%-4d  %s", g, tostring(name)))
    end

    -- ⑤ 地下城所有 Activities（不过滤M+，找诸王之眠/塞塔里斯的 GroupID）
    add("")
    add("===== [地下城 Activities ActID>=1700 OR 含关键词] =====")
    local dungActs = C_LFGList.GetAvailableActivities(2)
    for _, id in ipairs(dungActs) do
        local info = C_LFGList.GetActivityInfoTable(id)
        if info and info.fullName and #info.fullName > 0 then
            local name = info.fullName
            local isNew = id >= 1700
            local isKeyword = name:find("诸王") or name:find("塞塔") or
                              name:find("毒牙") or name:find("Altar") or
                              name:find("King") or name:find("Sethr") or
                              name:find("Ruby") or name:find("红玉")
            if isNew or isKeyword then
                add(string.format("ActID=%-5d  G=%-4d  M+=%s  %s",
                    id,
                    info.groupFinderActivityGroupID or 0,
                    tostring(info.isMythicPlusActivity or false),
                    name))
            end
        end
    end

    return table.concat(lines, "\n")
end

local function CreateDebugWindow()
    local frame = CreateFrame("Frame", "MSScanDumpFrame", UIParent, "BackdropTemplate")
    frame:SetSize(620, 500)
    frame:SetPoint("CENTER")
    frame:SetFrameStrata("DIALOG")
    frame:SetMovable(true)
    frame:EnableMouse(true)
    frame:RegisterForDrag("LeftButton")
    frame:SetScript("OnDragStart", frame.StartMoving)
    frame:SetScript("OnDragStop", frame.StopMovingOrSizing)
    frame:SetBackdrop({
        bgFile   = "Interface\\DialogFrame\\UI-DialogBox-Background",
        edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
        tile = true, tileSize = 32, edgeSize = 32,
        insets = { left = 11, right = 12, top = 12, bottom = 11 },
    })

    local title = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightLarge")
    title:SetPoint("TOP", frame, "TOP", 0, -16)
    title:SetText("|cffFFD700MeetingStone ScanDump|r  |cffAAAAAA点击文本框 → Ctrl+A → Ctrl+C 复制|r")

    local closeBtn = CreateFrame("Button", nil, frame, "UIPanelCloseButton")
    closeBtn:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -5, -5)
    closeBtn:SetScript("OnClick", function() frame:Hide() end)

    local refreshBtn = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
    refreshBtn:SetSize(80, 22)
    refreshBtn:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -18, 14)
    refreshBtn:SetText("刷新")

    local scrollFrame = CreateFrame("ScrollFrame", nil, frame, "UIPanelScrollFrameTemplate")
    scrollFrame:SetPoint("TOPLEFT",     frame, "TOPLEFT",  18, -44)
    scrollFrame:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -36, 42)

    local editBox = CreateFrame("EditBox", nil, scrollFrame)
    editBox:SetWidth(scrollFrame:GetWidth() - 4)
    editBox:SetHeight(1)
    editBox:SetMultiLine(true)
    editBox:SetAutoFocus(false)
    editBox:SetFontObject(GameFontHighlightSmall)
    editBox:SetScript("OnEscapePressed", function() frame:Hide() end)
    scrollFrame:SetScrollChild(editBox)

    local function Refresh()
        local text = BuildScanText()
        editBox:SetText(text)
        editBox:SetHeight(math.max(editBox:GetStringHeight() + 10, scrollFrame:GetHeight()))
    end

    refreshBtn:SetScript("OnClick", Refresh)
    Refresh()
    return frame
end

local f = CreateFrame("Frame")
f:RegisterEvent("PLAYER_ENTERING_WORLD")
f:SetScript("OnEvent", function(self, event, isLogin, isReload)
    if not (isLogin or isReload) then return end
    self:UnregisterAllEvents()
    C_Timer.After(3, function()
        local win = CreateDebugWindow()
        win:Show()
        print("|cffFFD700[ScanDump]|r 窗口已打开，点击文本框后 Ctrl+A → Ctrl+C 复制全部内容")
    end)
end)
