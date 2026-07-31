        .export cmd_fs_fout

        .importzp buffer_ptr
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
; This removes the sparse Slot Catalog entry. Active BBC drive mappings
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
        ldy     #$06
        lda     #FN_PROTOCOL_VERSION
        sta     (buffer_ptr),y
        iny
        lda     fuji_disk_slot
        sta     (buffer_ptr),y
        lda     #FN_DEVICE_SLOT_CATALOG
        sta     fuji_bus_tx_device
        lda     #SLOT_CATALOG_CMD_DELETE
        sta     fuji_bus_tx_command
        jsr     fujibus_set_payload_buffer_ptr
        lda     #2
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
