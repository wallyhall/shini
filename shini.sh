#!/bin/sh
# shini - compatible INI library for sh
#
# This code is released freely under the MIT license - see the shipped LICENSE document.
# For the latest version etc, please see https://github.com/wallyhall/shini
#

# Solely for the purpose of portable performance, this script breaks good practice to
# avoid forking subshells.  One such good practice is avoiding global variables.
# This variable is used to carry non-numeric results from functions to the caller.
# Alternatively an echo and "$(...)" approach could be used, but is significantly slower.

shini_setup()
{
    if [ -n "$ZSH_VERSION" ]; then
        RESTORE_OPTS=$(set +o)
        # Enable BASH_REMATCH for zsh
        setopt KSH_ARRAYS BASH_REMATCH
    fi
}

shini_teardown()
{
    [ -n "$ZSH_VERSION" ] && eval "$RESTORE_OPTS"
}

shini_function_exists()
{
    type "$1" > /dev/null 2>&1
    return $?
}

shini_regex_match()
{
    # $KSH_VERSION (I'm told) only exists on ksh 93 and above, which supports regex matching.
    # shellcheck disable=SC3054
    if [ -n "${BASH_VERSINFO[0]}" ] && [ "${BASH_VERSINFO[0]}" -ge 3 ] || \
       [ -n "$ZSH_VERSION" ] || \
       [ -n "$KSH_VERSION" ]; then
        # shellcheck disable=SC3010
        [[ "$1" =~ $2 ]] && return 0 || return 1
    fi

    printf '%s' "$1" | grep -qe "$2"
    return $?
}

shini_regex_extract()
{
    # shellcheck disable=SC3054
    if [ -n "${BASH_VERSINFO[0]}" ] && [ "${BASH_VERSINFO[0]}" -ge 3 ] || \
       [ -n "$ZSH_VERSION" ]; then
        # shellcheck disable=SC3010
        # shellcheck disable=SC3028
        # shellcheck disable=SC3054
        [[ "$1" =~ $2 ]] && printf "%s" "${BASH_REMATCH[1]}" || printf "%s" "$1"
        return 0
    fi

    printf '%s' "$1" | sed -E "s/$2/\1/"  # If you have isses on older systems,
    # it may be the non-newer POSIX compliant sed.
    # -E should be enabling extended regex mode portably.
}

# @param inifile Filename of INI file to parse
# @param postfix Function postfix for callbacks (optional)
# @param extra Extra argument for callbacks (optional)
shini_parse()
{
    shini_parse_section "$1" '' "$2" "$3" "$4" "$5"
    return $?
}

