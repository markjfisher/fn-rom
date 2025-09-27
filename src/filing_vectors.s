; Filing system vector entry points
; These handle OS calls like *CAT, *LOAD, *SAVE, etc.

        .export filev_entry
        .export argsv_entry
        .export bgetv_entry
        .export bputv_entry
        .export gbpbv_entry
        .export findv_entry
        .export fscv_entry
        .export close_all_files
        .export close_files_yhandle
        .export vectors_table
        .export extendedvectors_table

        .export fscv_os_about_to_proc_cmd
        .export fscv5_starCAT
        .export fscv_entry_jumping_to_function

        .import remember_axy
        .import print_string
        .import print_axy
        .import fuji_read_catalog
        .import print_char
        .import print_hex
        .import print_newline
        .import fscv10_starINFO
        .import unrec_command_text_pointer
        .import fscv3_unreccommand

        .include "fujinet.inc"

        .segment "CODE"

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; FILEV_ENTRY - File Vector
; Handles OSFILE calls
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

filev_entry:
.ifdef FN_DEBUG
        jsr     remember_axy
        jsr     print_string
        .byte   "FILEV "
        nop
        jsr     print_axy
.endif
        rts

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; ARGSV_ENTRY - Arguments Vector
; Handles OSARGS calls
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

argsv_entry:
.ifdef FN_DEBUG
        jsr     remember_axy
        jsr     print_string
        .byte   "ARGSV "
        nop
        jsr     print_axy
.endif
        rts

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; BGETV_ENTRY - Byte Get Vector
; Handles BGET calls
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

bgetv_entry:
.ifdef FN_DEBUG
        jsr     remember_axy
        jsr     print_string
        .byte   "BGETV "
        nop
        jsr     print_axy
.endif
        rts

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; BPUTV_ENTRY - Byte Put Vector
; Handles BPUT calls
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

bputv_entry:
.ifdef FN_DEBUG
        jsr     remember_axy
        jsr     print_string
        .byte   "BPUTV "
        nop
        jsr     print_axy
.endif
        rts

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; FSCV_ENTRY - Filing System Control Vector
; Handles filing system commands like *CAT, *LOAD, *SAVE, etc.
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

fscv_entry:
.ifdef FN_DEBUG
        jsr     remember_axy
        jsr     print_string
        .byte   "FSCV_ENTRY_CALLED "
        nop
        jsr     print_axy
.endif

        cmp     #$0C
        bcs     unknown_op
        stx     aws_tmp05              ; Save X
.ifdef FN_DEBUG
        jsr     print_string
        .byte   "FSCV "
        nop
        jsr     print_axy
.endif
        tax
        lda     fscv_table2,x         ; High byte first
        pha
        lda     fscv_table1,x         ; Low byte second
        pha
        txa
        ldx     aws_tmp05             ; Restore X

fscv_entry_jumping_to_function:
        rts

unknown_op:
.ifdef FN_DEBUG
        jsr     remember_axy
        jsr     print_string
        .byte   "FSCV_UNKNOWN_OP "
        nop
        jsr     print_axy
.endif
        rts

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; GBPBV_ENTRY - General Purpose Block Transfer Vector
; Handles OSGBPB calls for file operations
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

gbpbv_entry:
        cmp     #$09
        bcs     @unknown_op
        
.ifdef FN_DEBUG
        jsr     remember_axy
        jsr     print_string
        .byte   "GBPBV "
        nop
        jsr     print_axy
.endif

        ; Look up function in FSCV table
        tax
        lda     fscv_table1,x
        pha
        lda     fscv_table2,x
        pha
        txa
        rts

@unknown_op:
        rts

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; FINDV_ENTRY - File Find Vector  
; Handles OSFIND calls for opening/closing files
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

findv_entry:
.ifdef FN_DEBUG
        jsr     remember_axy
        jsr     print_string
        .byte   "FINDV "
        nop
        jsr     print_axy
.endif

        ; For now, just return without doing anything
        rts

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; FSCV TABLES - Maps FSCV operation numbers to function addresses
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

fscv_table1:
        ; Low bytes of function addresses
        .byte   <(fscv_placeholder - 1)    ; 0: *OPT
        .byte   <(fscv_placeholder - 1)    ; 1: EOF Y handler
        .byte   <(fscv_placeholder - 1)    ; 2: *RUN
        .byte   <(fscv3_unreccommand - 1)  ; 3: Unrecognized command
        .byte   <(fscv_placeholder - 1)    ; 4: *RUN
        .byte   <(fscv5_starCAT - 1)       ; 5: *CAT
        .byte   <(fscv_placeholder - 1)    ; 6: Shutdown filing system
        .byte   <(fscv_placeholder - 1)    ; 7: Handle range
        .byte   <(fscv_os_about_to_proc_cmd - 1)    ; 8: OS about to process command
        .byte   <(fscv_placeholder - 1)    ; 9: *EX
        .byte   <(fscv10_starINFO - 1)     ; 10: *INFO
        .byte   <(fscv_placeholder - 1)    ; 11: *RUN

