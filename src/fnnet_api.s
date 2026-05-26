; FujiNet OSWORD &78 / CALL API for long URIs and JSON paths.
; Parameter block (16 bytes at X/Y):
;   +0  reason in / status out
;   +1  status out (duplicate for CALL convenience)
;   +2  string pointer (u16le)
;   +4  string length (u16le, max FUJI_EXT_STR_MAX_LEN)
;   +6  handle in/out (BASIC file handle $10..$15)
;   +8  API version or CALL entry lo/hi (reason 0 out)

        .export fnnet_call_entry
        .export fnnet_dispatch

        .importzp aws_tmp00
        .importzp aws_tmp01
        .importzp aws_tmp02
        .importzp aws_tmp06
        .importzp aws_tmp07
        .importzp aws_tmp08
        .importzp aws_tmp09
        .importzp aws_tmp14
        .importzp aws_tmp15

        .import check_channel_yhndl_exyintch
        .import fuji_ch_bptr_hi
        .import fuji_ch_bptr_low
        .import fuji_ch_bptr_mid
        .import fuji_ch_ext_hi
        .import fuji_ch_ext_low
        .import fuji_ch_ext_mid
        .import fuji_ch_sect_cnt
        .import fuji_ch_write_count
        .import fuji_ch_write_pos_low
        .import fuji_ch_write_pos_mid
        .import fuji_ch_write_pos_hi
        .import fuji_ext_str_flags
        .import fuji_ext_str_len
        .import fuji_ext_str_len_hi
        .import fuji_ext_str_ptr
        .import fuji_json_path_len
        .import fuji_network_body_len
        .import fuji_network_body_len_hi
        .import fujibus_network_write_ext
        .import fujibus_network_translate_configure
        .import network_flush_write

        .include "fujinet.inc"

        .segment "CODE"

; CALL entry: A=reason, X/Y=parameter block pointer. Returns status in A.
fnnet_call_entry:
        stx     aws_tmp00
        sty     aws_tmp01
        ldy     #$00
        sta     (aws_tmp00),y

; Core dispatcher: X/Y=parameter block, reason at (block)+0.
fnnet_dispatch:
        stx     aws_tmp00
        stx     aws_tmp14
        sty     aws_tmp01
        sty     aws_tmp15

        ldy     #$00
        lda     (aws_tmp00),y
        cmp     #FNNET_REASON_VERSION
        bne     :+
        jmp     fnnet_reason_version
:

        cmp     #FNNET_REASON_JSON_QUERY
        bne     :+
        jmp     fnnet_reason_json_query
:

        cmp     #FNNET_REASON_STASH_JSON
        bne     :+
        jmp     fnnet_reason_stash_json
:

        cmp     #FNNET_REASON_SET_BODY_LEN
        bne     :+
        jmp     fnnet_reason_set_body_len
:

        cmp     #FNNET_REASON_WRITE_DATA
        bne     :+
        jmp     fnnet_reason_write_data
:

        ; fall into fail
fnnet_fail:
        lda     #FNNET_STATUS_BAD_CALL
fnnet_exit:
        ldy     #$00
        sta     (aws_tmp14),y
        ldy     #$01
        sta     (aws_tmp14),y
        rts

fnnet_reason_version:
        ldy     #$08
        lda     #<fnnet_call_entry
        sta     (aws_tmp00),y
        iny
        lda     #>fnnet_call_entry
        sta     (aws_tmp00),y
        lda     #FNNET_STATUS_OK
        beq     fnnet_exit

fnnet_reason_stash_json:
        jsr     fnnet_load_ext_str
        bcs     fnnet_fail

        lda     #FUJI_EXT_STR_IS_JSON
        jsr     set_flags_and_len
        lda     #FNNET_STATUS_OK
        beq     fnnet_exit

fnnet_reason_set_body_len:
        ldy     #$04
        lda     (aws_tmp00),y
        sta     fuji_network_body_len
        iny
        lda     (aws_tmp00),y
        sta     fuji_network_body_len_hi
        lda     #FNNET_STATUS_OK
        beq     fnnet_exit

fnnet_reason_write_data:
        jsr     fnnet_load_ext_str
        bcs     fnnet_fail

        ldy     #$06
        lda     (aws_tmp00),y
        tay
        jsr     check_channel_yhndl_exyintch
        bcs     fnnet_bad_channel

        sty     aws_tmp02

        jsr     network_flush_write
        bcc     :+
        jmp     fnnet_write_failed
:

        ldy     aws_tmp02
        lda     fuji_ch_write_count,y
        beq     :+
        lda     #$00
        sta     fuji_ch_write_count,y
