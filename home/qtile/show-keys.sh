#!/usr/bin/env bash

rofi -dmenu -i -p " Keys" -theme-str '
listview { lines: 20; fixed-height: false; }
window { width: 620px; }
element-icon { enabled: false; }
' <<'EOF'
Super + Return         Terminal (Alacritty)
Super + D              App Launcher (Rofi)
Super + B              Firefox
Super + Q              Kill Window
Super + F              Fullscreen
Super + Space          Toggle Floating
Super + Tab            Next Layout
Super + J              Focus Down
Super + K              Focus Up
Super + H              Shrink Main
Super + L              Grow Main
Super + Shift + J      Move Window Down
Super + Shift + K      Keybindings (this)
Super + Shift + Up     Move Window Up
Super + 1-6            Switch Workspace
Super + Shift + 1-6    Move to Workspace
Super + Shift + R      Restart Qtile
Super + Shift + Q      Logout
Print                  Screenshot (Flameshot)
EOF
