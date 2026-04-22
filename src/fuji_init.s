; FujiNet file system initialization
; Translated from MMFS mmfs100.asm lines 2943-3139

        .export init_fuji
        .export set_private_workspace_pointer_b0
        .export boot_options
        .export init_csp
        .export autoboot
        .export cmd_fs_disc
        .export cmd_fs_fuji

        ; for debugging and tracing
        .export not_opt0
        .export initdfs_noreset
        .export setdefaults
        .export go_fscv
        .export initdfs_exit

        .import a_rorx4
        .import channel_flags_clear_bits
        .import extendedvectors_table
        .import load_cur_drv_cat
        .import osbyte_X0YFF
        .import print_string
        .import return_with_a0
        .import tube_check_if_present
        .import vectors_table

        .import    set_fuji_fs_uri_ptr
        .import    get_fuji_host_uri_addr_to_aws_tmp6

        .import    fuji_current_fs_len
        .import    fuji_current_host_len

        .importzp  aws_tmp06
        .importzp  buffer_ptr

        .import __WORKSP_START__
        .import __WORKSP_SIZE__
        .importzp c_sp

.ifdef FUJINET_INTERFACE_DUMMY
        .import fuji_init_ram_filesystem
.endif

        .include "fujinet.inc"

        .segment "RO_EARLY"

; Boot options strings, force them into first page of ROM so they are together.
; Using a custom segment to not mix with the standard CA65 RODATA
boot_options:
        .byte   "L.!BOOT", $0D  ; needs to be exactly 8 bytes
        ; .byte   "!BOOT", $0D  ; this is just a substring of E.!BOOT so no need to reproduce it
        .byte   "E.!BOOT", $0D  ; must start with only 2 chars before the !BOOT for the offsets to work

.assert >boot_options = >(boot_options + 8), lderror, "boot_options crosses a page"
.assert >boot_options = >(boot_options + 10), lderror, "boot_options crosses a page"

        .segment "CODE"

init_csp:
        ; TODO: this should be driven from the PWS locations
        ; TODO: ... or completely removed when we stop using C functions via cc65
        lda     #<(__WORKSP_START__ + __WORKSP_SIZE__)
        sta     c_sp
        lda     #>(__WORKSP_START__ + __WORKSP_SIZE__)
        sta     c_sp+1
        rts

autoboot:
        lda     aws_tmp03               ; the stored value of Y when service 03 was called
        jsr     print_string
        ; This will need to be made to react to the type of build
        .byte   "Model B - FujiNet", $0D, $0D, 0

        bcc     init_fuji

cmd_fs_disc:
        dbg_string_axy "CMD_FS_DISC: "

        ; Following MMFS CMD_DISC pattern (lines 2928-2941)
        ; Check bit 6 of PagedROM_PrivWorkspaces to see if DISC/DISK should pass to DFS

        ldx     paged_ram_copy          ; Get current ROM number
        lda     paged_rom_priv_ws,x     ; Get private workspace flags  
        and     #$40                    ; Test bit 6 (OPT 5 flag)
        beq     cmd_fs_fuji             ; If bit 6 clear, act like *FUJI (activate FujiNet)
        rts

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; CMD_FS_FUJI - Handle *FUJI command (filing system selection)
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

cmd_fs_fuji:
        dbg_string_axy "CMD_FS_FUJI: "

        ; Initialize FujiNet filing system (following MMFS CMD_CARD pattern)
        lda     #$FF                    ; Set A=$FF to indicate not a boot file

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; INIT_FUJI - Initialize FujiNet file system
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

init_fuji:
        jsr     return_with_a0        ; On entry: if A=0 then boot file
        pha

        ; initialise c_sp for cc65 to the end of WORKSP segment, this resets CC65 stack
        jsr     init_csp

        ; Register as new Filing System
        lda     #$06
        jsr     go_fscv

        ; Copy vectors/extended vectors
        ldx     #$0D
@vect_loop:
        lda     vectors_table,x
        sta     $0212,x                 ; $212 to $21F = FILEV, ARGSV, BGETV, BPUTV, GBPBV, FINDF, FSCV
        dex
        bpl     @vect_loop

        lda     #$A8                  ; Read address of ROM pointer table (0D9F for OS 1.2)
        jsr     osbyte_X0YFF
        sty     aws_tmp01
        stx     aws_tmp00

        ldx     #$07
        ldy     #$1B
@extendedvec_loop:
        lda     extendedvectors_table-$1B,y
        sta     (aws_tmp00),y
        iny
        lda     extendedvectors_table-$1B,y
        sta     (aws_tmp00),y
        iny
        lda     paged_ram_copy
        sta     (aws_tmp00),y
        iny
        dex
        bne     @extendedvec_loop

        ; The fix for getting the simple LOAD/RUN working was not setting this to FF, but instead not using E00 as a buffer for fetching data
        sty     current_cat             ; set to "0" in ascii
        ; sty     current_cat+1           ; this has the comment "?" in MMFS src... who knows why? Can't see this being used, removing it

        ; FS URI / DIR path buffers (PWS) and their lengths (SWS) are not cleared here:
        ; on soft break the MOS keeps private workspace, so host/path state should survive.
        ; Cold reset clears them in setdefaults (see initdfs_reset).

        stx     current_drv             ; curdrv=0
        ; stx     current_host            ; set host to 0

        ldx     #$0F                    ; vectors claimed!
        lda     #$8F                    ; Issue Paged ROM Service Request
        jsr     OSBYTE

        ; If soft break and pws "full" and not booting a disk
        ; then copy pws to sws
        ; else reset fs to defaults.

        jsr     set_private_workspace_pointer_b0

        ldy     #<fuji_force_reset
        lda     (aws_tmp00),y         ; A=PWSP + offset (-ve=soft break)

        bpl     initdfs_reset         ; Branch if power up or hard break

        ldy     #<fuji_own_sws_indicator
        lda     (aws_tmp00),y         ; A=PWSP indicator location

        bmi     initdfs_noreset       ; Branch if PWSP "empty"

        jsr     claim_static_workspace

