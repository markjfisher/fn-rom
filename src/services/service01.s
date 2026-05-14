; Service call 01 - Claim absolute workspace
        .export service01_claim_absworkspace

        .segment "CODE"

service01_claim_absworkspace:
        ; Y contains current upper limit of absolute workspace
        ; We need to claim workspace up to $17 (like MMFS, which copies DFS - see p115 of Advanced Disk User Guide)
        ; this means $0E00 to $16FF become absolute workspace locations.
        cpy     #$17
        bcs     @exit                    ; already >= $17
        ldy     #$17                     ; set upper limit to $17
@exit:
        rts
