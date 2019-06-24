--基础的数据结构

require("libs.heap")

--双向队列
MAX_ITEM_CNT = 50	--这么item应该够了吧？不够会assert
clsQueue = CObject:new{
	TypeStr = "clsQueue"
}
function clsQueue:init()
	self._queue = {}
	self._headIdx = 0
	self._tailIdx = 1
end
function clsQueue:pushHead(data)
	local headIdx = self._headIdx
	local newHeadIdx = (headIdx - 1) % MAX_ITEM_CNT
	assert(newHeadIdx ~= self._tailIdx)
	self._queue[headIdx] = data
	self._headIdx = newHeadIdx
end
function clsQueue:pushTail(data)
	local tailIdx = self._tailIdx
	local newTailIdx = (tailIdx + 1) % MAX_ITEM_CNT
	assert(self._headIdx ~= newTailIdx)
	self._queue[tailIdx] = data
	self._tailIdx = newTailIdx
end
function clsQueue:popHead()
	local headIdx = self._headIdx
	local tailIdx = self._tailIdx
	local newHeadIdx = (headIdx + 1) % MAX_ITEM_CNT
	if newHeadIdx == tailIdx then
		return
	end
	self._headIdx = newHeadIdx
	local ret = self._queue[newHeadIdx]
	self._queue[newHeadIdx] = nil
	return ret
end
function clsQueue:popTail()
	local headIdx = self._headIdx
	local tailIdx = self._tailIdx
	local newTailIdx = (tailIdx - 1) % MAX_ITEM_CNT
	if headIdx == newTailIdx then
		return
	end
	self._tailIdx = newTailIdx
	local ret = self._queue[newTailIdx]
	self._queue[newTailIdx] = nil
	return ret
end
function clsQueue:getHead()
	local headIdx = self._headIdx
	local tailIdx = self._tailIdx
	local headItemIdx = (headIdx + 1) % MAX_ITEM_CNT
	if headItemIdx ~= tailIdx then
		return self._queue[headItemIdx]
	end
end
function clsQueue:getTail()
	local headIdx = self._headIdx
	local tailIdx = self._tailIdx
	local tailItemIdx = (tailIdx - 1) % MAX_ITEM_CNT
	if headIdx ~= tailItemIdx then
		return self._queue[tailItemIdx]
	end
end
function clsQueue:traverse(func)
	local headIdx = self._headIdx
	local tailIdx = self._tailIdx
	while true do
		headIdx = (headIdx + 1) % MAX_ITEM_CNT
		if headIdx == tailIdx then
			return
		end
		local content = self._queue[headIdx]
		func(content)
	end
end
function clsQueue:clear()
	while true do
		if not self:popTail() then
			break
		end
	end
end
function clsQueue:getCnt()
	if self._tailIdx > self._headIdx then
		return self._tailIdx - self._headIdx - 1
	else
		return MAX_ITEM_CNT - self._headIdx + self._tailIdx
	end
end

function test()
	local queue = clsQueue:create()
	queue:pushTail(1) --{1}
	assert(queue:getHead() == 1)
	assert(queue:getTail() == 1)
	queue:pushTail(2) --{1,2}
	assert(queue:getHead() == 1)
	assert(queue:getTail() == 2)
	queue:pushHead(0) --{0,1,2}
	assert(queue:getHead() == 0, 'head:' .. queue:getHead())
	assert(queue:getTail() == 2)
	assert(queue:popHead() == 0) --{1,2}
	assert(queue:popTail() == 2) --{1}
	assert(queue:popTail() == 1) --{}
	assert(not queue:getHead())
	assert(not queue:getTail())
	local success
	assert(not queue:popTail()) --{1}
	assert(not queue:popHead()) --{1}
	for i = 1, MAX_ITEM_CNT - 2 do
		queue:pushTail(i) --{1, 2, ..., MAX_ITEM_CNT - 2}
	end
	success = xpcall(function() queue:pushHead(MAX_ITEM_CNT - 2) end, function() end)
	assert(not success) --{1}
	success = xpcall(function() queue:pushTail(0) end, function() end)
	assert(not success) --{1}
end
