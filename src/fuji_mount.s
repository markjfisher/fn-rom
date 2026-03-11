; FujiNet disk mounting interface
; Implements drive-to-disk-image mapping (like MMFS *DIN command)
; This is part of the Hardware Interface Layer (fuji_fs.s equivalent)

        .export fuji_mount_disk
        .export _fuji_mount_disk      ; C-friendly label
        .export fuji_unmount_disk
        .export fuji_get_mounted_disk
        .export fuji_set_slot
        .export _fuji_set_slot       ; C-friendly label
        .export fuji_get_slot
        .export _fuji_get_slot       ; C-friendly label

        .import fuji_mount_disk_data
        .import fuji_set_mount_slot_data
        .import fuji_get_mount_slot_data
        .import fuji_begin_transaction
        .import fuji_end_transaction
        .import remember_axy
        .import remember_xy_only
        .import fuji_disk_slot

        .include "fujinet.inc"

        .segment "CODE"

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; fuji_mount_disk - Mount disk image into drive
; This is the high-level interface that manages transactions
;
; Entry: current_drv = drive number (0-3)
;        aws_tmp08/09 = disk image number to mount
; Exit:  Disk image mounted (mapping recorded)
;        A, X, Y may be modified
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

fuji_mount_disk:
        ; C-friendly alias for calling from C
_fuji_mount_disk:
        jsr     remember_xy_only
        
        ; Record the mapping: fuji_drive_disk_map[current_drv] = disk_num
        ldx     current_drv
        lda     aws_tmp08               ; Low byte of disk number
        sta     fuji_drive_disk_map,x
        
        ; Call hardware-specific mount implementation
        jsr     fuji_begin_transaction  ; Protect &BC-&CB
        jsr     fuji_mount_disk_data    ; Hardware-specific (dummy/serial)
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
        ldx     current_drv
        lda     #$FF                    ; $FF = no disk mounted
        sta     fuji_drive_disk_map,x
        rts

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; fuji_get_mounted_disk - Get which disk is mounted in current drive
;
; Entry: current_drv = drive number (0-3)
; Exit:  A = disk image number (or $FF if none mounted)
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

fuji_get_mounted_disk:
        ldx     current_drv
        lda     fuji_drive_disk_map,x
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
        ; C-friendly alias for calling from C
_fuji_set_slot:
        jsr     remember_xy_only
        
        ; NOTE: fuji_disk_slot is already set by the caller (via parameter parsing)
        ; current_drv is the BBC drive number - NOT the same as FujiNet mount slot!
        
        ; Call hardware-specific set slot implementation
        jsr     fuji_begin_transaction  ; Protect &BC-&CB
        jsr     fuji_set_mount_slot_data ; Hardware-specific (dummy/serial)
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
; Exit:  Mount record retrieved into FUJI_RX_BUFFER
;//////////////////////////////////////////////////////////////////////

fuji_get_slot:
        ; C-friendly alias for calling from C
_fuji_get_slot:
        jsr     remember_xy_only
        
        ; NOTE: fuji_disk_slot is already set by the caller (via parameter parsing)
        ; current_drv is the BBC drive number - NOT the same as FujiNet mount slot!
        
        ; Call hardware-specific get slot implementation
        jsr     fuji_begin_transaction  ; Protect &BC-&CB
        jsr     fuji_get_mount_slot_data ; Hardware-specific (dummy/serial)
        pha                             ; Save return value (bool)
        jsr     fuji_end_transaction    ; Restore &BC-&CB
        pla                             ; Restore return value
        
        ; This causes the XY to be restored, but leaves A alone for return value
        rts

