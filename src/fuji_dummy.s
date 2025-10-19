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

        .export dummy_catalog

        .export hello_app_start
        .export world_app_start
        .export test_app_start

        .export assign_ram_sectors_to_new_files
        .export fuji_init_ram_filesystem
        .export get_next_available_sector
        .export free_ram_sector

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

; RAM filesystem layout - DUAL DRIVE SUPPORT:
; $5000-500F - RAM disk state and workspace (16 bytes):
;   $5000    - Drive 0 next available page (0-5, not sector number!)
;   $5001    - Drive 1 next available page (0-5, not sector number!)
;   $5002-500F - Reserved for debug/temp workspace (14 bytes)
; $5010-5087 - Drive 0 catalog compressed (7 entries × 16 bytes = 112 bytes)
;              Entry 0: Disk title (8+8 bytes), Entries 1-6: Files (8+8 bytes each)
; $5088-50FF - Drive 1 catalog compressed (7 entries × 16 bytes = 112 bytes)
; $5100-5107 - Drive 0 page allocation (8 bytes, 1 per page, supports 6 files + 2 spare)
; $5108-510F - Drive 1 page allocation (8 bytes, 1 per page, supports 6 files + 2 spare)
; $5110-5717 - Drive 0 file pages (6 pages × 256 = $600 bytes)
; $5718-5D1F - Drive 1 file pages (6 pages × 256 = $600 bytes)
; Total: $D20 bytes (~3.3KB)

DRIVE0_NEXT_PAGE      = RAM_FS_START + $0       ; Next available page for drive 0 (0-5)
DRIVE1_NEXT_PAGE      = RAM_FS_START + $1       ; Next available page for drive 1 (0-5)
TEMP_STORAGE          = RAM_FS_START + $2       ; Temp workspace (14 bytes available)
RAM_CATALOG_OFFSET    = $10                     ; Catalogs start 16 bytes after RAM_FS_START

; Catalog compression: 7 entries (1 header + 6 files) × 16 bytes per entry
CATALOG_ENTRIES       = 7                       ; Header + 6 files
CATALOG_ENTRY_SIZE    = 16                      ; 8 bytes sector 0 + 8 bytes sector 1
CATALOG_COMPRESSED_SIZE = CATALOG_ENTRIES * CATALOG_ENTRY_SIZE  ; 112 bytes

; Drive 0 structures
DRIVE0_CATALOG    = RAM_FS_START + $010         ; Drive 0 catalog (112 bytes compressed)
DRIVE0_PAGE_ALLOC = RAM_FS_START + $100         ; Drive 0 page allocation (8 bytes)
DRIVE0_PAGES      = RAM_FS_START + $110         ; Drive 0 file pages (6 × 256)

; Drive 1 structures  
DRIVE1_CATALOG    = RAM_FS_START + $088         ; Drive 1 catalog (112 bytes compressed)
DRIVE1_PAGE_ALLOC = RAM_FS_START + $108         ; Drive 1 page allocation (8 bytes)
DRIVE1_PAGES      = RAM_FS_START + $718         ; Drive 1 file pages (6 × 256)

; Constants
MAX_PAGES_PER_DRIVE = 6                         ; 6 pages per drive (6 files max)
PAGE_SIZE           = 256                       ; Bytes per page
FIRST_RAM_SECTOR    = 2                         ; Sectors 2+ are RAM pages
NUM_DRIVES          = 2                         ; Support 2 drives (0 and 1)

; Static test data - a simple BBC Micro disc image
dummy_disc_title:
        .byte "TESTDISC", 0

; Dummy catalog data (512 bytes = 2 sectors of 256 bytes each)
; This simulates a BBC Micro disc catalog following DFS format
; Sector 0: Catalog header + file names
; Sector 1: Catalog info + file details
dummy_catalog:
        ; SECTOR 0 (bytes 0-255)
        ; Catalog header entry 0 (bytes 0-7): Disk title first 8 bytes
        .byte "TESTDISC"

        ; File entry 1 (bytes 8-15): Filename + directory
        .byte "HELLO  ", $24  ; Filename (7 bytes) + directory "$" (unlocked)

        ; File entry 2 (bytes 16-23): Filename + directory
        .byte "WORLD  ", $A4  ; Filename (7 bytes) + directory "$" (locked - high bit set)

        ; File entry 3 (bytes 24-31): Filename + directory
        .byte "TEST   ", $24  ; Filename (7 bytes) + directory "$" (unlocked)
