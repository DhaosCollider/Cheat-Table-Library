-- Released UE.lua by DhaosCollider
---------------------------------------------------------------------------------------------------
-- Thanks:
-- Basic UE4 Win64 Base Table by Cake-san
-- https://fearlessrevolution.com/viewtopic.php?p=165398#p165398
---------------------------------------------------------------------------------------------------
-- Log:
-- Mon Jun 20, 2022 Released Automate version Update 7.3 by Cake-san
-- https://fearlessrevolution.com/viewtopic.php?p=167452#p167452
-- Sun Sep 25, 2022 Created a UE.lua by DhaosCollider
---------------------------------------------------------------------------------------------------
local Obj = {}

Obj.Sig = { -- Confirmed Build ver.4.26/4.27
    Version               = '488D05xxxxxxxxC3CCCCCCCCCCCCCCCC40538D42',
    FName                 = '488D05xxxxxxxxEBxx488D0DxxxxxxxxE8xxxxxxxxC605',
    FUObjectArray         = '488D0DxxxxxxxxE8xxxxxxxx488D0Dxxxxxxxx4883C4xxE9xxxxxxxx4883ECxx488D0DxxxxxxxxFF15',
    FUObjectArray_IsValid = '488D0DxxxxxxxxE8xxxxxxxx84C074xx48837Fxx00',
    DisableDisregardForGC = '488D0DxxxxxxxxE8xxxxxxxx488D8DxxxxxxxxE8xxxxxxxx488D8D',
    FObjectIterator       = '48895C24xx48897424xx574883ECxx448B5424xx488D05',
    UWorld                = '488B0Dxxxxxxxx33DB4885C974xxE8'
}

Obj.Type = {
    ['BoolProperty']   = vtByte,
    ['ByteProperty']   = vtByte,
    ['IntProperty']    = vtDword,
    ['FloatProperty']  = vtSingle,
    ['NameProperty']   = vtQword,
    ['Int64Property']  = vtQword,
    ['DoubleProperty'] = vtDouble,
    ['StructProperty'] = vtPointer,
    ['TextProperty']   = vtPointer,
    ['StrProperty']    = vtPointer,
    ['ArrayProperty']  = vtPointer,
    ['MapProperty']    = vtPointer,
    ['ClassProperty']  = vtPointer,
    ['ObjectProperty'] = vtPointer
}

Obj.perThread  = 0x200
Obj.IgnoreList = Obj.IgnoreList or {}
---------------------------------------------------------------------------------------------------
-- UE Structure Lookup functions
---------------------------------------------------------------------------------------------------
-- local --
local function addGlovalStructList(list)
    for i = 1, #list do list[i]:addToGlobalStructureList() end
end

local function getElementByOffset(struct, offset)
    for i = 0, struct.Count - 1 do
        if (struct.Element[i].Offset == offset) then return i end
    end
end

local function assignOffsetList(Struct, list)
    local count, k = Struct.Count - 1, 1
    for i = 0, count do
        local element1 = Struct.Element[i]
        local element2 = Struct.Element[i + 1]
        if not element2 then goto continue end
        local bytesize = element1.Bytesize
        if bytesize < 4 then bytesize = 4 end
        local size = element2.Offset - element1.Offset - bytesize
        if not (size > 0) then goto continue end
        if (size % 4 > 0) then size = 4 - size % 4 + size end
        local start = element1.Offset
        start = (start % 4 > 0) and (4 - start % 4 + start) or start + 4
        size = size / 4
        for j = 0, size - 1 do
            if ((start + j * 4) >= (element1.Offset + bytesize)) then
                list[k] = start + j * 4
                k = k + 1
            end
        end
        ::continue::
    end
end

local function fillStruct4bytes(Struct)
    if not getElementByOffset(Struct, 0) then
        local element = Struct.addElement()
        element.Offset, element.Vartype = 0, vtDword
    end
    Struct.beginUpdate()
    local list = {}
    assignOffsetList(Struct, list)
    for i = 1, #list do
        local val = list[i]
        local element = Struct.addElement()
        element.Offset = val
        element.Vartype = vtDword
    end
    Struct.endUpdate()
end

local function copyStruct(original, copy, AddedOffset, AddedName)
    if not copy then copy = createStructure(original.Name..'_copy') end
    if not AddedOffset then AddedOffset = 0 end
    if not AddedName then AddedName = '' end
    copy.beginUpdate()
    for i = 0, original.Count - 1 do
        local element = copy.addElement()
        local origin = original.Element[i]
        element.Offset = origin.Offset + AddedOffset
        element.Name = (origin.Name == '') and origin.Name or AddedName..origin.Name
        element.Vartype = origin.Vartype
        element.ChildStruct = origin.ChildStruct
        element.childStructStart = origin.childStructStart
        element.Bytesize = origin.Bytesize
    end
    copy.endUpdate()
    return copy
end

local function checkLocalStruct(arg)
    if arg[1][arg[3].FullName] then
        copyStruct(arg[1][arg[3].FullName], arg[4], arg[6], arg[7])
    else
        local copy = createStructure(arg[3].FullName)
        Obj.createStruct(arg[1], arg[2], arg[3], copy, arg[5])
        arg[1][arg[3].FullName] = copy
        copyStruct(copy, arg[4], arg[6], arg[7])
    end
end

local function addElement(tbl, offset, name, varType)
    local element = tbl.addElement()
    element.Offset, element.Name = offset, name
    if varType then element.Vartype = varType end
    return element
end

