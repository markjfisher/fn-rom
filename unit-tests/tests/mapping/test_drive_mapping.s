.export _main
.export t_mapped_drive
.export t_mapped_drive_end
.export t_unmapped_drive
.export t_unmapped_drive_end
.export t_dsd80_side1
.export t_dsd80_side1_end
.export t_dsd80_side0
.export t_dsd80_side0_end
.export t_dsd40_side1
.export t_dsd40_side1_end
.export t_unmount_side1
.export t_unmount_side1_end

.import init_harness

.include "fnrom.inc"

.code

_main:
        lda     #$FF
        sta     fuji_drive_disk_map+0
        lda     #$06
        sta     fuji_drive_disk_map+1
        lda     #$02
        sta     fuji_drive_disk_map+2
        lda     #$FF
        sta     fuji_drive_disk_map+3
        lda     #$01
        sta     current_drv
t_mapped_drive:
        jsr     fuji_set_disk_slot_from_mapping_or_error
t_mapped_drive_end:

        lda     #$FF
        sta     fuji_drive_disk_map+0
        lda     #$06
        sta     fuji_drive_disk_map+1
        lda     #$02
        sta     fuji_drive_disk_map+2
        lda     #$FF
        sta     fuji_drive_disk_map+3
        lda     #$03
        sta     current_drv
        lda     #$22
        sta     fuji_disk_slot
t_unmapped_drive:
        jsr     fuji_set_disk_slot_from_mapping_or_error
t_unmapped_drive_end:

        ; An 80-track DSD in drive 0 (slot 0) shows side 1 as drive 2.
        lda     #$30
        sta     fuji_drive_disk_map+0
        lda     #$70
        sta     fuji_drive_disk_map+2
        lda     #$02
        sta     current_drv
t_dsd80_side1:
        jsr     fuji_set_disk_slot_from_mapping_or_error
t_dsd80_side1_end:

        ; Drive 0 reads side 0 again: the side-1 offset must not linger.
        lda     #$00
        sta     current_drv
t_dsd80_side0:
        jsr     fuji_set_disk_slot_from_mapping_or_error
t_dsd80_side0_end:

        ; A 40-track DSD in drive 1 (slot 1) shows side 1 as drive 3.
        lda     #$21
        sta     fuji_drive_disk_map+1
        lda     #$61
        sta     fuji_drive_disk_map+3
        lda     #$03
        sta     current_drv
t_dsd40_side1:
        jsr     fuji_set_disk_slot_from_mapping_or_error
t_dsd40_side1_end:

        ; Unmounting side 1 only unmaps drive 3: the image stays in drive 1.
t_unmount_side1:
        jsr     fuji_unmount_disk
t_unmount_side1_end:
        rts