# @param inifile Filename of INI file to parse
# @param section Section to parse (or empty string for entire file)
# @param postfix Function postfix for callbacks (optional)
# @param extra Extra argument for callbacks (optional)
shini_parse_section()
{
    shini_setup
    # ********

    RX_KEY='[a-zA-Z0-9_\-\.]'
    RX_SECTION='[a-zA-Z0-9_\-]'
    RX_WS='[ 	]'
    RX_QUOTE='"'
    POSTFIX=''
    SKIP_TO_SECTION=''
    EXTRA1=''
    EXTRA2=''
    EXTRA3=''
    SECTION_FOUND=-1
	
	if [ $# -ge 2 ] && [ -n "$2" ]; then
        SKIP_TO_SECTION="$2"
    fi
	
    if [ $# -ge 3 ] && [ -n "$3" ]; then
        POSTFIX="_$3"
    fi
	
    if [ $# -ge 4 ] && [ -n "$4" ]; then
        EXTRA1="$4"
    fi
	
    if [ $# -ge 5 ] && [ -n "$5" ]; then
        EXTRA2="$5"
    fi
	
    if [ $# -ge 6 ] && [ -n "$6" ]; then
        EXTRA3="$6"
    fi
	
    if ! shini_function_exists "__shini_parsed${POSTFIX}"; then
        printf 'shini: __shini_parsed%s function not declared.\n' "${POSTFIX}" 1>&2
        return 255
    fi

    if [ $# -lt 1 ]; then
        if shini_function_exists "__shini_no_file_passed{$POSTFIX}"; then
            "__shini_no_file_passed${POSTFIX}" "$EXTRA1" "$EXTRA2" "$EXTRA3"
        else
            printf 'shini: Argument 1 needs to specify the INI file to parse.\n' 1>&2
            return 254
        fi
    fi
    INI_FILE="$1"

    if [ ! -r "$INI_FILE" ]; then
        if shini_function_exists "__shini_file_unreadable${POSTFIX}"; then
            "__shini_file_unreadable${POSTFIX}" "$INI_FILE" "$EXTRA1" "$EXTRA2" "$EXTRA3"
        else
            # shellcheck disable=SC2016
            printf 'shini: Unable to read INI file:\n  `%s`\n' "$INI_FILE" 1>&2
            return 253
        fi
    fi

    # Iterate INI file line by line
    LINE_NUM=-1
    SECTION=''
    while read -r LINE || [ -n "$LINE" ]; do  # -n $LINE catches final line if not empty
        LINE_NUM=$((LINE_NUM+1))
        [ -z "$LINE" ] && continue

        # Check for new sections
        if shini_regex_match "$LINE" "^${RX_WS}*\[${RX_SECTION}${RX_SECTION}*\]${RX_WS}*$"; then
            SECTION="$(shini_regex_extract "$LINE" "^${RX_WS}*\[(${RX_SECTION}${RX_SECTION}*)\]${RX_WS}*$" "\1")"

            if [ "$SKIP_TO_SECTION" != '' ]; then
                # stop once specific section is finished
                [ "$SECTION_FOUND" -eq 0 ] && break;
                
                # mark the specified section as found
                [ "$SKIP_TO_SECTION" = "$SECTION" ] && SECTION_FOUND=0;
            fi

            if shini_function_exists "__shini_parsed_section${POSTFIX}"; then
                "__shini_parsed_section${POSTFIX}" "$SECTION" "$EXTRA1" "$EXTRA2" "$EXTRA3" || break
            fi
			
	        continue
        fi
        
        # Skip over sections we don't care about, if a specific section was specified
        [ "$SKIP_TO_SECTION" != '' ] && [ "$SECTION_FOUND" -ne 0 ] && LINE_NUM=$((LINE_NUM+1)) && continue;
		
        # Check for key/value lines
        if shini_regex_match "$LINE" "^${RX_WS}*(${RX_KEY}${RX_KEY}*)${RX_WS}*=${RX_WS}*((${RX_QUOTE}[^${RX_QUOTE}]*${RX_QUOTE})|([^${RX_QUOTE};]*))${RX_WS}*(;(.*))*$"; then
            # For shells supporting capturing regex ... extract the groups
            # shellcheck disable=SC3054
            if [ -n "${BASH_VERSINFO[0]}" ] && [ "${BASH_VERSINFO[0]}" -ge 3 ] || \
               [ -n "$ZSH_VERSION" ]; then
                # shellcheck disable=SC3028
                # shellcheck disable=SC3010
                {
                KEY="${BASH_REMATCH[1]}"
                COMMENT="${BASH_REMATCH[5]}"
                TMPVAL="${BASH_REMATCH[2]}"
                }

                # Trim quotes or whitespace as applicable
                TMPVAL="${TMPVAL%"${TMPVAL##*[![:space:]]}"}" # trim trailing whitespace
                TMPVAL="${TMPVAL#\"}" # strip leading quote
                TMPVAL="${TMPVAL%\"}" # strip trailing quote
                VALUE="$TMPVAL"
            else
                # Fallback-mode, using string manipulation to extract
                TMPKEY="${LINE%%=*}" # strip everything after key
                TMPKEY="${TMPKEY#"${TMPKEY%%[![:space:]]*}"}" # trim leading whitespace
                KEY="${TMPKEY%"${TMPKEY##*[![:space:]]}"}" # trim trailing whitespace

                # Extract the value and (possible) comment
                VALCOM="${LINE#*=}" # strip evrything before the value
                VALCOM="${VALCOM#"${VALCOM%%[![:space:]]*}"}" # trim leading whitespace

                # Determine if the value portion is quoted or not (POSIX-ly)
                if [ "${VALCOM#\"}" != "$VALCOM" ]; then
                    TMPVAL="${VALCOM#\"}" # strip first quote
                    VALUE="${TMPVAL%%\"*}" # strip everything after and including the second (remaining) quote
                    TMPCOM="${VALCOM#"\"${VALUE}\""}" # strip the quoted value out
                    COMMENT="${TMPCOM#*\;}" # strip everything upto (and including) earliest comment marker
                else
                    TMPVAL="${VALCOM%%\;*}" # strip everything after (and including) earliest comment marker
                    VALUE="${TMPVAL%"${TMPVAL##*[![:space:]]}"}" # trim trailing whitespace
                    COMMENT="${VALCOM#*\;}" # strip everything upto (and including) earliest comment marker
                fi
            fi

            "__shini_parsed${POSTFIX}" "$SECTION" "$KEY" "$VALUE" "$EXTRA1" "$EXTRA2" "$EXTRA3" || break
			
            if shini_function_exists "__shini_parsed_comment${POSTFIX}"; then
                if shini_regex_match "$LINE" ";"; then
                    COMMENT="$(shini_regex_extract "$LINE" "^.*\;(.*)$")"
                    "__shini_parsed_comment${POSTFIX}" "$COMMENT" "$EXTRA1" "$EXTRA2" "$EXTRA3" || break
                fi
            fi

            continue
        fi

        # Check for comment lines
        if shini_regex_match "$LINE" "^${RX_WS}*\;"; then
            if shini_function_exists "__shini_parsed_comment_line${POSTFIX}"; then
                COMMENT="${LINE#*\;}" # strip everything upto (and including) earliest comment marker
                "__shini_parsed_comment_line${POSTFIX}" "$COMMENT" "$EXTRA1" "$EXTRA2" "$EXTRA3" || break
            fi

            continue
        fi
		
        # Announce parse errors
        if ! shini_regex_match "$LINE" "^${RX_WS}*;.*$" &&
           ! shini_regex_match "$LINE" "^${RX_WS}*$"; then
            if shini_function_exists "__shini_parse_error${POSTFIX}"; then
                "__shini_parse_error${POSTFIX}" $LINE_NUM "$LINE" "$EXTRA1" "$EXTRA2" "$EXTRA3" || break
            else
                # shellcheck disable=SC2016
                printf 'shini: Unable to parse line %d:\n  `%s`\n' $LINE_NUM "$LINE" 1>&2
            fi
        fi
    done < "$INI_FILE"

    # ********
    shini_teardown

    return 0
}

# SUBSHELL FUNCTION
# @param inifile Filename of INI file to write to
# @param section Section of INI file to write to
# @param variable Variable name to add/update/delete
# @param value Value to add/update, do not specify to delete
# @param quote (Double-)quote the value being written (default: false)
shini_write()
(
    shini_setup
    # ********

    # This is not yet optimised (early write support only) - 
    # We actually re-parse the entire file, looking for the location in which to
    # write the new value, writing out everything we parse as-is meanwhile.

    # Declare the following if you want particular behaviour (like skipping
    # broken INI file content or handling an unreadable file etc).
    #  __shini_no_file_passed__writer()
    #  __shini_file_unreadable__writer()
    #  __shini_parse_error__writer()
    
    # Writer callbacks, used for writing the INI file content
    # shellcheck disable=SC2317
    __shini_parsed_section__writer()
    {
        # Validate the last section wasn't the target section
        if [ "$LAST_SECTION" = "$WRITE_SECTION" ]; then
            # If it was, and the value wasn't written already, write it
            if [ "$VALUE_WRITTEN" -eq 0 ]; then
                # shellcheck disable=SC2059
                printf "$PRINTFMT" "$WRITE_KEY" "$WRITE_VALUE" >> "$INI_FILE_TEMP"
                VALUE_WRITTEN=1
            fi
        fi

        printf "\n[%s]" "$1" >> "$INI_FILE_TEMP"
        
        LAST_SECTION="$1"
    }
    
    # shellcheck disable=SC2317
    __shini_parsed_comment__writer()
    {
        printf " ;%s" "$1" >> "$INI_FILE_TEMP"
    }

    # shellcheck disable=SC2317
    __shini_parsed_comment_line__writer()
    {
        printf "\n;%s" "$1" >> "$INI_FILE_TEMP"
    }
    
    # shellcheck disable=SC2317
    __shini_parsed__writer()
    {
        if [ "$1" = "$WRITE_SECTION" ]; then
            if [ "$2" = "$WRITE_KEY" ]; then
                if [ -n "$WRITE_VALUE" ]; then
                    # shellcheck disable=SC2059
                    printf "$PRINTFMT" "$WRITE_KEY" "$WRITE_VALUE" >> "$INI_FILE_TEMP"
                fi
                VALUE_WRITTEN=1
                return
            fi
        fi

        # shellcheck disable=SC2059
        printf "$PRINTFMT" "$2" "$3" >> "$INI_FILE_TEMP"
    }
    
    if [ $# -lt 3 ]; then
        if shini_function_exists "__shini_no_file_passed"; then
            __shini_no_file_passed
        else
            printf 'shini: Argument 1 needs to specify the INI file to write.\n' 1>&2
            return 254
        fi
    fi
    
    INI_FILE="$1"
    INI_FILE_TEMP="$(mktemp -t shini_XXXXXX)"
    
    WRITE_SECTION="$2"
    WRITE_KEY="$3"
    WRITE_VALUE="$4"
    LAST_SECTION=""
    VALUE_WRITTEN=0

    # "Quote value" mode (true/false)
    if [ -n "$5" ] && [ "$5" = true ]; then
        PRINTFMT='\n%s="%s"'
    else
        PRINTFMT='\n%s=%s'
    fi
    
    shini_parse "$INI_FILE" "_writer" "$WRITE_SECTION" "$WRITE_KEY" "$WRITE_VALUE"
    # Still not written out yet
    if [ "$VALUE_WRITTEN" -eq 0 ]; then
        # Check if final existing section was target one, add it if not
        if [ "$LAST_SECTION" != "$WRITE_SECTION" ]; then
            printf "\n[%s]" "$WRITE_SECTION" >> "$INI_FILE_TEMP"
        fi
        # Write value at end of file
        # shellcheck disable=SC2059
        printf "$PRINTFMT" "$WRITE_KEY" "$WRITE_VALUE" >> "$INI_FILE_TEMP"
    fi

    tail -n +2 "$INI_FILE_TEMP" > "$INI_FILE"
    rm -f "$INI_FILE_TEMP"
    
    # ********
    shini_teardown

    return 0
)

# SUBSHELL FUNCTION
# @param inifile Filename of INI file to read from
# @param section Section of INI file to read from (blank string if sectionless INI)
# @param key to read
shini_read()
(
    shini_setup
    # ********

    # shellcheck disable=SC2317
    __shini_parsed__key_read()
    {
        if [ "$1" = "$READ_SECTION" ]; then
            if [ "$2" = "$READ_KEY" ]; then
                printf "%s" "$3"
                FOUND=1
                return 1  # exit condition for shini_parse
            fi
        fi
    }
    
    INI_FILE="$1"
    
    READ_SECTION="$2"
    READ_KEY="$3"

    FOUND=0

    shini_parse "$INI_FILE" "_key_read" "$READ_SECTION" "$READ_KEY"

    # ********
    shini_teardown

    if [ $FOUND -eq 0 ]; then
        return 1
    else
        return 0
    fi
)
