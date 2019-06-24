

local DCTOOL_ENABLE_LOGGER = true

function open_log(log)
	DCTOOL_ENABLE_LOGGER = log
end

function log(...)
	if DCTOOL_ENABLE_LOGGER then
		local _str = ""
		for key, value in ipairs(arg) do
			_str = _str..value
		end
		print("DETECT {0}".format(_str))
		if DCTOOL_ENABLE_ENGINE_LOGGER:
			
end