; BPUTV_ENTRY - Byte Put Vector
; Handles BPUT calls for writing single bytes to files
; Translated from MMFS mmfs100.asm lines 5274-5303

        .export bputv_entry
        .export bput_yintchan
        .export err_file_read_only
        .export bp_entry
        .export ai_suggestion
        .export updext
        .export network_flush_write
        .export network_bput

        .importzp aws_tmp00
        .importzp aws_tmp01
        .importzp aws_tmp02
        .importzp aws_tmp06
        .importzp aws_tmp07
        .importzp aws_tmp08
        .importzp aws_tmp09
        .importzp aws_tmp10

        .import calc_buffer_sector_for_ptr
        .import channel_buffer_rw_yintch_c1read
        .import channel_buffer_to_disk_yintch
        .import channel_flags_set_bits
        .import channel_get_cat_entry_yintch
        .import channel_set_dir_drive_yintch
        .import check_channel_yhndl_exyintch
        .import cmp_ptr_ext
        .import dfs_cat_file_op
        .import dfs_cat_file_size
        .import err_file_locked
        .import fuji_cat_file_offset
        .import fuji_ch_111A
        .import fuji_ch_bptr_low
        .import fuji_ch_buf_page
        .import fuji_ch_ext_low
        .import fuji_ch_flg
        .import fuji_ch_handle_high
        .import fuji_ch_handle_low
        .import fuji_ch_sect_cnt
        .import fuji_ch_write_count
        .import fuji_ch_write_pos_hi
        .import fuji_ch_write_pos_low
        .import fuji_ch_write_pos_mid
        .import fuji_channel_start
        .import fuji_intch
        .import fuji_network_flush_mode
        .import fujibus_network_write
        .import load_then_inc_seq_ptr_yintch
        .import remember_axy
        .import report_error_cb
        .import save_cat_to_disk
        .import tya_cmp_ptr_ext

        .include "fujinet.inc"

        .segment "CODE"

bput_yintchan:
        jsr     remember_axy
        jmp     bp_entry

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
        jsr     remember_axy
        jsr     check_channel_yhndl_exyintch

        ; Save byte to write (A) before handle check clobbers it
        pha

        ; Check for network channel by testing handle bytes
        lda     fuji_ch_handle_low,y
        ora     fuji_ch_handle_high,y
        beq     not_network             ; if not network, go disk path
        pla                             ; restore byte for network_bput
        jmp     network_bput
not_network:
        pla                             ; restore byte for bp_entry
        jmp     bp_entry

bp_entry:
        pha
        lda     fuji_channel_start,y
        bmi     @bp_err_readonly
        lda     fuji_channel_start+1,y
        bmi     @bp_err_locked
        jmp     @bp_continue
@bp_err_readonly:
        jmp     err_file_read_only
@bp_err_locked:
        jmp     err_file_locked2
@bp_continue:
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
        ; Extend file by maximum of $100 sectors (64K) - MMFS lines 5313-5326
        lda     fuji_ch_111A,y          ; Add maximum of $100
        clc                             ; to sector count
        adc     #$01                    ; (i.e. 64K)
        sta     fuji_ch_111A,y          ; [else set to size of gap]
        asl     a                       ; Update cat entry
        asl     a
        asl     a
        asl     a
        eor     dfs_cat_file_op,x   ; Mixed byte
        and     #$30
        eor     dfs_cat_file_op,x
        sta     dfs_cat_file_op,x   ; File len 2
        pla
        lda     #$00
@bp_extendtogap:
        ; Set file length in catalog and channel - MMFS lines 5328-5333
        sta     dfs_cat_file_size+1,x   ; File len 1 (mid byte)
        sta     fuji_ch_sect_cnt,y          ; Sector count
        lda     #$00
        sta     dfs_cat_file_size,x     ; File len 0 (low byte)
        jsr     save_cat_to_disk        ; Write catalog to disk
        ldy     fuji_intch              ; Restore Y=intch

