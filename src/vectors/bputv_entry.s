; BPUTV_ENTRY - Byte Put Vector
; Handles BPUT calls for writing single bytes to files
; Translated from MMFS mmfs100.asm lines 5274-5303

        .export bputv_entry

        .import channel_get_cat_entry_yintch
        .import channel_set_dir_drive_yintch
        .import check_channel_yhndl_exyintch
        .import cmp_ptr_ext
        .import print_axy
        .import print_string
        .import remember_axy

        .include "fujinet.inc"

        .segment "CODE"

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; BPUTV_ENTRY - Byte Put Vector
; Handles BPUT calls
; A = byte to write
; Y = file handle provided by OSFIND
; Exit:
; A, X, and Y are unchanged
; see 16.1.4 of New Advanced User Guide
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

bputv_entry:
        dbg_string_axy "BPUTV: "
        ; rts

        jsr     remember_axy
        jsr     check_channel_yhndl_exyintch
@bp_entry:
        pha
        lda     fuji_channel_start,y
        bmi     @err_file_readonly
        lda     fuji_channel_start+1,y
        bmi     @err_file_locked2
        jsr     channel_set_dir_drive_yintch
        tya
        clc
        adc     #$04
        jsr     cmp_ptr_ext
        bne     @bp_noextend             ; If PTR<>Sector Count, i.e Ptr<sc
        jsr     channel_get_cat_entry_yintch  ; Enough space in gap?
        ldx     fuji_cat_file_offset    ; X=cat file offset
        sec                             ; Calc size of gap
        lda     $0F07,x                 ; Next file start sector
        sbc     $0F0F,x                 ; This file start
        pha                             ; lo byte
        lda     $0F06,x
        sbc     $0F0E,x                 ; Mixed byte
        and     #$03                    ; hi byte
        cmp     fuji_channel_start+2,y  ; File size in sectors
        bne     @bp_extendby100         ; If must be <gap size
        pla
        cmp     fuji_channel_start+1,y
        bne     @bp_extendtogap         ; If must be <gap size
        jmp     @bp_noextend

@bp_extendby100:
        pla
@bp_extendtogap:
        ; TODO: Implement file extension
        jmp     @bp_noextend

@bp_noextend:
        ; TODO: Implement byte writing
        pla
        clc
        rts

@err_file_readonly:
        ; TODO: Implement read-only error
        pla
        sec
        rts

@err_file_locked2:
        ; TODO: Implement file locked error
        pla
        sec
        rts
