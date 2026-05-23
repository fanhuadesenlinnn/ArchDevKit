-- 输入模块：键盘布局、鼠标灵敏度、触控板自然滚动和 XWayland 缩放。
hl.config({
	input = {
		kb_layout = "us",
		kb_variant = "",
		kb_model = "",
		kb_options = "caps:none,caps:super",
		kb_rules = "",
		follow_mouse = 1,
		sensitivity = -0.1,
		force_no_accel = false,

		touchpad = {
			disable_while_typing = true,
			natural_scroll = true,
		},
	},

	xwayland = {
		force_zero_scaling = true,
	},

	misc = {
		force_default_wallpaper = -1,
		disable_hyprland_logo = true,
		disable_splash_rendering = false,
	},
})

hl.device({
	name = "epic-mouse-v1",
	sensitivity = -0.5,
})
