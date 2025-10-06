; FILEV_ENTRY - File Vector
; Handles OSFILE calls for file operations like *LOAD, *SAVE, *DELETE, etc.
; Translated from MMFS mmfs100.asm lines 3670-3701

        .export filev_entry

        .import a_rorx6and3
        .import get_cat_entry_fspba
        .import parameter_fsp
        .import prt_info_msg_yoffset
        .import read_file_attribs_to_b0_yoffset
        .import remember_axy

        .include "fujinet.inc"

        .segment "CODE"

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; FILEV_ENTRY - File Vector
; Handles OSFILE calls
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

filev_entry:
.ifdef FN_DEBUG
        jsr     print_string
        .byte   "FILEV "
        nop
        jsr     print_axy
.endif
        ; rts

        jsr     remember_axy
        pha
        jsr     parameter_fsp

        stx     aws_tmp00              ; XY -> parameter block
        stx     fuji_param_block_lo    ; Store for later use
        sty     aws_tmp01
        sty     fuji_param_block_hi

        ; Copy parameters from OSFILE call into internal format
        ldx     #$00                   ; BA->filename
        ldy     #$00                   ; BC & 1074=load addr (32 bit)
        jsr     copy_word_b0ba         ; BE & 1076=exec addr
@filev_copyparams_loop:
        jsr     copy_vars_b0ba         ; C0 & 1078=start addr
        cpy     #$12                   ; C2 & 107A=end addr
        bne     @filev_copyparams_loop ; (lo word in zp, hi in page 10)

        pla
        tax
        inx
        cpx     #$08                   ; NB A=FF -> X=0
        bcs     @filev_unknownop       ; IF x>=8 (a>=7)
        lda     finv_table_hi,x        ; get addr from table
        pha                            ; and "return" to it
        lda     finv_table_lo,x
        pha

@filev_unknownop:
        lda     #$00
        rts

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; OSFILE operation tables
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

.feature line_continuations +

        ; 0: Load file to address (A=&FF)
        ; 1: Save memory block (A=0)
        ; 2: Save file (A=1)
        ; 3: Delete file (A=2)
        ; 4: Create file (A=3)
        ; 5: Write load address (A=4)
        ; 6: Write exec address (A=5)
        ; 7: Write file attributes (A=6)

.define FINV_TABLE \
        osfileFF_loadfiletoaddr         - 1, \
        osfile0_savememblock            - 1, \
        osfile1_savefile                - 1, \
        osfile2_deletefile              - 1, \
        osfile3_createfile              - 1, \
        osfile4_writeloadaddr           - 1, \
        osfile5_writeexecaddr           - 1, \
        osfile6_writefileattr           - 1

finv_table_lo: .lobytes FINV_TABLE
finv_table_hi: .hibytes FINV_TABLE

.feature line_continuations -

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; OSFILE operation handlers
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; osfileFF_loadfiletoaddr
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

; Load file to address (A=&FF)
; Translated from MMFS lines 1956-1993
osfileFF_loadfiletoaddr:
        jsr     get_cat_entry_fspba        ; Get Load Addr etc.
        jsr     set_param_block_pointer_b0  ; from catalogue
        jsr     read_file_attribs_to_b0_yoffset  ; (Just for info?)
        ; Fall into LoadFile_Ycatoffset

; LoadFile_Ycatoffset - Load file at catalog offset Y
LoadFile_Ycatoffset:
        sty     aws_tmp10                ; STY &BA
        ldx     #$00
        lda     aws_tmp11                ; If ?BE=0 don't do Load Addr
        bne     @load_at_load_addr

        ; use load address in control block
        iny
        iny
        ldx     #$02
        bne     @load_copyfileinfo_loop  ; always

        ; use file's load address
@load_at_load_addr:
        lda     $0F0E,y                  ; mixed byte
        sta     aws_tmp12                ; STA &C2
        jsr     load_addr_hi2

@load_copyfileinfo_loop:
        lda     $0F08,y
        sta     aws_tmp13,x              ; STA &BC,X
        iny
        inx
        cpx     #$08
        bne     @load_copyfileinfo_loop

        jsr     exec_addr_hi2

        ldy     aws_tmp10                ; LDY &BA
        jsr     prt_info_msg_yoffset     ; pt. print file info
        ; Fall into LoadMemBlockEX

; LoadMemBlockEX - Load memory block
; Since _MM32_ is true and _SWRAM_ is false, lines 1997-2005 are skipped
LoadMemBlockEX:
        ; Fall into LoadMemBlock

; LoadMemBlock - Load memory block
; Since _MM32_ is true, use exec_block_rw with A=&85
LoadMemBlock:
        lda     #$85
        bne     exec_block_rw

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; osfile0_savememblock
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

; Save memory block (A=0)
; Translated from MMFS lines 2028-2045
osfile0_savememblock:
        jsr     create_file_fsp
        jsr     set_param_block_pointer_b0
        jsr     read_file_attribs_to_b0_yoffset
        ; fall into SaveMemBlock

