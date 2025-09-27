; Workspace utility functions
        .export save_static_to_private_workspace
        .export channel_buffer_to_disk_yhandle

        .import  remember_axy
        .import  print_string
        .import  set_private_workspace_pointer_b0
        .import  return_with_a0
        .import  close_all_files
        .import  close_files_yhandle

        .include "fujinet.inc"

        .segment "CODE"

; Copy valuable data from static workspace (sws) to private workspace (pws)
; (sws data 10C0-10EF, and 1100-11BF)
save_static_to_private_workspace:
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
        lda     $1000,y                 ; Static workspace high part
        bcs     @stat_y_gtreq_c0
@stat_y_less_c0:
        lda     $1100,y                 ; Static workspace low part
@stat_y_gtreq_c0:
        sta     (aws_tmp00),y
        iny
        cpy     #<(CHECK_CRC7+1)
        bne     @stat_loop1

        ; Restore previous values
        pla
        sta     aws_tmp01
        pla
        sta     aws_tmp00
        rts


channel_buffer_to_disk_yhandle_a0:
        jsr     return_with_a0

; Force buffer save for channels
; Y = handle (0 = all files)
channel_buffer_to_disk_yhandle:
        lda     $10C0                   ; Force buffer save - opened channels flag byte
        pha                             ; Save opened channels flag byte
        tya                             ; A=handle
        bne     @chbuf1
        jsr     close_all_files
        beq     @chbuf2                 ; always
@chbuf1:
        jsr     close_files_yhandle
@chbuf2:
        pla                             ; Restore
        sta     $10C0
        rts

