; Register utility functions for BBC ROM development
; Common patterns for preserving registers across calls

        .export save_axy
        .export restore_axy
        .export save_axy_and_call
        .export return_with_carry_set
        .export return_with_carry_clear

        .segment "CODE"

; Save A, X, Y registers on stack
save_axy:
        pha
        txa
        pha
        tya
        pha
        rts

; Restore A, X, Y registers from stack
restore_axy:
        pla
        tay
        pla
        tax
        pla
        rts

; Save AXY, call function, restore AXY
; Usage: JSR save_axy_and_call / JMP target_function
save_axy_and_call:
        pha
        txa
        pha
        tya
        pha
        
        ; Set up return to restore_axy
        lda     #>(restore_axy-1)
        pha
        lda     #<(restore_axy-1)
        pha
        
        ; The target function address should be on the stack
        ; This is a simplified version - the full RememberAXY is more complex
        rts

; Return with carry set (error condition)
return_with_carry_set:
        sec
        rts

; Return with carry clear (success)
return_with_carry_clear:
        clc
        rts
