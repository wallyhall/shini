#!/bin/sh

# shellcheck disable=SC1091
. "$(dirname "$0")/shini.sh"

# shellcheck disable=SC2317
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

# shellcheck disable=SC2317
__shini_parsed_specific_test1()
{
        ERROR=0
        case "$1" in
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

        if [ "$ERROR" -eq 1 ]; then
                echo "Parse provided wrong result on '$1' '$2' '$3'" 1>&2
                FAIL=1
        fi
}

# shellcheck disable=SC2317
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
		echo "Parse returned wrong value during basic test '$3' instead of 'b'" 1>&2
		FAIL=1
	fi

	if [ "$ERROR" -eq 1 ]; then
		echo "Parse provided wrong result on '$1' '$2' '$3'" 1>&2
		FAIL=1
	fi
}

# shellcheck disable=SC2317
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

shini_parse "tests/nonexistent.ini" || true
shini_parse "tests/test1.ini"
shini_parse "tests/test2.ini"

## Write tests

FAIL=0

TEMP="$(mktemp -t shini_test_XXXXXX)"
printf "
[SECTION1]
abc=\"123\"
[SECTION2]
def=\"456\" ; comment
quack=duck ; comment
ccc=ccc" > "$TEMP"

shini_write "$TEMP" "SECTION1" "qqq" "aaa" 
shini_write "$TEMP" "SECTION1" "qqq" "abc"
shini_write "$TEMP" "SECTION1" "qqq" "ddd"
shini_write "$TEMP" "SECTION2" "rrr" "sss"
shini_write "$TEMP" "SECTION1" "abc" "bbb" 
shini_write "$TEMP" "SECTION3" "xxx" "yyy"

if ! grep -q '^qqq=ddd$' "$TEMP"; then
    echo "Writing failed (qqq=ddd)"
    FAIL=1
fi

if grep -q '^abc=123$' "$TEMP"; then
    echo "Updating failed (abc=123 still remains)"
    FAIL=1
fi

if ! grep -q '^quack=duck *; comment$' "$TEMP"; then
    echo "Write corruption (quack=duck)"
    FAIL=1
fi

if [ "$FAIL" -ne 0 ]; then
	echo "************ Resulting INI (1) ************"
	cat "$TEMP"
	echo "************        EOF        ************"
fi

# Quoted write tests

shini_write "$TEMP" "SECTION3" "rrr" " s s s " true
shini_write "$TEMP" "SECTION1" "qqq" "ddd" true

if ! grep -q '^rrr=" s s s "$' "$TEMP"; then
    echo "Quoted writing failed (rrr=\" s s s \")"
    FAIL=1
fi

if ! grep -q '^qqq="ddd"$' "$TEMP"; then
    echo "Quoted updating failed (qqq=\"ddd\")"
    FAIL=1
fi

if ! grep -q '^quack="duck"; comment$' "$TEMP"; then
    echo "Quoted write corruption (quack=\"duck\"; comment)"
    FAIL=1
fi

if grep -q '^abc="123"$' "$TEMP"; then
    echo "Quoted write corruption (abc=\"123\" is broken)"
    FAIL=1
fi

if [ "$FAIL" -ne 0 ]; then
	echo "************ Resulting INI (2) ************"
	cat "$TEMP"
	echo "************        EOF        ************"
fi

## Specific section test

shini_parse_section "tests/test1.ini" "test1sectionA" "specific_test1"

## Specific key test

VALUE="$(shini_read tests/test2.ini "" test1b)"
if [ "$VALUE" != "b" ]; then
	echo "Read of specific key failed: '$VALUE' instead of 'b'" 1>&2
fi

rm -f "$TEMP"

exit $FAIL
