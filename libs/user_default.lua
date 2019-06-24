module(..., package.seeall)


local UserNum = ""

function SetUserNum(num)
	UserNum = num
end


function setIntegerForKey(key, value)
	cc.UserDefault:getInstance():setIntegerForKey(key, value)
	cc.UserDefault:getInstance():flush()
end

function getIntegerForKey(key, default_value)
	return cc.UserDefault:getInstance():getIntegerForKey(key, default_value)
end

function setFloatForKey(key, value)
	cc.UserDefault:getInstance():setFloatForKey(key, value)
	cc.UserDefault:getInstance():flush()
end

function getFloatForKey(key, default_value)
	return cc.UserDefault:getInstance():getFloatForKey(key, default_value)
end

function setBoolForKey(key, value)
	cc.UserDefault:getInstance():setBoolForKey(key, value)
	cc.UserDefault:getInstance():flush()
end

function getBoolForKey(key, default_value)
	return cc.UserDefault:getInstance():getBoolForKey(key, default_value)
end

function setDoubleForKey(key, value)
	cc.UserDefault:getInstance():setDoubleForKey(key, value)
	cc.UserDefault:getInstance():flush()
end

function getDoubleForKey(key, default_value)
	return cc.UserDefault:getInstance():getDoubleForKey(key, default_value)
end

function setStringForKey(key, value)
	cc.UserDefault:getInstance():setStringForKey(key, value)
	cc.UserDefault:getInstance():flush()
end

function getStringForKey(key, default_value)
	return cc.UserDefault:getInstance():getStringForKey(key, default_value)
end




function keyWithUserNum(key)
	return string.format("%s_%s", UserNum, key)
end


function setUserIntegerForKey(key, value)
	cc.UserDefault:getInstance():setIntegerForKey(keyWithUserNum(key), value)
	cc.UserDefault:getInstance():flush()
end

function getUserIntegerForKey(key, default_value)
	cc.UserDefault:getInstance():getIntegerForKey(keyWithUserNum(key), default_value)
end

function setUserStringForKey(key, value)
	cc.UserDefault:getInstance():setStringForKey(keyWithUserNum(key), value)
	cc.UserDefault:getInstance():flush()
end

function getUserStringForKey(key, default_value)
	cc.UserDefault:getInstance():getStringForKey(keyWithUserNum(key), default_value)
end

