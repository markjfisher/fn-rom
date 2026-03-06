        .export fuji_set_mount_slot
        .export fuji_clear_mount_slot
        .export fuji_get_mount_slot

        .import fn_build_packet
        .import fn_send_packet
        .import fn_receive_packet
        .import fn_tx_buffer
        .import fn_rx_buffer

        .include "fujinet.inc"

        .segment "CODE"

; Set persisted Fuji mount slot using FujiDevice SetMount.
; Input:
;   fuji_current_mount_slot = 0-based slot index
;   fuji_buf_1060 = NUL-terminated URI
; Output:
;   Carry clear on success, set on failure
;
; FujiDevice SetMount payload layout:
;   byte 0  = slot index (0..7)
;   byte 1  = flags (bit0 = enabled)
;   byte 2  = URI length in bytes
;   bytes 3.. = URI data
;   next byte = mode length
;   next byte(s) = mode string (currently always "r")
;
; We build the payload directly in fn_tx_buffer after the 6-byte FujiBus header,
; then pass the final payload length in Y to fn_build_packet.
fuji_set_mount_slot:
        lda     fuji_current_mount_slot
        cmp     #$08
        bcs     @error

        ; Write slot index into payload byte 0.
        sta     fn_tx_buffer+FN_HEADER_SIZE+0

        ; Set the persisted mount entry enabled flag.
        lda     #$01                    ; enabled
        sta     fn_tx_buffer+FN_HEADER_SIZE+1

        ; Measure URI length by scanning for the NUL terminator.
        ; Y leaves this loop holding the URI length.
        ldy     #$00
@measure_uri:
        lda     fuji_buf_1060,y
        beq     @write_uri_len
        iny
        cpy     #$3F
        bcc     @measure_uri

@write_uri_len:
        ; Store the measured URI length into payload byte 2.
        tya
        sta     fn_tx_buffer+FN_HEADER_SIZE+2

        ; Copy exactly URI length bytes into payload bytes 3..
        ldx     #$00
@copy_uri:
        cpx     fn_tx_buffer+FN_HEADER_SIZE+2
        beq     @write_mode
        lda     fuji_buf_1060,x
        sta     fn_tx_buffer+FN_HEADER_SIZE+3,x
        inx
        bne     @copy_uri

@write_mode:
        ; X now equals uri_len.
        ; Convert that to the payload offset immediately after the URI:
        ;   3 fixed bytes + uri_len
        txa
        clc
        adc     #$03
        tay

        ; Encode mode length and mode string.
        ; At present FIN always writes persisted mounts in read-only mode.
        lda     #$01                    ; mode len = 1
        sta     fn_tx_buffer+FN_HEADER_SIZE,y
        iny
        lda     #'r'
        sta     fn_tx_buffer+FN_HEADER_SIZE,y
        iny

        ; Y now already contains the final payload length:
        ;   3 fixed bytes + uri_len + 1 modeLen + 1 modeChar
        ; No further arithmetic is required before fn_build_packet.

        ; fn_build_packet copies payload from (aws_tmp00); point at fn_tx_buffer payload.
        lda     #<(fn_tx_buffer+FN_HEADER_SIZE)
        sta     aws_tmp00
        lda     #>(fn_tx_buffer+FN_HEADER_SIZE)
        sta     aws_tmp01

        ; Build and send FujiBus packet to FujiDevice.
        lda     #FN_DEVICE_FUJI
        ldx     #FUJI_CMD_SET_MOUNT
        jsr     fn_build_packet
        jsr     fn_send_packet
        bcs     @error

        ; Receive FujiDevice response. We currently treat any transport failure
        ; as command failure and leave response payload parsing to later work.
        jsr     fn_receive_packet
        bcs     @error

        lda     fn_rx_buffer+FN_PARAMS_OFFSET
        bne     @error
        clc
        rts

@error:
        sec
        rts

; Clear persisted Fuji mount slot using FujiDevice SetMount removal semantics.
; Input:
;   fuji_current_mount_slot = 0-based slot index
; Output:
;   Carry clear on success, set on failure
;
; Payload layout for removal is:
;   byte 0 = slot index (0..7)
;   byte 1 = flags (0 when disabled/unused)
;   byte 2 = URI length = 0, which instructs FujiDevice to remove the entry
;   byte 3 = mode length = 0
fuji_clear_mount_slot:
        lda     fuji_current_mount_slot
        cmp     #$08
        bcs     @clear_error
        sta     fn_tx_buffer+FN_HEADER_SIZE+0

        lda     #$00
        sta     fn_tx_buffer+FN_HEADER_SIZE+1
        sta     fn_tx_buffer+FN_HEADER_SIZE+2
        sta     fn_tx_buffer+FN_HEADER_SIZE+3

        ; fn_build_packet copies payload from (aws_tmp00); point at fn_tx_buffer payload.
        lda     #<(fn_tx_buffer+FN_HEADER_SIZE)
        sta     aws_tmp00
        lda     #>(fn_tx_buffer+FN_HEADER_SIZE)
        sta     aws_tmp01

        lda     #FN_DEVICE_FUJI
        ldx     #FUJI_CMD_SET_MOUNT
        ldy     #$04
        jsr     fn_build_packet
        jsr     fn_send_packet
        bcs     @clear_error

        jsr     fn_receive_packet
        bcs     @clear_error

        lda     fn_rx_buffer+FN_PARAMS_OFFSET
        bne     @clear_error
        clc
        rts

@clear_error:
        sec
        rts

; Get persisted Fuji mount slot using FujiDevice GetMount.
; Input:
;   fuji_current_mount_slot = 0-based slot index
; Output:
;   response remains in fn_rx_buffer
;   Carry clear on success, set on failure
;
; Request payload layout is only one byte:
;   byte 0 = slot index (0..7)
fuji_get_mount_slot:
        ; Write requested slot index into payload byte 0.
        lda     fuji_current_mount_slot
        cmp     #$08
        bcs     @get_error
        sta     fn_tx_buffer+FN_HEADER_SIZE+0

        ; fn_build_packet copies payload from (aws_tmp00); point at what we just wrote.
        lda     #<(fn_tx_buffer+FN_HEADER_SIZE)
        sta     aws_tmp00
        lda     #>(fn_tx_buffer+FN_HEADER_SIZE)
        sta     aws_tmp01

        ; Payload length is exactly 1 byte for GetMount.
        lda     #FN_DEVICE_FUJI
        ldx     #FUJI_CMD_GET_MOUNT
        ldy     #$01
        jsr     fn_build_packet
        jsr     fn_send_packet
        bcs     @get_error

        ; On success the FujiDevice response record is left in fn_rx_buffer for
        ; the caller to decode.
        jsr     fn_receive_packet
        bcs     @get_error

        lda     fn_rx_buffer+FN_PARAMS_OFFSET
        bne     @get_error
        clc
        rts

@get_error:
        sec
        rts
