; Disk name matching functions
; Translated from MMFS DMatchInit, DMatch, GetDiskFirstAllX, GetDiskNext
; MMFS lines: 8100 (DMatchInit), 7826 (GetDiskFirstAllX), 7868 (GetDiskNext), 8158 (DMatch)
; For FujiNet, this queries available disk images and matches by name

        .export d_match_init
        .export d_match
        .export get_disk_first_all_x
        .export get_disk_next

        .import fuji_get_disk_list_data
        .import fuji_get_disk_name_data
        .import fuji_check_disk_exists
        .import remember_axy
        .import err_bad
        .import jmp_syntax

        .include "fujinet.inc"

        .segment "CODE"

; Disk matching workspace locations
; Matching MMFS workspace usage
dm_str          = fuji_filename_buffer + $00    ; Search string (up to 12 chars, like MMFS dmStr%)
dm_len          = fuji_filename_buffer + $0D    ; Length of search string (like MMFS dmLen%)
dm_ambig        = fuji_filename_buffer + $0E    ; Ambiguous match flag (like MMFS dmAmbig%)
gd_diskno       = aws_tmp08                     ; Current disk number (16-bit, like MMFS gddiskno%)
gd_ptr          = aws_tmp12                     ; Pointer to disk name (like MMFS gdptr%)

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; d_match_init - Initialize disk name matching
; Translated from MMFS DMatchInit (line 8100)
; Entry: Text pointer positioned at disk name
; Exit: dm_len = length of search string
;       dm_ambig = 0 or '*' if wildcard
;       Search string stored at dm_str (uppercase, null-terminated)
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

d_match_init:
        ldx     #0
        stx     dm_ambig                ; dmAmbig% = 0
        
        clc
        jsr     GSINIT
        beq     dmi_exit                ; If null string
        
dmi_loop:
        jsr     GSREAD
        bcs     dmi_exit                ; End of string
        cmp     #'*'                    ; Wildcard?
        beq     dmi_star
        
        ; Convert to uppercase (MMFS lines 8116-8120)
        cmp     #$61                    ; 'a'
        bcc     dmi_ucase               ; < 'a'
        cmp     #$7B                    ; 'z'+1
        bcs     dmi_ucase               ; > 'z'
        eor     #$20                    ; Convert to uppercase
dmi_ucase:
        sta     dm_str,x                ; Store in dmStr%
        
        inx
        cpx     #12                     ; Max 12 characters (MMFS limit)
        bne     dmi_loop
        
        ; Make sure at end of string (MMFS lines 8128-8131)
dmi_end:
        jsr     GSREAD
        bcc     err_bad_string          ; If not end of string
        
dmi_exit:
        cmp     #$0D                    ; CR?
        bne     dmi_syntax              ; Syntax error if not
        
        lda     #0
        sta     dm_str,x                ; Null terminator
        stx     dm_len                  ; Store length
        rts
        
        ; Wildcard found, must be end of string
dmi_star:
        sta     dm_ambig                ; dmAmbig% = '*'
        beq     dmi_end                 ; Always (A=0 after sta)
        
err_bad_string:
        jsr     err_bad
        .byte   $FF
        .byte   "Bad string", 0
        
dmi_syntax:
        jmp     jmp_syntax

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; get_disk_first_all_x - Get first available disk
; Translated from MMFS GetDiskFirstAllX (line 7826)
; Entry: X = options (0 = don't return unformatted, $FF = return all)
; Exit: gd_diskno (aws_tmp08/09) = disk number (or $FFFF if none)
;       Carry clear if found, set if none
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

get_disk_first_all_x:
        ; Call hardware layer to get/refresh disk list
        jsr     fuji_get_disk_list_data
        
        ; Initialize disk number to 0 (MMFS lines 7829-7831)
        lda     #$00
        sta     gd_diskno               ; gddiskno% = 0
        sta     gd_diskno+1
        
        ; Fall through to gd_first

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; get_disk_next - Get next available disk
; Translated from MMFS GetDiskNext (line 7868)
; Entry: gd_diskno (aws_tmp08/09) = current disk number
; Exit: gd_diskno (aws_tmp08/09) = next disk number (or $FFFF if no more)
;       Carry clear if found, set if no more
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

get_disk_next:
        ; Increment disk number (MMFS lines 7908-7910)
        inc     gd_diskno
        bne     gd_first
        inc     gd_diskno+1
        ; Fall through to gd_first

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; gd_first - Check if current disk is valid
; Translated from MMFS gdfirst (line 7915)
; Entry: gd_diskno (aws_tmp08/09) = disk number to check
; Exit: Carry clear if valid disk found, set if no more disks
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

gd_first:
        ; Check if disk exists
        jsr     fuji_check_disk_exists
        bcc     @found                  ; C=0 means exists
        
        ; Disk doesn't exist - check if we should continue
        lda     gd_diskno+1
        cmp     #$FF
        beq     gd_fin                  ; If high byte = $FF, no more
        
        ; Try next disk
        jmp     get_disk_next
        
@found:
        ; Get disk name to check if formatted (in fuji_filename_buffer)
        jsr     fuji_get_disk_name_data
        
        ; For dummy: all disks are formatted
        ; For serial: check byte 15 like MMFS
        ; MMFS line 7917: LDA (gdptr%),Y where Y=#$F, BMI gdnextloop
        
        ; Disk found
        clc
        rts
        
gd_fin:
        ; No more disks
        lda     #$FF
        sta     gd_diskno
        sta     gd_diskno+1
        sec
        rts

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; d_match - Match disk name against search pattern
; Translated from MMFS DMatch (line 8158)
; Entry: gd_diskno (aws_tmp08/09) = disk number to check
;        dm_str = search pattern (uppercase, null-terminated)
;        dm_len = pattern length
; Exit: Carry clear if match, set if no match
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

d_match:
        ; Get disk name into fuji_filename_buffer
        jsr     fuji_get_disk_name_data
        ; gd_ptr (aws_tmp12/13) now points to disk name in buffer
        
        ; Compare (MMFS lines 8160-8179)
        ldy     #0
        ldx     dm_len
        beq     dmat_end                ; If length = 0, match
        
dmat_lp:
        lda     (gd_ptr),y              ; Get char from disk name
        beq     dmat_nomatch            ; If null, no match
        
        ; Convert to uppercase (MMFS lines 8168-8173)
        cmp     #$61                    ; 'a'
        bcc     dm_notlc
        cmp     #$7B                    ; 'z'+1
        bcs     dm_notlc
        eor     #$20                    ; Convert to uppercase
dm_notlc:
        cmp     dm_str,y                ; Compare with search string
        bne     dmat_nomatch
        
        iny
        dex
        bne     dmat_lp
        
dmat_end:
        ; Check end conditions (MMFS lines 8181-8188)
        lda     (gd_ptr),y              ; Get next char from disk name
        beq     dmat_yes                ; If null, exact match
        lda     dm_len
        cmp     #12                     ; Full 12-char match?
        beq     dmat_yes
        lda     dm_ambig                ; Wildcard set?
        beq     dmat_nomatch            ; No wildcard, no match
        
dmat_yes:
        clc                             ; Match!
        rts
        
dmat_nomatch:
        sec                             ; No match
        rts


