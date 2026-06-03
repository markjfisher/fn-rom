; *FJSON — configure JSON translation on an open network channel
;
; Usage:
;   *FJSON <channel> <path>  — configure JSON translation on BASIC channel 0-5
;   *FJSON <path>           — set JSON path for future query (no query sent)
;   *FJSON                  — clear pending JSON path
;
; Requires the channel to have been opened by OPENIN("http://...") first.
; The FujiNet device buffers the full response, applies the JSON Pointer query,
; and subsequent BGET# reads return only the matched value.

        .export  cmd_fs_fjson
        .export  fjson_parse_start

        .importzp aws_tmp00
        .importzp aws_tmp03
        .importzp aws_tmp04
        .importzp aws_tmp10

        .importzp text_pointer

        .import check_channel_yhndl_exyintch
        .import err_bad
        .import err_syntax
        .import exit_user_ok
        .import fuji_ch_bptr_hi
        .import fuji_ch_bptr_low
        .import fuji_ch_bptr_mid
        .import fuji_ch_ext_hi
        .import fuji_ch_ext_low
        .import fuji_ch_ext_mid
        .import fuji_filename_buffer
        .import fuji_filename_len
        .import fuji_ch_sect_cnt
        .import fuji_json_path_len
        .import fuji_max_string_length
        .import fujibus_network_translate_configure
        .import get_fuji_json_path_addr_to_aws_tmp00
        .import num_params
        .import report_error
        .import param_get_string
        .import param_get_string_max_x

        .include "fujinet.inc"

        ; Register *FJSON into the FUTILS command group. Built only when
        ; FEATURE_NET is on (src/net/ is linked), so *FJSON is present iff the
        ; network device is — no .if in the command table (see ROM_ROLE_SPLIT_PLAN
        ; §5.3/§5.4).
        cmd_entry "FUTILS_EXT", "JSON", $16, $00, cmd_fs_fjson   ; [<handle> <string>]

        .segment "CODE"

err_bad_handle:
        ; display message then unset the JSON string
        lda     #$00
        sta     fuji_json_path_len

        jsr     err_bad
        .byte   $CB
        .byte   "handle", $00

cmd_fs_fjson:
        ; Count parameters: 0 = clear, 2 = handle + path
        jsr     num_params
        beq     params_0
        cmp     #$02
        beq     params_2

exit_bad_syntax:
        jmp     err_syntax

params_0:
        ; no params → clear pending path and exit
        lda     #$00
        sta     fuji_json_path_len
        jmp     exit_user_ok

params_2:
        ; Read handle as string first (supports multi-digit)
        clc
        jsr     param_get_string        ; Y must be preserved after this call

        tax                             ; X = length, A = length
        bne     fjson_parse_start
        cmp     #$02                    ; check we have exactly 2 digits, our minimum is 10
        bne     err_bad_handle

; Calculate the handle from the input string (atoi) on the 2 digit string.
fjson_parse_start:
        lda     fuji_filename_buffer
        sec
        sbc     #'0'                    ; first digit
        cmp     #10
        bcs     err_bad_handle          ; validate we only have digits

        asl     a                       ; *2
        pha                             ; save on the stack, and add directly to it
        asl     a                       ; *4
        asl     a                       ; *8

        clc
        tsx
        adc     $0101, x                ; first digit *10 (8x + 2x on stack)
        ; remove the byte from the stack, we can't use PLA, alternates are TAY/PLA/TYA which is 3 bytes, and trashes Y too
        inx
        txs

        clc
        adc     fuji_filename_buffer+1
        sec
        sbc     #'0'                    ; + second digit
        cmp     #100
        bcs     err_bad_handle

_fjson_parse_done:
        cmp     #filehndl
        bcc     err_bad_handle          ; if it's less than filehndl, not valid
        cmp     #filehndl+6
        bcs     err_bad_handle          ; if it's >= filehandle+6, not valid

_fjson_store_idx:
        pha                             ; save channel index

parse_json_path:
        ; Y is still valid from text parsing, as we haven't altered it
        ldx     #FUJI_JSON_PATH_BUFFER_SIZE
        jsr     param_get_string_max_x
        bcc     exit_bad_syntax

        sta     fuji_filename_len       ; save length
        sta     fuji_json_path_len

        ; Copy path from fuji_filename_buffer to PWS
        jsr     get_fuji_json_path_addr_to_aws_tmp00
        ldx     fuji_json_path_len
        ldy     #$00

fjson_copy_loop:
        lda     fuji_filename_buffer,y
        sta     (aws_tmp00),y
        iny
        dex
        bne     fjson_copy_loop

        ; Use the same file-handle-to-intch conversion that BGET uses
        pla                             ; A = channel index (0-5)
        tay                             ; Y = file handle for conversion
        jsr     check_channel_yhndl_exyintch
        ; Returns Y = intch (same as BGET uses), C=0 if channel is in use
        bcs     err_bad_handle

        sty     aws_tmp04                ; save intch across translate call
        jsr     fujibus_network_translate_configure
        bcs     err_network

        ; EXT/PTR update is done inside fujibus_network_translate_configure
_fjson_ext_done:
        lda     #$00
        sta     fuji_json_path_len      ; immediate translate should not affect future OPEN requests
        ; pla                             ; balance stack (intch was pushed)
        jmp     exit_user_ok

err_network:
        ; Exhausted/failed JSON translate should behave like an empty result for BASIC.
        ; Mark PTR=EXT=0 so subsequent BGET#/EOF# sees immediate EOF on this channel.
        ldy     aws_tmp04
        lda     #$00
        sta     fuji_ch_ext_low,y
        sta     fuji_ch_ext_mid,y
        sta     fuji_ch_ext_hi,y
        sta     fuji_ch_bptr_low,y
        sta     fuji_ch_bptr_mid,y
        sta     fuji_ch_bptr_hi,y
        sta     fuji_ch_sect_cnt,y
        sta     fuji_json_path_len
        jmp     exit_user_ok
