#!/bin/sh

# Include library
# For this reason, you should locate shini.sh somewhere super unwritable by world.
. "$(dirname "$0")/shini.sh"

# Declare a handler for parsed variables.  This is required.
__shini_parsed()
{
	printf "  %s.%s='%s'\n" "$1" "$2" "$3"
}

# Parse
printf "Parsing...\n\n"
shini_parse "example.ini"
printf "\nComplete.\n"

