---
--- 记录和比较lua内存信息
--- Created by berniebwang.
--- DateTime: 2019/1/24 11:55
---
local G6LuaMemoryTools = {}
local isMarkedGlobal = false

local ignoreList = 
{
	"OriRequire"
}
--- 获取以常见方式定义的table类名
--- 返回类名 + 类型
--- UA的四种lua类型
--- 1，InheritC++LuaClass, inherited from native C++ Object 的Lua类
--- 2，PureLuaClass _G.Class创建出来的纯lua类
--- 3, LuaUnrealClass
--- 4, RegisterMetaTable RegisterClass产生的Metatable
local function GetCommonClassName(checkTable,needPath)
	local ret = ""
	local t = 0
	if type(checkTable) == "table" then
		if rawget(checkTable, "__cname") and "string" == type(checkTable.__cname) then
			if rawget(checkTable, "__ctype") and 1 == checkTable.__ctype then
				ret,t = checkTable.__cname,1
			else
				ret,t =  checkTable.__cname,2
			end
		elseif rawget(checkTable, "__className") and "LuaUnrealClass" == checkTable.__className then
			local str = checkTable.__name

			if checkTable.GetName ~=nil then
				local n = checkTable:GetName()
				if n ~= nil then
					str = n
				end
			end
			
			ret,t =  str,3
		elseif rawget(checkTable, "DumpTag") then
			ret,t =  checkTable.__name,4
		end
	elseif type(checkTable) == "userdata" then
		local cMt = getmetatable(checkTable)
		if cMt ~= nil and rawget(cMt,"DumpTag") then
			local str = checkTable.__name

			if checkTable.GetName ~=nil then
				local n = checkTable:GetName()
				if n ~= nil then
					if needPath then
						local temp = checkTable
						while(temp ~= nil) do
							n = temp:GetName() .."."..n
								temp = temp:GetOuter()
						end
					end
					str = n
				end
			end
			ret,t = str.." "..tostring(checkTable),5
		end
	end

	if t ~= 0 then
		if ret == nil then
			ret = "nil"
		end
		if t == 1 then
			ret = "[InheritC++LuaClass:" .. ret .. "]"
		elseif t == 2 then
			ret = "[PureLuaClass:" .. ret .. "]"
		elseif t == 3 then
			ret = "[LuaUnrealClass:" .. ret .. "]"
		elseif t == 4 then
			ret = "[RegisterMetaTable:" .. ret .. "]"
		elseif t == 5 then
			ret = "[UObjectUserdata:" .. ret .. "]"
		end
		return ret
	else
		return nil
	end
end

--- Get the string result without overrided __tostring.
local function GetOriginalToStringResult(cObject)
	if not cObject then
		return ""
	end
	
	local strName = ""

	local cMt = getmetatable(cObject)
	if cMt then
		-- Check tostring override.
		local cToString = rawget(cMt, "__tostring")
		if cToString then
			rawset(cMt, "__tostring", nil)
			strName = tostring(cObject)
			rawset(cMt, "__tostring", cToString)
		else
			strName = tostring(cObject)
		end
	else
		strName = tostring(cObject)
	end

	local commonClassName = GetCommonClassName(cObject,true)
	if commonClassName ~= nil then
		strName = commonClassName
	end

	return strName
end

--- 获取类名
local function CheckTableWithClassName(checkTable, originName)
	local name = originName
	local commonClassName = GetCommonClassName(checkTable)
	if commonClassName ~= nil then
		name = originName .. commonClassName
	end

	-- isMarkedGlobal防止后面在UObject == ? 时导致引擎asset
	if not isMarkedGlobal and checkTable == _G then
		isMarkedGlobal = true
		name = "_G"
	end
	return name
end

--- 返回表的weak属性和元表
local function GetTableWeak(checkTable)
	-- Get metatable.
	local bWeakK = false
	local bWeakV = false
	local mt = getmetatable(checkTable)
	if mt then
		local strMode = rawget(mt, "__mode")
		if strMode then
			if "k" == strMode then
				bWeakK = true
			elseif "v" == strMode then
				bWeakV = true
			elseif "kv" == strMode then
				bWeakK = true
				bWeakV = true
			end
		end
	end
	return bWeakK, bWeakV
