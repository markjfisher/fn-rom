; FujiBus Protocol Implementation for BBC Micro
; Implements SLIP framing and FujiBus packet handling
; Compatible with fujinet-nio FujiBus protocol
;
; Based on reference implementations:
; - py/fujinet_tools/fujibus.py
; - fujinet-nio-lib/src/common/fn_slip.c
; - fujinet-nio-lib/src/common/fn_packet.c

        .export fn_calc_checksum
        .export fn_slip_encode
        .export fn_slip_decode
        .export fn_build_packet
        .export fn_send_packet
        .export fn_receive_packet

        ; Buffer locations (exported for other modules)
        .export fn_tx_buffer
        .export fn_rx_buffer
        .export fn_tx_len
        .export fn_tx_len_hi
        .export fn_rx_len
        .export fn_slip_buffer

        .import _write_serial_data
        .import _read_serial_data
        .import setup_serial_19200
        .import restore_output_to_screen

        .include "fujinet.inc"

; ============================================================================
; Local Constants (not in fujinet.inc)
; ============================================================================

; Maximum SLIP buffer size
FN_MAX_SLIP_SIZE = 2048    ; 2x max packet + 2 END markers

; ============================================================================
; Buffers - placed in workspace area (fuji_workspace = 0)
; Using $1200 for buffers
; This area is after the channel workspace ($1100-$111F)
; ============================================================================

; Transmit buffer - 1024 bytes at $1200
fn_tx_buffer    = $1200

; Receive buffer - 1024 bytes at $1600
fn_rx_buffer    = $1600

; SLIP working buffer - 2048 bytes at $1A00
fn_slip_buffer  = $1A00

; Buffer lengths - use private workspace for persistent storage
fn_tx_len       = $10FE
fn_tx_len_hi    = $10FF

fn_rx_len       = $10FC
fn_rx_len_hi    = $10FD

; Checksum accumulator (2 bytes)
fn_chk_sum      = $10FA
fn_chk_sum_hi   = $10FB

; ============================================================================
; CODE segment
; ============================================================================

        .segment "CODE"

; ============================================================================
; FN_CALC_CHECKSUM - Calculate FujiBus checksum
;
; The checksum is a sum of all bytes with carry folding.
; chk = sum of all bytes
; chk = ((chk >> 8) + (chk & 0xFF)) & 0xFFFF
; return chk & 0xFF
;
; Input:
;   aws_tmp00/01 = pointer to data buffer
;   aws_tmp02/03 = length of data (16-bit)
;
; Output:
;   A = checksum byte
;   X, Y preserved
; ============================================================================
fn_calc_checksum:
        ; Initialize checksum to 0
        lda     #$00
        sta     fn_chk_sum
        sta     fn_chk_sum_hi

        ; Save buffer pointer
        lda     aws_tmp00
        pha
        lda     aws_tmp01
        pha

        ; Use Y as index within current page
        ldy     #$00

@checksum_loop:
        ; Check if we've processed all bytes
        lda     aws_tmp02
        ora     aws_tmp03
        beq     @checksum_done

        ; Get next byte
        lda     (aws_tmp00),y
        
        ; Add to checksum
        clc
        adc     fn_chk_sum
        sta     fn_chk_sum
        bcc     @no_carry1
        inc     fn_chk_sum_hi
@no_carry1:

        ; Fold carry: chk_sum = (chk_sum >> 8) + (chk_sum & 0xFF)
        ; This is: chk_sum = hi(chk_sum) + lo(chk_sum)
        lda     fn_chk_sum_hi   ; hi byte
        clc
        adc     fn_chk_sum      ; add lo byte
        sta     fn_chk_sum
        lda     #$00
        sta     fn_chk_sum_hi   ; clear hi byte

        ; Advance pointer
        iny
        bne     @no_page_cross
        inc     aws_tmp01       ; Cross page boundary
@no_page_cross:

        ; Decrement length
        dec     aws_tmp02
        lda     aws_tmp02
        cmp     #$FF
        bne     @no_borrow
        dec     aws_tmp03
