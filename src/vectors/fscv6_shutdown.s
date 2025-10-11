; FSCV6 - Shutdown filing system
; Following MMFS fscv6_shutdownfilesys (line 4588+)
        .export fscv6_shutdown_filing_system

        .import close_all_files
        .import close_spool_exec_files
        .import remember_axy

.ifdef FN_DEBUG
        .import print_string
.endif

        .include "fujinet.inc"

        .segment "CODE"

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; fscv6_shutdown_filing_system - Shutdown filing system
; Following MMFS pattern (lines 4588+)
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

fscv6_shutdown_filing_system:
        jsr     remember_axy

.ifdef FN_DEBUG
        jsr     print_string
        .byte   "Shutting down FujiNet FS", $0D
        nop
.endif

        ; Close any SPOOL or EXEC files (following MMFS pattern)
        jsr     close_spool_exec_files
        
        ; Close all open files
        jsr     close_all_files
        
        ; TODO: Save static workspace to private workspace if needed
        ; (MMFS does this for Master systems)
        
        rts
