m = Map("autoupdate", translate("Auto Update Settings"), 
    translate("Configure automatic firmware updates for your OpenWrt device"))

s = m:section(NamedSection, "login", "login", translate("Update Settings"))
s.addremove = false
s.anonymous = true

enable = s:option(Flag, "enable", translate("Enable Auto Update"))
enable.rmempty = false

week = s:option(ListValue, "week", translate("Update Day"))
week:value(7, translate("Every Day"))
week:value(1, translate("Monday"))
week:value(2, translate("Tuesday"))
week:value(3, translate("Wednesday"))
week:value(4, translate("Thursday"))
week:value(5, translate("Friday"))
week:value(6, translate("Saturday"))
week.default = 7

hour = s:option(Value, "hour", translate("Update Hour (0-23)"))
hour.datatype = "range(0,23)"
hour.default = "3"

minute = s:option(Value, "minute", translate("Update Minute (0-59)"))
minute.datatype = "range(0,59)"
minute.default = "30"

github = s:option(Value, "github", translate("GitHub Repository URL"))
github.description = translate("Example: https://github.com/Hyy2001X/AutoBuild-Actions")

local apply = luci.http.formvalue("cbi.apply")
if apply then
    io.popen("/etc/init.d/autoupdate restart")
end

return m
