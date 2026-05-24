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

        .export  _fjson_copy_loop
        .export  _fjson_has_params
        .export  _fjson_one_param
        .export  _fjson_parse_start
        .export  _fjson_path_done
        .export  _fjson_store_channel
        .export  _fjson_store_idx
        .export  _fjson_two_params

        .importzp aws_tmp00
        .importzp aws_tmp03
        .importzp aws_tmp04
        .importzp aws_tmp10

        .importzp text_pointer

        .import check_channel_yhndl_exyintch
        .import err_bad
        .import exit_user_ok
        .import fuji_filename_buffer
        .import fuji_filename_len
        .import fuji_json_path_len
        .import fuji_max_string_length
        .import fujibus_network_translate_configure
        .import get_fuji_json_path_addr_to_aws_tmp00
        .import num_params
        .import report_error
        .import param_get_string
        .import param_get_string_max_x

        .include "fujinet.inc"

        .segment "CODE"

err_bad_handle:
        ; display message then unset the JSON string
        lda     #$00
        sta     fuji_json_path_len

        jsr     err_bad
        .byte   $CB
        .byte   "handle", $00

err_bad_params:
        ; display message then unset the JSON string
        lda     #$00
        sta     fuji_json_path_len

        jsr     err_bad
        .byte   $CB
        .byte   "params", $00

cmd_fs_fjson:
        ; Count parameters: 0 = clear, 1 = store path, 2 = handle + path
        jsr     num_params
        bne     _fjson_has_params

        ; no params → clear pending path and exit
        lda     #$00
        sta     fuji_json_path_len
        jmp     exit_user_ok

_fjson_has_params:
        cmp     #3
        bcs     err_bad_params

        cmp     #1
        bne     _fjson_two_params              ; 2+ params → parse handle + path
        jmp     _fjson_one_param               ; 1 param → store path only
_fjson_two_params:
        ; Read handle as string first (supports multi-digit)
        clc
        jsr     param_get_string        ; Y must be preserved after this call

        tax                             ; X = length, A = length
        bne     _fjson_parse_start
        cmp     #$03                    ; check we only had 1-2 digits
        bcs     err_bad_handle

; either have X=1, and 1 digit, so no multiplication needed
; or X=2 and 2 digits, first digit needs multiplying up by 10

_fjson_parse_start:
        lda     fuji_filename_buffer
        sec
        sbc     #'0'                    ; first digit

        dex
        beq     _fjson_parse_done       ; one digit only

        asl     a                       ; *2
        sta     aws_tmp03
        asl     a                       ; *4
        asl     a                       ; *8
        clc
        adc     aws_tmp03               ; first digit *10
        clc
        adc     fuji_filename_buffer+1
        sec
        sbc     #'0'                    ; + second digit

_fjson_parse_done:
        cmp     #filehndl
        bcc     err_bad_handle          ; if it's less than filehndl, not valid
        cmp     #filehndl+6
        bcs     err_bad_handle          ; if it's >= filehandle+6, not valid

_fjson_store_idx:
        pha                             ; save channel index
        jsr     parse_json_path

_fjson_store_channel:
        ; Use the same file-handle-to-intch conversion that BGET uses
        pla                             ; A = channel index (0-5)
        tay                             ; Y = file handle for conversion
        jsr     check_channel_yhndl_exyintch
        ; Returns Y = intch (same as BGET uses), C=0 if channel is in use
        bcs     err_bad_handle

        jsr     fujibus_network_translate_configure
        bcs     err_network

        ; EXT/PTR update is done inside fujibus_network_translate_configure
_fjson_ext_done:
        lda     #$00
        sta     fuji_json_path_len      ; immediate translate should not affect future OPEN requests
        ; pla                             ; balance stack (intch was pushed)
        jmp     exit_user_ok

_fjson_one_param:
        ; Single param: path only, no query sent
        jsr     parse_json_path
        jmp     exit_user_ok

parse_json_path:
        ; Y is still valid from text parsing, as we haven't altered it
        ldx     #FUJI_JSON_PATH_BUFFER_SIZE
        jsr     param_get_string_max_x
        bcc     err_bad_params

_fjson_path_done:
        sta     fuji_filename_len       ; save length
        sta     fuji_json_path_len

        ; Copy path from fuji_filename_buffer to PWS
        ; NOTE: get_fuji_json_path_addr_to_aws_tmp00 clobbers X (paged_ram_copy),
        ; so we must reload X from fuji_json_path_len AFTER the call.
        jsr     get_fuji_json_path_addr_to_aws_tmp00
        ldx     fuji_json_path_len
        ldy     #$00
_fjson_copy_loop:
        lda     fuji_filename_buffer,y
        sta     (aws_tmp00),y
        iny
        dex
        bne     _fjson_copy_loop
        rts

err_network:
        jsr     report_error
        .byte   $CB
        .byte   "FujiNet error", 0