@no_borrow:

        jmp     @checksum_loop

@checksum_done:
        ; Restore buffer pointer
        pla
        sta     aws_tmp01
        pla
        sta     aws_tmp00

        ; Return low byte of checksum
        lda     fn_chk_sum
        rts


; ============================================================================
; FN_SLIP_ENCODE - Encode data with SLIP framing
;
; Adds SLIP END markers at start and end, and escapes any END or ESCAPE
; bytes in the data.
;
; Input:
;   aws_tmp00/01 = pointer to input data
;   aws_tmp02/03 = length of input data (16-bit)
;
; Output:
;   fn_slip_buffer contains encoded data
;   fn_tx_len = length of encoded data
;   A = length low byte
; ============================================================================
fn_slip_encode:
        ; Initialize output pointer
        ldx     #$00            ; X is output index

        ; Start with END marker
        lda     #SLIP_END
        sta     fn_slip_buffer,x
        inx

        ; Save input buffer pointer
        lda     aws_tmp00
        pha
        lda     aws_tmp01
        pha

        ; Y is input index within current page
        ldy     #$00

@encode_loop:
        ; Check if we've processed all bytes
        lda     aws_tmp02
        ora     aws_tmp03
        beq     @encode_done

        ; Get next input byte
        lda     (aws_tmp00),y

        ; Check for special bytes
        cmp     #SLIP_END
        beq     @escape_end
        cmp     #SLIP_ESCAPE
        beq     @escape_esc

        ; Normal byte - store and continue
        sta     fn_slip_buffer,x
        inx
        jmp     @next_byte

@escape_end:
        ; Escape END byte: ESCAPE + ESC_END
        lda     #SLIP_ESCAPE
        sta     fn_slip_buffer,x
        inx
        lda     #SLIP_ESC_END
        sta     fn_slip_buffer,x
        inx
        jmp     @next_byte

@escape_esc:
        ; Escape ESCAPE byte: ESCAPE + ESC_ESC
        lda     #SLIP_ESCAPE
        sta     fn_slip_buffer,x
        inx
        lda     #SLIP_ESC_ESC
        sta     fn_slip_buffer,x
        inx

@next_byte:
        ; Advance input pointer
        iny
        bne     @no_page_cross
        inc     aws_tmp01
@no_page_cross:

        ; Decrement length
        dec     aws_tmp02
        lda     aws_tmp02
        cmp     #$FF
        bne     @no_borrow
        dec     aws_tmp03
@no_borrow:

        jmp     @encode_loop

@encode_done:
        ; End with END marker
        lda     #SLIP_END
        sta     fn_slip_buffer,x
        inx

        ; Store output length
        stx     fn_tx_len
        lda     #$00
        sta     fn_tx_len_hi

        ; Restore input buffer pointer
        pla
        sta     aws_tmp01
        pla
        sta     aws_tmp00

        ; Return length in A
        txa
        rts


; ============================================================================
; FN_SLIP_DECODE - Decode SLIP-framed data
;
; Removes SLIP framing and un-escapes any escaped bytes.
;
; Input:
;   aws_tmp00/01 = pointer to SLIP-encoded data
;   aws_tmp02/03 = length of encoded data (16-bit)
;
; Output:
;   fn_rx_buffer contains decoded data
;   fn_rx_len = length of decoded data
;   A = length low byte, 0 on error
; ============================================================================
fn_slip_decode:
        ; Initialize output index
        ldx     #$00

        ; Skip leading END marker if present
        ldy     #$00
        lda     (aws_tmp00),y
        cmp     #SLIP_END
        bne     @decode_start
        iny

@decode_start:
        ; Process until next END or end of data
@decode_loop:
        ; Check if we've reached end of input
        cpy     aws_tmp02       ; Compare with length low
        bne     @continue
        lda     aws_tmp03       ; Check high byte
        beq     @decode_done    ; End of input
