; *FMOUNT — bind BBC drive to a sparse config-nio AppStore slot

        .export  cmd_fs_fmount
        .export  fmount_build_slot_prefix
        .export  fmount_update_mapping

        .export  mount_ok

        .importzp aws_tmp08
        .importzp cws_tmp2
        .importzp cws_tmp3
        .importzp cws_tmp6
        .importzp cws_tmp7

        .importzp buffer_ptr
        .importzp current_drv
        .importzp fuji_bus_tx_command
        .importzp fuji_bus_tx_device

        .import current_cat
        .import err_bad_mount_slot
        .import exit_user_ok
        .import fuji_channel_scratch
        .import fuji_current_fs_len
        .import fuji_disk_slot
        .import fuji_filename_buffer
        .import fuji_fs_uri_ptr
        .import fuji_begin_transaction
        .import fuji_end_transaction
        .import fuji_mount_disk
        .import fujibus_receive_packet
        .import fujibus_send_packet
        .import fujibus_set_payload_buffer_ptr
        .import num_params
        .import param_get_byte
        .import param_get_string
        .import param_optional_drive_no
        .import print_newline
        .import print_string_ax
        .import report_error

        .include "fujinet.inc"

        .segment "CODE"


; Allow drives 0-3
MAX_BBC_DRIVE  := 3

FMOUNT_FLAG_FORCE_RO := DISK_MOUNT_FLAG_READONLY
FMOUNT_SLOT_VALUE_MAX := FUJI_FS_URI_BUFFER_SIZE + 2

;------------------------------------------------------------------------------
; Main entry — same layout as cmd_fin.s (parse, FujiBus, exit_user_ok)
;------------------------------------------------------------------------------
cmd_fs_fmount:
        ; FMOUNT accepts:
        ;   *FMOUNT <slot>
        ;   *FMOUNT <slot> <drive>
        ;   *FMOUNT <slot> <drive> RO
        ; With no explicit mode, FMOUNT defaults to AUTO.

        jsr     num_params
        cmp     #$01
        bcc     err_fmount
        cmp     #$04
        bcs     err_fmount
        sta     cws_tmp7                ; number of params

        lda     #$00
        sta     fuji_channel_scratch    ; live mount flags, default AUTO

        jsr     param_get_byte          ; sparse slot index 0-255
        sta     fuji_disk_slot

        ; Optional drive present?
        lda     cws_tmp7
        cmp     #$02
        bcc     @check_mode

        jsr     param_optional_drive_no

@check_mode:
        lda     cws_tmp7
        cmp     #$03
        bne     @done

        clc
        jsr     param_get_string
        tax                             ; length
        cpx     #$02
        bne     err_fmount

        lda     fuji_filename_buffer
        and     #$DF                    ; uppercase
        cmp     #'R'
        bne     err_fmount
        lda     fuji_filename_buffer+1
        and     #$DF
        cmp     #'O'
        bne     err_fmount

        lda     #FMOUNT_FLAG_FORCE_RO
        sta     fuji_channel_scratch

@done:
        jsr     fmount_read_slot
        cmp     #$00
        bne     mount_ok
        jmp     fmount_slot_unallocated

mount_ok:
        ; put fs_uri location in cws_tmp2/3, do it before set_fuji_data_buffer_ptr
        jsr     fuji_fs_uri_ptr
        sta     cws_tmp2
        stx     cws_tmp3

        ; set buffer_ptr/aws_tmp00/01 to PWS location
        ; jsr     set_fuji_data_buffer_ptr

        ; AppStoreRead response payload begins at +7:
        ; +7 version, +8 flags, +15 dataLenLo, +16 dataLenHi,
        ; +17 record version, +18 record flags, +19 URI.
        ; The compact record is [version=1, bit0=readonly, URI bytes].
        ldy     #$10
        lda     (buffer_ptr),y
        bne     err_fmount
        dey                             ; y=$0F data length low
        lda     (buffer_ptr),y
        sec
        sbc     #$02
        tax                             ; URI length
        bne     fmount_ok

        ; fall through to error

