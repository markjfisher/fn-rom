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

        .export hello_app_start
        .export world_app_start
        .export test_app_start

        .export assign_ram_sectors_to_new_files
        .export fuji_init_ram_filesystem
        
        ; Export debug labels for tracing
        .export assign_check_file
        .export assign_next_file 
        .export assign_done

        .import print_string
        .import print_hex
        .import print_newline
        .import remember_axy
.ifdef FN_DEBUG
        .import print_axy
.endif

        .include "fujinet.inc"

        .segment "CODE"

FUJI_ROM_SLOT = 14

RAM_FS_START = $5000

; Simple page-based RAM filesystem
RAM_CATALOG_START = RAM_FS_START                ; Catalog (512 bytes)
RAM_PAGE_ALLOC    = RAM_FS_START + $200         ; Page allocation table (32 bytes)  
RAM_PAGE_LENGTH   = RAM_FS_START + $220         ; Page length table (32 bytes)
RAM_PAGES_START   = RAM_FS_START + $240         ; File pages start
MAX_PAGES         = 32                          ; Maximum pages
PAGE_SIZE         = 256                         ; Bytes per page
FIRST_RAM_SECTOR  = 10                          ; Sectors 10+ are RAM pages

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

; .ifdef FN_DEBUG
;         pha
;         jsr     print_string
;         .byte   "fuji_read_block_data: sector="
;         nop
;         lda     fuji_file_offset
;         jsr     print_hex
;         jsr     print_string
;         .byte   " data_ptr=$"
;         nop
;         lda     data_ptr+1
;         jsr     print_hex
;         lda     data_ptr
;         jsr     print_hex
;         jsr     print_string
;         .byte   " size="
;         nop
;         lda     fuji_block_size+1
;         jsr     print_hex
;         lda     fuji_block_size
;         jsr     print_hex
;         jsr     print_newline
;         pla
; .endif

        ; For dummy interface, read from our sector data
        ; In a real implementation, this would read from network

        ; Simple sector to page mapping
        lda     fuji_file_offset         ; Get sector number
        cmp     #FIRST_RAM_SECTOR       ; Is it a RAM sector (10+)?
        bcs     @read_ram_page          ; Yes, read from RAM page
        
        ; ROM files: sectors 2, 3, 4 with test data
        cmp     #2
        beq     @read_sector2
        cmp     #3
        beq     @read_sector3
        cmp     #4
        beq     @read_sector4
        
        ; Unknown ROM sector, return error
        lda     #0
        rts

@read_ram_page:
        ; Convert sector to page: page = sector - FIRST_RAM_SECTOR  
        sec
        sbc     #FIRST_RAM_SECTOR       ; A = page number (0, 1, 2...)
        
        ; Calculate page address: RAM_PAGES_START + (page * 256)
        clc
        adc     #>RAM_PAGES_START       ; Add page number to high byte
        sta     aws_tmp13               ; High byte of page address
        lda     #<RAM_PAGES_START       ; Low byte
        sta     aws_tmp12
        jmp     @copy_sector_data
        
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

        lda     fuji_file_offset         ; Get sector number
        cmp     #FIRST_RAM_SECTOR       ; Is it a RAM sector (10+)?
        bcs     @write_ram_page         ; Yes, write to RAM page
        
        ; ROM sectors: cannot write to ROM, return error
        lda     #0
        rts
        
@write_ram_page:
        ; Convert sector to page: page = sector - FIRST_RAM_SECTOR
        sec
        sbc     #FIRST_RAM_SECTOR       ; A = page number (0, 1, 2...)
        
        ; Calculate page address: RAM_PAGES_START + (page * 256)
        clc
        adc     #>RAM_PAGES_START       ; Add page number to high byte
        sta     aws_tmp13               ; High byte of page address
        lda     #<RAM_PAGES_START       ; Low byte
        sta     aws_tmp12
        
        ; Copy data to page (simple 256 byte copy)
        ldy     #0
@write_loop:
        lda     (data_ptr),y            ; Read from buffer
        sta     (aws_tmp12),y           ; Write to page
        iny
        bne     @write_loop             ; Copy full page
        
        ; dbg_string_axy "WROTE to sector: "
        lda     #1                      ; Success
        rts

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; FUJI_READ_CATALOG_DATA - Read catalog from dummy interface
; Input: data_ptr points to 512-byte catalogue buffer
; Output: Catalogue data in buffer, Carry=0 if success, Carry=1 if error
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

fuji_read_catalog_data:
        jsr     remember_axy

.ifdef FN_DEBUG
        jsr     print_string
        .byte   "fuji_read_catalog_data: called"
        nop
        jsr     print_newline
.endif

        ; Copy RAM catalogue data to buffer (512 bytes) - includes created files
        ldy     #0
@copy_loop:
        lda     RAM_CATALOG_START,y     ; Read from RAM catalog, not ROM
        sta     (data_ptr),y
        iny
        bne     @copy_loop    ; Copy first 256 bytes

        ; Increment high byte of data_ptr
        inc     data_ptr+1

        ; Copy second 256 bytes
        ldy     #0
@copy_loop2:
        lda     RAM_CATALOG_START+256,y ; Read from RAM catalog, not ROM
        sta     (data_ptr),y
        iny
        bne     @copy_loop2   ; Copy second 256 bytes

        ; Restore data_ptr
        dec     data_ptr+1

.ifdef FN_DEBUG
        jsr     print_string
        .byte   "fuji_read_catalog_data: completed, returning 512 bytes"
        nop
        jsr     print_newline
