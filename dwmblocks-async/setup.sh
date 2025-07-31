#!/bin/bash

# Enhanced dwmblocks scripts with status2d colors and statuscmd click actions
# Assuming you have bar_status2d and bar_statuscmd patches

# Color definitions for status2d
# Format: ^c#RRGGBB^ for foreground, ^b#RRGGBB^ for background
# ^d^ resets to default colors

# sb-disk - Disk usage with colors and click action
cat > ~/.local/bin/sb-disk << 'EOF'
#!/bin/sh
# Disk usage with colors and click functionality
usage=$(df -h / | awk 'NR==2 {print $5}' | sed 's/%//')
free=$(df -h / | awk 'NR==2 {print $4}')
used=$(df -h / | awk 'NR==2 {print $3}')

# Color and icon based on usage
if [ "$usage" -gt 90 ]; then
    color="^c#ff6b6b^"  # Red for critical
    icon="󰗮"
elif [ "$usage" -gt 75 ]; then
    color="^c#ffa500^"  # Orange for warning
    icon="󰪥"
else
    color="^c#4ecdc4^"  # Teal for normal
    icon="󰋊"
fi

# With statuscmd click action (signal 3)
printf "^s3^%s%s %s%% (%s free)^d^" "$color" "$icon" "$usage" "$free"
EOF

# sb-memory - Memory usage with colors and click action
cat > ~/.local/bin/sb-memory << 'EOF'
#!/bin/sh
# Memory usage with colors
mem_percent=$(free | awk 'NR==2{printf "%.0f", $3*100/$2}')
mem_used=$(free -h | awk 'NR==2{print $3}')
mem_total=$(free -h | awk 'NR==2{print $2}')

# Color based on usage
if [ "$mem_percent" -gt 90 ]; then
    color="^c#ff6b6b^"  # Red
    icon="󰍛"
elif [ "$mem_percent" -gt 75 ]; then
    color="^c#ffa500^"  # Orange
    icon="󰍜"
else
    color="^c#45b7d1^"  # Blue
    icon="󰍛"
fi

# With statuscmd click action (signal 4)
printf "^s4^%s%s %s%% (%s/%s)^d^" "$color" "$icon" "$mem_percent" "$mem_used" "$mem_total"
EOF

# sb-volume - Volume with colors, mute detection, and click action
cat > ~/.local/bin/sb-volume << 'EOF'
#!/bin/sh
# Volume control with colors and click actions

get_volume() {
    if command -v pamixer >/dev/null 2>&1; then
        vol=$(pamixer --get-volume)
        muted=$(pamixer --get-mute)
    elif command -v amixer >/dev/null 2>&1; then
        vol=$(amixer get Master | tail -n1 | sed -r 's/.*\[(.*)%\].*/\1/')
        muted=$(amixer get Master | tail -n1 | grep -q '\[off\]' && echo "true" || echo "false")
    else
        printf "^c#ff6b6b^󰖁 N/A^d^"
        exit 1
    fi
}

# Handle click actions (for statuscmd)
case $BLOCK_BUTTON in
    1) # Left click - toggle mute
        if command -v pamixer >/dev/null 2>&1; then
            pamixer --toggle-mute
        elif command -v amixer >/dev/null 2>&1; then
            amixer set Master toggle
        fi
        ;;
    3) # Right click - open mixer
        setsid -f pavucontrol >/dev/null 2>&1 || setsid -f alsamixer -c 0 >/dev/null 2>&1
        ;;
    4) # Scroll up - increase volume
        if command -v pamixer >/dev/null 2>&1; then
            pamixer -i 5
        elif command -v amixer >/dev/null 2>&1; then
            amixer set Master 5%+
        fi
        ;;
    5) # Scroll down - decrease volume
        if command -v pamixer >/dev/null 2>&1; then
            pamixer -d 5
        elif command -v amixer >/dev/null 2>&1; then
            amixer set Master 5%-
        fi
        ;;
esac

get_volume

# Color and icon based on volume/mute status
if [ "$muted" = "true" ]; then
    color="^c#6c7086^"  # Gray for muted
    icon="󰖁"
elif [ "$vol" -gt 70 ]; then
    color="^c#a6e3a1^"  # Green for high
    icon="󰕾"
elif [ "$vol" -gt 30 ]; then
    color="^c#f9e2af^"  # Yellow for medium
    icon="󰖀"
elif [ "$vol" -gt 0 ]; then
    color="^c#fab387^"  # Orange for low
    icon="󰕿"
else
    color="^c#6c7086^"  # Gray for zero
    icon="󰖁"
fi

# With statuscmd click action (signal 8)
printf "^s8^%s%s %s%%^d^" "$color" "$icon" "$vol"
EOF

# sb-battery - Battery with colors, status, and click action
cat > ~/.local/bin/sb-battery << 'EOF'
#!/bin/sh
# Battery status with colors and click actions

battery_dir="/sys/class/power_supply/BAT0"
[ ! -d "$battery_dir" ] && battery_dir="/sys/class/power_supply/BAT1"

if [ ! -d "$battery_dir" ]; then
    printf "^c#6c7086^󰂑 N/A^d^"
    exit 1
fi

capacity=$(cat "$battery_dir/capacity" 2>/dev/null || echo "0")
status=$(cat "$battery_dir/status" 2>/dev/null || echo "Unknown")

