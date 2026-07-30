        .export cmd_fs_fslots

        .importzp aws_tmp00
        .importzp aws_tmp01
        .importzp aws_tmp02
        .importzp aws_tmp03
        .importzp aws_tmp12
        .importzp aws_tmp13
        .importzp pws_tmp04
        .importzp pws_tmp05
        .importzp pws_tmp06
        .importzp buffer_ptr
        .importzp fuji_bus_tx_command
        .importzp fuji_bus_tx_device

        .import cfl_print_formatted_blob
        .import err_syntax
        .import exit_user_ok
        .import fujibus_receive_packet
        .import fujibus_send_packet
        .import fujibus_set_payload_buffer_ptr
        .import num_params
        .import param_get_byte
        .import print_string

        .include "fujinet.inc"

        cmd_entry "FUTILS_EXT", "SLOTS", $0, $00, cmd_fs_fslots

        .segment "CODE"

FSLOTS_MAX_PAYLOAD       = 220
FSLOTS_REQ_FORMATTED     = $02
FSLOTS_RESP_MORE         = $01
FSLOTS_RESP_FORMATTED    = $02
FSLOTS_RESP_VERSION      = $07
FSLOTS_RESP_FLAGS        = $08
FSLOTS_RESP_NEXT         = $09
FSLOTS_RESP_PRESENCE_LEN = $0A
FSLOTS_RESP_ENTRY_COUNT  = $0B
FSLOTS_RESP_ENTRIES_LEN  = $0C
FSLOTS_RESP_DATA         = $0E

; *FSLOTS                 all populated catalogue slots
; *FSLOTS <index>         one catalogue slot
; *FSLOTS <lower> <upper> inclusive range
cmd_fs_fslots:
        jsr     num_params
        cmp     #3
        bcc     :+
        jmp     @syntax
:
        sta     aws_tmp02
        beq     @all
        jsr     param_get_byte
        sta     pws_tmp04              ; lower
        sta     pws_tmp05              ; upper for one-index form
        dec     aws_tmp02
        beq     @start
        jsr     param_get_byte
        sta     pws_tmp05
        cmp     pws_tmp04
        bcs     @start
        jmp     @syntax
@all:
        lda     #0
        sta     pws_tmp04
        lda     #$FF
        sta     pws_tmp05
@start:
        lda     pws_tmp04
        sta     pws_tmp06              ; cursor

@page:
        ldy     #$06
        lda     #FN_PROTOCOL_VERSION
        sta     (buffer_ptr),y
        iny
        lda     pws_tmp04
        sta     (buffer_ptr),y
        iny
        lda     pws_tmp05
        sta     (buffer_ptr),y
        iny
        lda     pws_tmp06
        sta     (buffer_ptr),y
        iny
        lda     #FSLOTS_REQ_FORMATTED
        sta     (buffer_ptr),y
        iny
        lda     #128
        sta     (buffer_ptr),y
        iny
        lda     #<FSLOTS_MAX_PAYLOAD
        sta     (buffer_ptr),y
        iny
        lda     #>FSLOTS_MAX_PAYLOAD
        sta     (buffer_ptr),y

        lda     #FN_DEVICE_FILE
        sta     fuji_bus_tx_device
        lda     #FILE_CMD_SLOT_CATALOG_RANGE
        sta     fuji_bus_tx_command
        jsr     fujibus_set_payload_buffer_ptr
        lda     #8
        ldx     #0
        jsr     fujibus_send_packet
        jsr     fujibus_receive_packet
        sta     aws_tmp12
        stx     aws_tmp13
        ora     aws_tmp13
        beq     @fail
        lda     aws_tmp13
        bne     @header
        lda     aws_tmp12
        cmp     #14
        bcc     @fail

@header:
        ldy     #5
        lda     (buffer_ptr),y
        cmp     #1
        bne     @fail
        iny
        lda     (buffer_ptr),y
        bne     @fail
        ldy     #FSLOTS_RESP_VERSION
        lda     (buffer_ptr),y
        cmp     #1
        bne     @fail
        iny
        lda     (buffer_ptr),y
        sta     aws_tmp02
        and     #FSLOTS_RESP_FORMATTED
        beq     @fail

        ldy     #FSLOTS_RESP_PRESENCE_LEN
        lda     (buffer_ptr),y
        clc
        adc     #FSLOTS_RESP_DATA
        sta     aws_tmp03
        lda     buffer_ptr
        clc
        adc     aws_tmp03
        sta     aws_tmp00
        lda     buffer_ptr+1
        adc     #0
        sta     aws_tmp01

        ldy     #FSLOTS_RESP_ENTRIES_LEN
        lda     (buffer_ptr),y
        clc
        adc     aws_tmp00
        sta     aws_tmp12
        iny
        lda     (buffer_ptr),y
        adc     aws_tmp01
        sta     aws_tmp13
        lda     aws_tmp00
        cmp     aws_tmp12
        bne     @print
        lda     aws_tmp01
        cmp     aws_tmp13
        beq     @after_print
@print:
        jsr     cfl_print_formatted_blob

@after_print:
        lda     aws_tmp02
        and     #FSLOTS_RESP_MORE
        beq     @done
        ldy     #FSLOTS_RESP_NEXT
        lda     (buffer_ptr),y
        cmp     pws_tmp06
        beq     @fail
        bcc     @fail
        sta     pws_tmp06
        jmp     @page

@done:  jmp     exit_user_ok
@syntax:jmp     err_syntax
@fail:
        jsr     print_string
        .byte   "FSLOTS err", $0D
        nop
        jmp     exit_user_ok
