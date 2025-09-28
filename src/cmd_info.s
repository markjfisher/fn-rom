; *INFO command implementation for FujiNet ROM
; Contains both FSCV and command table implementations

        .export fscv10_starINFO
        .export cmd_fs_info
        ; .export print_filename_yoffset
        ; .export print_info_line_yoffset


        .import fuji_read_catalog
        .import print_2_spaces_spl
        .import print_axy
        .import print_char
        .import print_fullstop
        .import print_hex
        .import print_space_spl
        .import print_string
        .import remember_axy

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

        ; Set up text pointer and command index (following MMFS pattern)
        ; TODO: Implement SetTextPointerYX equivalent
        ; For now, just set up the command index
        lda     #$01                    ; INFO command index in cmd_table_fujifs
        sta     aws_tmp00               ; Store command index for CMD_INFO

        ; Fall through

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
        rts

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; MMFS TRANSLATION FUNCTIONS
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

; parameter_afsp_Param_SyntaxErrorIfNull_getcatentry_fspTxtP
; Direct translation of MMFS line 620-630
parameter_afsp_param_syntaxerrorifnull_getcatentry_fsptxtp:
        jsr     parameter_afsp
        jsr     param_syntaxerrorifnull
        jsr     read_fsptextpointer
        bmi     getcatentry             ; always
        rts

getcatentry:
        jsr     get_cat_firstentry80
        rts

; get_cat_firstentry80 (MMFS line 672-676)
get_cat_firstentry80:
        jsr     checkcurdrvcat          ; Get cat entry
        ldx     #$00                    ; now first byte @ &1000+X
        beq     getcatentry2            ; always

; get_cat_nextentry (MMFS line 678-680)
get_cat_nextentry:
        ldx     #$00                    ; Entry: wrd &B6 -> first entry
        beq     getcatsetupb7           ; always

getcatentry2:
        lda     #$00                    ; word &B6 = &E00 = PTR
        sta     aws_tmp02               ; &B6 -> aws_tmp02
getcatsetupb7:
        lda     #$0E                    ; string at &E00+A
        sta     aws_tmp03               ; &B7 -> aws_tmp03
getcatloop2:
        ldy     #$00
        lda     aws_tmp02               ; &B6
        cmp     FilesX8                 ; ( MA+&F05) number of files *8
        bcs     matfn_exitc0            ; If >FilesX8 Exit with C=0
        adc     #$08
        sta     aws_tmp02               ; word &B6 += 8
        jsr     matchfilename
        bcc     getcatloop2             ; not a match, try next file
        lda     DirectoryParam
        ldy     #$07
        jsr     matchchr
        bne     getcatloop2             ; If directory doesn't match
        ldy     aws_tmp02               ; &B6
        sec                             ; Return, Y=offset-8, C=1
        jmp     y_sub8

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

; MatchFilename (MMFS line 728-756)
matchfilename:
        jsr     remember_axy            ; Match filename at &1000+X
matfn_loop1:
        lda     $1000,x                 ; with that at (&B6)
        cmp     $10CE                   ; wildcard character
        bne     matfn_nomatch           ; e.g. If="*"
        inx
matfn_loop2:
        jsr     matchfilename
        bcs     matfn_exit              ; If match then exit with C=1
        iny
        cpy     #$07
        bcc     matfn_loop2             ; If Y<7
matfn_loop3:
        lda     $1000,x                 ; Check next char is a space!
        cmp     #$20
        bne     matfn_exitc0            ; If exit with c=0 (no match)
        rts                             ; exit with C=1

matfn_nomatch:
        cpy     #$07
        bcs     matfn_loop3             ; If Y>=7
        jsr     matchchr
        bne     matfn_exitc0
        inx
        iny
        bne     matfn_loop1             ; next chr

matfn_exitc0:
        clc                             ; exit with C=0
matfn_exit:
        rts

; MatchChr (MMFS line 762-776)
matchchr:
        cmp     $10CE                   ; wildcard character
        beq     matchr_exit             ; eg. If "*"
        cmp     $10CD                   ; wildcard character
        beq     matchr_exit             ; eg. If "#"
        jsr     isalphachar
        eor     (aws_tmp02),y           ; (&B6),Y
        bcs     matchr_notalpha         ; IF not alpha char
        and     #$5F
matchr_notalpha:
        and     #$7F
matchr_exit:
        rts                             ; If n=1 then matched

