; *FLIST / *FLS — list directory via FileDevice ListDirectory (hand asm)
;
;   *FLS                    compact names (current directory)
;   *FLS LONG               long listing (size + unix time) for current directory
;   *FLS <path>             compact names for <path>
;   *FLS <path> LONG        long listing for <path>  (LONG must be the last argument)

        .export  cmd_fs_flist

        .export  cfl_after_name
        .export  cfl_copy_uri
        .export  cfl_done_ok
        .export  cfl_entry_loop
        .export  cfl_flist_one_page
        .export  cfl_is_long_keyword
        .export  cfl_long_entry
        .export  cfl_no_slash
        .export  cfl_page_loop
        .export  cfl_pr_chars
        .export  cfl_rxlen_ok
        .export  cfl_scan_uri_nul
        .export  cfl_tx_uri
        .export  cfl_tx_uri_done
        .export  cfl_uri_len_from_nul
        .export  cfl_uri_len_ok
        .export  cfl_use_current_uri
        .export  cfl_zterm

        .importzp aws_tmp00
        .importzp aws_tmp01
        .importzp aws_tmp02
        .importzp aws_tmp03
        .importzp aws_tmp04
        .importzp aws_tmp05
        .importzp aws_tmp06
        .importzp aws_tmp07
        .importzp aws_tmp08
        .importzp aws_tmp09
        .importzp aws_tmp12
        .importzp aws_tmp13
        .importzp pws_tmp04
        .importzp pws_tmp05
        .importzp pws_tmp06
        .importzp pws_tmp07
        .importzp pws_tmp09
        .importzp cws_tmp1
        .importzp cws_tmp2
        .importzp cws_tmp3
        .importzp cws_tmp7
        .importzp cws_tmp8

        .importzp buffer_ptr
        .importzp fuji_bus_tx_command
        .importzp fuji_bus_tx_device
        .importzp fuji_bus_tx_payload_hi
        .importzp fuji_bus_tx_payload_lo

        .import err_bad
        .import err_no_host
        .import exit_user_ok
        .import flist_resolve_target
        .import fuji_channel_scratch
        .importzp aws_tmp14
        .import fuji_current_dir_len
        .import fuji_current_fs_len
        .import fuji_current_host_len
        .import fuji_filename_buffer
        .import fuji_filename_len
        .import fujibus_receive_packet
        .import fujibus_send_packet
        .import get_fuji_fs_uri_addr_to_aws_tmp00
        .import get_fuji_host_uri_addr_to_aws_tmp00
        .import num_params
        .import param_get_string
        .import param_get_string_no_init
        .import print_char
        .import print_newline
        .import print_space
        .import print_string
        .import report_error

        .include "fujinet.inc"

        .segment "CODE"

FLIST_URI_BUFFER_SIZE   = FUJI_FS_URI_BUFFER_SIZE
; Max bytes for the variable entries blob in the ListDirectory response.
; FUJI_PWS_PACKET_SIZE (274) minus FujiBus/status (7) and list header (10).
FLIST_MAX_PAYLOAD       = 220
; Host file_commands.h: compact+sort, or sort-only for long listings
FLIST_LIST_FLAGS_COMPACT = $03
FLIST_LIST_FLAGS_LONG   = $02

; FujiBus response layout (file payload begins at buffer+7 after status bytes).
CFL_RESP_VERSION        = $07
CFL_RESP_FLAGS          = $08
CFL_RESP_ENTRY_COUNT    = $0D
CFL_RESP_ENTRIES_LEN    = $0F
CFL_RESP_ENTRIES        = $11

; fuji_channel_scratch: 0 = compact listing, non-zero = long listing (size + mtime)
; (must not use cws_tmp6/7 — clobbered by FujiBus RX and ResolvePath)

;------------------------------------------------------------------------------
; uint8_t cmd_fs_flist(void)
;------------------------------------------------------------------------------
cmd_fs_flist:
        lda     fuji_current_fs_len
        sta     aws_tmp04
        lda     fuji_current_dir_len
        sta     aws_tmp05

        lda     fuji_current_host_len
        bne     parse_flist_params
        jmp     err_no_host

