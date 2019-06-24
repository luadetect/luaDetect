require("libs.baseobj")
clsHeapNode = CObject:new{
	TypeStr = "clsHeapNode"
}

function clsHeapNode:init(Value, Id)
	Super(clsHeapNode).init(self, Value, Id)
	self.Value = Value
	self.Id = Id
end

function clsHeapNode:__SetId(Id)
	self.Id = Id
end

function clsHeapNode:SetIndex(Index)
	self.Index = Index
end

function clsHeapNode:GetIndex()
	return self.Index
end

function clsHeapNode:IdEqual(Other)
	return self.Id == Other.Id
end

function clsHeapNode:HigherPriority(Other)
	return self.Value < Other.Value
end

function clsHeapNode:EqualPriority(Other)
	return self.Value == Other.Value
end

function clsHeapNode:GetValue()
	return self.Value
end

function clsHeapNode:GetId()
	return self.Id
end

function clsHeapNode:OnPoped()
end

function clsHeapNode:Clone()
	return self
end

clsHeap = CObject:new{
	TypeStr = "clsHeap"
}

function clsHeap:init(IsAutoId)
	Super(clsHeap).init(self, IsAutoId)
	if IsAutoId then
		self.IncreaseId = 0
	end
	self.Array = {}
	self.IndexTbl = {}
end

function clsHeap:Clone()
	local NewHeap = self:New(self.IncreaseId == 0)
	for _, node in pairs(self.Array) do
		local newNode = node:Clone()
		table.insert(NewHeap.Array, newNode)
	end

	for k, v in pairs(self.IndexTbl) do
		NewHeap.IndexTbl[k] = v
	end
	return NewHeap
end

function clsHeap:Clean()
	self.Array = {}
	self.IndexTbl = {}
end

function clsHeap:GetLen()
	return #(self.Array)
end

function clsHeap:Push(Node)
	if self.IncreaseId and not Node:GetId() then
		self.IncreaseId = self.IncreaseId + 1
		Node:__SetId(self.IncreaseId)
	else
		self:PopById(Node:GetId())
	end
	table.insert(self.Array, Node)
	local Len = #(self.Array)
	Node:SetIndex(Len)
	self.IndexTbl[Node:GetId()] = Len
	self:__FixUp__(Len)
	return Node:GetIndex(), Node:GetId()
end

function clsHeap:Pop()
	local Len = #(self.Array)
	if Len < 1 then return nil end
	local Ret = self:GetHead()
	self:Swap(1, Len)
	table.remove(self.Array, Len)
	self.IndexTbl[Ret:GetId()] = nil
	if self:GetLen() < 1 then 
		Ret:OnPoped()
		return Ret 
	end
	self:__FixDown__()
	Ret:OnPoped()
	return Ret
end

function clsHeap:PopById(Id)
	local Node = self:GetNode(Id)
	if not Node then return end
	local Idx = Node:GetIndex()
	local Len = self:GetLen()
	self:Swap(Idx, Len)
	table.remove(self.Array, Len)
	self.IndexTbl[Node:GetId()] = nil
	if self:GetLen() < 1 then 
		Node:OnPoped()
		return Node
	end
	self:__FixDown__(Idx)
	Node:OnPoped()
	return Node
end

function clsHeap:Compare(NodeA, NodeB)
	return NodeA:HigherPriority(NodeB)
end

function clsHeap:__FixUp__(Idx) 
	while Idx > 1 do
		local ParentIdx = math.floor(Idx/2)
		if self:Compare(self.Array[Idx], self.Array[ParentIdx]) then
			self:Swap(Idx, ParentIdx)
		end 
		Idx = ParentIdx
	end 
end 

function clsHeap:__FixDown__(Idx)
	Idx = Idx or 1
	local Size = self:GetLen()
	while Idx * 2 <= Size do
		local ChildIdx = Idx * 2 
		if self.Array[ChildIdx+1] and self:Compare(self.Array[ChildIdx+1], self.Array[ChildIdx]) then ChildIdx = ChildIdx + 1 end 
		if self:Compare(self.Array[ChildIdx], self.Array[Idx]) then
			self:Swap(ChildIdx, Idx)
			Idx = ChildIdx
		else
			break
		end 
	end 