end

local function SetContainerStackInfo(dumpInfoContainer, stackLevel)
	local stackInfo = debug.getinfo(stackLevel, "Sl")
	if stackInfo then
		dumpInfoContainer.m_strShortSrc = stackInfo.short_src
		dumpInfoContainer.m_nCurrentLine = stackInfo.currentline
	end
end

--- 创建存储引用信息的table
local function CreateObjectReferenceInfoContainer()
	isMarkedGlobal = false

	local cContainer = {}

	local cObjectReferenceCount = {}
	setmetatable(cObjectReferenceCount, {__mode = "k"})

	local cObjectAddressToName = {}
	setmetatable(cObjectAddressToName, {__mode = "k"})

	-- Set members.
	cContainer.m_cObjectReferenceCount = cObjectReferenceCount
	cContainer.m_cObjectAddressToName = cObjectAddressToName

	-- For stack info.
	cContainer.m_nStackLevel = -1
	cContainer.m_strShortSrc = "None"
	cContainer.m_nCurrentLine = -1

	return cContainer
end

--- 创建存储单个对象完整引用信息的table
local function CreateSingleObjectReferenceInfoContainer(strObjectName, cObject)
	isMarkedGlobal = false

	local cContainer = {}

	-- Contain [address] - [true] info.
	local cObjectExistTag = {}
	setmetatable(cObjectExistTag, {__mode = "k"})

	-- Contain [name] - [true] info.
	local cObjectAliasName = {}

	-- Contain [access] - [true] info.
	local cObjectAccessTag = {}
	setmetatable(cObjectAccessTag, {__mode = "k"})

	-- Set members.
	cContainer.m_cObjectExistTag = cObjectExistTag
	cContainer.m_cObjectAliasName = cObjectAliasName
	cContainer.m_cObjectAccessTag = cObjectAccessTag

	-- For stack info.
	cContainer.m_nStackLevel = -1
	cContainer.m_strShortSrc = "None"
	cContainer.m_nCurrentLine = -1

	-- Init with object values.
	cContainer.m_strObjectName = strObjectName
	cContainer.m_strAddressName = (("string" == type(cObject)) and ("\"" .. tostring(cObject) .. "\"")) or GetOriginalToStringResult(cObject)
	cContainer.m_cObjectExistTag[cObject] = true

	return cContainer
end

--- 创建存储包含指定类名的引用信息的容器
---@param className string
local function CreateRefInfoContainerWithClassName(className)
	isMarkedGlobal = false

	local cContainer = {}

	-- Contain [address] - [true] info.
	local cObjectExistTag = {}
	setmetatable(cObjectExistTag, {__mode = "k"})

	-- Contain [name] - [true] info.
	local cObjectAliasName = {}

	-- Contain [access] - [true] info.
	local cObjectAccessTag = {}
	setmetatable(cObjectAccessTag, {__mode = "k"})

	-- Set members.
	cContainer.m_cObjectAliasName = cObjectAliasName
	cContainer.m_cObjectAccessTag = cObjectAccessTag

	-- For stack info.
	cContainer.m_nStackLevel = -1
	cContainer.m_strShortSrc = "None"
	cContainer.m_nCurrentLine = -1

	-- Init with object values.
	cContainer.searchClassName = className

	SetContainerStackInfo(cContainer, 2)
	
	return cContainer
end

--- 创建UE4对象检测所需容器
---@param isValidLowLevel boolean 是否调用IsValidLowLevel
local function CreateUObjectCheckInfoContainer(isValidLowLevel)
	isMarkedGlobal = false

	local cContainer = {}

	-- Contain [address] - [true] info.
	local cObjectExistTag = {}
	setmetatable(cObjectExistTag, {__mode = "k"})

	-- Contain [name] - [true] info.
	local cObjectAliasName = {}
	local cObjectTypeMap = {}

	-- Contain [access] - [true] info.
	local cObjectAccessTag = {}
	setmetatable(cObjectAccessTag, {__mode = "k"})

	-- Set members.
	cContainer.m_cObjectAliasName = cObjectAliasName
	cContainer.m_cObjectTypeMap = cObjectTypeMap
	cContainer.m_cObjectAccessTag = cObjectAccessTag

	-- For stack info.
	cContainer.m_nStackLevel = -1
	cContainer.m_strShortSrc = "None"
	cContainer.m_nCurrentLine = -1

	cContainer.isValidLowLevel = isValidLowLevel

	SetContainerStackInfo(cContainer, 2)
	
	return cContainer
