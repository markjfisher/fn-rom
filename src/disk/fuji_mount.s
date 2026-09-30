; FujiNet disk mounting interface
; Implements drive-to-disk-image mapping (like MMFS *DIN command)
; This is part of the Hardware Interface Layer (fuji_fs.s equivalent)

        .export fuji_begin_host_session
        .export fuji_create_disk
        .export fuji_mount_disk
        .export fuji_reinitialize_disk
        .export fuji_restore_boot_disk
        .export fuji_set_disk_slot_from_mapping_or_error
        .export fuji_unmount_disk

        .importzp aws_tmp08

        .importzp current_drv

        .import fuji_begin_host_session_data
        .import fuji_begin_transaction
        .import fuji_create_disk_data
        .import fuji_disk_slot
        .import fuji_drive_disk_map
        .import fuji_end_transaction
        .import fuji_mount_disk_data
        .import fuji_reinitialize_disk_data
        .import fuji_restore_boot_disk_data
        .import fuji_side_offset
        .import fuji_unmount_disk_data
        .import remember_xy_only

        .include "fujinet.inc"

        .segment "CODE"

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; fuji_create_disk - Create a disk image using the current FS URI
;
; Entry: A = create flags
;        fuji_current_fs_len / PWS FS URI buffer already populated
; Exit:  C clear on success, set on failure
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

fuji_create_disk:
        jsr     remember_xy_only
        pha                             ; Save create flags from caller

        jsr     fuji_begin_transaction  ; Protect &BC-&CB
        pla                             ; Restore create flags for hardware-specific create
        jsr     fuji_create_disk_data
        php                             ; Save carry result
        jsr     fuji_end_transaction    ; Restore &BC-&CB
        plp                             ; Restore carry result
        rts

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; fuji_reinitialize_disk - Recreate the image mounted in fuji_disk_slot
;
; Entry: A = number of BBC DFS tracks (40 or 80)
; Exit:  C clear on success, set on failure
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

fuji_reinitialize_disk:
        jsr     remember_xy_only
        pha

        jsr     fuji_begin_transaction
        pla
        jsr     fuji_reinitialize_disk_data
        php
        jsr     fuji_end_transaction
        plp
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
        jsr     fuji_drop_side1_alias
        lda     aws_tmp08               ; Low byte of disk number
        sta     fuji_drive_disk_map,x
        
        ; Call hardware-specific mount implementation
        jsr     fuji_begin_transaction  ; Protect &BC-&CB
        pla                             ; Restore live mount flags for hardware-specific mount
        jsr     fuji_mount_disk_data
        php                             ; Save carry result
        jsr     fuji_end_transaction    ; Restore &BC-&CB
        plp                             ; Restore carry result
        
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
        clc
        and     #DRIVE_MAP_SIDE1
        bne     @unmap                  ; DSD side 1: the image stays in drive X-2

        lda     fuji_drive_disk_map,x
        and     #DRIVE_MAP_SLOT_MASK
        sta     fuji_disk_slot

        jsr     fuji_begin_transaction
        jsr     fuji_unmount_disk_data
        php
        jsr     fuji_end_transaction

        ldx     current_drv
        jsr     fuji_drop_side1_alias
        plp
@unmap:
        lda     #$FF                    ; $FF = no disk mounted
        sta     fuji_drive_disk_map,x
        rts

; Drive X (0 or 1) is getting a new disk or none: forget the view drive X+2
; had of its old DSD's second side.
fuji_drop_side1_alias:
        cpx     #$02
        bcs     @done
        lda     fuji_drive_disk_map+2,x
        and     #DRIVE_MAP_SIDE1        ; also set in $FF, which is rewritten as is
        beq     @done
        lda     #$FF
        sta     fuji_drive_disk_map+2,x
@done:
        rts

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; fuji_restore_boot_disk - Restore configured boot/config disk to drive A
;
; Entry: A = target BBC drive number (0-3)
; Exit:  C clear on success, set on failure
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

fuji_restore_boot_disk:
        jsr     remember_xy_only

        and     #$03
        sta     fuji_disk_slot

        jsr     fuji_begin_transaction
        jsr     fuji_restore_boot_disk_data
        sta     aws_tmp08
        php
        jsr     fuji_end_transaction
        plp
        bcs     @restore_boot_exit

        lda     aws_tmp08
        and     #DISK_MOUNT_RESP_FLAG_MOUNTED
        beq     @restore_boot_exit

        ldx     fuji_disk_slot
        jsr     fuji_drop_side1_alias
        txa
        sta     fuji_drive_disk_map,x

@restore_boot_exit:
        rts

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; fuji_begin_host_session - Begin a new host disk session
;
; Power-on/hard break uses this to clear NIO runtime recovery state and restore
; the configured boot/config disk to BBC drive 0. Soft break must not call this.
;
; Exit:  C clear on success, set on failure
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

fuji_begin_host_session:
        jsr     remember_xy_only

        lda     #$00
        sta     fuji_disk_slot

        jsr     fuji_begin_transaction
        jsr     fuji_begin_host_session_data
        sta     aws_tmp08
        php
        jsr     fuji_end_transaction
        plp
        bcs     @begin_session_exit

        lda     aws_tmp08
        and     #DISK_MOUNT_RESP_FLAG_MOUNTED
        beq     @begin_session_exit

        jsr     mark_drive0_only_boot_mounted

@begin_session_exit:
        rts

mark_drive0_only_boot_mounted:
        lda     #$00
        sta     fuji_drive_disk_map+0
        lda     #$FF
        sta     fuji_drive_disk_map+1
        sta     fuji_drive_disk_map+2
        sta     fuji_drive_disk_map+3
        rts

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; fuji_set_disk_slot_from_mapping_or_error - Get which fujinet SLOT is mounted in current drive
; N=1 means no slot was set in mappings, fuji_disk_slot was set to FF
; N=0 means fuji_disk_slot was correctly set, and fuji_side_offset to the
;     first LBA of the DSD side the drive shows; A = the drive's map entry
; X = current_drv, Y preserved
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

fuji_set_disk_slot_from_mapping_or_error:
        lda     #$00                            ; side 0 starts at LBA 0
        sta     fuji_side_offset
        sta     fuji_side_offset+1
        ldx     current_drv
        lda     fuji_drive_disk_map,x
        sta     fuji_disk_slot                  ; this will change to FF if no slot from FIN
        bmi     @done
        and     #DRIVE_MAP_SLOT_MASK
        sta     fuji_disk_slot
        lda     fuji_drive_disk_map,x
        and     #DRIVE_MAP_SIDE1
        beq     @map_entry
        ; Side 1 follows all of side 0 in the image's LBAs.
        lda     fuji_drive_disk_map,x
        and     #DRIVE_MAP_80_TRACK
        bne     @side1_80
        lda     #<400
        sta     fuji_side_offset
        lda     #>400
        bne     @side1_hi                       ; always
@side1_80:
        lda     #<800
        sta     fuji_side_offset
        lda     #>800
@side1_hi:
        sta     fuji_side_offset+1
@map_entry:
        lda     fuji_drive_disk_map,x
@done:
        rts
