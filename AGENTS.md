# fn-rom agent instructions

## Project Context

This repository contains a BBC Micro ROM implementation for Fujinet connectivity called 'fn-rom'. It's based on MMFS (Multi-Mode File System) and provides enhanced file system functionality for BBC Micro computers, enabling them to access files stored on network-connected storage systems through the Fujinet protocol.

Key features include:
- Standard BBC MOS (Monitor Operating System) compatibility
- File system operations via Fujinet protocol
- Network connectivity support
- Multiple bus interface support (serial, userport, 1MHz)
- *CAT command for directory listing
- Standard BBC OS routines like OSFILE, OSCLI, OSFIND, etc.
- SSD image creation capabilities

## Deeper information about project

Read [fn-rom-bootstrap.md](docs/fn-rom-bootstrap.md) for more context about transport/architecture layers in the project.
