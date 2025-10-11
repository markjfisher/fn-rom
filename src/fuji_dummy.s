; FujiNet dummy interface implementation
; Uses static data in memory for testing high-level file system functions
; This implements the data layer functions called by fuji_fs.s
; Only compiled when DUMMY interface is selected

; Only compile this file if DUMMY interface is selected
.ifdef FUJINET_INTERFACE_DUMMY

        .export fuji_read_block_data
        .export fuji_write_block_data
        .export fuji_read_catalog_data
        .export fuji_write_catalog_data
        .export fuji_read_disc_title_data
        .export fuji_read_catalog

        .export dummy_catalogue
        .export dummy_sector2_data
        .export dummy_sector3_data
        .export dummy_sector4_data

        .import print_string
        .import remember_axy

        .include "fujinet.inc"

        .segment "CODE"

FUJI_ROM_SLOT = 14

; Static test data - a simple BBC Micro disc image
dummy_disc_title:
        .byte "TESTDISC", 0

; Dummy catalogue data (512 bytes = 2 sectors of 256 bytes each)
; This simulates a BBC Micro disc catalogue following DFS format
; Sector 0: Catalog header + file names
; Sector 1: Catalog info + file details
dummy_catalogue:
        ; SECTOR 0 (bytes 0-255)
        ; Catalog header entry 0 (bytes 0-7): Disk title first 8 bytes
        .byte "TESTDISC"

        ; File entry 1 (bytes 8-15): Filename + directory
        .byte "HELLO  ", $24  ; Filename (7 bytes) + directory "$" (unlocked)

        ; File entry 2 (bytes 16-23): Filename + directory
        .byte "WORLD  ", $A4  ; Filename (7 bytes) + directory "$" (locked - high bit set)

        ; File entry 3 (bytes 24-31): Filename + directory
        .byte "TEST   ", $24  ; Filename (7 bytes) + directory "$" (unlocked)

        ; Fill rest of sector 0 with zeros
        .res 256 - (* - dummy_catalogue), $00

        ; SECTOR 1 (bytes 256-511)
        ; Catalog header entry 0 (bytes 256-263): Disk title last 4 bytes + cycle + count + options
        .byte "    "     ; Last 4 bytes of disk title (padded with spaces)
        .byte $F0        ; Cycle number (byte 260)
        .byte $18        ; (Number of catalog entries)*8 = 3*8 = 24 = $18
        .byte $00        ; Boot option (byte 262)
        .byte $00        ; Disk size low byte (byte 263)

        ; File entry 1 (bytes 264-271): HELLO - File details
        .byte $00, $19   ; Load address (bytes 264-265) = $1900
        .byte <(hello_app_start - dummy_sector4_data + $1900), >(hello_app_start - dummy_sector4_data + $1900)  ; Exec address
        .byte <(dummy_sector4_data_end - dummy_sector4_data), >(dummy_sector4_data_end - dummy_sector4_data)  ; File length
        .byte $00        ; Mixed byte (byte 270) - all high bits = 0
        .byte $04        ; Start sector (byte 271) = sector 4

        ; File entry 2 (bytes 272-279): WORLD - File details  
        .byte $00, $1B   ; Load address = $1B00
        .byte <(world_app_start - dummy_sector3_data + $1B00), >(world_app_start - dummy_sector3_data + $1B00)  ; Exec address
        .byte <(dummy_sector3_data_end - dummy_sector3_data), >(dummy_sector3_data_end - dummy_sector3_data)  ; File length
        .byte $00        ; Mixed byte - all high bits = 0
        .byte $03        ; Start sector = sector 3

        ; File entry 3 (bytes 280-287): TEST - File details
        .byte $00, $1D   ; Load address = $1D00
        .byte <(test_app_start - dummy_sector2_data + $1D00), >(test_app_start - dummy_sector2_data + $1D00)  ; Exec address
        .byte <(dummy_sector2_data_end - dummy_sector2_data), >(dummy_sector2_data_end - dummy_sector2_data)  ; File length
        .byte $00        ; Mixed byte - all high bits = 0
        .byte $02        ; Start sector = sector 2

        ; Fill rest of sector 1 with zeros
        .res 512 - (* - dummy_catalogue), $00

