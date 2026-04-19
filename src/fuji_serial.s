; FujiNet serial interface implementation
; Low-level communication with FujiNet device via serial port
; This implements the data layer functions called by fuji_fs.s and fuji_cmds.s
; Only compiled when FUJI_INTERFACE_SERIAL is defined

; Only compile this file if SERIAL interface is selected
.ifdef FUJINET_INTERFACE_SERIAL

        .export err_bad_response

        .export fuji_mount_disk_data
        .export fuji_set_mount_slot_data
        .export fuji_get_mount_slot_data
        .export fuji_read_block_data
        .export fuji_read_catalog_data
        .export fuji_read_disc_title_data
        .export fuji_write_catalog_data
        .export fuji_write_block_data

        ; FUJI functions
        ; .export fuji_execute_get_hosts
        ; .export fuji_execute_set_host_url_n
        ; .export fuji_execute_reset

        ; other functions for debug
        ; .export fuji_send_cf

        .import err_bad
        .import remember_axy
        .import restore_output_to_screen


        ; Import FujiBus C functions - use underscore prefix for C calls
        .import _fujibus_disk_mount
        .import _fujibus_set_mount_slot
        .import _fujibus_get_mount_slot
        .import _fujibus_disk_read_sector
        .import _fujibus_disk_read_sector_partial
        .import _fujibus_disk_write_sector


        .include "fujinet.inc"

        .segment "CODE"

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; FUJI_READ_BLOCK_DATA - Read data block from FujiNet device
; Input: data_ptr points to buffer, other parameters in workspace
; Output: Data read into buffer, Carry=0 if success, Carry=1 if error
;
; This should only be called via fuji_read_block, which starts a
; transaction, and sets the buffer_ptr, otherwise you have to ensure
; buffer_ptr is setup correctly first. That is the start of PWS ($1700)
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

fuji_read_block_data:
        jsr     remember_axy

        ; C3/C2 carries the DFS start sector. The low two bits of the mixed
        ; byte are the upper sector bits; the upper nibble encodes file length
        ; high bits, which we currently ignore here.
        lda     fuji_file_offset
        sta     fuji_current_sector
        lda     fuji_file_offset+1
        and     #$03
        sta     fuji_current_sector+1

        ; fuji_block_size holds the byte count for this transfer.
        ; High byte = number of full 256-byte sectors.
        ; Low byte  = trailing partial sector bytes.
        lda     fuji_block_size
        sta     aws_tmp14
        lda     fuji_block_size+1
        sta     aws_tmp15

@read_full_sector:
        lda     aws_tmp15
        beq     @read_partial_sector

        jsr     _fujibus_disk_read_sector
        cmp     #$01
        bne     @read_error

        inc     fuji_current_sector
        bne     :+
        inc     fuji_current_sector+1
:
        inc     data_ptr+1
        dec     aws_tmp15
        bne     @read_full_sector

@read_partial_sector:
        lda     aws_tmp14
        beq     @read_success

        ; Payload is decoded into PWS at buffer_ptr; copy only the trailing
        ; aws_tmp14 bytes from packet offset 18 into data_ptr (see
        ; _fujibus_disk_read_sector_partial).
        jsr     _fujibus_disk_read_sector_partial
        cmp     #$01
        bne     @read_error

@read_success:
        lda     #$01
        clc
        rts

@read_error:
        lda     #$00
        sec
        rts

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; FUJI_WRITE_BLOCK_DATA - Write data block to FujiNet device
; Input: data_ptr points to buffer, other parameters in workspace
; Output: Carry=0 if success, Carry=1 if error
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

fuji_write_block_data:
        jsr     remember_axy

        lda     fuji_file_offset
        sta     fuji_current_sector
        lda     fuji_file_offset+1
        and     #$03
        sta     fuji_current_sector+1

        lda     fuji_block_size
        sta     aws_tmp14
        lda     fuji_block_size+1
        sta     aws_tmp15

@write_full_sector:
        lda     aws_tmp15
        beq     @write_partial_sector

        jsr     _fujibus_disk_write_sector
        cmp     #$01
        bne     @write_error

        inc     fuji_current_sector
        bne     :+
        inc     fuji_current_sector+1
:
        inc     data_ptr+1
        dec     aws_tmp15
        bne     @write_full_sector

@write_partial_sector:
        lda     aws_tmp14
        beq     @write_success

        ; Preserve the caller's partial buffer pointer while we stage a full
        ; sector for read/modify/write.
        lda     data_ptr
        sta     aws_tmp08
        lda     data_ptr+1
        sta     aws_tmp09

        lda     #<dfs_cat_s0_header
        sta     data_ptr
        lda     #>dfs_cat_s0_header
        sta     data_ptr+1

        jsr     _fujibus_disk_read_sector
        cmp     #$01
        bne     @write_error

        ldy     #$00
