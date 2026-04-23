; *FLIST / *FLS — list directory via FileDevice ListDirectory (hand asm)

        .export  _cmd_fs_flist
        .export  _parse_flist_params
        .export  _err_bad_flist_path
        .export  _err_flist_failed
        .export  _err_no_host_flist

        .import  err_bad
        .import  exit_user_ok
        .import  report_error
        .import  param_count
        .import  param_get_string

        .import  _fuji_data_buffer_ptr
        .import  _fujibus_receive_packet
        .import  _fujibus_send_packet

        .import  get_fuji_fs_uri_addr_to_aws_tmp6
        .import  get_fuji_host_uri_addr_to_aws_tmp6

        .import  print_char
        .import  print_newline

        .import  pusha
        .import  pushax

        .import  fuji_filename_len
        .import  fuji_current_fs_len
        .import  fuji_current_host_len

        .importzp  ptr1
        .importzp  ptr2
        .importzp  buffer_ptr
        .importzp  aws_tmp06
        .importzp  aws_tmp07
        .importzp  aws_tmp08
        .importzp  aws_tmp09
        .importzp  aws_tmp10
        .importzp  aws_tmp11
        .importzp  aws_tmp12
        .importzp  aws_tmp13
        .importzp  cws_tmp1
        .importzp  cws_tmp2
        .importzp  cws_tmp3
        .importzp  cws_tmp4
        .importzp  cws_tmp5
        .importzp  cws_tmp6
        .importzp  cws_tmp7
        .importzp  cws_tmp8

        .include "fujinet.inc"

        .segment "CODE"

FLIST_URI_BUFFER_SIZE   = FUJI_FS_URI_BUFFER_SIZE
FLIST_PAGE_SIZE         = 10
; compact (omit per-entry metadata) | sort by basename
FLIST_LIST_FLAGS        = $03


_err_no_host_flist:
        jsr     report_error
        .byte   $CB
        .byte   "No host set", 0

_err_bad_flist_path:
        jsr     err_bad
        .byte   $CB
        .byte   "path", 0

;------------------------------------------------------------------------------
; uint8_t cmd_fs_flist(void)
;------------------------------------------------------------------------------
_cmd_fs_flist:
        lda     fuji_current_host_len
        beq     _err_no_host_flist

@have_host:
        cmp     #FLIST_URI_BUFFER_SIZE
        bcs     _err_bad_flist_path

@len_ok:
        sta     fuji_current_fs_len

        jsr     get_fuji_fs_uri_addr_to_aws_tmp6
        lda     aws_tmp06
        sta     ptr2
        lda     aws_tmp07
        sta     ptr2+1

        jsr     get_fuji_host_uri_addr_to_aws_tmp6

        ldy     #$00
@copy_uri:
        cpy     fuji_current_fs_len
        beq     @zterm
        lda     (aws_tmp06),y
        sta     (ptr2),y
        iny
        bne     @copy_uri

@zterm:
        lda     #$00
        sta     (ptr2),y

        jsr     print_newline

        lda     #$00
        sta     cws_tmp6
        sta     cws_tmp7

@page_loop:
        jsr     @flist_one_page
        cmp     #$00
        beq     @page_fail

        lda     aws_tmp10
        ora     aws_tmp11
        beq     @done_ok

        lda     aws_tmp10
        clc
        adc     cws_tmp6
        sta     cws_tmp6
        lda     aws_tmp11
        adc     cws_tmp7
        sta     cws_tmp7

        lda     cws_tmp4
        bne     @page_loop

@done_ok:
        jmp     exit_user_ok

@page_fail:
        jmp     _err_flist_failed

;------------------------------------------------------------------------------
; One ListDirectory page. Input: start_index in cws_tmp6/7.
; Output: A=1 ok / A=0 fail; aws_tmp10/11 = returned count;
;         cws_tmp4 = more (0/1); uses buffer_ptr packet buffer.
;------------------------------------------------------------------------------
@flist_one_page:
        jsr     _fuji_data_buffer_ptr

        lda     fuji_current_fs_len
        sta     cws_tmp1

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
        sta     ptr1
        lda     buffer_ptr+1
        adc     #$00
        sta     ptr1+1

        jsr     get_fuji_fs_uri_addr_to_aws_tmp6

        ldy     #$00
@tx_uri:
        cpy     cws_tmp1
        beq     @tx_uri_done
        lda     (aws_tmp06),y
        sta     (ptr1),y
        iny
        bne     @tx_uri

