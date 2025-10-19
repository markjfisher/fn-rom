        .export check_channel_yhndl_exyintch
        .export check_channel_yhndl_exyintch_tya_cmpptr
        .export cmp_ptr_ext
        .export conv_yhndl_intch_exyintch
        .export err_bad_drive
        .export fscv1_eof_yhndl
        .export fscv7_hndlrange
        .export get_cat_entry
        .export get_cat_entry_fspba
        .export get_cat_firstentry80
        .export get_cat_firstentry80_fname
        .export get_cat_firstentry81
        .export get_cat_nextentry
        .export GSREAD_A
        .export is_hndlin_use_yintch
        .export load_cur_drv_cat
        .export load_cur_drv_cat2
        .export param_drive_no_bad_drive
        .export param_drive_no_syntax
        .export param_optional_drive_no
        .export param_syntaxerrorifnull
        .export param_syntaxerrorifnull_getcatentry_fsptxtp
        .export parameter_afsp_param_syntaxerrorifnull_getcatentry_fsptxtp
        .export prt_filename_yoffset
        .export prt_info_msg_yoffset
        .export prt_infoline_yoffset
        .export prt_y_spaces
        .export rdafsp_padall
        .export read_dir_drv_parameters2
        .export read_file_attribs_to_b0_yoffset
        .export read_fspba
        .export read_fspba_reset
        .export save_cat_to_disk
        .export set_curdir_drv_to_defaults
        .export set_curdrv_to_default
        .export set_current_drive_adrive
        .export tya_cmp_ptr_ext
        .export y_sub8

        .import GSINIT_A
        .import a_rolx5
        .import a_rorx5
        .import fuji_write_catalog
        .import clear_exec_spool_file_handle
        .import err_bad
        .import fuji_read_catalog
        .import is_alpha_char
        .import parameter_afsp
        .import print_2_spaces_spl
        .import print_axy
        .import print_char
        .import print_decimal
        .import print_fullstop
        .import print_hex
        .import print_newline
        .import print_nibble
        .import print_space_spl
        .import print_string
        .import prtcmd_at_bc_add_1
        .import prtcmd_prtchr
        .import remember_axy
        .import report_error
        .import y_add7

        .include "fujinet.inc"


; parameter_afsp_Param_SyntaxErrorIfNull_getcatentry_fspTxtP
; Direct translation of MMFS line 620-630
parameter_afsp_param_syntaxerrorifnull_getcatentry_fsptxtp:
        jsr     parameter_afsp

param_syntaxerrorifnull_getcatentry_fsptxtp:
        jsr     param_syntaxerrorifnull

getcatentry_fspTxtP:
        jsr     read_fsp_text_pointer
        jmp     get_cat_entry

get_cat_entry_fspba:
	jsr     read_fspba_reset

get_cat_entry:
        jsr     get_cat_firstentry80
        bcc     err_file_not_found
        ; too far a jump when debug is on to the next rts, so swap the logic
        rts

err_file_not_found:
        jsr     report_error
        .byte   $D6
        .byte   "Not found", 0


; get_cat_firstentry80 (MMFS line 672-676)
get_cat_firstentry81:
get_cat_firstentry80:
        ; dbg_string_axy "get_cat80: "
        jsr     check_cur_drv_cat       ; Get cat entry
        ldx     #$00                    ; now first byte @ &1000+X
        beq     get_cat_entry_2            ; always

; get_cat_nextentry (MMFS line 678-680)
get_cat_nextentry:
        ldx     #$00                    ; Entry: wrd &B6 -> first entry
        beq     getcatsetupb7           ; always

get_cat_firstentry80_fname:
        ldx     #$06                    ; copy filename from &C5 to &1058
@get_cat_loop1:
        lda     pws_tmp05,x
        sta     $1058,x
        dex
        bpl     @get_cat_loop1
        lda     #' '
        sta     $105F

        jsr     check_cur_drv_cat       ; catalog entry matching
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
        cmp     dfs_cat_num_x8                 ; ( MA+&F05) number of files *8
        bcs     matfn_exitc0            ; If >dfs_cat_num_x8 Exit with C=0
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

; DO NOT MOVE THIS! It's used by above as a fall through.
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
        lda     fuji_filename_buffer,x        ; with that at (&B6)
        cmp     fuji_wild_star               ; wildcard character
        bne     @matfn_nomatch          ; e.g. If="*"
        inx
@matfn_loop2:
        jsr     match_filename
        bcs     matfn_exit              ; If match then exit with C=1
        iny
        cpy     #$07
        bcc     @matfn_loop2            ; If Y<7
@matfn_loop3:
        lda     fuji_filename_buffer,x        ; Check next char is a space!
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
        cmp     fuji_wild_star               ; wildcard character
        beq     @exit                   ; eg. If "*"
        cmp     fuji_wild_hash               ; wildcard character
        beq     @exit                   ; eg. If "#"
        jsr     is_alpha_char
        eor     (aws_tmp06),y           ; (&B6),Y
        bcs     @not_alpha              ; IF not alpha char
        and     #$5F
