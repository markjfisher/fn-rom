.export _main
.export t_mapped_drive
.export t_mapped_drive_end
.export t_unmapped_drive
.export t_unmapped_drive_end

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
        rts
