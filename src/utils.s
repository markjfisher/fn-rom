        .export  a_rolx4
        .export  a_rolx5
        .export  a_rorx2and3
        .export  a_rorx3
        .export  a_rorx4
        .export  a_rorx4and3
        .export  a_rorx5
        .export  a_rorx6and3
        .export  do_vblank_loop
        .export  inc_word_aws_tmp00_dec_word_aws_tmp02
        .export  GSINIT_A
        .export  is_alpha_char
        .export  osbyte_0f_flush_inbuf2
        .export  osbyte_13_delay_a
        .export  osbyte_X0YFF
        .export  osbyte_YFF
        .export  vblank_end
        .export  set_text_pointer_yx
        .export  tube_check_if_present
        .export  ucasea2
        .export  y_add7
        .export  y_add8
        .export  vblank
        .export  network_retry_init
        .export  network_retry_backoff

        .export tube_claim
        .export tube_release
        .export tube_release_no_check

        .importzp aws_tmp00
        .importzp aws_tmp01
        .importzp aws_tmp02
        .importzp aws_tmp03
        .import fuji_network_retry_delay
        .import fuji_network_retry_left
        .import fuji_network_retry_max
        .importzp text_pointer

        .import GSINIT
        .import OSBYTE
        .import fuji_channel_scratch
        .import fuji_tube_present
        .import remember_axy
        .import tube_code

        .include "fujinet.inc"

        .segment "CODE"


; set A to be the number of 1/50ths of a second to delay (via vertical sync)
; exit: restores AXY to their values passed in
vblank:
osbyte_13_delay_a:
        jsr     remember_axy
do_vblank_loop:
        sta     fuji_channel_scratch
@delay:
        lda     #$13             ; OSBYTE 19 - Wait for vertical sync
        jsr     OSBYTE
        dec     fuji_channel_scratch
        bne     @delay
vblank_end:
        rts


; Initialise NotReady retry state
network_retry_init:
        lda     fuji_network_retry_max
        bne     @use_max
        lda     #NET_RETRY_MAX
@use_max:
        sta     fuji_network_retry_left
        lda     #NET_RETRY_DELAY_INIT
        sta     fuji_network_retry_delay
        rts


; Wait with exponential backoff before retrying a NotReady network operation.
;   Out: C clear = ok to retry; C set = exhausted
network_retry_backoff:
        dec     fuji_network_retry_left
        beq     @exhausted
        lda     fuji_network_retry_delay
        jsr     vblank
        asl     a
        cmp     #NET_RETRY_DELAY_MAX + 1
        bcs     @cap_delay
        sta     fuji_network_retry_delay
        clc
        rts
@cap_delay:
        lda     #NET_RETRY_DELAY_MAX
        sta     fuji_network_retry_delay
        clc
        rts
@exhausted:
        sec
        rts


osbyte_0f_flush_inbuf2:
        jsr     remember_axy
        lda     #$0f
        ldx     #$01
        ldy     #$00
        jmp     OSBYTE


; For Lots of OSBYTE calls, the formula for NEW and OLD values for the service call is
; NEW = (OLD & Y) EOR X
; with X=0, Y=FF, this becomes "no change", i.e. NEW == OLD
; Thus we fetch the current value and don't amend it.
osbyte_X0YFF:
        ldx     #0
osbyte_YFF:
        ldy     #$FF
        jmp     OSBYTE

; a_rorx6and3 - Shift A right by 6 bits and mask with 3
; Translated from MMFS lines 589-598
a_rorx6and3:
        lsr     a                       ; Shift right 2 bits
        lsr     a
        ; Fall into a_rorx4and3
a_rorx4and3:
        lsr     a                       ; Shift right 2 more bits (total 4)
        lsr     a
        ; Fall into a_rorx2and3
a_rorx2and3:
        lsr     a                       ; Shift right 2 more bits (total 6)
        lsr     a
        and     #$03                    ; Mask with 3
        rts

a_rorx5:
        lsr     a
a_rorx4:
        lsr     a
a_rorx3:
        lsr     a
        lsr     a
        lsr     a
        rts

a_rolx5:
        asl     a
a_rolx4:
        asl     a
        asl     a
        asl     a
        asl     a
        rts

GSINIT_A:
        clc
        jmp     GSINIT

set_text_pointer_yx:
        stx     text_pointer
        sty     text_pointer+1
        ldy     #$00
        rts

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; Tube check if present
; Exit: A=0 if tube present, $FF if not

; from New Advanced User Guide:
;  Before attempting to use any of the Tube routines an OSBYTE call with
;  A=&EA, X=0 and Y=&FF should be made to establish whether a Tube is
;  present on the machine. The X register will be returned with the value
;  &FF if a Tube is present and with zero otherwise.
;
; This function converts the result to A=0 if tube present, $FF if not,
; and sets fuji_tube_present to this value, i.e. "Tube present if this value is zero"
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

tube_check_if_present:
        lda     #$EA
        ldx     #$00
        ldy     #$FF
        jsr     OSBYTE
        txa
        eor     #$FF
        sta     fuji_tube_present
        rts

y_add8:
        iny
y_add7:
        iny
        iny
        iny
        iny
        iny
        iny
        iny
        rts
; Checks if the char is between $41 and $5A (A-Z)
; Exit: C=0 if alpha, 1 if not
is_alpha_char:
        pha
        and     #$5F
        cmp     #$41
        bcc     @exit1                  ; If <"A"
        cmp     #$5B
        bcc     @exit2                  ; If <="Z"
@exit1:
        sec
@exit2:
        pla
        rts

ucasea2:
        php
        jsr     is_alpha_char
        bcs     @ucasea
        and     #$5F                    ; A = Ucase(A)
@ucasea:
        and     #$7F                    ; Ignore bit 7
        plp
        rts

; Increments aws_tmp00/01 (buffer location) and
; decrements aws_tmp02/03 (used for count).
; Returns with C=0 if not reached 0, C=1 when zero reached
inc_word_aws_tmp00_dec_word_aws_tmp02:
        ; increment
        inc     aws_tmp00
        bne     :+
        inc     aws_tmp01

        ; decrement
:       lda     aws_tmp02
        bne     :+
        dec     aws_tmp03
:       dec     aws_tmp02
        ; check if we hit 0 so we can use BEQ
        lda     aws_tmp02
        ora     aws_tmp03
        rts

tube_claim:
        pha
@tclaim_loop:
        lda     #$C0 + tube_id    ; see comment below about tube_id
        jsr     tube_code
        bcc     @tclaim_loop
        pla
        rts

tube_release:
        jsr     tube_check_if_present
        bmi     trelease_exit

tube_release_no_check:
        pha
        ; #$80 + tubeid ($0A iin mmfs), commentary from MMFS:
        ;   See Tube Application Note No.004 Page 7
        ;   &0A is unallocated so shouldn't clash
        lda     #$80 + tube_id
        jsr     tube_code
        pla

trelease_exit:
        rts
