; Service call 01 - Claim absolute workspace
        .export service01_claim_absworkspace

        .import  print_axy
        .import  print_string

        .include "fujinet.inc"

        .segment "CODE"

service01_claim_absworkspace:

        dbg_string_axy "service01: "

        ; Y contains current upper limit of absolute workspace
        ; We need to claim workspace up to $17 (like MMFS)
        cpy     #$17
        bcs     @exit                    ; already >= $17
        ldy     #$17                     ; set upper limit to $17
@exit:
        rts
