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

        .import a_rolx4
        .import calc_buffer_sector_for_ptr
        .import channel_buffer_rw_yintch_c1read
        .import channel_buffer_to_disk_yintch
        .import channel_flags_set_bits
        .import channel_get_cat_entry_yintch
        .import channel_set_dir_drive_yintch
        .import check_channel_yhndl_exyintch
        .import cmp_ptr_ext
        .import dfs_cat_boot_option
        .import dfs_cat_file_size
        .import err_file_locked
        .import fuji_intch
        .import load_then_inc_seq_ptr_yintch
        .import remember_axy
        .import report_error_cb
        .import print_string
        .import print_newline
        .import save_cat_to_disk
        .import tya_cmp_ptr_ext
        .import fuji_begin_transaction
        .import fuji_end_transaction
        .import fujibus_network_write
        .import fuji_ch_handle_low
        .import fuji_ch_handle_high

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
; Write count stored per-channel in fuji_ch_1118,y.
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

network_bput:
        ; A = byte to write
        sty     aws_tmp02               ; save intch
        pha                             ; save byte on stack

        ; Store byte at buffer[write_count]
        ldy     aws_tmp02
        lda     fuji_ch_1118,y          ; write count (= buffer offset)
        sta     aws_tmp00               ; AWS_TMP00 = offset in buffer

        lda     fuji_ch_buf_page,y      ; buffer page
        sta     aws_tmp01               ; AWS_TMP01 = buffer page

        pla                             ; restore byte from stack
        ldx     #$00
        sta     (aws_tmp00,x)           ; store byte at buffer[write_count]

        ; Increment write count
        ldy     aws_tmp02
        tya
        tax
        inc     fuji_ch_1118,x          ; write_count++

        ; Increment PTR (tracks write position)
        inc     fuji_ch_bptr_low,x
        bne     :+
        inc     fuji_ch_bptr_mid,x
        bne     :+
        inc     fuji_ch_bptr_hi,x
:

        ; If write count wrapped from 255 to 0, buffer is full — flush
        lda     fuji_ch_1118,y
        cmp     #$00
        bne     @net_bput_exit          ; not full yet

        sty     aws_tmp02
        jsr     network_flush_write
        ldy     aws_tmp02

@net_bput_exit:
        rts


; network_flush_write — Flush buffered writes to network device
;   Input: Y = intch
;   Output: A = 1 on success, 0 on failure
;   Clobbers: aws_tmp02

network_flush_write:
        ; Nothing to flush if write count is 0
        lda     fuji_ch_1118,y
        ora     fuji_ch_sect_cnt,y      ; also check if ANY bytes pending
        beq     @flush_done

        ; Actually check just the write count byte
        lda     fuji_ch_1118,y
        beq     @flush_done

        ; Calculate offset = PTR - write_count
        ; Save write_count
        sta     aws_tmp12               ; save byte count
        sty     aws_tmp02               ; save intch

        ; PTR value is at fuji_ch_bptr_low/mid/hi
        ; We want offset = PTR - write_count
        ; Start with PTR value
        lda     fuji_ch_bptr_low,y
        sec
        sbc     aws_tmp12               ; subtract write_count
        sta     aws_tmp06               ; offset low
        lda     fuji_ch_bptr_mid,y
        sbc     #$00
        sta     aws_tmp07               ; offset mid
        lda     fuji_ch_bptr_hi,y
        sbc     #$00
        sta     aws_tmp08               ; offset hi
        lda     #$00
        sta     aws_tmp09               ; offset byte 3

        ; dataLen = write_count (from aws_tmp12)
        lda     aws_tmp12
        sta     aws_tmp02               ; dataLen low
        lda     #$00
        sta     aws_tmp03               ; dataLen high = 0

        ; save intch for after transaction
        sty     fuji_intch

        jsr     fuji_begin_transaction
        ldy     fuji_intch
        jsr     fujibus_network_write
        pha                             ; save result
        jsr     fuji_end_transaction
        pla                             ; restore result

        ldy     fuji_intch

        ; Clear write buffer count on success
        cmp     #$01
        bne     @flush_done
        lda     #$00
        sta     fuji_ch_1118,y

@flush_done:
        rts
