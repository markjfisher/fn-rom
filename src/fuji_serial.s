; FujiNet serial interface implementation
; Low-level communication with FujiNet device via serial port
; This implements the data layer functions called by fuji_fs.s and fuji_cmds.s
; Only compiled when FUJI_INTERFACE_SERIAL is defined

; Only compile this file if SERIAL interface is selected
.ifdef FUJINET_INTERFACE_SERIAL

        .export err_bad_response

        .export fuji_mount_disk_data
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
        .import err_disk
        .import read_1
        .import remember_axy
        .import restore_output_to_screen
        .import setup_serial_19200

        .import _calc_checksum
        .import _read_serial_data
        .import _write_serial_data

        ; Import FujiBus functions
        ; .import fn_disk_read_sector_impl
        ; .import fn_disk_write_sector_impl

        .include "fujinet.inc"

        .segment "CODE"

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; FUJI_READ_BLOCK_DATA - Read data block from FujiNet device
; Input: data_ptr points to buffer, other parameters in workspace
; Output: Data read into buffer, Carry=0 if success, Carry=1 if error
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

fuji_read_block_data:
        jsr     remember_axy

        ; Use FujiBus disk read sector
        ; jsr     fn_disk_read_sector_impl

        ; Return status in carry
        rts

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; FUJI_WRITE_BLOCK_DATA - Write data block to FujiNet device
; Input: data_ptr points to buffer, other parameters in workspace
; Output: Carry=0 if success, Carry=1 if error
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

fuji_write_block_data:
        jsr     remember_axy

        ; Use FujiBus disk write sector
        ; jsr     fn_disk_write_sector_impl

        ; Return status in carry
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
        jsr     remember_axy
        rts

;         ; Read sector 0 (first 256 bytes of catalog)
;         ; Set LBA = 0
;         lda     #$00
;         sta     fuji_current_sector
;         sta     fuji_current_sector+1

;         ; Set buffer pointer
;         lda     data_ptr
;         sta     aws_tmp08
;         lda     data_ptr+1
;         sta     aws_tmp09

;         jsr     fn_disk_read_sector_impl
;         bcs     @read_error

;         ; Read sector 1 (second 256 bytes of catalog)
;         inc     fuji_current_sector

;         ; Advance buffer pointer by 256
;         inc     aws_tmp09

;         jsr     fn_disk_read_sector_impl
;         bcs     @read_error

;         clc
;         rts

; @read_error:
;         sec
;         rts

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; fuji_write_catalog_DATA - Write catalog to FujiNet device
; Input: data_ptr points to 512-byte catalog buffer
; Output: Carry=0 if success, Carry=1 if error
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

fuji_write_catalog_data:
        jsr     remember_axy
        rts

;         ; Write sector 0 (first 256 bytes of catalog)
;         lda     #$00
;         sta     fuji_current_sector
;         sta     fuji_current_sector+1

;         ; Set buffer pointer
;         lda     data_ptr
;         sta     aws_tmp08
;         lda     data_ptr+1
;         sta     aws_tmp09

;         jsr     fn_disk_write_sector_impl
;         bcs     @write_error

;         ; Write sector 1 (second 256 bytes of catalog)
;         inc     fuji_current_sector

;         ; Advance buffer pointer by 256
;         inc     aws_tmp09

;         jsr     fn_disk_write_sector_impl
;         bcs     @write_error

;         clc
;         rts

; @write_error:
;         sec
;        rts

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
        jsr     remember_axy
        rts

;         ; Read sector 0
;         lda     #$00
;         sta     fuji_current_sector
;         sta     fuji_current_sector+1

;         ; Use a temporary buffer
;         lda     #<dfs_cat_s0_header
;         sta     aws_tmp08
;         lda     #>dfs_cat_s0_header
;         sta     aws_tmp09

;         jsr     fn_disk_read_sector_impl
;         bcs     @title_error

;         ; Copy first 8 bytes to title buffer
;         ldy     #$07
; @copy_first:
;         lda     dfs_cat_s0_header,y
;         sta     (data_ptr),y
;         dey
;         bpl     @copy_first

;         ; Read sector 1
;         inc     fuji_current_sector
;         jsr     fn_disk_read_sector_impl
;         bcs     @title_error

;         ; Copy bytes 0-3 to title buffer positions 8-11
;         ldy     #$03
; @copy_second:
;         lda     dfs_cat_s0_header,y
;         sta     (data_ptr),y
;         dey
;         bpl     @copy_second

;         clc
;         rts

; @title_error:
;         sec
;         rts

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
        ; TODO: Implement FujiBus disk mount
        ; This needs to send a Mount command with the disk image path
        ; For now, just return success
        rts


err_bad_response:
        jsr     restore_output_to_screen
        jsr     err_bad
        .byte   $CB                     ; again, not sure here
        .byte   "response", 0


.endif  ; FUJINET_INTERFACE_SERIAL
