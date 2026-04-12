# fn-rom

A bbc ROM for fujinet.

Using cc65.

It is extensively based on mmfs as an example of how to build a rom.

# What it should do minimally

- interfaces to the FN to support file system
- and network, and other devices

# Things it will do eventually

- use multiple buses (first will be rs232)
- support more than bbc (i.e. master, elk)

# Building

This will build the ROM in build/
```
make clean all
```

This will create an SSD containing the ROM
```
make clean ssd
```

# Creating SSD images from folder contents

The script [create_ssd.py](bin/create_ssd.py) can be used to make SSD images from a folder's contents.

For binary files (not having extension ".bas"), it will store them directly on the disk, and set a load/execute
address according to the parameters passed to the script. There is a limitation that all applications will share the same
load and exec address currently.

For BASIC files, it will tokenize and add line numbers as required to the source file. See below.

You need [basictool](https://github.com/ZornsLemma/basictool) and [dfstool](https://github.com/rcook/dfstool) installed locally.

An example to create the "net" example basic files into "net.ssd" is:

```bash
bin/create_ssd.py -i bas/net -o net.ssd
```

See the help for the script with `bin/create_ssd.py -h`

## Converting BAS files

Basic files do not need line numbers, the basictool can deal with that automatically.
If you need GOTO statements, then the target line will need a line number, and basictool will automatically
adjust other line numbers around that point.

One convention used by the script is that if the first line of the program is of the format:
```
REM filename: foo
```
then the file will be stored on the disk as "FOO", instead of the name of the source file.
This allows you to have normal file names on a modern system but tokenize them to a short name for the SSD image.