.ifdef FN_DEBUG
        jsr     print_string
        .byte   "Rest. ws", $0D
        nop
.endif

        ldy     #$00                  ; ** Restore copy of data
@copyfromPWStoSWS_loop:
        lda     (aws_tmp00),y         ; from private wsp
        cpy     #$C0                  ; to static wsp
        bcc     @copyfromPWS1
        sta     $1000,y
        bcs     @copyfromPWS2
@copyfromPWS1:
        sta     $1100,y
@copyfromPWS2:
        dey
        bne     @copyfromPWStoSWS_loop

        ; beq     setdefaults

        ; TODO: does this have a place in FN?

        ; jsr     calculate_crc7
        ; cmp     CHECK_CRC7
        ; bne     setdefaults

        lda     #$A0                  ; Refresh channel block info
@setchans_loop:
        tay
        pha
        lda     #$3F
        jsr     channel_flags_clear_bits  ; Clear bits 7 & 6, C=0
        pla
        sta     $111D,y               ; Buffer sector hi?
        sbc     #$1F                  ; A=A-$1F-(1-C)=A-$20
        bne     @setchans_loop
        beq     initdfs_noreset       ; always

; Initialise SWS (Static Workspace)
initdfs_reset:
        jsr     claim_static_workspace

; Set to defaults
setdefaults:
.ifdef FN_DEBUG
        jsr     print_string
        .byte   "defs", $0D
.endif
        lda     #'$'
        sta     fuji_default_dir
        sta     fuji_lib_dir
        lda     #$00
        sta     fuji_lib_drive
        ldy     #$00
        sty     fuji_default_drive
        sty     fuji_open_channels

        dey                           ; Y=$FF
        sty     fuji_cmd_enabled
        sty     fuji_fs_messages_on
        sty     fuji_error_flag

        ; Initialize RAM filesystem for file creation/writing
.ifdef FUJINET_INTERFACE_DUMMY
        jsr     fuji_init_ram_filesystem
.endif
        
        ; Initialize drive-to-disk mapping (all unmounted)
        lda     #$FF                    ; $FF = no disk mounted
        sta     fuji_drive_disk_map+0   ; Drive 0
        sta     fuji_drive_disk_map+1   ; Drive 1
        sta     fuji_drive_disk_map+2   ; Drive 2
        sta     fuji_drive_disk_map+3   ; Drive 3

        ; Power-on / hard break only: empty FS + host URI in PWS; zero lengths in SWS
        jsr     set_fuji_fs_uri_ptr
        lda     #$00
        tay
        sta     (buffer_ptr),y
        jsr     get_fuji_host_uri_addr_to_aws_tmp6
        sta     (aws_tmp06),y
        ldx     #$00
        stx     fuji_current_fs_len
        stx     fuji_current_dir_len
        stx     fuji_current_host_len

; TODO: REVIEW THIS CODE

initdfs_noreset:
        jsr     tube_check_if_present   ; Tube present?

        lda     #$FD                    ; Read hard/soft break value
        jsr     osbyte_X0YFF            ; X=0 soft break, X=1 power up reset, X=2 hard break
        cpx     #$00
        beq     skip_autoload

        ; TODO: if we want to autoboot a "BOOT.SSD" file, then we would implement it here.
        ; jsr     fuji_load_boot_disk

skip_autoload:
        pla                             ; reload A from the very start of file
        bne     initdfs_exit            ; branch if not boot file

        jsr     load_cur_drv_cat
        lda     dfs_cat_boot_option     ; Get boot option
        jsr     a_rorx4
        bne     not_opt0                ; branch if not opt.0

initdfs_exit:
        rts

not_opt0:
        ldy     #>(boot_options)        ; boot file? the high byte is same for all the strings by design, so only have to adjust X
        ldx     #<(boot_options)        ; ->L.!BOOT
        cmp     #$02
        bcc     @jmp_oscli              ; branch if opt 1
        beq     @oscli_opt2             ; branch if opt 2

        ldx     #<(boot_options+8)      ; ->E.!BOOT
        bne     @jmp_oscli              ; always
@oscli_opt2:
        ldx     #<(boot_options+10)     ; ->!BOOT
@jmp_oscli:
        jmp     OSCLI

go_fscv:
        jmp     (FSCV)

set_private_workspace_pointer_b0:
        lda     #$00
        sta     aws_tmp00
        ldx     paged_ram_copy
        lda     paged_rom_priv_ws, x
        and     #$3F                            ; not master. TODO: fix when we do multiple machine types
        sta     aws_tmp01
        rts

claim_static_workspace:
        ldx     #$0A
        lda     #$8F
        jsr     OSBYTE                          ; issue service request &A

        jsr     set_private_workspace_pointer_b0
        ldy     #<fuji_force_reset
        lda     #$FF
        sta     (aws_tmp00),y                   ; Data valid in SWS
        sta     fuji_force_reset
        iny
        sta     (aws_tmp00),y                   ; Set pws is "empty"
        rts


; fuji_load_boot_disk:
;         ; TODO: Implement autoload of BOOT.{SSD,DSD} into drive 0 at boot
;         ; Do we want this behaviour?
;         rts

