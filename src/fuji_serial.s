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
        .export fuji_execute_get_hosts
        .export fuji_execute_set_host_url_n
        .export fuji_execute_reset

        ; other functions for debug
        .export fuji_send_cf

        .import err_bad
        .import err_disk
        .import read_1
        .import remember_axy
        .import restore_output_to_screen
        .import setup_serial_19200

        .import _calc_checksum
        .import _read_serial_data
        .import _write_serial_data

        .include "fujinet.inc"

        .segment "CODE"

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; FUJI_READ_BLOCK_DATA - Read data block from FujiNet device
; Input: data_ptr points to buffer, other parameters in workspace
; Output: Data read into buffer, Carry=0 if success, Carry=1 if error
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

fuji_read_block_data:
        jsr     remember_axy

        ; TODO: Implement serial communication to read block
        ; 1. Send read command to FujiNet
        ; 2. Send block parameters (sector, count, etc.)
        ; 3. Receive data into buffer at data_ptr
        ; 4. Handle any errors

        ; For now, just return success
        clc
        rts

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; FUJI_WRITE_BLOCK_DATA - Write data block to FujiNet device
; Input: data_ptr points to buffer, other parameters in workspace
; Output: Carry=0 if success, Carry=1 if error
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

fuji_write_block_data:
        jsr     remember_axy

        ; TODO: Implement serial communication to write block
        ; 1. Send write command to FujiNet
        ; 2. Send block parameters (sector, count, etc.)
        ; 3. Send data from buffer at data_ptr
        ; 4. Handle any errors

        ; For now, just return success
        clc
        rts

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; fuji_read_catalog_DATA - Read catalog from FujiNet device
; Input: data_ptr points to 512-byte catalog buffer
; Output: Catalogue data in buffer, Carry=0 if success, Carry=1 if error
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

fuji_read_catalog_data:
        jsr     remember_axy

        ; TODO: Implement serial communication to read catalog
        ; 1. Send "GET_CATALOGUE" command to FujiNet
        ; 2. Receive 512-byte catalog data
        ; 3. Store in buffer at data_ptr (0x0E00)
        ; 4. Handle any errors

        ; For now, just return success
        clc
        rts

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; fuji_write_catalog_DATA - Write catalog to FujiNet device
; Input: data_ptr points to 512-byte catalog buffer
; Output: Carry=0 if success, Carry=1 if error
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

fuji_write_catalog_data:
        jsr     remember_axy

        ; TODO: Implement serial communication to write catalog
        ; 1. Send "PUT_CATALOGUE" command to FujiNet
        ; 2. Send 512-byte catalog data from buffer at data_ptr
        ; 3. Confirm successful update
        ; 4. Handle any errors

        ; For now, just return success
        clc
        rts

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; FUJI_READ_DISC_TITLE_DATA - Read disc title from FujiNet device
; Input: data_ptr points to 16-byte title buffer
; Output: Title data in buffer, Carry=0 if success, Carry=1 if error
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

fuji_read_disc_title_data:
        jsr     remember_axy

        ; TODO: Implement serial communication to read disc title
        ; 1. Send "GET_DISC_TITLE" command to FujiNet
        ; 2. Receive disc title string (up to 16 chars)
        ; 3. Store in buffer at data_ptr (0x1000)
        ; 4. Handle any errors

        ; For now, just return success
        clc
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
        rts


;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; fuji_execute_set_host_url_n - Set the Nth host URL
; values are pre-validated in cmd_fs_freset, 
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
fuji_execute_set_host_url_n:
        jsr     remember_axy

        ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
        ;; setup the data we are going to send before sending it
        ;; move the url to fuji_filename_buffer+1
        ldx     #$1F
