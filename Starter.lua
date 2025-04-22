-- Released Starter.lua under the MIT license
-- Copyright (c) 2022 DhaosCollider
-- https://opensource.org/licenses/mit-license.php
---------------------------------------------------------------------------------------------------
local Obj = {}
---------------------------------------------------------------------------------------------------
function Obj.onEnable(MainForm, AddressList)
    local time = os.clock()
    assert(getAddressSafe('$process'), translate(MainForm.sbOpenProcess.hint))
    print(('The table has %d options.'):format(Obj.getTableOptionCount(AddressList)))
    local mr, msg = AddressList.getMemoryRecordByID(777), "Activate table settings."
    mr.description = "<< "..msg
    print(msg.."\n")
    local setting = AddressList.getMemoryRecordByID(10000)
    setting.active = true
    local sec = (' (%.2fs)'):format(os.clock() - time)
    local isActive = setting.active and "completed." or "unfinished."
    print(setting.description.." Setup "..isActive..sec.."\n")
    mr.description, mr.color = '>> '..setting.description, Obj.enabledColor
    return Obj.isDebug or getLuaEngine().hide()
end
---------------------------------------------------------------------------------------------------
function Obj.onDisable(AddressList)
    local time = os.clock()
    AddressList.rebuildDescriptionCache()
    local al, info = AddressList.getMemoryRecordByID(777), "Initialize table settings."
    al.description = ">> "..info
    print(info.."\n"); synchronize(Obj.removeAdvOptions); synchronize(Obj.removeStructures)
    local setting = AddressList.getMemoryRecordByID(10000)
    setting.active = false
    local msg = not setting.active and "completed." or "unfinished."
    local sec = (' (%.2fs)'):format(os.clock() - time)
    print("Initialization "..msg..sec.."\n")
    al.description, al.color = "<< Check the box.", Obj.disabledColor
    return Obj.isDebug or getLuaEngine().hide()
end
---------------------------------------------------------------------------------------------------
function Obj.recommandInit(sender)
    -- Thanks: https://forum.cheatengine.org/viewtopic.php?t=602700
    if not readInteger("$process") then return closeCE() end
    local al = AddressList.getMemoryRecordByID(777)
    if not al then Obj.onClose(sender); return caFree end
    if not al.active then Obj.onClose(sender); return caFree end
    local msg = "Initializing the table settings is highly recommended.\nInitialize table settings?"
    local ret = messageDialog(msg, 3, 0, 1)
    if not (ret == mrYes) then Obj.onClose(sender); return caFree end
    al.active = false
end
---------------------------------------------------------------------------------------------------
-- showSelectionList functions
---------------------------------------------------------------------------------------------------
local function showDropdown(memrec)
    local desc = ("Selection List : %s"):format(memrec.description)
    local id, str = showSelectionList(desc, '', memrec.DropdownList)
    if (-1 < id) then return str:match('^(.+):'), str:match(':(.+)$') end
end

function Obj.showSelectionList(list, row)
    if not (32 < row.DropDownCount) then return end
    local isLinked = not (row.DropDownLinkedMemrec == '')
    local str = showDropdown(isLinked and list[row.DropDownLinkedMemrec] or row)
    if str then row.value = str end
end
---------------------------------------------------------------------------------------------------
function Obj.addPointerHeaderDescriptions(list, row)
    if not row.isAddressGroupHeader then return end
    if (row.OffsetCount == 0) and string.find(row.description, "P->") then return end
    row.description = string.match(row.description, "Group %d+") and "P->" or row.description
end
---------------------------------------------------------------------------------------------------
function Obj.changeTAddressListControl()
    local al = assert(getAddressList(), "changeTAddressListControl interrupted")
    al.onDescriptionChange = Obj.addPointerHeaderDescriptions
    al.onValueChange = Obj.showSelectionList
    al.Control[0].backgroundColor = darkMode() and 0x282020 or 0xE8F0F0
