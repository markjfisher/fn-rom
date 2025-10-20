; *FREE and *MAP command implementation
; Translated from MMFS CMD_FREE and CMD_MAP (lines 6419-6529)
; *FREE displays free space on disk
; *MAP displays disk usage map showing address and length of free blocks

        .export cmd_fs_free
        .export cmd_fs_map

        .import param_optional_drive_no
        .import load_cur_drv_cat2
        .import print_string
        .import OSNEWL
        .import print_nibble
        .import print_hex
        .import y_sub8
        .import print_bcd
        .import OSWRCH
        .import a_rorx4and3

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
        ror     aws_tmp06               ; Store flag in bit 7 of aws_tmp06
        jsr     param_optional_drive_no ; Get optional drive number
        jsr     load_cur_drv_cat2       ; Load catalog for current drive
        bit     aws_tmp06
        bmi     @skip_header            ; If *FREE, skip header
        jsr     print_string
        .byte   "Address :  Length", 13, 0

@skip_header:
        ; Get disk sector count from catalog
        lda     dfs_cat_boot_option     ; 0F06 - use boot option byte as high bits
        and     #$03
        sta     aws_tmp05               ; aws_tmp05 = disk size high byte (bits 8-9)
        sta     aws_tmp02               ; aws_tmp02 = map address high byte
        lda     dfs_cat_sect_count      ; 0F07 - total sectors on disk
        sta     aws_tmp04               ; aws_tmp04 = total sector count
        sec
        sbc     #$02                    ; Subtract 2 for catalog sectors
        sta     aws_tmp01               ; aws_tmp01 = map length low byte
        bcs     @no_borrow
        dec     aws_tmp02

@no_borrow:
        lda     #$02
        sta     pws_tmp11               ; pws_tmp11 = map address low byte (start at sector 2)
        lda     #$00                    ; Initialize counters
        sta     pws_tmp12               ; pws_tmp12 = map address mid byte (always 0 for us)
        sta     pws_tmp15               ; pws_tmp15 = total free low byte
        sta     aws_tmp00               ; aws_tmp00 = total free high byte

        ; Process files to find free space
        lda     dfs_cat_num_x8          ; FilesX8
        and     #$F8
        tay
        beq     @nofiles                ; If no files, all space is free
        bne     @fileloop_entry         ; Always branch

@fileloop:
        jsr     sub_nextblock           ; Calculate next block address
        jsr     y_sub8                  ; Y -> next file (Y = Y - 8)
        lda     aws_tmp04
        sec
        sbc     pws_tmp11
        lda     aws_tmp05
        sbc     pws_tmp12
        bcc     @nofiles

@fileloop_entry:
        ; Calculate gap between current map address and file start sector
        lda     dfs_cat_file_sect,y     ; File start sector low byte
        sec
        sbc     pws_tmp11               ; Subtract map address
        sta     aws_tmp01               ; aws_tmp01 = gap length low byte
        lda     dfs_cat_file_op,y       ; File op byte contains high bits of sector
        and     #$03
        sbc     pws_tmp12
        sta     aws_tmp02               ; aws_tmp02 = gap length high byte
        bcc     @fileloop

@nofiles:
        sty     pws_tmp13               ; Save Y offset
        bit     aws_tmp06
        bmi     @add_to_total           ; If *FREE, just add to total
        
        ; For *MAP, print this free block if non-zero
        lda     aws_tmp01
        ora     aws_tmp02
        beq     @add_to_total           ; If gap is 0, skip printing

        ; Print address (3 digit hex: high nibble + 2 digits)
        lda     pws_tmp12
        jsr     print_nibble            ; Print high nibble (always 0 for us)
        lda     pws_tmp11
        jsr     print_hex               ; Print low byte
        jsr     print_string
        .byte   "     :  ", 0
        
        ; Print length (3 digit hex)
        lda     aws_tmp02
        jsr     print_nibble
        lda     aws_tmp01
        jsr     print_hex
        jsr     OSNEWL

        jsr     sub_nextblock           ; Calculate next block address

@add_to_total:
        ; Add gap length to total free space
        lda     aws_tmp01
        clc
        adc     pws_tmp15
        sta     pws_tmp15
        lda     aws_tmp02
        adc     aws_tmp00
        sta     aws_tmp00
        
        ldy     pws_tmp13               ; Restore Y offset
        bne     @fileloop               ; More files to process

        ; Done processing files
        bit     aws_tmp06
        bpl     @done                   ; If *MAP, we're done

        ; For *FREE, print summary
        tay                             ; Y = total free high byte
        ldx     pws_tmp15               ; X = total free low byte
        lda     #$F8
        sec
        sbc     dfs_cat_num_x8          ; A = (31 * 8) - FilesX8 = space for files
        jsr     sub_freeinfo
        .byte   "Free", 13, 0

        lda     aws_tmp04               ; Total disk sectors
        sec
        sbc     pws_tmp15               ; Subtract free sectors
        tax
        lda     aws_tmp05
        sbc     aws_tmp00
        tay
        lda     dfs_cat_num_x8          ; Number of files * 8
        jsr     sub_freeinfo
        .byte   "Used", 13, 0

