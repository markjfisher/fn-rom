# fn-rom

A bbc ROM for fujinet.

Using cc65.

No cc65 conventions can be used, as this needs to be kept pure rom.
It is somewhat based on mmfs as an example of how to build a rom.

# What it should do minimally

- interfaces to the FN to support file system
- and network, and other devices

# Things it will do eventually

- use multiple buses (first will be rs232)
- support more than bbc (i.e. master, elk)
