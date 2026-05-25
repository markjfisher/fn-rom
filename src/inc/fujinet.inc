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

        ;.include "os.inc"
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
; data_ptr = aws_tmp08


; OS constants
filesysno               = $04
filehndl                = $10

; same as MMFS tube code. will this be an issue?
tube_id                 = $0A


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

; Disk mount flags / response flags
DISK_MOUNT_FLAG_READONLY      = $01
DISK_MOUNT_RESP_FLAG_MOUNTED  = $01
DISK_MOUNT_RESP_FLAG_READONLY = $02

; File Commands
FILE_CMD_STAT          = $01
FILE_CMD_LIST_DIRECTORY = $02
FILE_CMD_READ_FILE     = $03
FILE_CMD_WRITE_FILE    = $04
FILE_CMD_RESOLVE_PATH  = $05

; Network Commands (device 0xFD)
NET_CMD_OPEN       = $01
NET_CMD_READ       = $02
NET_CMD_WRITE      = $03
NET_CMD_CLOSE      = $04
NET_CMD_INFO       = $05
NET_CMD_INFO_READ  = $06
NET_CMD_TRANSLATE_CONFIGURE = $07

; Host-side NotReady retry policy (fn-rom; configurable later)
NET_RETRY_MAX         = 24    ; max attempts per operation
NET_RETRY_DELAY_INIT  = 5     ; initial wait: 5 VSyncs (~100ms at 50Hz)
NET_RETRY_DELAY_MAX   = 125   ; cap wait at 125 VSyncs (~2.5s at 50Hz)

NET_OPEN_EXT_TRANSLATION = $00000001

; Network open method flags (used by the FujiNet device for HTTP semantics)
NET_METHOD_GET     = $01
NET_METHOD_POST    = $02
NET_METHOD_PUT     = $03
NET_METHOD_DELETE  = $04
NET_METHOD_HEAD    = $05

; Network open flags
NET_FLAG_BODY_UNKNOWN = $04
NET_FLAG_ALLOW_EVICT = $08

; Network open response flags
NET_OPEN_FLAG_ACCEPTED = $01

; Network read response flags
NET_READ_FLAG_EOF   = $01

; Network protocol byte offsets within full response buffer
; FujiBus wire: [0]=dev [1]=cmd [2,3]=len [4]=chk [5]=desc [6]=status [7+]=protocol payload
NET_PAYLOAD_OFFSET        = 7

; Shared response header offsets (protocol payload relative)
NET_RESP_VERSION          = NET_PAYLOAD_OFFSET + 0   ; 7: 1 byte
NET_RESP_FLAGS            = NET_PAYLOAD_OFFSET + 1   ; 8: 1 byte
NET_RESP_RESERVED         = NET_PAYLOAD_OFFSET + 2   ; 9: 2 bytes
NET_RESP_HANDLE           = NET_PAYLOAD_OFFSET + 4   ; 11: 2 bytes u16le
NET_RESP_OFFSET_ECHO      = NET_PAYLOAD_OFFSET + 6   ; 13: 4 bytes u32le
NET_RESP_DATALEN          = NET_PAYLOAD_OFFSET + 10  ; 17: 2 bytes u16le
NET_RESP_DATA             = NET_PAYLOAD_OFFSET + 12  ; 19: variable

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
; Private workspace (PWS) layout for FujiBus: packet buffer at PWS+0.
; Plan: first 256 bytes were reserved for the packet slice; remaining PWS for strings.
; Disk read decodes 274 bytes (7+11 + 256-byte sector)
; at PWS+0 until responses are streamed or split.
FUJI_PWS_PACKET_OFFSET = 0
FUJI_PWS_PACKET_SIZE = 274
FUJI_PWS_PERM_FLAGS_SIZE = 6
FUJI_FS_URI_BUFFER_SIZE = 80
FUJI_HOST_URI_BUFFER_SIZE = 80
FUJI_JSON_PATH_BUFFER_SIZE = 72
FUJI_EXT_STR_MAX_LEN = 512

; fuji_ext_str_flags bits
FUJI_EXT_STR_ACTIVE = $01
FUJI_EXT_STR_IS_URL = $02
FUJI_EXT_STR_IS_JSON = $04

; FujiNet OSWORD/CALL API (see docs/fnnet-api.md)
; Must be < &80 so MOS offers it via service call 8 (&EF/&F0/&F1).
; &E0+ routes via USERV (&0200), not service 8.
FNNET_OSWORD = $78
FNNET_API_VERSION = $01
FNNET_REASON_VERSION = $00
FNNET_REASON_JSON_QUERY = $01
FNNET_REASON_STASH_JSON = $02
FNNET_REASON_OPEN_URL = $03
FNNET_REASON_SET_BODY_LEN = $04
FNNET_REASON_WRITE_DATA = $05

; fnnet status codes returned in parameter block +0/+1
FNNET_STATUS_OK = $00
FNNET_STATUS_BAD_CALL = $01
FNNET_STATUS_JSON_QUERY_FAILED = $02
FNNET_STATUS_BAD_CHANNEL = $03

; PWS layout after packet: 
; [+274] 6 byte flags area, fuji_force_reset and fuji_own_sws_indicator use 2
; [+280] working FS URI scratch buffer used for FileDevice requests such as *FIN and *FLS packet assembly
; [+360] canonical current URI used by *FHOST/*FCD/*FLS as the source of truth for the current location.
FUJI_PWS_PERM_FLAGS_OFFSET = FUJI_PWS_PACKET_OFFSET + FUJI_PWS_PACKET_SIZE
FUJI_FS_URI_OFFSET = FUJI_PWS_PERM_FLAGS_OFFSET + FUJI_PWS_PERM_FLAGS_SIZE
FUJI_HOST_URI_OFFSET = FUJI_FS_URI_OFFSET + FUJI_FS_URI_BUFFER_SIZE
; 512-byte PWS leaves 72 bytes after packet + FS URI + host URI.
; Reserve the remainder for transient JSON query strings used by *FJSON.
FUJI_JSON_PATH_OFFSET = FUJI_HOST_URI_OFFSET + FUJI_HOST_URI_BUFFER_SIZE
FN_MAX_PACKET_SIZE = FUJI_PWS_PACKET_SIZE

FN_PROTOCOL_VERSION = $01

.endif
