; *VERIFY and *FORM command implementation
; *VERIFY checks the integrity of each sector of a disc
; *FORM formats a disc (40 or 80 track)

; TODO: need to implement these for fujinet.
; Typically, it is done on the fujinet.

        .export cmd_fs_verify
        .export cmd_fs_form

        .include "fujinet.inc"

        .segment "CODE"

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; cmd_fs_verify - Handle *VERIFY command
; Verifies the integrity of a disk
; Syntax: *VERIFY (<drive>)
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

cmd_fs_verify:

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; cmd_fs_form - Handle *FORM command
; Formats a disk (40 or 80 track)
; Syntax: *FORM <40|80> (<drive>)
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

cmd_fs_form:

        rts
