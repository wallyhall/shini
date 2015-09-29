# shini - portable INI library for sh (with extras for bash)
#
# This code is released freely under the MIT license - see the shipped LICENSE document.
# For the latest version etc, please see https://github.com/wallyhall/shini
#

shini_function_exists()
{
	type "$1" > /dev/null
	return $?
}

# @param inifile Filename of INI file to parse
shini_parse()
{

	RX_KEY='[a-zA-Z0-9_\-]'
	RX_VALUE="[^;\"]"
	RX_SECTION='[a-zA-Z0-9_\-]'
	RX_WS='[ 	]'
	RX_QUOTE='"'
	RX_HEX='[0-9A-F]'

	if ! shini_function_exists "__shini_parsed"; then
		printf 'shini: __shini_parsed function not declared.\n' 1>&2
		exit 255
	fi

	if [ $# -lt 1 ]; then
		if shini_function_exists "__shini_no_file_passed"; then
			__shini_no_file_passed
		else
			printf 'shini: Argument 1 needs to specify the INI file to parse.\n' 1>&2
			exit 254
		fi
	fi
	INI_FILE="$1"

	if [ ! -r "$INI_FILE" ]; then
		if shini_function_exists "__shini_file_unreadable"; then
			__shini_file_unreadable "$INI_FILE"
		else
			printf 'shini: Unable to read INI file:\n  `%s`' "$INI_FILE" §>&2
			exit 253
		fi
	fi

	# Iterate INI file line by line
	LINE_NUM=0
	SECTION=''
	while read LINE; do
		# Check for new sections
		if printf '%s' "$LINE" | \
		  grep -qe "^${RX_WS}*\[${RX_SECTION}${RX_SECTION}*\]${RX_WS}*$"; then
			SECTION="$(printf '%s' "$LINE" | \
				sed "s/^${RX_WS}*\[\(${RX_SECTION}${RX_SECTION}*\)\]${RX_WS}*$/\1/")"
			continue
		fi
		
		# Check for new values
		if printf '%s' "$LINE" | \
		  grep -qe "^${RX_WS}*${RX_KEY}${RX_KEY}*${RX_WS}*="; then
			KEY="$(printf '%s' "$LINE" | \
				sed "s/^${RX_WS}*\(${RX_KEY}${RX_KEY}*\)${RX_WS}*=.*$/\1/")"
			VALUE="$(printf '%s' "$LINE" | \
				sed "s/^${RX_WS}*${RX_KEY}${RX_KEY}*${RX_WS}*=${RX_WS}*${RX_QUOTE}\{0,1\}\(${RX_VALUE}*\)${RX_QUOTE}\{0,1\}\(${RX_WS}*\;.*\)*$/\1/")"
				if printf '%s' "$VALUE" | grep -qe "^0x${RX_HEX}${RX_HEX}*$"; then
					VALUE=$(printf '%d' "$VALUE")
				fi
				__shini_parsed "$SECTION" "$KEY" "$VALUE"
			continue
		fi
		
		# Announce parse errors
		if [ "$LINE" != '' ] &&
		  ! printf '%s' "$LINE" | grep -qe "^${RX_WS}*;.*$" &&
		  ! printf '%s' "$LINE" | grep -qe "^${RX_WS}*$"; then
			if shini_function_exists "__shini_parse_error"; then
				__shini_parse_error $LINE_NUM "$LINE"
			else
				printf 'shini: Unable to parse line %d:\n  `%s`\n' $LINE_NUM "$LINE"
			fi
		fi
		
		LINE_NUM=$((LINE_NUM+1))
	done < "$INI_FILE"

}