end

local function AddReferenceInfo(dumpInfoContainer, searchObj, name)
	for i = 1,#ignoreList do
		if name ~= nil and string.find(name, ignoreList[i]) ~= nil then
			return false
		end
	end
	local refInfoContainer = dumpInfoContainer.m_cObjectReferenceCount
	local nameInfoContainer = dumpInfoContainer.m_cObjectAddressToName

	-- Add reference count and name.
	refInfoContainer[searchObj] = (refInfoContainer[searchObj] and (refInfoContainer[searchObj] + 1)) or 1
	if nameInfoContainer[searchObj] then
		return false
	end
	-- Set name.
	nameInfoContainer[searchObj] = name
	return true
end

local function AddSingleObjectReferenceInfo(dumpInfoContainer, searchObj, name)
	local existTag = dumpInfoContainer.m_cObjectExistTag
	local nameAllAlias = dumpInfoContainer.m_cObjectAliasName
	local accessTag = dumpInfoContainer.m_cObjectAccessTag
	-- Check if the specified object.
	if existTag[searchObj] and (not nameAllAlias[name]) then
		nameAllAlias[name] = true
	end

	-- Add reference and name.
	if accessTag[searchObj] then
		return false
	end

	-- Get this name.
	accessTag[searchObj] = true
	return true
end

local function AddRefInfoWithClassName(dumpInfoContainer, searchObj, name)
	for i = 1,#ignoreList do
		if name ~= nil and string.find(name, ignoreList[i]) ~= nil then
			return false
		end
	end

	local nameAllAlias = dumpInfoContainer.m_cObjectAliasName
	local accessTag = dumpInfoContainer.m_cObjectAccessTag

	-- Check if the specified object.
	local searchClassName = dumpInfoContainer.searchClassName
	if name ~= nil and searchClassName ~= nil then
		local startIndex, endIndex = string.find(name, searchClassName)
		if startIndex ~= nil and (not nameAllAlias[name]) then
			nameAllAlias[name] = true
		end
	end

	if accessTag[searchObj] then
		return false
	end

	accessTag[searchObj] = true
	return true
end

local function CheckUObject(dumpInfoContainer, searchObj, name)
	local nameAllAlias = dumpInfoContainer.m_cObjectAliasName
	local typeMap = dumpInfoContainer.m_cObjectTypeMap
	local accessTag = dumpInfoContainer.m_cObjectAccessTag
	local isValidLowLevel = dumpInfoContainer.isValidLowLevel

	if type(searchObj) == "userdata" then
		xpcall(
		function()
			local isValid
			if isValidLowLevel then
				isValid = searchObj:IsValidLowLevel()
			else
				isValid = searchObj:IsValid()
			end
			if not isValid then
				if isValid == nil then
					nameAllAlias[name] = "NULL_PTR"	
				else
					nameAllAlias[name] = "FALSE"
				end
				typeMap[name] = GetOriginalToStringResult(searchObj)
			end
        end,


        function(error)
            print(LogType.G6FrameWork, Info,string.format("CheckUObject name:%s", error))
		end
		)
	end

	-- Add reference and name.
	if accessTag[searchObj] then
		return false
	end

	-- Get this name.
	accessTag[searchObj] = true
	return true
end

