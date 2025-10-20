; *FREE and *MAP command implementation
; Translated from MMFS CMD_FREE and CMD_MAP (lines 6419-6529)
; *FREE displays free space on disk
; *MAP displays disk usage map showing address and length of free blocks

        .export cmd_fs_free
        .export cmd_fs_map

        .import a_rorx4and3
        .import load_cur_drv_cat2
        .import param_optional_drive_no
        .import print_bcd_spl
        .import print_hex_spl
        .import print_nibble_spl
        .import print_string_spl
        .import y_sub8

        .include "fujinet.inc"

        .segment "CODE"

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; cmd_fs_free - Handle *FREE command
; Displays free space on disk: "<n> Files <sss> Sectors <bytes>"
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

cmd_fs_free:
        sec                             ; Set flag for *FREE
        bcs cmd_free_map_entry

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; cmd_fs_map - Handle *MAP command
; Displays disk usage map: "Address : Length" for each free block
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

cmd_fs_map:
        clc                             ; Clear flag for *MAP

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; cmd_free_map_entry - Common entry point for *FREE and *MAP
; Entry: Carry set for *FREE, clear for *MAP
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

cmd_free_map_entry:
        ror     pws_tmp06               ; Store flag in bit 7 of pws_tmp06 (&C6)
        jsr     param_optional_drive_no ; Get optional drive number
        jsr     load_cur_drv_cat2       ; Load catalog for current drive
        bit     pws_tmp06
        bmi     @skip_header            ; If *FREE, skip header
        jsr     print_string_spl
        .byte   "Address :  Length", $0D

@skip_header:
        ; Get disk sector count from catalog
        lda     dfs_cat_boot_option     ; 0F06 - use boot option byte as high bits
        and     #$03
        sta     pws_tmp05               ; pws_tmp05 (&C5) = disk size high byte (bits 8-9)
        sta     pws_tmp02               ; pws_tmp02 (&C2) = map address high byte
        lda     dfs_cat_sect_count      ; 0F07 - total sectors on disk
        sta     pws_tmp04               ; pws_tmp04 (&C4) = total sector count
        sec
        sbc     #$02                    ; Subtract 2 for catalog sectors
        sta     pws_tmp01               ; pws_tmp01 (&C1) = map length low byte
        bcs     @no_borrow
        dec     pws_tmp02

@no_borrow:
        lda     #$02
        sta     aws_tmp11               ; aws_tmp11 (&BB) = map address low byte (start at sector 2)
        lda     #$00                    ; Initialize counters
        sta     aws_tmp12               ; aws_tmp12 (&BC) = map address mid byte (always 0 for us)
        sta     aws_tmp15               ; aws_tmp15 (&BF) = total free low byte
        sta     pws_tmp00               ; pws_tmp00 (&C0) = total free high byte

        ; Process files to find free space
        lda     dfs_cat_num_x8          ; FilesX8
        and     #$F8
        tay
        beq     @nofiles                ; If no files, all space is free
        bne     @fileloop_entry         ; Always branch

@fileloop:
        jsr     sub_nextblock           ; Calculate next block address
        jsr     y_sub8                  ; Y -> next file (Y = Y - 8)
        lda     pws_tmp04               ; &C4
        sec
        sbc     aws_tmp11               ; &BB
        lda     pws_tmp05               ; &C5
        sbc     aws_tmp12               ; &BC
        bcc     @nofiles

@fileloop_entry:
        ; Calculate gap between current map address and file start sector
        lda     dfs_cat_sect_count,y    ; File start sector low byte
        sec
        sbc     aws_tmp11               ; &BB - Subtract map address
        sta     pws_tmp01               ; pws_tmp01 (&C1) = gap length low byte
        lda     dfs_cat_boot_option,y   ; File op byte contains high bits of sector
        and     #$03
        sbc     aws_tmp12               ; &BC
        sta     pws_tmp02               ; pws_tmp02 (&C2) = gap length high byte
        bcc     @fileloop

@nofiles:
        sty     aws_tmp13               ; &BD - Save Y offset
        bit     pws_tmp06               ; &C6
        bmi     @add_to_total           ; If *FREE, just add to total
        
        ; For *MAP, print this free block if non-zero
        lda     pws_tmp01               ; &C1
        ora     pws_tmp02               ; &C2
        beq     @add_to_total           ; If gap is 0, skip printing

        ; Print address (3 digit hex: high nibble + 2 digits)
        lda     aws_tmp12               ; &BC
        jsr     print_nibble_spl        ; Print high nibble (always 0 for us)
        lda     aws_tmp11               ; &BB
        jsr     print_hex_spl           ; Print low byte
        jsr     print_string_spl
        .byte   "     :  "
        
        ; Print length (3 digit hex)
        lda     pws_tmp02               ; &C2
        jsr     print_nibble_spl
        lda     pws_tmp01               ; &C1
        jsr     print_hex_spl
        jsr     OSNEWL

        jsr     sub_nextblock           ; Calculate next block address

