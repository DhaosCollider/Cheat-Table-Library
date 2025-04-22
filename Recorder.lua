-- Released Recorder.lua under the MIT license
-- Copyright (c) 2022 Dhaos
-- https://opensource.org/licenses/mit-license.php
---------------------------------------------------------------------------------------------------
local Obj = {}
---------------------------------------------------------------------------------------------------
-- Functions that return Hex strings
---------------------------------------------------------------------------------------------------
function Obj.uint8_t(startAddress)
    local addr = getAddressSafe(startAddress)
    return addr and ('%X'):format(readBytes(addr)) or '??'
end

function Obj.uint16_t(startAddress)
    local addr = getAddressSafe(startAddress)
    return addr and ('%X'):format(readSmallInteger(addr)) or '??'
end

function Obj.uint32_t(startAddress)
    local addr = getAddressSafe(startAddress)
    return addr and ('%X'):format(readInteger(addr)) or '??'
end

function Obj.uint64_t(startAddress)
    local addr = getAddressSafe(startAddress)
    return addr and ('%X'):format(readQword(addr)) or '??'
end

function Obj.getStaticAddress(startAddress, plusOffset)
    if not (targetIs64Bit() and getAddressSafe(startAddress)) then return '??' end
    local addr = getAddressSafe(startAddress)
    local cap  = readInteger(addr, true) + 0x04
    local offs = plusOffset and (plusOffset + cap) or cap
    return (addr and offs) and ('%X'):format((addr + offs)) or '??'
end
---------------------------------------------------------------------------------------------------
function Obj.extractHexOffsetToNumber(record)
    local str = record.address
    return (str == "") and 0 or tonumber("0x"..str:match("^%+(%x+)"))
end
---------------------------------------------------------------------------------------------------
function Obj.createHeader(parent, description, address)
    local mr = getAddressList().createMemoryRecord()
    mr.appendToEntry(parent)
    mr.description = description or "Undefined"
    if address then mr.address = address; mr.isAddressGroupHeader = true end
    if not address then mr.isGroupHeader = true end
    mr.color = address and clOlive or clGray
    mr.options = '[moHideChildren]'
    return mr
end
---------------------------------------------------------------------------------------------------
function Obj.createChild(parent, description, address)
    local mr = getAddressList().createMemoryRecord()
    mr.appendToEntry(parent)
    mr.description = description or "Undefined"
    mr.address = address
    return mr
end
---------------------------------------------------------------------------------------------------
function Obj.getChild(parent, childName)
    for i = 0, parent.count - 1 do
        local name = parent.Child[i].description
        if (name == childName) then return parent.Child[i] end
    end
end
---------------------------------------------------------------------------------------------------
function Obj.extractClassName(memrec)
    -- Extract from description (Pointer-> or P->)
    local cName = memrec.description:match('->(.-)%p%d+%p$')
    return cName or memrec.description:match('->(.+)') or memrec.description
end
---------------------------------------------------------------------------------------------------
function Obj.mono_getStaticAddress(namespace, className)
    local cid = mono_findClass(namespace, className)
    return mono_class_getStaticFieldAddress('', cid)
end
---------------------------------------------------------------------------------------------------
-- mono_createChildren functions
---------------------------------------------------------------------------------------------------
local function createMemberVariable(parent, member)
    if member.isStatic then return end
    local isType = (0x01 < member.monotype) and (member.monotype < 0x0E)
    if not isType then return end
    local mr = getAddressList().createMemoryRecord()
    mr.appendToEntry(parent)
    mr.description = member.name:match('^<(.+)>') or member.name
    mr.varType = monoTypeToVarType(member.monotype)
    mr.address = ('+%02X'):format(member.offset)
    mr.showAsSigned = true
end

function Obj.mono_createChildren(namespace, parent)
    local cName = Obj.extractClassName(parent)
    if not cName then return end
    local cid = mono_findClass(namespace, cName)
    local tbl = mono_class_enumFields(cid, true)
    for i = 1, #tbl do createMemberVariable(parent, tbl[i]) end
end

