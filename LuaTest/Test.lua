
local function getMem()
    return  collectgarbage("count")
end

print(collectgarbage("collect"))

print(getMem())

local memtools = require("G6LuaMemoryTools")
local MemTest2 = require("MemTest2")


MemTest2:Init()

print(getMem())
package.loaded["MemTest"] = nil
package.loaded["MemTest2"] = nil

print(collectgarbage("collect"))

--MemTest2:Clear()
print(getMem())

memtools:SnapshotEndLuaMemory("E:/G6MemoryLog/MemoryBefore.txt")


print("success")