local function createStructProperty(arg, MemberData, Offset, Name)
    Obj.createStruct(arg[1], arg[2], MemberData.Property[1], arg[4], arg[5], Offset, Name..'.')
    if getElementByOffset(arg[4], Offset) then return end
    addElement(arg[4], Offset, Name, vtDword)
end

local function createRowStruct(arg, e, Offset)
    local sub = targetIs64Bit() and 0 or 4
    local ptr = readPointer(arg[5] + Offset)
    local name, struct = Obj.getObjectData(ptr)
    if not name then return end
    Obj.log(name.Type..' '..name.FullName)
    if not arg[2] then arg[2] = {} end
    if arg[2][name.Name] then struct = arg[2][name.Name] end
    if not arg[2][name.Name] then
        struct = createStructure(name.Name)
        arg[2][name.Name] = struct
        Obj.createStruct(arg[1], arg[2], name, struct, arg[5], nil, nil)
    end
    local f = addElement(arg[4], e.Offset + 8 - sub, 'Table', vtPointer)
    local ssstruct = createStructure('DataTable')
    f.setChildStruct(ssstruct)
    for r = 0, 10 do
        addElement(ssstruct, r * 0x18, string.format('[%u] FName', r), vtQword)
        f = addElement(ssstruct, r * 0x18 + 8, string.format('[%u] Data',r), vtPointer)
        f.setChildStruct(struct)
    end
    fillStruct4bytes(ssstruct)
    addElement(arg[4], e.Offset + 0x10 - sub * 2, 'Size', vtDword)
end

local function assignMapSize(MemberData, size)
    for i = 1, #MemberData.Property do
        local propsize = MemberData.Property[i].Propsize
        size = ((propsize < 4) and 4 or propsize) + size
    end
    return size + 0x8
end

local function createArrayFromName(arg, e, MemberData, Name, isMap)
    local array = createStructure(Name)
    arg[2][Name] = array
    e.setChildStruct(array)
    local size = 0
    if isMap then size = assignMapSize(MemberData, size) end
    for k = 1, #MemberData.Property do
        local tbl = MemberData.Property[k]
        local psize = isMap and size or tbl.Propsize
        local Offs  = (isMap and tbl.Offset) and tbl.Offset or 0
        for p = 0, 10 do
            local offset = p * psize + Offs
            Name = string.format('[%u] ', p)
            if string.find(tbl.Type, 'StructProperty') then
                Obj.createStruct(arg[1], arg[2], tbl.Property[1], array, arg[5], offset, Name)
            else
                local varType = Obj.Type[tbl.Type] and Obj.Type[tbl.Type] or vtDword
                addElement(array, offset, Name..tbl.Name, varType)
            end
        end
    end
    fillStruct4bytes(array)
end

local function createArrayOrMapProperty(arg, e, MemberData, Propsize, Typ)
    local sub = targetIs64Bit() and 0 or 4
    addElement(arg[4], e.Offset + 0x8 - sub, e.Name..'_size', vtDword)
    addElement(arg[4], e.Offset + 0xC - sub, e.Name..'_sizes', vtDword)
    for m = e.Offset + 0xC - sub + 4, Propsize - 1, 4 do
        if not getElementByOffset(arg[4], m) then
            addElement(arg[4], m, string.format('%s+%X', e.Name, m), vtDword)
        end
    end
    local isMap = string.find(Typ, 'MapProperty')
    local tbl = MemberData.Property[1]
    local isStruct = string.find(tbl.Type, 'StructProperty')
    local state = isStruct and tbl.Property and tbl.Property[1]
    local Name = state and tbl.Property[1].Name..'[]' or tbl.Name..'[]'
    if not arg[2] then arg[2] = {} end
    local isName = arg[2][Name]
    if isName then e.setChildStruct(arg[2][Name]) end
    if not isName then createArrayFromName(arg, e, MemberData, Name, isMap) end
end

local function checkNonStructProperties(arg, MemberData, Offset, Propsize, Name, Typ)
    local e = addElement(arg[4], Offset, Name)
    local isBool = Typ and string.find(Typ, 'BoolProperty')
    if isBool and MemberData.Bit then e.childStructStart = MemberData.Bit end
    local isRow = Name and string.find(Name, 'RowStruct')
    if arg[5] and isRow then createRowStruct(arg, e, Offset) end
    e.Vartype = Obj.Type[Typ] and Obj.Type[Typ] or vtDword
    local str1, str2 = 'ArrayProperty', 'MapProperty'
    if (string.find(Typ, str1) or string.find(Typ, str2)) and MemberData.Property then
        createArrayOrMapProperty(arg, e, MemberData, Propsize, Typ)
    end
end

local function createElementsForStruct(arg)
    for j = 1, #arg[3].Member do
        local MemberData = arg[3].Member[j]
        if not MemberData.Offset then goto continue end
        local Offset = arg[6] + MemberData.Offset
        local Propsize = MemberData.Propsize
        local Name = arg[7]..MemberData.Name
        local Typ = MemberData.Type
        local isUser = arg[3].Type and string.find(arg[3].Type, 'UserDefinedStruct')
        if isUser then Name = Name:sub(1, string.find(Name, '_') - 1) end
        local isStruct = Typ and string.find(Typ, 'StructProperty')
        if isStruct and MemberData.Property and MemberData.Property[1] then
            createStructProperty(arg, MemberData, Offset, Name)
        else
            checkNonStructProperties(arg, MemberData, Offset, Propsize, Name, Typ)
        end
        ::continue::
    end
end

