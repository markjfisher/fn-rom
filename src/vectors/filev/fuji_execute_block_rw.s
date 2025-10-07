; FujiNet block read/write operations
; Handles network-based file block operations
; Replaces MMFS hardware-specific exec_block_rw

        .export fuji_execute_block_rw
        .export fuji_read_file_block
        .export fuji_write_file_block

        .import fuji_read_block_data
        .import fuji_write_block_data
        .import remember_axy
        .import print_axy
        .import print_string

        .include "fujinet.inc"

        .segment "CODE"

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; fuji_execute_block_rw - FujiNet block read/write
; On entry A=operation ($85=read, $A5=write)
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

fuji_execute_block_rw:
        ; Store operation type
        sta     fuji_operation_type
        
.ifdef FN_DEBUG
        jsr     print_string
        .byte   "BLOCK_RW A="
        nop
        jsr     print_axy
        jsr     print_string
        .byte   " BC="
        nop
        lda     aws_tmp12
        ldx     aws_tmp13
        ldy     #0
        jsr     print_axy
        jsr     print_string
        .byte   " C0="
        nop
        lda     pws_tmp00
        ldx     pws_tmp01
        ldy     pws_tmp02
        jsr     print_axy
        jsr     print_string
        .byte   " BE="
        nop
        lda     aws_tmp14
        ldx     #0
        ldy     #0
        jsr     print_axy
.endif
        
        ; Get buffer address from workspace (set by LoadFile_Ycatoffset)
        ; &BC-&BD contain the buffer address (load address)
        lda     aws_tmp12                ; &BC (buffer address low)
        sta     fuji_buffer_addr
        lda     aws_tmp13                ; &BD (buffer address high)
        sta     fuji_buffer_addr+1
        
        ; Get start sector from workspace (set by LoadFile_Ycatoffset)
        ; The start sector is in the last byte of the 8-byte file info
        ; It's stored in aws_tmp12+7 after the copy loop
        lda     aws_tmp12+7              ; Start sector
        sta     fuji_file_offset
        lda     #0
        sta     fuji_file_offset+1
        sta     fuji_file_offset+2
        
        ; Get block size from workspace (set by LoadFile_Ycatoffset)
        ; The file length is in bytes 4-5 of the 8-byte file info (aws_tmp12+4, aws_tmp12+5)
        ; Plus high bits from the mixed byte (aws_tmp12+6)
        ; Mixed byte bits 5-4 contain file length high bits
        lda     aws_tmp12+4              ; File length low byte
        sta     fuji_block_size
        
        lda     aws_tmp12+5              ; File length high byte
        sta     fuji_block_size+1
        
        ; Extract high bits from mixed byte and add to high byte
        lda     aws_tmp12+6              ; Mixed byte
        and     #$30                     ; Extract bits 5-4 (file length high bits)
        lsr                             ; Shift right 4 positions
        lsr
        lsr
        lsr
        clc
        adc     fuji_block_size+1        ; Add to existing high byte
        sta     fuji_block_size+1
        
        ; Execute network operation
        lda     fuji_operation_type
        cmp     #$85                     ; Read operation
        beq     @fuji_read_block
        cmp     #$A5                     ; Write operation
        beq     @fuji_write_block
        
        ; Unknown operation
        lda     #$FF                     ; Error code
        rts
        
@fuji_read_block:
        jsr     fuji_read_file_block
        rts
        
@fuji_write_block:
        jsr     fuji_write_file_block
        rts

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; fuji_read_file_block - Read file block from network
; Uses dummy implementation for testing
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

fuji_read_file_block:
        jsr     remember_axy
        
.ifdef FN_DEBUG
        jsr     print_string
        .byte   "READ_BLOCK buf="
        nop
        lda     fuji_buffer_addr
        ldx     fuji_buffer_addr+1
        ldy     #0
        jsr     print_axy
        jsr     print_string
        .byte   " offset="
        nop
        lda     fuji_file_offset
        ldx     fuji_file_offset+1
        ldy     fuji_file_offset+2
        jsr     print_axy
.endif
        
        ; Set data_ptr to point to the buffer address
        lda     fuji_buffer_addr
        sta     data_ptr
        lda     fuji_buffer_addr+1
        sta     data_ptr+1
        
        ; For dummy implementation, we'll read from our static sector data
        ; In a real implementation, this would:
        ; 1. Calculate which sector(s) to read based on fuji_file_offset
        ; 2. Send network command to FujiNet device
        ; 3. Receive data and copy to buffer
        
        ; For now, just call our dummy interface
        jsr     fuji_read_block_data
        
        ; Return success (A=1) or error (A=0)
        lda     #1                       ; Success for dummy
        rts

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; fuji_write_file_block - Write file block to network
; Uses dummy implementation for testing
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

fuji_write_file_block:
        jsr     remember_axy
        
        ; Set data_ptr to point to the buffer address
        lda     fuji_buffer_addr
        sta     data_ptr
        lda     fuji_buffer_addr+1
        sta     data_ptr+1
        
        ; For dummy implementation, we'll just acknowledge the write
        ; In a real implementation, this would:
        ; 1. Calculate which sector(s) to write based on fuji_file_offset
        ; 2. Send network command to FujiNet device with data
        ; 3. Handle network response and errors
        
        ; For now, just call our dummy interface
        jsr     fuji_write_block_data
        
        ; Return success (A=1) or error (A=0)
        lda     #1                       ; Success for dummy
        rts
