; *INFO command implementation for FujiNet ROM
; Contains both FSCV and command table implementations

        .export fscv10_starINFO
        .export cmd_fs_info
        .export err_file_not_found
        .export get_cat_entry
        .export GSREAD_A

        .import cmd_table_fujifs
        .import cmd_table_info
        .import fuji_read_catalog
        .import is_alpha_char
        .import err_bad
        .import parameter_afsp
        .import print_2_spaces_spl
        .import print_axy
        .import print_char
        .import print_fullstop
        .import print_hex
        .import print_nibble
        .import print_newline
        .import print_space_spl
        .import print_string
        .import remember_axy
        .import GSINIT_A
        .import report_error
        .import set_text_pointer_yx
        .import y_add7
        .import prtcmd_at_bc_add_1
        .import prtcmd_prtchr

        .include "fujinet.inc"

        .segment "CODE"

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; FSCV10_STARINFO - Handle *INFO command via FSCV
; This is called when *INFO is used on the active filing system
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

fscv10_starINFO:
.ifdef FN_DEBUG
        jsr     print_string
        .byte   "FSCV10_STARINFO called", $0D
        nop
        jsr     print_axy
.endif

        jsr     set_text_pointer_yx
        lda     #<(cmd_table_info - cmd_table_fujifs - 1) ; aws_tmp15 (BF) needs to point to the INFO command
        sta     aws_tmp15               ; equivalent of .Param_SyntaxErrorIfNull


        ; Fall through to cmd_fs_info (old .CMD_INFO)

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; CMD_FS_INFO - Handle *INFO command
; This is the shared implementation called by both:
; - fscv10_starINFO (when *INFO is called on active filing system)
; - cmd_table_fujifs (when *FUJI INFO is called)
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

cmd_fs_info:
.ifdef FN_DEBUG
        jsr     print_string
        .byte   "CMD_FS_INFO called", $0D
        nop
        jsr     print_axy
.endif  
        ; Load catalog first
        jsr     fuji_read_catalog


        ; Direct translation of MMFS CMD_INFO (lines 664-670)
        jsr     parameter_afsp_param_syntaxerrorifnull_getcatentry_fsptxtp

@cmd_info_loop:
        jsr     prt_infoline_yoffset
        jsr     get_cat_nextentry
        bcs     @cmd_info_loop

; just a convenient rts nearby
getcat_exit:
        rts

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; MMFS TRANSLATION FUNCTIONS
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

; parameter_afsp_Param_SyntaxErrorIfNull_getcatentry_fspTxtP
; Direct translation of MMFS line 620-630
parameter_afsp_param_syntaxerrorifnull_getcatentry_fsptxtp:
        jsr     parameter_afsp

param_syntaxerrorifnull_getcatentry_fsptxtp:
        jsr     param_syntaxerrorifnull

getcatentry_fspTxtP:
        jsr     read_fsp_text_pointer
        bmi     get_cat_entry             ; always ??

getcatentry_fspBA:
	jsr     read_fspBA_reset

get_cat_entry:
        jsr     get_cat_firstentry80
        bcs     getcat_exit
        ; falls into err_FILENOTFOUND

err_file_not_found:
        jsr     report_error
        .byte   $D6
        .byte   "Not found", 0


; get_cat_firstentry80 (MMFS line 672-676)
get_cat_firstentry80:
        jsr     check_cur_drv_cat       ; Get cat entry
        ldx     #$00                    ; now first byte @ &1000+X
        beq     get_cat_entry_2            ; always

; get_cat_nextentry (MMFS line 678-680)
get_cat_nextentry:
        ldx     #$00                    ; Entry: wrd &B6 -> first entry
        beq     getcatsetupb7           ; always

get_cat_first_entry80_fname:
        ldx     #$06                    ; copy filename from &C5 to &1058
@get_cat_loop1:
        lda     pws_tmp05,x
        sta     $1058,x
        dex
        bpl     @get_cat_loop1
        lda     #' '
        sta     $105F

        jsr     check_cur_drv_cat       ; catalogue entry matching
        ldx     #$58                    ; string at &1058

get_cat_entry_2:
        lda     #$00                    ; word &B6 = &E00 = PTR (start of catalog)
        sta     aws_tmp06               ; &B6 -> aws_tmp06
