; *INFO command implementation for FujiNet ROM
; Contains both FSCV and command table implementations

        .export fscv10_starINFO
        .export cmd_fs_info
        .export print_filename_yoffset
        .export print_info_line_yoffset


        .import print_string
        .import print_axy
        .import remember_axy
        .import print_char
        .import print_fullstop
        .import print_hex
        .import print_newline
        .import print_space
        .import fuji_read_catalog

        .include "fujinet.inc"

        .segment "CODE"

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; FSCV10_STARINFO - Handle *INFO command via FSCV
; This is called when *INFO is used on the active filing system
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

fscv10_starINFO:
.ifdef FN_DEBUG
        jsr     remember_axy
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
        
        ; Fall through to CMD_INFO implementation (no JMP needed!)

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; CMD_FS_INFO - Handle *INFO command
; This is the shared implementation called by both:
; - fscv10_starINFO (when *INFO is called on active filing system)
; - cmd_table_fujifs (when *FUJI INFO is called)
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

cmd_fs_info:
.ifdef FN_DEBUG
        jsr     remember_axy
        jsr     print_string
        .byte   "CMD_FS_INFO called", $0D
        nop
        jsr     print_axy
.endif
        
        ; Load catalog first
        jsr     fuji_read_catalog
        
        ; Parse command line for specific filename
        jsr     parse_filename_from_command_line
        
        ; If no filename specified, show all files
        lda     aws_tmp00               ; Check if filename was found
        beq     @show_all_files
        
        ; Find and show specific file
        jsr     find_file_by_name
        bcc     @file_found
        jsr     print_string
        .byte   "File not found", $0D
        nop
        rts
        
@file_found:
        ; Y now contains the offset to the file entry
        jsr     print_info_line_yoffset
        jsr     print_newline
        rts
        
@show_all_files:
        ; Show all files
        ldy     #$00                    ; Start with first file
        
@info_loop:
        cpy     FilesX8                 ; Check if we've processed all files
        bcs     @done
        
        ; Print info for this file
        jsr     print_info_line_yoffset
        
@next_file:
        ; Move to next file (8 bytes per entry)
        tya
        clc
        adc     #$08
        tay
        jmp     @info_loop
        
@done:
        jsr     print_newline
        rts

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; PRINT_INFO_LINE_YOFFSET - Print one line of file info
; Y = catalog offset for file entry
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

print_info_line_yoffset:
        jsr     remember_axy
        
        ; Print filename with directory and lock status
        jsr     print_filename_yoffset
        
        ; Save Y offset
        tya
        pha
        
        ; Print "  " (two spaces)
        jsr     print_space
        
        ; Read mixed byte (offset 106) for high bits
        lda     $0F0E,y                 ; Mixed byte (offset 106)
        pha                             ; Save for later use
        
        ; Extract load address high bits (b3-b2)
        and     #$0C                    ; Mask b3-b2
        lsr                             ; Shift to b1-b0
        lsr
        sta     aws_tmp00               ; Store load address b17-b16
        
        ; Print load address (3 bytes) - MMFS style
        lda     aws_tmp00               ; Load address b17-b16
        cmp     #$03                    ; Check if high bits = 3
        bne     @load_not_host
        lda     #$FF                    ; If high bits = 3, use FF
        jsr     print_hex
        bne     @load_skip_high_bits
@load_not_host:
        lda     aws_tmp00               ; Load address b17-b16
        jsr     print_hex
@load_skip_high_bits:
        lda     $0F09,y                 ; Load address high byte (b15-b8)
        jsr     print_hex
        lda     $0F08,y                 ; Load address low byte (b7-b0)
        jsr     print_hex
        
        ; Print space
        lda     #' '
        jsr     print_char
        
        ; Extract exec address high bits (b7-b6)
        pla                             ; Restore mixed byte
        pha                             ; Save again
        and     #$C0                    ; Mask b7-b6
        lsr                             ; Shift to b5-b4
        lsr
        lsr
        lsr
        lsr
        lsr
        sta     aws_tmp01               ; Store exec address b17-b16
        
        ; Print exec address (3 bytes) - MMFS style
        lda     aws_tmp01               ; Exec address b17-b16
        cmp     #$03                    ; Check if high bits = 3
        bne     @exec_not_host
        lda     #$FF                    ; If high bits = 3, use FF
        jsr     print_hex
        jmp     @exec_skip_high_bits
@exec_not_host:
        lda     aws_tmp01               ; Exec address b17-b16
        jsr     print_hex
