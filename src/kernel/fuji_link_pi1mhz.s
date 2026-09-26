; FujiNet link over the 1MHz bus to a Pi1MHz (BUILD_INTERFACE=1MHZ).
;
; Replaces fuji_link_slip.s in this build. It keeps that file's five frame
; entry points and their register contracts, so fujibus.s and everything
; above it are unchanged - but a whole FujiBus packet goes to the Pi at once
; through its services port, with no SLIP and no RS423.
;
; The exchange (Pi1MHz docs/dev/fujinet-device.md):
;   - the request is written to buffer offset &000000 through the port's
;     auto-incrementing data register;
;   - a command block at &FFF000 names it and a 2 KB reply area at &000800:
;       [0] 114  [1..3] request offset  [4..5] request length
;       [6..8] reply offset  [9..10] reply capacity  -> [11..12] reply length
;   - writing &F0 (the block's page) to the command register runs it. The
;     register reads back with bit 7 set until the Pi has answered; then 0
;     means a reply is waiting. Anything else means there is none, as when
;     a serial device drops a bad packet.
;
; A write only rings the Pi; the following read waits for the answer.

.ifdef FUJINET_INTERFACE_1MHZ

        .export fuji_link_read_slip_frame
        .export fuji_link_read_slip_frame_to_payload
        .export fuji_link_write_slip_frame
        .export fuji_link_write_slip_frame_dual
        .export fuji_link_write_slip_frame_triple

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
        .importzp aws_tmp12
        .importzp aws_tmp13
        .importzp cws_tmp2
        .importzp cws_tmp3
        .importzp cws_tmp6
        .importzp cws_tmp7

        .importzp buffer_ptr

        .include "fujinet.inc"

        .segment "CODE"

PI_ADDR_LO      := $FCA6
PI_ADDR_MID     := $FCA7
PI_ADDR_HI      := $FCA8
PI_DATA         := $FCA9        ; auto-increments on every access
PI_CMD          := $FCAA

PI_BLOCK_PAGE   := $F0          ; command block at &FFF000
PI_EXCHANGE     := 114
PI_REPLY_MID    := $08          ; reply area at &000800 ...
PI_REPLY_CAP_HI := $08          ; ... of &0800 bytes

; About five seconds of polling at 2MHz before a read gives up, for an SD
; card that is slow to answer (serial waits for bytes in the same spirit).
PI_WAIT_OUTER   := 12

; Point the port at the command block, byte A.
pi_address_block:
        sta     PI_ADDR_LO
        lda     #PI_BLOCK_PAGE
        sta     PI_ADDR_MID
        lda     #$FF
        sta     PI_ADDR_HI
        rts

; Write one contiguous region (aws_tmp00/01 = ptr, aws_tmp02/03 = len) to
; the data port. Clobbers A, Y, aws_tmp00-03.
pi_emit_region:
        ldy     #$00
@loop:
        lda     aws_tmp02
        ora     aws_tmp03
        beq     @done
        lda     (aws_tmp00),y
        sta     PI_DATA
        inc     aws_tmp00
        bne     :+
        inc     aws_tmp01
:
        lda     aws_tmp02
        bne     :+
        dec     aws_tmp03
:
        dec     aws_tmp02
        jmp     @loop
@done:
        rts

; Write one frame from a contiguous region.
fuji_link_write_slip_frame:
        lda     #$00
        sta     aws_tmp08
        sta     aws_tmp09
        sta     cws_tmp6
        sta     cws_tmp7
        jmp     fuji_link_write_slip_frame_triple

; Write one frame from two contiguous regions.
fuji_link_write_slip_frame_dual:
        lda     #$00
        sta     cws_tmp6
        sta     cws_tmp7
        ; fall through

; Write one frame from three contiguous regions, and ring the Pi.
; Region 1: aws_tmp00/01, aws_tmp02/03
; Region 2: aws_tmp06/07, aws_tmp08/09 (skipped if len=0)
; Region 3: cws_tmp2/3, cws_tmp6/7 (skipped if len=0)
; Clobbers A, X, Y, aws_tmp00-03 (serial clobbers aws_tmp00-04).
fuji_link_write_slip_frame_triple:
        ; The command block first, while the region lengths are intact.
        lda     #$00
        jsr     pi_address_block
        lda     #PI_EXCHANGE
        sta     PI_DATA
        lda     #$00                    ; request at &000000
        sta     PI_DATA
        sta     PI_DATA
        sta     PI_DATA
        clc                             ; length = region 1 + 2 + 3
        lda     aws_tmp02
        adc     aws_tmp08
        tax
        lda     aws_tmp03
        adc     aws_tmp09
        tay
        clc
        txa
        adc     cws_tmp6
        sta     PI_DATA
        tya
        adc     cws_tmp7
        sta     PI_DATA
        lda     #$00                    ; reply at &000800
        sta     PI_DATA
        lda     #PI_REPLY_MID
        sta     PI_DATA
        lda     #$00
        sta     PI_DATA
        sta     PI_DATA                 ; capacity &0800
        lda     #PI_REPLY_CAP_HI
        sta     PI_DATA

        ; The packet, region by region.
        lda     #$00
        sta     PI_ADDR_LO
        sta     PI_ADDR_MID
        sta     PI_ADDR_HI
        jsr     pi_emit_region
        lda     aws_tmp06
        sta     aws_tmp00
        lda     aws_tmp07
        sta     aws_tmp01
        lda     aws_tmp08
        sta     aws_tmp02
        lda     aws_tmp09
        sta     aws_tmp03
        jsr     pi_emit_region
        lda     cws_tmp2
        sta     aws_tmp00
        lda     cws_tmp3
        sta     aws_tmp01
        lda     cws_tmp6
        sta     aws_tmp02
        lda     cws_tmp7
        sta     aws_tmp03
        jsr     pi_emit_region

        lda     #PI_BLOCK_PAGE
        sta     PI_CMD
        rts

; Wait for the Pi's answer to the last write and point the port at the
; reply. Exit: C clear with aws_tmp02/03 = reply length, aws_tmp00 = 0
; (running checksum) and aws_tmp04/05 = 0 (byte index); C set if the Pi
; did not answer in time or gave no reply. Clobbers A, X, aws_tmp10/11.
pi_wait_reply:
        ldx     #$00
        stx     aws_tmp10
        lda     #PI_WAIT_OUTER
        sta     aws_tmp11
@poll:
        lda     PI_CMD
        bpl     @answered
        dex
        bne     @poll
        dec     aws_tmp10
        bne     @poll
        dec     aws_tmp11
        bne     @poll
        sec
        rts
@answered:
        bne     @no_reply               ; A = result, bit 7 clear
        lda     #11
        jsr     pi_address_block
        lda     PI_DATA
        sta     aws_tmp02
        lda     PI_DATA
        sta     aws_tmp03
        lda     #$00
        sta     PI_ADDR_LO
        lda     #PI_REPLY_MID
        sta     PI_ADDR_MID
        lda     #$00
        sta     PI_ADDR_HI
        sta     aws_tmp00
        sta     aws_tmp01
        sta     aws_tmp04
        sta     aws_tmp05
        clc
        rts
@no_reply:
        sec
        rts

; Take the next reply byte into A and aws_tmp01's checksum: byte 4 is the
; received checksum (kept in aws_tmp01, counted as zero), every other byte
; is folded into aws_tmp00 with end-around carry, exactly as the SLIP
; reader does. Advances the index aws_tmp04/05. Preserves Y.
pi_take_byte:
        lda     aws_tmp05
        bne     @normal
        lda     aws_tmp04
        cmp     #$04
        bne     @normal
        lda     PI_DATA
        sta     aws_tmp01
        jmp     @count
@normal:
        lda     PI_DATA
        pha
        clc
        adc     aws_tmp00
        adc     #$00
        sta     aws_tmp00
        pla
@count:
        inc     aws_tmp04
        bne     :+
        inc     aws_tmp05
:
        rts

; Is the reply index aws_tmp04/05 at its length aws_tmp02/03? Z set if so.
pi_at_end:
        lda     aws_tmp04
        cmp     aws_tmp02
        bne     :+
        lda     aws_tmp05
        cmp     aws_tmp03
:
        rts

; Read one frame into buffer_ptr (at most FUJI_PWS_PACKET_SIZE bytes).
; Output: A/X = length, or 0/0 on error; aws_tmp00 = running checksum with
; byte 4 as zero; aws_tmp01 = received checksum byte.
fuji_link_read_slip_frame:
        jsr     pi_wait_reply
        bcs     pi_read_error
        lda     aws_tmp03               ; longer than the buffer: an error,
        cmp     #>FUJI_PWS_PACKET_SIZE  ; as the SLIP reader makes it
        bcc     @fits
        bne     pi_read_error
        lda     aws_tmp02
        cmp     #<FUJI_PWS_PACKET_SIZE+1
        bcs     pi_read_error
@fits:
        lda     buffer_ptr
        sta     aws_tmp08
        lda     buffer_ptr+1
        sta     aws_tmp09
        ldy     #$00
@loop:
        jsr     pi_at_end
        beq     pi_read_done
        jsr     pi_take_byte
        sta     (aws_tmp08),y
        inc     aws_tmp08
        bne     @loop
        inc     aws_tmp09
        jmp     @loop

pi_read_done:
        lda     aws_tmp02
        ldx     aws_tmp03
        rts

pi_read_error:
        lda     #$00
        tax
        rts

; Read one frame: the first seven bytes to buffer_ptr (bytes 5 and 6, the
; descriptor and status, also to aws_tmp12/13), the rest to aws_tmp06/07 up
; to the capacity aws_tmp08/09. Payload beyond the capacity is read and
; checksummed but not stored; the caller compares the length with its
; capacity. Output as fuji_link_read_slip_frame.
fuji_link_read_slip_frame_to_payload:
        lda     aws_tmp06
        sta     cws_tmp2
        lda     aws_tmp07
        sta     cws_tmp3
        lda     aws_tmp08
        sta     cws_tmp6
        lda     aws_tmp09
        sta     cws_tmp7
        jsr     pi_wait_reply
        bcs     pi_read_error
@header:
        jsr     pi_at_end
        beq     pi_read_done
        lda     aws_tmp05
        bne     @payload
        ldy     aws_tmp04
        cpy     #$07
        bcs     @payload
        jsr     pi_take_byte
        sta     (buffer_ptr),y
        cpy     #$05
        bne     :+
        sta     aws_tmp12
:
        cpy     #$06
        bne     @header
        sta     aws_tmp13
        jmp     @header
@payload:
        jsr     pi_at_end
        beq     pi_read_done
        jsr     pi_take_byte
        tax
        lda     cws_tmp6
        ora     cws_tmp7
        beq     @payload                ; over capacity: drained, not stored
        txa
        ldy     #$00
        sta     (cws_tmp2),y
        inc     cws_tmp2
        bne     :+
        inc     cws_tmp3
:
        lda     cws_tmp6
        bne     :+
        dec     cws_tmp7
:
        dec     cws_tmp6
        jmp     @payload

.endif  ; FUJINET_INTERFACE_1MHZ
