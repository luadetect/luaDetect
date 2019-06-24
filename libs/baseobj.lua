

--用复制的方式继承
function __inheritByCopy(self, o)
	--inherit by copy
	for k, v in pairs(self) do
		if not IsClsReservedVarName(k) and nil == o[k] then
			o[k] = v
		end
	end
end

--用metatable的方式继承
function __inheritByMetatable(self, o)
	--inherit by metatable
	setmetatable(o, {__index = self})
end

CObject = {
	_isCls = true,
	TypeStr = "CObject",
	_clsName = "CObject",
	doInherit = __inheritByCopy,
}

__objGlobalIdx = 1

local reservedVarNameDict = {
	["_isCls"] = true,
	["_clsRef"] = true,
	["_superClass"] = true,
	["_subClassList"] = true,
	["_touchEventInfoDict"] = true,
	["_clsName"] = true,
}
function IsClsReservedVarName(varName)
	return reservedVarNameDict[varName]
end

function IsClass(ref)
	return rawget(ref, "_isCls")
end
function IsObj(ref)
	return rawget(ref, "_clsRef")
end

function Super(cls)
	return rawget(cls, "_superClass")
end

function GetSubClsList(cls)
	return rawget(cls, "_subClassList")
end

function GetObjClass(obj)
	return rawget(obj, "_clsRef")
end

function CObject:new(o)
	assert(IsClass(self), 'obj cannot use new to gen subclass')
	o = o or {}

	--如果要在运行时修改类静态成员，可以使用GetObjClass(self)取到类引用进行修改
	self:doInherit(o)

	rawset(o, "_superClass", self)
	rawset(o, "_isCls", true)
	local subClassList = rawget(self, "_subClassList")
	if subClassList == nil then
		--子类的引用是一个弱引用，如果子类本身不被其他东西所引用就会被回收
		--这样就可以支持更新了
		subClassList = {}
		setmetatable(subClassList, {__mode="v"})
		rawset(self, "_subClassList", subClassList)
	end
	assert(self ~= o)
	table.insert(subClassList, o)
	return o
end

function CObject:newInstance(o)
	o = o or {}
	--self.__index = self
	--setmetatable(o, self)
	setmetatable(o, {__index = self})
	rawset(o, "_clsRef", self)

	o._objId = __objGlobalIdx
	__objGlobalIdx = __objGlobalIdx + 1

	return o
end

function CObject:create(...)
	local inst = self:newInstance()
	if inst.init then
		inst:init(...)
	end
	return inst
end

function CObject:getObjId()
	return self._objId
end

function CObject:getClsType()
	return self.TypeStr
end

function CObject:getClsName()
	return tostring(self._clsName)
end

function CObject:toString()
	return string.format("clsName=%s,objId=%d", self:getClsName() or "noCls", self:getObjId())
end
function CObject:__update__()
end

function CObject:updateModule(oldClass)
	-- 这里的self 其实是类本身
	local subClsList = GetSubClsList(self)
	if subClsList then
		for idx, sub in ipairs(subClsList) do
			local oldSub = table.copy(sub)
			for k, v in pairs(self) do
				if not IsClsReservedVarName(k) and (not rawget(sub, k) or sub[k] == oldClass[k]) then
					sub[k] = self[k]
				end
			end
			assert(sub ~= self)
			sub:updateModule(oldSub)
		end
	end
	self:__update__()
end
