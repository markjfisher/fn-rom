        .export  fujibus_read_slip_stream

        .import  _check_rs423_buffer
        .import  _read_rs423_char
        .import  setup_serial_19200
        .import  restore_output_to_screen

        .include "fujinet.inc"

WAIT_FIRST_MAX := 50000
WAIT_NEXT_MAX  := 2000

; Read and decode one SLIP frame from RS423 into the buffer at buffer_ptr.
; Decoded length is capped at FUJI_PWS_PACKET_SIZE bytes.
;
; Output:
;   A/X = decoded length
;   0/0 on error
;
; Uses:
;   aws_tmp04 = current byte
;   aws_tmp05 = escape flag
;   aws_tmp08/09 = output pointer
;   aws_tmp10/11 = wait countdown
;   cws_tmp6/7   = bytes remaining (decode capacity)

fujibus_read_slip_stream:
        jsr     setup_serial_19200

        lda     buffer_ptr
        sta     aws_tmp08
        lda     buffer_ptr+1
        sta     aws_tmp09

        lda     #$00
        sta     aws_tmp05          ; escape flag = 0

;-----------------------------------------
; Wait for start-of-frame END
;-----------------------------------------

        lda     #<WAIT_FIRST_MAX
        sta     aws_tmp10
        lda     #>WAIT_FIRST_MAX
        sta     aws_tmp11

@wait_start:

        jsr     _check_rs423_buffer
        beq     @dec_wait_start

        jsr     _read_rs423_char
        ldx     cws_tmp1
        beq     @no_error
        jmp     @error

@no_error:
        cmp     #SLIP_END
        bne     @wait_start

        jmp     @begin_frame

@dec_wait_start:
        lda     aws_tmp10
        bne     :+
        dec     aws_tmp11
:
        dec     aws_tmp10

        lda     aws_tmp10
        ora     aws_tmp11
        bne     @wait_start

        jmp     @error

;-----------------------------------------
; Begin frame: reset output pointer and capacity
;-----------------------------------------

@begin_frame:
        lda     buffer_ptr
        sta     aws_tmp08
        lda     buffer_ptr+1
        sta     aws_tmp09

        lda     #<FUJI_PWS_PACKET_SIZE
        sta     cws_tmp6
        lda     #>FUJI_PWS_PACKET_SIZE
        sta     cws_tmp7

;-----------------------------------------
; Frame decode loop
;-----------------------------------------

@frame_loop:

        lda     #<WAIT_NEXT_MAX
        sta     aws_tmp10
        lda     #>WAIT_NEXT_MAX
        sta     aws_tmp11

@wait_char:

        jsr     _check_rs423_buffer
        beq     @dec_wait_char

        jsr     _read_rs423_char
        ldx     cws_tmp1
        bne     @read_err

        sta     aws_tmp04
        beq     @process_char

@read_err:
        jmp     @error

@dec_wait_char:
        lda     aws_tmp10
        bne     :+
        dec     aws_tmp11
:
        dec     aws_tmp10

        lda     aws_tmp10
        ora     aws_tmp11
        bne     @wait_char
        beq     @error

;-----------------------------------------
; Error exit
;-----------------------------------------

@error_pla:
        pla                                     ; clean up the pushed byte

@error:
        jsr     restore_output_to_screen
        lda     #$00
        tax
        rts

;-----------------------------------------
; Process received byte
;-----------------------------------------

@process_char:

        lda     aws_tmp04
        cmp     #SLIP_END
        beq     @handle_end

        lda     aws_tmp05
        bne     @escaped_byte

        lda     aws_tmp04
        cmp     #SLIP_ESCAPE
        beq     @set_escape

        ; fall through to storing the byte
        ; jmp     @store_byte

@store_byte:
        pha                                     ; save the byte to store while we check capacity
        lda     cws_tmp6
        ora     cws_tmp7
        beq     @error_pla

        ; Decrement capacity
        lda     cws_tmp6
        bne     @dec_cap_lo
        dec     cws_tmp7
@dec_cap_lo:
        dec     cws_tmp6

        pla                                     ; fetch the byte to save again, the capacity check passed
        ldy     #$00
        sta     (aws_tmp08),y
        inc     aws_tmp08
        bne     @after_inc_hi
        inc     aws_tmp09
@after_inc_hi:
        jmp     @frame_loop

@escaped_byte:
        lda     #$00
        sta     aws_tmp05

        lda     aws_tmp04
        cmp     #SLIP_ESC_END
        beq     :+
        cmp     #SLIP_ESC_ESC
        beq     :++
        bne     @error
:
        lda     #SLIP_END
        bne     @store_byte                     ; always
:
        lda     #SLIP_ESCAPE
        bne     @store_byte                     ; always

@set_escape:
        lda     #$01
        sta     aws_tmp05
        bne     @frame_loop

@handle_end:
        ; ignore repeated leading ENDs
        lda     aws_tmp08
        cmp     buffer_ptr
        bne     @done
        lda     aws_tmp09
        cmp     buffer_ptr+1
        bne     @done
        jmp     @frame_loop

;-----------------------------------------
; Frame finished
;-----------------------------------------

@done:
        jsr     restore_output_to_screen

        lda     aws_tmp05
        bne     @error

        lda     aws_tmp08
        sec
        sbc     buffer_ptr
        pha

        lda     aws_tmp09
        sbc     buffer_ptr+1
        tax

        pla
        rts
