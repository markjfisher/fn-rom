; FujiNet dummy interface implementation
; Uses static data in memory for testing high-level file system functions
; This implements the data layer functions called by fuji_fs.s
; Only compiled when DUMMY interface is selected

; Only compile this file if DUMMY interface is selected
.ifdef FUJINET_INTERFACE_DUMMY

        .export fuji_read_block_data
        .export fuji_write_block_data
        .export fuji_read_catalogue_data
        .export fuji_write_catalogue_data
        .export fuji_read_disc_title_data

        .import remember_axy
        .import err_disk

        .include "fujinet.inc"

        .segment "CODE"

; Static test data - a simple BBC Micro disc image
dummy_disc_title:
        .byte "TESTDISC", 0

; Dummy catalogue data (512 bytes)
; This simulates a BBC Micro disc catalogue with a few test files
dummy_catalogue:
        ; Disc title (bytes 0-7)
        .byte "TESTDISC"
        ; Disc title continuation (bytes 248-255) 
        .byte $00, $00, $00, $00, $00, $00, $00, $00
        ; File entries (8 bytes each)
        ; File 1: HELLO
        .byte "HELLO   "  ; Filename (8 chars, space-padded)
        .byte $00, $00    ; Load address (2 bytes)
        .byte $00, $00    ; Exec address (2 bytes)
        .byte $05, $00    ; Length (2 bytes) - 5 bytes
        .byte $00         ; Attributes
        ; File 2: WORLD
        .byte "WORLD   "  ; Filename
        .byte $00, $00    ; Load address
        .byte $00, $00    ; Exec address
        .byte $06, $00    ; Length - 6 bytes
        .byte $00         ; Attributes
        ; File 3: TEST
        .byte "TEST    "  ; Filename
        .byte $00, $00    ; Load address
        .byte $00, $00    ; Exec address
        .byte $04, $00    ; Length - 4 bytes
        .byte $00         ; Attributes
        ; Fill rest with zeros (end of catalogue)
        .res 512 - (* - dummy_catalogue), $00

; Dummy file data
dummy_hello_data:
        .byte "Hello"
dummy_world_data:
        .byte "World!"
dummy_test_data:
        .byte "Test"

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; FUJI_READ_BLOCK_DATA - Read data block from dummy interface
; Input: data_ptr points to buffer, other parameters in workspace
; Output: Data read into buffer, Carry=0 if success, Carry=1 if error
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

fuji_read_block_data:
        jsr     remember_axy
        
        ; For dummy interface, we'll just copy some test data
        ; In a real implementation, this would read from network
        
        ; Simple test: copy dummy data to buffer
        ldy     #0
@copy_loop:
        lda     dummy_hello_data,y
        sta     (data_ptr),y
        iny
        cpy     #5        ; Copy 5 bytes ("Hello")
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
; FUJI_READ_CATALOGUE_DATA - Read catalogue from dummy interface
; Input: data_ptr points to 512-byte catalogue buffer
; Output: Catalogue data in buffer, Carry=0 if success, Carry=1 if error
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

fuji_read_catalogue_data:
        jsr     remember_axy
        
        ; Copy dummy catalogue data to buffer
        ldy     #0
@copy_loop:
        lda     dummy_catalogue,y
        sta     (data_ptr),y
        iny
        cpy     #$FF      ; Copy 255 bytes first
        bne     @copy_loop
        
        ; Copy remaining bytes
        ldy     #0
@copy_loop2:
        lda     dummy_catalogue+$FF,y
        sta     (data_ptr+1),y
        iny
        cpy     #$01      ; Copy remaining 1 byte
        bne     @copy_loop2
        
        clc
        rts

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; FUJI_WRITE_CATALOGUE_DATA - Write catalogue to dummy interface
; Input: data_ptr points to 512-byte catalogue buffer
; Output: Carry=0 if success, Carry=1 if error
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

fuji_write_catalogue_data:
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

.endif  ; FUJINET_INTERFACE_DUMMY
