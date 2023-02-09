-- Released Camera.lua under the MIT license
-- Copyright (c) 2023 Dhaos
-- https://opensource.org/licenses/mit-license.php
---------------------------------------------------------------------------------------------------
local Obj = {}
---------------------------------------------------------------------------------------------------
local function writeValue(memrec, sender)
    local val = (type(sender) == 'userdata') and sender.value or tostring(sender)
    if not (memrec.value == '??') then memrec.value = val end
end
---------------------------------------------------------------------------------------------------
function Obj.front(vector3, atan, speed)
    writeValue(vector3[1], vector3[1].value + (math.cos(atan[1]) * speed))
    writeValue(vector3[2], vector3[2].value + (math.sin(atan[1]) * speed))
    if atan[2] then writeValue(vector3[3], vector3[3].value + (math.sin(atan[2]) * speed)) end
end
---------------------------------------------------------------------------------------------------
function Obj.left(vector3, atan, speed)
    writeValue(vector3[1], vector3[1].value + (math.cos(atan[1] - math.rad(90.0)) * speed))
    writeValue(vector3[2], vector3[2].value + (math.sin(atan[1] - math.rad(90.0)) * speed))
end
---------------------------------------------------------------------------------------------------
function Obj.right(vector3, atan, speed)
    writeValue(vector3[1], vector3[1].value - (math.cos(atan[1] - math.rad(90.0)) * speed))
    writeValue(vector3[2], vector3[2].value - (math.sin(atan[1] - math.rad(90.0)) * speed))
end
---------------------------------------------------------------------------------------------------
function Obj.back(vector3, atan, speed)
    writeValue(vector3[1], vector3[1].value - (math.cos(atan[1]) * speed))
    writeValue(vector3[2], vector3[2].value - (math.sin(atan[1]) * speed))
    if atan[2] then writeValue(vector3[3], vector3[3].value - (math.sin(atan[2]) * speed)) end
end
---------------------------------------------------------------------------------------------------
return Obj