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

        .import remember_axy
        .import err_disk

        .include "fujinet.inc"

        .segment "CODE"

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
        .byte $01        ; Cycle number (byte 260)
        .byte $18        ; (Number of catalog entries)*8 = 3*8 = 24 = $18
        .byte $00        ; Boot option (byte 262)
        .byte $00        ; Disk size low byte (byte 263)

        ; File entry 1 (bytes 264-271): HELLO - File details
        .byte $00, $19   ; Load address (bytes 264-265) = $1900
        .byte $00, $1A   ; Exec address (bytes 266-267) = $1A00
        .byte $20, $00   ; File length (bytes 268-269) = 32 bytes
        .byte $CC        ; Mixed byte (byte 270) - load=3, exec=3, length=3, sector=0
        .byte $04        ; Start sector (byte 271) = sector 4

        ; File entry 2 (bytes 272-279): WORLD - File details  
        .byte $00, $1B   ; Load address = $1B00
        .byte $00, $1C   ; Exec address = $1C00
        .byte $30, $00   ; File length = 48 bytes
        .byte $00        ; Mixed byte - all high bits = 0
        .byte $03        ; Start sector = sector 3

        ; File entry 3 (bytes 280-287): TEST - File details
        .byte $00, $1D   ; Load address = $1D00
        .byte $00, $1E   ; Exec address = $1E00
        .byte $10, $00   ; File length = 16 bytes
        .byte $00        ; Mixed byte - all high bits = 0
        .byte $02        ; Start sector = sector 2

        ; Fill rest of sector 1 with zeros
        .res 512 - (* - dummy_catalogue), $00

; Dummy file data - 3 sectors of 256 bytes each
; Sector 2: TEST file (16 bytes + padding)
dummy_sector2_data:
        .byte "Hello from TEST", $0D  ; 16 bytes of actual data
        .res 256 - 16, $00             ; Fill rest with zeros

; Sector 3: WORLD file (48 bytes + padding)  
dummy_sector3_data:
        .byte "Hello from WORLD! This is a longer message.1234", $0D  ; 48 bytes
        .res 256 - 48, $00             ; Fill rest with zeros

; Sector 4: HELLO file (32 bytes + padding)
dummy_sector4_data:
        .byte "Hello from HELLO This is a test", $0D  ; 32 bytes
        .res 256 - 32, $00             ; Fill rest with zeros

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; FUJI_READ_BLOCK_DATA - Read data block from dummy interface
; Input: data_ptr points to buffer, other parameters in workspace
; Output: Data read into buffer, Carry=0 if success, Carry=1 if error
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

fuji_read_block_data:
        jsr     remember_axy

        ; For dummy interface, read from our sector data
        ; In a real implementation, this would read from network

        ; TODO: Implement proper sector reading based on sector number
        ; For now, just copy some test data to buffer
        ldy     #0
@copy_loop:
        lda     dummy_sector2_data,y
        sta     (data_ptr),y
        iny
        cpy     #16       ; Copy 16 bytes from TEST file
        bne     @copy_loop

        clc
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

        ; Simple test: just return success
        clc
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
