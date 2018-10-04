#!/bin/sh
# Usage: PREFIX=/usr/local ./install.sh
#
# Install scripts under $PREFIX.

set -eu

cd "$(dirname "$0")"

if [ -z "${PREFIX}" ]; then
    PREFIX="/usr/local"
fi

BIN_PATH="${PREFIX}/bin"

mkdir -p "$BIN_PATH"

install -p bin/* "$BIN_PATH"

cd - > /dev/null
