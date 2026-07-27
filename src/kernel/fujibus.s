; FujiBus Protocol Implementation for BBC Micro
; Implements SLIP framing and FujiBus packet handling

        .include "fujinet.inc"

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
        .importzp aws_tmp10
        .importzp aws_tmp11
        .importzp aws_tmp14
        .importzp aws_tmp15
        .importzp cws_tmp2
        .importzp cws_tmp3
        .importzp cws_tmp6
        .importzp cws_tmp7

        .importzp buffer_ptr
        .importzp fuji_bus_tx_command
        .importzp fuji_bus_tx_device
        .importzp fuji_bus_tx_payload_hi
        .importzp fuji_bus_tx_payload_lo

        .import calc_checksum
        .import calc_checksum_continue
        .import fuji_ax_save
        .import fuji_link_read_slip_frame
.ifndef UTILITIES_RESIDENT
        .import fuji_link_read_slip_frame_to_payload
.endif
        .import fuji_link_write_slip_frame
        .import fuji_link_write_slip_frame_triple

.export fujibus_send_packet
.export fujibus_send_packet_scatter
.export fujibus_receive_packet
.ifndef UTILITIES_RESIDENT
.export fujibus_receive_packet_to_payload
.endif
.export fujibus_set_payload_buffer_ptr

.export scatter_after_checksum
        .export scatter_after_checksum_r2
        .export scatter_after_checksum_r3
        .export scatter_store_checksum
        .export scatter_before_write

fujibus_header_size = 6
fujibus_response_header_size = 7

        .segment "CODE"

; Transport send ABI
;   input  A/X = payload byte count
;          fuji_bus_tx_device / fuji_bus_tx_command set
;          fuji_bus_tx_payload_lo/hi set
;   output none
;   clobbers aws_tmp00/01/02/03/08/09, A, X, Y

fujibus_set_payload_buffer_ptr:
        lda     buffer_ptr
        clc
        adc     #$06
        sta     fuji_bus_tx_payload_lo
        lda     buffer_ptr+1
        adc     #$00
        sta     fuji_bus_tx_payload_hi
        rts


; Internal core: aws_tmp02/03 = paylen, aws_tmp00/01 = payload ptr,
; buffer [0],[1] = dev/cmd.

fujibus_send_packet:
        sta     aws_tmp02
        stx     aws_tmp03

        lda     fuji_bus_tx_payload_lo
        sta     aws_tmp00
        lda     fuji_bus_tx_payload_hi
        sta     aws_tmp01

        ldy     #$00
        lda     fuji_bus_tx_device
        sta     (buffer_ptr),y
        iny
        lda     fuji_bus_tx_command
        sta     (buffer_ptr),y

fujibus_send_packet_body:
        jsr     fujibus_send_packet_prepare_payload_destination
        jsr     fujibus_send_packet_copy_payload
        jsr     fujibus_send_packet_store_total_len
        jsr     fujibus_send_packet_store_descriptor_bytes
        jsr     fujibus_send_packet_store_checksum
        jsr     fujibus_send_packet_prepare_write_region
        jmp     fuji_link_write_slip_frame

fujibus_send_packet_prepare_payload_destination:
        ; destination pointer = buffer + header size
        lda     buffer_ptr
        clc
        adc     #fujibus_header_size
        sta     aws_tmp08
        lda     buffer_ptr+1
        adc     #$00
        sta     aws_tmp09

        ldy     #$00
        rts

fujibus_send_packet_copy_payload:
@copy_payload:
        lda     aws_tmp02
        ora     aws_tmp03
        beq     @payload_done

        lda     (aws_tmp00),y
        sta     (aws_tmp08),y

        inc     aws_tmp00
        bne     :+
        inc     aws_tmp01
:
        inc     aws_tmp08
        bne     :+
        inc     aws_tmp09
:
        lda     aws_tmp02
        bne     :+
        dec     aws_tmp03
:
        dec     aws_tmp02
        jmp     @copy_payload

@payload_done:
        rts

fujibus_send_packet_store_total_len:
        ; total_len = current dest ptr - buffer base
        lda     aws_tmp08
        sec
        sbc     buffer_ptr
        sta     aws_tmp02

        lda     aws_tmp09
        sbc     buffer_ptr+1
        sta     aws_tmp03
        rts

fujibus_send_packet_store_descriptor_bytes:
        ldy     #$02
        lda     aws_tmp02
        sta     (buffer_ptr),y
        iny                             ; Y = 3
        lda     aws_tmp03
        sta     (buffer_ptr),y

        ; checksum placeholder + descriptor
        lda     #$00
        iny                             ; Y = 4
        sta     (buffer_ptr),y
        iny                             ; Y = 5
        sta     (buffer_ptr),y

        rts

fujibus_send_packet_store_checksum:
        ; checksum over full packet
        jsr     fujibus_send_packet_prepare_write_region
        jsr     calc_checksum
scatter_after_checksum:
        ldy     #$04
        sta     (buffer_ptr),y
        rts

fujibus_send_packet_prepare_write_region:
        lda     buffer_ptr
        sta     aws_tmp00
        lda     buffer_ptr+1
        sta     aws_tmp01
        ldy     #$02
        lda     (buffer_ptr),y
        sta     aws_tmp02
        iny
        lda     (buffer_ptr),y
        sta     aws_tmp03
        rts

; Scatter transport send ABI
;   region 1: aws_tmp00/01 ptr, aws_tmp02/03 len (includes FujiBus header)
;   region 2: aws_tmp06/07 ptr, aws_tmp08/09 len (optional)
;   region 3: cws_tmp2/3 ptr, cws_tmp6/7 len (optional)
;   clobbers aws_tmp00/01/02/03/04/08/09, A, X, Y