parse_flist_params:
        lda     #$00
        sta     fuji_channel_scratch        ; compact by default

        jsr     num_params
        sta     cws_tmp7
        bne     cfl_dispatch_params
        jmp     cfl_use_current_uri
cfl_dispatch_params:

        cmp     #$03
        bcs     err_bad_flist_syntax

        cmp     #$02
        beq     cfl_parse_path_long

        ; exactly one parameter
        clc
        jsr     param_get_string
        sta     fuji_filename_len
        jsr     cfl_is_long_keyword
        bcc     cfl_one_param_long

        jsr     flist_resolve_target
        bcs     err_bad_flist_path
        jmp     cfl_start_list_restore

cfl_one_param_long:
        lda     #$01
        sta     fuji_channel_scratch
        jmp     cfl_use_current_uri

cfl_parse_path_long:
        clc
        jsr     param_get_string
        sta     fuji_filename_len
        jsr     flist_resolve_target
        bcs     err_bad_flist_path

        ; Continue from after the path token (param_get_string re-inits GS).
        jsr     param_get_string_no_init
        sta     fuji_filename_len
        jsr     cfl_is_long_keyword
        bcs     err_bad_flist_arg

        lda     #$01
        sta     fuji_channel_scratch
        jmp     cfl_start_list_restore

err_bad_flist_syntax:
        jsr     report_error
        .byte   $CB
        .byte   "FLS [path] [LONG]", 0

err_bad_flist_path:
        jsr     err_bad
        .byte   $CB
        .byte   "path", 0

err_bad_flist_arg:
        jsr     err_bad
        .byte   $CB
        .byte   "LONG", 0

;------------------------------------------------------------------------------
; C=0 if fuji_filename_buffer holds the keyword LONG (length must be 4).
;------------------------------------------------------------------------------
cfl_is_long_keyword:
        lda     fuji_filename_len
        cmp     #$04
        bne     cfl_not_long_kw

        ldy     #$00
        lda     fuji_filename_buffer,y
        and     #$DF
        cmp     #'L'
        bne     cfl_not_long_kw
        iny
        lda     fuji_filename_buffer,y
        and     #$DF
        cmp     #'O'
        bne     cfl_not_long_kw
        iny
        lda     fuji_filename_buffer,y
        and     #$DF
        cmp     #'N'
        bne     cfl_not_long_kw
        iny
        lda     fuji_filename_buffer,y
        and     #$DF
        cmp     #'G'
        bne     cfl_not_long_kw

        clc
        rts

cfl_not_long_kw:
        sec
        rts

;------------------------------------------------------------------------------
; Use canonical current URI (no path argument).
;------------------------------------------------------------------------------
cfl_use_current_uri:
        lda     fuji_current_host_len
        cmp     #FLIST_URI_BUFFER_SIZE
        bcs     err_bad_flist_path

        sta     fuji_current_fs_len

        jsr     get_fuji_fs_uri_addr_to_aws_tmp00
        sta     aws_tmp03
        lda     aws_tmp00
        sta     aws_tmp02

        jsr     get_fuji_host_uri_addr_to_aws_tmp00

        ldy     #$00
cfl_copy_uri:
        cpy     fuji_current_fs_len
        beq     cfl_zterm
        lda     (aws_tmp00),y
        sta     (aws_tmp02),y
        iny
        bne     cfl_copy_uri

cfl_zterm:
        lda     #$00
        sta     (aws_tmp02),y

cfl_start_list_restore:
        lda     #$00
        sta     pws_tmp04
        sta     pws_tmp05

cfl_page_loop:
        jsr     cfl_flist_one_page
        bcc     cfl_page_ok

cfl_page_fail:
        jsr     report_error
        .byte   $CB
        .byte   "Dir list err", 0

cfl_page_ok:
        lda     pws_tmp06
        ora     pws_tmp07
        beq     cfl_done_ok

        lda     pws_tmp06
        clc
        adc     pws_tmp04
        sta     pws_tmp04
        lda     pws_tmp07
        adc     pws_tmp05
        sta     pws_tmp05

        lda     pws_tmp09
        bne     cfl_page_loop

cfl_done_ok:
        lda     aws_tmp04
        sta     fuji_current_fs_len
        lda     aws_tmp05
        sta     fuji_current_dir_len

        jmp     exit_user_ok


