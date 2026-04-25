; Workspace utility functions
        .export save_static_to_private_workspace
        .export set_fuji_data_buffer_ptr
        .export set_fuji_fs_uri_ptr
        .export _fuji_data_buffer_ptr
        .export _fuji_fs_uri_ptr
        .export _fuji_host_uri_ptr
        .export _fuji_dir_path_ptr
        .export get_fuji_fs_uri_addr_to_aws_tmp6
        .export get_fuji_host_uri_addr_to_aws_tmp6

        .import  remember_axy
        .import  fuji_current_host_len
        .import  fuji_current_dir_len
        .import  print_string
        .import  set_private_workspace_pointer_b0
        .import  return_with_a0
        .import  close_all_files
        .import  close_files_yhandle

        .include "fujinet.inc"

        .segment "CODE"

; Set buffer_ptr to PWS (FujiBus RX/TX packet buffer is at location 0).
set_fuji_data_buffer_ptr:
        jsr     set_private_workspace_pointer_b0
        lda     aws_tmp00
        sta     buffer_ptr
        lda     aws_tmp01
        sta     buffer_ptr+1
        rts

; Set buffer_ptr to PWS + FUJI_PWS_PACKET_OFFSET (FujiBus RX/TX packet buffer).
; THIS IS OPTIMIZED TO USE THE FACT THE WHOLE BUFFER STARTS ON A PAGE BOUNDARY
set_fuji_fs_uri_ptr:
        jsr     set_fuji_data_buffer_ptr

        ; directly add 280, the FUJI_PWS_PACKET_SIZE, just inc the high byte, then add 280-256 = 24
        ; and use the fact we know buffer_ptr lower byte is 0 from being on a boundary, so just need to set it rather than add
        inc     buffer_ptr+1
        lda     #24
        sta     buffer_ptr
        rts

; uint8_t *fuji_data_buffer_ptr(void);  return in A/X
; used by C functions to get the buffer_ptr
_fuji_data_buffer_ptr:
        ; ensure it's set correctly first
        jsr     set_fuji_data_buffer_ptr
        lda     buffer_ptr
        ldx     buffer_ptr+1
        rts

; uint8_t *fuji_fs_uri_ptr(void);  return in A/X — PWS + FUJI_FS_URI_OFFSET (see fujinet.inc)
; Must NOT redirect buffer_ptr (see set_fuji_fs_uri_ptr): FujiBus SLIP uses buffer_ptr for the
; RX/TX packet at PWS+0; C often calls this between fuji_data_buffer_ptr() and send/receive.
; INPUT: aws_tmp00 must point to buffer_ptr
_fuji_fs_uri_ptr:
        jsr     set_private_workspace_pointer_b0
        lda     aws_tmp00
        clc
        adc     #<(FUJI_FS_URI_OFFSET)
        pha
        lda     aws_tmp01
        adc     #>(FUJI_FS_URI_OFFSET)
        tax
        pla
        rts

; uint8_t *fuji_host_uri_ptr(void);  return in A/X — PWS + FUJI_HOST_URI_OFFSET
_fuji_host_uri_ptr:
        jsr     set_private_workspace_pointer_b0
        lda     aws_tmp00
        clc
        adc     #<(FUJI_HOST_URI_OFFSET)
        pha
        lda     aws_tmp01
        adc     #>(FUJI_HOST_URI_OFFSET)
        tax
        pla
        rts

; uint8_t *fuji_dir_path_ptr(void);  return in A/X
; PATH = suffix of canonical host URI: PWS host base + (host_len - dir_len).
_fuji_dir_path_ptr:
        jsr     set_private_workspace_pointer_b0
        lda     aws_tmp00
        clc
        adc     #<(FUJI_HOST_URI_OFFSET)
        sta     aws_tmp06
        lda     aws_tmp01
        adc     #>(FUJI_HOST_URI_OFFSET)
        sta     aws_tmp07
        lda     fuji_current_host_len
        sec
        sbc     fuji_current_dir_len
        bcs     @suffix_off_ok
        lda     #$00
@suffix_off_ok:
        clc
        adc     aws_tmp06
        pha
        lda     aws_tmp07
        adc     #$00
        tax
        pla
        rts

; FS URI storage address in aws_tmp06/aws_tmp07 (does not modify buffer_ptr)
get_fuji_fs_uri_addr_to_aws_tmp6:
        jsr     set_private_workspace_pointer_b0
        lda     aws_tmp00
        clc
        adc     #<(FUJI_FS_URI_OFFSET)
        sta     aws_tmp06
        lda     aws_tmp01
        adc     #>(FUJI_FS_URI_OFFSET)
        sta     aws_tmp07
        rts

; Host URI (*FHOST) storage address in aws_tmp06/aws_tmp07 (does not modify buffer_ptr)
get_fuji_host_uri_addr_to_aws_tmp6:
        jsr     set_private_workspace_pointer_b0
        lda     aws_tmp00
        clc
        adc     #<(FUJI_HOST_URI_OFFSET)
        sta     aws_tmp06
        lda     aws_tmp01
        adc     #>(FUJI_HOST_URI_OFFSET)
        sta     aws_tmp07
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
