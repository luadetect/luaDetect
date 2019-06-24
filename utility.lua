
require "global_type"

--[[
region == 0，表示大陆
region == 1. 表示海外
region == 2，表示台湾版本
]]

local region = -1

function set_region(reg)
	region = tonumber(reg)
end

local function get_region()
	return tonumber(region)
end

function get_service_scene_it_need()
	--返回需要服务状态的场景:
    --1,4,5,10,11
	return {global_type.Scene.Delay, global_type.Scene.ConnectToServerFailed, global_type.Scene.UnexpextOffline, global_type.Scene.LostPackets, global_type.Scene.CollectionNormal}
end

function get_service_status_normal()
	--返回正常的服务状态，跟场景相关，跟服务端接口相关
	return {'RUNNING', 'UP', 'running', 'up'}
end

function get_service_url()
	--返回当前合适的服务状态检查url
    --2 代表台湾，需要修改netease.com => easebar.com
	local url = ''
	if tonumber(region) == 2 then
		url = 'https://proxy-state.nie.easebar.com/status/'
    else
        url = 'https://proxy-state.nie.netease.com/status/'
    end
	return url
end

function get_dns_url()
    --返回当前合适的DNS解析url
    --2 代表台湾，需要修改netease.com => easebar.com
    if tonumber(region) == 2 then
        url = 'https://dl.nstool.easebar.com/internalquery'
    else
        url = 'https://nstool.netease.com/internalquery'
    end
    return url
end

function get_region_url()
	--返回当前合适的区域查询url
    --2 代表台湾，需要修改netease.com => easebar.com
	local url = ''
	if tonumber(region) == 2 then
		url = 'https://data-detect.nie.easebar.com/client/country_range'
    else
        url = 'https://data-detect.nie.netease.com/client/country_range'
    end
    return url
end

function get_website1()
	--返回合适的外部网站1
    --<1 国内，诊断www.sogou.com
    -->=1 海外（含台湾），诊断www.google.com
    local url = ''
    if tonumber(region) < 1 then
        url = 'https://www.sogou.com'
    else
        url = 'https://www.google.com'
    end
    return url
end

function get_website2()
	--返回合适的外部网站2
    --<1 国内，诊断hao.360.cn
    -- >=1 海外（含台湾），诊断www.facebook.com
    local url = ''
    if tonumber(region) < 1 then
        url = 'https://hao.360.cn'
    else
        url = 'https://www.facebook.com'
    end
    return url
end

function get_website3()
    -- 返回合适的外部网站2
    -- <1 国内，诊断m.baidu.com
    -- >=1 海外（含台湾），诊断www.bing.com
    local url = ''
    if tonumber(region) < 1 then
        url = 'https://m.baidu.com'
    else
        url = 'https://www.bing.com'
    end
    return url
end

function get_website_host1()
    -- 返回合适的外部网站1
    -- <1 国内，诊断www.sogou.com
    -- >=1 海外（含台湾），诊断www.google.com
    local host = ''
    if tonumber(region) < 1 then
        host = 'www.sogou.com'
    else
        host = 'www.google.com'
    end
    return host
end
function get_website_host2()
    -- 返回合适的外部网站2
    -- <1 国内，诊断hao.360.cn
    -- >=1 海外（含台湾），诊断www.facebook.com
    local host = ''
    if tonumber(region) < 1 then
        host = 'hao.360.cn'
    else
        host = 'www.facebook.com'
    end
    return host
end

function get_website_host3()
    -- 返回合适的外部网站2
    -- <1 国内，诊断m.baidu.com
    -- >=1 海外（含台湾），诊断www.bing.com
    local host = ''
    if tonumber(region) < 1 then
        host = 'm.baidu.com'
    else
        host = 'www.bing.com'
    end
    return host
end

function getPaymentURL()
    return 'https://buy.itunes.apple.com'
end

local function get_upload_url()
    -- 返回当前合适的上报数据url
    -- 2 代表台湾，需要修改netease.com => easebar.com
    local url = ''
    if int(region) == 2 then
        url = 'https://data-detect.nie.easebar.com/client/mobile_upload'
    else
        url = 'https://data-detect.nie.netease.com/client/mobile_upload'
    end
    return url
end