:

        lda     fuji_ch_write_pos_low,y
        sta     aws_tmp06
        lda     fuji_ch_write_pos_mid,y
        sta     aws_tmp07
        lda     fuji_ch_write_pos_hi,y
        sta     aws_tmp08
        lda     #$00
        sta     aws_tmp09

        jsr     fujibus_network_write_ext
        bcs     fnnet_write_failed

        ; advance write position by bulk payload length
        ldy     aws_tmp02
        lda     fuji_ch_write_pos_low,y
        clc
        adc     fuji_ext_str_len
        sta     fuji_ch_write_pos_low,y
        lda     fuji_ch_write_pos_mid,y
        adc     fuji_ext_str_len_hi
        sta     fuji_ch_write_pos_mid,y
        lda     fuji_ch_write_pos_hi,y
        adc     #$00
        sta     fuji_ch_write_pos_hi,y

        lda     #FNNET_STATUS_OK
        jmp     fnnet_exit

fnnet_reason_json_query:
        jsr     fnnet_load_ext_str
        bcc     :+
        jmp     fnnet_fail
:

        lda     #(FUJI_EXT_STR_ACTIVE | FUJI_EXT_STR_IS_JSON)
        jsr     set_flags_and_len

        ldy     #$06
        lda     (aws_tmp00),y
        tay
        jsr     check_channel_yhndl_exyintch
        bcs     fnnet_bad_channel

        sty     aws_tmp02

fnnet_json_channel_ok:
        jsr     fujibus_network_translate_configure
        bcs     fnnet_json_query_failed
fnnet_json_done:
        lda     #$00
        sta     fuji_json_path_len      ; immediate translate should not affect future OPEN requests
        lda     #FNNET_STATUS_OK
        jmp     fnnet_exit

fnnet_bad_channel:
        jsr     fnnet_clear_ext_state
        lda     #FNNET_STATUS_BAD_CHANNEL
        jmp     fnnet_exit

fnnet_json_query_failed:
        ; Match *FJSON soft-fail behaviour: translated read becomes immediate EOF,
        ; and the caller can inspect the non-zero fnnet status to distinguish it.
        ldy     aws_tmp02
        lda     #$00
        jsr     fnnet_clear_channel_read_state_y
        jsr     fnnet_clear_ext_state
        lda     #FNNET_STATUS_JSON_QUERY_FAILED
        jmp     fnnet_exit

fnnet_write_failed:
        jsr     fnnet_clear_ext_state
        lda     #FNNET_STATUS_BAD_CALL
        jmp     fnnet_exit

fnnet_load_ext_str:
        ldy     #$02
        lda     (aws_tmp00),y
        sta     fuji_ext_str_ptr
        iny
        lda     (aws_tmp00),y
        sta     fuji_ext_str_ptr+1
        iny
        lda     (aws_tmp00),y
        sta     fuji_ext_str_len
        iny
        lda     (aws_tmp00),y
        sta     fuji_ext_str_len_hi

        lda     fuji_ext_str_len
        ora     fuji_ext_str_len_hi
        beq     fnnet_load_fail

        lda     fuji_ext_str_len_hi
        cmp     #>(FUJI_EXT_STR_MAX_LEN + 1)
        bcc     fnnet_load_ok
        bne     fnnet_load_fail
        lda     fuji_ext_str_len
        cmp     #<FUJI_EXT_STR_MAX_LEN + 1
        bcs     fnnet_load_fail
fnnet_load_ok:
        lda     #$00
        sta     fuji_ext_str_flags
        clc
        rts
fnnet_load_fail:
        jsr     fnnet_clear_ext_state
        sec
        rts

; A = flags to ORA into fuji_ext_str_flags
set_flags_and_len:
        ora     fuji_ext_str_flags
        sta     fuji_ext_str_flags
        lda     fuji_ext_str_len
        sta     fuji_json_path_len
        rts

fnnet_clear_ext_state:
        lda     #$00
        sta     fuji_ext_str_flags
        sta     fuji_ext_str_len
        sta     fuji_ext_str_len_hi
        sta     fuji_ext_str_ptr
        sta     fuji_ext_str_ptr+1
        sta     fuji_json_path_len
        rts

; Entry: Y = intch, A = $00
fnnet_clear_channel_read_state_y:
        sta     fuji_ch_ext_low,y
        sta     fuji_ch_ext_mid,y
        sta     fuji_ch_ext_hi,y
        sta     fuji_ch_bptr_low,y
        sta     fuji_ch_bptr_mid,y
        sta     fuji_ch_bptr_hi,y
        sta     fuji_ch_sect_cnt,y
        rts
