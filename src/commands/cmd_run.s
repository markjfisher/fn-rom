; *RUN command implementation
; Based on MMFS fscv2_4_11_starRUN (line 2114)

        .export fscv2_4_11_starRUN

        .import LoadFile_Ycatoffset
        .import get_cat_firstentry81
        .import read_fspba_reset
        .import read_fspba
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
        ; dbg_string_axy "FSCV2_4_11_STARRUN: "

        ; Set up text pointer (MMFS line 2115)
        jsr     set_text_pointer_yx

        ; Set up text pointer and workspace
        lda     #$FF
        sta     aws_tmp14              ; &BE -> aws_tmp14 (use file's load address)
        lda     TextPointer
        sta     aws_tmp10              ; &BA -> aws_tmp10  
        lda     TextPointer+1
        sta     aws_tmp11              ; &BB -> aws_tmp11

        ; ldy     #$00
        sty     fuji_text_ptr_hi       ; MA+&10DA (Y=0)
        jsr     read_fspba_reset       ; Look in default drive/dir
        sty     fuji_text_ptr_offset   ; MA+&10D9 (Y=text ptr offset)
        jsr     get_cat_firstentry81
        bcs     runfile_found          ; If file found

        ; File not found in default location, try library
        ldy     fuji_text_ptr_hi       ; MA+&10DA
        lda     fuji_lib_dir           ; LIB_DIR -> DirectoryParam
        sta     DirectoryParam
        lda     fuji_lib_drive         ; LIB_DRIVE -> CurrentDrv
        sta     CurrentDrv
        jsr     read_fspba
        jsr     get_cat_firstentry81   ; Use correct function
        bcs     runfile_found          ; If file found

        ; File not found anywhere
err_bad_command:
        jsr     err_bad
        .byte   $FE
        .byte   "command", 0

runfile_found:
; .ifdef FN_DEBUG
;         jsr     print_string
;         .byte   "File found! Loading...", $0D
;         nop
; .endif
        ; Check if this is an *EXEC file (exec address = &FFFFFFFF)
        lda     dfs_cat_file_op,y               ; Mixed byte from catalog
        jsr     a_rorx6and3                     ; Extract high bits
        cmp     #$03                            ; If high bits = 3
        bne     runfile_run                     ; If not &FFFFFFFF, run normally

        ; Check if exec address is &FFFFFFFF
        lda     dfs_cat_file_exec_addr,y        ; Exec address low byte
        and     dfs_cat_file_exec_addr+1,y      ; Exec address high byte
        cmp     #$FF
        bne     runfile_run                     ; If not &FFFFFFFF, run normally

        ; This is an *EXEC file - convert to *EXEC command
        ldx     #$06
@runfile_exec_loop:
        lda     fuji_filename_buffer,x          ; Move filename
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
        sta     fuji_filename_buffer+3          ; Drive number X
        lda     #'.'
        sta     fuji_filename_buffer+1
        sta     fuji_filename_buffer+4
        sta     fuji_filename_buffer+6
        lda     DirectoryParam                  ; Directory D
        sta     fuji_filename_buffer+5

        ; Execute the *EXEC command
        ldx     #<fuji_filename_buffer
        ldy     #>fuji_filename_buffer          ; MP+HI(fuji_filename_buffer): FUTURE: need to adjust
        jmp     OSCLI                           ; Execute "E.:X.D.FILENAME"

runfile_run:
        ; Load the file normally
        jsr     LoadFile_Ycatoffset    ; Load file

        ; Set up execution parameters
        clc
        lda     fuji_text_ptr_offset   ; MA+&10D9 += text ptr (parameters)
        tay
        adc     TextPointer
        sta     fuji_text_ptr_offset
        lda     TextPointer+1
        adc     #$00
        sta     fuji_text_ptr_hi       ; MA+&10DA

        ; FUTURE: TUBE CODE        
        ; Check if execution address is &FFFFFFFF (host execution)
        ; TODO: Get execution address from loaded file workspace
        ; For now, assume host execution

runfile_inhost:
.ifdef FN_DEBUG
        jsr     print_string
        .byte   "Exec: "
        lda     aws_tmp15              ; High byte of exec address (stored from catalog)
        jsr     print_hex
        lda     aws_tmp14              ; Low byte of exec address (stored from catalog)
        jsr     print_hex
        jsr     print_newline
.endif
        ; Execute program in host
        lda     #$01                   ; Execute program
        jmp     (aws_tmp14)            ; Jump to execution address