function Obj.mono_createChildrenByImage(imageName, parent)
    local cName = Obj.extractClassName(parent)
    if not cName then return end
    local cid = mono_findClassByImage(imageName, cName)
    local tbl = mono_class_enumFields(cid, true)
    for i = 1, #tbl do createMemberVariable(parent, tbl[i]) end
end
---------------------------------------------------------------------------------------------------
function Obj.removeChildren(parent)
    for i = parent.count - 1, 0, -1 do
        local isScript = (parent[i].type == vtAutoAssembler)
        if not ((parent[i].OffsetCount > 0) or isScript) then parent[i].destroy() end
    end
end
---------------------------------------------------------------------------------------------------
function Obj.writeAddress(memrec, address, tbl)
    if not memrec then return end
    memrec.address = address
    if not tbl then return end
    memrec.OffsetCount = #tbl
    for i = 1, memrec.OffsetCount  do memrec.Offset[i - 1] = tbl[i] end
end
---------------------------------------------------------------------------------------------------
function Obj.addressUpdate(memrec, target, symbolOrAddress, tbl)
    synchronize(function()
        local timer = createTimer(getMainForm())
        local function update(timer)
            if not memrec.active then target.address = nil; return timer.destroy() end
            Obj.writeAddress(target, symbolOrAddress, tbl)
        end
        timer.onTimer, timer.interval = update, 100
    end)
end
---------------------------------------------------------------------------------------------------
function Obj.getAddress(memrec, isSafe)
    local addr = tonumber(memrec.currentAddress)
    if isSafe then return (0 < addr) and addr end
    return assert((0 < addr) and addr, memrec.description..' not loaded.')
end
---------------------------------------------------------------------------------------------------
function Obj.writeValue(memrec, sender)
    local val = (type(sender) == 'userdata') and sender.value or tostring(sender)
    if not (memrec.value == '??') then memrec.value = val end
end
---------------------------------------------------------------------------------------------------
function Obj.inputQueryForAdd(memrec, add)
    return inputQuery(memrec.description, 'Add:', tostring(add))
end
---------------------------------------------------------------------------------------------------
function Obj.showDropdown(memrec)
    local desc = ("Selection List : %s"):format(memrec.description)
    local id, str = showSelectionList(desc, '', memrec.DropdownList)
    return (-1 < id) and str:match('^(.+):'), str:match(':(.+)$')
end
---------------------------------------------------------------------------------------------------
-- sortDropdownListByDropDownValue functions
---------------------------------------------------------------------------------------------------
local function extractDropdownMap(List)
    local tbl = {}
    for i = 0, List.Count - 1 do
        local value, desc = List[i]:match("^([^:]+):(.+)$")
        if value and desc then tbl[value] = desc end
    end
    return tbl
end

function Obj.sortDropdownVal(record, isHex)
    assert(record.DropdownList, "Interrupted: function sortDropdownVal")
    local keys, list = {}, record.DropdownList
    local map = extractDropdownMap(list)
    local function parseValue(v, s) return s and tonumber(v, 16) or tonumber(v) or v end
    for k in pairs(map) do table.insert(keys, k) end
    table.sort(keys, function(a, b) return parseValue(a, isHex) < parseValue(b, isHex) end)
    list.clear()
    for _, k in ipairs(keys) do list.Add(string.format("%s:%s", k, map[k])) end
end
---------------------------------------------------------------------------------------------------
function Obj.findValByDropdownDesc(record, desc)
    local target = (type(desc) == "string") and desc:lower()
    if not target then return end
    for i = 1, #record.DropDownValue do
        local val, str = record.DropDownValue[i], record.DropDownDescription[i]
        if (str:lower() == target) then return val end
    end
end
---------------------------------------------------------------------------------------------------
function Obj.findDescByDropdownVal(record, id, isHex)
    local target = isHex and tonumber(id, 16) or tonumber(id)
    if not target then return end
    Obj.sortDropdownVal(record, isHex)
    local function binarySearch(left, right)
        if (left > right) then return end
        local mid = bShr(left + right, 1)
        local val = record.DropDownValue[mid]
        local num = isHex and tonumber(val, 16) or tonumber(val)
        if (num == target) then return record.DropDownDescription[mid] end
        return (num < target) and binarySearch(mid + 1, right) or binarySearch(left, mid - 1)
    end
    return binarySearch(0, record.DropDownCount - 1)
