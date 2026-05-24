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

        .import check_channel_yhndl_exyintch
        .import fuji_ch_bptr_hi
        .import fuji_ch_bptr_low
        .import fuji_ch_bptr_mid
        .import fuji_ch_ext_hi
        .import fuji_ch_ext_low
        .import fuji_ch_ext_mid
        .import fuji_ch_sect_cnt
        .import fuji_ext_str_flags
        .import fuji_ext_str_len
        .import fuji_ext_str_len_hi
        .import fuji_ext_str_ptr
        .import fuji_json_path_len
        .import fujibus_network_translate_configure

        .include "fujinet.inc"

        .segment "CODE"

; CALL entry: A=reason, X/Y=parameter block pointer. Returns status in A.
fnnet_call_entry:
        stx     aws_tmp00
        sty     aws_tmp01
        ldy     #$00
        sta     (aws_tmp00),y
        jmp     fnnet_dispatch

; Core dispatcher: X/Y=parameter block, reason at (block)+0.
fnnet_dispatch:
        stx     aws_tmp00
        sty     aws_tmp01

        ldy     #$00
        lda     (aws_tmp00),y
        cmp     #FNNET_REASON_VERSION
        beq     fnnet_reason_version

        cmp     #FNNET_REASON_JSON_QUERY
        beq     fnnet_reason_json_query

        cmp     #FNNET_REASON_STASH_JSON
        beq     fnnet_reason_stash_json

        ; fall into fail
fnnet_fail:
        lda     #FNNET_STATUS_BAD_CALL
fnnet_exit:
        ldy     #$00
        sta     (aws_tmp00),y
        ldy     #$01
        sta     (aws_tmp00),y
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

fnnet_reason_json_query:
        jsr     fnnet_load_ext_str
        bcs     fnnet_fail

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
        lda     #FNNET_STATUS_OK
        beq     fnnet_exit

fnnet_bad_channel:
        lda     #FNNET_STATUS_BAD_CHANNEL
        bne     fnnet_exit

fnnet_json_query_failed:
        ; Match *FJSON soft-fail behaviour: translated read becomes immediate EOF,
        ; and the caller can inspect the non-zero fnnet status to distinguish it.
        ldy     aws_tmp02
        lda     #$00
        sta     fuji_ch_ext_low,y
        sta     fuji_ch_ext_mid,y
        sta     fuji_ch_ext_hi,y
        sta     fuji_ch_bptr_low,y
        sta     fuji_ch_bptr_mid,y
        sta     fuji_ch_bptr_hi,y
        sta     fuji_ch_sect_cnt,y
        sta     fuji_json_path_len
        lda     #FNNET_STATUS_JSON_QUERY_FAILED
        bne     fnnet_exit

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
        sec
        rts

; A = flags to ORA into fuji_ext_str_flags
set_flags_and_len:
        ora     fuji_ext_str_flags
        sta     fuji_ext_str_flags
        lda     fuji_ext_str_len
        sta     fuji_json_path_len
        rts