@continue:

        ; Get next byte
        lda     (aws_tmp00),y
        iny
        bne     @no_page_cross1
        inc     aws_tmp01
@no_page_cross1:

        ; Check for END marker
        cmp     #SLIP_END
        beq     @decode_done

        ; Check for ESCAPE
        cmp     #SLIP_ESCAPE
        beq     @handle_escape

        ; Normal byte - store
        sta     fn_rx_buffer,x
        inx
        jmp     @decode_loop

@handle_escape:
        ; Get escaped byte
        cpy     aws_tmp02
        bne     @get_escaped
        lda     aws_tmp03
        beq     @decode_done    ; Incomplete escape
@get_escaped:
        lda     (aws_tmp00),y
        iny
        bne     @no_page_cross2
        inc     aws_tmp01
@no_page_cross2:

        ; Decode escape sequence
        cmp     #SLIP_ESC_END
        beq     @store_end
        cmp     #SLIP_ESC_ESC
        beq     @store_esc

        ; Unknown escape - keep as-is (matches Python behavior)
        ; Fall through to store the byte

@store_end:
        lda     #SLIP_END
        .byte   $2C             ; BIT instruction to skip next store
@store_esc:
        lda     #SLIP_ESCAPE

        ; Store decoded byte
        sta     fn_rx_buffer,x
        inx
        jmp     @decode_loop

@decode_done:
        ; Store output length
        stx     fn_rx_len
        lda     #$00
        sta     fn_rx_len_hi

        ; Return length in A
        txa
        rts


; ============================================================================
; FN_BUILD_PACKET - Build a FujiBus packet
;
; Header format: device(1) + command(1) + length(2) + checksum(1) + descr(1) = 6 bytes
;
; Input:
;   A = device ID
;   X = command byte
;   Y = payload length (0-255 for simple packets)
;   aws_tmp00/01 = pointer to payload data (or $0000 if no payload)
;
; Output:
;   fn_tx_buffer contains complete packet
;   fn_tx_len = total packet length
; ============================================================================
fn_build_packet:
        ; Save registers (standard 6502 - no phx/phy)
        ; Order on stack after saves: deviceID, command, payloadLen
        pha                     ; Device ID
        txa
        pha                     ; Command
        tya
        pha                     ; Payload length

        ; Calculate total length = header(6) + payload
        pla                     ; Get payload length
        tay                     ; Save in Y for later
        clc
        tya                     ; Get payload length
        adc     #FN_HEADER_SIZE
        sta     fn_tx_len
        lda     #$00
        sta     fn_tx_len_hi

        ; Build header
        ; Offset 0: Device ID
        pla                     ; Get device ID from stack
        sta     fn_tx_buffer+0

        ; Offset 1: Command
        pla                     ; Get command
        sta     fn_tx_buffer+1

        ; Offset 2-3: Length (little-endian)
        lda     fn_tx_len
        sta     fn_tx_buffer+2
        lda     fn_tx_len_hi
        sta     fn_tx_buffer+3

        ; Offset 4: Checksum placeholder (will be filled later)
        lda     #$00
        sta     fn_tx_buffer+4

        ; Offset 5: Descriptor (0 for simple packets)
        sta     fn_tx_buffer+5

        ; Check if payload present (Y still has payload length)
        cpy     #$00
        beq     @no_payload     ; Skip if no payload

        ; Copy payload to buffer after header
        tay                     ; Use Y as counter
        dey                     ; Adjust for 0-index

@copy_loop:
        lda     (aws_tmp00),y
        sta     fn_tx_buffer+FN_HEADER_SIZE,y
        dey
        bpl     @copy_loop

@no_payload:
        ; Calculate checksum over entire packet
        ; Set up parameters for fn_calc_checksum
        lda     #<fn_tx_buffer
        sta     aws_tmp00
        lda     #>fn_tx_buffer
        sta     aws_tmp01
        lda     fn_tx_len
        sta     aws_tmp02
        lda     fn_tx_len_hi
        sta     aws_tmp03

        jsr     fn_calc_checksum

        ; Store checksum at offset 4
        sta     fn_tx_buffer+4

        rts


