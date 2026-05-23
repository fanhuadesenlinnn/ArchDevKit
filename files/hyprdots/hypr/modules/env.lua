-- 环境变量模块：主要配置光标大小和 fcitx 中文输入法。
hl.env("XCURSOR_SIZE", "8")
hl.env("HYPRCURSOR_SIZE", "8")
hl.env("GTK_IM_MODULE", "fcitx")
hl.env("QT_IM_MODULE", "fcitx")
hl.env("XMODIFIERS", "@im=fcitx")
hl.env("SDL_IM_MODULE", "fcitx")
hl.env("INPUT_METHOD", "fcitx")
