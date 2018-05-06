#!/usr/bin/env bash
# Script removes old Kernal versions.

function show_usage() {
    cat << EOF
Usage: $(basename $0) [OPTION]
Remove old versions of Kernal from /boot partition.
OPTION:
    -l      List old Kernals.
    -h      Show this message.

EOF
    exit 1
}

while getopts ':lh' OPTION; do
    case $OPTION in
        l) DO_LISTING=1;;
        *) show_usage;;
    esac
done

function dpkg_cmd() {
    dpkg --list 'linux-image*' | grep -oe '^ii\s\+linux-image[-a-z0-9_\.]\+-generic' | awk '{print $2}' | grep -v $(uname -r)
}

# Just list old packages.
if [ -n "$DO_LISTING" ]; then
    dpkg_cmd
    exit 0
fi

if [ $EUID -ne 0 ]; then
    echo 'Run script with root privileges.'
    exit 126
fi

for pkg in $(dpkg_cmd); do
    sudo apt-get purge -qy $pkg
done

sudo apt-get -y autoremove
sudo update-grub