; SaveMemBlock - Save block of memory
; Since _MM32_ is true, use exec_block_rw with A=&A5
SaveMemBlock:
        lda     #$A5
        ; fall into exec_block_rw

; exec_block_rw - Block read/write
; Translated from MMFS lines 2048-2110
; On entry A=FDC command
exec_block_rw:
        ; Populate OSWORD control block
        sta     OWCtlBlock+6             ; FDC Command
        lda     #5
        sta     OWCtlBlock+5             ; Param count
        lda     CurrentDrv
        sta     OWCtlBlock               ; Drive

        ; Buffer address
        ldx     #2
@loop0:
        lda     aws_tmp12-1,x            ; &BC-1,X
        sta     OWCtlBlock,x
        lda     $1074-1,x                ; MA+&1074-1,X
        sta     OWCtlBlock+2,x
        dex
        bne     @loop0

        ; Convert sector address to track & sector
        lda     pws_tmp02                ; &C2
        and     #3
        tax
        lda     pws_tmp03                ; &C3 - X:A = sector address
        ldy     #$FF                     ; Y = track

@loop1:
        sec

@loop2:
        iny
        sbc     #10
        bcs     @loop2

        dex
        bpl     @loop1

        ; C=0
        adc     #10                      ; A = sector
        sty     OWCtlBlock+7
        sta     OWCtlBlock+8

        ; Block size (bytes)
        lda     pws_tmp01                ; &C1
        sta     OWCtlBlock+9
        lda     pws_tmp02                ; mixed byte
        lsr     a
        lsr     a
        lsr     a
        lsr     a
        and     #3
        sta     OWCtlBlock+10
        lda     pws_tmp00                ; &C0
        sta     OWCtlBlock+11

        jsr     ow7f_execute_and_report_if_disk_fault

        lda     #1
        rts

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; osfile1_savefile
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; Save file (A=1)
osfile1_savefile:
        ; TODO: Implement file saving
        rts

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; osfile2_deletefile
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; Delete file (A=2)
osfile2_deletefile:
        ; TODO: Implement file deletion
        rts

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; osfile3_createfile
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; Create file (A=3)
osfile3_createfile:
        ; TODO: Implement file creation
        rts

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; osfile4_writeloadaddr
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; Write load address (A=4)
osfile4_writeloadaddr:
        ; TODO: Implement load address writing
        rts

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; osfile5_writeexecaddr
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; Write exec address (A=5)
osfile5_writeexecaddr:
        ; TODO: Implement exec address writing
        rts

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; osfile6_writefileattr
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; Write file attributes (A=6)
osfile6_writefileattr:
        ; TODO: Implement file attribute writing
        rts

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; Helper functions
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

; Copy variables from B0 to BA
copy_vars_b0ba:
        jsr     copy_word_b0ba
        dex
        dex
        jsr     @copy_byte
@copy_byte:
        lda     (aws_tmp00),y
        sta     $1072,x                 ; TODO: what is this?
        inx
        iny
        rts

; Copy word from B0 to BA
copy_word_b0ba:
        jsr     @copy_byte
@copy_byte:
        lda     (aws_tmp00),y
        sta     aws_tmp10,x
        inx
        iny
        rts

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; Helper functions for OSFILE operations
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

; set_param_block_pointer_b0 - Set parameter block pointer
set_param_block_pointer_b0:
        lda     fuji_param_block_lo
        sta     aws_tmp00
        lda     fuji_param_block_hi
        sta     aws_tmp01
        rts

; load_addr_hi2 - Load address high bits
load_addr_hi2:
        lda     #$00
        sta     $1075                    ; MA+&1075
        lda     pws_tmp02                ; &C2
        and     #$08
        sta     $1074                    ; MA+&1074
        beq     ldadd_nothost
set_load_addr_to_host:
        lda     #$FF
        sta     $1075                    ; MA+&1075
        sta     $1074                    ; MA+&1074
ldadd_nothost:
        rts

load_and_exec_addr_hi2:
        jsr     load_addr_hi2

; exec_addr_hi2 - Execution address high bits
; Translated from MMFS lines 2642-2655
exec_addr_hi2:
        lda     #$00
        sta     $1077                    ; MA+&1077
        lda     pws_tmp02                ; &C2
        jsr     a_rorx6and3              ; Shift right 6 bits and mask with 3
        cmp     #$03
        bne     @exadd_nothost
        lda     #$FF
        sta     $1077                    ; MA+&1077
@exadd_nothost:
        sta     $1076                    ; MA+&1076
        rts


; create_file_fsp - Create file from FSP
create_file_fsp:
        ; TODO: Implement file creation
        rts

; ow7f_execute_and_report_if_disk_fault - Execute OSWORD 7F and report disk faults
ow7f_execute_and_report_if_disk_fault:
        ; TODO: Implement OSWORD 7F execution
        rts
