-- Copyright (C) 2018 jerrykuku <jerrykuku@qq.com>
-- Licensed to the public under the GNU General Public License v3.
module("luci.controller.firefly", package.seeall)

function index()
    if not nixio.fs.access("/etc/config/firefly") then
      return
end

    if nixio.fs.access("/usr/bin/ssr-redir") then
                  entry({"admin", "vpn", "firefly"},alias("admin", "vpn", "firefly", "client"), _("Firefly"), 10).dependent=true
                  entry({"admin", "vpn", "firefly", "client"}, cbi("firefly/client"), _("SSR Client"), 10).leaf=true
                  entry({"admin", "vpn", "firefly", "servers"}, cbi("firefly/servers"),  _("Node List"), 20).leaf=true
                  entry({"admin", "vpn", "firefly", "servers"}, arcombine(cbi("firefly/servers"), cbi("firefly/client-config")),  _("Node List"), 20).leaf =true
                  entry({"admin", "vpn", "firefly", "subscription"},cbi("firefly/subscription"),_("Subscription"),30).leaf=true
                  entry({"admin", "vpn", "firefly", "control"}, cbi("firefly/control"), _("Access Control"), 40).leaf=true
                  entry({"admin", "vpn", "firefly", "servers-list"}, arcombine(cbi("firefly/servers-list"), cbi("firefly/client-config")),  _("Severs Nodes"), 50).leaf =true
                  entry({"admin", "vpn", "firefly", "appointlist"},form("firefly/appointlist"),_("Appointlist List"),60).leaf =true
                  entry({"admin", "vpn", "firefly", "udp2raw"},cbi("firefly/udp2raw"),_("udp2raw tunnel"),70).leaf = true
                  entry({"admin", "vpn", "firefly", "advanced"}, cbi("firefly/advanced"),_("Advanced Settings"), 80).leaf =true
                  elseif nixio.fs.access("/usr/bin/ssr-server") then
                  entry({"admin", "vpn", "firefly"}, alias("admin", "vpn", "firefly", "server"), _("firefly"), 10).dependent =true
                  else
                        return
                  end
                  if nixio.fs.access("/usr/bin/ssr-server") then
                  entry({"admin", "vpn", "firefly", "server"},arcombine(cbi("firefly/server"), cbi("firefly/server-config")),  _("SSR Server"), 85).leaf = true
                  end
                  entry({"admin", "vpn", "firefly", "status"},form("firefly/status"),_("Status"), 90).leaf = true
                  entry({"admin", "vpn", "firefly", "logview"}, cbi("firefly/logview", {hideapplybtn=true, hidesavebtn=true, hideresetbtn=true}), _("Log") ,100).leaf=true
                  entry({"admin", "vpn", "firefly", "refresh"}, call("refresh_data"))
                  entry({"admin", "vpn", "firefly", "checkport"}, call("check_port"))
                  entry({"admin", "vpn", "firefly", "checkports"}, call("check_ports"))
                  entry({"admin", "vpn", "firefly", "ping"}, call("act_ping")).leaf=true
                  entry({"admin", "vpn", "firefly", "fileread"}, call("act_read"), nil).leaf=true
                  entry({"admin", "vpn", "firefly", "switch"}, call("switch"))
                  entry({"admin", "vpn", "firefly", "run"}, call("act_status"))
                  entry({"admin", "vpn", "firefly", "change"}, call("change_node"))
                  entry({"admin", "vpn", "firefly", "allserver"}, call("get_servers"))
                  entry({"admin", "vpn", "firefly", "subscribe"}, call("get_subscribe"))
                  entry({"admin", "vpn", "firefly", "flag"}, call("get_flag"))
                  entry({"admin", "vpn", "firefly", "ip"}, call("check_ip"))

    end