getcatsetupb7:
        lda     #$0E                    ; string at &E00+A
        sta     aws_tmp07               ; &B7 -> aws_tmp07
@get_cat_loop2:
        ldy     #$00
        lda     aws_tmp06               ; &B6
        cmp     FilesX8                 ; ( MA+&F05) number of files *8
        bcs     matfn_exitc0            ; If >FilesX8 Exit with C=0
        adc     #$08
        sta     aws_tmp06               ; word &B6 += 8
        jsr     match_filename
        bcc     @get_cat_loop2          ; not a match, try next file
        lda     DirectoryParam
        ldy     #$07
        jsr     match_chr
        bne     @get_cat_loop2          ; If directory doesn't match
        ldy     aws_tmp06               ; &B6
        sec                             ; Return, Y=offset-8, C=1

; Y_sub8 (MMFS line 715-723)
y_sub8:
        dey
        dey
        dey
        dey
        dey
        dey
        dey
        dey
        rts

; match_filename (MMFS line 728-756)
match_filename:
        jsr     remember_axy            ; Match filename at &1000+X
@matfn_loop1:
        lda     FilenameBuffer,x        ; with that at (&B6)
        cmp     Wild_Star               ; wildcard character
        bne     @matfn_nomatch          ; e.g. If="*"
        inx
@matfn_loop2:
        jsr     match_filename
        bcs     matfn_exit              ; If match then exit with C=1
        iny
        cpy     #$07
        bcc     @matfn_loop2            ; If Y<7
@matfn_loop3:
        lda     FilenameBuffer,x        ; Check next char is a space!
        cmp     #' '
        bne     matfn_exitc0            ; If exit with c=0 (no match)
        rts                             ; exit with C=1

@matfn_nomatch:
        cpy     #$07
        bcs     @matfn_loop3            ; If Y>=7
        jsr     match_chr
        bne     matfn_exitc0
        inx
        iny
        bne     @matfn_loop1            ; next chr

matfn_exitc0:
        clc                             ; exit with C=0
matfn_exit:
        rts

; match_chr (MMFS line 762-776)
match_chr:
        cmp     Wild_Star               ; wildcard character
        beq     @exit                   ; eg. If "*"
        cmp     Wild_Hash               ; wildcard character
        beq     @exit                   ; eg. If "#"
        jsr     is_alpha_char
        eor     (aws_tmp06),y           ; (&B6),Y
        bcs     @not_alpha              ; IF not alpha char
        and     #$5F
@not_alpha:
        and     #$7F
@exit:
        rts                             ; If n=1 then matched

; prt_InfoLine_Yoffset (MMFS line 826-855)
prt_infoline_yoffset:
        jsr     remember_axy            ; Print info
        jsr     prt_filename_yoffset
        tya                             ; Save offset
        pha
        lda     #$60                    ; word &B0=1060
        sta     aws_tmp00               ; &B0 -> aws_tmp00
        lda     #$10
        sta     aws_tmp01               ; &B1 -> aws_tmp01
        jsr     readfileattribstob0_yoffset ; create no. str
        ldy     #$02
        jsr     print_space_spl              ; print " " (one space)
        jsr     print_hex_3byte           ; Load address
        jsr     print_hex_3byte           ; Exec address
        jsr     print_hex_3byte           ; Length
        pla
        tay
        lda     $0F0E,y                 ; First sector high bits
        and     #$03
        jsr     print_nibble
        lda     $0F0F,y                 ; First sector low byte
        jsr     print_hex
        jmp     print_newline

; print_hex_3byte (MMFS line 857-868)
print_hex_3byte:
        ldx     #$03                    ; eg print "123456 "
@print_hex_3byte_loop:
        lda     $1062,y
        jsr     print_hex
        dey
        dex
        bne     @print_hex_3byte_loop
        jsr     y_add7
        jmp     print_2_spaces_spl

; ReadFileAttribsToB0_Yoffset (MMFS line 872-932)
readfileattribstob0_yoffset:
        jsr     remember_axy            ; Decode file attribs
        tya
        pha                             ; bytes 2-11
        tax                             ; X=cat offset
        ldy     #$12                    ; Y=(B0) offset
        lda     #$00                    ; Clear pwsp+2 to pwsp+&11
@readfileattribs_clearloop:
        dey
        sta     (aws_tmp00),y           ; (&B0),Y
        cpy     #$02
        bne     @readfileattribs_clearloop
