; FujiNet disk mounting interface
; Implements drive-to-disk-image mapping (like MMFS *DIN command)
; This is part of the Hardware Interface Layer (fuji_fs.s equivalent)

        .export fuji_clear_slot
        .export fuji_create_disk
        .export fuji_get_slot
        .export fuji_mount_disk
        .export fuji_set_disk_slot_from_mapping_or_error
        .export fuji_set_slot
        .export fuji_unmount_disk

        .importzp aws_tmp08

        .importzp current_drv

        .import fuji_begin_transaction
        .import fuji_clear_mount_slot_data
        .import fuji_create_disk_data
        .import fuji_disk_slot
        .import fuji_drive_disk_map
        .import fuji_end_transaction
        .import fuji_get_mount_slot_data
        .import fuji_mount_disk_data
        .import fuji_unmount_disk_data
        .import fuji_set_mount_slot_data
        .import remember_xy_only

        .include "fujinet.inc"

        .segment "CODE"

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; fuji_create_disk - Create a disk image using the current FS URI
;
; Entry: A = create flags
;        fuji_current_fs_len / PWS FS URI buffer already populated
; Exit:  A = bool (1 = success, 0 = failure)
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

fuji_create_disk:
        jsr     remember_xy_only
        pha                             ; Save create flags from caller

        jsr     fuji_begin_transaction  ; Protect &BC-&CB
        pla                             ; Restore create flags for hardware-specific create
        jsr     fuji_create_disk_data
        pha                             ; Save return value (bool)
        jsr     fuji_end_transaction    ; Restore &BC-&CB
        pla                             ; Restore return value
        rts

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; fuji_mount_disk - Mount disk image into drive
; This is the high-level interface that manages transactions
;
; Entry: current_drv = drive number (0-3)
;        aws_tmp08 = disk image number to mount
; Exit:  Disk image mounted (mapping recorded)
;        A, X, Y may be modified
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

fuji_mount_disk:
        jsr     remember_xy_only
        pha                             ; Save live mount flags from caller
        
        ; Record the mapping: fuji_drive_disk_map[current_drv] = disk_num
        ldx     current_drv
        lda     aws_tmp08               ; Low byte of disk number
        sta     fuji_drive_disk_map,x
        
        ; Call hardware-specific mount implementation
        jsr     fuji_begin_transaction  ; Protect &BC-&CB
        pla                             ; Restore live mount flags for hardware-specific mount
        jsr     fuji_mount_disk_data
        pha                             ; Save return value (bool)
        jsr     fuji_end_transaction    ; Restore &BC-&CB
        pla                             ; Restore return value
        
        rts

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; fuji_unmount_disk - Unmount disk from drive
;
; Entry: current_drv = drive number (0-3)
; Exit:  Disk unmounted (mapping cleared)
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

fuji_unmount_disk:
        jsr     remember_xy_only

        ldx     current_drv
        lda     fuji_drive_disk_map,x
        sta     fuji_disk_slot

        jsr     fuji_begin_transaction
        jsr     fuji_unmount_disk_data
        pha
        jsr     fuji_end_transaction

        ldx     current_drv
        lda     #$FF                    ; $FF = no disk mounted
        sta     fuji_drive_disk_map,x
        pla
        rts

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; fuji_set_disk_slot_from_mapping_or_error - Get which fujinet SLOT is mounted in current drive
; N=1 means no slot was set in mappings, fuji_disk_slot was set to FF
; N=0 means fuji_disk_slot was correctly set
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

fuji_set_disk_slot_from_mapping_or_error:
        ldx     current_drv
        lda     fuji_drive_disk_map,x
        sta     fuji_disk_slot                  ; this will change to FF if no slot from FIN
        rts

;//////////////////////////////////////////////////////////////////////
; fuji_clear_slot - Clear persisted mount record for a slot
; Entry: fuji_disk_slot = slot number (0-7)
; Exit:  A contains success code as a bool (1 = true)
;//////////////////////////////////////////////////////////////////////

fuji_clear_slot:
        jsr     remember_xy_only
        jsr     fuji_begin_transaction
        jsr     fuji_clear_mount_slot_data
        pha
        jsr     fuji_end_transaction
        pla
        rts

;//////////////////////////////////////////////////////////////////////
; fuji_set_slot - Set mount record for a slot
; This is the high-level interface that manages transactions
;
; Entry: current_drv = slot number (0-7)
;        fuji_current_fs_name = filesystem name (e.g., "N:", "H:" etc)
;        fuji_current_host_slot = host slot number (0-7)
;        fuji_current_dir_num = directory number
; Exit:  Mount record set in FujiNet
;        A contains success code as a bool (1 = true)
;//////////////////////////////////////////////////////////////////////

fuji_set_slot:
        jsr     remember_xy_only
        
        ; NOTE: fuji_disk_slot is already set by the caller (via parameter parsing)
        ; current_drv is the BBC drive number - NOT the same as FujiNet mount slot!
        
        ; Call hardware-specific set slot implementation
        jsr     fuji_begin_transaction  ; Protect &BC-&CB
        jsr     fuji_set_mount_slot_data
        pha                             ; Save return value (bool)
        jsr     fuji_end_transaction    ; Restore &BC-&CB
        pla                             ; Restore return value
        
        ; This causes the XY to be restored, but leaves A alone for return value
        rts

;//////////////////////////////////////////////////////////////////////
; fuji_get_slot - Get mount record for a slot
; This is the high-level interface that manages transactions
;
; Entry: current_drv = slot number (0-7)
; Exit:  Mount record retrieved into FUJI_DATA_BUFFER
;//////////////////////////////////////////////////////////////////////

fuji_get_slot:
        jsr     remember_xy_only
        
        ; NOTE: fuji_disk_slot is already set by the caller (via parameter parsing)
        ; current_drv is the BBC drive number - NOT the same as FujiNet mount slot!
        
        ; Call hardware-specific get slot implementation
        jsr     fuji_begin_transaction  ; Protect &BC-&CB
        jsr     fuji_get_mount_slot_data
        pha                             ; Save return value (bool)
        jsr     fuji_end_transaction    ; Restore &BC-&CB
        pla                             ; Restore return value
        
        ; This causes the XY to be restored, but leaves A alone for return value
        rts
