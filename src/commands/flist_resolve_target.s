; Resolve host URI + relative path from FUJI_FILENAME_BUFFER ($1000) via FileDevice
; ResolvePath. Caller sets fuji_filename_len and filename bytes.

        .export  flist_resolve_target

        .import  fujibus_receive_packet
        .import  fujibus_send_packet

        .import  get_fuji_fs_uri_addr_to_aws_tmp00
        .import  get_fuji_host_uri_addr_to_aws_tmp00

        .importzp  buffer_ptr
        .importzp  aws_tmp06
        .importzp  cws_tmp1
        .importzp  cws_tmp2
        .importzp  cws_tmp3
        .importzp  cws_tmp6
        .importzp  cws_tmp7
        .importzp  cws_tmp8

        .import  fuji_current_fs_len
        .import  fuji_current_host_len
        .import  fuji_filename_len

        .include "fujinet.inc"

        .segment "CODE"

FUJI_FILENAME_BUF     = $1000

;   Success: C=0, failure C=1

flist_resolve_target:
        lda     fuji_current_host_len
        bne     @got_host
        sec                                     ; C=1 is an error
        rts

@got_host:
        sta     cws_tmp1

        lda     fuji_filename_len
        sta     cws_tmp8

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
        sta     cws_tmp2
        lda     buffer_ptr+1
        adc     #$00
        sta     cws_tmp3

        jsr     get_fuji_host_uri_addr_to_aws_tmp00

        ldy     #$00
@copy_base:
        cpy     cws_tmp1
        beq     @after_base
        lda     (aws_tmp00),y
        sta     (cws_tmp2),y
        iny
        bne     @copy_base

@after_base:
        lda     cws_tmp8
        sta     (cws_tmp2),y

        iny
        lda     #$00
        sta     (cws_tmp2),y

        lda     cws_tmp2
        clc
        adc     cws_tmp1
        adc     #$02
        sta     cws_tmp2
        lda     cws_tmp3
        adc     #$00
        sta     cws_tmp3

        ldy     #$00
@copy_fn:
        cpy     cws_tmp8
        beq     @compute_paylen
        lda     FUJI_FILENAME_BUF,y
        sta     (cws_tmp2),y
        iny
        bne     @copy_fn

@compute_paylen:
        lda     #$05
        clc
        adc     cws_tmp1
        sta     cws_tmp6
        lda     #$00
        adc     #$00
        sta     cws_tmp7

        lda     cws_tmp6
        clc
        adc     cws_tmp8
        sta     cws_tmp6
        lda     cws_tmp7
        adc     #$00
        sta     cws_tmp7

        lda     #FN_DEVICE_FILE
        sta     fuji_bus_tx_device

        lda     #FILE_CMD_RESOLVE_PATH
        sta     fuji_bus_tx_command

        lda     buffer_ptr
        clc
        adc     #$06
        sta     fuji_bus_tx_payload_lo
        lda     buffer_ptr+1
        adc     #$00
        sta     fuji_bus_tx_payload_hi

        lda     cws_tmp6
        ldx     cws_tmp7
        jsr     fujibus_send_packet

        jsr     fujibus_receive_packet

        cpx     #$00
        bne     @recv_ok
        cmp     #$00
        beq     @fail

        cmp     #$0D
        bcs     @recv_ok

@fail:
        sec
        rts

@recv_ok:
        ldy     #$05
        lda     (buffer_ptr),y
        cmp     #$01
        bne     @fail

        ldy     #$06
        lda     (buffer_ptr),y
        bne     @fail

        ldy     #$07
        lda     (buffer_ptr),y
        cmp     #FN_PROTOCOL_VERSION
        bne     @fail

        ldy     #$08
        lda     (buffer_ptr),y
        and     #$03
        cmp     #$03
        bne     @fail

        ldy     #$0C
        lda     (buffer_ptr),y
        bne     @fail

        ldy     #$0B
        lda     (buffer_ptr),y
        cmp     #FUJI_FS_URI_BUFFER_SIZE
        bcs     @fail

        sta     fuji_current_fs_len

        lda     buffer_ptr
        clc
        adc     #$0D
        sta     cws_tmp2
        lda     buffer_ptr+1
        adc     #$00
        sta     cws_tmp3

        jsr     get_fuji_fs_uri_addr_to_aws_tmp00

        ldy     #$00
@copy_fs:
        cpy     fuji_current_fs_len
        beq     @nul_term
        lda     (cws_tmp2),y
        sta     (aws_tmp00),y
        iny
        bne     @copy_fs

@nul_term:
        cpy     #FUJI_FS_URI_BUFFER_SIZE
        bcs     @success
        lda     #$00
        sta     (aws_tmp06),y

@success:
        clc
        rts