fscv_table2:
        ; High bytes of function addresses
        .byte   >(fscv_placeholder - 1)    ; 0: *OPT
        .byte   >(fscv_placeholder - 1)    ; 1: EOF Y handler
        .byte   >(fscv_placeholder - 1)    ; 2: *RUN
        .byte   >(fscv3_unreccommand - 1)  ; 3: Unrecognized command
        .byte   >(fscv_placeholder - 1)    ; 4: *RUN
        .byte   >(fscv5_starCAT - 1)       ; 5: *CAT
        .byte   >(fscv_placeholder - 1)    ; 6: Shutdown filing system
        .byte   >(fscv_placeholder - 1)    ; 7: Handle range
        .byte   >(fscv_os_about_to_proc_cmd - 1)    ; 8: OS about to process command
        .byte   >(fscv_placeholder - 1)    ; 9: *EX
        .byte   >(fscv10_starINFO - 1)     ; 10: *INFO
        .byte   >(fscv_placeholder - 1)    ; 11: *RUN

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; FSCV5_STARCAT - Handle *CAT command
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

fscv5_starCAT:
.ifdef FN_DEBUG
        jsr     remember_axy
        jsr     print_string
        .byte   "FSCV5_STARCAT called", $0D
        nop
        jsr     print_axy
.endif
        
        ; Load catalog from our dummy interface
        jsr     fuji_read_catalog
        
        ; Print catalog (following MMFS pattern)
        jsr     print_catalog_mmfs_style
        
        rts

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; fscv_os_about_to_proc_cmd - OS about to process command
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

fscv_os_about_to_proc_cmd:
.ifdef FN_DEBUG
        jsr     print_string
        .byte   "FSCV8_OSABOUTTOPROCCMD called", $0D
        nop
.endif
        ; Set CMDEnabledIf1 flag
        bit     CMDEnabledIf1
        bmi     @parameter_fsp
        dec     CMDEnabledIf1
@parameter_fsp:
        lda     #$FF
        sta     $10CE
@param_out:
        sta     $10CD
        rts

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; FSCV_PLACEHOLDER - Placeholder for all FSCV operations
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

fscv_placeholder:
.ifdef FN_DEBUG
        jsr     remember_axy
        jsr     print_string
        .byte   "FSCV_PLACEHOLDER "
        nop
        jsr     print_axy
.endif
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

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; PRINT_CATALOG_MMFS_STYLE - Print catalog following MMFS pattern
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

print_catalog_mmfs_style:
        ; Print disk title (first 8 bytes)
        ldy     #$00
@title_loop:
        lda     $0E00,y
        jsr     print_char
        iny
        cpy     #$08
        bne     @title_loop
        
        ; Print cycle number in parentheses
        jsr     print_string
        .byte   " (", $80
        nop
        lda     $0F04
        jsr     print_hex
        jsr     print_string
        .byte   ")", $80
        nop
        jsr     print_newline
        
        ; Print "Drive X"
        jsr     print_string
        .byte   "Drive ", $80
        nop
        lda     CurrentDrv
        jsr     print_hex
        
        ; Print 13 spaces
        ldy     #$0D
@spaces_loop:
        lda     #' '
        jsr     print_char
        dey
        bne     @spaces_loop
        
        ; Print "Option X (LOAD)"
        jsr     print_string
        .byte   "Option ", $80
        nop
        lda     $0F06
        jsr     print_hex
        jsr     print_string
        .byte   " (LOAD)", $80
        nop
        jsr     print_newline
        
        ; Print "Dir. :X.$"
        jsr     print_string
        .byte   "Dir. :", $80
        nop
        lda     DEFAULT_DRIVE
        jsr     print_hex
        lda     #'.'
        jsr     print_char
        lda     DEFAULT_DIR
        jsr     print_char
        
        ; Print 11 spaces
        ldy     #$0B
@spaces_loop2:
        lda     #' '
        jsr     print_char
        dey
        bne     @spaces_loop2
        
        ; Print "Lib. :X.$"
        jsr     print_string
        .byte   "Lib. :", $80
        nop
        lda     LIB_DRIVE
        jsr     print_hex
        lda     #'.'
        jsr     print_char
        lda     LIB_DIR
        jsr     print_char
        jsr     print_newline
        
        ; Print file list
        ldy     #$00
@file_loop:
        cpy     FilesX8
        bcs     @done
        
        ; Check if file is marked (bit 7 set)
        lda     $0E08,y
        bmi     @next_file
        
        ; Print filename
        jsr     print_filename_at_y
        
        ; Mark file as printed
        lda     $0E08,y
        ora     #$80
        sta     $0E08,y
        
@next_file:
        ; Move to next file (8 bytes per entry)
        tya
        clc
        adc     #$08
        tay
        jmp     @file_loop
        
@done:
        jsr     print_newline
        rts

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; PRINT_FILENAME_AT_Y - Print filename at catalog offset Y
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

print_filename_at_y:
        ; Print 2 spaces
        lda     #' '
        jsr     print_char
        lda     #' '
        jsr     print_char
        
        ; Print filename (7 bytes)
        ldx     #$00
@name_loop:
        lda     $0E08,y
        jsr     print_char
        iny
        inx
        cpx     #$07
        bne     @name_loop
        
        ; Print directory character
        lda     $0E08,y
        jsr     print_char
        
        ; Restore Y to start of file entry
        tya
        sec
        sbc     #$07
        tay
        
        rts