err_fmount:
        jsr     report_error
        .byte   $CB
        .byte   "fmount", 0

fmount_ok:
        ; Apply the saved read-only mode unless the command already forced RO.
        ldy     #$12
        lda     (buffer_ptr),y
        and     #$01
        beq     fmount_copy_slot_uri
        lda     fuji_channel_scratch
        ora     #FMOUNT_FLAG_FORCE_RO
        sta     fuji_channel_scratch

fmount_copy_slot_uri:
        ; URI starts at response offset $13.
        lda     #$00
        ldy     #$00
        sta     (cws_tmp2),y
        sta     cws_tmp6                ; used as a scratch value for following loop
        lda     #$13
        sta     cws_tmp7

        cpx     #$00
        beq     @len_done

        ; copy X bytes from buffer_ptr+10 to fs_uri
@copy_uri:
        ldy     cws_tmp7
        lda     (buffer_ptr),y
        ldy     cws_tmp6
        sta     (cws_tmp2),y
        inc     cws_tmp6
        inc     cws_tmp7
        dex
        bne     @copy_uri

@len_done:
        lda     cws_tmp6
        sta     fuji_current_fs_len

        ; The BBC drive map addresses active DiskDevice slots, not catalog
        ; indexes.  The catalog slot has served its purpose once its URI has
        ; been resolved; bind this drive to its bounded runtime disk slot.
        lda     fuji_disk_slot
        pha                             ; retain catalog index for shared mapping state
        lda     current_drv
        sta     aws_tmp08
        sta     fuji_disk_slot

        lda     fuji_channel_scratch
        ora     #DISK_MOUNT_FLAG_LAZY
        jsr     fuji_mount_disk                         ; this uses "remember_xy_only" - can't rely on PLA to keep A set
        bcc     @mount_checked
        pla                             ; discard retained catalog index
        jmp     err_fmount

@mount_checked:
        ; Disk mount response payload: [7]=version [8]=flags
        ; bit1 on flags means effective read-only.
        ldy     #$08
        lda     (buffer_ptr),y
        and     #DISK_MOUNT_RESP_FLAG_READONLY
        beq     @save_mapping
        lda     fuji_channel_scratch
        ora     #DISK_MOUNT_FLAG_READONLY
        sta     fuji_channel_scratch

        lda     #<str_fmount_readonly
        ldx     #>str_fmount_readonly
        jsr     print_string_ax
        jsr     print_newline

@save_mapping:
        pla                             ; retained sparse catalog index
        tax
        lda     fuji_channel_scratch
        and     #DISK_MOUNT_FLAG_READONLY
        beq     @mapping_rw
        lda     #$03                    ; valid + read-only
        bne     @mapping_flags_ready
@mapping_rw:
        lda     #$01                    ; valid + AUTO/RW
@mapping_flags_ready:
        jsr     fmount_update_mapping
        bcc     @mount_success
        jmp     err_fmount

@mount_success:
        lda     #$FF
        sta     current_cat             ; invalidate cached catalog after remapping a drive
        jmp     exit_user_ok


str_fmount_readonly:
        .byte   "RO", 0
str_fmount_slot_unallocated:
        .byte   "No slot", 0

fmount_slot_unallocated:
        lda     #<str_fmount_slot_unallocated
        ldx     #>str_fmount_slot_unallocated
        jsr     print_string_ax
        jsr     print_newline
        jmp     exit_user_ok

; Read config-nio/slot-NNN via FileDevice AppStoreRead.
; Returns A=1 when the key exists and contains a valid compact slot record.
fmount_read_slot:
        jsr     fuji_begin_transaction
        jsr     fmount_read_slot_data
        pha
        jsr     fuji_end_transaction
        pla
        rts

fmount_read_slot_data:
        jsr     fmount_build_slot_prefix

        ; offset=0 (u32), maxBytes=FUJI_FS_URI_BUFFER_SIZE+2 (u16)
        lda     #$00
        ldx     #$04
