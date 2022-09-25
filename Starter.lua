-- Released Starter.lua under the MIT license
-- Copyright (c) 2022 DhaosCollider
-- https://opensource.org/licenses/mit-license.php

local Obj = {}

function Obj.onEnable()
    AddressList.rebuildDescriptionCache()
    local al, msg = AddressList.getMemoryRecordByID(777), "Activate table settings."
    synchronize(function() al.description = "<< "..msg end)
    Obj.log(msg.."\n")
    local setting = AddressList.getMemoryRecordByID(10000)
    setting.active = true
    msg = setting.active and "completed." or "unfinished."
    local sec = (' (%.2fs)'):format(al.asyncProcessingTime / 1000)
    Obj.log(setting.description.." Setup "..msg..sec.."\n")
    synchronize(function()
        al.description, al.color = '>> '..setting.description, Obj.enabledColor
    end)
end

function Obj.onDisable()
    AddressList.rebuildDescriptionCache()
    local al, msg = AddressList.getMemoryRecordByID(777), "Initialize table settings."
    synchronize(function() al.description = ">> "..msg end)
    Obj.log(msg.."\n"); Obj.removeAdvOptions(); Obj.removeStructures()
    msg = Obj.initializeTableSettings() and "completed." or "unfinished."
    local sec = (' (%.2fs)'):format(al.asyncProcessingTime / 1000)
    Obj.log("Initialization "..msg..sec.."\n")
    synchronize(function()
        al.description, al.color = "<< Check the box.", Obj.disabledColor
    end)
end

function Obj.initializeTableSettings()
    local state = true
    local setting = AddressList.getMemoryRecordByID(10000)
    local setEnd  = setting[setting.count - 1]
    if not (setting and setEnd) then setting.active = false return end
    for i = 1, AddressList.count - 1 do
        local al = AddressList[i]
        if not (al.type == vtAutoAssembler) then goto continue end
        local startIndex, endIndex = setting.index - 1, setEnd.index
        if not ((al.index < startIndex) or (al.index > endIndex)) then goto continue end
        al.active = false
        local str = al.active and "Failed" or "Disabled"
        Obj.log(str..": "..al.description)
        if al.active then state = false end
        ::continue::
    end
    setting.active = false
    return state
end

function Obj.recommandInit(sender)
    -- Thanks: https://forum.cheatengine.org/viewtopic.php?t=602700
    local al = AddressList.getMemoryRecordByID(777)
    if not al.active then Obj.onClose(sender); return caFree end
    local msg = "Initializing the table settings is highly recommended.\nInitialize table settings?"
    local ret = messageDialog(msg, 3, 0, 1)
    if not (ret == mrYes) then Obj.onClose(sender); return caFree end
    al.active = false
end

function Obj.getTForm(name)
    for i = 0, getFormCount() - 1 do
        local TForm = getForm(i)
        if (TForm.className == name) then return TForm end
    end
end

function Obj.removeAdvOptions()
    local ao = Obj.getTForm("TAdvancedOptions")
    if not ao or (ao.LvCodelist.Items.count == 0) then return end
    local msg = "Remove Advanced options?"
    if not (messageDialog(msg, 3, 0, 1) == mrYes) then return end
    ao.LvCodelist.Items.clear()
    return Obj.log("Removed Advanced options.\n")
end

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

function Obj.autoCompactMode(state)
    Obj.publicMemrecUpdate()
    local mr = AddressList["Cheat Engine: Compact Mode"]
    if not mr then return end
    mr.active = not Obj.isDebug and state
end

function Obj.publicMemrecUpdate()
    local mc = Obj.publicMemrecCount()
    local isUpdate = not (Obj.saveCount == mc)
    Obj.saveCount = isUpdate and mc or Obj.saveCount
    return isUpdate and Obj.log(Obj.saveCount.." memory records have been published.\n")
end

function Obj.publicMemrecCount()
    local setting = AddressList.getMemoryRecordByID(10000)
    if not setting then return end
    local setEnd = setting[setting.count - 1]
    return (AddressList.count - 1) - (setEnd.index - (setting.index - 1))
end

function Obj.getCheatTableName(path)
    return path and path:match("\\([^\\]+)$") or 'Cheat Table'
end

function Obj.log(...)
    return Obj.isDebug and print(...)
end

return Obj