--- 遍历收集内存信息
local function InternalCollectMemory(strName, cObject, cDumpInfoContainer, recordFunction, isCheckWeakTable)
	if not cObject then
		return
	end
	strName = strName or "unknown"
	-- Check stack.
	if cDumpInfoContainer.m_nStackLevel > 0 then
		SetContainerStackInfo(cDumpInfoContainer, cDumpInfoContainer.m_nStackLevel)
		cDumpInfoContainer.m_nStackLevel = -1
	end

	local collectMetatable = function(name)
		-- Dump metatable.
		local mt = getmetatable(cObject)
		if mt then
			InternalCollectMemory(name, mt, cDumpInfoContainer, recordFunction)
		end
	end

	local collectFenv = function(name)
		-- Dump environment table.
		local getfenv = debug.getfenv
		if getfenv then
			local cEnv = getfenv(cObject)
			if cEnv then
				InternalCollectMemory(name, cEnv, cDumpInfoContainer, recordFunction)
			end
		end
	end

	local strType = type(cObject)
	if "table" == strType then
		strName = CheckTableWithClassName(cObject, strName)

		local bWeakK, bWeakV = GetTableWeak(cObject)

		if not recordFunction(cDumpInfoContainer, cObject, strName) then
			return
		end

		-- Dump table key and value.
		for k, v in pairs(cObject) do
			local strKeyType = type(k)
			local keyName
			local vName
			if "table" == strKeyType then
				keyName = strName .. ".[table:key.table]"
				vName = strName .. ".[table:value]"
			elseif "function" == strKeyType then
				keyName = strName .. ".[table:key.function]"
				vName = strName .. ".[table:value]"
			elseif "thread" == strKeyType then
				keyName = strName .. ".[table:key.thread]"
				vName = strName .. ".[table:value]"
			elseif "userdata" == strKeyType then
				keyName = strName .. ".[table:key.userdata]"
				vName = strName .. ".[table:value]"
			else
				k = string.gsub(k,"[\x00-\x08\x0C\x0E-\x1F\x7F-\x9F]","")

				vName = strName .. "." .. tostring(k)
			end

			if keyName and (isCheckWeakTable or not bWeakK) then
				InternalCollectMemory(keyName, k, cDumpInfoContainer, recordFunction)
			end

			if vName and (isCheckWeakTable or not bWeakV) then
				InternalCollectMemory(vName, v, cDumpInfoContainer, recordFunction)
			end
		end

		collectMetatable(strName ..".[metatable]")
	elseif "function" == strType then
		-- Get function info.
		local cDInfo = debug.getinfo(cObject, "Su")

		if not recordFunction(cDumpInfoContainer, cObject, strName .. "[line:" .. tostring(cDInfo.linedefined) .. "@file:" .. cDInfo.short_src .. "]") then
			return
		end

		-- Get upvalues.
		local nUpsNum = cDInfo.nups
		for i = 1, nUpsNum do
			local strUpName, cUpValue = debug.getupvalue(cObject, i)
			local strUpValueType = type(cUpValue)
			--print(LogType.G6FrameWork, Info,strUpName, cUpValue)
			if "table" == strUpValueType then
				strUpName = strName .. ".[ups:table:" .. strUpName .. "]"
			elseif "function" == strUpValueType then
				strUpName = strName .. ".[ups:function:" .. strUpName .. "]"
			elseif "thread" == strUpValueType then
				strUpName = strName .. ".[ups:thread:" .. strUpName .. "]"
			elseif "userdata" == strUpValueType then
				strUpName = strName .. ".[ups:userdata:" .. strUpName .. "]"
			end
			InternalCollectMemory(strUpName, cUpValue, cDumpInfoContainer, recordFunction)
		end

		collectFenv(strName ..".[function:environment]")
	elseif "thread" == strType then
		if not recordFunction(cDumpInfoContainer, cObject, strName) then
			return
		end

		collectFenv(strName ..".[thread:environment]")
		collectMetatable(strName ..".[thread:metatable]")
	elseif "userdata" == strType then
		if not recordFunction(cDumpInfoContainer, cObject, strName) then
			return
		end

		collectFenv(strName ..".[userdata:environment]")
		collectMetatable(strName ..".[userdata:metatable]")
	elseif "string" == strType then
		-- if not recordFunction(cDumpInfoContainer, cObject, strName .. "[" .. strType .. "]") then
		-- 	return
		-- end
	else
		-- For "number" and "boolean". (If you want to dump them, uncomment the followed lines.)

		-- if not recordFunction(cDumpInfoContainer, cObject, strName .. "[" .. strType .. "]") then
		-- 	return
		-- end
	end
