-- Released Register.lua under the MIT license
-- Copyright (c) 2022 Dhaos
-- https://opensource.org/licenses/mit-license.php
---------------------------------------------------------------------------------------------------
local Obj = {}
---------------------------------------------------------------------------------------------------
function Obj.symbol(symbolname, address)
    unregisterSymbol(symbolname); registerSymbol(symbolname, address, true)
end
---------------------------------------------------------------------------------------------------
-- onEnable functions
---------------------------------------------------------------------------------------------------
local function activateTableSettings(author)
    for key, tbl in pairs(author) do
        local al = AddressList[key]
        local note = "Error: AddressList['"..key.."'] not found"
        if not al then Obj.log(note); goto continue end
        local state = Obj.multiCustomScan(tbl)
        local msg = state and "Available" or "Unavailable"
        Obj.log(msg..": "..al.description)
        Obj.log('-------------------------------------------------------------------------------')
        al.color = state and Obj.enabledColor or Obj.disabledColor
        ::continue::
    end
end

function Obj.onEnable(...)
    Obj.log('-------------------------------------------------------------------------------')
    local author = {...}
    for i = 1, #author do activateTableSettings(author[i]) end
end
---------------------------------------------------------------------------------------------------
-- onDisable functions
---------------------------------------------------------------------------------------------------
local function deactivateTableSettings(author)
    for key, tbl in pairs(author) do
        local al = AddressList[key]
        if not al then goto continue end
        if al then al.color = Obj.disabledColor end
        for i = 1, #tbl do local arg = tbl[i]; unregisterSymbol(arg[1]) end
        ::continue::
    end
end

function Obj.onDisable(...)
    local author = {...}
    for i = 1, #author do deactivateTableSettings(author[i]) end