end_of_sector0_data:

; TODO: need to mark this location so we can get the size of first sector above
end_of_sector0:

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
end_of_sector1_data:


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

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; Helper functions to get drive-specific addresses
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

; get_current_catalog - Get catalog address for current drive
; Output: aws_tmp12/13 = catalog address
; Uses current_drv ($CD) to determine which drive's catalog to access
get_current_catalog:
        lda     current_drv              ; Read from OS variable
        beq     @drive0
        ; Drive 1
        lda     #<DRIVE1_CATALOG
        sta     aws_tmp12
        lda     #>DRIVE1_CATALOG
        sta     aws_tmp13
        rts
@drive0:
        ; Drive 0
        lda     #<DRIVE0_CATALOG
        sta     aws_tmp12
        lda     #>DRIVE0_CATALOG
        sta     aws_tmp13
        rts

; get_current_page_alloc - Get page allocation address for current drive
; Output: aws_tmp12/13 = page allocation address
; Uses current_drv ($CD) to determine which drive's page allocation to access
get_current_page_alloc:
        lda     current_drv              ; Read from OS variable
        beq     @drive0
        ; Drive 1
        lda     #<DRIVE1_PAGE_ALLOC
        sta     aws_tmp12
        lda     #>DRIVE1_PAGE_ALLOC
        sta     aws_tmp13
        rts
@drive0:
        ; Drive 0
        lda     #<DRIVE0_PAGE_ALLOC
        sta     aws_tmp12
        lda     #>DRIVE0_PAGE_ALLOC
        sta     aws_tmp13
        rts

; get_current_pages_start - Get file pages start address for current drive
; Output: A = high byte offset to add to page number
; Uses current_drv ($CD) to determine which drive's pages to access
get_current_pages_start:
        lda     current_drv              ; Read from OS variable
        beq     @drive0
        ; Drive 1
        lda     #>DRIVE1_PAGES
        rts
@drive0:
        ; Drive 0
        lda     #>DRIVE0_PAGES
        rts

; convert_sector_to_drive_page - Convert sector to drive-relative page
; Input: A = sector number
; Output: A = page number (0-5 for current drive), Carry=1 if error
convert_sector_to_drive_page:
        cmp     #FIRST_RAM_SECTOR
        bcc     @error                  ; Sector < 2, error
        sec
        sbc     #FIRST_RAM_SECTOR       ; Convert to absolute page (0-11)
        
        ; Determine which drive this page belongs to
        cmp     #MAX_PAGES_PER_DRIVE
        bcc     @drive0_page            ; Page 0-5 = drive 0
        
        ; Page 6-11 = drive 1
        sec
        sbc     #MAX_PAGES_PER_DRIVE    ; Convert to drive-relative page (0-5)
        clc                             ; Success
        rts
        
@drive0_page:
        ; Already 0-5, just return
        clc                             ; Success
        rts
        
@error:
        sec                             ; Error
        rts

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; FUJI_READ_BLOCK_DATA - Read data block from dummy interface
; Input: data_ptr points to buffer, other parameters in workspace
; Output: Data read into buffer, Carry=0 if success, Carry=1 if error
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

fuji_read_block_data:
        jsr     remember_axy

.ifdef FN_DEBUG_READ_DATA
         pha
         jsr     print_string
         .byte   "READ: sector="
         lda     fuji_file_offset
         jsr     print_hex
         jsr     print_string
         .byte   " size="
         lda     fuji_block_size+1
         jsr     print_hex
         lda     fuji_block_size
         jsr     print_hex
         jsr     print_newline
         pla
.endif

        ; For dummy interface, read from RAM pages
        ; The sector in fuji_file_offset is drive-relative (2-7)
        ; Convert to absolute page based on current drive

        lda     fuji_file_offset         ; Get drive-relative sector number
        cmp     #FIRST_RAM_SECTOR       ; Is it a RAM sector (2+)?
        bcs     @read_ram_page          ; Yes, read from RAM page

        ; Sectors 0-1 (catalog) not handled here, return error
        lda     #0
        rts
        
@read_ram_page:
        ; Convert drive-relative sector to drive-relative page
        sec
        sbc     #FIRST_RAM_SECTOR       ; A = drive-relative page (0-5)
        
        ; Now convert to absolute page based on current drive
        ; Drive 0: absolute page = drive-relative page (0-5)
        ; Drive 1: absolute page = drive-relative page + 6 (6-11)
        ldx     current_drv
        beq     @read_drive0
        ; Drive 1: add 6 to get absolute page
        clc
        adc     #MAX_PAGES_PER_DRIVE
