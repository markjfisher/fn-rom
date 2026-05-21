; Workspace utility functions
        .export save_static_to_private_workspace
        .export set_fuji_data_buffer_ptr
        .export fuji_fs_uri_ptr
        .export fuji_host_uri_ptr
        .export get_fuji_fs_uri_addr_to_aws_tmp00
        .export get_fuji_host_uri_addr_to_aws_tmp00
        .export get_fuji_json_path_addr_to_aws_tmp00
        .export get_fuji_pws_flags_to_aws_tmp00
        .export set_private_workspace_pointer_aws_tmp00
        .export set_private_workspace_pointer_high_only

        .importzp aws_tmp00
        .importzp aws_tmp01

        .importzp paged_ram_copy

        .import fuji_channel_start
        .import fuji_last_state_loc
        .import fuji_static_workspace
        .import paged_rom_priv_ws
        .import remember_axy

        .include "fujinet.inc"

        .segment "CODE"

; Set buffer_ptr to PWS (FujiBus RX/TX packet buffer is at location 0).
set_fuji_data_buffer_ptr:
        ; jsr     set_private_workspace_pointer_high_only ; leaves A with high byte
        ; sta     buffer_ptr+1
        ; lda     #$00
        ; sta     buffer_ptr
        rts

fuji_fs_uri_ptr:
        jsr     get_fuji_fs_uri_addr_to_aws_tmp00
.if (.cpu .bitand CPU_ISET_65C02)
        bra     set_ax
.else
        clc
        bcc     set_ax
.endif
        ; ldx     aws_tmp01
        ; lda     aws_tmp00
        ; rts

; uint8_t *fuji_host_uri_ptr(void);  return in A/X — PWS + FUJI_HOST_URI_OFFSET
; TODO: this can be improved, PWS is always on a boundary, so lower byte is 00
fuji_host_uri_ptr:
        jsr     get_fuji_host_uri_addr_to_aws_tmp00

set_ax:
        ldx     aws_tmp01
        lda     aws_tmp00
        rts

get_fuji_pws_flags_to_aws_tmp00:
        lda     #<(FUJI_PWS_PERM_FLAGS_OFFSET)
        ldy     #>(FUJI_PWS_PERM_FLAGS_OFFSET)
        jmp     set_private_workspace_pointer_aws_tmp00_with_offset_AY

; FS URI storage address in aws_tmp00/aws_tmp01
get_fuji_fs_uri_addr_to_aws_tmp00:
        lda     #<(FUJI_FS_URI_OFFSET)
        ldy     #>(FUJI_FS_URI_OFFSET)
        jmp     set_private_workspace_pointer_aws_tmp00_with_offset_AY

; Host URI (*FHOST) storage address in aws_tmp00/aws_tmp01
get_fuji_host_uri_addr_to_aws_tmp00:
        lda     #<(FUJI_HOST_URI_OFFSET)
        ldy     #>(FUJI_HOST_URI_OFFSET)
        jmp     set_private_workspace_pointer_aws_tmp00_with_offset_AY

; JSON path storage address in aws_tmp00/aws_tmp01
get_fuji_json_path_addr_to_aws_tmp00:
        lda     #<(FUJI_JSON_PATH_OFFSET)
        ldy     #>(FUJI_JSON_PATH_OFFSET)
        jmp     set_private_workspace_pointer_aws_tmp00_with_offset_AY


; Copy valuable data from static workspace (sws) to private workspace (pws)
; (sws data 10C0-10XX (uses fuji_last_state_loc), and 1100-11BF)
; DO WE NEED TO COPY force_reset and i_own?
; claim_static_workspace in fuji_init.s saves values to them
save_static_to_private_workspace:
        ; Preserves A/X/Y on exit, so Y (currently pointing to fuji_own_sws_indicator) is preserved
        jsr     remember_axy

        ; Save current workspace pointer
        lda     aws_tmp00
        pha
        lda     aws_tmp01
        pha

        jsr     set_private_workspace_pointer_aws_tmp00
        ldy     #$00
@stat_loop1:
        cpy     #$C0
        bcc     @stat_y_less_c0
        lda     fuji_static_workspace - $C0, y  ; Static workspace high part
        bcs     @stat_y_gtreq_c0
@stat_y_less_c0:
        lda     fuji_channel_start,y            ; Static workspace low part
@stat_y_gtreq_c0:
        sta     (aws_tmp00),y
        iny
        cpy     #<(fuji_last_state_loc+1)
        bne     @stat_loop1

        ; Restore previous values
        pla
        sta     aws_tmp01
        pla
        sta     aws_tmp00
        rts

set_private_workspace_pointer_aws_tmp00:
        lda     #$00
        sta     aws_tmp00

set_private_workspace_pointer_high_only:
        ldx     paged_ram_copy
        lda     paged_rom_priv_ws, x
.ifndef FUJINET_MACHINE_MASTER
        and     #$3F
.endif
        sta     aws_tmp01
        rts

set_private_workspace_pointer_aws_tmp00_with_offset_AY:
        sta     aws_tmp00
        jsr     set_private_workspace_pointer_high_only
        clc
        tya                     ; high offset is in Y
        adc     aws_tmp01
        sta     aws_tmp01
        rts