@tx_uri_done:
        lda     ptr1
        clc
        adc     cws_tmp1
        sta     ptr1
        lda     ptr1+1
        adc     #$00
        sta     ptr1+1

        ldy     #$00
        lda     cws_tmp6
        sta     (ptr1),y
        iny
        lda     cws_tmp7
        sta     (ptr1),y
        iny
        lda     #FLIST_PAGE_SIZE
        sta     (ptr1),y
        iny
        lda     #$00
        sta     (ptr1),y
        iny
        lda     #FLIST_LIST_FLAGS
        sta     (ptr1),y

        lda     cws_tmp1
        clc
        adc     #8
        sta     aws_tmp12
        lda     #$00
        adc     #$00
        sta     aws_tmp13

        lda     #FN_DEVICE_FILE
        jsr     pusha

        lda     #FILE_CMD_LIST_DIRECTORY
        jsr     pusha

        lda     buffer_ptr
        clc
        adc     #$06
        sta     cws_tmp2
        lda     buffer_ptr+1
        adc     #$00
        sta     cws_tmp3
        lda     cws_tmp2
        ldx     cws_tmp3
        jsr     pushax

        lda     aws_tmp12
        ldx     aws_tmp13
        jsr     _fujibus_send_packet

        jsr     _fujibus_receive_packet
        sta     aws_tmp12
        stx     aws_tmp13

        lda     aws_tmp12
        ora     aws_tmp13
        bne     :+
        jmp     @fail_a0
:

        lda     aws_tmp13
        bne     @rxlen_ok
        lda     aws_tmp12
        cmp     #13
        bcs     :+
        jmp     @fail_a0
:

@rxlen_ok:
        ldy     #$05
        lda     (buffer_ptr),y
        cmp     #$01
        beq     :+
        jmp     @fail_a0
:

        ldy     #$06
        lda     (buffer_ptr),y
        beq     :+
        jmp     @fail_a0
:

        ldy     #$07
        lda     (buffer_ptr),y
        cmp     #FN_PROTOCOL_VERSION
        beq     :+
        jmp     @fail_a0
:

        ldy     #$08
        lda     (buffer_ptr),y
        sta     cws_tmp5
        and     #$01
        sta     cws_tmp4

        lda     buffer_ptr
        clc
        adc     aws_tmp12
        sta     ptr2
        lda     buffer_ptr+1
        adc     aws_tmp13
        sta     ptr2+1

        ldy     #$0B
        lda     (buffer_ptr),y
        sta     aws_tmp10
        iny
        lda     (buffer_ptr),y
        sta     aws_tmp11

        lda     aws_tmp10
        sta     cws_tmp2
        lda     aws_tmp11
        sta     cws_tmp3

        lda     buffer_ptr
        clc
        adc     #13
        sta     ptr1
        lda     buffer_ptr+1
        adc     #$00
        sta     ptr1+1

@entry_loop:
        lda     cws_tmp2
        ora     cws_tmp3
        bne     :+
        jmp     @entries_done
:

        lda     ptr1
        cmp     ptr2
        lda     ptr1+1
        sbc     ptr2+1
        bcc     :+
        jmp     @fail_a0
:

        ldy     #$00
        lda     (ptr1),y
        and     #$01
        sta     cws_tmp8

        ldy     #$01
        lda     (ptr1),y
        sta     cws_tmp1

        lda     ptr1
        clc
        adc     #$02
        sta     aws_tmp08
        lda     ptr1+1
        adc     #$00
        sta     aws_tmp09

        ldy     #$00
@pr_chars:
        lda     cws_tmp1
        beq     @after_name
        lda     (aws_tmp08),y
        jsr     print_char
        inc     aws_tmp08
        bne     :+
        inc     aws_tmp09
:
        dec     cws_tmp1
        jmp     @pr_chars

@after_name:
        lda     cws_tmp8
        beq     @no_slash
        lda     #'/'
        jsr     print_char
@no_slash:
        jsr     print_newline

        ldy     #$01
        lda     (ptr1),y
        sta     cws_tmp1

        lda     ptr1
        clc
        adc     #$02
        sta     aws_tmp08
        lda     ptr1+1
        adc     #$00
        sta     aws_tmp09

        lda     aws_tmp08
        clc
        adc     cws_tmp1
        sta     ptr1
        lda     aws_tmp09
        adc     #$00
        sta     ptr1+1

        lda     cws_tmp5
        and     #$02
        bne     @compact_skip

        lda     ptr1
        clc
        adc     #16
        sta     ptr1
        lda     ptr1+1
        adc     #$00
        sta     ptr1+1

@compact_skip:
        lda     cws_tmp2
        bne     :+
        dec     cws_tmp3
:
        dec     cws_tmp2

        jmp     @entry_loop

@entries_done:
        lda     #$01
        rts

@fail_a0:
        lda     #$00
        rts

;------------------------------------------------------------------------------
; uint8_t parse_flist_params()
;------------------------------------------------------------------------------
_parse_flist_params:
        jsr     param_count
        bcs     @read_string

        lda     #$00
        tax
        rts

@read_string:
        clc
        jsr     param_get_string
        sta     fuji_filename_len
        lda     #$01
        rts

_err_flist_failed:
        jsr     report_error
        .byte   $CB
        .byte   "Directory list failed", 0
