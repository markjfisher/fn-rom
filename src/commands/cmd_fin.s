; *FIN command implementation
; Find a file on a specific drive
; Syntax: *FIN <drive> <filename>

        .export cmd_fs_fin

        .import param_drive_and_disk
        .import load_drive

        .include "fujinet.inc"

        .segment "CODE"

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; cmd_fs_fin - Handle *FIN command
; Syntax: *FIN <drive> <filename>
; Finds and displays information about a file on a specific drive
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

cmd_fs_fin:
        jsr     param_drive_and_disk
        jmp     load_drive
