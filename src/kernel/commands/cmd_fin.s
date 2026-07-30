; *FIN — persist URI/path into sparse config-nio AppStore slot
; Default persisted policy is AUTO; live mount behavior is chosen by *FMOUNT.

        .export  cmd_fs_fin

        .export  err_no_host
        .export  err_bad_mount_slot

        .importzp aws_tmp00
        .importzp aws_tmp01
        .importzp buffer_ptr
        .importzp cws_tmp2
        .importzp cws_tmp3
        .importzp fuji_bus_tx_command
        .importzp fuji_bus_tx_device

        .import err_bad
        .import exit_user_ok
        .import fmount_build_slot_prefix
        .import fuji_begin_transaction
        .import fuji_channel_scratch
        .import fuji_current_fs_len
        .import fuji_disk_slot
        .import fuji_end_transaction
        .import fuji_filename_buffer
        .import fuji_filename_len
        .import fuji_fs_uri_ptr
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

        jsr     fin_resolve_target
        bcs     err_no_host
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

; Resolve the user path/URI against FujiNet's current host and copy the
; canonical URI into the PWS FS buffer.
; Carry set indicates that the target could not be resolved.
;------------------------------------------------------------------------------
fin_resolve_target:
        jsr     fuji_begin_transaction

        ldy     #$06
        lda     #FN_PROTOCOL_VERSION
        sta     (buffer_ptr),y
        iny
        lda     fuji_filename_len
        sta     (buffer_ptr),y
        iny
        lda     #$00
        sta     (buffer_ptr),y
        iny
        ldx     #$00
@copy_request:
        cpx     fuji_filename_len
        beq     @send
        lda     fuji_filename_buffer,x
        sta     (buffer_ptr),y
        iny
        inx
        bne     @copy_request
@send:
        lda     #FN_DEVICE_HOST
        sta     fuji_bus_tx_device
        lda     #HOST_CMD_RESOLVE_TARGET
        sta     fuji_bus_tx_command
        jsr     fujibus_set_payload_buffer_ptr
        lda     fuji_filename_len
        clc
        adc     #$03
        ldx     #$00
        jsr     fujibus_send_packet
        jsr     fujibus_receive_packet

        cpx     #$00
        bne     @check_status
        cmp     #$0A
        bcc     @failed
@check_status:
        ldy     #$05
        lda     (buffer_ptr),y
        cmp     #$01
        bne     @failed
        iny
        lda     (buffer_ptr),y
        bne     @failed
        ldy     #$07
        lda     (buffer_ptr),y
        cmp     #FN_PROTOCOL_VERSION
        bne     @failed
        ldy     #$09
        lda     (buffer_ptr),y
        bne     @failed
        dey
        lda     (buffer_ptr),y
        beq     @failed
        cmp     #(FUJI_FS_URI_BUFFER_SIZE + 1)
        bcs     @failed
        sta     fuji_current_fs_len

        jsr     fuji_fs_uri_ptr
        sta     cws_tmp2
        stx     cws_tmp3

        lda     buffer_ptr
        clc
        adc     #$0A
        sta     aws_tmp00
        lda     buffer_ptr+1
        adc     #$00
        sta     aws_tmp01

        ldx     fuji_current_fs_len
        ldy     #$00
@copy_uri:
        lda     (aws_tmp00),y
        sta     (cws_tmp2),y
        iny
        dex
        bne     @copy_uri

        lda     #$00
        sta     (cws_tmp2),y
        jsr     fuji_end_transaction
        clc
        rts

@failed:
        jsr     fuji_end_transaction
        sec
        rts

;------------------------------------------------------------------------------
; Replace config-nio/slot-NNN with [version=1, flags=rw, URI bytes].
; Carry set indicates success.
;------------------------------------------------------------------------------
fin_write_slot:
        jsr     fuji_begin_transaction

        ; AppStore writes do not truncate, so remove an older longer record.
        jsr     fmount_build_slot_prefix
        lda     #FN_DEVICE_FILE
        sta     fuji_bus_tx_device
        lda     #FILE_CMD_APPSTORE_DELETE
        sta     fuji_bus_tx_command
        jsr     fujibus_set_payload_buffer_ptr
        lda     #23
        ldx     #$00
        jsr     fujibus_send_packet
        jsr     fujibus_receive_packet

        ; Rebuild the prefix because the response replaced the request buffer.
        jsr     fmount_build_slot_prefix

        ; offset=0 (u32), data length=URI length+2 (u16)
        lda     #$00
        ldx     #$04
@zero_offset:
        iny
        sta     (buffer_ptr),y
        dex
        bne     @zero_offset
        lda     fuji_current_fs_len
        clc
        adc     #$02
        iny
        sta     (buffer_ptr),y
        lda     #$00
        iny
        sta     (buffer_ptr),y

        ; Compact slot record version and flags (AUTO/RW).
        lda     #$01
        iny
        sta     (buffer_ptr),y
        lda     #$00
        iny
        sta     (buffer_ptr),y

        ; Copy URI from the per-command workspace.
        lda     #$00
        sta     aws_tmp00
@copy_uri:
        lda     aws_tmp00
        cmp     fuji_current_fs_len
        beq     @send_write
        tay
        lda     (cws_tmp2),y
        pha
        tya
        clc
        ; buffer_ptr includes the six-byte FujiBus header. The AppStore write
        ; payload is 29 bytes before the record, then version+flags precede
        ; the URI: buffer offset 6 + 29 + 2 = 37.
        adc     #37
        tay
        pla
        sta     (buffer_ptr),y
        inc     aws_tmp00
        bne     @copy_uri

@send_write:
        lda     #FN_DEVICE_FILE
        sta     fuji_bus_tx_device
        lda     #FILE_CMD_APPSTORE_WRITE
        sta     fuji_bus_tx_command
        jsr     fujibus_set_payload_buffer_ptr
        lda     fuji_current_fs_len
        clc
        adc     #31
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