; Dummy file data - 3 sectors of 256 bytes each
; These contain actual executable BBC Micro code that can be loaded and run

; Sector 2: TEST file
dummy_sector2_data:
        ; ERROR: This should not print if run address is used correctly
        ; Save current ROM and switch to FujiNet ROM (slot 5)
        lda     paged_ram_copy          ; Save current ROMSEL
        pha
        lda     #FUJI_ROM_SLOT          ; FujiNet ROM slot
        sta     paged_ram_copy          ; Update RAM copy
        sta     ROMSEL                  ; Update hardware register
        
        jsr     print_string
        .byte   "ERROR: Running at load address!", $0D
        nop
        
        ; Restore original ROM
        pla
        sta     paged_ram_copy          ; Restore RAM copy
        sta     ROMSEL                  ; Restore hardware register
        rts
        
        ; Real application starts here (execute address)
test_app_start:
        ; Save current ROM and switch to FujiNet ROM (slot 5)
        lda     paged_ram_copy          ; Save current ROMSEL
        pha
        lda     #FUJI_ROM_SLOT          ; FujiNet ROM slot
        sta     paged_ram_copy          ; Update RAM copy
        sta     ROMSEL                  ; Update hardware register
        
        jsr     print_string
        .byte   "TEST app running!", $0D
        nop
        
        ; Restore original ROM
        pla
        sta     paged_ram_copy          ; Restore RAM copy
        sta     ROMSEL                  ; Restore hardware register
        rts
dummy_sector2_data_end:
        .res 256 - (* - dummy_sector2_data), $00  ; Fill rest with zeros

; Sector 3: WORLD file
dummy_sector3_data:
        ; ERROR: This should not print if run address is used correctly
        ; Save current ROM and switch to FujiNet ROM (slot 5)
        lda     paged_ram_copy          ; Save current ROMSEL
        pha
        lda     #FUJI_ROM_SLOT          ; FujiNet ROM slot
        sta     paged_ram_copy          ; Update RAM copy
        sta     ROMSEL                  ; Update hardware register
        
        jsr     print_string
        .byte   "ERROR: Running at load address!", $0D
        nop
        
        ; Restore original ROM
        pla
        sta     paged_ram_copy          ; Restore RAM copy
        sta     ROMSEL                  ; Restore hardware register
        rts
        
        ; Real application starts here (execute address)
world_app_start:
        ; Save current ROM and switch to FujiNet ROM (slot 5)
        lda     paged_ram_copy          ; Save current ROMSEL
        pha
        lda     #FUJI_ROM_SLOT          ; FujiNet ROM slot
        sta     paged_ram_copy          ; Update RAM copy
        sta     ROMSEL                  ; Update hardware register
        
        jsr     print_string
        .byte   "WORLD application loaded!", $0D
        nop
        jsr     print_string
        .byte   "This is a longer program", $0D
        nop
        
        ; Restore original ROM
        pla
        sta     paged_ram_copy          ; Restore RAM copy
        sta     ROMSEL                  ; Restore hardware register
        rts
dummy_sector3_data_end:
        .res 256 - (* - dummy_sector3_data), $00  ; Fill rest with zeros

; Sector 4: HELLO file
dummy_sector4_data:
        ; ERROR: This should not print if run address is used correctly
        ; Save current ROM and switch to FujiNet ROM (slot 5)
        lda     paged_ram_copy          ; Save current ROMSEL
        pha
        lda     #FUJI_ROM_SLOT          ; FujiNet ROM slot
        sta     paged_ram_copy          ; Update RAM copy
        sta     ROMSEL                  ; Update hardware register
        
        jsr     print_string
        .byte   "ERROR: Running at load address!", $0D
        nop
        
        ; Restore original ROM
        pla
        sta     paged_ram_copy          ; Restore RAM copy
        sta     ROMSEL                  ; Restore hardware register
        rts
        
        ; Real application starts here (execute address)