end

local function CollectObjectReferenceInMemory(strName, cObject, cDumpInfoContainer)
	InternalCollectMemory(strName, cObject, cDumpInfoContainer, AddReferenceInfo)
end

local function CollectSingleObjectReferenceInMemory(strName, cObject, cDumpInfoContainer)
	InternalCollectMemory(strName, cObject, cDumpInfoContainer, AddSingleObjectReferenceInfo)
end

-- Create a container to collect the mem ref info results from a dumped file.
-- strFilePath - The file path.
local function CreateObjectReferenceInfoContainerFromFile(strFilePath)
	-- Create a empty container.
	local cContainer = CreateObjectReferenceInfoContainer()
	cContainer.m_strShortSrc = strFilePath

	-- Cache ref info.
	local cRefInfo = cContainer.m_cObjectReferenceCount
	local cNameInfo = cContainer.m_cObjectAddressToName

	-- Read each line from file.
	local cFile = assert(io.open(strFilePath, "rb"))
	for strLine in cFile:lines() do
		local strHeader = string.sub(strLine, 1, 2)
		if "--" ~= strHeader then
			local _, _, strAddr, strName, strRefCount= string.find(strLine, "(.+)\t(.*)\t(%d+)")
			if strAddr then
				cRefInfo[strAddr] = strRefCount
				cNameInfo[strAddr] = strName
			end
		end
	end

	-- Close and clear file handler.
	io.close(cFile)
	cFile = nil

	return cContainer
end

local function OutputMemorySnapshot(strSavePath, strRootObjectName, cRootObject, cDumpInfoResultsBase, cDumpInfoResults)
	-- Check results.
	if not cDumpInfoResults then
		return
	end

	-- Collect memory info.
	local cRefInfoBase = (cDumpInfoResultsBase and cDumpInfoResultsBase.m_cObjectReferenceCount) or nil
	local cRefInfo = cDumpInfoResults.m_cObjectReferenceCount -- object2refCount
	local cNameInfo = cDumpInfoResults.m_cObjectAddressToName -- object2refString

	-- Create a cache result to sort by ref count.
	local cRes = {}
	local nIdx = 0
	for k in pairs(cRefInfo) do
		nIdx = nIdx + 1
		cRes[nIdx] = k
	end

	-- Sort result.
	table.sort(cRes, function (l, r)
		return cRefInfo[l] > cRefInfo[r]
	end)

	--local cFile = assert(io.open(strSavePath, "w"))
	local saveFile = io.open(strSavePath, "w")

	-- Write table header.
	if cDumpInfoResultsBase then
		saveFile:write("--------------------------------------------------------\n")
		saveFile:write("-- This is compared memory information.\n")
		saveFile:write("--------------------------------------------------------\n")
		saveFile:write("-- Collect base memory reference at line:" .. tostring(cDumpInfoResultsBase.m_nCurrentLine) .. "@file:" .. cDumpInfoResultsBase.m_strShortSrc .. "\n")
		saveFile:write("-- Collect compared memory reference at line:" .. tostring(cDumpInfoResults.m_nCurrentLine) .. "@file:" .. cDumpInfoResults.m_strShortSrc .. "\n")
	else
		saveFile:write("--------------------------------------------------------\n")
		saveFile:write("-- Collect memory reference at line:" .. tostring(cDumpInfoResults.m_nCurrentLine) .. "@file:" .. cDumpInfoResults.m_strShortSrc .. "\n")
	end

	saveFile:write("--------------------------------------------------------\n")
	saveFile:write("-- [Table/Function/String Address/Name]\t[Reference Path]\t[Reference Count]\n")
	saveFile:write("--------------------------------------------------------\n\n")

	if strRootObjectName and cRootObject then
		if type(cRootObject) == "string" then
			saveFile:write(string.format("-- From Root Object: \"%s\" (%s)\n", tostring(cRootObject), strRootObjectName))
		else
			saveFile:write(string.format("-- From Root Object: %s (%s)\n", GetOriginalToStringResult(cRootObject), strRootObjectName))
		end
	end

	-- Save each info.
	for i, v in ipairs(cRes) do
		if (not cDumpInfoResultsBase) or (not cRefInfoBase[v]) then
			if "string" == type(v) then
				local strOrgString = tostring(v)
				local nPattenBegin, nPattenEnd = string.find(strOrgString, "string: \".*\"")
				if ((not cDumpInfoResultsBase) and ((nil == nPattenBegin) or (nil == nPattenEnd))) then
					local strRepString = string.gsub(strOrgString, "([\n\r])", "\\n")
					saveFile:write("string: \"" .. strRepString .. "\"\t" .. cNameInfo[v] .. "\t" .. tostring(cRefInfo[v]) .. "\n\n")
				else
					saveFile:write(tostring(v) .. "\t" .. cNameInfo[v] .. "\t" .. tostring(cRefInfo[v]) .. "\n\n")
				end
			else
				saveFile:write(GetOriginalToStringResult(v) .. "\t" .. cNameInfo[v] .. "\t" .. tostring(cRefInfo[v]) .. "\n\n")
			end
		end
	end

	saveFile:close()