@l1:
        lda     fuji_filename_buffer,x
        sta     fuji_filename_buffer+1,x
        dex
        bpl     @l1

        ; copy the host number to the start
        lda     current_host
        sta     fuji_filename_buffer

        ; now perform checksum on it
        lda     #<fuji_filename_buffer          ; buffer
        sta     aws_tmp00
        lda     #>fuji_filename_buffer
        sta     aws_tmp01
        lda     #33                             ; length
        sta     aws_tmp02
        lda     #$00
        sta     aws_tmp03
        jsr     _calc_checksum
        sta     fuji_filename_buffer + 33       ; write checksum to 34th byte

        ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
        ; now send data to fujinet
        ; SEND 2 BLOCKS OF DATA:
        ; 1. The Command block
        ;   CF: 70 9F 00 00 00 00 <chksum:10>
        lda     #<cmd_set_host_url_n_data
        ldx     #>cmd_set_host_url_n_data
        jsr     fuji_send_cf

        ; 2. The command data:
        ;   host     (1 byte)     from current_host
        ;   url      (32 bytes)   from fuji_filename_buffer
        ;   checksum (1 byte)

        lda     #<fuji_filename_buffer
        sta     aws_tmp00
        lda     #>fuji_filename_buffer
        sta     aws_tmp01
        lda     #34
        sta     aws_tmp02
        lda     #$00
        sta     aws_tmp03
        jmp     _write_serial_data

fuji_execute_get_hosts:
        jsr     remember_axy
        lda     #<cmd_get_hosts_data
        ldx     #>cmd_get_hosts_data
        jsr     fuji_send_cf

        ; start the reading cycle - WHERE THIS IS DONE NEEDS ADJUSTING
        ; absorb the ACK
        ; jsr     read_1
        ; cmp     #'A'
        ; bne     err_bad_response

        ; now read the results data into buffer
        ; Set up buffer pointer from aws_tmp12/13 to aws_tmp00/01
        lda     #<dfs_cat_s0_header
        sta     aws_tmp00       ; Buffer pointer low
        lda     #>dfs_cat_s0_header
        sta     aws_tmp01       ; Buffer pointer high

        ; length = 8x32 = 256 + 1 checksum + 2 "A/C" = $0103
        lda     #$03
        sta     aws_tmp02
        lda     #$01
        sta     aws_tmp03
        ; TODO: needs a better wrapper for reading serial, like _write_serial_data does
        jsr     setup_serial_19200
        jsr     _read_serial_data
        pha
        jsr     restore_output_to_screen
        pla

        ; On return, success status in A, 1 = ok, 0 = error
        beq     err_bad_response

        ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
        ;; THIS IS OPTIONAL, IF WE ARE TIGHT FOR ROM SPACE WE CAN
        ;; PROBABLY SKIP THIS VALIDATION - saves 37 bytes
        ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

        ; check the first byte is 'A'
        lda     dfs_cat_s0_header
        cmp     #'A'
        bne     err_bad_response

        ; validate the checksum in byte indexes 1 to 257
        lda     #<(dfs_cat_s0_header+1)          ; buffer
        sta     aws_tmp00
        lda     #>(dfs_cat_s0_header+1)
        sta     aws_tmp01
        lda     #$00                             ; 256 bytes to checksum
        sta     aws_tmp02
        lda     #$01
        sta     aws_tmp03
        jsr     _calc_checksum
        ; compare with checksum in byte 258
        cmp     dfs_cat_s0_header+257
        bne     err_bad_response

        ; validate the last byte is 'C'
        lda     dfs_cat_s0_header+258
        cmp     #'C'
        bne     err_bad_response

        lda     #$01
        rts

err_bad_response:
        jsr     restore_output_to_screen
        jsr     err_bad
        .byte   $CB                     ; again, not sure here
        .byte   "response", 0

fuji_execute_reset:
        jsr     remember_axy

        lda     #<cmd_reset_data
        ldx     #>cmd_reset_data
        ; fall through to fuji_send_cf

; INPUT: A/X set to table we are reading backwards from
fuji_send_cf:
        sta     aws_tmp00
        stx     aws_tmp01
        lda     #$07
        sta     aws_tmp02
        lda     #$00
        sta     aws_tmp03
        jmp     _write_serial_data

; data is sent as: DEVICE, CMD, AUX1..4, CHKSUM
cmd_reset_data:
        .byte $70, $FF, $00, $00, $00, $00, $70

cmd_set_host_url_n_data:
        .byte $70, $9F, $00, $00, $00, $00, $10

cmd_get_hosts_data:
        .byte $70, $F4, $00, $00, $00, $00, $65


.endif  ; FUJINET_INTERFACE_SERIAL
