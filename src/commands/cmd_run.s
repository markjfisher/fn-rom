; *RUN command implementation
; Based on MMFS fscv2_4_11_starRUN (line 2114)

        .export fscv2_4_11_starRUN

        .import LoadFile_Ycatoffset
        .import get_cat_firstentry81
        .import read_fspBA_reset
        .import read_fspBA
        .import a_rorx6and3
        .import err_bad
        .import print_string
        .import print_axy
        .import print_hex
        .import print_newline
        .import set_text_pointer_yx
        .import dump_memory_block

        .include "fujinet.inc"

        .segment "CODE"

; fscv2_4_11_starRUN - Handle *RUN command (MMFS line 2114-2208)
fscv2_4_11_starRUN:
        dbg_string_axy "FSCV2_4_11_STARRUN: "

        ; Set up text pointer (MMFS line 2115)
        jsr     set_text_pointer_yx

        ; Set up text pointer and workspace
        lda     #$FF
        sta     aws_tmp14              ; &BE -> aws_tmp14
        lda     TextPointer
        sta     aws_tmp10              ; &BA -> aws_tmp10  
        lda     TextPointer+1
        sta     aws_tmp11              ; &BB -> aws_tmp11

        ; Look in default drive/dir first
        ldy     #$00
        sty     fuji_text_ptr_hi       ; MA+&10DA (Y=0)
        jsr     read_fspBA_reset       ; Look in default drive/dir
        sty     fuji_text_ptr_offset   ; MA+&10D9 (Y=text ptr offset)
.ifdef FN_DEBUG
        jsr     print_string
        .byte   "RUN: Searching def. dir", $0D
        nop
.endif
        jsr     get_cat_firstentry81   ; Use correct function
        bcs     runfile_found          ; If file found

        ; File not found in default location, try library
        ldy     fuji_text_ptr_hi       ; MA+&10DA
        lda     fuji_lib_dir           ; LIB_DIR -> DirectoryParam
        sta     DirectoryParam
        lda     fuji_lib_drive         ; LIB_DRIVE -> CurrentDrv
        sta     CurrentDrv
.ifdef FN_DEBUG
        jsr     print_string
        .byte   "RUN: Searching lib. dir", $0D
        nop
.endif
        jsr     read_fspBA
        jsr     get_cat_firstentry81   ; Use correct function
        bcs     runfile_found          ; If file found

        ; File not found anywhere
err_bad_command:
        jsr     err_bad
        .byte   $FE
        .byte   "command", 0

runfile_found:
.ifdef FN_DEBUG
        jsr     print_string
        .byte   "File found! Loading...", $0D
        nop
.endif
        ; Check if this is an *EXEC file (exec address = &FFFFFFFF)
        lda     $0F0E,y                ; Mixed byte from catalog
        jsr     a_rorx6and3            ; Extract high bits
        cmp     #$03                   ; If high bits = 3
        bne     runfile_run            ; If not &FFFFFFFF, run normally
        
        ; Check if exec address is &FFFFFFFF
        lda     $0F0A,y                ; Exec address low byte
        and     $0F0B,y                ; Exec address high byte
        cmp     #$FF
        bne     runfile_run            ; If not &FFFFFFFF, run normally

        ; This is an *EXEC file - convert to *EXEC command
        ldx     #$06
@runfile_exec_loop:
        lda     fuji_filename_buffer,x ; Move filename
        sta     fuji_filename_buffer+7,x
        dex
        bpl     @runfile_exec_loop
        
        ; Build *EXEC command: "E.:X.D.FILENAME" (following MMFS pattern)
        lda     #$0D
        sta     fuji_filename_buffer+14
        lda     #'E'
        sta     fuji_filename_buffer
        lda     #':'
        sta     fuji_filename_buffer+2
        lda     CurrentDrv
        ora     #$30
        sta     fuji_filename_buffer+3 ; Drive number X
        lda     #'.'
        sta     fuji_filename_buffer+1
        sta     fuji_filename_buffer+4
        sta     fuji_filename_buffer+6
        lda     DirectoryParam         ; Directory D
        sta     fuji_filename_buffer+5
        
        ; Execute the *EXEC command
        ldx     #$00
        ldy     #$10                   ; MP+&10
        jmp     OSCLI                  ; Execute "E.:X.D.FILENAME"

runfile_run:
        dbg_string_axy "Loading file: "
        
.ifdef FN_DEBUG
        pha
        ; Debug: Check what's in the catalog entry before loading
        jsr     print_string
        .byte   "Catalog entry exec addr: "
        nop
        lda     $0F0B,y                ; High byte of exec address from catalog
        jsr     print_hex
        lda     $0F0A,y                ; Low byte of exec address from catalog
        jsr     print_hex
        jsr     print_newline
        
        ; Debug: Check what's in aws_tmp14/15 before loading
        jsr     print_string
        .byte   "aws_tmp14/15 before load: "
        nop
        lda     aws_tmp15
        jsr     print_hex
        lda     aws_tmp14
        jsr     print_hex
        jsr     print_newline
        pla
.endif
        
        ; Load the file normally
        jsr     LoadFile_Ycatoffset    ; Load file
        
        ; Store execution address from catalog entry for final jump
        ; TODO: work out why this is needed, as it differs from MMFS where the values are already good
        lda     $0F0A,y                ; Exec address low byte from catalog
        sta     aws_tmp14              ; Store in workspace (&BE)
        lda     $0F0B,y                ; Exec address high byte from catalog
        sta     aws_tmp15              ; Store in workspace (&BF)
        
.ifdef FN_DEBUG
        ; Debug: Check what's in the workspace after loading
        jsr     print_string
        .byte   "After LoadFile_Ycatoffset:"
        nop
        jsr     print_newline
        
        ; Dump the execution address area (aws_tmp14/15 should contain exec address)
        lda     aws_tmp14
        jsr     print_hex
        lda     aws_tmp15  
        jsr     print_hex
        jsr     print_newline
        
        ; Also dump the workspace area that MMFS uses for exec address
        lda     #$76                    ; Low byte of $1076
        ldx     #$10                    ; High byte of $1076
        ldy     #$04                    ; Dump 4 bytes ($1076-$1079)
        jsr     dump_memory_block
.endif
        
        ; Set up execution parameters
        clc
        lda     fuji_text_ptr_offset   ; MA+&10D9 += text ptr (parameters)
        tay
        adc     TextPointer
        sta     fuji_text_ptr_offset
        lda     TextPointer+1
        adc     #$00
        sta     fuji_text_ptr_hi       ; MA+&10DA

        ; TUBE CODE TODO        
        ; Check if execution address is &FFFFFFFF (host execution)
        ; TODO: Get execution address from loaded file workspace
        ; For now, assume host execution

runfile_inhost:
.ifdef FN_DEBUG
        jsr     print_string
        .byte   "Executing at: "
        nop
        lda     aws_tmp15              ; High byte of exec address (stored from catalog)
        jsr     print_hex
        lda     aws_tmp14              ; Low byte of exec address (stored from catalog)
        jsr     print_hex
        jsr     print_newline
.endif
        ; Execute program in host
        lda     #$01                   ; Execute program
        jmp     (aws_tmp14)            ; Jump to execution address