@add_to_total:
        ; Add gap length to total free space
        lda     pws_tmp01               ; &C1
        clc
        adc     aws_tmp15               ; &BF
        sta     aws_tmp15
        lda     pws_tmp02               ; &C2
        adc     pws_tmp00               ; &C0
        sta     pws_tmp00
        
        ldy     aws_tmp13               ; &BD - Restore Y offset
        bne     @fileloop               ; More files to process

        ; Done processing files
        bit     pws_tmp06               ; &C6
        bpl     @done                   ; If *MAP, we're done

        ; For *FREE, print summary
        tay                             ; Y = total free high byte
        ldx     aws_tmp15               ; &BF - X = total free low byte
        lda     #$F8
        sec
        sbc     dfs_cat_num_x8          ; A = (31 * 8) - FilesX8 = space for files
        jsr     sub_freeinfo
        .byte   "Free", $0D

        lda     pws_tmp04               ; &C4 - Total disk sectors
        sec
        sbc     aws_tmp15               ; &BF - Subtract free sectors
        tax
        lda     pws_tmp05               ; &C5
        sbc     pws_tmp00               ; &C0
        tay
        lda     dfs_cat_num_x8          ; Number of files * 8
        jsr     sub_freeinfo
        .byte   "Used", 13
        nop

@done:
        rts

sub_nextblock:
        lda     dfs_cat_boot_option,y
        pha
        jsr     a_rorx4and3
        sta     aws_tmp12
        pla
        and     #$03
        clc
        adc     aws_tmp12
        sta     aws_tmp12               ; aws_tmp12 = (op & 3) + ((op >> 4) & 3)
        
        ; Add file length (in sectors)
        lda     dfs_cat_cycle,y         ; Increment the catalog cycle count
        cmp     #1                      ; Carry C=0 if whole sector
        lda     #0
        adc     dfs_cat_num_x8,y        ; ??? why indexed?
        bcc     @no_carry1
        inc     aws_tmp12

@no_carry1:
        clc
        adc     dfs_cat_sect_count,y
        sta     aws_tmp11
        bcc     @no_carry2
        inc     aws_tmp12

@no_carry2:
        rts


sub_freeinfo:
        ; Save registers, done after the printing in MMFS
        ; but doing it before in case registers are trashed
        stx     aws_tmp12               ; &BC - Save sector count low
        sty     aws_tmp13               ; &BD - Save sector count high
        
        ; Print number of files
        lsr     a                       ; Divide by 8 to get file count
        lsr     a
        lsr     a
        jsr     print_bcd_spl           ; Print as BCD
        jsr     print_string_spl
        .byte   " Files "
        
        ; Print number of sectors (3 digit hex)
        ; reload Y into A from start of function
        ; TODO: can we trust the print above NOT to trash x/y?
        lda     aws_tmp13               ; &BD

        jsr     print_nibble_spl
        lda     aws_tmp12               ; &BC
        jsr     print_hex_spl
        jsr     print_string_spl
        .byte   " Sectors "
        
        ; Convert sectors to bytes and print as decimal
        ; Sectors * 256 = bytes
        ; Store in aws_tmp11:aws_tmp12:aws_tmp13:aws_tmp14 (32-bit, &BB-&BE)
        lda     #$00
        sta     aws_tmp11               ; &BB - Low byte is always 0 (sectors * 256)
        sta     aws_tmp14               ; &BE - High byte is 0
        ldx     #$1F                    ; Shift count for 32-bit
        stx     pws_tmp01               ; &C1 - Counter
        ldx     #$09

        ; Clear decimal buffer at fuji_filename_buffer (MA+&1000 in MMFS)
@loop_1:
        sta     fuji_filename_buffer,x
        dex
        bpl     @loop_1

        ; Convert binary to decimal by repeated doubling and BCD adjust
@loop_2:
        asl     aws_tmp11               ; &BB - Shift 32-bit value left
        rol     aws_tmp12               ; &BC
        rol     aws_tmp13               ; &BD
        rol     aws_tmp14               ; &BE
        ldx     #$00
        ldy     #$09                    ; A=0

@loop_3:
        lda     fuji_filename_buffer,x
        rol     a
        cmp     #$0A
        bcc     @no_adjust
        sbc     #$0A                    ; Subtract 10 if >= 10

@no_adjust:
        sta     fuji_filename_buffer,x
        inx
        dey
        bpl     @loop_3
        dec     pws_tmp01               ; &C1
        bpl     @loop_2

        ; Print decimal string with comma separator
        ldy     #$20                    ; Space character
        ldx     #$05                    ; Start at position 5 (millions)

@loop_4:
        bne     @check_comma
        ldy     #$2C                    ; Comma character

@check_comma:
        lda     fuji_filename_buffer,x
        bne     @print_digit
        cpy     #$2C
        beq     @print_digit
        tya
        bne     @next_digit             ; Always

@print_digit:
        ldy     #$2C                    ; After first digit, use comma
        ora     #$30                    ; Convert to ASCII

@next_digit:
        jsr     OSWRCH
        cpx     #$03
        bne     @over
        tya
        jsr     OSWRCH                  ; print " ", or ","

@over:
        dex
        bpl     @loop_4
        jsr     print_string_spl
        .byte   " Bytes "
        nop
        jmp     print_string_spl
