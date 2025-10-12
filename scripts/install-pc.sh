#!/bin/bash

# Transforms the given .pc file into a non-relocatable version by replacing ${pcfiledir} with an
# absolute path, and outputs the resulting file to the given folder (by default, /usr/local/lib/pkgconfig/).
# The file name remains the same as the input file.
#
# Parameters:
#   $1 - The path to the .pc file to process (relative or absolute).
#   $2 - (Optional) The destination directory. Defaults to /usr/local/lib/pkgconfig/
#
# Usage Examples:
#   ./install-pc.sh path/to/file.pc
#   ./install-pc.sh path/to/file.pc /custom/pkgconfig/dir/

# Default destination directory
DEFAULT_DEST_DIR="/usr/local/lib/pkgconfig"

# Check if at least one argument (the .pc file) was provided
if [ $# -lt 1 ] || [ $# -gt 2 ]; then
    echo "Error: Please provide the path to the .pc file and optionally the destination directory" >&2
    echo "Usage: $0 <path-to-pc-file> [destination-directory]" >&2
    echo "Default destination: $DEFAULT_DEST_DIR" >&2
    exit 1
fi

PC_FILE="$1"
DEST_DIR="${2:-$DEFAULT_DEST_DIR}"

# Check if the input .pc file exists
if [ ! -f "$PC_FILE" ]; then
    echo "Error: File '$PC_FILE' does not exist or is not a regular file" >&2
    exit 1
fi

# Get the script directory to find make-absolute-pc.sh
SCRIPT_DIR="$(dirname "$(realpath "$0")")"
MAKE_ABSOLUTE_SCRIPT="$SCRIPT_DIR/make-absolute-pc.sh"

# Check if make-absolute-pc.sh exists
if [ ! -x "$MAKE_ABSOLUTE_SCRIPT" ]; then
    echo "Error: make-absolute-pc.sh not found or not executable at '$MAKE_ABSOLUTE_SCRIPT'" >&2
    exit 1
fi

# Create destination directory if it doesn't exist
if [ ! -d "$DEST_DIR" ]; then
    echo "Creating destination directory: $DEST_DIR"
    if ! mkdir -p "$DEST_DIR"; then
        echo "Error: Failed to create destination directory '$DEST_DIR'" >&2
        exit 1
    fi
fi

# Get the filename from the input path
PC_FILENAME="$(basename "$PC_FILE")"
DEST_FILE="$DEST_DIR/$PC_FILENAME"

# Transform the .pc file and write to destination
echo "Installing '$PC_FILE' to '$DEST_FILE'"
if ! "$MAKE_ABSOLUTE_SCRIPT" "$PC_FILE" > "$DEST_FILE"; then
    echo "Error: Failed to transform and install the .pc file" >&2
    exit 1
fi

echo "Successfully installed '$PC_FILENAME' to '$DEST_DIR'"