; *FLIST / *FLS — list directory via FileDevice ListDirectory (hand asm)
;
;   *FLS                    formatted lines for current directory
;   *FLS <path>             formatted lines for <path>

        .export  cmd_fs_flist

        .export  cfl_copy_uri
        .export  cfl_done_ok
        .export  cfl_flist_one_page
        .export  cfl_print_formatted_blob
        .export  cfl_page_loop
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
        .import fuji_current_dir_len
        .import fuji_current_fs_len
        .import fuji_current_host_len
        .import fuji_filename_len
        .import fujibus_receive_packet
        .import fujibus_send_packet
        .import get_fuji_fs_uri_addr_to_aws_tmp00
        .import get_fuji_host_uri_addr_to_aws_tmp00
        .import num_params
        .import param_get_string
        .import print_char
        .import print_newline
        .import report_error

        .include "fujinet.inc"

        .segment "CODE"

FLIST_URI_BUFFER_SIZE      = FUJI_FS_URI_BUFFER_SIZE
; FUJI_PWS_PACKET_SIZE (274) minus FujiBus/status (7) and list header (10).
FLIST_MAX_PAYLOAD          = 220
FLIST_LIST_FLAG_SORT       = $02
FLIST_LIST_FLAG_FORMATTED  = $04
FLIST_LIST_FLAGS_FORMATTED = FLIST_LIST_FLAG_SORT | FLIST_LIST_FLAG_FORMATTED

; FujiBus response layout (file payload begins at buffer+7 after status bytes).
CFL_RESP_VERSION        = $07
CFL_RESP_FLAGS          = $08
CFL_RESP_ENTRY_COUNT    = $0D
CFL_RESP_ENTRIES_LEN    = $0F
CFL_RESP_ENTRIES        = $11

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
        jsr     num_params
        beq     cfl_use_current_uri

        cmp     #$02
        bcs     err_bad_flist_syntax

        clc
        jsr     param_get_string
        sta     fuji_filename_len
        jsr     flist_resolve_target
        bcs     err_bad_flist_path

        jmp     cfl_start_list_restore

err_bad_flist_syntax:
        jsr     report_error
        .byte   $CB
        .byte   "FLS [path]", 0

err_bad_flist_path:
        jsr     err_bad
        .byte   $CB
        .byte   "path", 0

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
; One ListDirectory page. Input: start_index in pws_tmp04/pws_tmp05.
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
        lda     #FLIST_LIST_FLAGS_FORMATTED
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

        iny                             ; y=6
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
        jsr     cfl_print_formatted_blob
        clc
        rts

;------------------------------------------------------------------------------
; Print preformatted listing text at aws_tmp00..aws_tmp12:13 ($0A = newline).
;------------------------------------------------------------------------------
cfl_print_formatted_blob:
        lda     aws_tmp00
        sta     aws_tmp08
        lda     aws_tmp01
        sta     aws_tmp09

cfl_fmt_blob_loop:
        lda     aws_tmp08
        cmp     aws_tmp12
        lda     aws_tmp09
        sbc     aws_tmp13
        bcs     cfl_fmt_blob_done

        ldy     #$00
        lda     (aws_tmp08),y
        cmp     #$0A
        beq     cfl_fmt_blob_nl
        jsr     print_char
        jmp     cfl_fmt_blob_adv

cfl_fmt_blob_nl:
        jsr     print_newline

cfl_fmt_blob_adv:
        inc     aws_tmp08
        bne     cfl_fmt_blob_loop
        inc     aws_tmp09
        jmp     cfl_fmt_blob_loop

cfl_fmt_blob_done:
        rts
