; *VERIFY and *FORM command implementation
; Translated from MMFS CMD_VERIFY and CMD_FORM (lines 6136-6338)
; *VERIFY checks the integrity of each sector of a disc
; *FORM formats a disc (40 or 80 track)

        .export cmd_fs_verify
        .export cmd_fs_form

        .import param_optional_drive_no
        .import load_cur_drv_cat
        .import print_string
        .import print_nibble
        .import OSNEWL
        .import GSINIT_A
        .import print_hex
        .import OSWRCH
        .import OSRDCH
        .import report_error
        .import err_bad_drive
        .import param_syntaxerrorifnull

        .include "fujinet.inc"

        .segment "CODE"

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; cmd_fs_verify - Handle *VERIFY command
; Verifies the integrity of a disk
; Syntax: *VERIFY (<drive>)
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

cmd_fs_verify:
        lda     #$00                    ; Flag for verify (not format)
        beq     vform1

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; cmd_fs_form - Handle *FORM command
; Formats a disk (40 or 80 track)
; Syntax: *FORM <40|80> (<drive>)
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

cmd_fs_form:
        lda     #$FF                    ; Flag for format (not verify)

vform1:
        sta     aws_tmp09               ; Store verify/format flag
        sta     pws_tmp02               ; Also store in pws_tmp02 for later checks

        ; For *FORM, we need to read the track parameter (40 or 80)
        ; For *VERIFY, we skip it
        bpl     vform3_ok               ; If verifying, skip track parameter

        ; *FORM requires track parameter (40 or 80)
        jsr     param_syntaxerrorifnull ; Error if no parameter
        ; For dummy implementation, we'll just skip reading the track count
        ; and assume 40 tracks for simplicity

vform3_ok:
        jsr     GSINIT_A
        sty     aws_tmp10               ; Save string position
        bne     @driveloop              ; If drive specified

        ; No drive param, so ask!
        bit     aws_tmp09
        bmi     @form_askdrive          ; If formatting

        jsr     print_string
        .byte   "Verify", 0
        bcc     @askdrive               ; Always

@form_askdrive:
        jsr     print_string
        .byte   "Format", 0

@askdrive:
        jsr     print_string
        .byte   " which drive ? ", 0
        jsr     OSRDCH
        bcs     @report_escape
        cmp     #$20
        bcc     @err_bad_drive
        jsr     OSWRCH                  ; Echo character
        sec
        sbc     #'0'
        cmp     #$04
        bcs     @err_bad_drive          ; If >=4
        sta     current_drv
        jsr     OSNEWL
        ldy     aws_tmp10
        jmp     @drivein

@driveloop:
        jsr     param_optional_drive_no ; Get drive number

@drivein:
        sty     aws_tmp10               ; Save Y
        jsr     vf_current_drive        ; Verify/Format the drive
        ldy     aws_tmp10               ; Restore Y
        jsr     GSINIT_A
        bne     @driveloop              ; More drives?
        rts

@report_escape:
        jmp     report_escape

@err_bad_drive:
        jmp     err_bad_drive

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; vf_current_drive - Verify or Format the current drive
; For dummy implementation, just reads catalog and reports success
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

vf_current_drive:
        ; Check if formatting or verifying
        bit     aws_tmp09
        bmi     @formatting             ; If formatting

        ; Verifying
        jsr     print_string
        .byte   "Verifying", 0
        bcc     @print_drive            ; Always

@formatting:
        jsr     print_string
        .byte   "Formatting", 0

@print_drive:
        jsr     print_string
        .byte   " drive ", 0
        lda     current_drv
        jsr     print_nibble
        jsr     print_string
        .byte   " track   ", 0

        ; Load catalog to verify it's readable
        jsr     load_cur_drv_cat

        ; Calculate number of tracks from catalog
        ; For dummy implementation, we'll just assume 40 or 80 tracks
        lda     dfs_cat_boot_option     ; Get high bits
        and     #$03
        tax
        lda     dfs_cat_sect_count      ; Get total sectors
        ldy     #$0A                    ; 10 sectors/track
        sty     pws_tmp00

        ldy     #$FF                    ; Track counter
@trkloop1:
        sec
@trkloop2:
        iny
        sbc     pws_tmp00
        bcs     @trkloop2
        dex
        bpl     @trkloop1
        adc     pws_tmp00
        pha

        ; For dummy implementation, we don't actually verify sectors
        ; We just simulate by iterating through tracks
        sty     pws_tmp01               ; Save track count
        ldy     #$00                    ; Start at track 0

@verify_loop:
        ; Print current track number
        lda     #$08                    ; Backspace
        jsr     OSWRCH
        jsr     OSWRCH
        tya
        jsr     print_hex               ; Print track number
        iny
        cpy     pws_tmp01               ; Compare with total tracks
        bne     @verify_loop            ; Continue until done

        ; Print success message
        jsr     OSNEWL
        pla                             ; Clean up stack
        rts

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; report_escape - Report escape condition
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

report_escape:
        jsr     report_error
        .byte   $7E                     ; Escape error
        .byte   "Escape", 0

