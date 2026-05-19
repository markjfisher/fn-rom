        .export cmd_fs_fdrive

        .importzp aws_tmp00
        .importzp aws_tmp01
        .importzp buffer_ptr
        .importzp fuji_bus_tx_command
        .importzp fuji_bus_tx_device
        .importzp fuji_bus_tx_payload_hi
        .importzp fuji_bus_tx_payload_lo

        .import exit_user_ok
        .import fujibus_receive_packet
        .import fujibus_send_packet
        .import num_params
        .import print_char
        .import print_newline
        .import report_error

        .include "fujinet.inc"

        .segment "CODE"

FDRIVE_REQ_FLAG_FORMATTED = $01
FDRIVE_RESP_VERSION       = $07
FDRIVE_RESP_FLAGS         = $08
FDRIVE_RESP_FIRST_SLOT    = $09
FDRIVE_RESP_ENTRY_COUNT   = $0B
FDRIVE_RESP_DATA          = $0D

cmd_fs_fdrive:
        jsr     num_params
        beq     @send_request

        jsr     report_error
        .byte   $CB
        .byte   "FDRIVE", 0

@send_request:
        ldy     #$06
        lda     #FDRIVE_REQ_FLAG_FORMATTED
        sta     (buffer_ptr),y
        iny
        lda     #$00
        sta     (buffer_ptr),y          ; firstSlot lo = 0 => use configured first
        iny
        sta     (buffer_ptr),y          ; firstSlot hi
        iny
        sta     (buffer_ptr),y          ; lastSlot lo = 0 => use configured last
        iny
        sta     (buffer_ptr),y          ; lastSlot hi

        lda     #FN_DEVICE_FUJI
        sta     fuji_bus_tx_device

        lda     #FUJI_CMD_GET_MOUNTS
        sta     fuji_bus_tx_command

        lda     buffer_ptr
        clc
        adc     #$06
        sta     fuji_bus_tx_payload_lo
        lda     buffer_ptr+1
        adc     #$00
        sta     fuji_bus_tx_payload_hi

        ldx     #$00
        lda     #$05
        jsr     fujibus_send_packet

        jsr     fujibus_receive_packet

        cpx     #$00
        bne     @check_header
        cmp     #$00
        beq     @fail

        cmp     #$0D
        bcc     @fail

@check_header:
        ldy     #$05
        lda     (buffer_ptr),y
        cmp     #$01
        bne     @fail

        iny                             ; y=6
        lda     (buffer_ptr),y
        bne     @fail

        ldy     #FDRIVE_RESP_VERSION
        lda     (buffer_ptr),y
        cmp     #$01
        bne     @fail

        iny                             ; y=8 flags
        lda     (buffer_ptr),y
        and     #FDRIVE_REQ_FLAG_FORMATTED
        beq     @fail

        ldy     #FDRIVE_RESP_ENTRY_COUNT
        lda     (buffer_ptr),y
        sta     aws_tmp00               ; entry count lo, only for zero test
        iny
        lda     (buffer_ptr),y
        ora     aws_tmp00
        beq     @done

        lda     buffer_ptr
        clc
        adc     #FDRIVE_RESP_DATA
        sta     aws_tmp00
        lda     buffer_ptr+1
        adc     #$00
        sta     aws_tmp01

        ldy     #$00
@print_loop:
        lda     (aws_tmp00),y
        beq     @done
        cmp     #$0A
        beq     @print_nl
        jsr     print_char
        bne     @print_adv              ; A is preserved, and is not 0

@print_nl:
        jsr     print_newline

@print_adv:
        iny
        bne     @print_loop

@done:
        jmp     exit_user_ok

@fail:
        jsr     report_error
        .byte   $CB
        .byte   "Drive list err", 0