@read_drive0:
        ; A now contains absolute page number (0-11)

.ifdef FN_DEBUG_READ_DATA
        pha
        jsr     print_string
        .byte   " abs_page="
        nop
        jsr     print_hex
        pla
.endif

        ; Determine drive and convert to drive-relative page
        ; Pages 0-5 = drive 0, pages 6-11 = drive 1
        cmp     #MAX_PAGES_PER_DRIVE
        bcc     @drive0_read            ; Page 0-5 = drive 0
        
        ; Drive 1 (pages 6-11)
        sec
        sbc     #MAX_PAGES_PER_DRIVE    ; Convert to drive-relative page (0-5)
        pha                             ; Save page number
        lda     #>DRIVE1_PAGES          ; Get drive 1 pages base
        jmp     @calc_page_addr
        
@drive0_read:
        ; Drive 0 (pages 0-5)
        pha                             ; Save page number
        lda     #>DRIVE0_PAGES          ; Get drive 0 pages base
        
@calc_page_addr:
        sta     aws_tmp13               ; Base high byte
        pla                             ; Restore page number
        clc
        adc     aws_tmp13               ; Add page offset to base
        sta     aws_tmp13               ; Final high byte
        lda     #$00                    ; Low byte always 0 (page boundary)
        sta     aws_tmp12

; .ifdef FN_DEBUG_READ_DATA
;         jsr     print_string
;         .byte   " addr=$"
;         lda     aws_tmp13
;         jsr     print_hex
;         lda     aws_tmp12
;         jsr     print_hex
;         jsr     print_newline
; .endif
        
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

; .ifdef FN_DEBUG_READ_DATA
;         pha
;         jsr     print_string
;         .byte   " byte="
;         nop
;         jsr     print_hex
;         pla
; .endif

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

.ifdef FN_DEBUG_WRITE_DATA
        pha
        jsr     print_string
        .byte   "WRITE: sector="
        lda     fuji_file_offset
        jsr     print_hex
        jsr     print_string
        .byte   " buf=$"
        lda     data_ptr+1
        jsr     print_hex
        lda     data_ptr
        jsr     print_hex
        jsr     print_newline
        pla
.endif

        lda     fuji_file_offset         ; Get drive-relative sector number
        cmp     #FIRST_RAM_SECTOR       ; Is it a RAM sector (2+)?
        bcs     @write_ram_page         ; Yes, write to RAM page

        ; Sectors 0-1 (catalog) not handled here, return error
        lda     #0
        rts

@write_ram_page:
        ; Convert drive-relative sector to drive-relative page
        sec
        sbc     #FIRST_RAM_SECTOR       ; A = drive-relative page (0-5)
        
        ; Now convert to absolute page based on current drive
        ; Drive 0: absolute page = drive-relative page (0-5)
        ; Drive 1: absolute page = drive-relative page + 6 (6-11)
        ldx     current_drv
        beq     @write_drive0
        ; Drive 1: add 6 to get absolute page
        clc
        adc     #MAX_PAGES_PER_DRIVE
@write_drive0:
        ; A now contains absolute page number (0-11)

        ; Check if page is within total bounds (12 pages total)
        cmp     #(MAX_PAGES_PER_DRIVE * NUM_DRIVES)
        bcs     @write_error            ; Page >= 12, error

        ; Determine drive and convert to drive-relative page
        ; Pages 0-5 = drive 0, pages 6-11 = drive 1
        cmp     #MAX_PAGES_PER_DRIVE
        bcc     @drive0_write           ; Page 0-5 = drive 0
        
        ; Drive 1 (pages 6-11)
        sec
        sbc     #MAX_PAGES_PER_DRIVE    ; Convert to drive-relative page (0-5)
        pha                             ; Save page number
        lda     #>DRIVE1_PAGES          ; Get drive 1 pages base
        jmp     @calc_write_addr
        
@drive0_write:
        ; Drive 0 (pages 0-5)
        pha                             ; Save page number
        lda     #>DRIVE0_PAGES          ; Get drive 0 pages base
        
@calc_write_addr:
        sta     aws_tmp13               ; Base high byte
        pla                             ; Restore page number
        clc
        adc     aws_tmp13               ; Add page offset to base
        sta     aws_tmp13               ; Final high byte
        lda     #$00                    ; Low byte always 0 (page boundary)
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

