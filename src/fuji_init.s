; FujiNet file system initialization
; Translated from MMFS mmfs100.asm lines 2943-3139

        .export cmd_fs_fuji
        .export init_fuji

        .import a_rorx4
        .import calculate_crc7
        .import osbyte_X0YFF
        .import return_with_a0
        .import print_string
        .import tube_check_if_present
        .import channel_flags_clear_bits

        .include "mos.inc"
        .include "fujinet.inc"

        .segment "CODE"

; Boot options strings
BootOptions:
        .byte   "L.!BOOT", $0D
        .byte   "!BOOT", $0D
        .byte   "E.!BOOT", $0D

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; CMD_FS_FUJI - Initialize FujiNet file system
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

cmd_fs_fuji:
        lda     #$FF

init_fuji:
        jsr     return_with_a0        ; On entry: if A=0 then boot file
        pha

.ifdef FN_DEBUG
        jsr     print_string
        .byte   "Starting FujiNet", $0D
.endif

        lda     #$06
        jsr     go_fscv               ; new filing system

        ; Copy vectors/extended vectors
        ldx     #$0D                  ; copy vectors
@vect_loop:
        lda     vectors_table,x
        sta     $0212,x
        dex
        bpl     @vect_loop

        lda     #$A8                  ; copy extended vectors
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
        lda     PagedRomSelector_RAMCopy
        sta     (aws_tmp00),y
        iny
        dex
        bne     @extendedvec_loop

        sty     CurrentCat            ; curdrvcat<>0
        sty     CurrentDrv            ; TODO: why do we set this twice?
        stx     CurrentDrv            ; curdrv=0
        stx     MMC_STATE             ; Uninitialised

        ldx     #$0F                  ; vectors claimed!
        lda     #$8F
        jsr     OSBYTE

        ; If soft break and pws "full" and not booting a disk
        ; then copy pws to sws
        ; else reset fs to defaults.

        jsr     set_private_workspace_pointer_b0
        ldy     #<ForceReset          ; D3
        lda     (aws_tmp00),y         ; A=PWSP+$D3 (-ve=soft break)
        bpl     initdfs_reset         ; Branch if power up or hard break

        ldy     #<(ForceReset+1)      ; D4
        lda     (aws_tmp00),y         ; A=PWSP+$D4
        bmi     initdfs_noreset       ; Branch if PWSP "empty"

        jsr     claim_static_workspace

.ifdef FN_DEBUG
        jsr     print_string
        .byte   "Rest. ws", $0D
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

        ; Check VID CRC and if wrong reset filing system
        jsr     calculate_crc7
        cmp     CHECK_CRC7
        bne     setdefaults

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
        .byte   "Set FN defs", $0D
.endif
        lda     #' '
        sta     $11C0
        sta     $11D0

        lda     #'$'
        sta     DEFAULT_DIR
        sta     LIB_DIR
        lda     #$00
        sta     LIB_DRIVE
        ldy     #$00
        sty     DEFAULT_DRIVE
        sty     $10C0

        dey                           ; Y=$FF
        sty     CMDEnabledIf1
        sty     FSMessagesOnIfZero
        sty     $10DD

        ; INITIALISE VID VARIABLES

        jsr     vid_reset

initdfs_noreset:
        jsr     tube_check_if_present ; Tube present?

        lda     #$FD                  ; Read hard/soft break
        jsr     osbyte_X0YFF          ; X=0=soft,1=power up,2=hard
        cpx     #$00
        beq     skip_autoload
        jsr     mmc_begin2
        jsr     fuji_cmd_autoload

skip_autoload:
        pla
        bne     initdfs_exit          ; branch if not boot file

        jsr     load_cur_drv_cat
        lda     $0F06                 ; Get boot option
        jsr     a_rorx4
        bne     not_OPT0              ; branch if not opt.0

initdfs_exit:
        rts

; Assumes cmd strings all in same page!
not_OPT0:
        ldy     #>(BootOptions)       ; boot file?
        ldx     #<(BootOptions)       ; ->L.!BOOT
        cmp     #$02
        bcc     jmp_OSCLI             ; branch if opt 1
        beq     oscli_OPT2            ; branch if opt 2
        ldy     #>(BootOptions+8)
        ldx     #<(BootOptions+8)     ; ->E.!BOOT
        bne     jmp_OSCLI             ; always
oscli_OPT2:
        ldy     #>(BootOptions+10)
        ldx     #<(BootOptions+10)    ; ->!BOOT
jmp_OSCLI:
        jmp     OSCLI

go_fscv:
        jmp     (FSCV)

set_private_workspace_pointer_b0:
        lda     #$00
        sta     aws_tmp00
        ldx     PagedRomSelector_RAMCopy
        lda     PagedROM_PrivWorkspaces, x
        and     #$3F                            ; not master. TODO: fix if we have a master
        sta     aws_tmp01
        rts

claim_static_workspace:
        ldx     #$0A
        lda     #$8F
        jsr     OSBYTE                          ; issue service request &A

        jsr     set_private_workspace_pointer_b0
        ldy     #<ForceReset
        lda     #$FF
        sta     (aws_tmp00),y                   ; Data valid in SWS
        sta     ForceReset
        iny
        sta     (aws_tmp00),y                   ; Set pws is "empty"
        rts

vid_reset:
        ldy     #(CHECK_CRC7-VID-1)
        lda     #$00
@loop:
        sta     VID,y
        dey
        bpl     @loop
        lda     #$01
        sta     CHECK_CRC7
        rts

mmc_begin2:
        ; TODO: Implement MMC begin
        rts

fuji_cmd_autoload:
        ; TODO: Implement autoload
        rts

load_cur_drv_cat:
        ; TODO: Implement load current drive catalog
        rts

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; VECTOR TABLES
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

vectors_table:
        ; TODO: Define vector table
        .res    14, $00

extendedvectors_table:
        ; TODO: Define extended vector table
        .res    56, $00
