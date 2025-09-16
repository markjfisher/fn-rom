; RememberAXY - Save AXY registers and restore after subroutine call
; Usage: JSR remember_axy / JMP target_function
; This preserves A, X, Y across the target function call

; On exit of calling remember_axy, A/X/Y will be preserved AND the stack has the following bytes on it,
; which will be retrieved from the bottom up, so an RTS will jump to rAXY_restore
; where it can read the A/X/Y values from the stack
;
; A
; X
; Y
; rAXY_restore-1 H
; rAXY_restore-1 L

        .export remember_axy
        .export return_with_a0

        .segment "CODE"

remember_axy:
        ; Save A, X, Y on stack
        pha
        txa
        pha
        tya
        pha
        
        ; Set up return address to rAXY_restore
        lda     #>(rAXY_restore-1)
        pha
        lda     #<(rAXY_restore-1)
        pha

        ; We now need to manipulate the stack to get it into its final state whereby
        ; the initial rts for this function sets the A/X/Y to their correct state prior
        ; to calling it, and we have the desired values on the stack for subsequent
        ; recall of state after the wrapped function is called.

        ldy     #$05        
rAXY_loop:
        tsx                     ; Get current stack pointer
        lda     $0107,x         ; Read from stack area
        pha                     ; Push to stack (changes SP)
        dey
        bne     rAXY_loop
        
        ; Now shift 10 bytes up the stack to get the shape we require
        ldy     #$0A
rAXY_loop2:
        lda     $0109,x
        sta     $010B,x
        dex
        dey
        bne     rAXY_loop2
        ; last 2 bytes of stack after moving everything up by 2 need removing
        pla
        pla
        ; fall into restore for the initial restoring of A/X/Y for the call to remember_axy

rAXY_restore:
        ; Restore Y, X, A from stack
        pla
        tay
        pla
        tax
        pla

        ; This rts has dual purpose. First time through it returns to the caller of remember_axy
        ; with A/X/Y restored to their values prior to calling it.
        ; Second time when returning to the remembered location, returns to whatever
        ; was on the stack prior to calling remember_axy with A/X/Y again restored.
        rts

return_with_a0:
        ; Overwrites A with 0 in the remember_axy stack values
        pha
        txa
        pha
        lda     #$00
        tsx
        sta     $0109, x        ; Store A=0 in the saved A position
        pla
        tax
        pla
        rts