end

local function OutputMemorySnapshotSingleObject(strSavePath, cDumpInfoResults)
	-- Check results.
	if not cDumpInfoResults then
		return
	end

	-- Collect memory info.
	local cObjectAliasName = cDumpInfoResults.m_cObjectAliasName

	local saveFile = io.open(strSavePath, "w")

	-- Write table header.
	saveFile:write("--------------------------------------------------------\n")
	saveFile:write("-- Collect single object memory reference at line:" .. tostring(cDumpInfoResults.m_nCurrentLine) .. "@file:" .. cDumpInfoResults.m_strShortSrc .. "\n")
	saveFile:write("--------------------------------------------------------\n")

	-- Calculate reference count.
	local nCount = 0
	for k in pairs(cObjectAliasName) do
		nCount = nCount + 1
	end

	-- Output reference count.
	saveFile:write("-- For Object: " .. cDumpInfoResults.m_strAddressName .. " (" .. cDumpInfoResults.m_strObjectName .. "), have " .. tostring(nCount) .. " reference in total.\n")
	saveFile:write("--------------------------------------------------------\n\n")

	-- Save each info.
	for k in pairs(cObjectAliasName) do
		saveFile:write(k .. "\n\n")
	end

	saveFile:close()
end

local function OutputMemorySnapshotWithClsName(strSavePath, cDumpInfoResults)
	-- Check results.
	if not cDumpInfoResults then
		return
	end

	-- Collect memory info.
	local cObjectAliasName = cDumpInfoResults.m_cObjectAliasName

	local saveFile = io.open(strSavePath, "w")

	-- Write table header.
	saveFile:write("--------------------------------------------------------\n")
	saveFile:write("-- Collect memory reference with class name at line:" .. tostring(cDumpInfoResults.m_nCurrentLine) .. "@file:" .. cDumpInfoResults.m_strShortSrc .. "\n")
	saveFile:write("--------------------------------------------------------\n")

	-- Calculate reference count.
	local nCount = 0
	for k in pairs(cObjectAliasName) do
		nCount = nCount + 1
	end

	-- Output reference count.
	saveFile:write(string.format("-- For className: \"%s\", have %d reference in total.\n", cDumpInfoResults.searchClassName, nCount))
	saveFile:write("--------------------------------------------------------\n\n")

	-- Save each info.
	for k in pairs(cObjectAliasName) do
		saveFile:write(k .. "\n\n")
	end

	saveFile:close()
end

local function OutputMemoryUObjectCheckResult(strSavePath, cDumpInfoResults)
	-- Check results.
	if not cDumpInfoResults then
		return
	end

	-- Collect memory info.
	local cObjectAliasName = cDumpInfoResults.m_cObjectAliasName
	local cObjectTypeMap = cDumpInfoResults.m_cObjectTypeMap
	
	local saveFile = io.open(strSavePath, "w")

	-- Calculate reference count.
	local nCount = 0
	for k in pairs(cObjectAliasName) do
		nCount = nCount + 1
	end
	
	-- Output reference count.
	saveFile:write("--------------------------------------------------------\n")
	saveFile:write(string.format("-- :Have %d result in total. isValidLowLevel:%s \n", nCount, cDumpInfoResults.isValidLowLevel))
	saveFile:write("--------------------------------------------------------\n\n")

	-- Save each info.
	for k, v in pairs(cObjectAliasName) do
		saveFile:write(string.format("%s | %s | CheckResult:%s\n", cObjectTypeMap[k], k, v))
	end

	saveFile:close()