; ============================================================================
; FN_SEND_PACKET - Send a FujiBus packet via serial
;
; SLIP-encodes the packet in fn_tx_buffer and sends via serial.
;
; Input:
;   fn_tx_buffer contains packet data
;   fn_tx_len = packet length
;
; Output:
;   Carry clear on success, set on error
; ============================================================================
fn_send_packet:
        ; Set up parameters for SLIP encode
        lda     #<fn_tx_buffer
        sta     aws_tmp00
        lda     #>fn_tx_buffer
        sta     aws_tmp01
        lda     fn_tx_len
        sta     aws_tmp02
        lda     fn_tx_len_hi
        sta     aws_tmp03

        ; SLIP encode
        jsr     fn_slip_encode

        ; Set up serial write
        ; _write_serial_data expects:
        ;   aws_tmp00/01 = buffer pointer
        ;   aws_tmp02/03 = length
        lda     #<fn_slip_buffer
        sta     aws_tmp00
        lda     #>fn_slip_buffer
        sta     aws_tmp01
        lda     fn_tx_len
        sta     aws_tmp02
        lda     fn_tx_len_hi
        sta     aws_tmp03

        ; Send via serial
        jsr     _write_serial_data

        ; Return success (carry clear)
        clc
        rts


; ============================================================================
; FN_RECEIVE_PACKET - Receive a FujiBus packet via serial
;
; Reads SLIP-encoded data, decodes, and validates checksum.
;
; Input:
;   None (reads from serial)
;
; Output:
;   fn_rx_buffer contains decoded packet
;   fn_rx_len = packet length
;   Carry clear on success, set on error
;   A = status (1=success, 0=error)
; ============================================================================
fn_receive_packet:
        ; Set up for serial read
        ; _read_serial_data expects:
        ;   aws_tmp00/01 = buffer pointer
        ;   aws_tmp02/03 = max length to read

        lda     #<fn_slip_buffer
        sta     aws_tmp00
        lda     #>fn_slip_buffer
        sta     aws_tmp01
        lda     #<FN_MAX_SLIP_SIZE
        sta     aws_tmp02
        lda     #>FN_MAX_SLIP_SIZE
        sta     aws_tmp03

        ; Set up serial port
        jsr     setup_serial_19200

        ; Read data
        jsr     _read_serial_data

        ; Restore output
        jsr     restore_output_to_screen

        ; Check if read was successful
        cmp     #$01
        bne     @receive_error

        ; SLIP decode
        ; Set up parameters for decode
        lda     #<fn_slip_buffer
        sta     aws_tmp00
        lda     #>fn_slip_buffer
        sta     aws_tmp01
        ; Use bytes read as length
        ; _read_serial_data returns count in aws_tmp04/05
        ; For now, use the slip buffer length
        lda     #<FN_MAX_SLIP_SIZE
        sta     aws_tmp02
        lda     #>FN_MAX_SLIP_SIZE
        sta     aws_tmp03

        jsr     fn_slip_decode

        ; Check if we got a valid packet
        lda     fn_rx_len
        cmp     #FN_HEADER_SIZE
        bcc     @receive_error  ; Too short

        ; Validate checksum
        ; Save checksum byte
        ldy     #$04
        lda     fn_rx_buffer,y
        pha

        ; Zero checksum for calculation
        lda     #$00
        sta     fn_rx_buffer+4

        ; Calculate checksum
        lda     #<fn_rx_buffer
        sta     aws_tmp00
        lda     #>fn_rx_buffer
        sta     aws_tmp01
        lda     fn_rx_len
        sta     aws_tmp02
        lda     fn_rx_len_hi
        sta     aws_tmp03

        jsr     fn_calc_checksum

        ; Compare with saved checksum
        pla
        cmp     fn_chk_sum
        bne     @receive_error

        ; Success
        lda     #$01
        clc
        rts

@receive_error:
        lda     #$00
        sec
        rts