-- 执行订阅
function get_subscribe()
                 local cjson = require "cjson"
                 local e = {}
                 local uci = luci.model.uci.cursor()
                 local auto_update = luci.http.formvalue("auto_update")
                 local auto_update_time = luci.http.formvalue("auto_update_time")
                 local proxy = luci.http.formvalue("proxy")
                 local subscribe_url = luci.http.formvalue("subscribe_url")
                 if subscribe_url ~= "[]" then
                 local cmd1 = 'uci set firefly.@server_subscribe[0].auto_update="' ..
                         auto_update .. '"'
                 local cmd2 = 'uci set firefly.@server_subscribe[0].auto_update_time="' ..
                         auto_update_time .. '"'
                 local cmd3 = 'uci set firefly.@server_subscribe[0].proxy="' .. proxy .. '"'
                 luci.sys.call('uci delete firefly.@server_subscribe[0].subscribe_url ')
                 luci.sys.call(cmd1)
                 luci.sys.call(cmd2)
                 luci.sys.call(cmd3)
                 for k, v in ipairs(cjson.decode(subscribe_url)) do
                 luci.sys.call(
                 'uci add_list firefly.@server_subscribe[0].subscribe_url="' .. v ..  '"')
    end
                 luci.sys.call('uci commit firefly')
                 luci.sys.call(
            "nohup /usr/bin/lua /usr/share/firefly/subscribe.lua >/www/check_update.htm 2>/dev/null &")

                 e.error = 0
                 else
                 e.error = 1
    end

                 luci.http.prepare_content("application/json")
                 luci.http.write_json(e)

  end

-- 获取所有节点
function get_servers()
                local uci = luci.model.uci.cursor()
                local server_table = {}
                uci:foreach("firefly", "servers", function(s)
                local e = {}
                e["name"] = s[".name"]
                local t1 = luci.sys.exec(
                       "ping -c 1 -W 1 %q 2>&1 | grep -o 'time=[0-9]*.[0-9]' | awk -F '=' '{print$2}'" %
                           s["server"])
                e["t1"] = t1
                table.insert(server_table, e)
    end)
                luci.http.prepare_content("application/json")
                luci.http.write_json(server_table)
end

-- 切换节点
function change_node()
                local e = {}
                local uci = luci.model.uci.cursor()
                local sid = luci.http.formvalue("set")
                local name = ""
                uci:foreach("firefly", "global", function(s) name = s[".name"] end)
                e.status = false
                e.sid = sid
                if sid ~= "" then
                uci:set("firefly", name, "global_server", sid)
                uci:commit("firefly")
                luci.sys.call("/etc/init.d/firefly restart")
                e.status = true
    end
                luci.http.prepare_content("application/json")
                luci.http.write_json(e)
end

function switch()
               local e = {}
               local uci = luci.model.uci.cursor()
               local sid = luci.http.formvalue("node")
               local isSwitch = uci:get("firefly", sid, "switch_enable")
               if isSwitch == "1" then
               uci:set("firefly", sid, "switch_enable","0")
               e.switch = false
               else
               uci:set("firefly", sid, "switch_enable","1")
               e.switch = true
  end
               uci:commit("firefly")
               e.status = true
               luci.http.prepare_content("application/json")
               luci.http.write_json(e)
  end


-- 检测全局服务器状态
function act_status()
              math.randomseed(os.time())
              local e = {}
-- 全局服务器
                   e.global=luci.sys.call("ps -w | grep ssr-retcp | grep -v grep >/dev/null") == 0
-- 检测Socks5

	           if tonumber(luci.sys.exec("ps -w | grep ssr-local |grep -v grep| wc -l"))>0 then
	                e.socks5 = true
                   elseif tonumber(luci.sys.exec("ps -w | grep ss-local |grep -v grep| wc -l"))>0 then
		        e.socks5 = true
	           elseif tonumber(luci.sys.exec("ps -w | grep v2-ssr-local |grep -v grep| wc -l"))>0 then
  end
--检测chinadns状态
	          if tonumber(luci.sys.exec("ps -w | grep chinadns |grep -v grep| wc -l"))>0 then
		        e.chinadns= true
	          elseif tonumber(luci.sys.exec("ps -w | grep dnsparsing |grep -v grep| wc -l"))>0 then
	 	        e.chinadns= true
	          elseif tonumber(luci.sys.exec("ps -w | grep dnscrypt-proxy |grep -v grep| wc -l"))>0 then
		        e.chinadns= true
                  elseif tonumber(luci.sys.exec("ps -w | grep pdnsd |grep -v grep| wc -l"))>0 then
		        e.chinadns= true
	          elseif tonumber(luci.sys.exec("ps -w | grep dns2socks |grep -v grep| wc -l"))>0 then
		        e.chinadns= true
                  elseif tonumber(luci.sys.exec("ps -w | grep dnsforwarder |grep -v grep| wc -l"))>0 then
	        	e.chinadns= true
