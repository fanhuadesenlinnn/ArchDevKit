-- 杂项模块：XWayland 缩放和 Hyprland 默认壁纸/Logo 显示行为。
hl.config({
	xwayland = {
		force_zero_scaling = true,
	},

	misc = {
		force_default_wallpaper = -1,
		disable_hyprland_logo = true,
		disable_splash_rendering = false,
	},
})
