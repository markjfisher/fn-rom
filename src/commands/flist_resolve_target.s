; Resolve host URI + relative path from FUJI_FILENAME_BUFFER ($1000) via FileDevice
; ResolvePath. Caller sets fuji_filename_len and filename bytes.

        .export  flist_resolve_target

        .export  frt_after_base
        .export  frt_compute_paylen
        .export  frt_copy_base
        .export  frt_copy_fn
        .export  frt_copy_fs
        .export  frt_fail
        .export  frt_got_host
        .export  frt_nul_term
        .export  frt_recv_ok
        .export  frt_success

        .importzp aws_tmp00
        .importzp aws_tmp01
        .importzp aws_tmp02
        .importzp aws_tmp03
        .importzp cws_tmp1
        .importzp cws_tmp2
        .importzp cws_tmp3
        .importzp cws_tmp6
        .importzp cws_tmp7
        .importzp cws_tmp8

        .importzp buffer_ptr
        .importzp fuji_bus_tx_command
        .importzp fuji_bus_tx_device
        .importzp fuji_bus_tx_payload_hi
        .importzp fuji_bus_tx_payload_lo

        .import copy_aws_tmp00_to_aws_tmp02_a
        .import fuji_current_dir_len
        .import fuji_current_fs_len
        .import fuji_current_host_len
        .import fuji_filename_buffer
        .import fuji_filename_len
        .import fujibus_receive_packet
        .import fujibus_set_payload_buffer_ptr
        .import fujibus_send_packet
        .import get_fuji_fs_uri_addr_to_aws_tmp00
        .import get_fuji_host_uri_addr_to_aws_tmp00

        .include "fujinet.inc"

        .segment "CODE"

;   Success: C=0, failure C=1

flist_resolve_target:
        lda     fuji_current_host_len
        bne     frt_got_host
        sec
        rts

frt_got_host:
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

        lda     cws_tmp2
        sta     aws_tmp02
        lda     cws_tmp3
        sta     aws_tmp03
        lda     cws_tmp1
frt_copy_base:
        jsr     copy_aws_tmp00_to_aws_tmp02_a

frt_after_base:
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
frt_copy_fn:
        cpy     cws_tmp8
        beq     frt_compute_paylen
        lda     fuji_filename_buffer,y
        sta     (cws_tmp2),y
        iny
        bne     frt_copy_fn

frt_compute_paylen:
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

        jsr     fujibus_set_payload_buffer_ptr

        lda     cws_tmp6
        ldx     cws_tmp7
        jsr     fujibus_send_packet

        jsr     fujibus_receive_packet

        cpx     #$00
        bne     frt_recv_ok
        cmp     #$00
        beq     frt_fail

        cmp     #$0D
        bcs     frt_recv_ok

frt_fail:
        sec
        rts

frt_recv_ok:
        ldy     #$05
        lda     (buffer_ptr),y
        cmp     #$01
        bne     frt_fail

        ldy     #$06
        lda     (buffer_ptr),y
        bne     frt_fail

        ldy     #$07
        lda     (buffer_ptr),y
        cmp     #FN_PROTOCOL_VERSION
        bne     frt_fail

        ldy     #$08
        lda     (buffer_ptr),y
        and     #$03
        cmp     #$03
        bne     frt_fail

        ; ResolvePath response:
        ;   +7  version
        ;   +8  flags
        ;   +9  reserved (u16)
        ;   +11 resolvedUriLen (u16)
        ;   +13 resolvedUri bytes
        ;   +13+resolvedUriLen displayPathLen (u16)
        ;   +15+resolvedUriLen displayPath bytes

        ldy     #$0B
        lda     (buffer_ptr),y          ; resolvedUriLen low
        sta     fuji_current_fs_len
        iny
        lda     (buffer_ptr),y          ; resolvedUriLen high
        bne     frt_fail

        lda     fuji_current_fs_len
        cmp     #FUJI_FS_URI_BUFFER_SIZE
        bcs     frt_fail

        lda     buffer_ptr
        clc
        adc     #$0D                    ; start of resolvedUri bytes
        sta     cws_tmp2
        lda     buffer_ptr+1
        adc     #$00
        sta     cws_tmp3

        jsr     get_fuji_fs_uri_addr_to_aws_tmp00

        lda     aws_tmp00
        sta     aws_tmp02
        lda     aws_tmp01
        sta     aws_tmp03
        lda     cws_tmp2
        sta     aws_tmp00
        lda     cws_tmp3
        sta     aws_tmp01

        lda     fuji_current_fs_len
frt_copy_fs:
        jsr     copy_aws_tmp00_to_aws_tmp02_a

frt_nul_term:
        cpy     #FUJI_FS_URI_BUFFER_SIZE
        bcs     frt_success
        lda     #$00
        sta     (aws_tmp02),y

        ; Read displayPathLen (u16le) immediately after resolvedUri bytes.
        lda     cws_tmp2
        clc
        adc     fuji_current_fs_len
        sta     cws_tmp2
        lda     cws_tmp3
        adc     #$00
        sta     cws_tmp3

        ldy     #$00
        lda     (cws_tmp2),y            ; displayPathLen low
        sta     fuji_current_dir_len
        iny
        lda     (cws_tmp2),y            ; displayPathLen high
        bne     frt_fail

        lda     fuji_current_dir_len
        cmp     fuji_current_fs_len
        bcc     frt_success
        beq     frt_success
        lda     #$00
        sta     fuji_current_dir_len

frt_success:
        clc
        rts
