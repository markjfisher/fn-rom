        .export check_channel_yhndl_exyintch
        .export check_channel_yhndl_exyintch_tya_cmpptr
        .export cmp_ptr_ext
        .export conv_yhndl_intch_exyintch
        .export err_bad_drive
        .export err_syntax
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
        .export jmp_syntax
        .export load_cur_drv_cat
        .export load_cur_drv_cat2
        .export num_params
        .export param_drive_no_bad_drive
        .export param_drive_no_syntax
        .export param_get_num
        .export param_get_string
        .export param_optional_drive_no
        .export param_syntax_error_if_null
        .export param_syntax_error_if_null_getcatentry_fsptxtp
        .export parameter_afsp_param_syntax_error_if_null_getcatentry_fsptxtp
        .export prt_filename_yoffset
        .export prt_info_msg_yoffset
        .export prt_infoline_yoffset
        .export prt_y_spaces
        .export rdafsp_padall
        .export read_dir_drv_parameters
        .export read_dir_drv_parameters2
        .export read_file_attribs_to_b0_yoffset
        .export read_fspba
        .export read_fspba_reset
        .export read_fsp_text_pointer
        .export save_cat_to_disk
        .export set_curdir_drv_to_defaults
        .export set_curdrv_to_default
        .export set_current_drive_adrive
        .export tya_cmp_ptr_ext
        .export y_sub8
        .export param_count_a
        .export param_drive_or_default
        .export find_and_mount_disk

        .import GSINIT_A
        .import a_rolx5
        .import a_rorx5
        .import fuji_write_catalog
        .import clear_exec_spool_file_handle
        .import d_match
        .import d_match_init
        .import err_bad
        .import err_disk
        .import fuji_mount_disk
        .import fuji_read_catalog
        .import get_disk_first_all_x
        .import get_disk_next
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
        .import GSREAD

        .include "fujinet.inc"


; parameter_afsp_param_syntax_error_if_null_getcatentry_fspTxtP
; Direct translation of MMFS line 620-630
parameter_afsp_param_syntax_error_if_null_getcatentry_fsptxtp:
        jsr     parameter_afsp

param_syntax_error_if_null_getcatentry_fsptxtp:
        jsr     param_syntax_error_if_null

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
        lda     directory_param
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

; param_syntax_error_if_null - Check for syntax error if no parameters (MMFS line 5553-5556)
param_syntax_error_if_null:
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
        lda     current_cat              ; Get current catalog drive
        cmp     current_drv              ; Compare with current drive
        bne     load_cur_drv_cat           ; If different, load catalog
        rts

; Additional helper functions needed

; set_curdir_drv_to_defaults - Set current directory and drive to defaults (MMFS line 2657-2667)
set_curdir_drv_to_defaults:
        lda     fuji_default_dir             ; Set working directory
        sta     directory_param

set_curdrv_to_default:
        lda     fuji_default_drive           ; Set working drive
set_current_drive_adrive:
        and     #$03
set_current_drive_adrive_noand:
        sta     current_drv
        rts



; read a generic string, non optional, error if empty
; and save into fuji_filename_buffer
; EXIT A = length (max 63+1 for nul)
;      fuji_filename_buffer contains 0 terminated string up to 63 bytes
;      C = 0 for truncated string (i.e. hit max first)
;      C = 1 for completed reading string
param_get_string:
        jsr     GSINIT_A
        beq     err_bad_string

param_get_string_no_init:
        ldx     #$00
@str_loop:
        jsr     GSREAD_A
        bcs     @exit_str
        sta     fuji_filename_buffer, x
        inx
        cpx     #$3F            ; allow up to 64 bytes (with terminating 00, i.e. 63+1)
        bcc     @str_loop
        clc                     ; mark that we have truncated

@exit_str:
        lda     #$00
        sta     fuji_filename_buffer, x
        txa                     ; return the length in A
        ; C=0 for truncated string (max hit), C=1 for string read to end
        rts

err_bad_string:
        jsr     err_bad
        .byte   $CB                             ; i'm guessing this byte is for the memory param to show? Not sure how to do this for a generic "number" error
        .byte   "string", 0

; read a generic number, continuing from current read position (Y)
; non optional, error if it's not between 0-9
; returns result in A
param_get_num:
        jsr     GSINIT_A
        beq     err_bad_num
        jsr     GSREAD_A
;        sec
        sbc     #'0'-1                          ; NOTE: C is 0, so we need to decrease by 1 to get correct subtraction (saves a SEC)
        bmi     err_bad_num                     ; < 0
        cmp     #$0A
        bcs     err_bad_num                     ; > 9
        ; good result in A
        rts

