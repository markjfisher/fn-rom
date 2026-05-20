        .export cmd_fs_fdrive

        .importzp aws_tmp00
        .importzp aws_tmp01
        .importzp aws_tmp02
        .importzp aws_tmp03
        .importzp aws_tmp08
        .importzp aws_tmp12
        .importzp aws_tmp13
        .importzp pws_tmp04
        .importzp pws_tmp05
        .importzp buffer_ptr
        .importzp fuji_bus_tx_command
        .importzp fuji_bus_tx_device
        .importzp fuji_bus_tx_payload_hi
        .importzp fuji_bus_tx_payload_lo

        .import cfl_print_formatted_blob
        .import exit_user_ok
        .import fujibus_receive_packet
        .import fujibus_send_packet
        .import num_params
        .import report_error

        .include "fujinet.inc"

        .segment "CODE"

FDRIVE_MAX_PAYLOAD          = 220
FDRIVE_REQ_FLAG_FORMATTED   = $01
FDRIVE_RESP_FLAG_MORE       = $01
FDRIVE_RESP_FLAG_FORMATTED  = $02
FDRIVE_RESP_VERSION         = $07
FDRIVE_RESP_FLAGS           = $08
FDRIVE_RESP_FIRST_SLOT      = $09
FDRIVE_RESP_START_INDEX     = $0B
FDRIVE_RESP_ENTRY_COUNT     = $0D
FDRIVE_RESP_ENTRIES_LEN     = $0F
FDRIVE_RESP_DATA            = $11

cmd_fs_fdrive:
        jsr     num_params
        beq     @init

        jsr     report_error
        .byte   $CB
        .byte   "FDRIVE", 0

@init:
        lda     #$00
        sta     pws_tmp04
        sta     pws_tmp05

@page_loop:
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
        iny
        lda     pws_tmp04
        sta     (buffer_ptr),y          ; startIndex lo
        iny
        lda     pws_tmp05
        sta     (buffer_ptr),y          ; startIndex hi
        iny
        lda     #<FDRIVE_MAX_PAYLOAD
        sta     (buffer_ptr),y
        iny
        lda     #>FDRIVE_MAX_PAYLOAD
        sta     (buffer_ptr),y

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
        lda     #$09
        jsr     fujibus_send_packet

        jsr     fujibus_receive_packet
        sta     aws_tmp12
        stx     aws_tmp13

        lda     aws_tmp12
        ora     aws_tmp13
        bne     :+
        jmp     @fail
: 

        lda     aws_tmp13
        bne     @check_header
        lda     aws_tmp12
        cmp     #$11
        bcc     @fail_near

@check_header:
        ldy     #$05
        lda     (buffer_ptr),y
        cmp     #$01
        bne     @fail_near

        iny                             ; y=6
        lda     (buffer_ptr),y
        bne     @fail_near

        ldy     #FDRIVE_RESP_VERSION
        lda     (buffer_ptr),y
        cmp     #$01
        bne     @fail_near

        iny                             ; y=8 flags
        lda     (buffer_ptr),y
        sta     aws_tmp02
        and     #FDRIVE_RESP_FLAG_FORMATTED
        beq     @fail_near

        ldy     #FDRIVE_RESP_START_INDEX
        lda     (buffer_ptr),y
        cmp     pws_tmp04
        bne     @fail_near
        iny
        lda     (buffer_ptr),y
        cmp     pws_tmp05
        bne     @fail_near

        ldy     #FDRIVE_RESP_ENTRY_COUNT
        lda     (buffer_ptr),y
        sta     aws_tmp03
        iny
        lda     (buffer_ptr),y
        sta     aws_tmp08

        lda     pws_tmp04
        clc
        adc     aws_tmp03
        sta     pws_tmp04
        lda     pws_tmp05
        adc     aws_tmp08
        sta     pws_tmp05

        ; entries blob end = buffer + FDRIVE_RESP_DATA + entriesLen
        lda     buffer_ptr
        clc
        adc     #FDRIVE_RESP_DATA
        sta     aws_tmp00
        lda     buffer_ptr+1
        adc     #$00
        sta     aws_tmp01

        ldy     #FDRIVE_RESP_ENTRIES_LEN
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

        lda     aws_tmp02
        and     #FDRIVE_RESP_FLAG_MORE
        beq     @done
        jmp     @page_loop

@fail_near:
        jmp     @fail

@done:
        jmp     exit_user_ok

@fail:
        jsr     report_error
        .byte   $CB
        .byte   "Drive list err", 0
