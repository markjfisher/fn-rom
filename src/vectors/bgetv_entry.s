; BGETV_ENTRY - Byte Get Vector
; Handles BGET calls for reading single bytes from files
; Translated from MMFS mmfs100.asm lines 5169-5195

        .export bgetv_entry
        .export channel_buffer_rw_yintch_c1read
        .export channel_buffer_to_disk_yintch
        .export load_then_inc_seq_ptr_yintch
        .export err_eof

        .export network_bget
        .export nwbg_no_data_available
        .export nwbg_net_eof_j
        .export nwbg_net_read
        .export nwbg_net_have_data
        .export nwbg_net_eof
        .export nwbg_net_eof_exit

        .importzp aws_tmp06
        .importzp aws_tmp07
        .importzp aws_tmp08
        .importzp aws_tmp09
        .importzp aws_tmp10
        .importzp aws_tmp11
        .importzp aws_tmp12
        .importzp aws_tmp13
        .importzp aws_tmp14
        .importzp aws_tmp15
        .importzp pws_tmp00
        .importzp pws_tmp01
        .importzp pws_tmp02
        .importzp pws_tmp03

        .import calc_buffer_sector_for_ptr
        .import channel_flags_set_bits
        .import channel_set_dir_drive_yintch
        .import check_channel_yhndl_exyintch_tya_cmpptr
        .import fuji_ch_1118
        .import fuji_ch_bptr_hi
        .import fuji_ch_bptr_low
        .import fuji_ch_bptr_mid
        .import fuji_ch_buf_page
        .import fuji_ch_ext_hi
        .import fuji_ch_ext_low
        .import fuji_ch_ext_mid
        .import fuji_ch_flg
        .import fuji_ch_handle_high
        .import fuji_ch_handle_low
        .import fuji_ch_sect_cnt
        .import fuji_ch_sect_hi
        .import fuji_ch_sect_lo
        .import fuji_error_flag
        .import fuji_filev_load_hi
        .import fuji_intch
        .import fuji_network_buf_cnt
        .import fuji_network_buf_cnt_hi
        .import fujibus_network_read
        .import load_mem_block
        .import network_retry_backoff
        .import network_retry_init
        .import remember_xy_only
        .import report_error_cb
        .import save_mem_block

        .include "fujinet.inc"

        .segment "CODE"

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; BGETV_ENTRY - Byte Get Vector
; Handles BGET calls
; Y = file handle provided by OSFIND
; Exit:
; A = byte read
; C = 0 if not EOF, 1 if EOF
; X and Y are unchanged
; see 16.1.3 of New Advanced User Guide
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

bgetv_entry:
        jsr     remember_xy_only
        jsr     check_channel_yhndl_exyintch_tya_cmpptr         ; exits with Y=intch
        php                                                     ; save Z flag

        ; Check for network channel by testing handle bytes
        ; (Z flag from PTR/EXT comparison is lost after this check)
        lda     fuji_ch_handle_low,y
        ora     fuji_ch_handle_high,y
        bne     network_bget

        ; Disk channel - restore processor status flag
        plp
        bne     @bg_not_eof              ; If PTR<>EXT
        lda     fuji_ch_flg,y            ; Already at EOF?
        and     #$10
        beq     :+                       ; IF bit 4 NOT set, skip
        jmp     err_eof                  ; IF bit 4 set, error out
:
        lda     #$10
        jsr     channel_flags_set_bits   ; Set bit 4
        lda     #$FE

        sec
        rts                              ; C=1=EOF

@bg_not_eof:
        lda     fuji_ch_flg,y
        bmi     @bg_samesector1          ; If buffer ok
        jsr     channel_set_dir_drive_yintch
        jsr     channel_buffer_to_disk_yintch  ; Save buffer
        sec
        jsr     channel_buffer_rw_yintch_c1read  ; Load buffer

@bg_samesector1:
        jsr     load_then_inc_seq_ptr_yintch  ; load buffer ptr into BA/BB then increments Seq Ptr

        ; THIS IS THE MAIN READ OF THE DATA BYTE INTO A
        ; X is always 0 at this point from previous subroutine
        lda     (aws_tmp10, x)          ; Byte from buffer

        clc
        rts                             ; C=0 => NOT EOF

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; network_bget - Network-aware byte read
; For network channels, the buffer is refilled via NET_CMD_READ
; when exhausted. Buffer count is stored in fuji_ch_1118,y.
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

