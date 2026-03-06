; FujiNet ROM definitions and constants

        .import cmd_table_fujifs
        .import cmd_table_futils
        .import cmd_table_utils
        .import cmd_table_help
        .import cmd_table_fs
        .import cmd_table_END

        .import cmd_table_fujifs_cmds
        .import cmd_table_futils_cmds
        .import cmd_table_utils_cmds
        .import cmd_table_help_cmds
        .import cmd_table_fs_cmds

.ifndef FUJINET_INC
FUJINET_INC = 1

        .include "os.inc"
        .include "macros.inc"


; command table lengths (number of functions)
; used to print appropriate help table ()

; OLD: cmdtab1size
cmdtab_fujifs_cmds_size = <((cmd_table_utils_cmds - cmd_table_fujifs_cmds) / 2 - 1)
; OLD: cmdtab2size
cmdtab_utils_cmds_size  = <((cmd_table_fs_cmds - cmd_table_utils_cmds) / 2 - 1)
; OLD: cmdtab22size - not used, but needed for sizes
cmdtab_fs_cmds_size     = <((cmd_table_help_cmds - cmd_table_fs_cmds) / 2 - 1)
; OLD: cmdtab3size
cmdtab_help_cmds_size   = <((cmd_table_futils_cmds - cmd_table_help_cmds) / 2 - 1)
; OLD: cmdtab4size
cmdtab_futils_cmds_size = <((cmd_table_END - cmd_table_futils_cmds) / 2 - 1)


; offsets from cmd_table_fujifs
; used to detect the input commands
cmdtab_offset_fujifs    = 0

; OLD: cmdtab2 (14)
cmdtab_offset_utils     = <(cmd_table_utils - cmd_table_fujifs)
; OLD: cmdtab22 (2F)
cmdtab_offset_fs        = <(cmd_table_fs - cmd_table_fujifs)
; OLD: cmdtab3 (1B)
cmdtab_offset_help      = <(cmd_table_help - cmd_table_fujifs)
; OLD: cmdtab4 (0D)
cmdtab_offset_futils    = <(cmd_table_futils - cmd_table_fujifs)

; Shared data pointer for all FujiNet interface implementations
; This provides a consistent interface across all implementations
data_ptr = aws_tmp08


; OS constants
filesysno               = $04
filehndl                = $10


; ============================================================================
; FujiBus Protocol Constants
; ============================================================================

; SLIP protocol bytes
SLIP_END       = $C0
SLIP_ESCAPE    = $DB
SLIP_ESC_END   = $DC
SLIP_ESC_ESC   = $DD

; Wire Device IDs
FN_DEVICE_FUJI     = $70
FN_DEVICE_DISK     = $FC
FN_DEVICE_NETWORK  = $FD
FN_DEVICE_FILE     = $FE
FN_DEVICE_HOST     = $F0     ; New HostDevice

; Disk Commands
DISK_CMD_MOUNT       = $01
DISK_CMD_UNMOUNT     = $02
DISK_CMD_READ_SECTOR = $03
DISK_CMD_WRITE_SECTOR = $04
DISK_CMD_INFO        = $05
DISK_CMD_CLEAR_CHANGED = $06
DISK_CMD_CREATE      = $07

; File Commands
FILE_CMD_STAT          = $01
FILE_CMD_LIST_DIRECTORY = $02
FILE_CMD_READ_FILE     = $03
FILE_CMD_WRITE_FILE    = $04
FILE_CMD_RESOLVE_PATH  = $05

; Fuji Commands
FUJI_CMD_GET_MOUNTS = $FD
FUJI_CMD_SET_MOUNT  = $FC
FUJI_CMD_GET_MOUNT  = $FB

; Host Commands
HOST_CMD_LIST_HOSTS  = $01
HOST_CMD_GET_HOST    = $02
HOST_CMD_ADD_HOST    = $03
HOST_CMD_UPDATE_HOST = $04
HOST_CMD_REMOVE_HOST = $05
HOST_CMD_LIST_MOUNTS = $10
HOST_CMD_GET_MOUNT   = $11
HOST_CMD_ADD_MOUNT   = $12
HOST_CMD_UPDATE_MOUNT = $13
HOST_CMD_REMOVE_MOUNT = $14

; Protocol constants
FN_HEADER_SIZE = 6
FN_PARAMS_OFFSET = 4
FN_MAX_PACKET_SIZE = 320   ; Sufficient for disk operations (256 byte sector + overhead)
FN_PROTOCOL_VERSION = $01

.endif
