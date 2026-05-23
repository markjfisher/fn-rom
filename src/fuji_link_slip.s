; Shared SLIP framing over a raw FujiNet link.
; The selected physical link implementation provides the fuji_link_* symbols.

        .export fuji_link_read_slip_frame
        .export fuji_link_write_slip_frame
        .export fuji_link_write_slip_frame_dual
        .export fuji_link_write_slip_frame_triple
        .export slip_emit_region

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
        .importzp cws_tmp1
        .importzp cws_tmp2
        .importzp cws_tmp3
        .importzp cws_tmp6
        .importzp cws_tmp7

        .importzp buffer_ptr

        .import fuji_link_restore_default_io
        .import fuji_link_setup
        .import fuji_link_check_byte_available
        .import fuji_link_read_byte
        .import fuji_link_write_byte

        .include "fujinet.inc"

        .segment "CODE"

WAIT_FIRST_MAX := 65000
WAIT_NEXT_MAX  := 2000

; SLIP-encode and write one contiguous region (aws_tmp00/01 = ptr, aws_tmp02/03 = len).
; Clobbers A, Y, aws_tmp04.
slip_emit_region:
        ldy     #$00

@loop:
        lda     aws_tmp02
        ora     aws_tmp03
        beq     @done_region

        lda     (aws_tmp00),y
        sta     aws_tmp04

        inc     aws_tmp00
        bne     :+
        inc     aws_tmp01
:
        lda     aws_tmp02
        bne     :+
        dec     aws_tmp03
:
        dec     aws_tmp02

        lda     aws_tmp04
        cmp     #SLIP_END
        beq     @write_esc_end
        cmp     #SLIP_ESCAPE
        beq     @write_esc_esc

        jsr     fuji_link_write_byte
        jmp     @loop

@write_esc_end:
        lda     #SLIP_ESCAPE
        jsr     fuji_link_write_byte
        lda     #SLIP_ESC_END
        jsr     fuji_link_write_byte
        jmp     @loop

@write_esc_esc:
        lda     #SLIP_ESCAPE
        jsr     fuji_link_write_byte
        lda     #SLIP_ESC_ESC
        jsr     fuji_link_write_byte
        jmp     @loop

@done_region:
        rts

; Read and decode one SLIP frame from the selected link into buffer_ptr.
; Output: A/X = decoded length, or 0/0 on error.
fuji_link_read_slip_frame:
        jsr     fuji_link_setup

        lda     buffer_ptr
        sta     aws_tmp08
        lda     buffer_ptr+1
        sta     aws_tmp09

        lda     #$00
        sta     aws_tmp05

        lda     #<WAIT_FIRST_MAX
        sta     aws_tmp10
        lda     #>WAIT_FIRST_MAX
        sta     aws_tmp11

@wait_start:
        jsr     fuji_link_check_byte_available
        beq     @dec_wait_start

        jsr     fuji_link_read_byte
        ldx     cws_tmp1
        beq     @start_byte_ok
        jmp     @read_error

@start_byte_ok:
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
        jmp     @read_error

@begin_frame:
        lda     buffer_ptr
        sta     aws_tmp08
        lda     buffer_ptr+1
        sta     aws_tmp09

        lda     #<FUJI_PWS_PACKET_SIZE
        sta     cws_tmp6
        lda     #>FUJI_PWS_PACKET_SIZE
        sta     cws_tmp7

@frame_loop:
        lda     #<WAIT_NEXT_MAX
        sta     aws_tmp10
        lda     #>WAIT_NEXT_MAX
        sta     aws_tmp11

@wait_char:
        jsr     fuji_link_check_byte_available
        beq     @dec_wait_char

        jsr     fuji_link_read_byte
        ldx     cws_tmp1
        bne     @read_error

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
        beq     @read_error

@error_pla:
        pla

@read_error:
        jsr     fuji_link_restore_default_io
        lda     #$00
        tax
        rts

@process_char:
        lda     aws_tmp04
        cmp     #SLIP_END
        beq     @handle_end

        lda     aws_tmp05
        bne     @escaped_byte

        lda     aws_tmp04
        cmp     #SLIP_ESCAPE
        beq     @set_escape

@store_byte:
        pha
        lda     cws_tmp6
        ora     cws_tmp7
        beq     @error_pla

        lda     cws_tmp6
        bne     @dec_cap_lo
        dec     cws_tmp7
@dec_cap_lo:
        dec     cws_tmp6

        pla
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
        bne     @read_error
:
        lda     #SLIP_END
        bne     @store_byte
:
        lda     #SLIP_ESCAPE
        bne     @store_byte

@set_escape:
        lda     #$01
        sta     aws_tmp05
        bne     @frame_loop

@handle_end:
        lda     aws_tmp08
        cmp     buffer_ptr
        bne     @done
        lda     aws_tmp09
        cmp     buffer_ptr+1
        bne     @done
        jmp     @frame_loop

@done:
        jsr     fuji_link_restore_default_io

        lda     aws_tmp05
        bne     @read_error

        lda     aws_tmp08
        sec
        sbc     buffer_ptr
        pha

        lda     aws_tmp09
        sbc     buffer_ptr+1
        tax

        pla
        rts

; Write one SLIP frame from a contiguous region.
fuji_link_write_slip_frame:
        jsr     fuji_link_setup

        lda     #SLIP_END
        jsr     fuji_link_write_byte

        jsr     slip_emit_region

        lda     #SLIP_END
        jsr     fuji_link_write_byte
        jmp     fuji_link_restore_default_io

; Write one SLIP frame from two contiguous regions.
fuji_link_write_slip_frame_dual:
        jsr     fuji_link_setup

        lda     #SLIP_END
        jsr     fuji_link_write_byte

        jsr     slip_emit_region

        lda     aws_tmp06
        sta     aws_tmp00
        lda     aws_tmp07
        sta     aws_tmp01
        lda     aws_tmp08
        sta     aws_tmp02
        lda     aws_tmp09
        sta     aws_tmp03

        jsr     slip_emit_region

        lda     #SLIP_END
        jsr     fuji_link_write_byte
        jmp     fuji_link_restore_default_io

; Write one SLIP frame from three contiguous regions.
; Region 1: aws_tmp00/01, aws_tmp02/03
; Region 2: aws_tmp06/07, aws_tmp08/09 (skipped if len=0)
; Region 3: cws_tmp2/3, cws_tmp6/7 (skipped if len=0)
fuji_link_write_slip_frame_triple:
        jsr     fuji_link_setup

        lda     #SLIP_END
        jsr     fuji_link_write_byte

        jsr     slip_emit_region

        lda     aws_tmp08
        ora     aws_tmp09
        beq     @skip_r2
        lda     aws_tmp06
        sta     aws_tmp00
        lda     aws_tmp07
        sta     aws_tmp01
        lda     aws_tmp08
        sta     aws_tmp02
        lda     aws_tmp09
        sta     aws_tmp03
        jsr     slip_emit_region
@skip_r2:

        lda     cws_tmp6
        ora     cws_tmp7
        beq     @skip_r3
        lda     cws_tmp2
        sta     aws_tmp00
        lda     cws_tmp3
        sta     aws_tmp01
        lda     cws_tmp6
        sta     aws_tmp02
        lda     cws_tmp7
        sta     aws_tmp03
        jsr     slip_emit_region
@skip_r3:

        lda     #SLIP_END
        jsr     fuji_link_write_byte
        jmp     fuji_link_restore_default_io
