
array = array or {}

function array.index(arr, value)
	for idx, val in ipairs(arr)do
		if val == value then
			return idx
		end
	end
end
function array.merge( a, b )
	assert( type(a) == type(b) and type(b) == "table")
	for k,v in ipairs(b) do
		table.insert(a, v)
	end
	return a
end

function array.join(...)
	local t = {}
	for _, tmpT in pairs({...}) do
		for k, v in ipairs(tmpT) do
			table.insert(t, v)
		end
	end
	return t
end

function array.random_pick(ar)
	if #ar == 0 then
		return nil
	end
	return ar[math.random(1, #ar)]
end

function array.copy(arr)
	if not arr then return nil end
	local ret = {}
	for k,v in ipairs(arr) do
		table.insert(ret, v)
	end
	return ret
end

--从Array中随机乱序抽取n个index
function array.random_index(Array, n)
	n = n or 1
	return table.keys(math.random_pick_nums(#Array, n))
end

function array.random_values(Values, n)
	n = n or 1
	if n == 1 then
		return Values[math.random(1, #Values)]
	end
	local ret = {}
	local randIdxTbl = array.random_index(Values, n)
	for _, idx in pairs(randIdxTbl) do
		table.insert(ret, Values[idx])
	end
	return ret
end

function array.inplace_random_pick(Array, n)
	local Ret = {}
	local e = #Array
	for i=1, n do
		local Rand = math.random(1, e)
		local RandValue = Array[Rand]
		table.insert(Ret, RandValue)
		Array[Rand] = Array[e]
		e = e - 1
	end
	return Ret
end

--shuffle
function array.shuffle(arr)
	if not arr or not next(arr)then
		return false
	end
	require "ext.exttable"
	local number = #arr
	if number == 1 or number == 0 then return false end
	local realnum = number
	for i = 1, number do
		local idx = math.random(realnum)
		table.swap(arr, idx, realnum)
		realnum = realnum - 1
	end
	return true
end
