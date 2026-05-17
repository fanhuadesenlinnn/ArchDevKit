{
  "layer": "top",
  "position": "top",
  "height": 34,
  "modules-left": ["hyprland/workspaces", "hyprland/window"],
  "modules-center": ["clock"],
  "modules-right": ["network", "pulseaudio", "cpu", "memory", "tray"],
  "hyprland/workspaces": { "format": "{id}", "on-click": "activate" },
  "clock": { "format": "{:%Y-%m-%d %H:%M}" },
  "network": { "format-wifi": "  {essid}", "format-ethernet": "󰈀 有线", "format-disconnected": "󰖪 断开" },
  "pulseaudio": { "format": "  {volume}%", "format-muted": "󰖁 静音", "on-click": "pavucontrol" },
  "cpu": { "format": "CPU {usage}%" },
  "memory": { "format": "MEM {}%" },
  "tray": { "spacing": 10 }
}
