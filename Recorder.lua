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
    local cap  = readInteger(addr, true) + 0x4
    local offs = plusOffset and (plusOffset + cap) or cap
    return (addr and offs) and ('%X'):format((addr + offs)) or '??'
end
---------------------------------------------------------------------------------------------------
function Obj.createHeader(parent, description, address)
    local mr = AddressList.createMemoryRecord()
    mr.appendToEntry(parent)
    mr.description = description or "Undefined"
    if address then mr.address = address; mr.isAddressGroupHeader = true end
    if not address then mr.isGroupHeader = true end
    mr.color = address and clOlive or clGray
    mr.options = '[moHideChildren, moDeactivateChildrenAsWell]'
    return mr
end
---------------------------------------------------------------------------------------------------
function Obj.createChild(parent, description, address)
    local mr = AddressList.createMemoryRecord()
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
function Obj.mono_getStaticAddress(className)
    local cid = mono_findClass('', className)
    return mono_class_getStaticFieldAddress('', cid)
end
---------------------------------------------------------------------------------------------------
-- mono_createChildren functions
---------------------------------------------------------------------------------------------------
local function createMemberVariable(parent, member)
    if member.isStatic then return end
    local isType = (0x01 < member.monotype) and (member.monotype < 0x0e)
    if not isType then return end
    local mr = AddressList.createMemoryRecord()
    mr.appendToEntry(parent)
    mr.description = member.name:match('^<(.+)>') or member.name
    mr.varType = monoTypeToVarType(member.monotype)
    mr.address = ('+%02X'):format(member.offset)
    mr.showAsSigned = true
end

function Obj.mono_createChildren(parent)
    local cName = Obj.extractClassName(parent)
    if not cName then return end
    local cid = mono_findClass('', cName)
    local tbl = mono_class_enumFields(cid, true)
    for i = 1, #tbl do createMemberVariable(parent, tbl[i]) end
end
---------------------------------------------------------------------------------------------------
function Obj.removeChildren(parent)
    for i = parent.count - 1, 0, -1 do
        local isPointer = (parent[i].OffsetCount > 0)
        local isScript  = (parent[i].type == vtAutoAssembler)
        if not (isPointer or isScript) then parent[i].destroy() end
    end
end
---------------------------------------------------------------------------------------------------
function Obj.writeAddress(memrec, address, isPointer)
    if not memrec then return end
    memrec.address = address
    if not isPointer then return end
    memrec.OffsetCount = 1
    memrec.Offset[0] = 0
end
---------------------------------------------------------------------------------------------------
function Obj.getAddress(memrec, isSafe)
    local addr = tonumber(memrec.currentAddress)
    local msg = memrec.description..' not loaded.'
    if isSafe then return (0 < addr) and addr end
    return (0 < addr) and addr or error(messageDialog(msg, 2, 2))
end
---------------------------------------------------------------------------------------------------
function Obj.writeValue(memrec, sender)
    local val = (type(sender) == 'userdata') and sender.value or tostring(sender)
    if not (memrec.value == '??') then memrec.value = val end
end
---------------------------------------------------------------------------------------------------
function Obj.inputQueryForAdd(memrec, str)
    return ('%s'):format(inputQuery(memrec.description, 'Add:', str))
end
---------------------------------------------------------------------------------------------------
function Obj.showDropdown(memrec, dropdown)
    local id, str = showSelectionList(memrec.description, '', dropdown.DropdownList)
    if assert(not (id == -1)) then return str:match('^(.+):'), str:match(':(.+)$') end
end
---------------------------------------------------------------------------------------------------
function Obj.interlocking(memrec, target, timer)
    if not (memrec or target or timer) then return end
    local interlocking = function(timer)
        if not target.active then memrec.active = false; return timer.destroy() end
    end
    return interlocking
end
---------------------------------------------------------------------------------------------------
return Obj
