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

RAINBOW_FREQ=0.1
RAINBOW_CYCLE=63
FRAME_DELAY_US=100000
FRAME_DELAY_STR=0.100
USE_EPOCHREALTIME=0

declare -a COLUMN_STATE      # 0 gap, 1 active stream
declare -a COLUMN_HEAD       # current head position in rows
declare -a COLUMN_GAP        # remaining frames before stream restarts
declare -a COLUMN_LENGTH     # length of active stream
declare -a COLUMN_COLOR      # color offset per column
declare -a COLUMN_LAST_CHAR  # character previously used as head

declare -a RAINBOW_TABLE
RESIZE_REQUEST=0
NUM_COLUMNS=0

# Katakana character set (Unicode U+FF66 to U+FF9D)
# This is the authentic Matrix character set
CHARS=(
    "ｱ" "ｲ" "ｳ" "ｴ" "ｵ" "ｶ" "ｷ" "ｸ" "ｹ" "ｺ"
    "ｻ" "ｼ" "ｽ" "ｾ" "ｿ" "ﾀ" "ﾁ" "ﾂ" "ﾃ" "ﾄ"
    "ﾅ" "ﾆ" "ﾇ" "ﾈ" "ﾉ" "ﾊ" "ﾋ" "ﾌ" "ﾍ" "ﾎ"
    "ﾏ" "ﾐ" "ﾑ" "ﾒ" "ﾓ" "ﾔ" "ﾕ" "ﾖ" "ﾗ" "ﾘ"
    "ﾘ" "ﾜ" "ﾞ" "ﾟ"
)
CHAR_SET_SIZE=${#CHARS[@]}

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

init_rainbow_table() {
    if ((${#RAINBOW_TABLE[@]} > 0)); then
        return
    fi

    local data
    data=$(awk -v freq="$RAINBOW_FREQ" -v cycle="$RAINBOW_CYCLE" 'BEGIN {
        pi = atan2(0,-1)
        for (i = 0; i < cycle; i++) {
            r = int(sin(freq*i) * 127 + 128)
            g = int(sin(freq*i + 2*pi/3) * 127 + 128)
            b = int(sin(freq*i + 4*pi/3) * 127 + 128)
            printf "%d;%d;%d\n", r, g, b
        }
    }')

    local i=0
    while IFS= read -r line; do
        RAINBOW_TABLE[$i]=$line
        ((i++))
    done <<< "$data"
}

rainbow_color() {
    local position=$1
    local index=$((position % RAINBOW_CYCLE))
    if ((index < 0)); then
        index=$((index + RAINBOW_CYCLE))
    fi
    echo "${RAINBOW_TABLE[$index]}"
}

##############################################################################
# Column Rain Animation
# Manages a single falling column of characters
##############################################################################

calculate_frame_delay() {
    local ms=$((160 - SPEED * 12))
    if ((ms < 20)); then
        ms=20
    fi
    FRAME_DELAY_US=$((ms * 1000))
    printf -v FRAME_DELAY_STR '0.%03d' "$ms"
}

init_columns() {
    local num_columns=$((TERM_WIDTH * DENSITY / 100))
    ((num_columns < 1)) && num_columns=1

    NUM_COLUMNS=$num_columns

    for ((col=1; col<=NUM_COLUMNS; col++)); do
        COLUMN_STATE[$col]=0
        COLUMN_HEAD[$col]=0
        COLUMN_GAP[$col]=$((RANDOM % 10 + 5))
        COLUMN_LENGTH[$col]=$((RANDOM % (TERM_HEIGHT / 2 + 1) + 3))
        COLUMN_COLOR[$col]=$((RANDOM % RAINBOW_CYCLE))
        COLUMN_LAST_CHAR[$col]=""
    done

}

draw_column_frame() {
    local col=$1

    if ((COLUMN_STATE[$col] == 0)); then
        local gap=${COLUMN_GAP[$col]}
        if ((gap > 0)); then
            COLUMN_GAP[$col]=$((gap - 1))
            return
        fi
        COLUMN_STATE[$col]=1
        COLUMN_HEAD[$col]=1
    fi

    local head=${COLUMN_HEAD[$col]}
    local length=${COLUMN_LENGTH[$col]}
    local color_offset=${COLUMN_COLOR[$col]}
    local prev_char=${COLUMN_LAST_CHAR[$col]}

    if ((head >= 1 && head <= TERM_HEIGHT)); then
        local char="${CHARS[$((RANDOM % CHAR_SET_SIZE))]}"
        COLUMN_LAST_CHAR[$col]=$char
        local rainbow_pos=$((head + color_offset))
        local rgb
        rgb=$(rainbow_color "$rainbow_pos")
        printf '\e[%d;%dH\e[1;38;2;%sm%s' "$head" "$col" "$rgb" "$char"
    fi

    local trail_pos=$((head - 1))
    if ((trail_pos >= 1 && trail_pos <= TERM_HEIGHT)); then
        if [[ -n $prev_char ]]; then
            local trail_rainbow=$((trail_pos + color_offset))
            local trail_rgb
            trail_rgb=$(rainbow_color "$trail_rainbow")
            printf '\e[%d;%dH\e[2;38;2;%sm%s' "$trail_pos" "$col" "$trail_rgb" "$prev_char"
        fi
    fi

    local erase_pos=$((head - length))
    if ((erase_pos >= 1)); then
        if ((erase_pos <= TERM_HEIGHT)); then
            printf '\e[0m\e[%d;%dH ' "$erase_pos" "$col"
        fi
    fi

    COLUMN_HEAD[$col]=$((head + 1))

    if ((head > TERM_HEIGHT + length)); then
        COLUMN_STATE[$col]=0
        COLUMN_HEAD[$col]=0
        COLUMN_GAP[$col]=$((RANDOM % 10 + 5))
        COLUMN_LENGTH[$col]=$((RANDOM % (TERM_HEIGHT / 2 + 1) + 3))
        COLUMN_COLOR[$col]=$(((color_offset + RANDOM % RAINBOW_CYCLE) % RAINBOW_CYCLE))
        COLUMN_LAST_CHAR[$col]=""
    fi
}

##############################################################################
# Main Loop
##############################################################################

main_loop() {
    while true; do
        local frame_start_us frame_end_us elapsed sleep_us

        if ((USE_EPOCHREALTIME)); then
            frame_start_us=${EPOCHREALTIME//./}
        fi

        if ((RESIZE_REQUEST)); then
            get_terminal_size
            printf '\e[2J\e[H'
            init_columns
            RESIZE_REQUEST=0
        fi

        for ((col=1; col<=NUM_COLUMNS; col++)); do
            draw_column_frame "$col"
        done

        printf '\e[0m'

        if ((USE_EPOCHREALTIME)); then
            frame_end_us=${EPOCHREALTIME//./}
            elapsed=$((frame_end_us - frame_start_us))
            sleep_us=$((FRAME_DELAY_US - elapsed))
            if ((sleep_us > 0)); then
                local sleep_arg=""
                local sleep_sec=$((sleep_us / 1000000))
                local sleep_rem=$((sleep_us % 1000000))
                if ((sleep_sec > 0)); then
                    printf -v sleep_arg '%d.%06d' "$sleep_sec" "$sleep_rem"
                elif ((sleep_rem > 0)); then
                    printf -v sleep_arg '0.%06d' "$sleep_rem"
                fi
                if [[ -n $sleep_arg ]]; then
                    sleep "$sleep_arg"
                fi
            fi
        else
            sleep "$FRAME_DELAY_STR"
        fi
    done
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
    printf '\e[0m'
    restore_terminal
}

on_sigwinch() {
    RESIZE_REQUEST=1
}

on_interrupt() {
    # Ctrl+C pressed
    exit 0
}

main() {
    # Parse arguments
    parse_arguments "$@" || exit 1

    # Detect high-resolution timing support
    if [[ -n ${EPOCHREALTIME-} ]]; then
        USE_EPOCHREALTIME=1
    fi

    # Precompute timing and color tables
    calculate_frame_delay
    init_rainbow_table

    # Setup terminal
    setup_terminal

    # Initialize columns based on current terminal size
    init_columns

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
