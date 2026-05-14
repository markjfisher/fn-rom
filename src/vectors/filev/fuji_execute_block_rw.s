; FujiNet block read/write operations
; Handles network-based file block operations
; Replaces MMFS hardware-specific exec_block_rw

        .export fuji_execute_block_rw
        .export fuji_read_file_block
        .export fuji_write_file_block

        .importzp aws_tmp12
        .importzp aws_tmp13
        .importzp pws_tmp00
        .importzp pws_tmp01
        .importzp pws_tmp02
        .importzp pws_tmp03

        .importzp data_ptr

        .import fuji_block_size
        .import fuji_buffer_addr
        .import fuji_file_offset
        .import fuji_read_block_data
        .import fuji_write_block_data
        .import remember_axy

        .include "fujinet.inc"

        .segment "CODE"

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; fuji_execute_block_rw - FujiNet block read/write
; On entry A=operation ($85=read, $A5=write)
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

fuji_execute_block_rw:
        ; Store operation type
        pha
        ; sta     fuji_operation_type

        ; Get buffer address from workspace (set by LoadFile_Ycatoffset)
        ; &BC-&BD contain the buffer address (load address)
        lda     aws_tmp12                ; &BC (buffer address low)
        sta     fuji_buffer_addr
        lda     aws_tmp13                ; &BD (buffer address high)
        sta     fuji_buffer_addr+1

        ; Get start sector from workspace variables (set by calc_buffer_sector_for_ptr)
        ; Channel buffer system uses pws_tmp02/pws_tmp03 for sector info
        lda     pws_tmp03               ; Start sector low byte
        sta     fuji_file_offset
        lda     pws_tmp02               ; Start sector high byte (mixed byte)
        sta     fuji_file_offset+1
        lda     #0
        sta     fuji_file_offset+2

        ; MMFS passes C0/C1/C2/C3 in the OSWORD-style block format:
        ; - C3/C2 bits 0-1 = start sector
        ; - C1 + C0        = transfer size for files / one sector for channel IO
        ;
        ; For the current FujiNet path we keep the 16-bit byte count in
        ; fuji_block_size. This covers normal DFS file loads and single-sector
        ; channel buffering.
        lda     pws_tmp00
        sta     fuji_block_size
        lda     pws_tmp01
        sta     fuji_block_size+1

        ; Execute network operation
        pla
        ; lda     fuji_operation_type
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
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

fuji_read_file_block:
        jsr     remember_axy

        ; Set data_ptr to point to the buffer address
        lda     fuji_buffer_addr
        sta     data_ptr
        lda     fuji_buffer_addr+1
        sta     data_ptr+1

        jsr     fuji_read_block_data
        bcs     @read_error
        lda     #$01
        rts

@read_error:
        lda     #$00
        rts

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; fuji_write_file_block - Write file block to network
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

fuji_write_file_block:
        jsr     remember_axy

        ; Set data_ptr to point to the buffer address
        lda     fuji_buffer_addr
        sta     data_ptr
        lda     fuji_buffer_addr+1
        sta     data_ptr+1

        jsr     fuji_write_block_data
        bcs     @write_error
        lda     #$01
        rts

@write_error:
        lda     #$00
        rts
