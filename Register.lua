-- Released Register.lua under the MIT license
-- Copyright (c) 2022 Dhaos
-- https://opensource.org/licenses/mit-license.php

local Obj = {}

function Obj.symbol(symbolname, address)
    unregisterSymbol(symbolname); registerSymbol(symbolname, address, true)
end

function Obj.restoreTableSettings()
    if not (Obj.SymbolList and Obj.ResultList) then return end
    Obj.log("Enabled: Restore Mode")
    local msg = "Error: Symbol/Result count is not the same.\n"
    local isSame = (Obj.SymbolList.count == Obj.ResultList.count)
    if not isSame then Obj.log(msg); return end
    for i = 0, Obj.SymbolList.count - 1 do
        local sl, rl = Obj.SymbolList[i], Obj.ResultList[i]
        if sl then Obj.symbol(sl, rl) end
    end
    if not Obj.DescriptionList then return end
    for i = 0, Obj.DescriptionList.count - 1 do
        local dl = Obj.DescriptionList[i]
        local al = AddressList[dl]
        synchronize(function() if al then al.color = Obj.enabledColor end end)
        Obj.log("Restored: "..al.description)
    end
    return true
end

function Obj.activateTableSettings(author)
    for key, tbl in pairs(author) do
        local al = AddressList[key]
        local note = "Error: AddressList['"..key.."'] not found"
        if not al then Obj.log(note); goto continue end
        local state = Obj.multiCustomScan(tbl)
        Obj.DescriptionList = Obj.DescriptionList or createStringlist()
        local isFirst = not Obj.activateCount
        if state and isFirst then Obj.DescriptionList.add(al.description) end
        local msg = state and "Available" or "Unavailable"
        Obj.log(msg..": "..al.description)
        synchronize(function() al.color = state and Obj.enabledColor or Obj.disabledColor end)
        ::continue::
    end
    return (Obj.DescriptionList.count == 0) and Obj.log("Nothing can be used.\n")
end

function Obj.deactivateTableSettings(author)
    for key, tbl in pairs(author) do
        local al = AddressList[key]
        if not al then goto continue end
        synchronize(function() if al then al.color = Obj.disabledColor end end)
        for i = 1, #tbl do local arg = tbl[i]; unregisterSymbol(arg[1]) end
        ::continue::
    end
end

function Obj.onEnable(...)
    local isRestore = (Obj.isRestore and Obj.restoreTableSettings())
    if isRestore then return Obj.log("Restoration complete.\n") end
    local author = {...}
    for i = 1, #author do Obj.activateTableSettings(author[i]) end
    if not Obj.activateCount then Obj.log("Restore lists have been created.\n") end
    Obj.activateCount = Obj.activateCount and (Obj.activateCount + 1) or 1
    return Obj.log((Obj.scanCount * 2).." temporary files have been created.\n")
end

function Obj.onDisable(...)
    local author = {...}
    for i = 1, #author do Obj.deactivateTableSettings(author[i]) end
end

function Obj.multiCustomScan(args)
    local isAvailable = true
    for i = 1, #args do
        local arg = args[i]
        if getAddressSafe(arg[1]) then goto continue end
        local addr = Obj.customScan(arg[1], arg[2], arg[3], arg[4], arg[5])
        if not addr then isAvailable = false end
        Obj.scanCount  = Obj.scanCount and (Obj.scanCount + 1) or 1
        Obj.SymbolList = Obj.SymbolList or createStringlist()
        Obj.ResultList = Obj.ResultList or createStringlist()
        local state = not Obj.activateCount and addr
        if state then Obj.SymbolList.add(arg[1]); Obj.ResultList.add(addr) end
        if arg[1] and addr then Obj.symbol(arg[1], addr) end
        ::continue::
    end
    return isAvailable
end

function Obj.customScan(strSymbol, strAOB, selectNum, start, size)
    local Result = Obj.memScan(strAOB, start, size)
    if not Result then Obj.log("Error: "..strSymbol.." AOB not found"); return end
    local msg = "Error: "..strSymbol.." AOB Result.count < selectNum"
    if (Result.count < selectNum) then Result.destroy(); Obj.log(msg); return end
    local address = Result[selectNum - 1]
    Result.destroy(); return address
end

function Obj.memScan(strAOB, start, size)
    local ms = createMemScan()
    local fl = createFoundList(ms)
    memscan_firstScan(ms, soExactValue, vtByteArray, nil, strAOB, nil, start, start + size,
    "*X*W", fsmNotAligned, nil, true, false, false, false)
    memscan_waitTillDone(ms); foundlist_initialize(fl)
    local fc = foundlist_getCount(fl)
    if (fc < 1) then ms.destroy(); fl.destroy(); return end
    local Result = createStringlist()
    for i = 0, fc - 1 do Result.add(fl.getAddress(i)) end
    ms.destroy(); fl.destroy(); return Result