end
---------------------------------------------------------------------------------------------------
function Obj.getTForm(name)
    for i = 0, getFormCount() - 1 do
        local TForm = getForm(i)
        if (TForm.className == name) then return TForm end
    end
end
---------------------------------------------------------------------------------------------------
function Obj.removeAdvOptions()
    local ao = Obj.getTForm("TAdvancedOptions")
    if not ao or (ao.LvCodelist.Items.count == 0) then return end
    local msg = "Remove Advanced options?"
    if not (messageDialog(msg, 3, 0, 1) == mrYes) then return end
    ao.LvCodelist.Items.clear()
    return Obj.log("Removed Advanced options.\n")
end
---------------------------------------------------------------------------------------------------
function Obj.removeStructures()
    local sc = getStructureCount()
    if (sc == 0) then return end
    local msg = "Remove Dissect data/structures?"
    if not (messageDialog(msg, 3, 0, 1) == mrYes) then return end
    for i = sc - 1, 0, -1 do
        local st = getStructure(i)
        if st then st.removeFromGlobalStructureList() end
    end
    return Obj.log("Removed Dissect data/structures.\n")
end
---------------------------------------------------------------------------------------------------
function Obj.getTableOptionCount(AddressList)
    local setting = AddressList.getMemoryRecordByID(10000)
    if not setting then return end
    local count = 0
    for i = 1, setting.index - 2 do
        local al = AddressList[i]
        local isHeader = al.isAddressGroupHeader or al.isGroupHeader
        if not isHeader then count = count + 1 end
    end
    return count
end
---------------------------------------------------------------------------------------------------
function Obj.getCheatTableName(path)
    return path and path:match("\\([^\\]+)$") or 'Cheat Table'
end
---------------------------------------------------------------------------------------------------
function Obj.onLoad(loadMemrec)
    if not loadMemrec.script:find('Register') then return end
    synchronize(function()
        loadMemrec.active = (messageDialog('Load Checkbox States?', 3, 0, 1) == mrYes)
    end)
end
---------------------------------------------------------------------------------------------------
function Obj.lanchBrowser(url, info)
    assert(url:match("^http") or url:match("^www"), "Invalid URL.")
    if not (type(info) == "string") then return shellExecute(url) end
    synchronize(function()
        return (messageDialog(info, 3, 0, 1) == mrYes) and shellExecute(url)
    end)