.endif
        clc
        rts

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; FUJI_WRITE_CATALOG_DATA - Write catalog to dummy interface
; Input: data_ptr points to 512-byte catalogue buffer
; Output: Carry=0 if success, Carry=1 if error
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

fuji_write_catalog_data:
.ifdef FN_DEBUG_CREATE_FILE
        ; Mark catalog sync start
        lda     #$BB
        sta     $6FF3               ; Debug marker - RAM sync start
.endif
        jsr     remember_axy

        ; Simple catalog sync - just copy system catalog to RAM
        ; No complex translation needed with page-based approach
        
        ; Copy catalog sector 0
        ldy     #0
@copy_s0:
        lda     dfs_cat_s0_header,y
        sta     RAM_CATALOG_START,y
        iny
        bne     @copy_s0
        
        ; Copy catalog sector 1  
        ldy     #0
@copy_s1:
        lda     dfs_cat_s1_header,y
        sta     RAM_CATALOG_START+256,y
        iny
        bne     @copy_s1
        
        ; Update any new files to use fake RAM sectors (10+)
        ; This is where we assign fake sectors to new files
        jsr     assign_ram_sectors_to_new_files
        
        ; dbg_string_axy "Catalog synced: "

        clc
        rts

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; assign_ram_sectors_to_new_files - Assign fake sectors to new files
; Simple approach: any file with sector >= 4 gets fake sector 10+
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

assign_ram_sectors_to_new_files:
        ; Process files starting from file 3 (offset 24) - this includes TFILE 
        ldy     #24                     ; Start at offset 24 (file 3)
        
assign_check_file:
@check_file:
        cpy     dfs_cat_num_x8          ; Past end of files?
        bcs     assign_done             ; Yes, done
        
        ; Check if this file has incomplete data (load address = 0)
        ; This indicates a file created by OSFILE but not yet processed
        tya
        sta     aws_tmp14               ; Save file offset
        clc
        adc     #0                      ; Load address offset in sector 1
        tax
        
        lda     RAM_CATALOG_START+256,x ; Get load address low
        sta     aws_tmp12               ; Save for later
        inx
        lda     RAM_CATALOG_START+256,x ; Get load address high
        ora     aws_tmp12               ; Check if both bytes are zero
        bne     assign_next_file        ; Not zero, file already has data
        
        ; File has incomplete data - fill in defaults for new RAM file
        ldy     aws_tmp14               ; Restore file offset
        
        ; Set default load address ($FFFF = host address)
        tya
        clc
        adc     #0                      ; Load address offset
        tax
        lda     #$FF
        sta     RAM_CATALOG_START+256,x   ; Load address low
        inx
        sta     RAM_CATALOG_START+256,x   ; Load address high
        
        ; Set default exec address ($FFFF = host address)  
        inx
        sta     RAM_CATALOG_START+256,x   ; Exec address low
        inx
        sta     RAM_CATALOG_START+256,x   ; Exec address high
        
        ; Set initial file size (0)
        inx
        lda     #0
        sta     RAM_CATALOG_START+256,x   ; Size low
        inx
        sta     RAM_CATALOG_START+256,x   ; Size high
        
        ; Set mixed byte (all bits 0 for host addresses)
        inx
        lda     #0
        sta     RAM_CATALOG_START+256,x
        
        ; Assign fake RAM sector
        ldy     aws_tmp14               ; Restore file offset
        tya
        sec
        sbc     #24                     ; Convert to file index from offset 24 
        lsr     a                       ; Divide by 8 to get file index  
        lsr     a
        lsr     a
        clc
        adc     #FIRST_RAM_SECTOR       ; Add to base (10+)
        
        ; Store fake sector
        tya
        clc  
        adc     #7                      ; Sector offset
        tax
        sta     RAM_CATALOG_START+256,x ; Store fake sector
        
        ; Mark page as allocated
        sec
        sbc     #FIRST_RAM_SECTOR       ; Convert to page number
        tax
        lda     #1
        sta     RAM_PAGE_ALLOC,x        ; Mark page as used
        
assign_next_file:
@next_file:
        ldy     aws_tmp14               ; Restore file offset
        tya
        clc
        adc     #8                      ; Move to next file
        tay
        jmp     assign_check_file
        
assign_done:
@assign_done:
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

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; RAM Filesystem Functions
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; FUJI_INIT_RAM_FILESYSTEM - Initialize RAM filesystem
; Copies ROM catalog to RAM and sets up for file creation
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

fuji_init_ram_filesystem:
        jsr     remember_axy
        
        ; Copy ROM catalog to RAM catalog area
        ldy     #0
@copy_catalog_loop:
        lda     dummy_catalogue,y
        sta     RAM_CATALOG_START,y
        iny
        bne     @copy_catalog_loop      ; Copy first 256 bytes
        
        ; Copy second 256 bytes  
        ldy     #0
@copy_catalog_loop2:
        lda     dummy_catalogue+256,y
        sta     RAM_CATALOG_START+256,y
        iny
        bne     @copy_catalog_loop2     ; Copy second 256 bytes
        
        ; Clear page allocation table (all pages free)
        lda     #$00
        ldy     #$1F                    ; 32 bytes for allocation table
@clear_alloc_loop:
        sta     RAM_PAGE_ALLOC,y
        dey
        bpl     @clear_alloc_loop
        
        ; Clear page length table
        lda     #$00
        ldy     #$1F                    ; 32 bytes for length table
@clear_length_loop:
        sta     RAM_PAGE_LENGTH,y
        dey
        bpl     @clear_length_loop
        
        rts

; RAM filesystem variables (kept for future use)
ram_file_alloc_ptr:
        .word   RAM_PAGES_START

.endif  ; FUJINET_INTERFACE_DUMMY