end
--检测服务端状态
	         if tonumber(luci.sys.exec("ps -w | grep ssr-server |grep -v grep| wc -l"))>0 then
	                e.server= true
end
                 if luci.sys.call("pidof ssr-server >/dev/null") == 0 then
                        e.ssr_server= true
end
 	         if luci.sys.call("pidof ss-server >/dev/null") == 0 then
		        e.ss_server= true
end
	         if luci.sys.call("ps -w | grep v2ray-server | grep -v grep >/dev/null") == 0 then
		        e.v2_server= true

end

   -- 检测国内通道
          e.baidu = false
          sret = luci.sys.call("/usr/bin/ssr-check www.baidu.com 80 3 1")
          if sret == 0 then
          e.baidu =  true
end

    -- 检测国外通道
         e.google = false
         sret = luci.sys.call("/usr/bin/ssr-check www.google.com 80 3 1")
         if sret == 0 then
         e.google =  true
end


-- 检测游戏模式状态
       e.game = false
    if tonumber(luci.sys.exec("ps -w | grep ssr-reudp |grep -v grep| wc -l"))>0 then
      e.game= true
    else
        if tonumber(luci.sys.exec("ps -w | grep ssr-retcp |grep \"\\-u\"|grep -v grep| wc -l"))>0 then
            e.game= true
        end
    end
    luci.http.prepare_content("application/json")
    luci.http.write_json(e)
end
function act_ping()
	local e = {}
	local domain = luci.http.formvalue("domain")
	local port = luci.http.formvalue("port")
	e.index = luci.http.formvalue("index")
	local iret = luci.sys.call(" ipset add ss_spec_wan_ac " .. domain .. " 2>/dev/null")
	local socket = nixio.socket("inet", "stream")
	socket:setopt("socket", "rcvtimeo", 3)
	socket:setopt("socket", "sndtimeo", 3)
	e.socket = socket:connect(domain, port)
	socket:close()
	e.ping = luci.sys.exec("ping -c 1 -W 1 %q 2>&1 | grep -o 'time=[0-9]*.[0-9]' | awk -F '=' '{print$2}'" % domain)
	if (e.ping == "") then
		e.ping = luci.sys.exec(string.format("echo -n $(tcpping -c 1 -i 1 -p %s %s 2>&1 | grep -o 'ttl=[0-9]* time=[0-9]*.[0-9]' | awk -F '=' '{print$3}') 2>/dev/null",port, domain))
  end
	if (iret == 0) then
		luci.sys.call(" ipset del ss_spec_wan_ac " .. domain)
	end
	luci.http.prepare_content("application/json")
	luci.http.write_json(e)
end
function check_status()
	local set ="/usr/bin/ssr-check www." .. luci.http.formvalue("set") .. ".com 80 3 1"
	sret=luci.sys.call(set)
	if sret== 0 then
		retstring ="0"
	else
		retstring ="1"
	end

	luci.http.prepare_content("application/json")
	luci.http.write_json({ ret=retstring })
end

-- 刷新检测文件
function refresh_data()
local set =luci.http.formvalue("set")
local icount =0

if set == "gfw_data" then
	refresh_cmd="wget-ssl --no-check-certificate https://cdn.jsdelivr.net/gh/gfwlist/gfwlist/gfwlist.txt -O /tmp/gfw.b64"
	sret=luci.sys.call(refresh_cmd .. " 2>/dev/null")
	if sret== 0 then
	luci.sys.call("/usr/bin/firefly-gfw")
	icount = luci.sys.exec("cat /tmp/gfwnew.txt | wc -l")
	if tonumber(icount)>1000 then
	oldcount=luci.sys.exec("cat /etc/dnsmasq.firefly/gfw_list.conf | wc -l")
	if tonumber(icount) ~= tonumber(oldcount) then
		luci.sys.exec("cp -f /tmp/gfwnew.txt /etc/dnsmasq.firefly/gfw_list.conf")
		luci.sys.exec("cp -f /tmp/gfwnew.txt /tmp/dnsmasq.firefly/gfw_list.conf")
		luci.sys.call("/etc/init.d/dnsmasq restart")
		retstring=tostring(math.ceil(tonumber(icount)/2))
	else
		retstring ="0"
	end
	else
	retstring ="-1"
	end
	luci.sys.exec("rm -f /tmp/gfwnew.txt ")