;------------------------------------------------------------------------------
; One ListDirectory page. Input: start_index in pws_tmp04/pws_tmp05;
; listing mode in fuji_channel_scratch.
; Output: C=0 ok / C=1 fail; pws_tmp06/07 = this page entry count
;         pws_tmp09 = more pages (0/1)
;------------------------------------------------------------------------------
cfl_flist_one_page:
        lda     fuji_current_fs_len
        sta     cws_tmp8

        jsr     get_fuji_fs_uri_addr_to_aws_tmp00

        lda     aws_tmp00
        sta     aws_tmp06
        lda     aws_tmp01
        sta     aws_tmp07

        ldy     #$00
cfl_scan_uri_nul:
        lda     (aws_tmp00),y
        beq     cfl_uri_len_from_nul
        iny
        cpy     cws_tmp8
        bcc     cfl_scan_uri_nul

        lda     cws_tmp8
        sta     cws_tmp1
        jmp     cfl_uri_len_ok

cfl_uri_len_from_nul:
        sty     cws_tmp1

cfl_uri_len_ok:
        lda     cws_tmp1
        bne     has_length

        sec
        rts

has_length:
        ldy     #$06
        lda     #FN_PROTOCOL_VERSION
        sta     (buffer_ptr),y
        iny
        lda     cws_tmp1
        sta     (buffer_ptr),y
        iny
        lda     #$00
        sta     (buffer_ptr),y

        lda     buffer_ptr
        clc
        adc     #$09
        sta     aws_tmp00
        lda     buffer_ptr+1
        adc     #$00
        sta     aws_tmp01

        ldy     #$00
cfl_tx_uri:
        cpy     cws_tmp1
        beq     cfl_tx_uri_done
        lda     (aws_tmp06),y
        sta     (aws_tmp00),y
        iny
        bne     cfl_tx_uri

cfl_tx_uri_done:
        lda     aws_tmp00
        clc
        adc     cws_tmp1
        sta     aws_tmp00
        lda     aws_tmp01
        adc     #$00
        sta     aws_tmp01

        ldy     #$00
        lda     pws_tmp04
        sta     (aws_tmp00),y
        iny
        lda     pws_tmp05
        sta     (aws_tmp00),y
        iny
        lda     #<FLIST_MAX_PAYLOAD
        sta     (aws_tmp00),y
        iny
        lda     #>FLIST_MAX_PAYLOAD
        sta     (aws_tmp00),y
        iny
        lda     fuji_channel_scratch
        beq     cfl_flags_compact
        lda     #FLIST_LIST_FLAGS_LONG
        bne     cfl_flags_store
cfl_flags_compact:
        lda     #FLIST_LIST_FLAGS_COMPACT
cfl_flags_store:
        sta     (aws_tmp00),y

        lda     cws_tmp1
        clc
        adc     #8
        sta     aws_tmp12
        lda     #$00
        adc     #$00
        sta     aws_tmp13

        lda     #FN_DEVICE_FILE
        sta     fuji_bus_tx_device

        lda     #FILE_CMD_LIST_DIRECTORY
        sta     fuji_bus_tx_command

        lda     buffer_ptr
        clc
        adc     #$06
        sta     fuji_bus_tx_payload_lo
        lda     buffer_ptr+1
        adc     #$00
        sta     fuji_bus_tx_payload_hi

        lda     aws_tmp12
        ldx     aws_tmp13
        jsr     fujibus_send_packet

        jsr     fujibus_receive_packet
        sta     aws_tmp12
        stx     aws_tmp13

        lda     aws_tmp12
        ora     aws_tmp13
        beq     cfl_fail_c1

        lda     aws_tmp13
        bne     cfl_rxlen_ok
        lda     aws_tmp12
        cmp     #17
        bcs     cfl_rxlen_ok

cfl_fail_c1:
        sec
        rts

