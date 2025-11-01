; FujiNet disk mounting interface
; Implements drive-to-disk-image mapping (like MMFS *DIN command)
; This is part of the Hardware Interface Layer (fuji_fs.s equivalent)

        .export fuji_mount_disk
        .export fuji_unmount_disk
        .export fuji_get_mounted_disk

        .import fuji_mount_disk_data
        .import fuji_begin_transaction
        .import fuji_end_transaction
        .import remember_axy

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
        jsr     remember_axy
        
        ; Record the mapping: fuji_drive_disk_map[current_drv] = disk_num
        ldx     current_drv
        lda     aws_tmp08               ; Low byte of disk number
        sta     fuji_drive_disk_map,x
        
        ; Call hardware-specific mount implementation
        jsr     fuji_begin_transaction  ; Protect &BC-&CB
        jsr     fuji_mount_disk_data    ; Hardware-specific (dummy/serial)
        jsr     fuji_end_transaction    ; Restore &BC-&CB
        
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

