#!/usr/bin/env bash
# Prints out battery charge information.

# Check if executable is accessible.
# Args:
#   $1  checked command name
function cmd_exists() {
    type "$1" &> /dev/null
}

# Retrieves battery information using one of available command-line utilites.
# Returned format: "plugged_in current_energy full_energy percentage minutes_left".
function cmd_battery_run() {
    if cmd_exists 'upower'; then
        battery_info_str_upower
        return $?
    fi
    return 1
}

# Retrieves battery information using `upower` utilite.
function battery_info_str_upower() {
    local id=$(upower -e 2> /dev/null | grep -m 1 battery)
    [ -z "$id" ] && return 1
    local upower_out=$(upower -i $id 2> /dev/null)
    [ -z "$upower_out" ] && return 1
    # 0 - unplugged, 1 - plugged-in
    local state=$(cat <<< "$upower_out" | awk '/state:/ {print $2 == "charging"}')
    # Battery energy level.
    local energy_left=$(cat <<< "$upower_out" | awk '/energy:/ {print 0+$2}')
    local energy_full=$(cat <<< "$upower_out" | awk '/energy-full:/ {print 0+$2}')
    # Battery energy level in percents.
    if [ $energy_full = 0 ]; then
        local percentage=0
    else
        local percentage=$(awk -v left=$energy_left -v full=$energy_full 'BEGIN{printf "%d", (left/full)*100}')
    fi
    # Minutes left to full charge or discharge.
    local time_to=$(cat <<< "$upower_out" | grep -m 1 -E '(remain|time to [a-z]+)' | cut -d: -f2)
    local time_left=$(echo "$time_to" | awk '{print 0+$1}')
    local time_left_unit=$(echo "$time_to" | awk '{print $2}')
    if [ "$time_left_unit" = 'hours' ]; then
        time_left=$(awk -v left="$time_left" 'BEGIN{printf "%d", left*60}')
    fi
    printf "%d %.0f %.0f %d %.0f" $state $energy_left $energy_full $percentage $time_left
    return 0
}

# Returns glyph for remaining battery charge.
# Args:
#   $1  left energy
function glyph_energy_left() {
    local energy=$(("$1"))
    if ((energy <= 5 )); then
        printf "\u2581"
    elif ((energy <= 20)); then
        printf "\u2582"
    elif ((energy <= 50)); then
        printf "\u2584"
    elif ((energy <= 80)); then
        printf "\u2586"
    else
        printf "\u2588"
    fi
}

# Returns glyph indicating battery charging state.
# Args:
#   $1  plugged-in flag
function glyth_plugged_state() {
    local state=$(("$1"))
    ((state == 1)) && printf "\u26a1" || printf ""
}

# Add color code to stdout.
# Args:
#   $1  remaining energy
function print_color_code() {
    local percentage=$(("$1"))
    if ((percentage <= 25)); then
        printf "\e[31m"
    elif ((percentage <= 75)); then
        printf "\e[33m"
    else
        printf "\e[32m"
    fi
}

# Help message.
function show_usage() {
    cat << EOF
Usage: $(basename $0) [OPTION]
Display current charge information of your device battery.

OPTION:
    -h      Show this message.
    -l      Display information in long format.
    -t      Use text instead of glyphs.
EOF
    exit 0
}

# Global variables.
short_output=1
text_output=0
color_output=0
# Process script arguments.
while getopts ':hclt' OPTION; do
    case "$OPTION" in
        c) color_output=1;;
        l) short_output=0;;
        t) text_output=1;;
        *) show_usage;;
    esac
done

function main() {
    local info=$(cmd_battery_run)
    [ -z "$info" ] && return 1
    local glyph plugged_glyth
    # Unpack battery information string.
    local plugged=$(printf "$info" | awk '{print $1}')
    local energy_left=$(printf "$info" | awk '{print $2}')
    local energy_full=$(printf "$info" | awk '{print $3}')
    local percentage=$(printf "$info" | awk '{print $4}')
    local time_left=$(printf "$info" | awk '{print $5}')
    [[ "$percentage" = 0 && "$plugged" != 1 ]] && return 1
    # Calculate remaining time string.
    if ((time_left <= 90)); then
        time_left=$(printf "%d min" $time_left)
    else
        time_left=$(printf "%dh %dmin" $((time_left / 60)) $((time_left % 60)))
    fi
    # Select glyphs.
    if ((text_output == 1)); then
        ((plugged == 1)) && plugged_glyth='charging ' || plugged_glyth='discharging '
    else
        ((plugged == 1)) && plugged_glyth=$(glyth_plugged_state $plugged) || plugged_glyth="$(glyph_energy_left $percentage) "
    fi
    # Output battery information.
    ((color_output == 1)) && print_color_code $percentage
    if ((short_output == 1)); then
        if ((plugged == 1)); then
            printf "$plugged_glyth%d%%" $percentage
        else
            printf "%d%% (%s)" $percentage "$time_left"
        fi
    else
        printf "$plugged_glyth%d%% [%d/%d Wh] left %s" $percentage $energy_left $energy_full "$time_left"
    fi
    ((color_output == 1)) && printf "\e[0m"
    return 0
}

main
