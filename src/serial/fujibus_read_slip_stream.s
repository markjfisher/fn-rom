        .export  fujibus_read_slip_stream

        .import  _check_rs423_buffer
        .import  _read_rs423_char

        .include "fujinet.inc"

WAIT_FIRST_MAX := 50000
WAIT_NEXT_MAX  := 2000

; Read and decode one SLIP frame from RS423
;
; Output:
;   A/X = decoded length
;   0/0 on error
;
; Uses:
;   aws_tmp04 = current byte
;   aws_tmp05 = escape flag
;   aws_tmp08/09 = output pointer
;   aws_tmp10/11 = wait counter

fujibus_read_slip_stream:

        lda     #<fuji_data_buffer
        sta     aws_tmp08
        lda     #>fuji_data_buffer
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
        lda     cws_tmp1
        beq     @no_error
        jmp     @error

@no_error:
        cmp     #SLIP_END
        bne     @wait_start

        jmp     @frame_loop

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
        lda     cws_tmp1
        bne     @error

        sta     aws_tmp04
        jmp     @process_char

@dec_wait_char:
        lda     aws_tmp10
        bne     :+
        dec     aws_tmp11
:
        dec     aws_tmp10

        lda     aws_tmp10
        ora     aws_tmp11
        bne     @wait_char

        jmp     @error

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

        lda     aws_tmp04
        jmp     @store_byte

@escaped_byte:
        lda     #$00
        sta     aws_tmp05

        lda     aws_tmp04
        cmp     #SLIP_ESC_END
        beq     :+
        cmp     #SLIP_ESC_ESC
        beq     :++
        jmp     @error
:
        lda     #SLIP_END
        jmp     @store_byte
:
        lda     #SLIP_ESCAPE
        jmp     @store_byte

@set_escape:
        lda     #$01
        sta     aws_tmp05
        jmp     @frame_loop

@handle_end:
        ; ignore repeated leading ENDs
        lda     aws_tmp08
        cmp     #<fuji_data_buffer
        bne     @done
        lda     aws_tmp09
        cmp     #>fuji_data_buffer
        bne     @done
        jmp     @frame_loop

@store_byte:
        ldy     #$00
        sta     (aws_tmp08),y
        inc     aws_tmp08
        bne     @frame_loop
        inc     aws_tmp09
        jmp     @frame_loop

;-----------------------------------------
; Frame finished
;-----------------------------------------

@done:

        lda     aws_tmp05
        bne     @error

        lda     aws_tmp08
        sec
        sbc     #<fuji_data_buffer
        pha

        lda     aws_tmp09
        sbc     #>fuji_data_buffer
        tax

        pla
        rts

;-----------------------------------------
; Error exit
;-----------------------------------------

@error:
        lda     #$00
        tax
        rts