@zero_offset:
        iny
        sta     (buffer_ptr),y
        dex
        bne     @zero_offset
        lda     #FMOUNT_SLOT_VALUE_MAX
        iny
        sta     (buffer_ptr),y
        lda     #$00
        iny
        sta     (buffer_ptr),y

        lda     #FN_DEVICE_FILE
        sta     fuji_bus_tx_device
        lda     #FILE_CMD_APPSTORE_READ
        sta     fuji_bus_tx_command
        jsr     fujibus_set_payload_buffer_ptr
        lda     #29
        ldx     #$00
        jsr     fujibus_send_packet
        jsr     fujibus_receive_packet
        tax
        beq     @not_found

        ; FujiBus status must be present and OK.
        ldy     #$05
        lda     (buffer_ptr),y
        cmp     #$01
        bne     @not_found
        iny
        lda     (buffer_ptr),y
        bne     @not_found

        ; AppStore response: version 1, exists flag, zero offset, data >= 3.
        iny                             ; y=$07
        lda     (buffer_ptr),y
        cmp     #FN_PROTOCOL_VERSION
        bne     @not_found
        iny
        lda     (buffer_ptr),y
        and     #$02
        beq     @not_found
        ldy     #$10
        lda     (buffer_ptr),y
        bne     @not_found
        dey
        lda     (buffer_ptr),y
        cmp     #$03
        bcc     @not_found
        ldy     #$11
        lda     (buffer_ptr),y
        cmp     #$01
        bne     @not_found
        lda     #$01
        rts

@not_found:
        lda     #$00
        rts

; Build the common AppStore request prefix for config-nio/slot-NNN.
; Leaves Y at the final key byte (request payload offset 22).
fmount_build_slot_prefix:
        ; version + namespace length
        lda     #FN_PROTOCOL_VERSION
        ldy     #$06
        sta     (buffer_ptr),y
        lda     #$0A                    ; "config-nio"
        iny
        sta     (buffer_ptr),y
        lda     #$00
        iny
        sta     (buffer_ptr),y

        ldx     #$00
@copy_namespace:
        lda     fmount_namespace,x
        iny
        sta     (buffer_ptr),y
        inx
        cpx     #$0A
        bne     @copy_namespace

        lda     #$08                    ; "slot-NNN"
        iny
        sta     (buffer_ptr),y
        lda     #$00
        iny
        sta     (buffer_ptr),y

        ldx     #$00
@copy_key_prefix:
        lda     fmount_key_prefix,x
        iny
        sta     (buffer_ptr),y
        inx
        cpx     #$05
        bne     @copy_key_prefix

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

fmount_namespace:
        .byte   "config-nio"
fmount_key_prefix:
        .byte   "slot-"

; Update one entry in config-nio/mappings.
; Binary v1 format: [version=1], then eight [flags, catalog-slot] pairs.
; Entry: A = flags (bit0 valid, bit1 readonly), X = catalog slot.
;        current_drv selects the pair to update.
; Exit:  C clear on success, set on failure.
fmount_update_mapping:
        pha                             ; retained flags
        txa
        pha                             ; retained catalog slot
        jsr     fuji_begin_transaction

        ; Read the fixed-size record so old/missing data can be initialized.
        jsr     fmount_build_mappings_prefix
        lda     #$00
        ldx     #$04
@read_offset:
        iny
        sta     (buffer_ptr),y
        dex
        bne     @read_offset
        lda     #$11                    ; 1 + 8 * 2 bytes
        iny
        sta     (buffer_ptr),y
        lda     #$00
        iny
        sta     (buffer_ptr),y
        lda     #FN_DEVICE_FILE
        sta     fuji_bus_tx_device
        lda     #FILE_CMD_APPSTORE_READ
        sta     fuji_bus_tx_command
        jsr     fujibus_set_payload_buffer_ptr
        lda     #$1D
        ldx     #$00
        jsr     fujibus_send_packet
        jsr     fujibus_receive_packet
        tax
        beq     @initialize
        ldy     #$05
        lda     (buffer_ptr),y
        cmp     #$01
        bne     @initialize
        iny
        lda     (buffer_ptr),y
        bne     @initialize
        ldy     #$08
        lda     (buffer_ptr),y
        and     #$02                    ; exists
        beq     @initialize
        ldy     #$10
        lda     (buffer_ptr),y
        bne     @initialize
        dey
        lda     (buffer_ptr),y
        cmp     #$11
        bne     @initialize
        ldy     #$11
        lda     (buffer_ptr),y
        cmp     #$01
        beq     @partial_write

