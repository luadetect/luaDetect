
local typeprog = nil

function splittype(url)
	local match = string.match(url, '^([^/:]+):')
	if match == nil then
		return nil, url
	end
	return string.lower(string.sub(url, 1, string.len(match) + 1)), string.sub(url, string.len(match)+2)
end

function splithost(url)
	local match_a, match_b = string.match(url, '^//([^/?]*)(.*)$')
	if match_a == nil then
		return nil, url
	end
	if match_b == nil then
		return match_a, match_b
	end
	local start_idx = string.find(match_b, '/')
	if start_idx ~= 1 then
		match_b = '/'..match_b
	end
	return match_a, match_b
end

function splitport(host)
	local new_host, port = string.match(host, '^(.*):([0-9]*)$')
	if new_host == nil then
		return host, nil
	end
	if port then
		return new_host, port
	end
	return host, port
end
