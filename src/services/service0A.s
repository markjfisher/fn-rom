; Service call 0A - Claim static workspace
        .export service0A_claim_statworkspace

        .include "mos.inc"

        .segment "CODE"

service0A_claim_statworkspace:
        ; Another ROM wants the static workspace
        ; For now, we'll just acknowledge and let them have it
        ; In a full implementation, we'd save our state to private workspace
        rts
