; *FHOST / *FFS -- show, set, list, select, or delete FujiNet current HOST.
; HOST state is owned by FujiNet-NIO HostService, not target-side RAM.
        .export  cmd_fs_fhost
        .export  fhost_show_current
        .export  fhost_copy_and_resolve
        .export  fhost_ensure_host_trailing_slash

        .importzp aws_tmp00
        .importzp aws_tmp01
        .importzp aws_tmp02
        .importzp aws_tmp12
        .importzp buffer_ptr
        .importzp fuji_bus_tx_command
        .importzp fuji_bus_tx_device

        .import exit_user_ok
        .import err_syntax
        .import fuji_filename_buffer
        .import fuji_filename_len
        .import fujibus_receive_packet
        .import fujibus_set_payload_buffer_ptr
        .import fujibus_send_packet
        .import num_params
        .import param_get_string
        .import print_char
        .import print_newline
        .import print_string
        .import report_error

        .include "fujinet.inc"

        .segment "CODE"

FHOST_READ_MAX = 255

cmd_fs_fhost:
        jsr     num_params
        beq     @show_fhost
        cmp     #$01
        beq     @one_param
        cmp     #$02
        beq     @two_params
        jmp     err_syntax

@show_fhost:
        jsr     fhost_show_current
        jmp     exit_user_ok

@one_param:
        clc
        jsr     param_get_string
        sta     fuji_filename_len

        jsr     fhost_arg_is_list
        bcs     @not_list
        jsr     fhost_list_history
        jmp     exit_user_ok

@not_list:
        jsr     fhost_arg_is_index
        bcs     @set_fhost
        lda     aws_tmp00
        jsr     fhost_select_history
        bcs     @host_err
        jsr     fhost_show_current
        jmp     exit_user_ok

@set_fhost:
        jsr     fhost_copy_and_resolve
        jsr     fhost_show_current
        jmp     exit_user_ok

@two_params:
        clc
        jsr     param_get_string
        sta     fuji_filename_len
        tya
        pha
        jsr     fhost_arg_is_index
        bcc     @index_ok
        pla
        tay
        jmp     @syntax
@index_ok:
        pla
        tay
        lda     aws_tmp00
        sta     aws_tmp12

        clc
        jsr     param_get_string
        cmp     #$01
        bne     @syntax
        lda     fuji_filename_buffer
        and     #$DF
        cmp     #'D'
        bne     @syntax

        lda     aws_tmp12
        jsr     fhost_delete_history
        bcs     @host_err
        jmp     exit_user_ok

@syntax:
        jmp     err_syntax
@host_err:
        jsr     report_error
        .byte   $CB
        .byte   "HOST", 0

fhost_show_current:
        jsr     fhost_get_current
        bcc     @got_current

        jsr     print_string
        .byte   "HOST: "
        nop
        jsr     print_none_str
        jsr     print_newline
        jsr     print_string
        .byte   "PATH: "
        nop
        jsr     print_none_str
        jmp     print_newline

@got_current:
        jsr     print_string
        .byte   "HOST: "
        nop
        ldy     #$08                    ; hostLen lo
        lda     (buffer_ptr),y
        sta     aws_tmp12
        sta     aws_tmp02
        iny
        lda     (buffer_ptr),y          ; hostLen hi
        bne     @done_host
        lda     buffer_ptr
        clc
        adc     #$0C
        sta     aws_tmp00
        lda     buffer_ptr+1
        adc     #$00
        sta     aws_tmp01
        jsr     fhost_print_bytes
@done_host:
        jsr     print_newline

        jsr     print_string
        .byte   "PATH: "
        nop
        ldy     #$0A                    ; pathLen lo
        lda     (buffer_ptr),y
        sta     aws_tmp12
        iny
        lda     (buffer_ptr),y          ; pathLen hi
        bne     @path_slash
        lda     aws_tmp12
        beq     @path_slash
        lda     buffer_ptr
        clc
        adc     #$0C
        adc     aws_tmp02
        sta     aws_tmp00
        lda     buffer_ptr+1
        adc     #$00
        sta     aws_tmp01
        jsr     fhost_print_bytes
        jmp     print_newline
@path_slash:
        lda     #'/'
        jsr     print_char
        jmp     print_newline

print_none_str:
        jsr     print_string
        .byte   "(none)"
        nop
        rts

; Compatibility export: write fuji_filename_buffer/len as current HOST.
fhost_copy_and_resolve:
        jsr     fhost_set_current
        bcs     @write_err
        rts
@write_err:
        jsr     report_error
        .byte   $CB
        .byte   "HOST", 0

; Compatibility export: no target-side canonical HOST buffer remains.
fhost_ensure_host_trailing_slash:
        rts

fhost_get_current:
        ldy     #$06
        lda     #FN_PROTOCOL_VERSION
        sta     (buffer_ptr),y
        lda     #HOST_CMD_GET_CURRENT
        sta     fuji_bus_tx_command
        lda     #$01
        jsr     fhost_send_host
        jsr     fhost_check_host_ok
        bcs     @fail
        ldy     #$09                    ; reject hostLen hi
        lda     (buffer_ptr),y
        bne     @fail
        ldy     #$0B                    ; reject pathLen hi
        lda     (buffer_ptr),y
        bne     @fail
        clc
        rts