@write_error:
        lda     #0                      ; Return error
        rts

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; FUJI_READ_CATALOG_DATA - Read catalog from dummy interface
; Input: data_ptr points to 512-byte catalog buffer
; Output: Catalogue data in buffer, Carry=0 if success, Carry=1 if error
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

fuji_read_catalog_data:
        jsr     remember_axy

        ; Get current drive's catalog address
        jsr     get_current_catalog     ; Returns address in aws_tmp12/13

        ; Expand compressed catalog (112 bytes) to full DFS catalog (512 bytes)
        ; Compressed format: 7 entries × 16 bytes (8 for sector 0, 8 for sector 1)
        ; Expanded format: Sector 0 (256 bytes) + Sector 1 (256 bytes)
        
        ; Clear destination buffer first (512 bytes)
        ldy     #0
        lda     #0
@clear_s0:
        sta     (data_ptr),y
        iny
        bne     @clear_s0

        inc     data_ptr+1
        ldy     #0
@clear_s1:
        sta     (data_ptr),y
        iny
        bne     @clear_s1
        dec     data_ptr+1

        ; Now copy compressed catalog data, expanding it
        ; Use simple byte counter in memory
        lda     #0
        sta     TEMP_STORAGE            ; Byte counter (0-111)
        
@copy_byte_loop:
        ; Read byte from compressed catalog
        ldy     TEMP_STORAGE
        lda     (aws_tmp12),y           ; Read byte from compressed
        sta     TEMP_STORAGE + 1        ; Save byte
        
        ; Calculate entry number: entry = counter / 16
        tya
        lsr     a                       ; ÷ 2
        lsr     a                       ; ÷ 4
        lsr     a                       ; ÷ 8
        lsr     a                       ; ÷ 16
        ; A = entry number (0-6)
        asl     a                       ; × 2
        asl     a                       ; × 4
        asl     a                       ; × 8
        ; A = entry * 8
        sta     TEMP_STORAGE + 2        ; Save entry*8
        
        ; Calculate byte within entry: counter & 15
        lda     TEMP_STORAGE
        and     #15                     ; byte within entry (0-15)
        cmp     #8
        bcs     @write_s1
        
        ; Write to sector 0: dest = entry*8 + byte_in_entry
        clc
        adc     TEMP_STORAGE + 2        ; Add entry*8
        tay
        lda     TEMP_STORAGE + 1        ; Get byte
        sta     (data_ptr),y            ; Write to sector 0
        jmp     @next_byte
        
@write_s1:
        ; Write to sector 1: dest = entry*8 + (byte_in_entry-8)
        sec
        sbc     #8                      ; byte - 8
        clc
        adc     TEMP_STORAGE + 2        ; Add entry*8
        tay
        inc     data_ptr+1              ; Point to sector 1
        lda     TEMP_STORAGE + 1        ; Get byte
        sta     (data_ptr),y            ; Write to sector 1
        dec     data_ptr+1              ; Back to sector 0
        
@next_byte:
        inc     TEMP_STORAGE            ; Next byte
        lda     TEMP_STORAGE
        cmp     #CATALOG_COMPRESSED_SIZE  ; Done all 112 bytes?
        bne     @copy_byte_loop

        clc
        rts

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; FUJI_WRITE_CATALOG_DATA - Write catalog to dummy interface
; Input: data_ptr points to 512-byte catalog buffer
; Output: Carry=0 if success, Carry=1 if error
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

fuji_write_catalog_data:
.ifdef FN_DEBUG_CREATE_FILE
        ; Mark catalog sync start
        lda     #$BB
        sta     $6FF3               ; Debug marker - RAM sync start
.endif
        jsr     remember_axy

        ; Get current drive's catalog address
        jsr     get_current_catalog     ; Returns address in aws_tmp12/13

        ; Compress full 512-byte DFS catalog to 112-byte compressed format
        ; Full format: Sector 0 (256 bytes) + Sector 1 (256 bytes)
        ; Compressed format: 7 entries × 16 bytes (8 from sector 0, 8 from sector 1)

        lda     #0
        sta     TEMP_STORAGE            ; Entry counter (0-6)
        