err_bad_num:
        jsr     err_bad
        .byte   $CB                             ; i'm guessing this byte is for the memory param to show? Not sure how to do this for a generic "number" error
        .byte   "number", 0


; (<drive>)
param_optional_drive_no:
        jsr     GSINIT_A
        beq     set_curdrv_to_default

; <drive>
; Exit: A=DrvNo, C=0, XY preserved
param_drive_no_syntax:
        jsr     param_syntax_error_if_null

param_drive_no_bad_drive:
        jsr     GSREAD_A
        bcs     err_bad_name
        cmp     #':'
        beq     param_drive_no_bad_drive
        sec
        sbc     #'0'
        cmp     #$04              ; TODO: how many drives do we want to support - how does this map from FujiNet drives, to BBC drives?
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
        lda     current_drv
        sta     current_cat
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
        sta     text_pointer
        lda     aws_tmp11
        sta     text_pointer+1
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
        stx     directory_param          ; Save directory (X)
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

; ######################################################################################
; GSREAD_A
; ######################################################################################
; get a char and check if it's in ascii range.
; GSREAD will return in A the char read from the string, if it's "escaped" char, then A is ascii value minus $40
GSREAD_A:
        jsr     GSREAD
        php
        and     #$7F
        cmp     #$0D        ; Return?
        beq     @exit
        cmp     #$20        ; Control character? (I.e. < $20)
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
        sta     directory_param          ; command line
        jsr     GSINIT_A
        bne     read_dir_drv_parameters2        ; if not null string
        lda     #$00
        sta     current_drv
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
        sta     directory_param          ; Store directory character
        jsr     GSREAD_A
        bcc     err_bad_directory

rdd_exit1:
        lda     current_drv
        rts

jmp_bad_drive:
        jmp     err_bad_drive

jmp_syntax:
        jmp     err_syntax

err_disk_not_found:
        jsr     err_disk
        .byte   $D6
        .byte   "not found", 0

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; MM32-style parameter parsing for *FIN command
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

; default to 0-1 range, allowing 0 or 1
param_count:
        lda     #$00

; param_count_a - Count the number of parameters entered by user
; Entry: if b7 = 0, permissable range is 0-1, else it's 1-2
;        if b0 = 0, lower limit is allowed
; Exit: C = result, i.e.
; 0    range: (0-1) and count = 0   OR  range: (1-2) and count = 1 (i.e. 'lower value')
; 1    range: (0-1) and count = 1   OR  range: (1-2) and count = 2 (i.e. 'upper value')
;       Y preserved.
;       Jumps to err_syntax if wrong count for given params
param_count_a:
        pha                             ; Save flags
        tya                             ; this will be used as index to char by GSREAD, so save it
        pha                             ; Save Y

        ldx     #$00                    ; Count = 0

@loop1:
        jsr     GSINIT_A                ; up to first space only
        beq     @l1                     ; If no more params

        inx                             ; increment count during loop

@loop2:
        jsr     GSREAD_A
        bcc     @loop2                  ; Until end of string
        bcs     @loop1                  ; always: Check for next param

@l1:
        pla                             ; Restore Y
        tay

        pla                             ; Get flags
        bpl     @l2                     ; If flag7=0: range 0 to 1

        ; range 1 to 2
        dex
        bmi     jmp_syntax              ; If count=0, error as we should have 1 or 2 params

@l2:
        cpx     #$01                    ; x is normalised down to 0-1 for either case because of the dex.
        ; If it matches, C=1 because compare uses carry flag as mini subtraction.
        beq     @l3                     ; matched the upper limit
        bcs     jmp_syntax              ; it was too high, we had too many args

        ; lower range hit, see if the end condition allows this
        ror     a                       ; Check b0 of flag. 1 means not allowed, which drops into C
        bcs     jmp_syntax

        ; fallthrough with C=0, which is our lower range value hit

@l3:
        ; if we came from X=1 check above, then C=1 and is upper limit return value
        rts

; just read the number of parameters on command line, return in A
; preserve Y
num_params:
        tya                             ; save Y
        pha

        ldx     #$00
@loop1:
        jsr     GSINIT_A
        beq     @exit_count             ; finished reading string, got a null

        inx
@loop2:
        jsr     GSREAD_A
        bcc     @loop2
        bcs     @loop1

@exit_count:
        pla                             ; restore Y
        tay
        txa                             ; set result in A
        rts