end

---@param savePath string 快照文件存放路径
---@param rootObject table 快照根对象
---@param rootObjectName string 快照根对象名称
local function DumpMemorySnapshot(savePath, rootObject, rootObjectName)
    if rootObject == nil then
		error("G6LuaMemoryTools: rootObject is nil!")
        return
    end
    rootObjectName = rootObjectName or tostring(rootObject)

	local cDumpInfoContainer = CreateObjectReferenceInfoContainer()
	SetContainerStackInfo(cDumpInfoContainer, 2)

	-- Collect memory info.
	CollectObjectReferenceInMemory(rootObjectName, rootObject, cDumpInfoContainer)
	
	-- Dump the result.
	OutputMemorySnapshot(savePath, rootObjectName, rootObject, nil, cDumpInfoContainer)
end

local function DumpMemorySnapshotComparedFile(strSavePath, strResultFilePathBefore, strResultFilePathAfter)
	-- Read results from file.
	local cResultBefore = CreateObjectReferenceInfoContainerFromFile(strResultFilePathBefore)
	local cResultAfter = CreateObjectReferenceInfoContainerFromFile(strResultFilePathAfter)

	-- Dump the result.
	OutputMemorySnapshot(strSavePath,nil,nil, cResultBefore, cResultAfter)
end

local function DumpMemorySnapshotSingleObject(strSavePath, strObjectName, cObject)
	-- Check object.
	if not cObject then
		return
	end

	if (not strObjectName) or (0 == string.len(strObjectName)) then
		strObjectName = GetOriginalToStringResult(cObject)
	end

	-- Create container.
	local cDumpInfoContainer = CreateSingleObjectReferenceInfoContainer(strObjectName, cObject)
	SetContainerStackInfo(cDumpInfoContainer, 2)

	-- Collect memory info.
	CollectSingleObjectReferenceInMemory("registry", debug.getregistry(), cDumpInfoContainer)

	-- Dump the result.
	OutputMemorySnapshotSingleObject(strSavePath, cDumpInfoContainer)
end

local function OutputFilteredResult(strFilePath, strFilter, bIncludeFilter, bOutputFile)
	if (not strFilePath) or (0 == string.len(strFilePath)) then
		print(LogType.G6FrameWork, Info,"You need to specify a file path.")
		return
	end

	if (not strFilter) or (0 == string.len(strFilter)) then
		print(LogType.G6FrameWork, Info,"You need to specify a filter string.")
		return
	end

	-- Read file.
	local cFilteredResult = {}
	local cReadFile = assert(io.open(strFilePath, "rb"))
	for strLine in cReadFile:lines() do
		local nBegin, nEnd = string.find(strLine, strFilter)
		if nBegin and nEnd then
			if bIncludeFilter then
				nBegin, nEnd = string.find(strLine, "[\r\n]")
				if nBegin and nEnd  and (string.len(strLine) == nEnd) then
					table.insert(cFilteredResult, string.sub(strLine, 1, nBegin - 1))
				else
					table.insert(cFilteredResult, strLine)
				end
			end
		else
			if not bIncludeFilter then
				nBegin, nEnd = string.find(strLine, "[\r\n]")
				if nBegin and nEnd and (string.len(strLine) == nEnd) then
					table.insert(cFilteredResult, string.sub(strLine, 1, nBegin - 1))
				else
					table.insert(cFilteredResult, strLine)
				end
			end
		end
	end

	-- Close and clear read file handle.
	io.close(cReadFile)
	cReadFile = nil

	-- Write filtered result.
	local cOutputHandle = nil
	local cOutputEntry = print

	if bOutputFile then
		-- Combine file name.
		local _, _, strResFileName = string.find(strFilePath, "(.*)%.txt")
		strResFileName = strResFileName .. "-Filter-" .. ((bIncludeFilter and "I") or "E") .. "-[" .. strFilter .. "].txt"

		local cFile = assert(io.open(strResFileName, "w"))
		cOutputHandle = cFile
		cOutputEntry = cFile.write
	end

	local cOutputer = function (strContent)
		if cOutputHandle then
			cOutputEntry(cOutputHandle, strContent)
		else
			cOutputEntry(strContent)
		end
	end

	-- Output result.
	for i, v in ipairs(cFilteredResult) do
		cOutputer(v .. "\n")
	end

	if bOutputFile then
		io.close(cOutputHandle)
		cOutputHandle = nil
	end