@compress_entries:
        ; Calculate source offset in sector 0: entry * 8
        lda     TEMP_STORAGE
        asl     a                       ; × 2
        asl     a                       ; × 4
        asl     a                       ; × 8
        tay                             ; Y = source offset in sector 0
        
        ; Calculate destination offset in compressed: entry * 16
        lda     TEMP_STORAGE
        asl     a                       ; × 2
        asl     a                       ; × 4
        asl     a                       ; × 8
        asl     a                       ; × 16
        sta     TEMP_STORAGE + 1        ; Save dest offset
        
        ; Copy 8 bytes from sector 0
        ldx     #0
@copy_from_s0:
        lda     (data_ptr),y            ; Read from system catalog sector 0
        sty     TEMP_STORAGE + 2        ; Save Y
        ldy     TEMP_STORAGE + 1        ; Y = dest offset
        sta     (aws_tmp12),y           ; Write to compressed catalog
        inc     TEMP_STORAGE + 1        ; Next dest byte
        ldy     TEMP_STORAGE + 2        ; Restore Y
        iny                             ; Next source byte
        inx
        cpx     #8
        bne     @copy_from_s0
        
        ; Now copy 8 bytes from sector 1
        ; Calculate source offset in sector 1: entry * 8
        lda     TEMP_STORAGE
        asl     a                       ; × 2
        asl     a                       ; × 4
        asl     a                       ; × 8
        tay                             ; Y = source offset in sector 1
        
        inc     data_ptr+1              ; Point to sector 1
        ldx     #0
@copy_from_s1:
        lda     (data_ptr),y            ; Read from system catalog sector 1
        sty     TEMP_STORAGE + 2        ; Save Y
        ldy     TEMP_STORAGE + 1        ; Y = dest offset
        sta     (aws_tmp12),y           ; Write to compressed catalog
        inc     TEMP_STORAGE + 1        ; Next dest byte
        ldy     TEMP_STORAGE + 2        ; Restore Y
        iny                             ; Next source byte
        inx
        cpx     #8
        bne     @copy_from_s1
        dec     data_ptr+1              ; Back to sector 0
        
        ; Next entry
        inc     TEMP_STORAGE
        lda     TEMP_STORAGE
        cmp     #CATALOG_ENTRIES        ; Done all 7 entries?
        bne     @compress_entries

        ; Mark RAM pages as allocated for files in catalog
        jsr     assign_ram_sectors_to_new_files

        clc
        rts

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; assign_ram_sectors_to_new_files - Mark RAM pages as allocated based on catalog
; MMFS handles sector calculation, this just marks pages as used for write operations
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

assign_ram_sectors_to_new_files:
.ifdef FN_DEBUG_CREATE_FILE
        pha
        jsr     print_string
        .byte   "=== MARKING RAM PAGES AS ALLOCATED ===", $0D
        nop
        pla
.endif
        ; Get current drive's catalog and page allocation addresses
        jsr     get_current_catalog     ; Returns catalog addr in aws_tmp12/13
        ; Note: We'll scan the compressed catalog in RAM

        ; Scan all files and mark their RAM pages as allocated
        ldy     #RAM_CATALOG_OFFSET     ; Start at offset 8 (first file entry, after disc title)

assign_check_file:
@check_file:
        cpy     dfs_cat_num_x8          ; Past end of files?
        bcc     @continue_check         ; No, continue checking
        jmp     assign_done             ; Yes, done
@continue_check:

        ; Calculate offset in compressed catalog
        ; Compressed offset = (catalog_offset / 8) * 16 = catalog_offset * 2
        ; Add 15 to get to the sector byte (last byte of the 16-byte entry)
        tya
        pha                             ; Save Y
        asl     a                       ; catalog_offset * 2
        clc
        adc     #15                     ; +15 = sector byte (last byte of entry)
        tay
        
        lda     (aws_tmp12),y           ; Get sector number from compressed catalog
        pla                             ; Restore original Y
        tay
        sta     aws_tmp14               ; Save sector number
        
.ifdef FN_DEBUG_CREATE_FILE
        pha
        jsr     print_string
        .byte   "CHECK: offset="
        tya
        jsr     print_hex
        jsr     print_string
        .byte   " sector="
        nop
        lda     aws_tmp14
        jsr     print_hex
        jsr     print_newline
        pla
