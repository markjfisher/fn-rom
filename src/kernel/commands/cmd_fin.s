; *FIN — resolve and persist a path/URI in the Slot Catalog
; Default persisted policy is AUTO; live mount behavior is chosen by *FMOUNT.

        .export  cmd_fs_fin

        .export  err_no_host
        .export  err_bad_mount_slot

        .importzp buffer_ptr
        .importzp fuji_bus_tx_command
        .importzp fuji_bus_tx_device

        .import err_bad
        .import exit_user_ok
        .import fuji_begin_transaction
        .import fuji_disk_slot
        .import fuji_end_transaction
        .import fuji_filename_buffer
        .import fuji_filename_len
        .import fujibus_receive_packet
        .import fujibus_send_packet
        .import fujibus_set_payload_buffer_ptr
        .import param_count_a
        .import param_get_byte
        .import param_get_string
        .import report_error

        .include "fujinet.inc"

        .segment "CODE"

;------------------------------------------------------------------------------
; uint8_t cmd_fs_fin(void)
;------------------------------------------------------------------------------
cmd_fs_fin:
        ; parse parameters
        lda     #$80
        jsr     param_count_a
        bcc     @one_param_only

        jsr     param_get_byte

@ok_slot:
        sta     fuji_disk_slot
        jmp     @read_filename

@one_param_only:
        lda     #$00
        sta     fuji_disk_slot

@read_filename:
        clc
        jsr     param_get_string
        sta     fuji_filename_len

        jsr     fin_write_slot
        bcs     @set_ok

        jsr     report_error
        .byte   $CB
        .byte   "mount", 0

@set_ok:
        jmp     exit_user_ok


err_bad_mount_slot:
        ; this terminates command because the byte after the string is 0
        jsr     err_bad
        .byte   $CB                     ; TODO sort out what error codes we want to return
        .byte   "mount slot", 0         ; terminate after message
;------------------------------------------------------------------------------
err_no_host:
        jsr     report_error
        .byte   $CB
        .byte   "No host", 0

; Ask the Slot Catalog service to resolve the target against the current host
; and replace this entry with the resulting canonical URI.
; Carry set indicates success.
;------------------------------------------------------------------------------
fin_write_slot:
        jsr     fuji_begin_transaction

        ; Put request: version, index, flags, target length (u16), target.
        ldy     #$06
        lda     #FN_PROTOCOL_VERSION
        sta     (buffer_ptr),y
        iny
        lda     fuji_disk_slot
        sta     (buffer_ptr),y
        iny
        lda     #$00                    ; AUTO/RW
        sta     (buffer_ptr),y
        iny
        lda     fuji_filename_len
        sta     (buffer_ptr),y
        iny
        lda     #$00
        sta     (buffer_ptr),y

        ldx     #$00
@copy_target:
        cpx     fuji_filename_len
        beq     @send_write
        lda     fuji_filename_buffer,x
        iny
        sta     (buffer_ptr),y
        inx
        bne     @copy_target

@send_write:
        lda     #FN_DEVICE_SLOT_CATALOG
        sta     fuji_bus_tx_device
        lda     #SLOT_CATALOG_CMD_PUT
        sta     fuji_bus_tx_command
        jsr     fujibus_set_payload_buffer_ptr
        lda     fuji_filename_len
        clc
        adc     #5
        ldx     #$00
        jsr     fujibus_send_packet
        jsr     fujibus_receive_packet
        tax
        beq     @failed
        ldy     #$05
        lda     (buffer_ptr),y
        cmp     #$01
        bne     @failed
        iny
        lda     (buffer_ptr),y
        bne     @failed
        jsr     fuji_end_transaction
        sec
        rts

@failed:
        jsr     fuji_end_transaction
        clc
        rts

;------------------------------------------------------------------------------
; void parse_fin_params(void)
; 1 arg: filename only → fuji_disk_slot = 0
; 2 args: slot then filename (slot 0–255)
;------------------------------------------------------------------------------
parse_fin_params:
        lda     #$80
        jsr     param_count_a

        bcc     @one_param_only

        jsr     param_get_byte

@ok_slot:
        sta     fuji_disk_slot
        jmp     @read_filename

@one_param_only:
        lda     #$00
        sta     fuji_disk_slot

@read_filename:
        clc
        jsr     param_get_string
        sta     fuji_filename_len
        rts
