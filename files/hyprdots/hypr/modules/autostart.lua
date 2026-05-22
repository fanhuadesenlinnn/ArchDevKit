local vars = require("modules.variables")

local function exec_once(cmd)
	hl.exec_cmd(cmd)
end

hl.on("hyprland.start", function()
	exec_once("hyprpaper")
	exec_once("waybar")
	exec_once("wl-paste --type text --watch cliphist store")
	exec_once("wl-paste --type image --watch cliphist store")
	exec_once("fcitx5 -d")
	exec_once("systemctl --user start hyprpolkitagent")
	exec_once("dunst")
	exec_once("[workspace 1] " .. vars.browser)
	exec_once("[workspace 2 silent] " .. vars.terminal)
end)
