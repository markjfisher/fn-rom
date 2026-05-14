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
.export  _fjson_clear_channel
.export  _fjson_clear_no_stash
.export  _fjson_copy_loop
.export  _fjson_copy_loop_1
.export  _fjson_copy_ok_1
.export  _fjson_done
.export  _fjson_ext_cont
.export  _fjson_has_params
.export  _fjson_no_handle
.export  _fjson_no_params
.export  _fjson_one_param
.export  _fjson_parse_num
.export  _fjson_parse_start
.export  _fjson_path_done
.export  _fjson_read_loop
.export  _fjson_read_path
.export  _fjson_skip
.export  _fjson_skip_spaces
.export  _fjson_store_channel
.export  _fjson_store_done
.export  _fjson_store_idx
.export  _fjson_two_params

        .importzp aws_tmp00
        .importzp aws_tmp03
        .importzp aws_tmp04
        .importzp aws_tmp10

        .importzp text_pointer

        .import check_channel_yhndl_exyintch
        .import exit_user_ok
        .import fuji_filename_buffer
        .import fuji_filename_len
        .import fuji_json_path_len
        .import fujibus_network_translate_configure
        .import get_fuji_json_path_addr_to_aws_tmp00
        .import num_params
        .import param_get_string
        .import set_fuji_data_buffer_ptr

        .include "fujinet.inc"

        .segment "CODE"

cmd_fs_fjson:
        ; Count parameters: 0 = clear, 1 = store path, 2+ = handle + path + send query
        jsr     num_params
        bne     _fjson_has_params
        jmp     _fjson_no_params               ; 0 params → clear
_fjson_has_params:
        cmp     #1
        bne     _fjson_two_params              ; 2+ params → parse handle + path + send query
        jmp     _fjson_one_param               ; 1 param → store path only
_fjson_two_params:

_fjson_skip:
        ; Read handle as string first (supports multi-digit)
        sec
        jsr     param_get_string
        sty     aws_tmp10               ; save Y (GSREAD text index)
        tax                             ; X = length, A = length
        bne     _fjson_parse_start
        jmp     _fjson_no_handle
_fjson_parse_start:
        ldy     #$00
        lda     #$00
        sta     aws_tmp03               ; value = 0
_fjson_parse_num:
        lda     aws_tmp03
        asl     a                       ; * 2
        sta     aws_tmp04
        asl     a                       ; * 4
        asl     a                       ; * 8
        clc
        adc     aws_tmp04               ; * 8 + * 2 = * 10
        clc
        adc     fuji_filename_buffer,y
        sec
        sbc     #'0'
        sta     aws_tmp03               ; value = value * 10 + digit
        iny
        dex
        bne     _fjson_parse_num
        lda     aws_tmp03               ; A = BASIC handle value
        ldy     aws_tmp10               ; restore Y (GSREAD text index)

        sec
        sbc     #filehndl               ; BASIC handle → channel index 0-5
        cmp     #6
        bcc     _fjson_store_idx
        jmp     _fjson_bad_channel
_fjson_store_idx:
        pha                             ; save channel index

        ; Read JSON Pointer path from command text buffer (preserves hyphens)
        ; Y from aws_tmp10 points to the character after the handle token
        ldy     aws_tmp10

        ; Skip leading spaces
_fjson_skip_spaces:
        lda     (text_pointer),y
        cmp     #$20
        bne     _fjson_read_path
        iny
        jmp     _fjson_skip_spaces

_fjson_read_path:
        ldx     #$00
_fjson_read_loop:
        lda     (text_pointer),y
        beq     _fjson_path_done              ; NUL → done
        cmp     #$0D                    ; CR → done
        beq     _fjson_path_done
        sta     fuji_filename_buffer,x
        inx
        iny
        cpx     #FUJI_JSON_PATH_BUFFER_SIZE
        bcc     _fjson_read_loop
_fjson_path_done:
        stx     fuji_filename_len       ; save length
        stx     fuji_json_path_len
        cpx     #$00                    ; test length for zero
        beq     _fjson_clear_channel          ; empty path → clear

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

_fjson_store_channel:
        ; Use the same file-handle-to-intch conversion that BGET uses
        ; Reconstruct the BASIC file handle from the channel index
        pla                             ; A = channel index (0-5)
        clc
        adc     #filehndl               ; A = BASIC file handle ($10..$15)
        tay                             ; Y = file handle for conversion
        jsr     check_channel_yhndl_exyintch
        ; Returns Y = intch (same as BGET uses), C=0 if channel is in use
        bcc     _fjson_store_done
        jmp     _fjson_bad_channel            ; channel not in use
_fjson_store_done:

        ; Push intch on stack (preserved unconditionally across JSR/RET)
        tya
        pha

        ; Set buffer_ptr to PWS packet buffer and send JSON query
        lda     fuji_json_path_len
        bne     _fjson_ext_cont
        pla                             ; balance stack
        jmp     _fjson_done                   ; if path was cleared, skip
_fjson_ext_cont:

        ; jsr     set_fuji_data_buffer_ptr
        jsr     fujibus_network_translate_configure
        ; A = 1 on success, 0 on failure
        ; EXT/PTR update is done inside fujibus_network_translate_configure
_fjson_ext_done:
        lda     #$00
        sta     fuji_json_path_len      ; immediate translate should not affect future OPEN requests
        pla                             ; balance stack (intch was pushed)
        jmp     exit_user_ok

_fjson_clear_channel:
        pla                             ; balance stack (channel number was pushed)
        lda     #$00
        sta     fuji_json_path_len
        jmp     exit_user_ok

_fjson_one_param:
        ; Single param: path only, no query sent
        sec
        jsr     param_get_string
        sta     fuji_filename_len

        beq     _fjson_clear_no_stash

        cmp     #FUJI_JSON_PATH_BUFFER_SIZE
        bcc     _fjson_copy_ok_1
        lda     #FUJI_JSON_PATH_BUFFER_SIZE
_fjson_copy_ok_1:
        sta     fuji_json_path_len
        tax
        beq     _fjson_done

        jsr     get_fuji_json_path_addr_to_aws_tmp00
        ldy     #$00
_fjson_copy_loop_1:
        lda     fuji_filename_buffer,y
        sta     (aws_tmp00),y
        iny
        dex
        bne     _fjson_copy_loop_1
        jmp     exit_user_ok

_fjson_clear_no_stash:
        lda     #$00
        sta     fuji_json_path_len
        jmp     exit_user_ok

_fjson_bad_channel:
_fjson_no_handle:
_fjson_no_params:
        ; no params → clear pending path and exit
        lda     #$00
        sta     fuji_json_path_len
        jmp     exit_user_ok

_fjson_done:
        rts
