#!/bin/bash

##############################################################################
# Matrix Digital Rain - Rainbow Edition
# Recreates the falling rain animation from the Matrix movies with rainbow
# colors similar to cmatrix | lolcat
#
# Usage: ./matrix-rain.sh [-s SPEED] [-d DENSITY] [-h]
#   -s SPEED   Animation speed 1-10 (default: 5)
#   -d DENSITY Column density 1-100 (default: 80)
#   -h         Show this help message
##############################################################################

set -o pipefail

# Configuration
SPEED=5
DENSITY=80
TERM_WIDTH=0
TERM_HEIGHT=0

# Katakana character set (Unicode U+FF66 to U+FF9D)
# This is the authentic Matrix character set
CHARS=(
    "ｱ" "ｲ" "ｳ" "ｴ" "ｵ" "ｶ" "ｷ" "ｸ" "ｹ" "ｺ"
    "ｻ" "ｼ" "ｽ" "ｾ" "ｿ" "ﾀ" "ﾁ" "ﾂ" "ﾃ" "ﾄ"
    "ﾅ" "ﾆ" "ﾇ" "ﾈ" "ﾉ" "ﾊ" "ﾋ" "ﾌ" "ﾍ" "ﾎ"
    "ﾏ" "ﾐ" "ﾑ" "ﾒ" "ﾓ" "ﾔ" "ﾕ" "ﾖ" "ﾗ" "ﾘ"
    "ﾘ" "ﾜ" "ﾞ" "ﾟ"
)

##############################################################################
# Terminal Setup and Cleanup
##############################################################################

setup_terminal() {
    # Switch to alternate screen buffer
    printf '\e[?1049h'
    # Clear screen
    printf '\e[2J'
    # Hide cursor
    printf '\e[?25l'
    # Disable line wrapping
    printf '\e[?7l'
    # Get terminal size
    get_terminal_size
}

restore_terminal() {
    # Show cursor
    printf '\e[?25h'
    # Enable line wrapping
    printf '\e[?7h'
    # Switch back to main screen buffer
    printf '\e[?1049l'
}

get_terminal_size() {
    # Try to get terminal dimensions using escape sequences
    local IFS='[;' response

    # Position cursor at far corner and request position
    printf '\e[999;999H\e[6n' >&2
    read -t 1 -rs response >&2

    # Parse the response (should be something like ESC[rows;colsR)
    if [[ $response =~ ([0-9]+)\;([0-9]+) ]]; then
        TERM_HEIGHT=${BASH_REMATCH[1]}
        TERM_WIDTH=${BASH_REMATCH[2]}
    else
        # Fallback to tput if available
        if command -v tput &>/dev/null; then
            TERM_HEIGHT=$(tput lines 2>/dev/null || echo 24)
            TERM_WIDTH=$(tput cols 2>/dev/null || echo 80)
        else
            # Ultimate fallback
            TERM_HEIGHT=${LINES:-24}
            TERM_WIDTH=${COLUMNS:-80}
        fi
    fi

    # Ensure minimum size
    TERM_HEIGHT=$((TERM_HEIGHT < 10 ? 10 : TERM_HEIGHT))
    TERM_WIDTH=$((TERM_WIDTH < 20 ? 20 : TERM_WIDTH))

    # Reset cursor position
    printf '\e[H'
}

##############################################################################
# Rainbow Color Generator
# Uses sine wave algorithm similar to lolcat
##############################################################################

rainbow_color() {
    local position=$1
    local freq=0.1

    # Calculate RGB using awk for floating point math
    # Formula: color = sin(freq * position + phase) * 127 + 128
    local rgb
    rgb=$(awk -v pos="$position" -v freq="$freq" 'BEGIN {
        pi = atan2(0,-1)
        r = int(sin(freq*pos) * 127 + 128)
        g = int(sin(freq*pos + 2*pi/3) * 127 + 128)
        b = int(sin(freq*pos + 4*pi/3) * 127 + 128)
        print r ";" g ";" b
    }')

    echo "$rgb"
}

##############################################################################
# Column Rain Animation
# Manages a single falling column of characters
##############################################################################

