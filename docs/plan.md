Read @/docs/context_bootstrap.md to understand the fujinet-nio project.
Our plan in this task is to update the fn-rom project to be compatible with the fujinet-nio fujibus transport.

fn-rom is a project to create a bbc 8 bit ROM that can be burned onto eeprom and placed in the bbc micro (or loaded into the emulator) to act as a bridge between the bbc micro, and the fujinet-nio device for network based disk images.

The fujinet may be running and listening on pty port for posix on a linux machine, or running on an esp32s3 connected to the PC so the emulator talks to either a linux process, or an esp32 directly connected to the host 8 bit machine. Ultimately the fujinet is either software based (pty), or hardware connected to ttyUSB0 for a PC to connect to and a host emulator, or it's "production" mode connected between an 8 bit bbc micro, an rs232 based fujinet.

Either way, the fn-rom project connects the 2 sides together to allow network commands that allow disk drive behaviour over a network using files for the images instead of physical floppy disks.
That is where fn-rom will end for functionality, i.e. purely for disk interaction via fujinet - it is similar to the MMFS project allowing SD cards containing disk images to be connected to a BBC and act as disks to the BBC's OS. In fact fn-rom is based on MMFS from a code point of view, it sets up the "*" commands that a BBC uses for interacting with ROMs to be able to list files, boot disks, read files, execute files etc.

The fn-rom project has an architecture described in @/../../bbc/fn-rom/docs/ARCHITECTURE.md 

We need to update the fn-rom from using the legacy transport for communicating with the legacy fujinet-firmware to instead using fujibus protocol for the fujinet-nio rewrite of fujinet-firmware.
The legacy firmware used a simple 6 byte command frame to send data, we have fujibus and SLIP as detailed in the transport section of the @/docs/architecture.md for fujinet-nio.

We have a python client that is able to send requests to the fujinet-nio at @/py/fujinet_tools/fujibus.py for linux to be able to run python programs that make valid fujibus requests, and we also have a fujinet-nio-lib implementation of fujibus written in C for client applications to communicate with the fujinet-nio at @/../fujinet-nio-lib/src/common/fn_packet.c  and @/../fujinet-nio-lib/src/common/fn_slip.c for framing.

We need to use these existing example implementations and turn them into 6502 ASM versions so that @/../../bbc/fn-rom/src/fuji_serial.s can bridge the gap betwen command handling and fujinet-nio commands to fetch information.

Some of the things that the fn-rom does (getting host urls and hosts) are not supported in fujinet-nio yet, so we will need to evaluate how to implement those in the fujinet-nio firmware, then we want to create a bridge to the disk interface so that we can start exposing SSD and DSD image files as disks to the bbc, and implement the functions:
- fuji_read_block_data
- fuji_write_block_data
- fuji_read_catalog_data
- fuji_write_catalog_data
- fuji_read_disc_title_data
- fuji_mount_disk_data

There is already disk support in fujinet-nio, see @/src/lib/disk/ssd_image.cpp 

Write a plan we can execute to:
- Update the fn-rom project to support fujibus (this does not have to live in fuji_serial.s directly) in 6502 BBC ASM (there is a ton of code already in fn-rom for that pattern)
- Implement the disk commands listed previously to allow true disk from ssd image files
- Figure out how we will handle "hosts" in fujinet-nio which are a fujinet-firmware concept of a list of network hostnames that disks can be mounted from across a network. We started this work briefly with a HostType and HostConfig enum and struct defined in @/include/fujinet/config/fuji_config.h along with the MountConfig so that we can "mount" images of disks from hosts for the fujinet-nio to expose, but this is only exposed and tested for saving to the persisted config file (e.g. @/tests/test_fuji_config_yaml.cpp )

This will elevate our fn-rom to being able to communicate with fujinet-nio, and use it to supply disk images for mounting, booting from, reading and writing from/to. Fujinet-nio already supports SSD images in its disk architecture, let's plan a way to interface the BBC ROM for file system commands with it.

