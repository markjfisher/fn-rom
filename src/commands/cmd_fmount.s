        .export cmd_fs_fmount

        .import err_bad
        .import fn_disk_mount
        .import fuji_get_mount_slot
        .import fn_rx_buffer
        .import param_count_a
        .import param_drive_or_default
        .import param_get_num
        .import set_user_flag_x

        .include "fujinet.inc"

        .segment "CODE"

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; cmd_fs_fmount - Handle *FMOUNT command
;
; Syntax:
;   *FMOUNT <fuji slot> [<bbc drive>]
;
; The first parameter is a 0-based FujiNet persisted mount slot index.
; The optional second parameter is a BBC drive number (0..3). If omitted,
; param_drive_or_default falls back to the current/default BBC drive.
;
; Design split:
; - The FujiNet persisted mount table (slots 0..7) is populated by FIN or by
;   FHOST when you set a URI (*FHOST <uri>* writes that URI to slot 0).
; - FMOUNT sends GetMount(slot): payload is a single byte (slot index). FujiNet
;   returns the stored mount record (enabled, URI, mode) for that slot.
; - FMOUNT bridges one persisted slot onto one BBC drive by updating
;   fuji_drive_disk_map and by calling DiskDevice Mount for the live slot.
;
; FMOUNT validates the persisted FujiNet slot via FujiDevice GetMount before the
; BBC-side bridge is updated. Empty or disabled slots are rejected.
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

cmd_fs_fmount:
        ; Count parameters first. FMOUNT supports 1 or 2 parameters only.
        lda     #$80                    ; allows 1-2 parameters
        jsr     param_count_a

        ; Read and validate the mandatory FujiNet mount slot index.
        jsr     param_get_num           ; FujiNet mount slot index 0-7
        cmp     #$08
        bcs     bad_mount_slot
        sta     fuji_disk_table_index
        sta     fuji_current_mount_slot

        ; Validate that the selected persisted FujiNet slot is populated and
        ; enabled before updating the BBC-side bridge mapping.
        jsr     fuji_get_mount_slot
        bcs     bad_mount_slot
        ldy     #FN_HEADER_SIZE+1
        lda     fn_rx_buffer,y
        and     #$01
        beq     bad_mount_slot
        iny
        lda     fn_rx_buffer,y
        beq     bad_mount_slot

        ; Read optional BBC drive number, or fall back to the current/default
        ; drive if the user omitted it.
        jsr     param_drive_or_default  ; optional BBC drive number
        sta     current_drv

        ; Build the live DiskDevice mount request from the validated persisted URI
        ; so FMOUNT immediately affects the active runtime state as well as the
        ; ROM-side bridge table.
        ldy     #FN_HEADER_SIZE+2
        lda     fn_rx_buffer,y
        sta     aws_tmp02
        ldx     #$00
@copy_uri:
        cpx     aws_tmp02
        beq     @mount_live
        iny
        lda     fn_rx_buffer,y
        sta     fuji_current_fs_uri,x
        inx
        bne     @copy_uri

@mount_live:
        lda     #$00
        sta     fuji_current_fs_uri,x
        lda     #<fuji_current_fs_uri
        sta     aws_tmp00
        lda     #>fuji_current_fs_uri
        sta     aws_tmp01
        lda     current_drv
        clc
        adc     #$01
        ldx     #$00
        jsr     fn_disk_mount
        bcs     bad_mount_slot

        ; Bridge mapping table used later by DFS disk I/O:
        ;   BBC drive number -> FujiNet mount slot index
        ldx     current_drv
        lda     fuji_disk_table_index
        sta     fuji_drive_disk_map,x

        ; Standard success path: zero user flag.
        ldx     #$00
        jmp     set_user_flag_x

bad_mount_slot:
        ; Standard ROM "Bad mount slot" error path.
        jsr     err_bad
        .byte   $CB
        .byte   "mount slot", 0
