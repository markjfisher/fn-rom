; Workspace utility functions
        .export save_static_to_private_workspace
        .export set_fuji_data_buffer_ptr
        .export _fuji_data_buffer_ptr

        .import  remember_axy
        .import  print_string
        .import  set_private_workspace_pointer_b0
        .import  return_with_a0
        .import  close_all_files
        .import  close_files_yhandle

        .include "fujinet.inc"

        .segment "CODE"

; Set buffer_ptr to PWS + FUJI_PWS_PACKET_OFFSET (FujiBus RX/TX packet buffer).
set_fuji_data_buffer_ptr:
        jsr     set_private_workspace_pointer_b0
        lda     aws_tmp00
        clc
        adc     #<FUJI_PWS_PACKET_OFFSET
        sta     buffer_ptr
        lda     aws_tmp01
        adc     #>FUJI_PWS_PACKET_OFFSET
        sta     buffer_ptr+1
        rts

; uint8_t *fuji_data_buffer_ptr(void);  return in A/X
_fuji_data_buffer_ptr:
        lda     buffer_ptr
        ldx     buffer_ptr+1
        rts

; Copy valuable data from static workspace (sws) to private workspace (pws)
; (sws data 10C0-10XX (uses fuji_last_state_loc), and 1100-11BF)
save_static_to_private_workspace:
        ; Preserves A/X/Y on exit, so Y (currently pointing to fuji_own_sws_indicator) is preserved
        jsr     remember_axy

.ifdef FN_DEBUG
        jsr     print_string
        .byte   "Saving workspace", $0D
.endif

        ; Save current workspace pointer
        lda     aws_tmp00
        pha
        lda     aws_tmp01
        pha

        jsr     set_private_workspace_pointer_b0
        ldy     #$00
@stat_loop1:
        cpy     #$C0
        bcc     @stat_y_less_c0
        lda     fuji_static_workspace - $C0, y  ; Static workspace high part
        bcs     @stat_y_gtreq_c0
@stat_y_less_c0:
        lda     $1100,y                 ; Static workspace low part
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
