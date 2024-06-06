# fn-rom - FujiNet Beeb Sideways ROM project

This is the src code for the FujiNet Beeb/Elk Sideways ROM for the FujiNet adapter.

It is very early stages, as there is no hardware setup yet for the FujiNet with the BBC.

For more information on Fujinet, see [FujiNet Online](https://fujinet.online/)

This code base owes everything to the [MMFS source code](https://github.com/hoglet67/MMFS/).
I have used it as the basis for this ROM, copying large sections of it to get going.

Building and Running in an emulator notes are below. This assumes a working setup with:

- Msys2 shell
- `beebem` emulator installed at `/c/Program Files (x86)/BeebEm/BeebEm.exe` (configurable with BEEBEM env var)
- `beeb` perl scripts on path from MMFS_Utils
- `beebasm` on the path, compiled from source, or otherwise.

## building

The ROMs for Beeb, Master and Electron can be built with

```shell
./build.sh -b
```

To enable debug output in the ROM, include the `-d` flag

```shell
./build.sh -bd
```

## running in emulator

Currently, beebem is a simple target for the ROM, and the build script targets loading the ROM into it with:

```shell
./build.sh -e
```

At the moment there is no connection to a virtual FujiNet-PC instance, but this is planned. For now, ROM commands are simple and won't do much.

## build and run emulator

Any and all of the above arguments can be combined, so:

```shell
./build.sh -bde
```
