; *FLIST / *FLS — list directory via FileDevice ListDirectory (hand asm)

        .export  cmd_fs_flist

        .export  cfl_after_name
        .export  cfl_compact_skip
        .export  cfl_copy_uri
        .export  cfl_done_ok
        .export  cfl_entry_loop
        .export  cfl_flist_one_page
        .export  cfl_len_ok
        .export  cfl_no_slash
        .export  cfl_page_loop
        .export  cfl_pr_chars
        .export  cfl_rxlen_ok
        .export  cfl_scan_uri_nul
        .export  cfl_tx_uri
        .export  cfl_tx_uri_done
        .export  cfl_uri_len_from_nul
        .export  cfl_uri_len_ok
        .export  cfl_zterm

        .import  err_bad
        .import  err_no_host
        .import  exit_user_ok
        .import  flist_resolve_target
        .import  fuji_host_uri_ptr
        .import  fujibus_receive_packet
        .import  fujibus_send_packet
        .import  get_fuji_fs_uri_addr_to_aws_tmp00
        .import  get_fuji_host_uri_addr_to_aws_tmp00
        .import  param_count
        .import  param_get_string
        .import  print_char
        .import  print_newline
        .import  report_error
        .import  set_fuji_data_buffer_ptr

        .include "fujinet.inc"

        .segment "CODE"

FLIST_URI_BUFFER_SIZE   = FUJI_FS_URI_BUFFER_SIZE
FLIST_PAGE_SIZE         = 10
; Host file_commands.h: kListFlagCompactOmitMetadata | kListFlagSortByName
FLIST_LIST_FLAGS        = $03


;------------------------------------------------------------------------------
; uint8_t cmd_fs_flist(void)
;------------------------------------------------------------------------------
cmd_fs_flist:
        lda     fuji_current_host_len
        bne     parse_flist_params
        jmp     err_no_host

parse_flist_params:
        jsr     param_count
        bcc     cfl_no_param

        clc                                     ; terminate with spaces
        jsr     param_get_string
        sta     fuji_filename_len

        jsr     set_fuji_data_buffer_ptr
        jsr     flist_resolve_target
        bcc     cfl_start_list

        ; fall through to error
err_bad_flist_path:
        jsr     err_bad
        .byte   $CB
        .byte   "path", 0

cfl_no_param:
        lda     fuji_current_host_len
        cmp     #FLIST_URI_BUFFER_SIZE
        bcs     err_bad_flist_path

cfl_len_ok:
        sta     fuji_current_fs_len

        ; fs_uri into aws_tmp02/03
        jsr     get_fuji_fs_uri_addr_to_aws_tmp00
        ; A contains high byte already
        sta     aws_tmp03
        lda     aws_tmp00
        sta     aws_tmp02

        ; host_uri into aws_tmp00/01
        jsr     get_fuji_host_uri_addr_to_aws_tmp00

        ; copy fuji_current_fs_len bytes from host_uri into fs_uri
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

cfl_start_list:
        ; ListDirectory start_index (16-bit). Must not live in cws_tmp6/7 ($AD/$AE):

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
        jmp     exit_user_ok


;------------------------------------------------------------------------------
; One ListDirectory page. Input: start_index in pws_tmp04/pws_tmp05.
; Output: C=0 ok / C=1 fail; pws_tmp06/07 = this page entry count
;         pws_tmp09 = more pages (0/1); buffer_ptr aliases cws_tmp4/cws_tmp5 only.
;------------------------------------------------------------------------------
cfl_flist_one_page:
        jsr     set_fuji_data_buffer_ptr

        lda     fuji_current_fs_len
        sta     cws_tmp8

        jsr     get_fuji_fs_uri_addr_to_aws_tmp00

        ; Preserve FS URI pointer before aws_tmp00/01 are reused for packet assembly.
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

        ; error out
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

        ; aws_tmp06/07 holds FS URI
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
        lda     #FLIST_PAGE_SIZE
        sta     (aws_tmp00),y
        iny
        lda     #$00
        sta     (aws_tmp00),y
        iny
        lda     #FLIST_LIST_FLAGS
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

        ; check RX len in aws_tmp12/13
        lda     aws_tmp13
        bne     cfl_rxlen_ok
        lda     aws_tmp12
        cmp     #13
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

        ldy     #$07
        lda     (buffer_ptr),y
        cmp     #FN_PROTOCOL_VERSION
        bne     cfl_fail_c1

        ldy     #$08
        lda     (buffer_ptr),y
        sta     pws_tmp08
        and     #$01
        sta     pws_tmp09

        lda     buffer_ptr
        clc
        adc     aws_tmp12
        sta     aws_tmp02
        lda     buffer_ptr+1
        adc     aws_tmp13
        sta     aws_tmp02+1

        ldy     #$0B
        lda     (buffer_ptr),y
        sta     pws_tmp06
        iny
        lda     (buffer_ptr),y
        sta     pws_tmp07

        lda     pws_tmp06
        sta     cws_tmp2
        lda     pws_tmp07
        sta     cws_tmp3

        lda     buffer_ptr
        clc
        adc     #13
        sta     aws_tmp00
        lda     buffer_ptr+1
        adc     #$00
        sta     aws_tmp01

cfl_entry_loop:
        lda     cws_tmp2
        ora     cws_tmp3
        bne     :+

        ; successful return from cfl_flist_one_page, the only good exit
        clc
        rts

:
        ; validate not greater
        lda     aws_tmp00
        cmp     aws_tmp02
        lda     aws_tmp01
        sbc     aws_tmp02+1
        bcs     cfl_fail_c1

        ldy     #$00
        lda     (aws_tmp00),y
        and     #$01
        sta     cws_tmp8

        ldy     #$01
        lda     (aws_tmp00),y
        sta     cws_tmp1

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
        jsr     print_newline

        ldy     #$01
        lda     (aws_tmp00),y
        sta     cws_tmp1

        lda     aws_tmp00
        clc
        adc     #$02
        sta     aws_tmp08
        lda     aws_tmp01
        adc     #$00
        sta     aws_tmp09

        lda     aws_tmp08
        clc
        adc     cws_tmp1
        sta     aws_tmp00
        lda     aws_tmp09
        adc     #$00
        sta     aws_tmp01

        lda     pws_tmp08
        and     #$02
        bne     cfl_compact_skip

        lda     aws_tmp00
        clc
        adc     #16
        sta     aws_tmp00
        lda     aws_tmp01
        adc     #$00
        sta     aws_tmp01

cfl_compact_skip:
        lda     cws_tmp2
        bne     :+
        dec     cws_tmp3
:
        dec     cws_tmp2

        jmp     cfl_entry_loop
