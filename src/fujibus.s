; FujiBus Protocol Implementation for BBC Micro
; Implements SLIP framing and FujiBus packet handling
; Compatible with fujinet-nio FujiBus protocol
;
; Based on reference implementations:
; - py/fujinet_tools/fujibus.py
; - fujinet-nio-lib/src/common/fn_slip.c
; - fujinet-nio-lib/src/common/fn_packet.c

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
        .import _calc_checksum
        .import setup_serial_19200
        .import restore_output_to_screen
        .import inc_word_aws_tmp00_dec_word_aws_tmp02

        .include "fujinet.inc"

; ============================================================================
; Local Constants (not in fujinet.inc)
; ============================================================================

; Maximum SLIP buffer size for BBC DFS operations
; Disk sector = 256 bytes, FujiBus header = 6 bytes, payload overhead = ~10 bytes
; Max response = 6 + 13 + 256 = 275 bytes
; Max SLIP encoded = 275 * 2 + 2 = 552 bytes
FN_MAX_SLIP_SIZE = 640      ; 2x max packet + margin

; ============================================================================
; Buffers - Memory-efficient layout staying under PAGE ($1900)
; ============================================================================
; Memory map (see also os.s for fuji_* symbols that share these regions):
; $0E00-$0FFF - Catalog area (512 bytes) - also used for large RX ops
; $1000-$10FF - FujiNet workspace variables (scalars, not buffers)
; $1100-$111F - Channel workspace (fuji_channel_start etc.)
; $1120-$115F - FujiBus TX buffer (64 bytes)  OVERLAPS os.s fuji_current_fs_uri
; $1160-$135F - FujiBus RX buffer (512 bytes) OVERLAPS os.s fuji_current_dir_path
; $1360-$18FF - Available for future use
; $1900       - PAGE limit (DO NOT EXCEED!)
;
; OVERLAP: os.s defines fuji_current_fs_uri=$1120 and fuji_current_dir_path=$1160.
; Building a packet in fn_tx_buffer overwrites the current FS URI. RX/slip use
; the same 512 bytes as fuji_current_dir_path. Code that builds TX payloads must
; not assume the base-URI pointer is valid after writing to fn_tx_buffer (hence
; the precopy in fn_file_resolve_path).
;
; 64-BYTE LIMIT: FN_TX_BUFFER_SIZE=64 is too small for long URLs. ResolvePath
; payload = 1 + 2 + base_uri_len + 2 + arg_len; with 255-byte URI + 255-byte arg
; that is 515 bytes. Short URIs (e.g. "HOST:/FILE.SSD", ~16 chars) fit in the
; 58-byte payload area (64 - 6 header). Long-URL support will need a larger TX
; build area (e.g. in $1360-$18FF) or streaming; not yet implemented.
; ============================================================================

; Transmit buffer - 64 bytes at $1120 (shared with fuji_current_fs_uri in os.s)
fn_tx_buffer    = $1120
FN_TX_BUFFER_SIZE = 64

; Receive buffer - 512 bytes at $1160 (for responses with sector data)
fn_rx_buffer    = $1160
FN_RX_BUFFER_SIZE = 512

; SLIP working buffer - reuse RX buffer area during encoding
; (TX and RX don't happen simultaneously)
fn_slip_buffer  = $1160

; Buffer lengths - use workspace variables
fn_tx_len       = $10FE
fn_tx_len_hi    = $10FF

fn_rx_len       = $10FC
fn_rx_len_hi    = $10FD

; ============================================================================
; CODE segment
; ============================================================================

        .segment "CODE"

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
;   aws_tmp00/01 = pointer to payload data (ignored if Y=0)
;
; Output:
;   fn_tx_buffer contains complete packet
;   fn_tx_len = total packet length
; ============================================================================
fn_build_packet:
        ; Store header bytes directly - no stack nonsense
        sta     fn_tx_buffer+0          ; Device ID
        stx     fn_tx_buffer+1          ; Command

        ; Calculate total length = header(6) + payload
        sty     fn_tx_len               ; Save payload length
        tya
        clc
        adc     #FN_HEADER_SIZE
        sta     fn_tx_len
        sta     fn_tx_buffer+2          ; Length low in header
        lda     #$00
        sta     fn_tx_len_hi            ; High byte always 0 for small packets
        sta     fn_tx_buffer+3          ; Length high in header
        sta     fn_tx_buffer+4          ; Checksum placeholder (0 for calculation)
        sta     fn_tx_buffer+5          ; Descriptor (0 for simple packets)

        ; Copy payload if present
        cpy     #$00
        beq     @calc_checksum

        ; Save payload pointer (we need aws_tmp00/01 for checksum later)
        lda     aws_tmp00
        pha
        lda     aws_tmp01
        pha

        ; Copy payload using Y as index (counting down from length-1)
        dey                             ; Y = payload_len - 1
@copy_loop:
        lda     (aws_tmp00),y
        sta     fn_tx_buffer+FN_HEADER_SIZE,y
        dey
        bpl     @copy_loop

        ; Restore payload pointer
        pla
        sta     aws_tmp01
        pla
        sta     aws_tmp00

@calc_checksum:
        ; Calculate checksum using existing optimized routine
        ; _calc_checksum expects: aws_tmp00/01 = buf, aws_tmp02/03 = len
        ; Returns checksum in A
        lda     #<fn_tx_buffer
        sta     aws_tmp00
        lda     #>fn_tx_buffer
        sta     aws_tmp01
        lda     fn_tx_len
        sta     aws_tmp02
        lda     #$00
        sta     aws_tmp03

        jsr     _calc_checksum

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

        ; Calculate checksum using optimized routine
        lda     #<fn_rx_buffer
        sta     aws_tmp00
        lda     #>fn_rx_buffer
        sta     aws_tmp01
        lda     fn_rx_len
        sta     aws_tmp02
        lda     fn_rx_len_hi
        sta     aws_tmp03

        jsr     _calc_checksum

        ; Compare with saved checksum (returned in A, also in aws_tmp04)
        pla
        cmp     aws_tmp04       ; _calc_checksum stores result here
        bne     @receive_error

        ; Success
        lda     #$01
        clc
        rts

@receive_error:
        lda     #$00
        sec
        rts