end

function Obj.enableMemoryRecords(memoryRecordTable)
    for i = 1, #memoryRecordTable do
        local mr = memoryRecordTable[i]
        if not mr then Obj.log("Error: mr['"..i.."'] not found"); goto continue end
        mr.active = true
        local msg = mr.active and "Enabled" or "Failed"
        Obj.log(msg..": "..mr.description)
        ::continue::
    end
    return Obj.log("")
end

function Obj.disableMemoryRecords(memoryRecordTable)
    for i = #memoryRecordTable, 1, -1 do
        local mr = memoryRecordTable[i]
        if not mr then Obj.log("Error: mr['"..i.."'] not found"); goto continue end
        mr.active = false
        local msg = not mr.active and "Disabled" or "Failed"
        Obj.log(msg..": "..mr.description)
        ::continue::
    end
    return Obj.log("")
end

function Obj.createSectionTable(moduleNameOrAddress)
    local sectionTable = {}
    local addr = getAddress(moduleNameOrAddress)
    local coff = addr + readInteger(addr + 0x3C) + 0x4
    local sectionAddr = coff + readSmallInteger(coff + 0x10) + 0x14
    sectionTable.imageBase = addr
    sectionTable.count = readSmallInteger(coff + 0x2)
    return Obj.assignToSectionTable(sectionTable, sectionAddr)
end

function Obj.assignToSectionTable(sectionTable, base)
    for i = 0, sectionTable.count - 1 do
        local tbl = {}
        tbl.Name                 = readString(base + i * 0x28, 8)
        tbl.PhysicalAddress      = readInteger(base + 0x04 + i * 0x28)
        tbl.VirtualSize          = readInteger(base + 0x08 + i * 0x28)
        tbl.VirtualAddress       = readInteger(base + 0x0C + i * 0x28)
        tbl.SizeOfRawData        = readInteger(base + 0x10 + i * 0x28)
        tbl.PointerToRawData     = readInteger(base + 0x14 + i * 0x28)
        tbl.PointerToRelocations = readInteger(base + 0x18 + i * 0x28)
        tbl.PointerToLinenumbers = readInteger(base + 0x1C + i * 0x28)
        tbl.NumberOfRelocations  = readSmallInteger(base + 0x20 + i * 0x28)
        tbl.NumberOfLinenumbers  = readSmallInteger(base + 0x22 + i * 0x28)
        tbl.Characteristics      = readInteger(base + 0x24 + i * 0x28)
        sectionTable[#sectionTable + 1] = tbl
    end
    return sectionTable
end

function Obj.getSectionIndexFromName(moduleNameOrAddress, sectionName)
    local tbl = Obj.createSectionTable(moduleNameOrAddress)
    for i = 1, #tbl do if (tbl[i].Name == sectionName) then return i end end
end

function Obj.getSectionRegion(sectionTable, selectIndex)
    local section = selectIndex and sectionTable[selectIndex] or sectionTable[1]
    local start = sectionTable.imageBase + section.VirtualAddress
    return start, section.VirtualSize
end

function Obj.getJitRegion(className, methodName, signature)
    local sig = signature and Obj.findMethodBySignature(className, methodName, signature)
    local id  = sig or mono_findMethod("", className, methodName)
    local tbl = mono_getJitInfo(mono_compile_method(id))
    if tbl then return tbl.code_start, tbl.code_size end
end

function Obj.findMethodBySignature(className, methodName, signature)
    -- Thanks: https://fearlessrevolution.com/viewtopic.php?p=214984#p214984
    local id  = mono_findClass("", className)
    local tbl = mono_class_enumMethods(id)
    for i = 1, #tbl do
        local specific = tbl[i]
        local isName = (specific.name == methodName)
        local sig = isName and mono_method_getSignature(specific.method) or ""
        if sig:match(signature) then return specific.method end
    end
end

function Obj.labelAndSymbol(parameters, syntaxcheck)
    -- Thanks: https://wiki.cheatengine.org/index.php?title=Lua:ObjAutoAssemblerCommand
    if syntaxcheck then return end
    local msg = translate('Wrong number of parameters, no "name", for "RegisterLabel" custom AA command.')
    if not parameters then return nil, msg end
    return 'label('..parameters..')\r\nregistersymbol('..parameters..')'
end

function Obj.log(...)
    return Obj.isDebug and print(...)
end

return Obj