network_bget:
        plp                             ; clear the status that was stashed, not needed here

        ; Multi-byte buffered read from network stream.
        ; Per-channel buffer state stored in channel block:
        ;   $18 (fuji_ch_1118):    buf_start_low  — stream offset of buffer[0]
        ;   $19 (fuji_ch_sect_cnt): buf_cnt        — bytes available in buffer (0 = empty)
        ;   $1C (fuji_ch_sect_lo):  buf_start_mid  — mid byte of buffer start
        ;   $1D (fuji_ch_sect_hi):  buf_start_hi   — high byte of buffer start
        ;
        ; Buffer index = PTR - buf_start. Since the buffer is ≤256 bytes,
        ; and buf_start ≤ PTR ≤ buf_start + 256 within one fill, the
        ; 8-bit subtraction PTR_low - buf_start_low gives the correct index.

        ; sty     aws_tmp02               ; save intch

        ; Check if buffer has data for current PTR position
        lda     fuji_ch_bptr_low,y      ; PTR low
        sec
        sbc     fuji_ch_1118,y          ; subtract buf_start_low
        cmp     fuji_ch_sect_cnt,y      ; compare with buf_cnt
        bcs     nwbg_no_data_available
        jmp     nwbg_net_have_data          ; if index < buf_cnt, data available