else
	retstring ="-1"
end
elseif set == "ip_data" then
	if (luci.model.uci.cursor():get_first('firefly', 'global', 'chnroute', '0') == '1') then
		refresh_cmd="wget-ssl --no-check-certificate -O - " .. luci.model.uci.cursor():get_first('firefly', 'global', 'chnroute_url', 'https://ispip.clang.cn/all_cn.txt') .. ' > /tmp/china_cdn.txt 2>/dev/null'
	else
		refresh_cmd="wget -O- 'http://ftp.apnic.net/apnic/stats/apnic/delegated-apnic-latest'  2>/dev/null| awk -F\\| '/CN\\|ipv4/ { printf(\"%s/%d\\n\", $4, 32-log($5)/log(2)) }' > /tmp/china_cdn.txt"
	end
	sret=luci.sys.call(refresh_cmd)
	icount = luci.sys.exec("cat /tmp/china_cdn.txt | wc -l")
	if sret== 0 and tonumber(icount)>1000 then
		oldcount=luci.sys.exec("cat /etc/china_cdn.txt | wc -l")
		if tonumber(icount) ~= tonumber(oldcount) then
			luci.sys.exec("cp -f /tmp/china_cdn.txt /etc/china_cdn.txt")
			retstring=tostring(tonumber(icount))
		else
			retstring ="0"
		end
	else
		retstring ="-1"
	end
	luci.sys.exec("rm -f /tmp/china_cdn.txt ")
else
if nixio.fs.access("/usr/bin/wget-ssl") then
	refresh_cmd="wget-ssl --no-check-certificate -O - ".. luci.model.uci.cursor():get_first('firefly', 'global', 'adblock_url','https://easylist-downloads.adblockplus.org/easylistchina+easylist.txt') .." > /tmp/adnew.conf"
end
sret=luci.sys.call(refresh_cmd .. " 2>/dev/null")
if sret== 0 then
	luci.sys.call("/usr/bin/firefly-ad")
	icount = luci.sys.exec("cat /tmp/ad.conf | wc -l")
	if tonumber(icount)>1000 then
	if nixio.fs.access("/etc/dnsmasq.firefly/ad.conf") then
		oldcount=luci.sys.exec("cat /etc/dnsmasq.firefly/ad.conf | wc -l")
	else
		oldcount=0
	end
	if tonumber(icount) ~= tonumber(oldcount) then
		luci.sys.exec("cp -f /tmp/ad.conf /etc/dnsmasq.firefly/ad.conf")
		luci.sys.exec("cp -f /tmp/ad.conf /tmp/dnsmasq.firefly/ad.conf")
		luci.sys.call("/etc/init.d/dnsmasq restart")
		retstring=tostring(math.ceil(tonumber(icount)))
	else
		retstring ="0"
	end
	else
	retstring ="-1"
	end
	luci.sys.exec("rm -f /tmp/ad.conf")
else
	retstring ="-1"
end
end
luci.http.prepare_content("application/json")
luci.http.write_json({ ret=retstring ,retcount=icount})
end

-- 检测所有服务器
function check_ports()
    local set = ""
    local retstring = "<br /><br />"
    local s
    local server_name = ""
    local firefly = "firefly"
    local uci = luci.model.uci.cursor()
    local iret = 1

    uci:foreach(
        firefly,
        "servers",
        function(s)
            if s.alias then
                server_name = s.alias
            elseif s.server and s.server_port then
                server_name = "%s:%s" % {s.server, s.server_port}
            end
            iret = luci.sys.call(" ipset add ss_spec_wan_ac " .. s.server .. " 2>/dev/null")
            socket = nixio.socket("inet", "stream")
            socket:setopt("socket", "rcvtimeo", 3)
            socket:setopt("socket", "sndtimeo", 3)
            ret = socket:connect(s.server, s.server_port)
            if tostring(ret) == "true" then
                socket:close()
                retstring = retstring .. "<font color='green'>[" .. server_name .. "] OK.</font><br />"
            else
                retstring = retstring .. "<font color='red'>[" .. server_name .. "] Error.</font><br />"
            end
            if iret == 0 then
                luci.sys.call(" ipset del ss_spec_wan_ac " .. s.server)
            end
        end
    )

    luci.http.prepare_content("application/json")
    luci.http.write_json({ret = retstring})
