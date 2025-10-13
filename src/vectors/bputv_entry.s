; BPUTV_ENTRY - Byte Put Vector
; Handles BPUT calls for writing single bytes to files
; Translated from MMFS mmfs100.asm lines 5274-5303

        .export bputv_entry
        .export bput_yintchan
        .export err_file_read_only

        .import calc_buffer_sector_for_ptr
        .import channel_buffer_rw_yintch_c1read
        .import channel_buffer_to_disk_yintch
        .import channel_flags_set_bits
        .import channel_get_cat_entry_yintch
        .import channel_set_dir_drive_yintch
        .import check_channel_yhndl_exyintch
        .import cmp_ptr_ext
        .import err_file_locked
        .import load_then_inc_seq_ptr_yintch
        .import remember_axy
        .import report_error_cb

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
        ; dbg_string_axy "BPUTV: "
        ; rts

        jsr     remember_axy
        jsr     check_channel_yhndl_exyintch
bp_entry:
        pha
        lda     fuji_channel_start,y
        bmi     err_file_read_only
        lda     fuji_channel_start+1,y
        bmi     err_file_locked2
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
        lda     fuji_ch_flg,y           ; Check buffer status (MMFS line 5335)
        bmi     @bp_savebyte            ; If PTR in buffer
        jsr     channel_buffer_to_disk_yintch  ; Save buffer (MMFS line 5337)
        lda     fuji_ch_ext_low,y       ; EXT byte 0 (MMFS line 5338)
        bne     @bp_loadbuf             ; IF <>0 load buffer (MMFS line 5339)
        jsr     cmp_ptr_ext             ; Compare PTR with EXT (MMFS line 5340)
        bne     @bp_loadbuf             ; If PTR<>EXT, i.e. PTR<EXT (MMFS line 5341)
        jsr     calc_buffer_sector_for_ptr  ; new sector! (MMFS line 5342)
        bne     @bp_savebyte            ; always (MMFS line 5343)
@bp_loadbuf:
        sec                             ; Load buffer (MMFS line 5345)
        jsr     channel_buffer_rw_yintch_c1read  ; (MMFS line 5346)
@bp_savebyte:
        lda     #$40                    ; Bit 6 set = new data (MMFS line 5348)
        jsr     channel_flags_set_bits  ; (MMFS line 5349)
        jsr     load_then_inc_seq_ptr_yintch  ; load buffer ptr, increment PTR (MMFS line 5350)
        pla                             ; Get byte to write (MMFS line 5351)
        sta     (aws_tmp10,x)   ; Byte to buffer (MMFS line 5352)
        jsr     cmp_ptr_ext             ; Check if PTR >= EXT (MMFS line 5353)
        bcc     @bp_exit                ; If PTR<EXT (MMFS line 5354)
        lda     #$20                    ; Update cat file len when closed (MMFS line 5358)
        jsr     channel_flags_set_bits  ; Set bit 5 (MMFS line 5359)
        ldx     #$02                    ; EXT=PTR (MMFS line 5360)
@bp_setextloop:
        lda     fuji_ch_bptr_low,y      ; Copy PTR to EXT (MMFS lines 5362-5363)
        sta     fuji_ch_ext_low,y
        iny
        dex
        bpl     @bp_setextloop
@bp_exit:
        clc
        rts

err_file_locked2:
        jmp     err_file_locked

err_file_read_only:
        jsr     report_error_cb
        .byte   $C1
        .byte   "Read only", 0

bput_yintchan:
        jsr     remember_axy
        jmp     bp_entry
