; Service call 02 - Claim private workspace
        .export service02_claim_privworkspace

        .include "mos.inc"

        .segment "CODE"

service02_claim_privworkspace:
        ; Y contains first available page for private workspace
        ; Store it in our private workspace slot
        tya
        sta     PagedROM_PrivWorkspaces,x
        
        ; Set up workspace pointer at $B0/$B1
        sta     aws_tmp01                ; $B1 = PWS page
        lda     #$00
        sta     aws_tmp00                ; $B0 = 0 (low byte)
        
        rts