end 

function clsHeap:Swap(IndexA, IndexB)
	self.Array[IndexA], self.Array[IndexB] = self.Array[IndexB], self.Array[IndexA]
	self.Array[IndexA]:SetIndex(IndexA)
	self.Array[IndexB]:SetIndex(IndexB)
	self.IndexTbl[self.Array[IndexA]:GetId()] = IndexA
	self.IndexTbl[self.Array[IndexB]:GetId()] = IndexB
end

function clsHeap:GetHead()
	return self.Array[1]
end

function clsHeap:GetTop()
	return self:GetHead()
end

function clsHeap:GetIndex(Id)
	return self.IndexTbl[Id]
end

function clsHeap:IsExist(Id)
	return self:GetIndex(Id)
end

function clsHeap:GetNode(Id)
	local Idx = self:IsExist(Id)
	return Idx and self.Array[Idx]
end

-- 遍历所有Node
function clsHeap:TransNodes(Func)
	assert(IsFunc(Func))
	for idx, Node in pairs(self.Array) do
		Func(Node, idx)
	end
end

function clsHeap:IsAutoId() 
	return self.IncreaseId
end


-- 排名固定大小的堆，比如前10名，允许存在2个第10名，那么堆size为11
-- 优先级越高，越先被pop
clsSizeFixedHeap = clsHeap:new{
	TypeStr = "clsSizeFixedHeap"
}

function clsSizeFixedHeap:init(Size, IsAutoId)
	Super(clsSizeFixedHeap).init(self, IsAutoId)
	self.FixSize = Size
end

function clsSizeFixedHeap:Push(NewNode)
	local Index, Id = nil, nil
	local IsReplace = false
	if NewNode:GetId() then
		local OldNode = self:GetNode(NewNode:GetId())
		if OldNode then
			-- 只Update
			-- 新的优先级更低
			if not NewNode:HigherPriority(OldNode) then
				IsReplace = true
				OldNode.Value = NewNode:GetValue()
				self:__FixDown__(OldNode:GetIndex())
			end
			Index, Id = OldNode:GetIndex(), OldNode:GetId()
		end
	end
	local Size = self:GetLen()

	if not IsReplace and 
		(Size < self.FixSize or Size >= 1 and 
		(self:GetHead():HigherPriority(NewNode) or self:GetHead():EqualPriority(NewNode)) ) then
		Index, Id = Super(clsSizeFixedHeap).Push(self, NewNode)
	end
	Size = self:GetLen()
	if Size > self.FixSize then
		local PopIdList = {}
		local HPCnt = 0
		self:TransNodes( function (Node)
			if Node:EqualPriority(self:GetHead()) then
				table.insert(PopIdList, Node:GetId())
				HPCnt = HPCnt + 1
			end
		end)
		if Size - self.FixSize >= HPCnt then
			for _, Id in pairs(PopIdList) do
				self:PopById(Id)
			end
		end
	end
	return Index, Id
end

function Test()
	local TestArray = {
		[1] = 54,
		[2] = 78,
	}
	local queue = clsHeap:New()
	local SizeFixedQuque = clsSizeFixedHeap:New(2)
	for id, value in pairs(TestArray) do
		local Node = clsHeapNode:New(value, id)
		SizeFixedQuque:Push(Node)
		-- 可以自己重载Node的OnPoped函数。
	end

	local Node2 = clsHeapNode:New(76, 7)
	SizeFixedQuque:Push(Node2)

	local Node3 = clsHeapNode:New(76, 8)
	SizeFixedQuque:Push(Node3)

	while SizeFixedQuque:GetLen() > 0 do
		local Node = SizeFixedQuque:Pop()
		print("SizeFixedQuque", Node:GetId(), Node:GetValue())
	end
end