@exec_skip_high_bits:
        lda     $0F0B,y                 ; Exec address high byte (b15-b8)
        jsr     print_hex
        lda     $0F0A,y                 ; Exec address low byte (b7-b0)
        jsr     print_hex
        
        ; Print space
        lda     #' '
        jsr     print_char
        
        ; Extract file length high bits (b5-b4)
        pla                             ; Restore mixed byte
        pha                             ; Save again
        and     #$30                    ; Mask b5-b4
        lsr                             ; Shift to b3-b2
        lsr
        lsr
        lsr
        sta     aws_tmp02               ; Store file length b17-b16
        
        ; Print file length (3 bytes) - MMFS style
        lda     aws_tmp02               ; File length b17-b16
        cmp     #$03                    ; Check if high bits = 3
        bne     @length_not_host
        lda     #$FF                    ; If high bits = 3, use FF
        jsr     print_hex
        jmp     @length_skip_high_bits
@length_not_host:
        lda     aws_tmp02               ; File length b17-b16
        jsr     print_hex
@length_skip_high_bits:
        lda     $0F0D,y                 ; File length high byte (b15-b8)
        jsr     print_hex
        lda     $0F0C,y                 ; File length low byte (b7-b0)
        jsr     print_hex
        
        ; Print space
        lda     #' '
        jsr     print_char
        
        ; Extract start sector high bits (b1-b0) and combine with low byte
        pla                             ; Restore mixed byte
        and     #$03                    ; Mask b1-b0 (start sector b9-b8)
        sta     aws_tmp03               ; Store start sector b9-b8
        lda     $0F0F,y                 ; Start sector b7-b0
        sta     aws_tmp04               ; Store start sector b7-b0
        
        ; Print start sector (2 bytes) - 10-bit value
        lda     aws_tmp03               ; Start sector b9-b8
        jsr     print_hex
        lda     aws_tmp04               ; Start sector b7-b0
        jsr     print_hex
        
        ; Restore Y offset
        pla
        tay
        
        ; Print newline
        jsr     print_newline
        rts

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; PARSE_FILENAME_FROM_COMMAND_LINE - Parse filename from command line
; Returns: aws_tmp00 = 0 if no filename, 1 if filename found
;          aws_tmp01-aws_tmp07 = filename (up to 7 chars)
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

parse_filename_from_command_line:
        ; For now, just return 0 (no filename)
        ; TODO: Implement proper command line parsing
        lda     #$00
        sta     aws_tmp00
        rts

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; FIND_FILE_BY_NAME - Find file by name in catalog
; Input: aws_tmp01-aws_tmp07 = filename to find
; Returns: C=1 if not found, C=0 if found (Y = file entry offset)
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

find_file_by_name:
        ; For now, just return not found
        ; TODO: Implement file name matching
        sec
        rts

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; PRINT_FILENAME_YOFFSET - Print filename with directory and lock status
; Y = catalog offset for file entry
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

print_filename_yoffset:
        jsr     remember_axy
        
        ; Y is the offset into the file details (starting at $0F08)
        ; We need to convert this to filename offset (starting at $0E08)
        ; File details start at offset 264, filename entries start at offset 8
        ; Both use the same indexing: Y=0 for file 0, Y=8 for file 1, etc.
        ; So filename offset = Y + 8
        tya
        clc
        adc     #$08                    ; Add 8 to get filename offset
        tay
        
        ; Check directory character (byte 7 of filename entry)
        lda     $0E07,y                 ; Directory byte (offset 7 within filename entry)
        pha                             ; Save for lock status check
        and     #$7F                    ; Remove lock bit
        bne     @print_dir              ; If directory != 0, print it
        
        ; No directory, print "  "
        jsr     print_space
        jsr     print_space
        bne     @print_name             ; A is ' '

@print_dir:
        ; Print directory character
        jsr     print_char
        jsr     print_fullstop
        
@print_name:
        ; Print filename (7 bytes) - Y is now at start of filename entry
        ldx     #$06                    ; 7 characters (0-6)
@name_loop:
        lda     $0E00,y                 ; Filename byte
        jsr     print_char
        iny
        dex
        bpl     @name_loop
        
        ; Print "  " (two spaces)
        jsr     print_space
        jsr     print_space
        
        ; Check lock status
        pla                             ; Restore directory byte
        bpl     @not_locked             ; If bit 7 clear, not locked
        ; File is locked, print "L"
        lda     #'L'
        jsr     print_char
        bne     @done
        
@not_locked:
        ; File not locked, print " "
        jsr     print_space
        
@done:
        ldy     #$01                    ; Restore Y to start of file entry
        rts