; param_drive_or_default - Read drive parameter or use default
; Entry: C = 0 if default to be used. From param_count_a, this means we are on the lower bound, thus there's probably a missing parameter, so need to fill it with default
; Exit: A = physical drive number
param_drive_or_default:
        bcc     @use_default

        jsr     GSINIT_A
        jsr     param_drive_no_bad_drive
        jsr     GSREAD_A                ; sets C=1 if at end of string
        lda     current_drv
        bcs     @l2

        ; Not end of string, which was just a drive number like "0"
        jmp     err_bad_drive

@use_default:
        lda     fuji_default_drive

@l2:
        and     #$03                    ; TODO: in MM32.asm this is "AND #&01" with comment "only interest in 'physical drive'"
        sta     current_drv
        rts

; THIS ALL NEEDS REVIEWING - UNTESTED AND MOST OF IT NOT NEEDED - PASS TO FUJINET TO FIND THE FILE AND TRY WITH EXTENSIONS
; TO REDUCE THE CLIENT SIDE CODE

; find_and_mount_disk - Find disk by name and mount it
; Based on MM32 mm32_chain_open (MM32.asm line 1435-1578)
; Separates filename parsing (reusable) from disk operations (FujiNet-specific)
;
; Entry: A = flags
;            b0: 0=looking for file, 1=dir
;            b1: 0=normal, 1='autoload'
;        if C = 0, skip reading the filename
;        current_drv set to target drive
; Exit: C = 1 if file not found, C = 0 if found and mounted
find_and_mount_disk:
        sec

; Entry point for FBOOT and others that pre-load filename, carry will be off coming in this way
find_and_mount_disk2:
        rts
;         pha                             ; Store the flags for later
;         bcc     @l0                     ; Skip filename search if C=0

;         clc                             ; We are not cataloguing
;         jsr     parse_disk_filename     ; MM32 line 1448: JSR mm32_param_filename
;         bcs     @notfound               ; MM32 line 1449: BCS notfound - If error when reading parameter
;         beq     @zerolen                ; MM32 line 1450: BEQ zerolen - If string zero length

; @l0:    ; Scan for disk
;         ; For FujiNet: Call device to search for disk by name
;         jsr     search_fujinet_disks    ; Search FujiNet for matching disk
;         bcc     @found                  ; C=0 = found
        
;         ; MM32 line 1460-1466: Try with .SSD extension
;         pla                             ; MM32 line 1460: PLA - Recover flags
;         pha                             ; MM32 line 1461: PHA - Stash them for l8r
;         and     #$01                    ; MM32 line 1462: AND #$01 - File or directory
;         bne     @notfound               ; MM32 line 1463: BNE notfound - If directory don't try appending suffixes


; ; TODO: THIS ISN'T NEEDED - LET FN DO SEARCHING FOR FILE EXTENSIONS

;         jsr     add_ssd_extension       ; MM32 line 1464: JSR mm32_add_ssd_ext
;         jsr     search_fujinet_disks    ; MM32 line 1465: JSR mm32_Scan_Dir
;         bcc     @found                  ; MM32 line 1466: BCC found

;         ; MM32 line 1469-1483: Try with .DSD extension
;         jsr     change_ssd_to_dsd       ; MM32 line 1469-1480: Change .SSD to .DSD
;         jsr     search_fujinet_disks    ; MM32 line 1482: JSR mm32_Scan_Dir
;         bcc     @found                  ; MM32 line 1483: BCC found

; @notfound:
;         ; MM32 line 1485-1492: Not found
;         pla                             ; MM32 line 1486: PLA - Recover flags
;         and     #$02                    ; MM32 line 1487: AND #$02 - See if we are in autoload mode
;         beq     @notautoload            ; MM32 line 1488: BEQ notautoload
;         sec                             ; MM32 line 1489: SEC
;         rts                             ; MM32 line 1490: RTS - On cold start, simply return
; @notautoload:
;         jmp     err_disk_not_found      ; MM32 line 1492: JMP err_FILENOTFOUND