; IsAlphaChar (MMFS line 808-821)
isalphachar:
        pha
        and     #$5F                    ; Uppercase
        cmp     #$41
        bcc     isalpha1                ; If <"A"
        cmp     #$5B
        bcc     isalpha2                ; If <="Z"
isalpha1:
        sec
isalpha2:
        pla
        rts

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
        jsr     printhex3byte           ; Load address
        jsr     printhex3byte           ; Exec address
        jsr     printhex3byte           ; Length
        pla
        tay
        lda     $0F0E,y                 ; First sector high bits
        and     #$03
        jsr     printnibble
        lda     $0F0F,y                 ; First sector low byte
        jsr     print_hex
        jmp     printnewline

; PrintHex3Byte (MMFS line 857-868)
printhex3byte:
        ldx     #$03                    ; eg print "123456 "
printhex3byte_loop:
        lda     $1062,y
        jsr     print_hex
        dey
        dex
        bne     printhex3byte_loop
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
readfileattribs_clearloop:
        dey
        sta     (aws_tmp00),y           ; (&B0),Y
        cpy     #$02
        bne     readfileattribs_clearloop
readfileattribs_copyloop:
        jsr     readfileattribs_copy2bytes ; copy low bytes of
        iny                             ; load/exec/length
        iny
        cpy     #$0E
        bne     readfileattribs_copyloop
        pla
        tax
        lda     $0E0F,x
        bpl     readfileattribs_notlocked ; If not locked
        lda     #$08
        sta     (aws_tmp00),y           ; pwsp+&E=8
readfileattribs_notlocked:
        lda     $0F0E,x                 ; mixed byte
        ldy     #$04                    ; load address high bytes
        jsr     readfileattribs_addrhbytes
        ldy     #$0C                    ; file length high bytes
        lsr
        lsr
        pha
        and     #$03
        sta     (aws_tmp00),y
        pla
        ldy     #$08                    ; exec address high bytes
readfileattribs_addrhbytes:
        lsr
        lsr                             ; /4
        pha
        and     #$03
        cmp     #$03                    ; done slightly diff. to 8271
        bne     readfileattribs_nothost
        lda     #$FF
        sta     (aws_tmp00),y
        iny
readfileattribs_nothost:
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

; Helper functions needed by MMFS translation
parameter_afsp:
        ; TODO: Implement parameter parsing
        rts

param_syntaxerrorifnull:
        ; TODO: Implement syntax error checking
        rts

read_fsptextpointer:
        ; TODO: Implement text pointer reading
        lda     #$FF                    ; Set negative flag
        rts

checkcurdrvcat:
        ; TODO: Implement current drive catalog check
        rts


y_add7:
        ; Add 7 to Y
        tya
        clc
        adc     #$07
        tay
        rts

printnibble:
        ; Print single hex nibble
        and     #$0F
        cmp     #$0A
        bcc     @digit
        adc     #$06
@digit:
        adc     #$30
        jsr     print_char
        rts

printnewline:
        ; Print newline
        lda     #$0D
        jsr     print_char
        rts

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; MISSING FUNCTIONS NEEDED BY MMFS TRANSLATION
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

; prt_filename_yoffset - Print filename with directory and lock status
; Direct translation of MMFS prt_filename_Yoffset (lines 551-580)
prt_filename_yoffset:
        jsr     remember_axy
        lda     $0E0F,y                 ; Directory byte
        php                             ; Save flags (including lock bit)
        and     #$7F                    ; Remove lock bit, keep directory
        bne     @prt_filename_prtchr    ; If directory != 0, print it
        jsr     print_2_spaces_spl           ; Print "  " (two spaces)
        beq     @prt_filename_nodir     ; always
@prt_filename_prtchr:
        jsr     print_char              ; Print directory character
        jsr     print_fullstop          ; Print "."
@prt_filename_nodir:
        ldx     #$06                    ; Print filename (7 characters)
@prt_filename_loop:
        lda     $0E08,y                 ; Filename byte
        and     #$7F                    ; Remove high bit
        jsr     print_char
        iny
        dex
        bpl     @prt_filename_loop
        jsr     print_2_spaces_spl           ; Print "  " (two spaces)
        lda     #' '                    ; Default to space
        plp                             ; Restore flags
        bpl     @prt_filename_notlocked ; If not locked, print space
        lda     #'L'                    ; If locked, print "L"
@prt_filename_notlocked:
        jsr     print_char              ; Print "L" or " "
        ldy     #$01                    ; Restore Y to start of file entry
        rts