@readfileattribs_copyloop:
        jsr     readfileattribs_copy2bytes ; copy low bytes of
        iny                             ; load/exec/length
        iny
        cpy     #$0E
        bne     @readfileattribs_copyloop
        pla
        tax
        lda     $0E0F,x
        bpl     @readfileattribs_notlocked ; If not locked
        lda     #$08
        sta     (aws_tmp00),y           ; pwsp+&E=8
@readfileattribs_notlocked:
        lda     $0F0E,x                 ; mixed byte
        ldy     #$04                    ; load address high bytes
        jsr     @readfileattribs_addrhibytes
        ldy     #$0C                    ; file length high bytes
        lsr
        lsr
        pha
        and     #$03
        sta     (aws_tmp00),y
        pla
        ldy     #$08                    ; exec address high bytes
@readfileattribs_addrhibytes:
        lsr
        lsr                             ; /4
        pha
        and     #$03
        cmp     #$03                    ; done slightly diff. to 8271
        bne     @readfileattribs_nothost
        lda     #$FF
        sta     (aws_tmp00),y
        iny
@readfileattribs_nothost:
        sta     (aws_tmp00),y
readfileattribs_exits:
        pla
        rts
readfileattribs_copy2bytes:
        jsr     readfileattribs_copy1byte
readfileattribs_copy1byte:
        lda     $0F08,x
        sta     (aws_tmp00),y
        inx
        iny
        rts

; param_syntaxerrorifnull - Check for syntax error if no parameters (MMFS line 5553-5556)
param_syntaxerrorifnull:
        jsr     GSINIT_A                ; Initialize parameter parsing
        beq     err_syntax             ; If no parameters, syntax error
        rts


param_syntax_error_if_not_null:
        jsr     GSINIT_A
        bne     err_syntax
        rts

; err_syntax - Syntax error handler (MMFS line 5566-5571)
err_syntax:
        jsr     report_error             ; Print Syntax error
        .byte   $DC                      ; Error code
        .byte   "Syntax: "               ; Null-terminated string
        stx     aws_tmp09                ; ?&B9=&100 offset (>0)
        jsr     prtcmd_at_bc_add_1       ; Print command syntax
        lda     #$00                     ; Add null terminator
        jsr     prtcmd_prtchr            ; Print null character
        jmp     $0100                    ; Cause BREAK!





; check_cur_drv_cat - Check if current drive catalog is loaded (MMFS line 7255-7259)
check_cur_drv_cat:
        lda     CurrentCat              ; Get current catalog drive
        cmp     CurrentDrv              ; Compare with current drive
        bne     load_cur_drv_cat           ; If different, load catalog
        rts

; Additional helper functions needed

; set_curdir_drv_to_defaults - Set current directory and drive to defaults (MMFS line 2657-2667)
set_curdir_drv_to_defaults:
        lda     DEFAULT_DIR             ; Set working directory
        sta     DirectoryParam

set_curdrv_to_default:
        lda     DEFAULT_DRIVE           ; Set working drive
set_current_drive_Adrive:
        and     #$03
set_current_drive_Adrive_noand:
        sta     CurrentDrv
        rts

param_drive_no_syntax:
        jsr     param_syntaxerrorifnull

param_drive_no_bad_drive:
        jsr     GSREAD_A
        bcs     err_bad_name
        cmp     #':'
        beq     param_drive_no_bad_drive
        sec
        sbc     #'0'
        cmp     #4
        bcc     set_current_drive_Adrive_noand

err_bad_drive:
        jsr     err_bad
        .byte   $CD
        .byte   "drive", 0

; load_cur_drv_cat - Load current drive catalog (MMFS line 7267-7279)
load_cur_drv_cat:
        ; For now, just mark the catalog as loaded
        ; TODO: Implement actual catalog loading from disk
        lda     CurrentDrv
        sta     CurrentCat
        rts

; read_fsp_text_pointer - Read filename from text pointer (MMFS line 452-504)
read_fsp_text_pointer:
        jsr     set_curdir_drv_to_defaults ; Set current directory and drive
        jmp     rdafsp_entry            ; Jump to filename parsing

read_fspBA_reset:
        jsr     set_curdir_drv_to_defaults ; Set current directory and drive