end
---------------------------------------------------------------------------------------------------
function Obj.writeNameToChildren(parent, list, isHex)
    for i = 0, parent.count - 1 do
        local num = Obj.extractHexOffsetToNumber(parent[i])
        parent[i].description = string.format("%s", Obj.findDescByDropdownVal(list, num))
    end
end
---------------------------------------------------------------------------------------------------
-- createCutomSelectionList functions
---------------------------------------------------------------------------------------------------
local function createCustomForm(caption, width, height)
    local form = createForm()
    form.Caption  = caption
    form.Width    = width or 500
    form.Height   = height or 300
    form.position = poMainFormCenter
    return form
end

local function createCustomGrid(form)
    local grid = createListView(form)
    grid.ViewStyle, grid.Align = vsReport, alClient
    grid.GridLines, grid.RowSelect, grid.ReadOnly = true, true, true
    return grid
end

local function addColums(grid, caption)
    local colums = grid.Columns.add()
    colums.caption = caption
    return colums
end

local function addDataToGrid(grid, data)
    for i = 1, #data do
        local itemData = data[i]
        local item = grid.Items.add()
        item.Caption = itemData[1]
        for j = 2, #itemData do item.SubItems.add(itemData[j]) end
    end
end

local function addSearchBox(form, grid, data)
    local searchBox = createEdit(form)
    searchBox.Align = alTop
    searchBox.Height = 25
    searchBox.setFocus()
    local function matchesKeyword(value, desc, keyword)
        return value:lower():find(keyword, 1, true) or desc:lower():find(keyword, 1, true)
    end
    local function createItem(value, desc)
        local item = grid.Items.add()
        item.Caption = value
        item.SubItems.add(desc)
    end
    local function updateGrid()
        local keyword = searchBox.Text:lower()
        grid.Items.clear()
        for i = 1, #data do
            local value, desc = data[i][1], data[i][2]
            if matchesKeyword(value, desc, keyword) then createItem(value, desc) end
        end
    end
    searchBox.OnChange = updateGrid
end

function Obj.createHotkeyList(data)
    local form = createCustomForm('Hotkeys')
    local grid = createCustomGrid(form)
    grid.OnSelectItem = function(Sender)
        local al, mf = getAddressList(), getMainForm()
        local index = tonumber(Sender.Selected.SubItems[0])
        al.setSelectedRecord(al[index]); mf.SetHotkey1.doClick()
        form.close()
    end
    addColums(grid,      'Hotkey').Width = form.Width / 9 * 2
    addColums(grid,       'Index').Width = form.Width / 9
    addColums(grid, 'Description').Width = form.Width / 9 * 6
    addDataToGrid(grid, data); addSearchBox(form, grid, data)
    return form
end

local function createDropdownTable(memrec, isHex)
    Obj.sortDropdownVal(memrec.DropDownList, isHex)
    local tbl = {}
    for i = 0, memrec.DropDownCount - 1 do
        tbl[#tbl + 1] = {memrec.DropDownValue[i], memrec.DropDownDescription[i]}
    end
    return tbl
end

function Obj.createDropdownList(memrec, isHex)
    local form = createCustomForm(memrec.description)
    local grid = createCustomGrid(form)
    grid.OnSelectItem = function(Sender)
        Obj.dropdownResult = Sender.Selected.caption
        form.close()
    end
    addColums(grid,       'Value').Width = form.Width / 7
    addColums(grid, 'Description').Width = form.Width / 7 * 6
    local data = createDropdownTable(memrec, isHex)
    addDataToGrid(grid, data); addSearchBox(form, grid, data)
    return form
end

function Obj.showDropdownEx(memrec, isHex)
    local frm = Obj.createDropdownList(memrec, isHex)
    frm.visible = false
    frm.showModal(); frm.destroy()
    local str = Obj.dropdownResult
    Obj.dropdownResult = nil
    return str
end
---------------------------------------------------------------------------------------------------
return Obj
---------------------------------------------------------------------------------------------------
