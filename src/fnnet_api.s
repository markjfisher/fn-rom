; FujiNet OSWORD &E0 / CALL API for long URIs and JSON paths.
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
        bne     @not_version
        jmp     fnnet_reason_version
@not_version:
        cmp     #FNNET_REASON_JSON_QUERY
        bne     @not_json_query
        jmp     fnnet_reason_json_query
@not_json_query:
        cmp     #FNNET_REASON_STASH_JSON
        bne     @not_stash
        jmp     fnnet_reason_stash_json
@not_stash:
        jmp     fnnet_fail

fnnet_reason_version:
        ldy     #$01
        lda     #FNNET_API_VERSION
        sta     (aws_tmp00),y
        iny
        sta     (aws_tmp00),y
        ldy     #$08
        lda     #<fnnet_call_entry
        sta     (aws_tmp00),y
        iny
        lda     #>fnnet_call_entry
        sta     (aws_tmp00),y
        lda     #$00
        jmp     fnnet_exit

fnnet_reason_stash_json:
        jsr     fnnet_load_ext_str
        bcc     fnnet_stash_ok
        jmp     fnnet_fail
fnnet_stash_ok:
        lda     fuji_ext_str_len
        sta     fuji_json_path_len
        lda     fuji_ext_str_flags
        ora     #FUJI_EXT_STR_IS_JSON
        sta     fuji_ext_str_flags
        lda     #$00
        jmp     fnnet_exit

fnnet_reason_json_query:
        jsr     fnnet_load_ext_str
        bcc     fnnet_json_ok
        jmp     fnnet_fail
fnnet_json_ok:
        lda     fuji_ext_str_len
        sta     fuji_json_path_len
        lda     fuji_ext_str_flags
        ora     #(FUJI_EXT_STR_ACTIVE | FUJI_EXT_STR_IS_JSON)
        sta     fuji_ext_str_flags

        ldy     #$06
        lda     (aws_tmp00),y
        tay
        jsr     check_channel_yhndl_exyintch
        bcs     fnnet_json_channel_ok
        jmp     fnnet_fail
fnnet_json_channel_ok:
        jsr     fujibus_network_translate_configure
        bne     fnnet_json_done
        jmp     fnnet_fail
fnnet_json_done:
        lda     #$00
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
        sec
        rts

fnnet_fail:
        lda     #$01
fnnet_exit:
        ldy     #$01
        sta     (aws_tmp00),y
        rts