cfl_rxlen_ok:
        ldy     #$05
        lda     (buffer_ptr),y
        cmp     #$01
        bne     cfl_fail_c1

        ldy     #$06
        lda     (buffer_ptr),y
        bne     cfl_fail_c1

        ldy     #CFL_RESP_VERSION
        lda     (buffer_ptr),y
        cmp     #FN_PROTOCOL_VERSION
        bne     cfl_fail_c1

        ldy     #CFL_RESP_FLAGS
        lda     (buffer_ptr),y
        and     #$01
        sta     pws_tmp09

        ldy     #CFL_RESP_ENTRY_COUNT
        lda     (buffer_ptr),y
        sta     pws_tmp06
        iny
        lda     (buffer_ptr),y
        sta     pws_tmp07

        lda     pws_tmp06
        sta     cws_tmp2
        lda     pws_tmp07
        sta     cws_tmp3

        ; entries blob end = buffer + CFL_RESP_ENTRIES + entriesLen
        lda     buffer_ptr
        clc
        adc     #CFL_RESP_ENTRIES
        sta     aws_tmp00
        lda     buffer_ptr+1
        adc     #$00
        sta     aws_tmp01

        ldy     #CFL_RESP_ENTRIES_LEN
        lda     (buffer_ptr),y
        clc
        adc     aws_tmp00
        sta     aws_tmp12
        lda     aws_tmp01
        adc     #$00
        sta     aws_tmp13
        iny
        lda     (buffer_ptr),y
        adc     aws_tmp13
        sta     aws_tmp13
        bcc     :+
        inc     aws_tmp12
:
        ; rewind aws_tmp00 to first entry for the loop
        lda     buffer_ptr
        clc
        adc     #CFL_RESP_ENTRIES
        sta     aws_tmp00
        lda     buffer_ptr+1
        adc     #$00
        sta     aws_tmp01

cfl_entry_loop:
        lda     cws_tmp2
        ora     cws_tmp3
        bne     cfl_entry_has_count

        clc
        rts

cfl_entry_has_count:
        lda     aws_tmp00
        cmp     aws_tmp12
        lda     aws_tmp01
        sbc     aws_tmp13
        bcc     @entry_in_blob
        clc
        rts

@entry_in_blob:
        ldy     #$00
        lda     (aws_tmp00),y
        and     #$01
        sta     cws_tmp8

        ldy     #$01
        lda     (aws_tmp00),y
        sta     cws_tmp1

        lda     fuji_channel_scratch
        bne     cfl_long_entry

        lda     aws_tmp00
        clc
        adc     #$02
        sta     aws_tmp08
        lda     aws_tmp01
        adc     #$00
        sta     aws_tmp09

        ldy     #$00
cfl_pr_chars:
        lda     cws_tmp1
        beq     cfl_after_name
        lda     (aws_tmp08),y
        jsr     print_char
        inc     aws_tmp08
        bne     :+
        inc     aws_tmp09
:
        dec     cws_tmp1
        jmp     cfl_pr_chars

cfl_after_name:
        lda     cws_tmp8
        beq     cfl_no_slash
        lda     #'/'
        jsr     print_char
cfl_no_slash:
        jsr     cfl_print_crlf
        jmp     cfl_entry_advance

;------------------------------------------------------------------------------
; Long listing: FILE/DIR prefix, decimal size, decimal unix time, then name.
; Entry layout at aws_tmp00: flags, nameLen, name[], u64 size, u64 mtime.
;------------------------------------------------------------------------------
cfl_long_entry:
        lda     cws_tmp8
        beq     cfl_long_file
        jsr     print_string
        .byte   "DIR ", 0
        jmp     cfl_long_kind_done
cfl_long_file:
        jsr     print_string
        .byte   "FILE ", 0
cfl_long_kind_done:
        lda     aws_tmp00
        clc
        adc     #$02
        sta     aws_tmp08
        lda     aws_tmp01
        adc     #$00
        sta     aws_tmp09

        lda     cws_tmp1
        clc
        adc     aws_tmp08
        sta     aws_tmp08
        lda     #$00
        adc     aws_tmp09
        sta     aws_tmp09

        ldy     #$00
        jsr     cfl_print_u64le

        jsr     print_space

        lda     aws_tmp08
        clc
        adc     #$08
        sta     aws_tmp08
        lda     aws_tmp09
        adc     #$00
        sta     aws_tmp09

        ldy     #$00
        jsr     cfl_print_u64le

        jsr     print_space

        lda     aws_tmp00
        clc
        adc     #$02
        sta     aws_tmp08
        lda     aws_tmp01
        adc     #$00
        sta     aws_tmp09

        ldy     #$00
