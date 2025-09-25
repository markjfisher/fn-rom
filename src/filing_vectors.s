; Filing system vector entry points
; These handle OS calls like *CAT, *LOAD, *SAVE, etc.

        .export filev_entry
        .export argsv_entry
        .export bgetv_entry
        .export bputv_entry
        .export gbpbv_entry  
        .export findv_entry
        .export fscv_entry

        .import remember_axy
        .import print_string
        .import print_axy

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
        cmp     #$0C
        bcs     @unknown_op
        
.ifdef FN_DEBUG
        jsr     remember_axy
        jsr     print_string
        .byte   "FSCV "
        nop
        jsr     print_axy
.endif

        ; For now, just return without doing anything
        ; This prevents crashes but doesn't implement functionality
        rts

@unknown_op:
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
        .byte   <(fscv_placeholder - 1)    ; 3: Unrecognized command
        .byte   <(fscv_placeholder - 1)    ; 4: *RUN
        .byte   <(fscv_placeholder - 1)    ; 5: *CAT
        .byte   <(fscv_placeholder - 1)    ; 6: Shutdown filing system
        .byte   <(fscv_placeholder - 1)    ; 7: Handle range
        .byte   <(fscv_placeholder - 1)    ; 8: OS about to process command
        .byte   <(fscv_placeholder - 1)    ; 9: *EX
        .byte   <(fscv_placeholder - 1)    ; 10: *INFO
        .byte   <(fscv_placeholder - 1)    ; 11: *RUN

fscv_table2:
        ; High bytes of function addresses
        .byte   >(fscv_placeholder - 1)    ; 0: *OPT
        .byte   >(fscv_placeholder - 1)    ; 1: EOF Y handler
        .byte   >(fscv_placeholder - 1)    ; 2: *RUN
        .byte   >(fscv_placeholder - 1)    ; 3: Unrecognized command
        .byte   >(fscv_placeholder - 1)    ; 4: *RUN
        .byte   >(fscv_placeholder - 1)    ; 5: *CAT
        .byte   >(fscv_placeholder - 1)    ; 6: Shutdown filing system
        .byte   >(fscv_placeholder - 1)    ; 7: Handle range
        .byte   >(fscv_placeholder - 1)    ; 8: OS about to process command
        .byte   >(fscv_placeholder - 1)    ; 9: *EX
        .byte   >(fscv_placeholder - 1)    ; 10: *INFO
        .byte   >(fscv_placeholder - 1)    ; 11: *RUN

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

