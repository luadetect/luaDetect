
local global_dict = {}

function set_value(key, vaule)
	if string.len(key) == 0 then
		return
	end
	global_dict[key] = vaule
end

function get_value(key, default_value)
	if string.len(key) == 0 then
		return default_value
	end
	return global_dict[key] or default_value
end
