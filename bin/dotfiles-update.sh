#!/usr/bin/env bash
# Clone dotfiles fron git repository into user home directory.

show_usage() {
    cat <<EOF
Usage: $(basename $0) [OPTIONS] [git_repo]
Checkout git repository into destination folder and create hardlinks to
content of destination folder in user home directory.
If git repository not provided default will be used:
    - https://github.com/a1black/dotfiles.git
Do not run script as root or sudoer
OPTIONS:
    -d      Destination directory (default is ~/.dotfiles).
    -h      Show this message.
EOF

    exit 0
}

show_error() {
    cat >&2 <<EOF
$1
Try '$(basename $0) -h' for more information.
EOF

    exit 1
}

# Check UID
if [[ -n "$SUDO_USER" || "$UID" -eq 0 ]]; then
    show_error 'Run scsript as current user.'
fi

# Check for required software
! git --version > /dev/null 2>&1 && show_error 'Git is not available.'
! wget --version > /dev/null 2>&1 && show_error 'Wget is not available.'

# Set defaults
GITREPO='https://github.com/a1black/dotfiles.git'
DESTINATION=~/.dotfiles

# Process arguments
while getopts ":hd:" OPTION; do
    case $OPTION in
        d) DESTINATION="$OPTARG";;
        h) show_usage;;
        *) show_error "Unknown option.";;
    esac
done

POSARG=${@:$OPTIND:1}
[ -n "$POSARG" ] && GITREPO="$POSARG"
DESTINATION="$(realpath "$DESTINATION")"

# Validate arguments
if ! [[ "$GITREPO" =~ ^(https?://)?[-a-zA-Z0-9_\+%@.:]+(/[-a-zA-Z0-9_\+%.]+)*$ ]]; then
    show_error 'Provide URL like: https://github.com/user/reponame.git'
elif ! [[ "$GITREPO" =~ ^http ]]; then
    GITREPO="https://$GITREPO"
fi
if ! wget -q --no-cookies --spider --timeout=2 --tries=2 "$GITREPO" > /dev/null 2>&1; then
    show_error "Repository '$GITREPO' does not exist."
elif [[ -e "$DESTINATION" && ! -d "$DESTINATION" ]]; then
    show_error "Invalid destination folder '$DESTINATION'."
fi

## Retrieve dot files from git repository
try_stash() {
    local dirty=$(git status --short --untracked-files=normal \
                  --ignore-submodules | wc -l)
    if [ $dirty -ne 0 ]; then
        git stash push -q -u -m "dotsup_$(date +%s)"
        echo "stash@{0}"
    fi
    return 0
}

# Try clone
git clone -q "$GITREPO" "$DESTINATION" 2> /dev/null

if [ $? -ne 0 ]; then
    cd "$DESTINATION"
    # Check if destination folder is git working tree
    if ! git rev-parse --is-inside-work-tree > /dev/null 2>&1; then
        show_error "Folder '$DESTINATION' is not empty."
    fi
    STASH=$(try_stash)
    git pull -q
    if [ -n "$STASH" ]; then
        git stash apply $STASH
        git stash drop $STASH
    fi
fi

# Create hard links
cd "$DESTINATION"
for elem in $(git ls-files -co --exclude-standard); do
    if [[ "${elem,,}" = readme.md || ${elem,,} = license || ${elem,,} = tags ]]; then
        continue
    fi
    # Get dirname
    path=${elem%/*}
    if ! [ "$path" = "$elem" ]; then
        mkdir -p "$HOME/$path" 2> /dev/null || continue
    fi
    ln -f "$DESTINATION/$elem" "$HOME/$elem" 2> /dev/null
done
