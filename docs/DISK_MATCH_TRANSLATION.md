# Disk Matching Functions - MMFS Translation

## Overview

The disk matching functions have been faithfully translated from MMFS to work with FujiNet's architecture. These functions enable the `*FIN` command to find disk images by name (e.g., `*FIN REVS`).

## Translated Functions

### d_match_init (MMFS line 8100: DMatchInit)

**Purpose**: Parses and initializes the search string from the command line.

**Translation Details**:
- Reads characters from text pointer using `GSINIT` and `GSREAD`
- Converts lowercase to uppercase using EOR #$20
- Stores up to 12 characters in `dm_str`
- Handles wildcard '*' character
- Sets `dm_ambig` flag if wildcard found
- Null-terminates string and stores length in `dm_len`

**Key MMFS Lines Translated**: 8100-8153

### get_disk_first_all_x (MMFS line 7826: GetDiskFirstAllX)

**Purpose**: Initialize disk iteration and find first disk.

**Translation Details**:
- Calls `fuji_get_disk_list_data` to refresh disk list
- Initializes `gd_diskno` to 0
- Falls through to `gd_first` to validate disk

**Key MMFS Lines Translated**: 7826-7837

### get_disk_next (MMFS line 7868: GetDiskNext)

**Purpose**: Advance to next disk in sequence.

**Translation Details**:
- Increments `gd_diskno` (16-bit)
- Falls through to `gd_first` to validate
- In MMFS, this also handles page boundaries and sector changes

**Key MMFS Lines Translated**: 7868-7910

### gd_first (MMFS line 7915: gdfirst)

**Purpose**: Validate current disk number and check if formatted.

**Translation Details**:
- Calls `fuji_check_disk_exists` to see if disk is valid
- Gets disk name using `fuji_get_disk_name_data`
- Returns C=0 if valid, C=1 if no more disks
- Sets `gd_diskno` to $FFFF when exhausted

**Key MMFS Lines Translated**: 7915-7926

### d_match (MMFS line 8158: DMatch)

**Purpose**: Compare disk name against search pattern.

**Translation Details**:
- Gets disk name into buffer via `fuji_get_disk_name_data`
- Compares character-by-character with uppercase conversion
- Handles exact matches and wildcard matches
- Returns C=0 for match, C=1 for no match

**Key MMFS Lines Translated**: 8158-8194

## Workspace Variables

Matching MMFS workspace layout:

| Variable | Address | MMFS Equivalent | Purpose |
|----------|---------|-----------------|---------|
| `dm_str` | `fuji_filename_buffer + $10` | `dmStr%` | Search string (12 chars max) |
| `dm_len` | `fuji_filename_buffer + $0D` | `dmLen%` | Search string length |
| `dm_ambig` | `fuji_filename_buffer + $0E` | `dmAmbig%` | Wildcard flag (0 or '*') |
| `gd_diskno` | `aws_tmp08/09` | `gddiskno%` | Current disk number (16-bit) |
| `gd_ptr` | `aws_tmp12/13` | `gdptr%` | Pointer to disk name |

## Hardware Layer Adaptations

Since FujiNet doesn't read from MMC sectors like MMFS, these hardware functions were implemented:

### fuji_get_disk_list_data
- **MMFS equivalent**: Reads disk table from MMC
- **Dummy version**: No-op (static disk list)
- **Serial version**: Would query FujiNet device

### fuji_check_disk_exists
- **Purpose**: Check if disk number is valid
- **Dummy version**: Compares against `NUM_DUMMY_DISKS`
- **Serial version**: Would check with FujiNet device

### fuji_get_disk_name_data
- **Purpose**: Get disk name for matching
- **Dummy version**: Looks up from static name table
- **Serial version**: Would query FujiNet device
- **Sets**: `gd_ptr` to point to name in `fuji_filename_buffer`

## Differences from MMFS

1. **Sector/Memory Management**: MMFS reads directly from MMC sectors; FujiNet queries via hardware layer
2. **Disk Count**: MMFS has NUM_CHUNKS sectors; FujiNet has simpler disk numbering
3. **Formatted Check**: MMFS checks byte 15 from disk table; FujiNet assumes all disks formatted (for now)
4. **CheckESCAPE**: Not implemented in initial translation (MMFS line 7869)

## Usage in *FIN Command

The command flow is:
1. `cmd_fs_fin` calls `param_drive_and_disk`
2. `param_drive_and_disk` calls `d_match_init` to parse disk name
3. Calls `get_disk_first_all_x` to start iteration
4. In loop: calls `d_match` to check each disk
5. If no match, calls `get_disk_next` and continues
6. When match found, returns disk number in `aws_tmp08/09`
7. `load_drive` then mounts that disk

## Testing

With the dummy interface:
- Two disks available: "TESTDISK0" (disk 0) and "TESTDISK1" (disk 1)
- `*FIN 0 TESTDISK0` should mount disk 0 into drive 0
- `*FIN TESTDISK1` should mount disk 1 into current drive
- `*FIN TEST*` should match first disk (wildcard)

## Future Enhancements

1. Add CheckESCAPE support for long disk scans
2. Implement formatted/unformatted disk filtering
3. Support .SSD/.DSD extension matching like MMFS
4. Optimize serial version with caching

