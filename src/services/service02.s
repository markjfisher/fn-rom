; Service call 02 - Claim private workspace
        .export service02_claim_privworkspace

        .import  print_axy
        .import  print_string
        .import  osbyte_X0YFF
        .import  save_static_to_private_workspace

        .include "fujinet.inc"

        .segment "CODE"

service02_claim_privworkspace:

.ifdef FN_DEBUG
        jsr     print_string
        .byte   "D: service02", $0D
        nop
        jsr     print_axy
.endif

        ; Y contains first available page for private workspace
        tya
        pha                             ; Save Y=PWS Page
        
        ; Set up workspace pointer at $B0/$B1
        sta     aws_tmp01                ; $B1 = PWS page
        ldy     PagedROM_PrivWorkspaces,x
        tya
        and     #$40                     ; Preserve bit 6
        ora     aws_tmp01
        sta     PagedROM_PrivWorkspaces,x
        lda     #$00
        sta     aws_tmp00                ; $B0 = 0 (low byte)
        
        cpy     aws_tmp01                ; Private workspace may have moved!
        beq     @samepage                ; If same as before
        
        ldy     #<ForceReset             ; $D3
        sta     (aws_tmp00),y            ; PWSP+$D3=0
        
@samepage:
        ; Read hard/soft BREAK
        lda     #$FD
        jsr     osbyte_X0YFF             ; X=0=soft,1=power up,2=hard
        dex                              ; X=FF=soft,0=power up,1=hard
        
        txa                              ; A=FF=soft,0=power up,1=hard
        ldy     #<ForceReset             ; $D3
        and     (aws_tmp00),y
        sta     (aws_tmp00),y            ; So, PWSP+$D3 is +ve if: power up, hard reset or PSWP page has changed
        php
        iny                              ; $D4
        plp
        bpl     @notsoft                 ; If not soft break
        
        lda     (aws_tmp00),y            ; A=PWSP+$D4
        bpl     @notsoft                 ; If PWSP "full"
        
        ; If soft break and pws is empty then I must have owned sws,
        ; so copy it to my pws.
        jsr     save_static_to_private_workspace
        
@notsoft:
        lda     #$00
        sta     (aws_tmp00),y            ; PWSP+$D4=0 = PWSP "full"

        ldx     PagedRomSelector_RAMCopy
        pla
        tay
        lda     #$02
        iny
        iny
        
        rts