read_fspBA:
        lda     aws_tmp10
        sta     TextPointer
        lda     aws_tmp11
        sta     TextPointer+1
        ldy     #$00
        jsr     GSINIT_A

; rdafsp_entry - Filename parsing entry point (MMFS line 464-504)
rdafsp_entry:
        ldx     #' '                    ; Get drive & dir (X="space")
        jsr     GSREAD_A                ; Get character
        bcs     err_bad_name           ; If end of string
        sta     $1000                   ; Store first character
        cmp     #'.'                    ; C="."?
        bne     rdafsp_notdot          ; If not dot, continue
rdafsp_setdrv:
        stx     DirectoryParam          ; Save directory (X)
        beq     rdafsp_entry            ; Always (restart)
rdafsp_notdot:
        cmp     #':'                    ; C=":"? (Drive number follows)
        bne     rdafsp_notcolon
        jsr     param_drive_no_bad_drive ; Get drive no.
        jsr     GSREAD_A
        bcs     err_bad_name           ; If end of string
        cmp     #'.'                    ; C="."?
        beq     rdafsp_setdrv

err_bad_name:
        jsr     err_bad
        .byte   $CC
        .byte   "name", 0


rdafsp_notcolon:
        tax                             ; X=last character
        jsr     GSREAD_A                ; Get next character
        bcs     rdafsp_padall           ; If end of string
        cmp     #'.'                    ; C="."?
        beq     rdafsp_setdrv
        ldx     #$01                    ; Read rest of filename
@rdafsp_rdfnloop:
        sta     FilenameBuffer,x        ; Store filename character
        inx
        jsr     GSREAD_A                ; Get next character
        bcs     rdafsp_padx             ; If end of string
        cpx     #$07                    ; Max 7 characters
        bne     @rdafsp_rdfnloop
        beq     err_bad_name            ; Too many characters

GSREAD_A:
        jsr     GSREAD
        php
        and     #$7F
        cmp     #$0D        ; Return?
        beq     @exit
        cmp     #$20        ; Control character? (I.e. <&20)
        bcc     err_bad_name
        cmp     #$7F        ; Backspace?
        beq     err_bad_name
@exit:
        plp
        rts

rdafsp_padall:
        ldx     #$01                    ; Pad all with spaces
rdafsp_padx:
        lda     #' '                    ; Pad with spaces
@rdafsp_padloop:
        sta     FilenameBuffer,x                 ; Store space
        inx
        cpx     #$40                    ; Pad to $40 (64 bytes)
        bne     @rdafsp_padloop
        ldx     #$06                    ; Copy from FilenameBuffer ($1000) to $C5
@rdafsp_copyloop:
        lda     FilenameBuffer,x
        sta     pws_tmp05,x
        dex
        bpl     @rdafsp_copyloop
        rts

; prt_filename_yoffset - Print filename with directory and lock status
; Direct translation of MMFS prt_filename_Yoffset (lines 551-580)
; Y = offset into catalog filename area (0, 8, 16, etc.)
prt_filename_yoffset:
        jsr     remember_axy
        lda     $0E0F,y                 ; Directory byte (MA+&0E0F,Y)
        php                             ; Save flags (including lock bit)
        and     #$7F                    ; Remove lock bit, keep directory
        bne     @prt_filename_prtchr    ; If directory != 0, print it
        jsr     print_2_spaces_spl      ; Print "  " (two spaces)
        beq     @prt_filename_nodir     ; always
@prt_filename_prtchr:
        jsr     print_char              ; Print directory character
        jsr     print_fullstop          ; Print "."
@prt_filename_nodir:
        ldx     #$06                    ; Print filename (7 characters)
@prt_filename_loop:
        lda     $0E08,y                 ; Filename byte (MA+&0E08,Y)
        and     #$7F                    ; Remove high bit
        jsr     print_char
        iny
        dex
        bpl     @prt_filename_loop
        jsr     print_2_spaces_spl      ; Print "  " (two spaces)
        lda     #' '                    ; Default to space
        plp                             ; Restore flags
        bpl     @prt_filename_notlocked ; If not locked, print space
        lda     #'L'                    ; If locked, print "L"
@prt_filename_notlocked:
        jsr     print_char              ; Print "L" or " "
        ldy     #$01                    ; Restore Y to start of file entry
        rts
