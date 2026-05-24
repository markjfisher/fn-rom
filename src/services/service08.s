; Service call 08 - Unrecognised OSWORD
; MOS saves the OSWORD function in &EF and X/Y in &F0/&F1 before issuing
; service call 8. OSWORD &80+ routes via USERV (&0200), not service 8.
;
; Structure matches MMFS .SERVICE08_unrec_OSWORD (mmfs100.asm ~3488):
;   RememberAXY { checks; ReturnWithA0; jmp handler } RTS
;   handler: jsr work; rts   (handler outside inner block, like .notOSWORD7F)
        .export service08_unrec_osword

        .import fnnet_dispatch
        .import remember_axy
        .import return_with_a0
        .import paged_ram_copy
        .import vectors_table
        .import ACTIVE_ROM_ID
        .import OSFILE_V

        .import osword_call_save:       zeropage
        .import osword_x_save:          zeropage
        .import osword_y_save:          zeropage

        .include "fujinet.inc"

        .segment "CODE"

; https://www.sprow.co.uk/bbc/library/oswords.txt
; I always thought MMFS service 08 was its way of doing disk stuff, and we don't need it in fujinet
; and although I've got this working, it seems from the above that 7E and 7F (which MMFS supports)
; are standard DFS techniques for getting the Disk size (7E), and writing to disk controller (7F)
; so we need to support them too from software expecting them to work.


; OS standard values:
; $70 (ADFS) Read master sequence number and status byte
; $71 (ADFS) Free free space on disk, same as *FREE
; $72 (ADFS) Write to disk controller chip
; $73 (ADFS) Read last ADFS error information
; $7A (Teletext ROM) Depends on entry values
; $7B (COMMAND ROM) Modem Commands!
; $7D (DFS) Read master sequence number
; $7E (DFS) Read disk size
; $7F (DFS) Write to disk controller chip

; FNROM custom values
; $78 (FujiNet) Dispatch on control block sent

; A/X/Y are in osword_call_save, osword_x_save, osword_y_save
; We will return the ones given to us, but set A=0 if we accept the call.
service08_unrec_osword:
        jsr     remember_axy

        ldy     osword_call_save
        bmi     service08_exit_remember
        cpy     #FNNET_OSWORD           ; allow FNNET_OSWORD ($78)
        beq     checks
        cpy     #$7D                    ; allow 7D and 7E
        bcc     service08_exit_remember
        ; fall through for 7E. We've already checked it's not >=$80 with BMI

checks:
        ; MMFS checks $0DBC against $F4 to validate correct ROM, DBC is current paged ROM
        ; not sure how this could ever fail, as we are paged in when it runs, so we must be active
        lda     paged_ram_copy
        cmp     ACTIVE_ROM_ID
        bne     service08_exit_remember

        ; ensure our OSFILE is installed, another extra check MMFS makes to ensure we're active FS
        lda     OSFILE_V
        cmp     vectors_table
        bne     service08_exit_remember
        lda     OSFILE_V+1
        cmp     vectors_table+1
        bne     service08_exit_remember


        ; this MUST be called inside a remember_axy, as it just sets the A value returned to 0
        jsr     return_with_a0          ; claim: A=0 on exit via remember_axy
        ; A is OSFILE_V+1, which is non-zero
        bne     fnnet_service08_handler
        brk                             ; TESTING ONLY

service08_exit_remember:
        rts                             ; MMFS line 3528: unwind remember_axy

fnnet_service08_handler:
        ldx     osword_x_save           ; parameter block pointer low
        ldy     osword_y_save           ; parameter block pointer high
        jmp     fnnet_dispatch