end

--- 将registry内存信息保存到指定路径
---@param savePath string 快照文件存放路径
local function SnapshotRegistryMemory(savePath)
    DumpMemorySnapshot(savePath, debug.getregistry(), "registry")
end

function G6LuaMemoryTools:SnapshotStartLuaMemory(savePath, isAutoSuffix)
	local fileSavePath = savePath
	if isAutoSuffix then
		fileSavePath = fileSavePath .. "_Start.txt"
	end
	SnapshotRegistryMemory(fileSavePath)
end

function G6LuaMemoryTools:SnapshotEndLuaMemory(savePath, isAutoSuffix)
	local fileSavePath = savePath
	if isAutoSuffix then
		fileSavePath = fileSavePath .. "_End.txt"
	end
	SnapshotRegistryMemory(fileSavePath)
end

function G6LuaMemoryTools:CompareSnapShot(savePath, firstSnapPath, secondSnapPath, isAutoSuffix)
	local tempSavePath = savePath
	local tempFirstSnapPath = firstSnapPath or savePath
	local tempSecondSnapPath = secondSnapPath or savePath
	if isAutoSuffix then
		tempSavePath = savePath .. "_Compare.txt"
		tempFirstSnapPath = tempFirstSnapPath .. "_Start.txt"
		tempSecondSnapPath = tempSecondSnapPath .. "_End.txt"
	end
	DumpMemorySnapshotComparedFile(tempSavePath, tempFirstSnapPath, tempSecondSnapPath)
end

--- 列出指定对象的所有引用
---@param savePath string 输出文本文件路径
---@param strObjectName string 日志中记录中的对象名称，目前仅供日志显示使用
---@param cObject any 要查找的对象
function G6LuaMemoryTools:ListSingleObjectAllReference(savePath, strObjectName, cObject)
	DumpMemorySnapshotSingleObject(savePath, strObjectName, cObject)
end

--- 列出包含指定名称的table的所有引用信息，table定义类型要符合GetCommonClassName()
---@param savePath string 输出文本文件路径
---@param className string 要包含的指定名称，同string.find()中的pattern用法
---@param cObject any 要查找的对象
function G6LuaMemoryTools:ListRefInfoWithClassName(savePath, searchClsName, searchRoot)
	if searchClsName == nil or searchClsName == "" then
		return
	end
	
	-- Create container.
	local cDumpInfoContainer = CreateRefInfoContainerWithClassName(searchClsName)
	searchRoot = searchRoot or debug.getregistry()
	InternalCollectMemory("registry", searchRoot, cDumpInfoContainer, AddRefInfoWithClassName)
	
	-- Dump the result.
	OutputMemorySnapshotWithClsName(savePath, cDumpInfoContainer)
end

--- 检测无效的UObject对象
---@param savePath string 输出文本文件路径
---@param cObject any 开始查找的根对象
---@param isLowLevel boolean 是否调用IsValidLowLevel
function G6LuaMemoryTools:CheckUObjValid(savePath, searchRoot, isValidLowLevel)
	searchRoot = searchRoot or debug.getregistry()
	isValidLowLevel = isValidLowLevel or false
	-- Create container.
	local cDumpInfoContainer = CreateUObjectCheckInfoContainer(isValidLowLevel)
	InternalCollectMemory("registry", searchRoot, cDumpInfoContainer, CheckUObject, true)
	-- Dump the result.
	OutputMemoryUObjectCheckResult(savePath, cDumpInfoContainer)
end

return G6LuaMemoryTools