-- Released AGE.lua by Dhaos
---------------------------------------------------------------------------------------------------
-- Thanks:
-- 【改造 投稿】ARCGameEngine by sceawung 
-- https://necocan-index.rick-addison.com/bbs/patio.cgi?read=64&ukey=1
---------------------------------------------------------------------------------------------------
-- Log:
-- 2020/06/16 Fixed by sceawung
-- 2021/07/27 Refactored and merged by Dhaos
-- 2021/08/17 Created bRot32 & AGEbitFields3 by sceawung
-- 2021/08/22 Fixed by Dhaos
-- 2022/03/19 Created a AGE.lua by Dhaos
-- 2022/04/08 Fixed by Dhaos
-- 2022/07/06 Added registerBitFields by Dhaos
---------------------------------------------------------------------------------------------------
local Obj = {}

Obj.customType = [[
    alloc(TypeName,14)
    alloc(CallMethod,1)
    alloc(ByteSize,4)
    alloc(UsesFloat,1)
    alloc(PreferedAlignment,4)
    alloc(ConvertRoutine,16)
    alloc(ConvertBackRoutine,20)
    alloc(AGEBitsMasker,4)
    registersymbol(AGEBitsMasker)

    TypeName:
        db 'ARCGameEngine', 00

    CallMethod:
        db #1

    ByteSize:
        dd #4

    UsesFloat:
        dd #0

    PreferedAlignment:
        dd #-1

    ConvertRoutine:
        [32-bit]
        mov ecx,[rsp+04]
        [/32-bit]
        mov eax,[rcx]
        xor eax,[AGEBitsMasker]
        ror eax,0E
        ret

    ConvertBackRoutine:
        [32-bit]
        mov ecx,[rsp+04]
        mov eax,[rsp+0C]
        [/32-bit]
        rol ecx,0E
        xor ecx,[AGEBitsMasker]
        [64-bit]
        db 41
        [/64-bit]
        mov [rax],ecx
        ret
]]

function Obj.registerBitFields()
    local bRot32 = function(i, n)
        n = n & 31
        return i >> n | i << (32 - n) & 0xFFFFFFFF
    end
    for i = 0, 31 do
        registerCustomTypeLua('AGEbitField'..i, 4, function(...)
        local v = byteTableToDword({...})
        return bRot32(v ~ readInteger("AUX"), 0x0E) >> i & 1
        end, function(b, a)
        local c = bRot32(readInteger(a) ~ readInteger("AUX"), 0x0E) & ~(1 << i) | (b & 1) << i
        return unpack(dwordToByteTable(bRot32(c, -0x0E) ~ readInteger("AUX")))
        end, false)
    end
end

function Obj.register32bitOnChangeValueType()
    local msg = "Failed to register the ARCGameEngine custom type."
    local ct = registerCustomTypeAutoAssembler(Obj.customType) or error(msg)
    local vt = MainForm.VarType
    for i = vt.Items.Count - 1, 0, -1 do
        local state = (vt.Items[i] == ct.name)
        if state then vt.ItemIndex = i; vt.OnChange(); return end
    end
end

function Obj.customTypeSetup()
    assert((process == 'AGE.EXE'), MainForm.sbOpenProcess.hint..' (AGE.EXE)')
    if Obj.maskValue then return end
    Obj.registerBitFields(); Obj.register32bitOnChangeValueType()
    local IAGEService = executeCodeEx(0, nil, "AGE.GetClassObject", "AGE:IAGEService")
    local COMethod = readPointer(readPointer(IAGEService) + 0x0C)
    local isModern = (readBytes(COMethod, 1) == 0xE9) and 8 or 0
    COMethod = not (isModern == 0) and COMethod + 5 + readInteger(COMethod + 1, true) or nil
    local baseAddr = readPointer(readInteger(COMethod + 1)) + readInteger(COMethod + 7, true)
    local isLatest = not (readPointer(baseAddr + 0x24) == getAddress("kernel32.dll")) and 12 or 0
    local startAddress = readPointer(baseAddr - 0x1470 + isModern)
    local stopAddress  = startAddress + readInteger(baseAddr - 0x1488 + isModern) * 4
    unregisterSymbol("COM3"); registerSymbol("COM3", startAddress)
    unregisterSymbol("AUX"); registerSymbol("AUX", baseAddr + 0x20 + isLatest)
    Obj.maskValue = readInteger("AUX")
    writeIntegerLocal("AGEBitsMasker", Obj.maskValue)
    MainForm.FromAddress.Text = ("%08X"):format(startAddress)
    MainForm.ToAddress.Text   = ("%08X"):format(stopAddress)
	AddressList.OnAddressChange = function(list, row)
		if not (row.Type == vtCustom) then return end
		local addr = row.Address
        if not ('0' <= addr and addr <= '9') then return end
		local curr = row.CurrentAddress
        if not (startAddress <= curr and curr < stopAddress) then return end
		row.Address = ("COM3+%06X"):format(curr - startAddress)
    end
    AddressList.OnDescriptionChange = AddressList.OnAddressChange
    AddressList.OnValueChange       = AddressList.OnAddressChange
end

return Obj