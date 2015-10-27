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

## Write tests

TEMP="$(mktemp -t shini_test)"
echo -n "
[SECTION1]
abc=123
[SECTION2]
def=456 ; comment
ccc=ccc" > "$TEMP"

shini_write "$TEMP" "SECTION1" "qqq" "aaa"
shini_write "$TEMP" "SECTION1" "qqq" "abc"
shini_write "$TEMP" "SECTION1" "qqq" "ddd"
shini_write "$TEMP" "SECTION2" "rrr" "sss"
shini_write "$TEMP" "SECTION1" "abc" "bbb"
shini_write "$TEMP" "SECTION3" "xxx" "yyy"

if ! grep -q "abc=bbb" "$TEMP"; then
    echo "Writing failed (abc=bbb)"
    FAIL=1
fi

if ! grep -q "qqq=ddd" "$TEMP"; then
    echo "Writing failed (qqq=ddd)"
    FAIL=1
fi

if grep -q "abc=123" "$TEMP"; then
    echo "Updating failed (abc=123 still remains)"
    FAIL=1
fi

rm -f "$TEMP"

exit $FAIL