@done:
        rts

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; sub_nextblock - Calculate start of next block after current file
; Entry: Y = catalog offset for file
; Exit: pws_tmp12:pws_tmp11 = address of next block
;       Modifies: A, pws_tmp11, pws_tmp12
; Translated from MMFS Sub_A8E2_nextblock (lines 6533-6558)
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

sub_nextblock:
        ; Calculate file end sector = start sector + file length
        lda     dfs_cat_file_op,y       ; Get file op byte (contains high bits of sector and size)
        pha
        jsr     a_rorx4and3             ; Extract bits 8-9 of sector and shift
        sta     pws_tmp12
        pla
        and     #$03
        clc
        adc     pws_tmp12
        sta     pws_tmp12               ; pws_tmp12 = (op & 3) + ((op >> 4) & 3)
        
        ; Add file length (in sectors)
        lda     dfs_cat_file_size,y     ; File size low byte
        cmp     #1                      ; Carry C=0 if whole sector
        lda     #0
        adc     dfs_cat_file_size+1,y   ; File size mid byte
        bcc     @no_carry1
        inc     pws_tmp12

@no_carry1:
        clc
        adc     dfs_cat_file_sect,y     ; Add start sector
        sta     pws_tmp11
        bcc     @no_carry2
        inc     pws_tmp12

@no_carry2:
        rts

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; sub_freeinfo - Print free/used info line
; Entry: A = number of files * 8
;        X = number of sectors (low byte)
;        Y = number of sectors (high byte)
;        String immediately after JSR (null terminated)
; Exit: Returns after string
; Translated from MMFS Sub_A90D_freeinfo (lines 6560-6590)
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

sub_freeinfo:
        ; Save registers
        stx     pws_tmp12               ; Save sector count low
        sty     pws_tmp13               ; Save sector count high
        
        ; Print number of files
        lsr     a                       ; Divide by 8 to get file count
        lsr     a
        lsr     a
        jsr     print_bcd               ; Print as BCD
        jsr     print_string
        .byte   " Files ", 0
        
        ; Print number of sectors (3 digit hex)
        lda     pws_tmp13
        jsr     print_nibble
        lda     pws_tmp12
        jsr     print_hex
        jsr     print_string
        .byte   " Sectors ", 0
        
        ; Convert sectors to bytes and print as decimal
        ; Sectors * 256 = bytes
        ; Store in pws_tmp11:pws_tmp12:pws_tmp13:pws_tmp14 (32-bit)
        lda     #$00
        sta     pws_tmp11               ; Low byte is always 0 (sectors * 256)
        sta     pws_tmp14               ; High byte is 0
        ldx     #$1F                    ; Shift count for 32-bit
        stx     aws_tmp01               ; Counter
        ldx     #$09

        ; Clear decimal buffer at fuji_filename_buffer
@clear_loop:
        sta     fuji_filename_buffer,x
        dex
        bpl     @clear_loop

        ; Convert binary to decimal by repeated doubling and BCD adjust
@convert_loop:
        asl     pws_tmp11               ; Shift 32-bit value left
        rol     pws_tmp12
        rol     pws_tmp13
        rol     pws_tmp14
        ldx     #$00
        ldy     #$09                    ; A=0

@bcd_loop:
        lda     fuji_filename_buffer,x
        rol     a
        cmp     #$0A
        bcc     @no_adjust
        sbc     #$0A                    ; Subtract 10 if >= 10

@no_adjust:
        sta     fuji_filename_buffer,x
        inx
        dey
        bpl     @bcd_loop
        dec     aws_tmp01
        bpl     @convert_loop

        ; Print decimal string with comma separator
        ldy     #$20                    ; Space character
        ldx     #$05                    ; Start at position 5 (millions)

@print_loop:
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
        jsr     OSWRCH

@next_digit:
        dex
        cpx     #$02
        bne     @print_loop

        ; Print last 3 digits (always, no leading space suppression)
        lda     fuji_filename_buffer+2
        ora     #$30
        jsr     OSWRCH
        lda     #$2C                    ; Comma
        jsr     OSWRCH
        lda     fuji_filename_buffer+1
        ora     #$30
        jsr     OSWRCH
        lda     fuji_filename_buffer
        ora     #$30
        jsr     OSWRCH

        ; Print the label string (passed as inline parameter)
        pla                             ; Get return address low
        sta     aws_tmp00
        pla                             ; Get return address high
        sta     aws_tmp01
        
        ; Increment return address to point to string
        inc     aws_tmp00
        bne     @print_string
        inc     aws_tmp01

@print_string:
        ldy     #$00
@string_loop:
        lda     (aws_tmp00),y
        beq     @string_done
        jsr     OSWRCH
        iny
        bne     @string_loop

@string_done:
        ; Calculate new return address (after string)
        tya
        clc
        adc     aws_tmp00
        sta     aws_tmp00
        bcc     @push_return
        inc     aws_tmp01

@push_return:
        lda     aws_tmp01
        pha
        lda     aws_tmp00
        pha
        rts