@initialize:
        ; Remove an incompatible early-development text record.
        jsr     fmount_build_mappings_prefix
        lda     #FN_DEVICE_FILE
        sta     fuji_bus_tx_device
        lda     #FILE_CMD_APPSTORE_DELETE
        sta     fuji_bus_tx_command
        jsr     fujibus_set_payload_buffer_ptr
        lda     #$17
        ldx     #$00
        jsr     fujibus_send_packet
        jsr     fujibus_receive_packet

        ; Write a complete empty v1 map with the selected pair populated.
        jsr     fmount_build_mappings_prefix
        lda     #$00
        ldx     #$04
@init_offset:
        iny
        sta     (buffer_ptr),y
        dex
        bne     @init_offset
        lda     #$11
        iny
        sta     (buffer_ptr),y
        lda     #$00
        iny
        sta     (buffer_ptr),y
        iny                             ; first data byte
        lda     #$01
        sta     (buffer_ptr),y
        ldx     #$10
        lda     #$00
@zero_pairs:
        iny
        sta     (buffer_ptr),y
        dex
        bne     @zero_pairs

        lda     current_drv
        asl     a
        clc
        adc     #$24                    ; buffer+35 data, +1 flags
        tay
        tsx
        lda     $0102,x                 ; retained flags
        sta     (buffer_ptr),y
        iny
        lda     $0101,x                 ; retained catalog slot
        sta     (buffer_ptr),y

        lda     #FN_DEVICE_FILE
        sta     fuji_bus_tx_device
        lda     #FILE_CMD_APPSTORE_WRITE
        sta     fuji_bus_tx_command
        jsr     fujibus_set_payload_buffer_ptr
        lda     #$2E                    ; 29-byte prefix/write header + 17 data
        ldx     #$00
        jmp     @send_write

@partial_write:
        jsr     fmount_build_mappings_prefix
        lda     current_drv
        asl     a
        clc
        adc     #$01                    ; offset of this drive's flags
        iny
        sta     (buffer_ptr),y
        lda     #$00
        ldx     #$03
@partial_offset:
        iny
        sta     (buffer_ptr),y
        dex
        bne     @partial_offset
        lda     #$02
        iny
        sta     (buffer_ptr),y
        lda     #$00
        iny
        sta     (buffer_ptr),y
        tsx
        lda     $0102,x                 ; retained flags
        iny
        sta     (buffer_ptr),y
        lda     $0101,x                 ; retained catalog slot
        iny
        sta     (buffer_ptr),y

        lda     #FN_DEVICE_FILE
        sta     fuji_bus_tx_device
        lda     #FILE_CMD_APPSTORE_WRITE
        sta     fuji_bus_tx_command
        jsr     fujibus_set_payload_buffer_ptr
        lda     #$1F                    ; 29-byte prefix/write header + 2 data
        ldx     #$00

@send_write:
        jsr     fujibus_send_packet
        jsr     fujibus_receive_packet
        tax
        beq     @mapping_failed
        ldy     #$05
        lda     (buffer_ptr),y
        cmp     #$01
        bne     @mapping_failed
        iny
        lda     (buffer_ptr),y
        bne     @mapping_failed
        jsr     fuji_end_transaction
        pla
        pla
        clc
        rts

@mapping_failed:
        jsr     fuji_end_transaction
        pla
        pla
        sec
        rts

; Build AppStore request prefix for config-nio/mappings.
; Leaves Y at the final key byte.
fmount_build_mappings_prefix:
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
        lda     fmount_namespace,x
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
        lda     fmount_mappings_key,x
        iny
        sta     (buffer_ptr),y
        inx
        cpx     #$08
        bne     @copy_key
        rts

fmount_mappings_key:
        .byte   "mappings"