end
---------------------------------------------------------------------------------------------------
Obj.info = [[
⡀⡀⡀⡀⡀⡀⡀⡀⡀⡀⡀⡀⡀⠸⣿⣿⣿⣿⣿⣿⣿⣿⣶⡀⡀⡀⡀⡀⡀⣿⣿⡏⡀⡀⡀⡀⡀⡀⡀⡀⡀⡀⡀⡀⡀⡀⡀⡀⡀⡀⡀⡀⡀⡀⡀⡀⡀⡀⡀⡀⡀⡀⡀⡀⡀⡀⡀⡀⡀⡀⡀⡀⡀⡀⡀⡀⡀⡀⡀
⡀⡀⡀⡀⡀⡀⡀⡀⡀⡀⡀⡀⡀⡀⡀⣿⣿⣿⡀⡀⠙⢿⣿⣿⣆⡀⡀⡀⢸⣿⣿⡀⡀⡀⡀⡀⡀⡀⡀⡀⡀⡀⣀⣠⣤⣤⣤⡀⡀⡀⡀⡀⡀⣠⣴⣶⣶⣤⡀⡀⡀⡀⡀⢀⣴⣶⣶⣦⡀⡀⡀⡀⡀⡀⡀⡀⡀⡀⡀
⡀⡀⡀⡀⡀⡀⡀⡀⡀⡀⡀⡀⡀⡀⢰⣿⣿⠃⡀⡀⡀⡀⠹⣿⣿⡀⡀⡀⣿⣿⡟⡀⣠⣶⣶⣶⡆⡀⡀⡀⣠⣿⣿⣿⠿⣿⣿⡇⡀⡀⡀⣴⣿⣿⣿⣿⣿⣿⣧⡀⡀⣠⣿⣿⣿⠟⠿⣿⡀⡀⡀⡀⡀⡀⡀⡀⡀⡀⡀
⡀⡀⡀⡀⡀⡀⡀⡀⡀⡀⡀⡀⡀⡀⣿⣿⣿⡀⡀⡀⡀⡀⡀⣿⣿⡀⡀⢠⣿⣿⣵⣿⣿⠿⣿⣿⡏⡀⡀⣼⣿⣿⠋⡀⢸⣿⣿⡀⡀⡀⣾⣿⣿⠋⡀⡀⣹⣿⣿⡀⡀⣿⣿⣏⡀⡀⡀⡀⡀⡀⡀⡀⡀⡀⡀⡀⡀⡀⡀
⡀⡀⡀⡀⡀⡀⡀⡀⡀⡀⡀⡀⡀⢀⣿⣿⠇⡀⡀⡀⡀⡀⣼⣿⣿⡀⡀⣾⣿⣿⣿⠟⡀⣼⣿⣿⡀⡀⣰⣿⣿⠁⡀⣠⣿⣿⡏⡀⡀⣾⣿⡿⡀⡀⡀⡀⣿⣿⡟⡀⡀⠙⢿⣿⣿⣿⣦⡀⡀⡀⡀⡀⡀⡀⡀⡀⡀⡀⡀
⡀⡀⡀⡀⡀⡀⡀⡀⡀⡀⡀⡀⡀⣼⣿⣿⡀⡀⡀⢀⣴⣿⣿⣿⠁⡀⡀⣿⣿⣿⠃⡀⢀⣿⣿⡇⡀⡀⣿⣿⠇⢀⣾⣿⣿⣿⡀⡀⡀⣿⣿⠁⡀⡀⢀⣾⣿⡿⡀⡀⡀⠐⡀⡀⢙⣿⣿⡀⡀⡀⡀⡀⡀⡀⡀⡀⡀⡀⡀
⡀⡀⡀⡀⡀⡀⡀⡀⡀⡀⡀⡀⡀⣿⣿⣏⣠⣴⣾⣿⣿⣿⠟⡀⡀⡀⣸⣿⣿⠁⡀⡀⣾⣿⣿⡀⡀⡀⢿⣿⣿⣿⣿⣿⣿⣿⡀⡀⡀⣿⣿⣷⣤⣶⣿⣿⠟⡀⡀⡀⣶⣶⣾⣿⣿⣿⠋⡀⡀⡀⡀⡀⡀⡀⡀⡀⡀⡀⡀
⡀⡀⡀⡀⡀⡀⡀⡀⡀⡀⣰⣿⣿⣿⣿⣿⣿⣿⡿⠛⠉⡀⡀⡀⡀⡀⠻⠿⠏⡀⡀⡀⠿⣿⠿⡀⡀⡀⡀⠉⠉⠁⡀⠛⠛⠃⡀⡀⡀⠈⠻⠿⠿⠿⠛⠁⡀⡀⡀⡀⠉⠛⠛⠋⠁⡀⡀⡀⡀⡀⡀⡀⡀⡀⡀⡀⡀⡀⡀
⡀⡀⡀⡀⡀⡀⡀⡀⡀⡀⠙⠛⠛⠛⠋⠉⡀⡀⡀⡀⡀⡀⡀⡀⡀⡀⡀⡀⡀⡀⡀⡀⡀⡀⡀⡀⡀⡀⡀⡀⡀⡀⡀⡀⡀⡀⡀⡀⡀⡀⡀⡀⡀⡀⡀⡀⡀⡀⡀⡀⡀⡀⡀⡀⡀⡀⡀⡀⡀⡀⡀⡀⡀⡀⡀⡀⡀⡀⡀
]]
---------------------------------------------------------------------------------------------------
function Obj.log(...) return Obj.isDebug and print(...) end
---------------------------------------------------------------------------------------------------
return Obj
---------------------------------------------------------------------------------------------------