cfl_long_name:
        lda     cws_tmp1
        beq     cfl_long_name_done
        lda     (aws_tmp08),y
        jsr     print_char
        inc     aws_tmp08
        bne     :+
        inc     aws_tmp09
:
        dec     cws_tmp1
        jmp     cfl_long_name

cfl_long_name_done:
        jsr     cfl_print_crlf

;------------------------------------------------------------------------------
cfl_print_crlf:
        jmp     print_newline

cfl_entry_advance:
        lda     aws_tmp00
        clc
        adc     #$02
        sta     aws_tmp08
        lda     aws_tmp01
        adc     #$00
        sta     aws_tmp09

        lda     cws_tmp1
        clc
        adc     aws_tmp08
        sta     aws_tmp00
        lda     #$00
        adc     aws_tmp01
        sta     aws_tmp01

        ; Use the requested listing mode (response flags may not be trustworthy here).
        lda     fuji_channel_scratch
        beq     cfl_dec_entry_count

        lda     aws_tmp00
        clc
        adc     #16
        sta     aws_tmp00
        lda     aws_tmp01
        adc     #$00
        sta     aws_tmp01

cfl_dec_entry_count:
        lda     cws_tmp2
        bne     :+
        dec     cws_tmp3
:
        dec     cws_tmp2

        jmp     cfl_entry_loop


; Binary u64 scratch follows the 20-digit BCD block in fuji_filename_buffer.
CFL_U64_BIN = $14
CFL_U64_BCD_DIGITS = $14

;------------------------------------------------------------------------------
; Print unsigned 64-bit little-endian value at (aws_tmp08),Y as decimal.
; Uses fuji_filename_buffer[0..19] for BCD and [20..27] for the binary value.
;------------------------------------------------------------------------------
cfl_print_u64le:
        sty     aws_tmp14

        ldy     #$00
cfl_u64_copy:
        lda     (aws_tmp08),y
        sta     fuji_filename_buffer + CFL_U64_BIN,y
        iny
        cpy     #$08
        bcc     cfl_u64_copy

        ldx     #CFL_U64_BCD_DIGITS - 1
        lda     #$00
cfl_u64_clear:
        sta     fuji_filename_buffer,x
        dex
        bpl     cfl_u64_clear

        ldx     #$40
cfl_u64_shift:
        lda     fuji_filename_buffer + CFL_U64_BIN
        asl     a
        sta     fuji_filename_buffer + CFL_U64_BIN
        rol     fuji_filename_buffer + CFL_U64_BIN + 1
        rol     fuji_filename_buffer + CFL_U64_BIN + 2
        rol     fuji_filename_buffer + CFL_U64_BIN + 3
        rol     fuji_filename_buffer + CFL_U64_BIN + 4
        rol     fuji_filename_buffer + CFL_U64_BIN + 5
        rol     fuji_filename_buffer + CFL_U64_BIN + 6
        rol     fuji_filename_buffer + CFL_U64_BIN + 7

        ldy     #$00
cfl_u64_bcd:
        lda     fuji_filename_buffer,y
        rol     a
        cmp     #$0A
        bcc     cfl_u64_bcd_ok
        sbc     #$0A
cfl_u64_bcd_ok:
        sta     fuji_filename_buffer,y
        iny
        cpy     #CFL_U64_BCD_DIGITS
        bcc     cfl_u64_bcd

        dex
        bne     cfl_u64_shift

        lda     #$00
        sta     aws_tmp14

        ldx     #$00
cfl_u64_digits:
        lda     fuji_filename_buffer,x
        ora     aws_tmp14
        sta     aws_tmp14
        beq     cfl_u64_skip_digit
        ora     #$30
        jsr     print_char
cfl_u64_skip_digit:
        inx
        cpx     #CFL_U64_BCD_DIGITS
        bcc     cfl_u64_digits

        lda     aws_tmp14
        bne     cfl_u64_done
        lda     #'0'
        jsr     print_char
cfl_u64_done:
        ldy     aws_tmp14
        rts