.endif

        lda     aws_tmp14               ; Get sector number
        ; Is this a RAM sector that needs page allocation?
        cmp     #FIRST_RAM_SECTOR       ; Is it a RAM sector (2+)?
        bcc     assign_next_file        ; No, skip (catalog sectors 0-1)
        
        ; Convert absolute sector to page (0-11)
        sec
        sbc     #FIRST_RAM_SECTOR       ; page = sector - 2
        
        ; Determine which drive this page belongs to
        cmp     #MAX_PAGES_PER_DRIVE    ; Page 0-5 or 6-11?
        bcc     @mark_drive0            ; 0-5 = drive 0
        
        ; Drive 1 (pages 6-11)
        sec
        sbc     #MAX_PAGES_PER_DRIVE    ; Convert to drive-relative (0-5)
        tax
        lda     #1
        sta     DRIVE1_PAGE_ALLOC,x     ; Mark drive 1 page as used
        jmp     assign_next_file
        
@mark_drive0:
        ; Drive 0 (pages 0-5)
        tax
        lda     #1
        sta     DRIVE0_PAGE_ALLOC,x     ; Mark drive 0 page as used

assign_next_file:
@next_file:
        tya
        clc
        adc     #8                      ; Move to next file
        tay
        jmp     assign_check_file

assign_done:
@assign_done:
.ifdef FN_DEBUG_CREATE_FILE
        jsr     print_string
        .byte   "=== ASSIGN_RAM_SECTORS DONE"
        nop
        jsr     print_newline
.endif
        rts

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; get_next_available_sector - Get next available sector, reusing freed sectors
; Strategy:
;   1. Scan RAM_PAGE_ALLOC for first free page (value=0)
;   2. If found, mark it allocated and return sector (drive-relative, always 2+)
;   3. If no free pages, allocate new page
; Output: A = drive-relative sector number (2-7, same for all drives)
; Side effects: Marks page as allocated
; Note: Returns drive-relative sector for catalog. The actual RAM location
;       is determined by the drive number internally when reading/writing.
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

get_next_available_sector:
        ; CRITICAL: Save aws_tmp02-03 AND aws_tmp12-13 to avoid corrupting caller's data
        ; These registers may contain load/exec addresses or other important data
        lda     aws_tmp02
        sta     TEMP_STORAGE + 2
        lda     aws_tmp03
        sta     TEMP_STORAGE + 3
        lda     aws_tmp12
        sta     TEMP_STORAGE + 4
        lda     aws_tmp13
        sta     TEMP_STORAGE + 5
        
        ; Get current drive's page allocation table
        jsr     get_current_page_alloc  ; Returns address in aws_tmp12/13
        
        ; Scan for freed pages in current drive (0-5)
        ldx     #0                      ; Start at page 0
@scan_loop:
        cpx     #MAX_PAGES_PER_DRIVE    ; Scanned all 6 pages?
        bcs     @no_free_pages          ; Yes, allocate new
        
        ; Check if this page is free
        ; Calculate address: aws_tmp12/13 + X using aws_tmp02/03
        txa
        clc
        adc     aws_tmp12
        sta     aws_tmp02
        lda     aws_tmp13
        adc     #0
        sta     aws_tmp03
        ldy     #0
        lda     (aws_tmp02),y           ; Read allocation byte
        cmp     #0
        beq     @found_free_page        ; If 0, this page is free!
        
        ; Not free, try next page
        inx
        jmp     @scan_loop
        
@no_free_pages:
        ; No freed pages found, allocate new page
        ; Find first unallocated page by scanning
        ldx     #0
@find_new_page:
        cpx     #MAX_PAGES_PER_DRIVE
        bcc     @check_page             ; In range, check it
        jmp     @disk_full              ; All pages used!
@check_page:
        
        ; Check this page
        txa
        clc
        adc     aws_tmp12
        sta     aws_tmp02
        lda     aws_tmp13
        adc     #0
        sta     aws_tmp03
        ldy     #0
        lda     (aws_tmp02),y
        cmp     #0
        beq     @alloc_new_page         ; Found free page
        inx
        jmp     @find_new_page
        
@alloc_new_page:
        ; Mark page X as allocated
        txa
        clc
        adc     aws_tmp12
        sta     aws_tmp02
        lda     aws_tmp13
        adc     #0
        sta     aws_tmp03
        ldy     #0
        lda     #1
        sta     (aws_tmp02),y           ; Mark as allocated
        jmp     @convert_and_exit       ; Common exit point
        
@found_free_page:
        ; X contains the free page number, mark as allocated
        txa
        clc
        adc     aws_tmp12
        sta     aws_tmp02
        lda     aws_tmp13
        adc     #0
        sta     aws_tmp03
        ldy     #0
        lda     #1
        sta     (aws_tmp02),y
        jmp     @convert_and_exit       ; Common exit point
        
