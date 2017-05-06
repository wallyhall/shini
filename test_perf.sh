#!/bin/sh
set -e

. "$(dirname "$0")/shini.sh"

__shini_parsed ()
{
    echo "[$1] $2 = $3"
}

__shini_parse_error ()
{
    echo "[$1] $2 = $3"
}

SECTION=''
[ -n "$1" ] && SECTION=$1

shini_parse_section "tests/php.ini" $SECTION