@not_alpha:
        and     #$7F
@exit:
        rts                             ; If n=1 then matched

prt_info_msg_yoffset:
        bit     fuji_fs_messages_on
        bmi     matfn_exit              ; just an rts

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
        jsr     read_file_attribs_to_b0_yoffset ; create no. str
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
        jmp     print_space_spl

; read_file_attribs_to_b0_yoffset (MMFS line 872-932)
read_file_attribs_to_b0_yoffset:
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
        lda     fuji_default_dir             ; Set working directory
        sta     DirectoryParam

set_curdrv_to_default:
        lda     fuji_default_drive           ; Set working drive
set_current_drive_adrive:
        and     #$03
set_current_drive_adrive_noand:
        sta     CurrentDrv
        rts

; (<drive>)
param_optional_drive_no:
        jsr     GSINIT_A
        beq     set_curdrv_to_default

; <drive>
; Exit: A=DrvNo, C=0, XY preserved
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
        ; exit with C=0
        bcc     set_current_drive_adrive_noand

err_bad_drive:
        jsr     err_bad
        .byte   $CD
        .byte   "drive", 0

load_cur_drv_cat2:
        jsr     remember_axy

; load_cur_drv_cat - Load current drive catalog (MMFS line 7267-7279)
; For FujiNet, this is equivalent to MMFS's exec_cat_rw with A=#&53
load_cur_drv_cat:
        ; Load catalog from FujiNet interface (equivalent to OW7F_Execute_and_ReportIfDiskFault)
        jsr     fuji_read_catalog

        ; Mark catalog as loaded for current drive (equivalent to MMFS line 7322-7323)
write_current_drv_to_cat:
        lda     CurrentDrv
        sta     CurrentCat
        rts

save_cat_to_disk:
        lda     dfs_cat_cycle
        clc
        sed
        adc     #$01
        sta     dfs_cat_cycle
        cld

        jsr     fuji_write_catalog
        jmp     write_current_drv_to_cat


; read_fsp_text_pointer - Read filename from text pointer (MMFS line 452-504)
read_fsp_text_pointer:
        jsr     set_curdir_drv_to_defaults ; Set current directory and drive
        jmp     rdafsp_entry            ; Jump to filename parsing

read_fspba_reset:
        jsr     set_curdir_drv_to_defaults ; Set current directory and drive

read_fspba:
        lda     aws_tmp10               ; **Also creates copy at &C5 (MMFS line 458)
        sta     TextPointer
        lda     aws_tmp11
        sta     TextPointer+1
        ldy     #$00
        jsr     GSINIT_A

; rdafsp_entry - Filename parsing entry point (MMFS line 464-504)
rdafsp_entry:
        ldx     #' '                    ; Get drive & dir (X="space")
        jsr     GSREAD_A                ; Get character
        bcs     err_bad_name            ; If end of string
        sta     fuji_filename_buffer    ; Store first character
        cmp     #'.'                    ; C="."?
        bne     rdafsp_notdot           ; If not dot, continue
rdafsp_setdrv:
        stx     DirectoryParam          ; Save directory (X)
        beq     rdafsp_entry            ; Always (restart)
rdafsp_notdot:
        cmp     #':'                    ; C=":"? (Drive number follows)
        bne     rdafsp_notcolon
        jsr     param_drive_no_bad_drive ; Get drive no.
        jsr     GSREAD_A
        bcs     err_bad_name            ; If end of string
        cmp     #'.'                    ; C="."?
        beq     rdafsp_entry            ; err if not eg ":0."

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
        sta     fuji_filename_buffer,x        ; Store filename character
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
        sta     fuji_filename_buffer,x  ; Store space
        inx
        cpx     #$40                    ; Pad to $40 (64 bytes)
        bne     @rdafsp_padloop
        ldx     #$06                    ; Copy from fuji_filename_buffer ($1000) to $C5
@rdafsp_copyloop:
        lda     fuji_filename_buffer,x
        sta     pws_tmp05,x
        dex
        bpl     @rdafsp_copyloop

; .ifdef FN_DEBUG
;         jsr     print_string
;         .byte   "Parsed filename: "
;         ldx     #$00
; @debug_filename_loop:
;         lda     fuji_filename_buffer,x
;         jsr     print_char
;         inx
;         cpx     #$07
;         bne     @debug_filename_loop
;         jsr     print_newline
; .endif

        rts

; prt_filename_yoffset - Print filename with directory and lock status
; Direct translation of MMFS prt_filename_Yoffset (lines 551-580)
; Y = offset into catalog filename area (0, 8, 16, etc.)
prt_filename_yoffset:
        jsr     remember_axy
        lda     dfs_cat_file_dir,y      ; Directory byte (MA+&0E0F,Y)
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
        lda     dfs_cat_file_name,y     ; Filename byte (MA+&0E08,Y)
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

