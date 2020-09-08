
local mt = {}
mt.__gc = function()	
	print("MemTest  gc")
end


local mt2 = {}
mt2.__gc = function()	
	print("instance  gc")
end

local MemTest = setmetatable({}, mt)

local List = {}

print("Address:",List)

function MemTest:TestFunc()

	for i=1,10 do
    	local instance = setmetatable({}, mt2)
    	print("Address Sub:",instance)
    	instance.class = MemTest
    	table.insert(List,instance)
	end

end

function MemTest:Clear()

	List = {} 

end

return MemTest