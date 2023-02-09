local function getIndex()
    local hl, al, il = createStringList(), getAddressList(), {}
    for i = 0, al.count - 1 do
        local mr = al[i]
        local isHotkey = (0 < mr.HotkeyCount)
        local str = isHotkey and ('%s: %s'):format(mr.Hotkey[0].hotkeyString, mr.description)
        if str then hl.add(str); il[#il + 1] = mr.index end
    end
    local id = showSelectionList('Hotkeys', '', hl)
    hl.destroy()
    return (-1 < id) and il[id + 1]
end
---------------------------------------------------------------------------------------------------
local function viewSetHotkeys()
    local index = getIndex()
    if not index then return end
    local al, mf = getAddressList(), getMainForm()
    al.setSelectedRecord(al[index])
    MainForm.SetHotkey1.doClick()
end
---------------------------------------------------------------------------------------------------
local function cleanHotkeys(mr)
    if not (0 < mr.HotkeyCount) then return end
    for i = 0, mr.HotkeyCount - 1 do mr.Hotkey[i].destroy() end
end
---------------------------------------------------------------------------------------------------
local function cleanAllHotkeys()
    local al = getAddressList()
    for i = 0, al.count - 1 do cleanHotkeys(al[i]) end
end
---------------------------------------------------------------------------------------------------
local function findHotkeyInfoItem(str)
    local mf = getMainForm()
    for i = mf.Menu.Items.count - 1, 0, -1 do
        local caption = mf.Menu.Items[i].caption
        if (caption == str) then return mf.Menu.Items[i].caption end
    end
end
---------------------------------------------------------------------------------------------------
local function addListViewMenu(Item)
    local ListViewMenu = createMenuItem(Item)
    Item.add(ListViewMenu)
    ListViewMenu.caption = 'List view'
    ListViewMenu.onClick = viewSetHotkeys
end
---------------------------------------------------------------------------------------------------
local function addCleanAllMenu(Item)
    local CleanAllMenu = createMenuItem(Item)
    Item.add(CleanAllMenu)
    CleanAllMenu.caption = 'Clean all'
    CleanAllMenu.onClick = cleanAllHotkeys
end
---------------------------------------------------------------------------------------------------
local function addHotkeys()
    if findHotkeyInfoItem('&Hotkeys') then return end
    local HotKeyInfoItem = createMenuItem(MainForm.Menu.Items)
    MainForm.Menu.Items.add(HotKeyInfoItem)
    HotKeyInfoItem.caption = '&Hotkeys'
    addListViewMenu(HotKeyInfoItem); addCleanAllMenu(HotKeyInfoItem)
end
---------------------------------------------------------------------------------------------------
return addHotkeys()