fujibus_send_packet_scatter:
        ldy     #$00
        lda     fuji_bus_tx_device
        sta     (buffer_ptr),y
        iny
        lda     fuji_bus_tx_command
        sta     (buffer_ptr),y

        jsr     fujibus_send_packet_scatter_store_total_len

        ldy     #$04
        lda     #$00
        sta     (buffer_ptr),y
        iny
        sta     (buffer_ptr),y

        jsr     fujibus_send_packet_scatter_store_checksum
        ; The triple-frame writer consumes region 1 from aws_tmp00..03 and
        ; region 2/3 from their original descriptors, so only region 1 needs
        ; restoring after checksum preparation repurposed aws_tmp00..03.
        jsr     fujibus_send_packet_scatter_restore_region1_for_write
scatter_before_write:
        jmp     fuji_link_write_slip_frame_triple

fujibus_send_packet_scatter_store_total_len:
        ; total_len = region1 + region2 + region3
        lda     aws_tmp02
        clc
        adc     aws_tmp08
        adc     cws_tmp6
        ldy     #$02
        sta     (buffer_ptr),y

        lda     aws_tmp03
        adc     aws_tmp09
        adc     cws_tmp7
        iny
        sta     (buffer_ptr),y

        rts

fujibus_send_packet_scatter_store_checksum:
        jsr     calc_checksum

        lda     aws_tmp08
        ora     aws_tmp09
        beq     scatter_after_checksum_r2

        lda     aws_tmp06
        sta     aws_tmp00
        lda     aws_tmp07
        sta     aws_tmp01
        lda     aws_tmp08
        sta     aws_tmp02
        lda     aws_tmp09
        sta     aws_tmp03

        jsr     calc_checksum_continue
scatter_after_checksum_r2:

        lda     cws_tmp6
        ora     cws_tmp7
        beq     scatter_after_checksum_r3

        lda     cws_tmp2
        sta     aws_tmp00
        lda     cws_tmp3
        sta     aws_tmp01
        lda     cws_tmp6
        sta     aws_tmp02
        lda     cws_tmp7
        sta     aws_tmp03

        jsr     calc_checksum_continue
scatter_after_checksum_r3:

scatter_store_checksum:
        ldy     #$04
        lda     aws_tmp04               ; checksum result from calc_checksum(_continue)
        sta     (buffer_ptr),y
        rts

fujibus_send_packet_scatter_restore_region1_for_write:
        lda     buffer_ptr
        sta     aws_tmp00
        lda     buffer_ptr+1
        sta     aws_tmp01

        ldy     #$02
        lda     (buffer_ptr),y
        sec
        sbc     aws_tmp08
        sta     aws_tmp02
        iny
        lda     (buffer_ptr),y
        sbc     aws_tmp09
        sta     aws_tmp03

        lda     aws_tmp02
        sec
        sbc     cws_tmp6
        sta     aws_tmp02
        lda     aws_tmp03
        sbc     cws_tmp7
        sta     aws_tmp03
        rts

; Transport receive ABI
;   output A/X = decoded packet length, or 0/0 on failure
;   clobbers aws_tmp00/01/02/03/04/05/08/09/10/11, A, X, Y

fujibus_receive_packet:
        ; receive and decode SLIP into buffer at buffer_ptr
        jsr     fuji_link_read_slip_frame

        ; Canonical decoded length/result lives in aws_tmp10/11.
        sta     aws_tmp10
        stx     aws_tmp11

        jsr     fujibus_receive_packet_validate_decoded_length
        bcc     fujibus_receive_packet_fail

        lda     aws_tmp00              ; streamed checksum, byte 4 as zero
        cmp     aws_tmp01              ; received checksum byte
        bne     fujibus_receive_packet_fail

        lda     aws_tmp10
        ldx     aws_tmp11
        rts

; Transport receive-to-payload ABI
;   input  aws_tmp06/07 = caller payload destination
;          aws_tmp08/09 = caller payload capacity
;   output A/X = decoded packet length, or 0/0 on failure
;          buffer_ptr[0..6] = FujiBus response header/status
;          caller payload destination receives bytes from decoded offset 7 onward
;   Notes: payload overflow is drained and checksummed; the caller compares
;          returned total length - 7 against its capacity to decide BAD_CALL.
;   clobbers aws_tmp00/01/02/03/04/05/08/09/10/11, cws_tmp2/3/6/7, A, X, Y

.ifndef UTILITIES_RESIDENT
fujibus_receive_packet_to_payload:
        jsr     fuji_link_read_slip_frame_to_payload
        sta     aws_tmp10
        stx     aws_tmp11

        jsr     fujibus_receive_packet_validate_decoded_length
        bcc     fujibus_receive_packet_fail

        lda     aws_tmp00              ; streamed checksum, byte 4 as zero
        cmp     aws_tmp01              ; received checksum byte
        bne     fujibus_receive_packet_fail

        lda     aws_tmp10
        ldx     aws_tmp11
        rts
.endif

fujibus_receive_packet_validate_decoded_length:
        ; if dec_len == 0 return 0
        ldx     aws_tmp11
        cpx     #$00
        bne     @check_min
        lda     aws_tmp10
        cmp     #$00
        beq     @invalid

        ; if dec_len < fujibus_header_size return 0
        ; (fujibus_header_size = 6)
@check_min:
        lda     aws_tmp11
        bne     @valid
        lda     aws_tmp10
        cmp     #fujibus_header_size
        bcs     @valid

@invalid:
        clc
        rts

@valid:
        sec
        rts

fujibus_receive_packet_fail:
        lda     #$00
        tax
        rts
