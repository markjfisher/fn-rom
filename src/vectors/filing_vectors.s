; Filing system vector entry points
; These handle OS calls like *CAT, *LOAD, *SAVE, etc.

        .export gbpbv_entry
        .export fscv_entry

        .export close_all_files
        .export close_files_yhandle
        .export extendedvectors_table
        .export parameter_afsp
        .export parameter_fsp
        .export vectors_table

        .export fscv_os_about_to_proc_cmd
        .export fscv_entry_jumping_to_function

        .import argsv_entry
        .import bgetv_entry
        .import bputv_entry
        .import filev_entry
        .import findv_entry
        .import fscv0_starOPT
        .import fscv1_eof_yhndl
        .import fscv2_4_11_starRUN
        .import fscv3_unreccommand
        .import fscv5_starCAT
        .import fscv10_starINFO
        .import print_axy
        .import print_string

        .include "fujinet.inc"

        .segment "CODE"

; Vector implementations moved to individual files in vectors/ subfolder

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; FSCV_ENTRY - Filing System Control Vector
; Handles filing system commands like *CAT, *LOAD, *SAVE, etc.
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

fscv_entry:
        dbg_string_axy "FSCV_ENTRY: "

        cmp     #$0C
        bcs     unknown_op
        stx     aws_tmp05              ; Save X
        dbg_string_axy "FSCV: "
        tax
        lda     fscv_table_hi,x         ; High byte first
        pha
        lda     fscv_table_lo,x         ; Low byte second
        pha
        txa
        ldx     aws_tmp05             ; Restore X

fscv_entry_jumping_to_function:
        rts

unknown_op:
        dbg_string_axy "FSCV_UNKNOWN_OP: "
        rts

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; GBPBV_ENTRY - General Purpose Block Transfer Vector
; Handles OSGBPB calls for file operations
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

gbpbv_entry:
        cmp     #$09
        bcs     @unknown_op
        
        dbg_string_axy "GBPBV: "

        ; Look up function in FSCV table
        tax
        lda     fscv_table_lo,x
        pha
        lda     fscv_table_hi,x
        pha
        txa
        rts

@unknown_op:
        rts

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; FSCV TABLES - Maps FSCV operation numbers to function addresses
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

.feature line_continuations +

        ; 0: *OPT
        ; 1: EOF Y handler
        ; 2: *RUN
        ; 3: Unrecognized command
        ; 4: *RUN
        ; 5: *CAT
        ; 6: Shutdown filing system (new filing system start)
        ; 7: Handle range
        ; 8: OS about to process command
        ; 9: *EX
        ; 10: *INFO
        ; 11: *RUN
        ; 12: *RENAME

; See New_Advanced_User_Guide.pdf 16.1.7: Filing System Control Vector

.define FSCV_TABLE \
        fscv0_starOPT             - 1, \
        fscv1_eof_yhndl           - 1, \
        fscv2_4_11_starRUN        - 1, \
        fscv3_unreccommand        - 1, \
        fscv2_4_11_starRUN        - 1, \
        fscv5_starCAT             - 1, \
        fscv_placeholder          - 1, \
        fscv_placeholder          - 1, \
        fscv_os_about_to_proc_cmd - 1, \
        fscv_placeholder          - 1, \
        fscv10_starINFO           - 1, \
        fscv2_4_11_starRUN        - 1

fscv_table_lo: .lobytes FSCV_TABLE
fscv_table_hi: .hibytes FSCV_TABLE

.feature line_continuations -

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; fscv_os_about_to_proc_cmd - OS about to process command
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

fscv_os_about_to_proc_cmd:
        dbg_string_axy "FSCV8_OS_CMD: "

        ; Set fuji_cmd_enabled flag
        bit     fuji_cmd_enabled
        bmi     parameter_fsp
        dec     fuji_cmd_enabled
parameter_fsp:
        lda     #$FF
        sta     fuji_wild_star
param_out:
        sta     fuji_wild_hash
        rts

; parameter_afsp - Set up wildcard characters (MMFS line 4290-4294)
parameter_afsp:
        lda     #'*'
        sta     fuji_wild_star
        lda     #'#'
        bne     param_out

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; FSCV_PLACEHOLDER - Placeholder for all FSCV operations
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

fscv_placeholder:
        dbg_string_axy "FSCV_PLACEHOLDER: "
        rts

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; FILE OPERATIONS
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

; Close all open files
close_all_files:
        ; TODO: Implement close all files
        ; This should iterate through all open file handles and close them
        rts

; Close files by handle
; Y = file handle to close
close_files_yhandle:
        ; TODO: Implement close files by handle
        ; This should close the specific file handle in Y
        rts

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; VECTOR TABLES
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

vectors_table:
        ; Filing system vectors (14 bytes) - OS vector addresses
        .word   $FF1B                 ; FILEV
        .word   $FF1E                 ; ARGSV  
        .word   $FF21                 ; BGETV
        .word   $FF24                 ; BPUTV
        .word   $FF27                 ; GBPBV
        .word   $FF2A                 ; FINDV
        .word   $FF2D                 ; FSCV

extendedvectors_table:
        ; Extended vectors (21 bytes = 7 entries * 3 bytes each)
        ; Each entry: 2 bytes vector, 1 byte BRK
        .word   filev_entry           ; FILEV extended
        .byte   $00                   ; BRK
        
        .word   argsv_entry           ; ARGSV extended  
        .byte   $00                   ; BRK
        
        .word   bgetv_entry           ; BGETV extended
        .byte   $00                   ; BRK
        
        .word   bputv_entry           ; BPUTV extended
        .byte   $00                   ; BRK
        
        .word   gbpbv_entry           ; GBPBV extended
        .byte   $00                   ; BRK
        
        .word   findv_entry           ; FINDV extended
        .byte   $00                   ; BRK
        
        .word   fscv_entry            ; FSCV extended
        .byte   $00                   ; BRK