hello_app_start:
        ; Save current ROM and switch to FujiNet ROM (slot 5)
        lda     paged_ram_copy          ; Save current ROMSEL
        pha
        lda     #FUJI_ROM_SLOT          ; FujiNet ROM slot
        sta     paged_ram_copy          ; Update RAM copy
        sta     ROMSEL                  ; Update hardware register
        
        jsr     print_string
        .byte   "HELLO from FujiNet!", $0D
        nop
        jsr     print_string
        .byte   "File loaded OK", $0D
        nop
        
        ; Restore original ROM
        pla
        sta     paged_ram_copy          ; Restore RAM copy
        sta     ROMSEL                  ; Restore hardware register
        rts
dummy_sector4_data_end:
        .res 256 - (* - dummy_sector4_data), $00  ; Fill rest with zeros

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; FUJI_READ_BLOCK_DATA - Read data block from dummy interface
; Input: data_ptr points to buffer, other parameters in workspace
; Output: Data read into buffer, Carry=0 if success, Carry=1 if error
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

fuji_read_block_data:
        jsr     remember_axy

        ; For dummy interface, read from our sector data
        ; In a real implementation, this would read from network

        ; Calculate which sector to read based on file offset
        ; fuji_file_offset contains the start sector number (not byte offset)
        ; For dummy interface, we'll use this directly as sector number
        
        lda     fuji_file_offset         ; Get start sector number
        sta     fuji_current_sector      ; Store sector number
        
        ; For dummy, we have sectors 2, 3, 4 with test data
        ; Map them to our dummy data
        cmp     #2
        beq     @read_sector2
        cmp     #3
        beq     @read_sector3
        cmp     #4
        beq     @read_sector4
        
        ; Unknown sector, return error
        lda     #0
        rts
        
@read_sector2:
        lda     #<dummy_sector2_data
        sta     aws_tmp12                ; Use zero-page variable for indirect addressing
        lda     #>dummy_sector2_data
        sta     aws_tmp13                ; Use zero-page variable for indirect addressing
        jmp     @copy_sector_data
        
@read_sector3:
        lda     #<dummy_sector3_data
        sta     aws_tmp12                ; Use zero-page variable for indirect addressing
        lda     #>dummy_sector3_data
        sta     aws_tmp13                ; Use zero-page variable for indirect addressing
        jmp     @copy_sector_data
        
@read_sector4:
        lda     #<dummy_sector4_data
        sta     aws_tmp12                ; Use zero-page variable for indirect addressing
        lda     #>dummy_sector4_data
        sta     aws_tmp13                ; Use zero-page variable for indirect addressing
        jmp     @copy_sector_data
        
@copy_sector_data:
        ; Copy data from sector to buffer
        ; Use block size from fuji_block_size
        lda     fuji_block_size
        sta     aws_tmp14                ; Use temporary workspace variable
        lda     fuji_block_size+1
        sta     aws_tmp15                ; Use temporary workspace variable
        
        ldy     #0
@copy_loop:
        lda     (aws_tmp12),y            ; Use zero-page variable for indirect addressing
        sta     (data_ptr),y
        iny
        cpy     aws_tmp14                ; Compare with temporary variable
        bne     @copy_loop
        
        ; Check if we need to copy more bytes (high byte)
        lda     aws_tmp15                ; Use temporary workspace variable
        beq     @copy_done
        
        ; Copy remaining bytes (simplified - just copy 256 bytes max)
        ldy     #0
@copy_loop2:
        lda     (aws_tmp12),y            ; Use zero-page variable for indirect addressing
        sta     (data_ptr),y
        iny
        bne     @copy_loop2
        
