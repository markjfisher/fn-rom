; FujiDevice FujiBus: GetMount / SetMount (replaces fujibus_fuji_c.c)
; Calls FujiBus transport send/receive with fuji_bus_tx_* ZP params (see os.s / fujibus.s).

        .export  fujibus_clear_mount_slot
        .export  fujibus_get_mount_slot
        .export  fujibus_set_mount_slot

        .importzp aws_tmp00
        .importzp cws_tmp2
        .importzp cws_tmp3

        .importzp buffer_ptr
        .importzp fuji_bus_tx_command
        .importzp fuji_bus_tx_device
        .importzp fuji_bus_tx_payload_hi
        .importzp fuji_bus_tx_payload_lo

        .import fuji_current_fs_len
        .import fuji_disk_slot
        .import fujibus_receive_packet_raw
        .import fujibus_send_packet_raw
        .import get_fuji_fs_uri_addr_to_aws_tmp00

        .include "fujinet.inc"

        .segment "CODE"


; bool fujibus_get_mount_slot(void)
;   A=1 success, A=0 failure, X=0
fujibus_get_mount_slot:
        ; jsr     set_fuji_data_buffer_ptr

        ldy     #$06
        lda     fuji_disk_slot
        sta     (buffer_ptr),y

        lda     #FN_DEVICE_FUJI
        sta     fuji_bus_tx_device

        lda     #FUJI_CMD_GET_MOUNT
        sta     fuji_bus_tx_command

        lda     buffer_ptr
        clc
        adc     #$06
        sta     fuji_bus_tx_payload_lo
        lda     buffer_ptr+1
        adc     #$00
        sta     fuji_bus_tx_payload_hi

        ldx     #$00
        lda     #$01

        jmp     do_send_recv_check

; bool fujibus_set_mount_slot(void)
;   Payload at buffer+6: slot, flags $01, uri_len, uri..., mode_len, mode 'auto'
fujibus_set_mount_slot:
        ; jsr     set_fuji_data_buffer_ptr

        ldy     #$06
        lda     fuji_disk_slot
        sta     (buffer_ptr),y

        ldy     #$07
        lda     #$01
        sta     (buffer_ptr),y

        ldy     #$08
        lda     fuji_current_fs_len
        sta     (buffer_ptr),y

        lda     buffer_ptr
        clc
        adc     #$09
        sta     cws_tmp2
        lda     buffer_ptr+1
        adc     #$00
        sta     cws_tmp3

        jsr     get_fuji_fs_uri_addr_to_aws_tmp00

        ldy     #$00
@copy_uri:
        cpy     fuji_current_fs_len
        beq     @uri_done
        lda     (aws_tmp00),y
        sta     (cws_tmp2),y
        iny
        bne     @copy_uri

@uri_done:
        lda     fuji_current_fs_len
        clc
        adc     #$09
        tay
        lda     #$04
        sta     (buffer_ptr),y
        iny
        lda     #'a'
        sta     (buffer_ptr),y
        iny
        lda     #'u'
        sta     (buffer_ptr),y
        iny
        lda     #'t'
        sta     (buffer_ptr),y
        iny
        lda     #'o'
        sta     (buffer_ptr),y

        lda     #FN_DEVICE_FUJI
        sta     fuji_bus_tx_device

        lda     #FUJI_CMD_SET_MOUNT
        sta     fuji_bus_tx_command

        lda     buffer_ptr
        clc
        adc     #$06
        sta     fuji_bus_tx_payload_lo
        lda     buffer_ptr+1
        adc     #$00
        sta     fuji_bus_tx_payload_hi

        lda     fuji_current_fs_len
        clc
        adc     #$08
        ldx     #$00
        bcc     :+
        inx
:       jmp     do_send_recv_check

; bool fujibus_clear_mount_slot(void)
;   Payload at buffer+6: slot, flags 0, uri_len 0, mode_len 0
fujibus_clear_mount_slot:
        ldy     #$06
        lda     fuji_disk_slot
        sta     (buffer_ptr),y

        iny                             ; y=7
        lda     #$00
        sta     (buffer_ptr),y

        iny                             ; y=8
        sta     (buffer_ptr),y

        iny                             ; y=9
        sta     (buffer_ptr),y

        lda     #FN_DEVICE_FUJI
        sta     fuji_bus_tx_device

        lda     #FUJI_CMD_SET_MOUNT
        sta     fuji_bus_tx_command

        lda     buffer_ptr
        clc
        adc     #$06
        sta     fuji_bus_tx_payload_lo
        lda     buffer_ptr+1
        adc     #$00
        sta     fuji_bus_tx_payload_hi

        ldx     #$00
        lda     #$04

do_send_recv_check:
        jsr     fujibus_send_packet_raw
        jsr     fujibus_receive_packet_raw
        ; fall through

; Shared: receive in A/X; [5]=1 param count, [6]=0 status
fujibus_fuji_check_status:
        cpx     #$00
        bne     @chk1
        cmp     #$00
        beq     @bad
@chk1:
        ldy     #$05
        lda     (buffer_ptr),y
        cmp     #$01
        bne     @bad
        ldy     #$06
        lda     (buffer_ptr),y
        bne     @bad

        lda     #$01
        ldx     #$00
        rts
@bad:
        lda     #$00
        tax
        rts
