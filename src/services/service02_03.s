; Service call 02 - Claim private workspace
; Service call 03 - Auto-boot

; combined to save some space, and 03 is trivial

        .export service02_claim_privworkspace
        .export service03_autoboot

        .import  autoboot
        .import  osbyte_X0YFF
        .import  print_axy
        .import  print_string
        .import  remember_axy
        .import  save_static_to_private_workspace

        .include "fujinet.inc"

        .segment "CODE"

; On entry:
;  A = 02
;  X = rom slot
;  Y = first available page for PWS
service02_claim_privworkspace:

        dbg_string_axy "service02: "

        ; Y contains first available page for private workspace
        tya
        pha                             ; Save Y=PWS Page

        ; Set up workspace pointer at $B0/$B1, i.e. aws_tmp01 for ZP indirection
        sta     aws_tmp01

        ; get the private workspace location for this ROM that was allocated on boot. e.g. $17
        ldy     paged_rom_priv_ws,x
        tya
        and     #$40                     ; Preserve bit 6 - not sure why, this was in MMFS
        ora     aws_tmp01
        sta     paged_rom_priv_ws,x
        lda     #$00
        sta     aws_tmp00                ; $B0 = 0 (low byte)

        ; this seems to set force-reset flag to 0 if page has changed, which is AND'd against the power up indicator below
        cpy     aws_tmp01                ; Private workspace may have moved!
        beq     @samepage                ; If same as before

        ldy     #<fuji_force_reset
        sta     (aws_tmp00),y

@samepage:
        ; Read hard/soft BREAK
        lda     #$FD
        jsr     osbyte_X0YFF             ; X=0=soft,1=power up,2=hard
        dex                              ; X=FF=soft,0=power up,1=hard

        txa                              ; A=FF=soft,0=power up,1=hard
        ldy     #<fuji_force_reset
        and     (aws_tmp00),y
        sta     (aws_tmp00),y            ; So, PWSP:fuji_force_reset is +ve if: power up, hard reset or PSWP page has changed
        php
        ; OPTIMIZATION - requires fuji_own_sws_indicator to be after fuji_force_reset in memory
        iny                              ; This is the location after force reset, used for the "I Own SWS" indicator
        plp
        bpl     @notsoft                 ; If not soft break

        lda     (aws_tmp00),y            ; A=PWSP : fuji_own_sws_indicator
        bpl     @notsoft                 ; If PWSP "full"

        ; If soft break and pws is empty then I must have owned sws,
        ; so copy it to my pws.
        jsr     save_static_to_private_workspace

@notsoft:
        lda     #$00
        sta     (aws_tmp00),y            ; PWSP:fuji_own_sws_indicator = 0 => PWSP "full"

        ; RESET A=2 (service call), X=<rom slot>, Y=Original PWS page (before incrementing it for next caller)
        ldx     paged_ram_copy
        pla
        tay
        lda     #$02

        ; Here is where we claim 2 pages of PWS, only need 1 if we're not doing UTILS
        iny
        iny

; save a byte by sharing RTS between the 2 services
svr3_exit:
        rts

service03_autoboot:
        jsr     remember_axy
        sty     aws_tmp03
        lda     #$7A            ; keyboard scan
        jsr     OSBYTE
        txa
        bmi     jmp_autoboot
        cmp     #'F'            ; F for FujiNet break

        bne     svr3_exit
        lda     #$78
        jsr     OSBYTE

jmp_autoboot:
        jmp     autoboot

        rts
