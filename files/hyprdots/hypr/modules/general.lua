-- 通用外观模块：窗口间距、边框、布局和 dwindle/master 行为。
hl.config({
	general = {
		gaps_in = 3,
		gaps_out = 6,
		border_size = 0,
		col = {
			active_border = {
				colors = {
					"rgb(f5c2e7)",
					"rgb(000000)",
				},
				angle = 45,
			},
			inactive_border = {
				colors = {
					"rgb(242731)",
				},
			},
		},
		resize_on_border = true,
		extend_border_grab_area = 30,
		hover_icon_on_border = true,
		resize_corner = 5,
		allow_tearing = false,
		-- ArchDevKit defaults to stock Hyprland layouts; upstream hyprdots used
		-- the optional scrolling layout.
		layout = "dwindle",
	},
	-- scrolling = {
	-- 	fullscreen_on_one_column = true,
	-- 	focus_fit_method = 1,
	-- 	column_width = 0.6,
	-- 	follow_focus = 1,
	-- 	direction = "left",
	-- 	-- explicit_column_widths = { 0.3, 0.5, 0.65, 0.8, 0.985, 1.0 },
	-- },
	dwindle = {
		-- pseudotile = true
		preserve_split = true,
	},
	master = {
		new_status = inherit,
		new_on_top = true,
		new_on_active = "true",
		smart_resizing = true,
	},
})