end

-- 检测单个节点状态并返回连接速度
function check_port()

    local e = {}
    -- e.index=luci.http.formvalue("host")
    local t1 = luci.sys.exec(
                   "ping -c 1 -W 1 %q 2>&1 | grep -o 'time=[0-9]*.[0-9]' | awk -F '=' '{print$2}'" %
                       luci.http.formvalue("host"))
    luci.http.prepare_content("application/json")
    luci.http.write_json({ret = 1, used = t1})

end

function JudgeIPString(ipStr)
    if type(ipStr) ~= "string" then return false end

    -- 判断长度
    local len = string.len(ipStr)
    if len < 7 or len > 15 then -- 长度不对
        return false
    end

    -- 判断出现的非数字字符
    local point = string.find(ipStr, "%p", 1) -- 字符"."出现的位置
    local pointNum = 0 -- 字符"."出现的次数 正常ip有3个"."
    while point ~= nil do
        if string.sub(ipStr, point, point) ~= "." then -- 得到非数字符号不是字符"."
            return false
        end
        pointNum = pointNum + 1
        point = string.find(ipStr, "%p", point + 1)
        if pointNum > 3 then return false end
    end
    if pointNum ~= 3 then -- 不是正确的ip格式
        return false
    end

    -- 判断数字对不对
    local num = {}
    for w in string.gmatch(ipStr, "%d+") do
        num[#num + 1] = w
        local kk = tonumber(w)
        if kk == nil or kk > 255 then -- 不是数字或超过ip正常取值范围了
            return false
        end
    end

    if #num ~= 4 then -- 不是4段数字
        return false
    end

    return ipStr
end

-- 检测 当前节点ip 和 网站访问情况
function check_ip()
-- 获取当前的ip和国家
    local e = {}
    local d = {}
    local mm = require 'maxminddb'
    local db = mm.open('/usr/share/firefly/GeoLite2-Country.mmdb')
    local ip = string.gsub(luci.sys.exec("curl -s https://api.ip.sb/ip"), "\n", "")
    local res = db:lookup(ip)
    d.flag = string.lower(res:get("country", "iso_code"))
    d.country = res:get("country", "names", "zh-CN")
    e.outboard = ip
    e.outboardip = d

    -- 检测国内通道
    e.baidu = false
    sret1 = luci.sys.call("/usr/bin/ssr-check www.baidu.com 80 3 1")
    if sret1 == 0 then e.baidu = true end

    e.taobao = false
    sret2 = luci.sys.call("/usr/bin/ssr-check www.taobao.com 80 3 1")
    if sret2 == 0 then e.taobao = true end

    -- 检测国外通道
    e.google = false
    sret3 = luci.sys.call("/usr/bin/ssr-check www.google.com 80 3 1")
    if sret3 == 0 then e.google = true end

    e.youtube = false
    sret4 = luci.sys.call("/usr/bin/ssr-check www.youtube.com 80 3 1")
    if sret4 == 0 then e.youtube = true end

    luci.http.prepare_content("application/json")
    luci.http.write_json(e)
end

-- 获取节点国旗 iso code
function get_flag()
    local e = {}
    local host = luci.http.formvalue("host")
    local remark = luci.http.formvalue("remark")
    local cmd = '/usr/share/firefly/getflag.sh "' .. remark .. '" ' .. host
    e.host = host
    e.flag = luci.sys.exec(cmd)
    luci.http.prepare_content("application/json")
    luci.http.write_json(e)
end

function act_read(lfile)
	local NXFS = require "nixio.fs"
	local HTTP = require "luci.http"
	local lfile = HTTP.formvalue("lfile")
	local ldata={}
	ldata[#ldata+1] = NXFS.readfile(lfile) or "_nofile_"
	if ldata[1] == "" then
		ldata[1] = "_nodata_"
	end
	HTTP.prepare_content("application/json")
	HTTP.write_json(ldata)
end