prt_y_spaces:
        jsr     print_space_spl
        dey
        bne     prt_y_spaces
        rts

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; fscv1_eof_yhndl - EOF being chekced, X = file handle
; Esit: X=$FF if EOF, X=$00 if not EOF
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

fscv1_eof_yhndl:
        pha
        tya
        pha
        txa
        tay
        jsr     check_channel_yhndl_exyintch_tya_cmpptr
        bne     @eof_not_end
        ldx     #$FF
        bne     @eof_exit
@eof_not_end:
        ldx     #$00
@eof_exit:
        pla
        tay
        pla
        rts

check_channel_yhndl_exyintch_tya_cmpptr:
        jsr     check_channel_yhndl_exyintch

tya_cmp_ptr_ext:
        tya
cmp_ptr_ext:
        tax
        lda     fuji_ch_bptr_hi,y       ; PTR#
        cmp     fuji_ch_ext_hi,x        ; EXT#
        bne     @cmpPE_exit
        lda     fuji_ch_bptr_mid,y
        cmp     fuji_ch_ext_mid,x
        bne     @cmpPE_exit
        lda     fuji_ch_bptr_low,y
        cmp     fuji_ch_ext_low,x
@cmpPE_exit:
        rts

check_channel_yhndl_exyintch:
        jsr     conv_yhndl_intch_exyintch
        jsr     is_hndlin_use_yintch
        bcc     check_channel_yhndl_exyintch_exit
        jsr     clear_exec_spool_file_handle
        rts

check_channel_yhndl_exyintch_exit:
        rts

conv_yhndl_intch_exyintch:
        ; Convert file handle Y to internal channel number
        ; Based on MMFS conv_Yhndl_intch_exYintch (line 5083)
        pha                             ; Save A
        tya
; label not actively used
conv_hndl_x_entry:
        cmp     #filehndl
        bcc     conv_hndl10
        cmp     #filehndl + 8
        bcc     conv_hndl18
conv_hndl10:
        lda     #$08                    ; exit with C=1,A=0; intch=0
conv_hndl18:
        jsr     a_rolx5                 ; if Y<$10 or >$18
        tay                             ; ch0=$00, ch1=$20, ch2=$40
        pla                             ; ch3=$60...ch7=$E0
        rts                             ; c=1 if not valid

is_hndlin_use_yintch:
        ; Check if file handle is in use
        ; Based on MMFS IsHndlinUse_Yintch (line 5051)
        pha                             ; Save A
        stx     fuji_saved_x            ; Save X to fuji_saved_x
        tya
        and     #$E0
        sta     fuji_intch              ; Save intch
        beq     hndlinuse_notused_c1
        jsr     a_rorx5                 ; ch.1-7
        tay                             ; create bit mask
        lda     #$00                    ; 1=10000000
        sec                             ; 2=01000000 etc
hndlinuse_loop:
        ror     a
        dey
        bne     hndlinuse_loop
        ; Carry = 0
        ldy     fuji_intch              ; Y=intch
        bit     fuji_open_channels      ; Test if open
        bne     hndlinuse_used_c0
hndlinuse_notused_c1:
        sec
hndlinuse_used_c0:
        pla
        rts

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; fscv7_hndlrange - Return file handle range
; Translated from MMFS fscv7_hndlrange (lines 4582-4586)
; Exit: X = lowest handle issued (filehndl+1 = $11)
;       Y = highest handle possible (filehndl+5 = $15)
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

fscv7_hndlrange:
        ldx     #filehndl + 1           ; Lowest handle issued = $11
        ldy     #filehndl + 5           ; Highest handle possible = $15
        rts

read_dir_drv_parameters:
        lda     fuji_default_dir        ; read drive/directory from
        sta     DirectoryParam          ; command line
        jsr     GSINIT_A
        bne     read_dir_drv_parameters2        ; if not null string
        lda     #$00
        sta     CurrentDrv
        rts

; read_dir_drv_parameters2 - Read directory and drive parameters
read_dir_drv_parameters2:
        jsr     set_curdrv_to_default
@rdd_loop:
        jsr     GSREAD_A                ; Read next character
        bcs     err_bad_directory       ; If end of string, error
        cmp     #':'                    ; ":"?
        bne     rdd_exit2               ; Not ":", store as directory
        jsr     param_drive_no_bad_drive ; Get drive number
        jsr     GSREAD_A                ; Read next character
        bcs     rdd_exit1               ; If end of string, done
        cmp     #'.'                    ; "."?
        beq     @rdd_loop               ; Loop if "."

err_bad_directory:
        jsr     err_bad
        .byte   $CE
        .byte   "dir", 0

rdd_exit2:
        sta     DirectoryParam          ; Store directory character
        jsr     GSREAD_A
        bcc     err_bad_directory

rdd_exit1:
        lda     CurrentDrv
        rts

