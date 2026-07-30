        .export cmd_fs_fout

        .importzp buffer_ptr
        .importzp cws_tmp6
        .importzp fuji_bus_tx_command
        .importzp fuji_bus_tx_device

        .import err_syntax
        .import exit_user_ok
        .import fuji_begin_transaction
        .import fuji_disk_slot
        .import fuji_end_transaction
        .import fujibus_receive_packet
        .import fujibus_send_packet
        .import fujibus_set_payload_buffer_ptr
        .import param_count
        .import param_get_byte
        .import report_error

        .include "fujinet.inc"

        ; Registration is local to the transient boot-disk utility binary;
        ; there is no resident command-table entry.
        cmd_entry "FUTILS_EXT", "OUT",     $A, $00, cmd_fs_fout      ; <slot>

        .segment "CODE"

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; cmd_fs_fout - Handle *FOUT command
;
; Syntax:
;   *FOUT <slot>
;
; This removes the sparse config-nio AppStore entry. Active BBC drive mappings
; are independent runtime state and are removed with *FUMOUNT <drive>.
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

cmd_fs_fout:
        jsr     param_count
        bcs     valid_count             ; 1 arg
        jmp     err_syntax

valid_count:
        jsr     param_get_byte
        sta     fuji_disk_slot

        jsr     fuji_begin_transaction
        jsr     fout_build_slot_prefix
        lda     #FN_DEVICE_FILE
        sta     fuji_bus_tx_device
        lda     #FILE_CMD_APPSTORE_DELETE
        sta     fuji_bus_tx_command
        jsr     fujibus_set_payload_buffer_ptr
        lda     #23
        ldx     #$00
        jsr     fujibus_send_packet
        jsr     fujibus_receive_packet
        tax
        beq     @delete_failed

        ldy     #$05
        lda     (buffer_ptr),y
        cmp     #$01
        bne     @delete_failed
        iny
        lda     (buffer_ptr),y
        bne     @delete_failed

        jsr     fuji_end_transaction
        jmp     exit_user_ok

@delete_failed:
        jsr     fuji_end_transaction
err_fout:
        jsr     report_error
        .byte   $CB
        .byte   "FOUT err", 0

; Build AppStore request prefix for config-nio/slot-NNN.
; Leaves Y at buffer offset 28, the final key byte.
fout_build_slot_prefix:
        lda     #FN_PROTOCOL_VERSION
        ldy     #$06
        sta     (buffer_ptr),y
        lda     #$0A
        iny
        sta     (buffer_ptr),y
        lda     #$00
        iny
        sta     (buffer_ptr),y

        ldx     #$00
@copy_namespace:
        lda     fout_namespace,x
        iny
        sta     (buffer_ptr),y
        inx
        cpx     #$0A
        bne     @copy_namespace

        lda     #$08
        iny
        sta     (buffer_ptr),y
        lda     #$00
        iny
        sta     (buffer_ptr),y

        ldx     #$00
@copy_key:
        lda     fout_key_prefix,x
        iny
        sta     (buffer_ptr),y
        inx
        cpx     #$05
        bne     @copy_key

        lda     fuji_disk_slot
        sta     cws_tmp6
        ldx     #'0'
@hundreds:
        lda     cws_tmp6
        cmp     #100
        bcc     @hundreds_done
        sbc     #100
        sta     cws_tmp6
        inx
        bne     @hundreds
@hundreds_done:
        txa
        iny
        sta     (buffer_ptr),y

        ldx     #'0'
@tens:
        lda     cws_tmp6
        cmp     #10
        bcc     @tens_done
        sbc     #10
        sta     cws_tmp6
        inx
        bne     @tens
@tens_done:
        txa
        iny
        sta     (buffer_ptr),y
        lda     cws_tmp6
        clc
        adc     #'0'
        iny
        sta     (buffer_ptr),y
        rts

fout_namespace:
        .byte   "config-nio"
fout_key_prefix:
        .byte   "slot-"
