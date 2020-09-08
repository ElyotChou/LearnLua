
-- -- 计算字符串宽度
 
-- local str = "we我们"
-- local fontSize = 20
-- local lenInByte = #str
-- local width = 0
 

-- -- 字符串保存到table
-- function stringToTable(s)
--     local tb = {}

--     --[[
--     UTF8的编码规则：
--     1. 字符的第一个字节范围： 0x00—0x7F(0-127),或者 0xC2—0xF4(194-244);
--         UTF8 是兼容 ascii 的，所以 0~127 就和 ascii 完全一致
--     2. 0xC0, 0xC1,0xF5—0xFF(192, 193 和 245-255)不会出现在UTF8编码中
--     3. 0x80—0xBF(128-191)只会出现在第二个及随后的编码中(针对多字节编码，如汉字)
--     ]]
--     for utfChar in string.gmatch(s, "[%z\1-\127\194-\244][\128-\191]*") do
--         table.insert(tb, utfChar)
--     end

--     return tb
-- end

-- function Bytes4Character(theByte)
--     local seperate = {0, 0xc0, 0xe0, 0xf0}
--     for i = #seperate, 1, -1 do
--         if theByte >= seperate[i] then return i end
--     end
--     return 1
-- end

-- function HandleLongTxt(str,maxLen)

-- 	local strTable = stringToTable(str)

-- 	local newStr = {}

-- 	local curLen = 0
--  	for i = 1,#strTable do

--  		local result = Bytes4Character(string.byte(strTable[i], 1))
--  		if result == 3 then
--  			curLen = curLen + 2
--  		else
--  			curLen = curLen + 1
--  		end

--  		table.insert(newStr,strTable[i])

--  		if curLen >= maxLen then
--  			table.insert(newStr,"...")
--  			break
--  		end
--  	end


--  	return table.concat(newStr)

-- end

-- local result = HandleLongTxt("你好你v好你好你好你好",12)
-- print(result)

-- local timestamp = 1561636137;
-- local strDate = os.date("%H:%M:%S", timestamp)
-- print("strDate = ", strDate);

local function getMem()
    return  collectgarbage("count")
end

print(collectgarbage("collect"))

print(getMem())

local memtools = require("G6LuaMemoryTools")
local MemTest2 = require("MemTest2")

-- local map = debug.getregistry()
-- local datas = map["_LOADED"]
-- for k,v in pairs(datas) do
--     print(k,v)
-- end

MemTest2:Init()

print(getMem())
package.loaded["MemTest"] = nil
package.loaded["MemTest2"] = nil

print(collectgarbage("collect"))

--MemTest2:Clear()
print(getMem())

memtools:SnapshotEndLuaMemory("E:/G6MemoryLog/MemoryBefore.txt")

-- local f = MemTest.TestFunc
-- print(f)


-- collectgarbage("collect")

-- print(getMem())

-- MemTest:TestFunc()
-- print(MemTest.List)

-- print(getMem())

-- package.loaded["MemTest"] = nil

-- local map = debug.getregistry()
-- local datas = map["_LOADED"]
-- for k,v in pairs(datas) do
--     print(k,v)
-- end


-- print(getMem())

-- print(MemTest)

-- collectgarbage("collect")
-- memtools:SnapshotEndLuaMemory("E:/G6MemoryLog/MemoryBefore.txt")

-- MemTest:Clear()
-- print(getMem())



print("success")