@disk_full:
        lda     #0                      ; Return 0 for disk full
        jmp     @restore_and_exit       ; Skip sector conversion, just restore and exit

@convert_and_exit:
        ; Convert page (in X) to drive-relative sector
        ; ALL drives return sectors 2-7 (drive-relative for catalog)
        ; The actual RAM location is determined by current_drv when reading/writing
        txa
        clc
        adc     #FIRST_RAM_SECTOR       ; sector = page + 2 (always 2-7)
        ; Fall through to @restore_and_exit

@restore_and_exit:
        ; A contains the sector number (or 0 for disk full)
        ; Save A temporarily
        pha
        
        ; Restore aws_tmp02-03 and aws_tmp12-13
        lda     TEMP_STORAGE + 2
        sta     aws_tmp02
        lda     TEMP_STORAGE + 3
        sta     aws_tmp03
        lda     TEMP_STORAGE + 4
        sta     aws_tmp12
        lda     TEMP_STORAGE + 5
        sta     aws_tmp13
        
        ; Restore A (sector number) and return
        pla
        rts

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; free_ram_sector - Mark a sector as free for reuse
; Input: A = sector number to free
; Side effects: Marks page as free in RAM_PAGE_ALLOC
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

free_ram_sector:
        ; Check if this is a RAM sector (2+)
        cmp     #FIRST_RAM_SECTOR
        bcc     @not_ram_sector         ; Sectors 0-1 are catalog, can't free
        
        ; Convert sector to absolute page number (0-11)
        sec
        sbc     #FIRST_RAM_SECTOR       ; page = sector - 2
        
        ; Determine which drive: pages 0-5=drive0, 6-11=drive1
        cmp     #MAX_PAGES_PER_DRIVE
        bcc     @free_drive0
        
        ; Drive 1 (pages 6-11)
        sec
        sbc     #MAX_PAGES_PER_DRIVE    ; Convert to drive-relative (0-5)
        tax
        lda     #0
        sta     DRIVE1_PAGE_ALLOC,x
        rts
        
@free_drive0:
        ; Drive 0 (pages 0-5)
        tax
        lda     #0
        sta     DRIVE0_PAGE_ALLOC,x
        
@not_ram_sector:
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


;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; RAM Filesystem Functions
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; FUJI_INIT_RAM_FILESYSTEM - Initialize RAM filesystem
; Copies ROM catalog to RAM and sets up for file creation
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

fuji_init_ram_filesystem:
        jsr     remember_axy

        ; Note: We read current_drv ($CD) directly, no need to initialize it here
        ; The OS will have already set it via *DRIVE or defaults
        
        ; Clear both drive's compressed catalogs
        ldx     #0
        lda     #0
@clear_catalogs:
        sta     DRIVE0_CATALOG,x
        sta     DRIVE1_CATALOG,x
        inx
        cpx     #(CATALOG_COMPRESSED_SIZE * 2)  ; Clear 224 bytes total
        bne     @clear_catalogs

        ; Clear page allocation tables for both drives
        lda     #0
        ldx     #0
@clear_alloc:
        sta     DRIVE0_PAGE_ALLOC,x
        sta     DRIVE1_PAGE_ALLOC,x
        inx
        cpx     #8                      ; 8 bytes per drive
        bne     @clear_alloc

        ; Initialize DRIVE 0 with TEST, WORLD, HELLO files
        ; Create compressed catalog entry 0 (disk title)
        ldy     #0
@init_drive0_title:
        lda     dummy_catalog,y
        sta     DRIVE0_CATALOG,y        ; Copy first 8 bytes (sector 0)
        iny
        cpy     #8
        bne     @init_drive0_title
        ldy     #0
@init_drive0_title_s1:
        lda     end_of_sector0_data,y
        sta     DRIVE0_CATALOG+8,y      ; Copy next 8 bytes (sector 1)
        iny
        cpy     #8
        bne     @init_drive0_title_s1

        ; Copy file entries 1-3 (HELLO, WORLD, TEST) individually
        ; Each entry is 16 bytes: 8 for sector 0, 8 for sector 1
        
        ; Entry 1: HELLO (bytes 16-31)
        ldx     #0
@copy_hello_entry:
        lda     dummy_catalog+8,x       ; Sector 0 data
        sta     DRIVE0_CATALOG+16,x
        lda     end_of_sector0_data+8,x ; Sector 1 data
        sta     DRIVE0_CATALOG+24,x
        inx
        cpx     #8
        bne     @copy_hello_entry
        
        ; Entry 2: WORLD (bytes 32-47)
        ldx     #0
