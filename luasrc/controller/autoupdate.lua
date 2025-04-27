module("luci.controller.autoupdate", package.seeall)

function index()
    entry({"admin", "system", "autoupdate"}, 
        cbi("autoupdate"),
        _("AutoUpdate"), 60).dependent = false
	
    entry({"admin", "system", "autoupdate", "do_upgrade"}, 
        call("action_upgrade"), 
        nil).leaf = true
end

function action_upgrade()
    luci.http.redirect(luci.dispatcher.build_url("admin/system/autoupdate"))
end
