#!/bin/sh
. "$(dirname "$0")/shini.sh"

__shini_parse_error()
{
	case "$2" in
		"")
			;;
		"a")
			;;

		*)
			echo "Parse error thrown wrongly on '$1' '$2'" 1>&2
			FAIL=1
			;;
	esac
}

__shini_parsed()
{
	ERROR=0
	case "$1" in
		"")
			case "$2" in
				"test1a")
					;;
				"test1b")
					;;

				*)
					ERROR=1
					;;
			esac
			;;
		"test1sectionA")
			case "$2" in
				"test1c")
					;;
				"test1d")
					;;
				"test1e")
					;;

				*)
					ERROR=1
					;;
			esac
			;;

		*)
			ERROR=1
			;;
	esac

	if [ "$3" != "b" ]; then
		FAIL=1
	fi

	if [ $ERROR -eq 1 ]; then
		echo "Parse provided wrong result on '$1' '$2' '$3'" 1>&2
		FAIL=1
	fi
}

__shini_file_unreadable()
{
	case "$1" in
		"tests/nonexistent.ini")
			;;

		*)
			echo "File unreadable failed on '$1'" 1>&2
			FAIL=1
			;;
	esac
}

FAIL=0

shini_parse "tests/nonexistent.ini"
shini_parse "tests/test1.ini"
shini_parse "tests/test2.ini"

exit $FAIL