@copy_partial:
        lda     (aws_tmp08),y
        sta     dfs_cat_s0_header,y
        iny
        cpy     aws_tmp14
        bne     @copy_partial

        jsr     _fujibus_disk_write_sector
        cmp     #$01
        bne     @write_error

@write_success:
        lda     #$01
        clc
        rts

@write_error:
        lda     #$00
        sec
        rts

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; fuji_read_catalog_DATA - Read catalog from FujiNet device
; Input: data_ptr points to 512-byte catalog buffer
; Output: Catalogue data in buffer, Carry=0 if success, Carry=1 if error
;
; The catalog is stored in sectors 0 and 1 of the disk.
; We read both sectors and combine them.
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

fuji_read_catalog_data:
        ; Read sector 0 (first 256 bytes of catalog)
        lda     #$00
        sta     fuji_current_sector
        sta     fuji_current_sector+1

        ; Call C function to read sector - it uses global state:
        ; - fuji_disk_slot (set by caller)
        ; - fuji_current_sector (set above)
        ; - data_ptr (set by caller)
        jsr     _fujibus_disk_read_sector
        ; check the return value in A, 1 = success
        cmp     #$01
        bne     @read_error

        ; Read sector 1 (second 256 bytes of catalog)
        inc     fuji_current_sector
        bne     :+
        inc     fuji_current_sector+1
:
        ; Advance buffer pointer by 256
        inc     data_ptr+1

        jsr     _fujibus_disk_read_sector
        ; check the return value in A, 1 = success
        cmp     #$01
        bne     @read_error

        clc
        rts

@read_error:
        sec
        rts


;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; fuji_write_catalog_DATA - Write catalog to FujiNet device
; Input: data_ptr points to 512-byte catalog buffer
; Output: Carry=0 if success, Carry=1 if error
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

fuji_write_catalog_data:
        lda     #$00
        sta     fuji_current_sector
        sta     fuji_current_sector+1

        lda     #$00
        sta     aws_tmp14

        jsr     _fujibus_disk_write_sector
        cmp     #$01
        beq     :+
        inc     aws_tmp14
:

        inc     fuji_current_sector
        bne     :+
        inc     fuji_current_sector+1
:
        inc     data_ptr+1

        jsr     _fujibus_disk_write_sector
        cmp     #$01
        beq     :+
        inc     aws_tmp14
:

        lda     aws_tmp14
        bne     @write_error

        clc
        rts

@write_error:
        sec
        rts

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; FUJI_READ_DISC_TITLE_DATA - Read disc title from FujiNet device
; Input: data_ptr points to 16-byte title buffer
; Output: Title data in buffer, Carry=0 if success, Carry=1 if error
;
; The disc title is stored in:
; - Sector 0, bytes 0-7 (first 8 chars)
; - Sector 1, bytes 0-3 (last 4 chars)
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

fuji_read_disc_title_data:
        ; jsr     remember_axy
        rts

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; fuji_mount_disk_data - Mount disk image into drive (hardware implementation)
;
; For serial/userport: This would send MOUNT command to FujiNet device
;
; Entry: current_drv = drive number (0-3)
;        aws_tmp08/09 = disk image number to mount
; Exit:  Nothing (mapping already recorded by caller)
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

fuji_mount_disk_data:
        ; Mount disk using FujiBus - call the C function
        ; aws_tmp08 contains the slot number (already set by caller)
        ; FUJI_CURRENT_FS_URI contains the URI (already set by cmd_fmount_c.c)
        ; Call the C function - pass flags in A (0 = read-write)
        lda     #$00
        jsr     _fujibus_disk_mount
        rts

;//////////////////////////////////////////////////////////////////////
; fuji_set_mount_slot_data - Set mount record for a slot (data layer)
; Calls the C function fujibus_set_mount_slot()
;//////////////////////////////////////////////////////////////////////

fuji_set_mount_slot_data:
        jsr     _fujibus_set_mount_slot
        rts

;//////////////////////////////////////////////////////////////////////
; fuji_get_mount_slot_data - Get mount record for a slot (data layer)
; Calls the C function fujibus_get_mount_slot()
;//////////////////////////////////////////////////////////////////////

fuji_get_mount_slot_data:
        jsr     _fujibus_get_mount_slot
        rts

err_bad_response:
        jsr     restore_output_to_screen
        jsr     err_bad
        .byte   $CB                     ; again, not sure here
        .byte   "response", 0


.endif  ; FUJINET_INTERFACE_SERIAL