@fail:
        sec
        rts

fhost_set_current:
        ldy     #$06
        lda     #FN_PROTOCOL_VERSION
        sta     (buffer_ptr),y
        iny
        lda     fuji_filename_len
        sta     (buffer_ptr),y
        iny
        lda     #$00
        sta     (buffer_ptr),y
        iny
        ldx     #$00
@copy:
        cpx     fuji_filename_len
        beq     @send
        lda     fuji_filename_buffer,x
        sta     (buffer_ptr),y
        iny
        inx
        bne     @copy
@send:
        lda     #HOST_CMD_SET_CURRENT
        sta     fuji_bus_tx_command
        lda     fuji_filename_len
        clc
        adc     #$03
        jsr     fhost_send_host
        jmp     fhost_check_host_ok

fhost_list_history:
        ldy     #$06
        lda     #FN_PROTOCOL_VERSION
        sta     (buffer_ptr),y
        iny
        lda     #$00                    ; offset lo
        sta     (buffer_ptr),y
        iny
        sta     (buffer_ptr),y          ; offset hi
        iny
        lda     #FHOST_READ_MAX
        sta     (buffer_ptr),y
        iny
        lda     #$00
        sta     (buffer_ptr),y

        lda     #HOST_CMD_LIST_HISTORY
        sta     fuji_bus_tx_command
        lda     #$05
        jsr     fhost_send_host
        jsr     fhost_check_host_ok
        bcs     @none
        ldy     #$0B                    ; dataLen lo
        lda     (buffer_ptr),y
        sta     aws_tmp12
        iny
        lda     (buffer_ptr),y          ; dataLen hi
        bne     @none
        lda     aws_tmp12
        beq     @none
        lda     buffer_ptr
        clc
        adc     #$0D
        sta     aws_tmp00
        lda     buffer_ptr+1
        adc     #$00
        sta     aws_tmp01
        jsr     fhost_print_bytes
        rts
@none:
        jsr     print_none_str
        jmp     print_newline

fhost_select_history:
        ldx     #HOST_CMD_SELECT_HISTORY
        bne     fhost_index_command

fhost_delete_history:
        ldx     #HOST_CMD_DELETE_HISTORY

; A=index, X=command.
fhost_index_command:
        sta     aws_tmp12
        stx     fuji_bus_tx_command
        ldy     #$06
        lda     #FN_PROTOCOL_VERSION
        sta     (buffer_ptr),y
        iny
        lda     aws_tmp12
        sta     (buffer_ptr),y
        lda     #$02
        jsr     fhost_send_host
        jmp     fhost_check_host_ok

; A=payload length low. fuji_bus_tx_command already set.
fhost_send_host:
        pha
        lda     #FN_DEVICE_HOST
        sta     fuji_bus_tx_device
        jsr     fujibus_set_payload_buffer_ptr
        pla
        ldx     #$00
        jsr     fujibus_send_packet
        jsr     fujibus_receive_packet
        rts

fhost_check_host_ok:
        ldy     #$05
        lda     (buffer_ptr),y
        cmp     #$01
        bne     @fail
        iny
        lda     (buffer_ptr),y
        bne     @fail
        iny
        lda     (buffer_ptr),y
        cmp     #FN_PROTOCOL_VERSION
        bne     @fail
        clc
        rts
@fail:
        sec
        rts

; aws_tmp00/01=source, aws_tmp12=len.
fhost_print_bytes:
        lda     aws_tmp12
        beq     @done
@loop:
        ldy     #$00
        lda     (aws_tmp00),y
        cmp     #$0A
        beq     @newline
        jsr     print_char
        jmp     @advance
@newline:
        jsr     print_newline
@advance:
        inc     aws_tmp00
        bne     :+
        inc     aws_tmp01
:
        dec     aws_tmp12
        bne     @loop
@done:
        rts

fhost_arg_is_list:
        lda     fuji_filename_len
        cmp     #$04
        bne     @no
        ldy     #$00
@loop:
        lda     fuji_filename_buffer,y
        and     #$DF
        cmp     fhost_list_word,y
        bne     @no
        iny
        cpy     #$04
        bne     @loop
        clc
        rts
@no:
        sec
        rts

fhost_arg_is_index:
        lda     fuji_filename_len
        beq     @no
        cmp     #$03
        bcs     @no

        ldy     #$00
        lda     fuji_filename_buffer,y
        cmp     #'0'
        bcc     @no
        cmp     #'9'+1
        bcs     @no
        sec
        sbc     #'0'
        sta     aws_tmp00

        lda     fuji_filename_len
        cmp     #$01
        beq     @ok

        iny
        lda     fuji_filename_buffer,y
        cmp     #'0'
        bcc     @no
        cmp     #'9'+1
        bcs     @no
        sec
        sbc     #'0'
        sta     aws_tmp01

        lda     aws_tmp00
        asl     a
        asl     a
        clc
        adc     aws_tmp00
        asl     a
        clc
        adc     aws_tmp01
        sta     aws_tmp00

@ok:
        lda     aws_tmp00
        cmp     #$20
        bcs     @no
        clc
        rts
@no:
        sec
        rts

fhost_list_word:
        .byte   "LIST"
