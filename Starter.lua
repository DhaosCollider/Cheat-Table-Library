-- Released Starter.lua under the MIT license
-- Copyright (c) 2022 DhaosCollider
-- https://opensource.org/licenses/mit-license.php
---------------------------------------------------------------------------------------------------
local Obj = {}
---------------------------------------------------------------------------------------------------
function Obj.onEnable(MainForm, AddressList, process)
    local success = readInteger(process) or pcall(synchronize, MainForm.sbOpenProcess.doClick)
    local startTime = assert(success, 'Error: MainForm.sbOpenProcess.doClick') and os.clock()
    Obj.log(('The table has %d options.'):format(Obj.getTableOptionCount(AddressList)))
    AddressList.rebuildDescriptionCache()
    local mr, msg = AddressList.getMemoryRecordByID(777), "Activate table settings."
    mr.description = "<< "..msg
    Obj.log(msg.."\n")
    local setting = AddressList.getMemoryRecordByID(10000)
    setting.active = true
    local sec = (' (%.2fs)'):format(os.clock() - startTime)
    local isActive = setting.active and "completed." or "unfinished."
    Obj.log(setting.description.." Setup "..isActive..sec.."\n")
    mr.description, mr.color = '>> '..setting.description, Obj.enabledColor
end
---------------------------------------------------------------------------------------------------
function Obj.onDisable(AddressList)
    AddressList.rebuildDescriptionCache()
    local al, info = AddressList.getMemoryRecordByID(777), "Initialize table settings."
    al.description = ">> "..info
    Obj.log(info.."\n"); Obj.removeAdvOptions(); Obj.removeStructures()
    local setting = AddressList.getMemoryRecordByID(10000)
    setting.active = false
    local msg = not setting.active and "completed." or "unfinished."
    local sec = (' (%.2fs)'):format(al.asyncProcessingTime / 1000)
    Obj.log("Initialization "..msg..sec.."\n")
    al.description, al.color = "<< Check the box.", Obj.disabledColor
end
---------------------------------------------------------------------------------------------------
function Obj.recommandInit(sender)
    -- Thanks: https://forum.cheatengine.org/viewtopic.php?t=602700
    local al = AddressList.getMemoryRecordByID(777)
    if not al then Obj.onClose(sender); return caFree end
    if not al.active then Obj.onClose(sender); return caFree end
    local msg = "Initializing the table settings is highly recommended.\nInitialize table settings?"
    local ret = messageDialog(msg, 3, 0, 1)
    if not (ret == mrYes) then Obj.onClose(sender); return caFree end
    al.active = false
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
function Obj.onLoad(AddressList, description)
    if not AddressList[description].script:find('Register') then return end
    AddressList[description].active = (messageDialog('Load Checkbox States?', 3, 0, 1) == mrYes)
end
---------------------------------------------------------------------------------------------------
function Obj.log(...) return Obj.isDebug and print(...) end
---------------------------------------------------------------------------------------------------
return Obj
---------------------------------------------------------------------------------------------------