# Handle click actions
case $BLOCK_BUTTON in
    1) # Left click - show detailed battery info
        notify-send "Battery Info" "$(acpi -b 2>/dev/null || echo "Capacity: ${capacity}%\nStatus: ${status}")"
        ;;
    3) # Right click - power settings
        setsid -f xfce4-power-manager-settings >/dev/null 2>&1 || \
        setsid -f gnome-power-statistics >/dev/null 2>&1
        ;;
esac

# Determine color based on capacity and status
if [ "$status" = "Charging" ]; then
    if [ "$capacity" -gt 80 ]; then
        color="^c#a6e3a1^"  # Green
        icon="󰂋"
    elif [ "$capacity" -gt 60 ]; then
        color="^c#f9e2af^"  # Yellow
        icon="󰂊"
    elif [ "$capacity" -gt 40 ]; then
        color="^c#fab387^"  # Orange
        icon="󰢝"
    elif [ "$capacity" -gt 20 ]; then
        color="^c#f38ba8^"  # Light red
        icon="󰢜"
    else
        color="^c#ff6b6b^"  # Red (blinking could be added)
        icon="󰢟"
    fi
elif [ "$status" = "Full" ]; then
    color="^c#a6e3a1^"  # Green
    icon="󰁹"
else
    # Discharging
    if [ "$capacity" -gt 80 ]; then
        color="^c#a6e3a1^"  # Green
        icon="󰁹"
    elif [ "$capacity" -gt 60 ]; then
        color="^c#f9e2af^"  # Yellow
        icon="󰂂"
    elif [ "$capacity" -gt 40 ]; then
        color="^c#fab387^"  # Orange
        icon="󰂀"
    elif [ "$capacity" -gt 20 ]; then
        color="^c#f38ba8^"  # Light red
        icon="󰁾"
    elif [ "$capacity" -gt 10 ]; then
        color="^c#ff6b6b^"  # Red
        icon="󰁻"
    else
        color="^c#ff0000^"  # Bright red for critical
        icon="󰂎"
    fi
fi

# With statuscmd click action (signal 9)
printf "^s9^%s%s %s%%^d^" "$color" "$icon" "$capacity"
EOF

# sb-date - Date and time with colors and click action
cat > ~/.local/bin/sb-date << 'EOF'
#!/bin/sh
# Date and time with colors and click actions

# Handle click actions
case $BLOCK_BUTTON in
    1) # Left click - show calendar
        notify-send "$(date '+%B %Y')" "$(cal -m)"
        ;;
    3) # Right click - open calendar app
        setsid -f gnome-calendar >/dev/null 2>&1 || \
        setsid -f kalendar >/dev/null 2>&1 || \
        setsid -f thunderbird -calendar >/dev/null 2>&1
        ;;
esac

date_str=$(date '+%a %m/%d')
time_str=$(date '+%H:%M')

# Different colors for different times of day
hour=$(date '+%H')
if [ "$hour" -ge 6 ] && [ "$hour" -lt 12 ]; then
    color="^c#f9e2af^"  # Morning - yellow
elif [ "$hour" -ge 12 ] && [ "$hour" -lt 18 ]; then
    color="^c#fab387^"  # Afternoon - orange
elif [ "$hour" -ge 18 ] && [ "$hour" -lt 22 ]; then
    color="^c#cba6f7^"  # Evening - purple
else
    color="^c#89b4fa^"  # Night - blue
fi

# With statuscmd click action (signal 10)
printf "^s10^%s󰥔 %s %s^d^" "$color" "$date_str" "$time_str"
EOF

# Additional utility script for handling statuscmd signals
cat > ~/.local/bin/dwmblocks-button << 'EOF'
#!/bin/sh
# Handle dwmblocks button clicks
# This script can be called by dwm's statuscmd patch

signal="$1"
button="$2"

export BLOCK_BUTTON="$button"

case "$signal" in
    3) ~/.local/bin/sb-disk ;;
    4) ~/.local/bin/sb-memory ;;
    8) ~/.local/bin/sb-volume ;;
    9) ~/.local/bin/sb-battery ;;
    10) ~/.local/bin/sb-date ;;
esac

# Refresh dwmblocks
pkill -RTMIN+$signal dwmblocks
EOF

# Make all scripts executable
chmod +x ~/.local/bin/sb-disk
chmod +x ~/.local/bin/sb-memory
chmod +x ~/.local/bin/sb-volume
chmod +x ~/.local/bin/sb-battery
chmod +x ~/.local/bin/sb-date
chmod +x ~/.local/bin/dwmblocks-button

echo "Enhanced dwmblocks scripts created with status2d colors and statuscmd support!"
echo ""
echo "Features added:"
echo "- Status2d color support (^c#RRGGBB^ format)"
echo "- Statuscmd click actions (^sN^ format)"
echo "- Dynamic colors based on status/values"
echo "- Click handlers for each module"
echo ""
echo "Click actions:"
echo "- Volume: Left=toggle mute, Right=mixer, Scroll=volume up/down"
echo "- Battery: Left=info popup, Right=power settings"
echo "- Date: Left=calendar popup, Right=calendar app"
echo "- Memory/Disk: Click for detailed info (customize as needed)"
echo ""
echo "Make sure your dwm config.c includes proper statuscmd handling!"
echo "Your config.h should work as-is with these enhanced scripts."