rain_column() {
    local col=$1
    local speed=$2
    local char_set_size=${#CHARS[@]}

    # Column state
    local pos=0
    local length=$((RANDOM % (TERM_HEIGHT / 2) + 3))
    local gap=$((RANDOM % 10 + 5))
    local in_gap=true
    local color_offset=$((RANDOM % 360))

    # Trail history (position -> character)
    declare -A trail

    while true; do
        # Delay based on speed (1-10, inverted: 1=slow, 10=fast)
        local delay=$(echo "scale=3; 1.0 - ($speed - 1) * 0.08" | bc -l 2>/dev/null || echo "0.5")
        sleep "$delay"

        # Handle gap before stream starts
        if $in_gap; then
            gap=$((gap - 1))
            if ((gap <= 0)); then
                in_gap=false
                pos=1
                length=$((RANDOM % (TERM_HEIGHT / 2) + 3))
            fi
            continue
        fi

        # Move current stream down
        local rainbow_pos=$((pos + color_offset))
        local rgb=$(rainbow_color "$rainbow_pos")

        # Print head character (bright, full intensity)
        if ((pos >= 1 && pos <= TERM_HEIGHT)); then
            local char="${CHARS[$((RANDOM % char_set_size))]}"
            printf '\e[%d;%dH\e[1;38;2;%sm%s\e[m' "$pos" "$col" "$rgb" "$char"
        fi

        # Print trail characters (dimmer)
        local trail_pos=$((pos - 1))
        if ((trail_pos >= 1 && trail_pos <= TERM_HEIGHT)); then
            if [[ -n "${trail[$trail_pos]}" ]]; then
                local trail_rainbow=$((trail_pos + color_offset))
                local trail_rgb=$(rainbow_color "$trail_rainbow")
                printf '\e[%d;%dH\e[2;38;2;%sm%s\e[m' "$trail_pos" "$col" "$trail_rgb" "${trail[$trail_pos]}"
            fi
        fi

        # Store character for trail
        trail[$pos]="${CHARS[$((RANDOM % char_set_size))]}"

        # Remove character beyond trail length
        local erase_pos=$((pos - length))
        if ((erase_pos >= 1)); then
            unset 'trail[$erase_pos]'
            printf '\e[%d;%dH ' "$erase_pos" "$col"
        fi

        # Reset stream and gap when we reach bottom
        pos=$((pos + 1))
        if ((pos > TERM_HEIGHT + length)); then
            pos=0
            in_gap=true
            gap=$((RANDOM % 10 + 5))
            trail=()
        fi
    done
}

##############################################################################
# Main Loop
##############################################################################

main_loop() {
    local num_columns=$((TERM_WIDTH * DENSITY / 100))

    # Ensure at least 1 column
    num_columns=$((num_columns < 1 ? 1 : num_columns))

    # Spawn rain processes for each column
    for ((col=1; col<=num_columns; col++)); do
        rain_column "$col" "$SPEED" &
    done

    # Wait for all background processes
    wait
}

##############################################################################
# Argument Parsing
##############################################################################

print_help() {
    cat << 'EOF'
Matrix Digital Rain - Rainbow Edition
Recreates the falling rain animation from the Matrix movies

USAGE:
  matrix-rain.sh [OPTIONS]

OPTIONS:
  -s SPEED    Animation speed (1-10, default: 5)
              1 = slow, 10 = fast
  -d DENSITY  Column density (1-100%, default: 80)
              Percentage of terminal width filled with columns
  -h          Show this help message

EXAMPLES:
  ./matrix-rain.sh                    # Default settings
  ./matrix-rain.sh -s 8 -d 100        # Fast animation, full density
  ./matrix-rain.sh -s 2 -d 50         # Slow animation, sparse

CONTROLS:
  Ctrl+C      Stop the animation
EOF
}

parse_arguments() {
    while getopts "s:d:h" opt; do
        case $opt in
            s)
                SPEED=$OPTARG
                if ! [[ $SPEED =~ ^[0-9]+$ ]] || ((SPEED < 1 || SPEED > 10)); then
                    echo "Error: Speed must be between 1 and 10" >&2
                    return 1
                fi
                ;;
            d)
                DENSITY=$OPTARG
                if ! [[ $DENSITY =~ ^[0-9]+$ ]] || ((DENSITY < 1 || DENSITY > 100)); then
                    echo "Error: Density must be between 1 and 100" >&2
                    return 1
                fi
                ;;
            h)
                print_help
                return 0
                ;;
            *)
                echo "Invalid option: -$OPTARG" >&2
                return 1
                ;;
        esac
    done
}

##############################################################################
# Signal Handlers and Entry Point
##############################################################################

cleanup() {
    # Kill all background processes
    jobs -p | xargs -r kill 2>/dev/null
    # Restore terminal
    restore_terminal
}

on_sigwinch() {
    # Terminal was resized
    get_terminal_size
    # Kill all columns and restart
    jobs -p | xargs -r kill 2>/dev/null
    printf '\e[2J'  # Clear screen
    main_loop &
    wait
}

on_interrupt() {
    # Ctrl+C pressed
    exit 0
}

main() {
    # Parse arguments
    parse_arguments "$@" || exit 1

    # Setup terminal
    setup_terminal

    # Setup signal handlers
    trap cleanup EXIT
    trap on_interrupt INT TERM
    trap on_sigwinch SIGWINCH

    # Start main animation loop
    main_loop
}

# Ensure UTF-8 support
export LC_ALL=en_US.UTF-8
export LANG=en_US.UTF-8

# Run main if script is executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