; @found:
;         ; MM32 line 1494-1516: Validate file vs directory match
;         pla                             ; MM32 line 1495: PLA - Recover flags
;         pha                             ; MM32 line 1496: PHA - Stash them for l8r
;         and     #$01                    ; MM32 line 1497: AND #$01 - File or directory?
;         beq     @file                   ; MM32 line 1498: BEQ file
;         pla                             ; MM32 line 1499: PLA - Fix up stack
;         lda     pws_tmp08               ; MM32 line 1500: LDA is_dir% - is_dir flag from search
;         bne     @okay                   ; MM32 line 1501: BNE okay
;         rts                             ; MM32 line 1502: RTS
; @file:
;         pla                             ; MM32 line 1504: PLA - Recover flags
;         ldx     pws_tmp08               ; MM32 line 1505: LDX is_dir%
;         beq     @okay                   ; MM32 line 1506: BEQ okay
;         and     #$02                    ; MM32 line 1507: AND #$02 - Autoload mode?
;         beq     @notautoload2           ; MM32 line 1508: BEQ notautoload2
;         sec                             ; MM32 line 1509: SEC
;         rts                             ; MM32 line 1510: RTS
; @notautoload2:
;         jsr     report_error            ; MM32 line 1512: JSR ReportError
;         .byte   $D6                     ; MM32 line 1513: EQUB &D6
;         .byte   "Is directory", 0       ; MM32 line 1514: EQUB "Is directory",0

; @zerolen:
;         ; MM32 line 1518-1524: No parameter given by user - unmount drive
;         pla                             ; MM32 line 1520: PLA - Fix up stack before exit
;         jsr     fuji_unmount_disk       ; Clear drive mapping (MM32 clears CHAIN_INDEX)
;         rts

; @okay:
;         ; MM32 line 1526-1577: File/Directory Found - mount it
;         ; Disk number is in aws_tmp08/09 (returned by search_fujinet_disks)
        
;         ; MM32 line 1567-1576: Store cluster in CHAIN_INDEX
;         ; For FujiNet: Record drive→disk mapping
;         jsr     fuji_mount_disk         ; Record mapping in fuji_drive_disk_map
        
;         ; Load the catalog for the mounted disk
;         jsr     load_cur_drv_cat        ; Load catalog from FujiNet
        
;         clc                             ; C=0 = success
;         rts                             ; MM32 line 1577: RTS

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; Filename Parsing Functions (Pure string manipulation - no I/O)
; Based on MM32.asm lines 1106-1220, 1369-1388, 1469-1480
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

; parse_disk_filename - Parse disk filename from command line
; Based on MM32 mm32_param_filename (MM32.asm line 1106-1220)
; Entry: C=1 if cataloguing (allows wildcards)
; Exit: C=1 if error (string too long), Z=1 if zero length string
;       Filename stored in fuji_filename_buffer+16 with hash markers
parse_disk_filename:
        ; TODO: Implement MM32-style filename parsing with:
        ; - Hash markers at start/end
        ; - Wildcard support (* and #) if cataloguing
        ; - Directory marker (/) handling
        ; - Uppercase conversion
        ; - Extension dot handling
        ; - Max 16 character limit
        ; For now, use simpler parsing
        jsr     read_fsp_text_pointer
        lda     fuji_filename_buffer    ; Check if empty
        clc                             ; C=0 = OK
        rts

; add_ssd_extension - Add .SSD extension to filename
; Based on MM32 mm32_add_ssd_ext (MM32.asm line 1369-1388)
; Modifies filename in fuji_filename_buffer+16
add_ssd_extension:
        ; TODO: Find the dot in filename and append "SSD" + hash marker
        ; For now, placeholder
        rts

; change_ssd_to_dsd - Change .SSD extension to .DSD
; Based on MM32 mm32_change_ext_dsd (MM32.asm line 1469-1480)
; Modifies filename in fuji_filename_buffer+16
change_ssd_to_dsd:
        ; TODO: Find "SSD" after dot and change first 'S' to 'D'
        ; For now, placeholder
        rts

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; FujiNet Disk Operations (Device I/O - to be implemented)
; These replace MM32's FAT32 directory scanning
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

; search_fujinet_disks - Search FujiNet device for disk matching filename
; Replaces MM32 mm32_Scan_Dir (MM32.asm line 551-704)
; Entry: Filename pattern in fuji_filename_buffer
; Exit: C=0 if found, C=1 if not found
;       If found: aws_tmp08/09 = disk number
;                 pws_tmp08 = is_dir flag (0=file, non-zero=dir)
search_fujinet_disks:
        ; TODO: Implement FujiNet device call to:
        ; 1. Get list of available disk images from FujiNet
        ; 2. Match each disk name against pattern in fuji_filename_buffer
        ; 3. Return disk number in aws_tmp08/09 if found
        ; 4. Set pws_tmp08 to indicate if it's a directory
        ; For now, return C=1 (not found)
        sec
        rts