nwbg_no_data_available:
        ; Check if PTR >= EXT (already at EOF — don't send a Read)
        lda     fuji_ch_bptr_hi,y
        cmp     fuji_ch_ext_hi,y
        bcc     nwbg_net_read
        bne     nwbg_net_eof_j              ; PTR_hi > EXT_hi → EOF
        lda     fuji_ch_bptr_mid,y
        cmp     fuji_ch_ext_mid,y
        bcc     nwbg_net_read                ; PTR_mid < EXT_mid → need to read
        bne     nwbg_net_eof_j              ; PTR_mid > EXT_mid → EOF
        lda     fuji_ch_bptr_low,y
        cmp     fuji_ch_ext_low,y
        bcs     nwbg_net_eof_j              ; PTR_low >= EXT_low → EOF
        bcc     nwbg_net_read

nwbg_net_eof_j:
        ; Set PTR = EXT so EOF handler (PTR == EXT check) returns TRUE
        lda     fuji_ch_ext_low,y
        sta     fuji_ch_bptr_low,y
        lda     fuji_ch_ext_mid,y
        sta     fuji_ch_bptr_mid,y
        lda     fuji_ch_ext_hi,y
        sta     fuji_ch_bptr_hi,y
        ; sty     fuji_intch
        sec                             ; ensure C=1 for EOF
        rts

nwbg_net_read:
        ; Buffer exhausted — refill via NET_CMD_READ
        ; offset = PTR (absolute byte position — no alignment)
        lda     fuji_ch_bptr_low,y
        sta     aws_tmp06
        lda     fuji_ch_bptr_mid,y
        sta     aws_tmp07
        lda     fuji_ch_bptr_hi,y
        sta     aws_tmp08
        lda     #$00
        sta     aws_tmp09

        ; max_bytes = 256
        lda     #$00
        sta     aws_tmp14
        lda     #$01
        sta     aws_tmp15

        ; Retry NotReady with exponential backoff (see network_retry_* in utils.s).
        jsr     network_retry_init
        sty     fuji_intch              ; preserve intch across wait/retry loop

nwbg_read_retry:
        ldy     fuji_intch              ; restore intch before each read attempt
        jsr     fujibus_network_read
        ldy     fuji_intch              ; reload intch (aws_tmp02 clobbered)
        cmp     #$02
        bne     nwbg_read_done

        jsr     network_retry_backoff
        bcs     nwbg_net_eof            ; timeout behaves as EOF for BASIC
        jmp     nwbg_read_retry

nwbg_read_done:
        cmp     #$01
        bne     nwbg_net_eof            ; hard failure = EOF


        ; Store buffer start offset and count in channel block
        lda     fuji_ch_bptr_low,y
        sta     fuji_ch_1118,y           ; buf_start_low
        lda     fuji_ch_bptr_mid,y
        sta     fuji_ch_sect_lo,y        ; buf_start_mid (repurpose sect_lo)
        lda     fuji_ch_bptr_hi,y
        sta     fuji_ch_sect_hi,y        ; buf_start_hi (repurpose sect_hi)
        lda     fuji_network_buf_cnt
        sta     fuji_ch_sect_cnt,y       ; buf_cnt (repurpose sect_cnt)

        ; Check if any bytes were returned
        ora     fuji_network_buf_cnt_hi
        beq     nwbg_net_eof                ; 0 bytes = EOF

        ; Fall through to read the byte

nwbg_net_have_data:
        ; Read byte from buffer page at calculated index
        lda     fuji_ch_bptr_low,y
        sec
        sbc     fuji_ch_1118,y           ; index = PTR_low - buf_start_low
        sta     aws_tmp10                ; BA = buffer offset

        lda     fuji_ch_buf_page,y
        sta     aws_tmp11                ; BB = buffer page

        ldx     #$00
        lda     (aws_tmp10, x)           ; read the byte
        pha                              ; save it

        ; Increment PTR
        tya
        tax
        inc     fuji_ch_bptr_low,x
        bne     :+
        inc     fuji_ch_bptr_mid,x
        bne     :+
        inc     fuji_ch_bptr_hi,x
:
        pla                              ; restore byte
        clc
        rts

nwbg_net_eof:
        ; For network channels: advance PTR = EXT so EOF# returns TRUE.
        ; Unknown-length streams initialise EXT to $FFFFFF, but translated/known-
        ; length reads set a smaller EXT and must not be forced back to $FFFFFF.
        lda     fuji_ch_handle_low,y
        ora     fuji_ch_handle_high,y
        beq     nwbg_net_eof_exit

        lda     fuji_ch_ext_low,y
        sta     fuji_ch_bptr_low,y
        lda     fuji_ch_ext_mid,y
        sta     fuji_ch_bptr_mid,y
        lda     fuji_ch_ext_hi,y
        sta     fuji_ch_bptr_hi,y
nwbg_net_eof_exit:
        sec                             ; C=1 = EOF
        rts

err_eof:
        jsr     report_error_cb
        .byte   $DF
        .byte   "EOF",0

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; Helper functions
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;


channel_buffer_to_disk_yintch:
        ; Save channel buffer to disk (MMFS lines 5223-5228)
        lda     fuji_ch_flg,y
        and     #$40                    ; Bit 6 set?
        beq     chnbuf_exit2            ; If no exit
        clc                             ; C=0=write buffer
        ; Fall through to channel_buffer_rw_yintch_c1read

channel_buffer_rw_yintch_c1read:
        ; Read/write channel buffer
        ; C=1 for read, C=0 for write
        inc     fuji_error_flag         ; Remember in case of error
        ldy     fuji_intch              ; Setup NMI vars
        lda     fuji_ch_buf_page,y      ; Buffer page
        sta     aws_tmp13               ; Data ptr high byte
        lda     #$FF                    ; Set load address to host
        sta     fuji_filev_load_hi
        sta     fuji_filev_load_hi+1
        lda     #$00
        sta     aws_tmp12               ; Data ptr low byte
        sta     pws_tmp00               ; Sector
        lda     #$01
        sta     pws_tmp01
        bcs     chnbuf_read             ; IF c=1 load buffer else save
        lda     fuji_ch_sect_lo,y       ; Buffer sector
        sta     pws_tmp03               ; Start sec. b0-b7 (&C3)
        lda     fuji_ch_sect_hi,y
        sta     pws_tmp02               ; "mixed byte" (&C2)
        jsr     save_mem_block
        ldy     fuji_intch              ; Y=intch
        lda     #$BF                    ; Clear bit 6
        jsr     channel_flags_clear_bits
        bcc     chnbuf_exit             ; always
chnbuf_read:
        jsr     calc_buffer_sector_for_ptr      ; Calculate which sector to load
        jsr     load_mem_block                  ; Load buffer (high-level interface)

chnbuf_exit:
        dec     fuji_error_flag
        ldy     fuji_intch
chnbuf_exit2:
        rts

load_then_inc_seq_ptr_yintch:
        ; Load buffer pointer into BA/BB then increment sequence pointer
        lda     fuji_ch_bptr_low,y      ; Seq.Ptr
        sta     aws_tmp10               ; BA
        lda     fuji_ch_buf_page,y      ; Buffer page
        sta     aws_tmp11               ; BB

        tya
        tax
        inc     fuji_ch_bptr_low,x      ; Seq.Ptr+=1
        bne     samesector
        jsr     channel_flags_clear_bit7 ; PTR in new sector!
        inc     fuji_ch_bptr_mid,x
        bne     samesector
        inc     fuji_ch_bptr_hi,x
samesector:
        ldx     #$00
        rts

channel_flags_clear_bit7:
        lda     #$7F                    ; Clear bit 7
        and     fuji_ch_flg,y
        sta     fuji_ch_flg,y
        clc
        rts

channel_flags_clear_bits:
        and     fuji_ch_flg,y
        sta     fuji_ch_flg,y
        clc
        rts
