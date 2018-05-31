#!/usr/bin/env bash
# Prints out bash 256 color scheme.

# Returns color that is readable on specified background color.
# Args:
#   $1  decimal code for background color
function get_contrasted_clr () {
    # Default values.
    local black=0 white=15
    local clr=$(($1))
    local r g b yiq
    if ((clr == black)); then
        printf $white
    elif ((clr == white)); then
        printf $black
    elif ((clr < 16)); then
        printf $black
    elif ((clr < 232)); then
        ((r = (clr - 16) / 36))
        ((g = (clr - 16) % 36 / 6))
        ((b = (clr - 16) % 36 % 6))
        ((yiq = r * 299 + g * 587 + b * 114))
        ((yiq < 2500)) && printf $white || printf $black
    elif ((clr < 244)); then
        printf $white
    else
        printf $black
    fi
}

# Prints color block and its decimical code.
# Args:
#   $1  decimal code for displayed color
function print_clr () {
    printf "\e[48;5;%sm" $1
    printf "\e[38;5;%sm" $(get_contrasted_clr $1)
    printf "%3d\e[0m" $1
}

# Prints sequence of colors.
# Args:
#   $1  start of the color sequence
#   $2  end of the color sequence
function print_clr_sequence () {
    local clr
    for ((clr = "$1"; clr < "$2"; clr++)); do
        print_clr $clr
        printf " "
    done
}

# Prints section of color palette.
# Args:
#   $1  start of the section
#   $2  end of the section (inclusive)
#   $3  width of a color block in the palette section
#   $4  height of a color block in the palette section
function print_palette_section () {
    # Default values.
    local width_max=20
    # Sector paramenters.
    local start end size width height height_max
    ((start = $1, end = $2, size = 1 + end - start))
    # Get width of a color block.
    [ -z "$3" ] && ((width = size)) || ((width = $3))
    (( width > width_max )) && ((width = width_max))
    # Get height of a color block.
    ((height_max = (end - start) / width + 1))
    [ -z "$4" ] && ((height = height_max)) || ((height = $4))
    ((height > height_max)) && ((height = height_max))
    # Define section building parameters.
    local cols=$((width_max / width))
    local i j clr
    # Print section of the palette.
    for ((; start <= end; start += width * height * cols)); do
        printf "\n"
        for ((i = 0; i < height; i++)); do
            for ((j = 0; start <= end && j < cols; j++)); do
                ((clr = start + i * width + j * width * height))
                if ((clr + width <= end)); then
                    print_clr_sequence $clr $((clr + width))
                else
                    print_clr_sequence $clr $((end + 1))
                fi
                printf "  "
            done
            printf "\n"
        done
    done
}

# Basic 16 colors.
print_palette_section 0 15
# The rest of spectrum.
print_palette_section 16 231 6 6
# 24 shades of gray.
print_palette_section 232 255 $(((256 - 232) / 2))
