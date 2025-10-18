#!/bin/bash

# Replaces ${pcfiledir} in the given .pc file with an absolute path, outputting the result to stdout.
# Parameters:
#   $1 - The path to the .pc file to process (relative or absolute).
#
# Usage Example:
#   ./make-absolute-pc.sh path/to/file.pc > path/to/absolute-file.pc

# Check if a file path was provided
if [ $# -ne 1 ]; then
    echo "Error: Please provide exactly one argument - the path to the .pc file" >&2
    echo "Usage: $0 <path-to-pc-file>" >&2
    exit 1
fi

PC_FILE="$1"

# Check if the file exists
if [ ! -f "$PC_FILE" ]; then
    echo "Error: File '$PC_FILE' does not exist or is not a regular file" >&2
    exit 1
fi

# Get the absolute directory path of the .pc file
PC_FILE_ABS=$(realpath "$PC_FILE")
PC_DIR_ABS=$(dirname "$PC_FILE_ABS")

# Read the file and replace ${pcfiledir} with the absolute directory path
sed "s|\${pcfiledir}|$PC_DIR_ABS|g" "$PC_FILE"