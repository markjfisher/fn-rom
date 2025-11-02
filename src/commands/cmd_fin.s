; *FIN command implementation
; Find a file on a specific drive
; Syntax: *FIN <drive> <filename>

        .export cmd_fs_fin

        .import param_count_a
        .import param_drive_or_default
        .import find_and_mount_disk

        .include "fujinet.inc"

        .segment "CODE"

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; cmd_fs_fin - Handle *FIN command
; Syntax: *FIN <drive> <filename>
; Finds and displays information about a file on a specific drive
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

cmd_fs_fin:
        ; Translated from MM32 mm32_cmd_din (MM32.asm line 1329-1339)
        ; *DIN (<drive>) <dosname>
        
        ; Check parameter count (1 or 2 allowed)
        lda     #$80                    ; flag7=1, flag0=0: allows 1-2 parameters
        jsr     param_count_a           ; Returns C=0 if 1 param, C=1 if 2
        
        ; Read drive parameter or use default
        jsr     param_drive_or_default  ; Sets current_drv
        
        ; Find and mount disk
        lda     #$00                    ; Looking for a file (not directory)
        jmp     find_and_mount_disk     ; Find disk by name and mount it