@copy_done:
        lda     #1                       ; Success
        rts

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; FUJI_WRITE_BLOCK_DATA - Write data block to dummy interface
; Input: data_ptr points to buffer, other parameters in workspace
; Output: Carry=0 if success, Carry=1 if error
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

fuji_write_block_data:
        jsr     remember_axy

        ; For dummy interface, we'll just acknowledge the write
        ; In a real implementation, this would send data to network

        ; Calculate which sector to write based on file offset
        ; fuji_file_offset contains the start sector number (not byte offset)
        lda     fuji_file_offset         ; Get start sector number
        sta     fuji_current_sector      ; Store sector number
        
        ; For dummy, we have sectors 2, 3, 4 with test data
        ; In a real implementation, we would write to the appropriate sector
        cmp     #2
        beq     @write_sector2
        cmp     #3
        beq     @write_sector3
        cmp     #4
        beq     @write_sector4
        
        ; Unknown sector, return error
        lda     #0
        rts
        
@write_sector2:
@write_sector3:
@write_sector4:
        ; For dummy implementation, just acknowledge the write
        ; In a real implementation, we would:
        ; 1. Copy data from buffer to sector
        ; 2. Send network command to update the file
        ; 3. Handle network response
        
        lda     #1                       ; Success
        rts

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; FUJI_READ_CATALOG_DATA - Read catalog from dummy interface
; Input: data_ptr points to 512-byte catalogue buffer
; Output: Catalogue data in buffer, Carry=0 if success, Carry=1 if error
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

fuji_read_catalog_data:
        jsr     remember_axy

        ; Copy dummy catalogue data to buffer (512 bytes)
        ldy     #0
@copy_loop:
        lda     dummy_catalogue,y
        sta     (data_ptr),y
        iny
        bne     @copy_loop    ; Copy first 256 bytes

        ; Increment high byte of data_ptr
        inc     data_ptr+1

        ; Copy second 256 bytes
        ldy     #0
@copy_loop2:
        lda     dummy_catalogue+256,y
        sta     (data_ptr),y
        iny
        bne     @copy_loop2   ; Copy second 256 bytes

        ; Restore data_ptr
        dec     data_ptr+1

        clc
        rts

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; FUJI_WRITE_CATALOG_DATA - Write catalog to dummy interface
; Input: data_ptr points to 512-byte catalogue buffer
; Output: Carry=0 if success, Carry=1 if error
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

fuji_write_catalog_data:
        jsr     remember_axy

        ; For dummy interface, we'll just acknowledge the write
        ; In a real implementation, this would send catalogue to network

        ; Simple test: just return success
        clc
        rts

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; FUJI_READ_DISC_TITLE_DATA - Read disc title from dummy interface
; Input: data_ptr points to 16-byte title buffer
; Output: Title data in buffer, Carry=0 if success, Carry=1 if error
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

fuji_read_disc_title_data:
        jsr     remember_axy

        ; Copy dummy disc title to buffer
        ldy     #0
@copy_loop:
        lda     dummy_disc_title,y
        beq     @done     ; Stop at null terminator
        sta     (data_ptr),y
        iny
        cpy     #16       ; Max 16 bytes
        bne     @copy_loop

@done:
        clc
        rts

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; FUJI_READ_CATALOG - Read catalog and store in BBC catalog area
; This is a high-level function that loads catalog into $0E00-$0FFF
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

fuji_read_catalog:
        jsr     remember_axy

        ; Set data_ptr to point to BBC catalog area ($0E00)
        lda     #<$0E00
        sta     data_ptr
        lda     #>$0E00
        sta     data_ptr+1

        ; Call the low-level catalog read function
        jsr     fuji_read_catalog_data

        ; The cycle number and boot option are already in the catalog data
        ; at $0F04 and $0F06, so we don't need to copy them anywhere

        clc
        rts

.endif  ; FUJINET_INTERFACE_DUMMY
