# ~/.zprofile — seamless login
# On tty1, after autologin, hand off to a uwsm-managed Hyprland session.
# Guarded to VT 1 so Ctrl+Alt+F2..F6 stay as plain recovery shells.
if [ "$XDG_VTNR" = 1 ] && uwsm check may-start; then
    exec uwsm start -e -D Hyprland hyprland.desktop
fi