end
---------------------------------------------------------------------------------------------------
-- multiCustomScan functions
---------------------------------------------------------------------------------------------------
local function memScan(strAOB, start, size)
    local ms = createMemScan()
    local fl = createFoundList(ms)
    memscan_firstScan(ms, soExactValue, vtByteArray, nil, strAOB, nil, start, start + size,
    "*X*W", fsmNotAligned, nil, true, false, false, false)
    memscan_waitTillDone(ms); foundlist_initialize(fl)
    local fc = foundlist_getCount(fl)
    if (fc < 1) then ms.destroy(); fl.destroy(); return end
    local Result = {}
    for i = 0, fc - 1 do Result[#Result + 1] = fl.getAddress(i) end
    ms.destroy(); fl.destroy(); return Result
end

local function customScan(strSymbol, strAOB, selectNum, start, size)
    local Result = memScan(strAOB, start, size)
    if not Result then Obj.log("Error: "..strSymbol.." AOB not found"); return end
    local msg = "Error: "..strSymbol.." AOB Result.count < selectNum"
    if (#Result < selectNum) then Obj.log(msg) return end
    local address = Result[selectNum]
    return address
end

local function aobScanRegion(SymbolName, StartAddress, StopAddress, AOBString)
    local str = 'aobScanRegion(%s, %X, %X, %s)\nregistersymbol(%s)'
    local script = str:format(SymbolName, StartAddress, StopAddress, AOBString, SymbolName)
    return autoAssemble(script)
end

function Obj.multiCustomScan(args)
    local isAvailable = true
    for i = 1, #args do
        local arg = args[i]
        if getAddressSafe(arg[1]) then goto continue end
        local isAA = (arg[3] == 1) and aobScanRegion(arg[1], arg[4], arg[4] + arg[5], arg[2])
        if isAA then goto continue end
        local addr = customScan(arg[1], arg[2], arg[3], arg[4], arg[5])
        if not addr then isAvailable = false end
        if arg[1] and addr then Obj.symbol(arg[1], addr) end
        ::continue::
    end
    return isAvailable
end
---------------------------------------------------------------------------------------------------
-- enableMemoryRecords functions
---------------------------------------------------------------------------------------------------
local function enableMemoryRecordVariable(variableTable)
    if not variableTable[1].value then return end
    variableTable[1].value = variableTable[2]
    variableTable[1].allowIncrease = (variableTable[3] == 'inc')
    variableTable[1].allowDecrease = (variableTable[3] == 'dec')
end

function Obj.enableMemoryRecords(memoryRecordTable)
    for i = 1, #memoryRecordTable do
        local tbl = type(memoryRecordTable[i]) == 'table' and memoryRecordTable[i]
        local mr = tbl and tbl[1] or memoryRecordTable[i]
        if not mr then Obj.log("enableMemoryRecords mr['"..i.."'] not found"); goto continue end
        mr.active = true
        local msg = mr.active and "Enabled" or "Failed"
        Obj.log(msg..": "..mr.description)
        if mr.active and tbl then enableMemoryRecordVariable(tbl) end
        ::continue::
    end
    return Obj.log("")
end
---------------------------------------------------------------------------------------------------
function Obj.disableMemoryRecords(memoryRecordTable)
    for i = #memoryRecordTable, 1, -1 do
        local mr = memoryRecordTable[i]
        if not mr then Obj.log("disableMemoryRecords mr['"..i.."'] not found"); goto continue end
        mr.active = false
        local msg = not mr.active and "Disabled" or "Failed"
        Obj.log(msg..": "..mr.description)
        ::continue::
    end
    return Obj.log("")
end
---------------------------------------------------------------------------------------------------
-- createSectionTable functions
---------------------------------------------------------------------------------------------------
local function assignToSectionTable(sectionTable, base)
    for i = 0, sectionTable.count - 1 do
        sectionTable[#sectionTable + 1] = {
            Name                 = readString(base + i * 0x28, 8),
            PhysicalAddress      = readInteger(base + 0x04 + i * 0x28),
            VirtualSize          = readInteger(base + 0x08 + i * 0x28),
            VirtualAddress       = readInteger(base + 0x0C + i * 0x28),
            SizeOfRawData        = readInteger(base + 0x10 + i * 0x28),
            PointerToRawData     = readInteger(base + 0x14 + i * 0x28),
            PointerToRelocations = readInteger(base + 0x18 + i * 0x28),
            PointerToLinenumbers = readInteger(base + 0x1C + i * 0x28),
            NumberOfRelocations  = readSmallInteger(base + 0x20 + i * 0x28),
            NumberOfLinenumbers  = readSmallInteger(base + 0x22 + i * 0x28),
            Characteristics      = readInteger(base + 0x24 + i * 0x28)
        }
    end
    return sectionTable
end

function Obj.createSectionTable(moduleNameOrAddress)
    local sectionTable = {}
    local addr = getAddress(moduleNameOrAddress)
    local coff = addr + readInteger(addr + 0x3C) + 0x4
    local sectionAddr = coff + readSmallInteger(coff + 0x10) + 0x14
    sectionTable.imageBase = addr
    sectionTable.count = readSmallInteger(coff + 0x2)
    return assignToSectionTable(sectionTable, sectionAddr)
end
---------------------------------------------------------------------------------------------------
function Obj.getSectionIndexFromName(moduleNameOrAddress, sectionName)
    local tbl = Obj.createSectionTable(moduleNameOrAddress)
    for i = 1, #tbl do if (tbl[i].Name == sectionName) then return i end end
end
---------------------------------------------------------------------------------------------------
function Obj.getSectionRegion(sectionTable, selectIndex)
    local section = selectIndex and sectionTable[selectIndex] or sectionTable[1]
    assert(section, "Invalid section")
    local start = sectionTable.imageBase + section.VirtualAddress
    return start, section.VirtualSize
end
---------------------------------------------------------------------------------------------------
-- getJitRegion functions
---------------------------------------------------------------------------------------------------
local function findMethodBySignature(className, methodName, signature)
    -- Thanks: https://fearlessrevolution.com/viewtopic.php?p=214984#p214984
    assert(className and methodName and signature, "Invalid arguments")
    local id  = mono_findClass("", className)
    local tbl = mono_class_enumMethods(id)
    for i = 1, #tbl do
        local isName = (tbl[i].name == methodName)
        local sig = isName and mono_method_getSignature(tbl[i].method) or ""
        if sig:match(signature) then return tbl[i].method end
    end
end

function Obj.getJitRegion(className, methodName, signature)
    local sig = signature and findMethodBySignature(className, methodName, signature)
    local id  = sig or mono_findMethod("", className, methodName)
    local tbl = mono_getJitInfo(mono_compile_method(id))
    if tbl then return tbl.code_start, tbl.code_size end
end
---------------------------------------------------------------------------------------------------
function Obj.labelAndSymbol(parameters, syntaxcheck)
    -- Thanks: https://wiki.cheatengine.org/index.php?title=Lua:ObjAutoAssemblerCommand
    if syntaxcheck then return end
    local msg = translate('Wrong number of parameters, no "name", for "RegisterLabel" custom AA command.')
    if not parameters then return nil, msg end
    return 'label('..parameters..')\r\nregistersymbol('..parameters..')'
end
---------------------------------------------------------------------------------------------------
-- loadCheckboxStates functions
---------------------------------------------------------------------------------------------------
local function getVariableState(mr)
    if (mr.value == '') then return end
    local inc = mr.allowIncrease and 'inc' or nil
    local dec = mr.allowDecrease and 'dec' or nil
    return mr.value, inc or dec
end

local function handleHeader(header, mr, list)
    if mr.description == '<settings>' or not mr.active then return end
    list[#list + 1] = {mr, getVariableState(mr)}
    for i = 0, mr.count - 1 do handleHeader(header, mr[i], list) end
end

local function getEnableList(header)
    local list = {}
    for i = 0, header.count - 1 do handleHeader(header, header[i], list) end
    return list
end

local function getStateString(arg)
    local parent = arg[1].Parent.description
    local child  = arg[1].description
    local str = [=[Recorder.getChild(AddressList["%s"], "%s")]=]
    if not arg[3] then return ('    '..str):format(parent, child) end
    local mr = str:format(parent, child)
    local allow = arg[3] and (", '%s'"):format(arg[3]) or ''
    return ("    {%s, '%s'%s}"):format(mr, arg[2], allow)
end

function Obj.addEnableList(tbl)
    local enableList = getEnableList(getAddressList().getMemoryRecordByID(777))
    for i = 1, #enableList do local mr = enableList[i][1]; tbl[#tbl + 1] = mr end
    return tbl
end

function Obj.loadCheckboxStates(mainMemrec, loadMemrec)
    local enableList = getEnableList(mainMemrec)
    if (#enableList == 0) then error(messageDialog('No checked boxes were found.', 2, 2)) end
    local str = '{$lua}\nif syntaxcheck then return end\n\n[ENABLE]\n\nlocal mr = {\n'
    for i = 1, #enableList do
        local al = getStateString(enableList[i])
        str = (i == #enableList) and str..al..'\n}\n\n' or str..al..',\n'
    end
    loadMemrec.script = str.."synchronize(function() Register.enableMemoryRecords(mr) end); return 'nop'\n\n[DISABLE]"
    local info = translate("You haven't saved your last changes yet. Save Now?")
    assert(messageDialog(info, 3, 0, 1) == mrYes)
    mainMemrec.active = false
    return getMainForm().Save1.doClick()
end
---------------------------------------------------------------------------------------------------
function Obj.log(...) return Obj.isDebug and print(...) end
---------------------------------------------------------------------------------------------------
return Obj
---------------------------------------------------------------------------------------------------
