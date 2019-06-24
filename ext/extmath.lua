
module(..., package.seeall)

--返回一个数组的所有排列
--input {1, 2}
--output { {1, 2}, {2, 1} }
function math.permutation(Array)
	local Out = {}
	local function Append(Out, Array)
		local x = {} 
		for i, v in ipairs(Array) do
			table.insert(x, v) 
		end 
		table.insert(Out, x) 
	end
	local function Gen(n)
		if n == 1 then
			Append(Out, Array)
		end 
		for i=1, n do
			Array[i], Array[n] = Array[n], Array[i]
			Gen(n-1)
			Array[i], Array[n] = Array[n], Array[i]
		end 
	end 
	Gen(#Array)
	return Out 
end

-- 返回 [1, n] 的一个随机排列表
function math.rand_perm(n)
	local ret = {}
	for i=1,n do
		table.insert(ret, i)
	end
	for i=1, n do
		local j = math.random(i, n)
		ret[i], ret[j] = ret[j], ret[i]
	end
	return ret
end

function math.limit( value, a, b)
	local min, max = a, b
	if b and a > b then
		min, max = b, a
	end
	if value < min then
		return min
	elseif max and value >  max then
		return max
	else
		return value
	end
end

--从{1,2,...,n}里面无放回地抽取m个元素，robert floyd sampling算法
--返回{[num1] = true, [num2] = true, ...}
function math.random_pick_nums(n, m)
	assert(n > m)
	local s = {}
	for j = n - m + 1, n do
		local t = math.random(1, j)
		if not s[t] then
			s[t] = true
		else
			s[j] = true
		end
	end
	return s
end

--把n个球随机分成m份(1份里面至少有1个球)，返回每份的球的个数
function math.random_split(n, m)
	local RandNums = math.random_pick_nums(n - 1, m - 1)
	local Res = table.keys(RandNums)
	table.insert(Res, n)
	table.sort(Res)
	for i = #Res, 1, -1 do
		Res[i] = Res[i] - (Res[i - 1] or 0)
	end
	return Res
end

--从第一位的索引是1
function math.toBit(num)
	if type(num) ~= "number" then return nil end
	local bit, temp = {}, nil
	for i = 32 , 1, -1 do
		 temp = 2 ^ (i - 1)
		 if num >= temp then
		 	bit[i] = 1
		 	num = num - temp
		 end
	end 
	return bit
end
