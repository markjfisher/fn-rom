; Filing system vector entry points
; These handle OS calls like *CAT, *LOAD, *SAVE, etc.

        .export gbpbv_entry
        .export fscv_entry

        .export upgbpb

        .export extendedvectors_table
        .export parameter_afsp
        .export parameter_fsp
        .export vectors_table

        .export gbpbv_table_lo
        .export gbpbv_table_hi
        .export gbpbv_table3

        .export fscv_os_about_to_proc_cmd

        .import remember_axy
        .import return_with_a0

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
        .import fscv6_shutdown_filing_system
        .import fscv7_hndlrange
        .import fscv9_star_ex
        .import fscv10_starINFO

        .import gbpb_gosub
        .import gbpb_put_bytes
        .import gbpb_getbyte_savebyte
        .import gbpb5_get_mediatitle
        .import gbpb6_rd_cur_dir_device
        .import gbpb7_rd_cur_lib_device
        .import gbpb8_rd_file_cur_dir

        .import fastgb

        .import tube_release_no_check

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

        cmp     #$0C                    ; we handle commands $00 to $0B, or 0-11
        bcs     unknown_op
        stx     aws_tmp05               ; Save X

        tax                             ; the fscv command (index into table)
        lda     fscv_table_hi,x         ; High byte first
        pha
        lda     fscv_table_lo,x         ; Low byte second
        pha
        txa
        ldx     aws_tmp05             ; Restore X

        ; we love a good rts jump, this is also used as a generic rts in table
just_rts:
        rts

unknown_op:
        dbg_string_axy "FSCV_UNKNOWN_OP: "
        rts


;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; GBPBV_ENTRY - General Purpose Block Transfer Vector
; Handles OSGBPB calls for file operations
; See 16.1.5 of New Advanced User Guide
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

gbpbv_entry:
        cmp     #$09
        bcs     gbpbv_unknown

        jsr     remember_axy
        jsr     return_with_a0

        stx     fuji_gbpbv_blk_save_ptr
        sty     fuji_gbpbv_blk_save_ptr+1

        dbg_string_axy "GBPBV: "

        tay
        jmp     fastgb

upgbpb:
        jsr     gbpb_gosub
        php
        bit     gbpb_tube
        bpl     @gbpb_nottube
        jsr     tube_release_no_check
@gbpb_nottube:
        plp

gbpbv_unknown:
        rts

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; FSCV TABLES - Maps FSCV operation numbers to function addresses
; See New Advanced User Guide: "16.1.7 Filing system control vector, FSCV"
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
        ; 12: *RENAME   - NOT SUPPORTED

.define FSCV_TABLE \
        fscv0_starOPT                - 1, \
        fscv1_eof_yhndl              - 1, \
        fscv2_4_11_starRUN           - 1, \
        fscv3_unreccommand           - 1, \
        fscv2_4_11_starRUN           - 1, \
        fscv5_starCAT                - 1, \
        fscv6_shutdown_filing_system - 1, \
        fscv7_hndlrange              - 1, \
        fscv_os_about_to_proc_cmd    - 1, \
        fscv9_star_ex                - 1, \
        fscv10_starINFO              - 1, \
        fscv2_4_11_starRUN           - 1

fscv_table_lo: .lobytes FSCV_TABLE
fscv_table_hi: .hibytes FSCV_TABLE

        ; 1: write bytes to file at sequential file pointer specified
        ; 2: append bytes to file at current file pointer
        ; 3: read bytes from specified position in file
        ; 4: read bytes from current position in file
        ; 5: read title, option and drive into memory
        ; 6: read current directory and drive names
        ; 7: read current library and drive names
        ; 8: read file names from the current directory

; this is not used as an rts jump table, so doesn't need the -1
.define GBPBV_TABLE              \
        just_rts,                \
        gbpb_put_bytes,          \
        gbpb_put_bytes,          \
        gbpb_getbyte_savebyte,   \
        gbpb_getbyte_savebyte,   \
        gbpb5_get_mediatitle,    \
        gbpb6_rd_cur_dir_device, \
        gbpb7_rd_cur_lib_device, \
        gbpb8_rd_file_cur_dir   

gbpbv_table_lo: .lobytes GBPBV_TABLE
gbpbv_table_hi: .hibytes GBPBV_TABLE

; this is used in fastgp as microcode bytes.
; bit 0:  1 == preserving PTR
; bit 1:  1 == transfer data
; bit 2:  1 == tube operation (TODO)
gbpbv_table3:
        .byte $04, $02, $03, $06, $07, $04, $04, $04, $04

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