local function addUObjectElement(Struct, name)
    if not getElementByOffset(Struct, 0) then
        addElement(Struct, 0, 'VTable', vtPointer)
    end
    if not getElementByOffset(Struct, Obj.UObject.objectId) then
        addElement(Struct, Obj.UObject.objectId, 'ObjectIndex', vtDword)
    end
    if not getElementByOffset(Struct, Obj.UObject.class) then
        addElement(Struct, Obj.UObject.class, 'Class/Type', vtPointer)
    end
    if not getElementByOffset(Struct, Obj.UObject.FNameIndex) then
        addElement(Struct, Obj.UObject.FNameIndex, 'FNameIndex', vtDword)
    end
    if not getElementByOffset(Struct, Obj.UObject.outer) then
        addElement(Struct, Obj.UObject.outer, 'Outer', vtPointer)
    end
    if string.find(name, 'Function') and Obj.UObject.func then
        addElement(Struct, Obj.UObject.func, 'Func', vtPointer)
    end
end

local function createStructFromObjectData(Object, structName, isGlobal, isfullname, Struct,
    AddedOffset, AddedName, Instance, name)

    if not Object then return end
    Struct = Struct and Struct or createStructure(Object.Name)
    local LocalStruct, ArrayStruct = {}, {}
    Struct.beginUpdate()
    Obj.createStruct(LocalStruct, ArrayStruct, Object, Struct, Instance, nil, nil)
    Struct.endUpdate()
    addUObjectElement(Struct, Object.Name)
    fillStruct4bytes(Struct)
    if isGlobal then Obj.StructList[#Obj.StructList + 1] = Struct end
    addGlovalStructList(Obj.StructList)
    return Struct
end

local function saveAndRemoveStruct()
    Obj.StructList = {}
    local count = getStructureCount()
    for i = count - 1, 0, -1 do
        local struct = getStructure(i)
        Obj.StructList[i + 1] = struct
        struct:removeFromGlobalStructureList()
    end
end

local function getMemoryRegionBaseAddress(address)
    local tbl = enumMemoryRegions()
    for i= #tbl, 1, -1 do
        if (tbl[i].BaseAddress <= address) then return tbl[i].BaseAddress end
    end
end

local function findNearThisInstance(address)
    local base = getAddress(address)
    if inModule(base) then return end
    local region = base - getMemoryRegionBaseAddress(base)
    local size = targetIs64Bit() and 0x10 or 0x08
    local align = base - (base % size)
    for i = 0, region, size do
        local addr = align - i
        local data = Obj.getObjectData(addr)
        if data and data.Class and not (data.FullName == 'None') then return data end
    end
end

local function getObjectDataInfo(address)
    local ObjectData = findNearThisInstance(address)
    if not ObjectData then return end
    local class = ObjectData.Class
    return ObjectData.Address, class, class.Name, class.FullName
end
-- gloval --
function Obj.createStruct(...)
    local arg = {...}
    if arg[6] then checkLocalStruct(arg); return end
    arg[6] = arg[6] and arg[6] or 0
    arg[7] = arg[7] and arg[7] or ''
    for i = 0, 10 do
        if arg[3].Member then
            Obj.log(arg[3].Type..' '..arg[3].FullName)
            createElementsForStruct(arg)
        end
        if not arg[3].Super then break end
        arg[3] = arg[3].Super
    end
end

function Obj.StructureNameLookupCallback(address)
    local addr, class, name = getObjectDataInfo(address)
    if name then return name, addr end
end

function Obj.StructureDissectOverrideCallback(Struct, Instance)
    local address, class, name, fullname = getObjectDataInfo(Instance)
    if not class then return end
    saveAndRemoveStruct()
    createStructFromObjectData(class, nil, nil, nil, Struct, nil, nil, Instance, name)
    Obj.log('')
    return (Struct.Count > 1)
end
---------------------------------------------------------------------------------------------------
-- saveBasicObjects functions
---------------------------------------------------------------------------------------------------

local function saveBasicObject(pointer, start, stop)
    for j = start, stop do
        local ptr = readPointer(pointer + j * Obj.UObjectMul)
        if not readPointer(ptr) then break end
        Obj.getObjectData(ptr)
    end
end

local function saveBasicObjects(size)
    for i = 0, 0x1000, size do
        local pointer = readPointer(Obj.GUObjectAddress + i)
        Obj.log(('UObjectArray (saveBasicObjects): 0x%02X'):format(i))
        if not readPointer(pointer) then break end
        local region = Obj.getRegionSize(pointer)
        local num, stop = Obj.perThread, 0
        for j = 0, math.floor(region / (Obj.UObjectMul * Obj.perThread)) do
            local start = stop
            stop = stop + num
            saveBasicObject(pointer, start, stop - 1)
        end
    end
end

function Obj.saveBasicObjects()
    Obj.FullNameList, Obj.ObjectList = {}, {}
    Obj.totalObjects, Obj.totalProperties = 0, 0
    local starttime = os.clock()
    local size = targetIs64Bit() and 8 or 4
    saveBasicObjects(size)
    local info = 'Total of %u objects has been found. (%.2fs)\n'
    Obj.log(info:format(Obj.totalObjects, os.clock() - starttime))
end
---------------------------------------------------------------------------------------------------
-- getObjectData functions
---------------------------------------------------------------------------------------------------
-- local --
local function getName1(pointer)
    local class = readPointer(pointer + Obj.UObject.class)
    local typ = readInteger(class + Obj.UObject.FNameIndex)
    if not (class and typ) then return end
    local name = readInteger(pointer + Obj.UObject.FNameIndex)
    typ  = Obj.getFNameString(typ, true)
    name = Obj.getFNameString(name, true)
    return typ, name, readPointer(pointer + Obj.UObject.outer), class
end

local function getName2(pointer)
    if not readPointer(pointer) then return end
    local typ = readInteger(readPointer(pointer + 8))
    if not typ then return end
    local name = readInteger(pointer + 0x28)
    typ  = Obj.getFNameString(typ, true)
    name = Obj.getFNameString(name, true)
    return typ, name, readPointer(pointer + 0x10)
end

local function getNameSetup(pointer)
    if (Obj.version < 4.25) then return getName1(pointer) end
    local typ, name = getName2(pointer)
    if not (typ and name) then return getName1(pointer) end
    return getName2(pointer)
end

local function createObjectData(pointer, typ, name, outer)
    local tbl = {}
    tbl.Outer = not (outer == 0) and outer or nil
    tbl.Type, tbl.Name, tbl.Address = typ, name, pointer
    if not tbl.Name then tbl.Name ='InvalidName' end
    return tbl
end

local function getFullName(dataNew, str)
    for i = 0, 10 do
        if not dataNew.Outer or not Obj.ObjectList[dataNew.Outer] then return str end
        local dataOld = dataNew
        dataNew = Obj.ObjectList[dataNew.Outer]
        local isOld = string.find(dataOld.Type, 'Property') or string.find(dataOld.Type,'Function')
        local isNew = string.find(dataNew.Type, 'Property') or string.find(dataNew.Type,'Function')
        str = (not isNew and isOld) and dataNew.Name..':'..str or dataNew.Name..'.'..str
    end
    return str
end

local function assignClass(ObjectData, class)
    class = Obj.getObjectData(class)
    if not class then return end
    if not class.Instance then class.Instance = {} end
    class.Instance[#class.Instance + 1] = ObjectData
    ObjectData.Class = class
end

local function assignUper(ObjectData)
    ObjectData.Super = Obj.getObjectData(ObjectData.Super)
    if not ObjectData.Super then return end
    if not ObjectData.Super.Uper then ObjectData.Super.Uper = {} end
    ObjectData.Super.Uper[#ObjectData.Super.Uper + 1] = ObjectData
end

local function assignProperty(pointer, ObjectData, typ, size)
    if Obj.totalProperties then Obj.totalProperties = Obj.totalProperties + 1 end
    local UObject = Obj.UObject
    local isValid = UObject.offset and UObject.propSize and UObject.property and UObject.bitMask
    if not isValid then return end
    ObjectData.Offset   = readSmallInteger(pointer + UObject.offset)
    ObjectData.Propsize = readSmallInteger(pointer + UObject.propSize)
    if string.find(typ, 'StructProperty') or string.find(typ, 'ObjectProperty') then
        ObjectData.Property = {Obj.getObjectData(readPointer(pointer + UObject.property))}
        if not ObjectData.Property[1] then ObjectData.Property = nil end
    elseif string.find(typ, 'MapProperty') or string.find(typ, 'ArrayProperty') then
        local ptr1 = readPointer(pointer + UObject.property)
        local ptr2 = readPointer(pointer + UObject.property + size)
        ObjectData.Property = {Obj.getObjectData(ptr1), Obj.getObjectData(ptr2)}
        if not ObjectData.Property[1] then ObjectData.Property = nil end
    elseif string.find(typ, 'BoolProperty') then
        ObjectData.Bit = readInteger(pointer + UObject.bitMask)
    end
end

local function assignMember(pointer, ObjectData, size)
    if not (Obj.UObject.member and Obj.UObject.nextMember) then return end
    local member = Obj.getObjectData(readPointer(pointer + Obj.UObject.member))
    if not member then return end
    ObjectData.Membersize = readInteger(pointer + Obj.UObject.member + size)
    ObjectData.Member = {member}
    for i = 0, 0x1000 do
        member = Obj.getObjectData(readPointer(member.Address + Obj.UObject.nextMember))
        if not member then break end
        local isFunction = string.find(member.Type, 'Function')
        local isOffset = member.Offset and (member.Offset > 0)
        if not isFunction and isOffset then ObjectData.Member[#ObjectData.Member + 1] = member end
    end
end

local function assignUObjectFunction(j, i, ptr, pointers)
    if not (j == 0x30) then return pointers end
    for k = i - 4, Obj.UObject.objectId, -4 do
        pointers = readPointer(ptr + k)
        if readPointer(pointers) and inModule(pointers) then
            local ext, opc = splitDisassembledString(disassemble(pointers))
            local find = string.find
            local isOpc = find(opc, 'mov') or find(opc, 'push') or find(opc, 'sub')
            Obj.UObject.func = isOpc and k or nil
            if Obj.UObject.func then
                Obj.log(('UObject.func = 0x%02X'):format(Obj.UObject.func))
            end
            break
        end
    end
    return pointers
end

local function isModuleFunction(pointers, size, i, ptr)
    if not (readPointer(pointers) and inModule(pointers)) then return end
    for j = 0, 0x30, size do
        if not inModule(readPointer(pointers + j)) then break end
        pointers = assignUObjectFunction(j, i, ptr, pointers)
    end
end

local function findFunction(typ, str, ptr)
    if Obj.UObject.func then return end
    local size = targetIs64Bit() and 8 or 4
    Obj.log(typ..' '..str..string.format(' = %X', ptr))
    for i = Obj.UObject.objectId, 0x130, 4 do
        if Obj.UObject.func then break end
        local pointers = readPointer(ptr + i)
        isModuleFunction(pointers, size, i, ptr)
    end
end

local function assignEnum(pointer, ObjectData)
    if not (Obj.UObject.enumProp or Obj.IgnoreList[pointer]) then
        Obj.IgnoreList[pointer] = true
        Obj.log(('%016X: %s %s'):format(ObjectData.Address, ObjectData.Type, ObjectData.FullName))
        for i = Obj.UObject.offset + 4, Obj.UObject.offset + 4+0x100, 4 do
            local data = Obj.getObjectData(readPointer(ObjectData.Address + i))
            local isEnum = data and ((data.Type == 'Enum') or (data.Type == 'UserDefinedEnum'))
            if isEnum then Obj.UObject.enumProp = i; break end
        end
    end
    if Obj.UObject.enumProp then
        local ptr = readPointer(ObjectData.Address + Obj.UObject.enumProp)
        ObjectData.EnumProp = Obj.getObjectData(ptr)
    end
end

local function EInterpCurveMode(size, pointer)
    Obj.IgnoreList[pointer] = true
    Obj.log(string.format('%016X: EInterpCurveMode', pointer))
    for j = Obj.UObject.outer + size, 0x100, 4 do
        local ptr = readPointer(pointer + j)
        local CIM_Linear = Obj.checkValue(ptr, 0x50, 'CIM_Linear', 1)
        if not (readPointer(ptr) and CIM_Linear) then return end
        Obj.UObject.enumOffset = j
        Obj.log(string.format('EInterpCurveMode enums = %X\n', ptr))
        Obj.UObject.enumName = CIM_Linear - ptr
        local val1 = Obj.checkValue(ptr, 0x50, 1, 2)
        local val2 = Obj.checkValue(ptr, 0x50, 'CIM_CurveAuto', 1)
        Obj.UObject.enumIndex = val1 and val1 - val2 or 4
        for k = Obj.UObject.enumName + 8, 0x50, 4 do
            local isFName = Obj.getFNameString(readInteger(ptr + k), true)
            if (readInteger(ptr + k) > 4) and isFName then Obj.UObject.enumMul = k break end
        end
    end
end

local function assignObjectTypes(pointer, ObjectData, typ, name, class, str)
    if not (Obj.UObject.super and Obj.UObject.offset) then return end
    if class then assignClass(ObjectData, class) end
    if Obj.totalObjects then Obj.totalObjects = Obj.totalObjects + 1 end
    local UObject = Obj.UObject
    local super = readPointer(pointer + UObject.super)
    ObjectData.Super = not (super == 0) and super or nil
    if ObjectData.Super then assignUper(ObjectData) end
    local size = targetIs64Bit() and 8 or 4
    if string.find(typ, 'Property') then assignProperty(pointer, ObjectData, typ, size) end
    if not string.find(typ, 'Property') then assignMember(pointer, ObjectData, size) end
    if (typ =='Function') and not str:find('Default') then findFunction(typ, str, pointer) end
    local enums = UObject.enumOffset and UObject.enumName and UObject.enumIndex and UObject.enumMul
    local state = enums or Obj.IgnoreList[pointer]
    if not state and string.find(name,'EInterpCurveMode') then EInterpCurveMode(size, pointer) end
    if string.find(ObjectData.Type, 'EnumProperty') then assignEnum(pointer, ObjectData) end
end
-- gloval --
function Obj.getObjectData(address)
    -- Requre autoConfig/saveBasicObjects
    if not readPointer(address) then return end
    if Obj.ObjectList[address] then return Obj.ObjectList[address] end
    local objid = readInteger(address + Obj.UObject.objectId)
    if not objid then return end
    local typ, name, outer, class = getNameSetup(address)
    if not (typ and name) or (typ:len() > 100) then return end
    local ObjectData = createObjectData(address, typ, name, outer)
    ObjectData.ObjectId = objid
    Obj.ObjectList[address] = ObjectData
    local str = getFullName(ObjectData, ObjectData.Name)
    ObjectData.FullName = str
    Obj.FullNameList[str:lower()] = ObjectData
    assignObjectTypes(address, ObjectData, typ, name, class, str)
    return ObjectData
end
---------------------------------------------------------------------------------------------------
-- StaticFindObject functions
---------------------------------------------------------------------------------------------------
-- local --
local function findObject(pointer, start, stop, fullname, name)
    for j = start, stop do
        if Obj.staticObjectFoundAddress then break end
        local pointers = readPointer(pointer + j * Obj.UObjectMul)
        if not readPointer(pointers) then break end
        local Data = Obj.getObjectData(pointers)
        if fullname and Obj.FullNameList[fullname] then break end
        local state = Data and name and string.find(Data.Name:lower(), Name:lower())
        if state then Obj.staticObjectFoundAddress = Data.Address; break end
    end
end

local function getFullNameListAddress(fullname, name, size)
    for i = 0, 0x1000, (targetIs64Bit() and 8 or 4) do
        local pointer = readPointer(Obj.GUObjectAddress + i)
        Obj.log(('UObjectArray (StaticFindObject): 0x%02X'):format(i))
        if not readPointer(pointer) then break end
        local region, stop = Obj.getRegionSize(pointer), 0
        for j = 0, math.floor(region / size) do
            local start = stop
            stop = stop + Obj.perThread
            findObject(pointer, start, stop - 1, fullname, name)
            if Obj.FullNameList[fullname] then return Obj.FullNameList[fullname].Address end
        end
    end
end
-- gloval --
function Obj.StaticFindObject(fullname, name)
    if fullname then fullname = fullname:lower() end
    if Obj.FullNameList[fullname] then return Obj.FullNameList[fullname].Address end
    local size = Obj.UObjectMul * Obj.perThread
    return getFullNameListAddress(fullname, name, size) or Obj.staticObjectFoundAddress
end
---------------------------------------------------------------------------------------------------
-- autoConfig functions
---------------------------------------------------------------------------------------------------
-- local --
local function assignUObjectSuper(pointer, Data, flag, i)
    if not Data then return end
    Obj.log(('getObjectData: %s %s = %X'):format(Data.Type, Data.FullName, Data.Address))
    if not Data.FullName:find('Engine.'..'Engine') or flag[1] then return end
    Obj.UObject.super, pointer[1], flag[1] = i, pointer[2], true
    Obj.log(('UObject.super = 0x%02X'):format(Obj.UObject.super))
end

local function assignUObjectNextMember(pointer, Data, flag, j)
    for k = 0, 1 do
        Data = Obj.getObjectData(pointer[3])
        local isProperty = Data and string.find(Data.Type, 'Property')
        local isFunction = Data and string.find(Data.Type, 'Function')
        local isSStruct  = Data and string.find(Data.Type, 'ScriptStruct')
        local isState    = Data and string.find(Data.Type, 'State')
        local isCore     = Data and string.find(Data.FullName, 'Core')
        if isCore or not (isProperty or isFunction or isSStruct or isState) then break end
        local str = 'assignUObjectNextMember (0x%02X): %s %s = %X'
        Obj.log(str:format(j, Data.Type, Data.FullName, pointer[3]))
        if (k == 1) then
            Obj.UObject.nextMember = j
            Obj.log(('UObject.nextMember = 0x%02X'):format(Obj.UObject.nextMember))
            flag[2] = true
            break
        end
        pointer[3] = readPointer(pointer[3] + j)
    end
end

local function findUObjectNextMember(pointer, Data, flag, size)
    Obj.log(('findUObjectNextMember: %s %s = %X'):format(Data.Type, Data.FullName, pointer[2]))
    for j = size, 0x100, 4 do
        pointer[3] = readPointer(pointer[2] + j)
        assignUObjectNextMember(pointer, Data, flag, j)
        if flag[2] then break end
    end
end

local function assignUObjectMember(pointer, Data, flag, size, i)
    if not Data then return end
    local isProp = Data.Type and string.find(Data.Type, 'Property')
    local isFunc = Data.Type and string.find(Data.Type, 'Function')
    local isEnum = Data.Type and string.find(Data.Type, 'Enum')
    local isCore = Data.FullName and string.find(Data.FullName, 'Core')
    if (isProp or isFunc or isEnum) and not isCore then
        findUObjectNextMember(pointer, Data, flag, size)
        if flag[2] then
            Obj.UObject.member = i
            Obj.log(('UObject.member = 0x%02X'):format(Obj.UObject.member))
        end
    end
end

local function assignUObjectSuperAndMember(pointer, size)
    local flag = {}
    for i = Obj.UObject.outer + size, 0x100, 4 do
        pointer[2] = readPointer(pointer[1] + i)
        local Data = Obj.getObjectData(pointer[2])
        assignUObjectSuper(pointer, Data, flag, i)
        assignUObjectMember(pointer, Data, flag, size, i)
        if flag[1] and flag[2] then return Data end
    end
end

local function findObjectPropertyPointer(pointer, Data)
    pointer[3] = readPointer(Obj.UObject.member + pointer[1])
    for i = 0, 300 do
        Data = Obj.getObjectData(pointer[3])
        if Data then
            Obj.log(string.format('%016X: %s %s', pointer[3], Data.Type, Data.FullName))
            if string.find(Data.Type, 'ObjectProperty') then break end
        end
        pointer[3] = readPointer(Obj.UObject.nextMember + pointer[3])
    end
end

local function assignUObjectProperty(pointer, Data, size)
    for i = Obj.UObject.nextMember + size, 0x100, size do
        Data = Obj.getObjectData(readPointer(pointer[3] + i))
        local isClass = Data and string.find(Data.Type, 'Class')
        local isCore  = Data and string.find(Data.FullName, 'Core')
        if isClass and not isCore then
            Obj.UObject.property = i
            Obj.log(('UObject.property = 0x%02X'):format(Obj.UObject.property))
            break
        end
    end
end

local function findObjectOrFloatPointer(pointer, Data)
    pointer[3] = readPointer(Obj.UObject.nextMember + pointer[2])
    for i = 0, 300 do
        Data = Obj.getObjectData(pointer[3])
        if Data then
            Obj.log(string.format('%016X: %s %s', pointer[3], Data.Type, Data.FullName))
            local isType1 = string.find(Data.Type, 'ObjectProperty')
            local isType2 = string.find(Data.Type, 'FloatProperty')
            if isType1 or isType2 then break end
        end
        pointer[3] = readPointer(Obj.UObject.nextMember + pointer[3])
    end
end

local function assignUObjectOffset(pointer, varsize, size)
    for i = Obj.UObject.nextMember + size, 0x100, 2 do
        local val1, val2 = readSmallInteger(pointer[3] + i), readSmallInteger(pointer[2] + i)
        local isValid = (val1 + varsize == val2)
        Obj.log(string.format('checkUObjectOffset: 0x%X (%s)', i, tostring(isValid)))
        if isValid then
            Obj.UObject.offset = i
            Obj.log(('UObject.offset = 0x%02X'):format(Obj.UObject.offset))
            break
        end
    end
end

local function findBitMaskPointer(pointer, Data)
    pointer[3] = readPointer(Obj.UObject.member + Data.Address)
    for i = 0, 100 do
        if not pointer[3] then break end
        Data = Obj.getObjectData(pointer[3])
        if Data then
            pointer[4] = readPointer(Obj.UObject.nextMember + pointer[3])
            Obj.log(string.format('%016X: %s %s', pointer[3], Data.Type, Data.FullName))
            local isBool = string.find(Data.Type,'BoolProperty')
            local isVal1 = readSmallInteger(Obj.UObject.offset + pointer[3])
            local siVal2 = readSmallInteger(Obj.UObject.offset + pointer[4])
            if isBool and (isVal1 == siVal2) then break end
        end
        pointer[3] = readPointer(Obj.UObject.nextMember + pointer[3])
    end
end

local function assignUObjectBitMask(pointer, Data)
    Obj.log(string.format('%016X: %s %s', pointer[4], Data.Type, Data.FullName))
    for i = Obj.UObject.property, 0x100, 1 do
        local val1, val2 = readBytes(pointer[3] + i), readBytes(pointer[4] + i)
        local isVal1 = (val1 == 1) or (val1 % 2 == 0)
        local isVal2 = (val2 == 1) or (val2 % 2 == 0)
        if isVal1 and isVal2 and (val1 < val2) then
            Obj.UObject.bitMask = i
            Obj.log(('UObject.bitMask = 0x%02X'):format(Obj.UObject.bitMask))
            break
        end
    end
end

local function assignUObject(pointer, size)
    local Data = assignUObjectSuperAndMember(pointer, size)
    findObjectPropertyPointer(pointer, Data)
    local sizeTbl = {[0] = 1, [2] = 4, [3] = 8, [4] = 4, [12] = size}
    local UObject, varsize = Obj.UObject, sizeTbl[Obj.Type[Data.Type]]
    UObject.propSize = Obj.checkValue(pointer[3] + UObject.outer, 0x100, varsize, 2) - pointer[3]
    assignUObjectProperty(pointer, Data, size)
    findObjectOrFloatPointer(pointer, Data)
    pointer[2] = readPointer(UObject.nextMember + pointer[3])
    assignUObjectOffset(pointer, varsize, size)
    for i, v in pairs(Obj.ObjectList) do if (v.Name == 'Actor') then Data = v; break end end
    Obj.log(('%s %s = %X'):format(Data.Type, Data.FullName, Data.Address))
    findBitMaskPointer(pointer, Data)
    Data = Obj.getObjectData(pointer[4])
    if Data then assignUObjectBitMask(pointer, Data) end
    if not UObject.bitMask then UObject.bitMask = UObject.property end
end
-- gloval --
function Obj.autoConfig()
    if Obj.UObject then return end
    Obj.FullNameList, Obj.ObjectList, Obj.UObject = {}, {}, {}
    local time = os.clock()
    local sub = targetIs64Bit() and 0 or 4
    local UObject = Obj.UObject
    UObject.objectId   = 0x0C - sub
    UObject.class      = 0x10 - sub
    UObject.FNameIndex = 0x18 - (sub * 2)
    UObject.outer      = 0x20 - (sub * 2)
    local str = 'UObject.objectId   = 0x%02X\nUObject.class      = 0x%02X\nUObject.FNameIndex = 0x%02X\nUObject.outer      = 0x%02X'
    Obj.log(str:format(UObject.objectId, UObject.class, UObject.FNameIndex, UObject.outer))
    local pointer, size = {}, targetIs64Bit() and 8 or 4
    pointer[1] = Obj.StaticFindObject('/Script/Engine.GameEngine')
    assignUObject(pointer, size)
    Obj.FullNameList, Obj.ObjectList = nil, nil
    Obj.log(('autoConfig done. (%.2fs)\n'):format(os.clock() - time))
end
---------------------------------------------------------------------------------------------------
-- getFNameString functions
---------------------------------------------------------------------------------------------------
-- local --
local function getStringOffset(id, index, ptr, le, widechar)
    if not ((id > 0) and (id < 7) and (le >= 10) and (le <= 15)) then return end
    local length = (widechar and le * 2 or le) - 1
    for k = 2, 0x20, 2 do
        local read = readString(ptr + index + k, length, widechar)
        local isByte = string.find(read, 'ByteProperty')
        if isByte then return k end
    end
end
-- gloval --
function Obj.getFNameString(FName, IndexOnly)
    if not FName then return end
    local num = IndexOnly and FName >> 32 or readInteger(FName + 4)
    local id  = IndexOnly and FName & 0xFFFFFFFF or readInteger(FName)
    if not id then return end
    if Obj.FNameList[id] and (num > 0) then return Obj.FNameList[id]..'_'..num - 1 end
    if Obj.FNameList[id] then return Obj.FNameList[id] end
    local index = (id & 0xFFFF) << 1
    local ptr = readPointer(Obj.FNamePool + (id >> 0x10) * (targetIs64Bit() and 8 or 4))
    local le = readSmallInteger(ptr + index) and readSmallInteger(ptr + index) >> 6
    if not le or (le > 200) then return end
    local widechar = (readBytes(ptr + index, 1) == 1)
    Obj.stringOffset = Obj.stringOffset or getStringOffset(id, index, ptr, le, widechar)
    if not Obj.stringOffset then return end
    le = (widechar and le * 2 or le) - 1
    local str = readString(ptr + index + Obj.stringOffset, le , widechar)
    if not str then return end
    if (num > 0) then return str..'_'..num - 1 end
    Obj.FNameList[id] = str
    return str
end
---------------------------------------------------------------------------------------------------
 -- parseTables functions
---------------------------------------------------------------------------------------------------
-- local --
local function findString(namestr, start, stop)
    local acclen = 0
    for i = start, stop do
        local name = Obj.getFNameString(i + acclen, true)
        if (namestr == name) then return i + acclen end
    end
end

local function findStringFName(namestr)
    local fr = #Obj.FNameRegions
    local size = (Obj.version < 4.23) and (fr << 0x0E) - 1 or (fr << 0x10) - 1
    local count = math.floor((size / Obj.perThread) + 0.5)
    local result, num, start, stop = nil, Obj.perThread, 0, 0
    for i = 0, count do
        start, stop = i * num, (i + 1) * num
        result = findString(namestr, start, stop - 1)
        if result then break end
    end
    return result
end

local function parseFNamePool(NamePoolData)
    Obj.FNameList, Obj.FNameRegions = {}, {}
    Obj.FNamePool = NamePoolData + 0x10
    local size = targetIs64Bit() and 8 or 4
    for i = 0, 0x1000, size do
        local ptr = readPointer(Obj.FNamePool + i * size)
        if not readPointer(ptr) then break end
        Obj.FNameRegions[i + 1] = Obj.getRegionSize(ptr)
    end
    Obj.log('findStringFName: /Script/CoreUObject')
    assert(findStringFName('/Script/CoreUObject'))
end

local function getGUObjectAddress(NamePoolData, GUObjectArray)
    parseFNamePool(NamePoolData)
    local ptr = readPointer(GUObjectArray)
    if not readPointer(ptr) then ptr = readPointer(GUObjectArray + 0x10) end
    assert(readPointer(readPointer(ptr)))
    local isModule = inModule(readPointer(readPointer(readPointer(readPointer(ptr)))))
    return isModule and ptr
end
-- gloval --
function Obj.getRegionSize(address)
    local tbl = enumMemoryRegions()
    for i= #tbl, 1, -1 do
        if (tbl[i].BaseAddress <= address) then return tbl[i].RegionSize end
    end
end

function Obj.checkValue(address, size, value, typ, literal)
    -- Require parseTable/getObjectData
    local cvalue, tempvalue, value2, state = readBytes(address, size, true)
    if not cvalue then return false end
    if (type(value) == type('')) and string.find(value, '~') then
        value2 = tonumber(value:sub(string.find(value, '~') + 1, value:len()))
        value  = tonumber(value:sub(1, string.find(value, '~') - 1))
    end
    if (typ == 1) then
        for i = 1, #cvalue, 4 do
            local datatable = {}
            for m = 1, 4 do datatable[m] = cvalue[m + i - 1] end
            tempvalue = byteTableToDword(datatable)
            local str = Obj.getFNameString(tempvalue, true)
            state = not literal and string.find(str,value) or (str == value)
            if str and state then return address + i - 1 end
        end
    elseif (typ == 2) then
        for i = 1, #cvalue, 2 do
            local datatable = {}
            for m = 1, 2 do datatable[m] = cvalue[m + i - 1] end
            tempvalue = byteTableToWord(datatable)
            state = value2 and (tempvalue >= value) and (tempvalue <= value2)
            if (tempvalue == value) or state then return address + i - 1 end
        end
    elseif (typ == 4) then
        for i = 1, #cvalue, 4 do
            local datatable = {}
            for m = 1, 4 do datatable[m] = cvalue[m + i - 1] end
            tempvalue = byteTableToDword(datatable)
            state = value2 and (tempvalue >= value) and (tempvalue <= value2)
            if (tempvalue == value) or state then return address + i - 1 end
        end
    elseif (typ == 8) then
        for i = 1, #cvalue, 4 do
            local datatable = {}
            for m = 1, 8 do datatable[m] = cvalue[m + i - 1] end
            tempvalue = byteTableToQword(datatable)
            state = value2 and (tempvalue >= value) and (tempvalue <= value2)
            if (tempvalue == value) or state then return address + i - 1 end
        end
    end
end

function Obj.parseTable(NamePoolData, GUObjectArray)
    Obj.GUObjectAddress = getGUObjectAddress(NamePoolData, GUObjectArray)
    for o = 4, 8 * 4, 4 do
        for k = 0, 10 * o, o do
            local ptr = readPointer(readPointer(Obj.GUObjectAddress) + k)
            if not Obj.checkValue(ptr, 0x50, k / o, 2) then break end
            if (k == (10 * o)) then Obj.UObjectMul = o end
            if Obj.UObjectMul then break end
        end
    end
    Obj.log('FNamePool/GUObjectArray parsed.\n')
end
---------------------------------------------------------------------------------------------------
-- getVersionFromFile
---------------------------------------------------------------------------------------------------
function Obj.getVersionFromFile()
    local fileVer, info = getFileVersion(enumModules()[1].PathToFile)
    local ver = ('%s.%s'):format(info.major, ('%02d'):format(info.minor))
    Obj.log('getVersionFromFile: '..ver..'.'..info.release)
    return tonumber(ver)
end
---------------------------------------------------------------------------------------------------
function Obj.log(...)
    return Obj.isDebug and print(...)
end
---------------------------------------------------------------------------------------------------
return Obj