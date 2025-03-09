#!/bin/bash

# Check if a name argument is provided
if [ -z "$1" ]; then
  echo "Usage: $0 <name-of-post>"
  exit 1
fi

# Replace spaces with hyphens and convert to lowercase
NAME=$(echo "$1" | tr '[:upper:]' '[:lower:]' | tr ' ' '-')

# Create the new CTF write-up
hugo new --kind ctf "ctf/$NAME.md"