@copy_world_entry:
        lda     dummy_catalog+16,x      ; Sector 0 data
        sta     DRIVE0_CATALOG+32,x
        lda     end_of_sector0_data+16,x ; Sector 1 data
        sta     DRIVE0_CATALOG+40,x
        inx
        cpx     #8
        bne     @copy_world_entry
        
        ; Entry 3: TEST (bytes 48-63)
        ldx     #0
@copy_test_entry:
        lda     dummy_catalog+24,x      ; Sector 0 data
        sta     DRIVE0_CATALOG+48,x
        lda     end_of_sector0_data+24,x ; Sector 1 data
        sta     DRIVE0_CATALOG+56,x
        inx
        cpx     #8
        bne     @copy_test_entry

        ; Copy file data to drive 0 pages
        ; TEST → page 0 (sector 2)
        jsr     @copy_test_to_drive0
        ; WORLD → page 1 (sector 3)
        jsr     @copy_world_to_drive0
        ; HELLO → page 2 (sector 4)
        jsr     @copy_hello_to_drive0

        ; Mark drive 0 pages as allocated
        lda     #1
        sta     DRIVE0_PAGE_ALLOC+0
        sta     DRIVE0_PAGE_ALLOC+1
        sta     DRIVE0_PAGE_ALLOC+2

        ; Initialize DRIVE 1 - empty disk (just title, no files)
        ; Set disk title in sector 0 data (bytes 0-7)
        lda     #'D'
        sta     DRIVE1_CATALOG+0
        lda     #'R'
        sta     DRIVE1_CATALOG+1
        lda     #'I'
        sta     DRIVE1_CATALOG+2
        lda     #'V'
        sta     DRIVE1_CATALOG+3
        lda     #'E'
        sta     DRIVE1_CATALOG+4
        lda     #'1'
        sta     DRIVE1_CATALOG+5
        lda     #' '
        sta     DRIVE1_CATALOG+6
        sta     DRIVE1_CATALOG+7
        
        ; Set sector 1 data (bytes 8-15): title continuation + cycle + count + boot
        lda     #' '
        sta     DRIVE1_CATALOG+8        ; Title byte 8
        sta     DRIVE1_CATALOG+9        ; Title byte 9
        sta     DRIVE1_CATALOG+10       ; Title byte 10
        sta     DRIVE1_CATALOG+11       ; Title byte 11
        lda     #$00
        sta     DRIVE1_CATALOG+12       ; Cycle number
        sta     DRIVE1_CATALOG+13       ; File count = 0 (empty disk!)
        sta     DRIVE1_CATALOG+14       ; Boot option
        sta     DRIVE1_CATALOG+15       ; Disk size

        rts

; Helper functions to copy ROM file data to drive 0 RAM pages
@copy_test_to_drive0:
        ; Copy TEST file from ROM to drive 0, page 0
        ldy     #0
        ldx     #<(dummy_sector2_data_end - dummy_sector2_data)
@copy_test_loop:
        cpx     #0
        beq     @copy_test_done
        lda     dummy_sector2_data,y
        sta     DRIVE0_PAGES,y          ; Drive 0, page 0
        iny
        dex
        jmp     @copy_test_loop
@copy_test_done:
        rts

@copy_world_to_drive0:
        ; Copy WORLD file from ROM to drive 0, page 1
        ldy     #0
        ldx     #<(dummy_sector3_data_end - dummy_sector3_data)
@copy_world_loop:
        cpx     #0
        beq     @copy_world_done
        lda     dummy_sector3_data,y
        sta     DRIVE0_PAGES+256,y      ; Drive 0, page 1
        iny
        dex
        jmp     @copy_world_loop
@copy_world_done:
        rts

@copy_hello_to_drive0:
        ; Copy HELLO file from ROM to drive 0, page 2
        ldy     #0
        ldx     #<(dummy_sector4_data_end - dummy_sector4_data)
@copy_hello_loop:
        cpx     #0
        beq     @copy_hello_done
        lda     dummy_sector4_data,y
        sta     DRIVE0_PAGES+512,y      ; Drive 0, page 2
        iny
        dex
        jmp     @copy_hello_loop
@copy_hello_done:
        rts

.endif  ; FUJINET_INTERFACE_DUMMY