@bp_noextend:
        lda     fuji_ch_flg,y           ; Check buffer status (MMFS line 5335)
        bmi     @bp_savebyte            ; If PTR in buffer
        jsr     channel_buffer_to_disk_yintch  ; Save buffer (MMFS line 5337)
        lda     fuji_ch_ext_low,y       ; EXT byte 0 (MMFS line 5338)
        bne     @bp_loadbuf             ; IF <>0 load buffer (MMFS line 5339)
        jsr     tya_cmp_ptr_ext         ; Compare PTR with EXT (MMFS line 5340)
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
        jsr     tya_cmp_ptr_ext         ; Check if PTR >= EXT (MMFS line 5353)
        bcc     bp_exit                 ; If PTR<EXT (MMFS line 5354)

updext:
        lda     #$20                    ; Update cat file len when closed (MMFS line 5358)
        jsr     channel_flags_set_bits  ; Set bit 5 (MMFS line 5359)
        ldx     #$02                    ; EXT=PTR (MMFS line 5360)
@bp_setextloop:
        lda     fuji_ch_bptr_low,y      ; Copy PTR to EXT (MMFS lines 5362-5363)
        sta     fuji_ch_ext_low,y
        iny
        dex
        bpl     @bp_setextloop

ai_suggestion:
        ldy     fuji_intch              ; CRITICAL: Restore Y=intch after loop!
bp_exit:
        ; clc
        rts

err_file_locked2:
        jmp     err_file_locked

err_file_read_only:
        jsr     report_error_cb
        .byte   $C1
        .byte   "Read only", 0

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; @network_bput — Network-aware byte write
; Buffers bytes in the channel buffer page and flushes via
; NET_CMD_WRITE when the buffer is full (256 bytes).
; Write buffer state per-channel (independent from read state):
;   fuji_ch_write_count,y    — number of buffered bytes ($1A)
;   fuji_ch_write_pos_low..hi — write stream position ($0A..$0C)
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

network_bput:
        pha                             ; save byte on stack

        ; Store byte at buffer[write_count]
        lda     fuji_ch_write_count,y   ; write count (= buffer offset)
        sta     aws_tmp00

        lda     fuji_ch_buf_page,y
        sta     aws_tmp01

        pla                             ; restore byte
        ldx     #$00
        sta     (aws_tmp00,x)           ; store at buffer[write_count]

        ; Increment write count and write position
        tya
        tax
        inc     fuji_ch_write_count,x   ; write_count++

        inc     fuji_ch_write_pos_low,x
        bne     :+
        inc     fuji_ch_write_pos_mid,x
        bne     :+
        inc     fuji_ch_write_pos_hi,x
:

        ; If write count wrapped from 255 to 0, buffer full — flush
        lda     fuji_ch_write_count,y
        cmp     #$00
        beq     @do_flush

        ; In immediate mode, flush after every BPUT
        lda     fuji_network_flush_mode
        beq     net_bput_exit

@do_flush:
        jsr     network_flush_write
        ; need to validate if the flush worked
        bcc     no_err_flushing
        jmp     $0100                                   ; already have the error message on the stack

no_err_flushing:
        ldy     fuji_intch

nfw_flush_done:
net_bput_exit:
        rts




; network_flush_write — Flush buffered writes to network device
;   Input: Y = intch
;   Output: C=0 on success, C=1 on failure and write count is set to 0. writes a write fail messager before returning

network_flush_write:
        clc                             ; anticipate no error in case there's nothing to flush
        lda     fuji_ch_write_count,y
        beq     nfw_flush_done

        sta     aws_tmp02               ; save write count for network_write call

        ; Calculate offset = write_pos - write_count
        ; write_pos is the absolute position AFTER the last byte written
        ; The first buffered byte is at (write_pos - write_count)
        lda     fuji_ch_write_pos_low,y
        sec
        sbc     aws_tmp02
        sta     aws_tmp06               ; offset low
        lda     fuji_ch_write_pos_mid,y
        sbc     #$00
        sta     aws_tmp07               ; offset mid
        lda     fuji_ch_write_pos_hi,y
        sbc     #$00
        sta     aws_tmp08               ; offset hi
        lda     #$00
        sta     aws_tmp09

        jsr     fujibus_network_write

        ; first reset the count to 0 as we have flushed either way
        ldy     fuji_intch
        lda     #$00
        sta     fuji_ch_write_count,y

        bcs     err_write_fail
        ; returns with C=0 for flush write
        rts

err_write_fail:
        jsr     report_error_cb
        .byte   $C2
        .byte   "Write err", $80
        nop
        sec
        rts
