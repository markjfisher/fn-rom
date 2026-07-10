        .export  cmd_fs_flist

        .export  cfl_done_ok
        .export  cfl_flist_one_page
        .export  cfl_print_formatted_blob
        .export  cfl_page_loop
        .export  cfl_rxlen_ok
        .export  cfl_tx_uri
        .export  cfl_tx_uri_done
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
        .importzp buffer_ptr
        .importzp fuji_bus_tx_command
        .importzp fuji_bus_tx_device
        .importzp fuji_bus_tx_payload_hi
        .importzp fuji_bus_tx_payload_lo

        .import err_bad
        .import err_syntax
        .import exit_user_ok
        .import fuji_current_dir_len
        .import fuji_current_fs_len
        .import fuji_filename_buffer
        .import fuji_filename_len
        .import fujibus_receive_packet
        .import fujibus_set_payload_buffer_ptr
        .import fujibus_send_packet
        .import get_fuji_fs_uri_addr_to_aws_tmp00
        .import param_count
        .import param_get_string
        .import print_char
        .import print_newline
        .import report_error

        .include "fujinet.inc"

        ; Self-register into the command group (Lever B). Present iff this
        ; module is linked (UTILITIES=resident) -- no .if in the command table.
        cmd_entry "FUTILS_EXT", "LS",      $7, $00, cmd_fs_flist     ; (<path>)
        cmd_entry "FUTILS_EXT", "LIST",    $7, $00, cmd_fs_flist     ; (<path>)

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

; *FLIST / *FLS — list directory via FileDevice ListDirectory
;
;   *FLS                    formatted lines for current directory
;   *FLS <path>             formatted lines for <path>

cmd_fs_flist:
        lda     fuji_current_fs_len
        sta     aws_tmp04
        lda     fuji_current_dir_len
        sta     aws_tmp05

        jsr     param_count             ; 0-1 params, C=0 means 0 params
        bcc     cfl_use_current_uri

one_param:
        jsr     param_get_string
        sta     fuji_filename_len
        jsr     cfl_copy_arg_uri
        bcc     cfl_start_list_restore

err_bad_flist_path:
        jsr     err_bad
        .byte   $CB
        .byte   "path", 0

;------------------------------------------------------------------------------
; Use current HOST stored in FujiNet (no path argument): send empty spec.
;------------------------------------------------------------------------------
cfl_use_current_uri:
        lda     #$00
        sta     fuji_current_fs_len
        jsr     get_fuji_fs_uri_addr_to_aws_tmp00
        ldy     #$00
        lda     #$00
        sta     (aws_tmp00),y
        beq     cfl_start_list_restore

;------------------------------------------------------------------------------
; Copy raw path/URI argument into the FS URI buffer.
;------------------------------------------------------------------------------
cfl_copy_arg_uri:
        lda     fuji_filename_len
        cmp     #FLIST_URI_BUFFER_SIZE
        bcs     cfl_arg_bad
        sta     fuji_current_fs_len
        jsr     get_fuji_fs_uri_addr_to_aws_tmp00
        ldy     #$00
@copy:
        cpy     fuji_filename_len
        beq     cfl_arg_zterm
        lda     fuji_filename_buffer,y
        sta     (aws_tmp00),y
        iny
        bne     @copy
cfl_zterm:
cfl_arg_zterm:
        lda     #$00
        sta     (aws_tmp00),y
        clc
        rts
cfl_arg_bad:
        sec
        rts

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
        .byte   "List err", 0

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
        sta     aws_tmp12

        jsr     get_fuji_fs_uri_addr_to_aws_tmp00

        lda     aws_tmp00
        sta     aws_tmp06
        lda     aws_tmp01
        sta     aws_tmp07

        ldy     #$06
        lda     #FN_PROTOCOL_VERSION
        sta     (buffer_ptr),y
        iny
        lda     aws_tmp12
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
        cpy     aws_tmp12
        beq     cfl_tx_uri_done
        lda     (aws_tmp06),y
        sta     (aws_tmp00),y
        iny
        bne     cfl_tx_uri

cfl_tx_uri_done:
        lda     aws_tmp00
        clc
        adc     aws_tmp12
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

        lda     aws_tmp12
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

        jsr     fujibus_set_payload_buffer_ptr

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
cfl_fmt_blob_loop:
        lda     aws_tmp00
        cmp     aws_tmp12
        lda     aws_tmp01
        sbc     aws_tmp13
        bcs     cfl_fmt_blob_done

        ldy     #$00
        lda     (aws_tmp00),y
        cmp     #$0A
        beq     cfl_fmt_blob_nl
        jsr     print_char
        bne     cfl_fmt_blob_adv        ; always. A is restored last, and is not 0

cfl_fmt_blob_nl:
        jsr     print_newline

cfl_fmt_blob_adv:
        inc     aws_tmp00
        bne     cfl_fmt_blob_loop
        inc     aws_tmp01
        bne     cfl_fmt_blob_loop       ; always, the upper byte can never roll over to 00

cfl_fmt_blob_done:
        rts
