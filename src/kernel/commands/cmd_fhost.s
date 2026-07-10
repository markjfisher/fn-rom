; *FHOST / *FFS — set or show current HOST stored in FujiNet AppStore.
        .export  cmd_fs_fhost
        .export  fhost_show_current
        .export  fhost_copy_and_resolve
        .export  fhost_ensure_host_trailing_slash

        .importzp aws_tmp00
        .importzp aws_tmp01
        .importzp aws_tmp02
        .importzp aws_tmp03
        .importzp aws_tmp12
        .importzp aws_tmp13
        .importzp buffer_ptr
        .importzp fuji_bus_tx_command
        .importzp fuji_bus_tx_device

        .import exit_user_ok
        .import fuji_filename_buffer
        .import fuji_filename_len
        .import fujibus_receive_packet
        .import fujibus_set_payload_buffer_ptr
        .import fujibus_send_packet
        .import param_count
        .import param_get_string
        .import print_char
        .import print_newline
        .import print_string
        .import report_error

        .include "fujinet.inc"

        .segment "CODE"

FHOST_NS_LEN       = 11
FHOST_KEY_LEN      = 12
FHOST_PATH_KEY_LEN = 20
FHOST_PREFIX_LEN   = 28
FHOST_RW_REQ_LEN   = 34
FHOST_PREFIX_OFF   = $22
FHOST_DATA_OFF     = $28
FHOST_READ_MAX     = 255

cmd_fs_fhost:
        jsr     param_count
        bcs     @set_fhost

        jsr     fhost_show_current
        jmp     exit_user_ok

@set_fhost:
        clc
        jsr     param_get_string
        sta     fuji_filename_len
        jsr     fhost_copy_and_resolve
        jsr     fhost_show_current
        jmp     exit_user_ok

fhost_show_current:
        jsr     print_string
        .byte   "HOST: "
        jsr     fhost_read_current_host
        bcc     @print_host
        jsr     print_none_str
        jsr     print_newline
        jsr     print_string
        .byte   "PATH: "
        jsr     print_none_str
        jmp     print_newline

@print_host:
        jsr     fhost_print_read_value
        jsr     print_newline
        jsr     print_string
        .byte   "PATH: "
        jsr     fhost_read_current_path
        bcc     @print_path
        lda     #'/'
        jsr     print_char
        jmp     print_newline
@print_path:
        jsr     fhost_print_read_value
        jmp     print_newline

print_none_str:
        jsr     print_string
        .byte   "(none)"
        nop
        rts

; Compatibility export: write fuji_filename_buffer/len as current HOST.
fhost_copy_and_resolve:
        jsr     fhost_write_current_host
        bcs     @write_err
        rts
@write_err:
        jsr     report_error
        .byte   $CB
        .byte   "HOST", 0

; Compatibility export: no target-side canonical HOST buffer remains.
fhost_ensure_host_trailing_slash:
        rts

fhost_read_current_host:
        lda     #<fhost_key_current_host
        ldx     #>fhost_key_current_host
        ldy     #FHOST_KEY_LEN
        jmp     fhost_appstore_read

fhost_read_current_path:
        lda     #<fhost_key_current_path
        ldx     #>fhost_key_current_path
        ldy     #FHOST_PATH_KEY_LEN
        jmp     fhost_appstore_read

fhost_write_current_host:
        lda     #<fhost_key_current_host
        ldx     #>fhost_key_current_host
        ldy     #FHOST_KEY_LEN
        ; fall through

; A/X=key pointer, Y=key length. Value is fuji_filename_buffer/len.
fhost_appstore_write:
        jsr     fhost_build_prefix

        ; offset u32 = 0
        ldy     #FHOST_PREFIX_OFF
        lda     #$00
        sta     (buffer_ptr),y
        iny
        sta     (buffer_ptr),y
        iny
        sta     (buffer_ptr),y
        iny
        sta     (buffer_ptr),y
        iny

        lda     fuji_filename_len
        sta     (buffer_ptr),y
        iny
        lda     #$00
        sta     (buffer_ptr),y
        iny

        lda     buffer_ptr
        clc
        adc     #FHOST_DATA_OFF
        sta     aws_tmp02
        lda     buffer_ptr+1
        adc     #$00
        sta     aws_tmp03

        ldy     #$00
@copy_value:
        cpy     fuji_filename_len
        beq     @send
        lda     fuji_filename_buffer,y
        sta     (aws_tmp02),y
        iny
        bne     @copy_value

@send:
        lda     #FN_DEVICE_FILE
        sta     fuji_bus_tx_device
        lda     #FILE_CMD_APPSTORE_WRITE
        sta     fuji_bus_tx_command
        jsr     fujibus_set_payload_buffer_ptr
        lda     fuji_filename_len
        clc
        adc     #FHOST_RW_REQ_LEN
        ldx     #$00
        jsr     fujibus_send_packet
        jsr     fujibus_receive_packet
        jmp     fhost_check_basic_ok

; A/X=key pointer, Y=key length.
fhost_appstore_read:
        jsr     fhost_build_prefix

        ldy     #FHOST_PREFIX_OFF
        lda     #$00
        sta     (buffer_ptr),y
        iny
        sta     (buffer_ptr),y
        iny
        sta     (buffer_ptr),y
        iny
        sta     (buffer_ptr),y
        iny
        lda     #FHOST_READ_MAX
        sta     (buffer_ptr),y
        iny
        lda     #$00
        sta     (buffer_ptr),y

        lda     #FN_DEVICE_FILE
        sta     fuji_bus_tx_device
        lda     #FILE_CMD_APPSTORE_READ
        sta     fuji_bus_tx_command
        jsr     fujibus_set_payload_buffer_ptr
        lda     #FHOST_RW_REQ_LEN
        ldx     #$00
        jsr     fujibus_send_packet
        jsr     fujibus_receive_packet
        jsr     fhost_check_basic_ok
        bcs     @fail

        ldy     #$08                    ; AppStore read flags
        lda     (buffer_ptr),y
        and     #$02                    ; exists
        beq     @fail

        ldy     #$0F                    ; dataLen low
        lda     (buffer_ptr),y
        sta     aws_tmp12
        iny
        lda     (buffer_ptr),y
        bne     @fail
        lda     aws_tmp12
        beq     @fail

        clc
        rts
@fail:
        sec
        rts

fhost_check_basic_ok:
        cpx     #$00
        bne     @check
        cmp     #$11
        bcc     @fail
@check:
        ldy     #$05
        lda     (buffer_ptr),y
        cmp     #$01
        bne     @fail
        iny
        lda     (buffer_ptr),y
        bne     @fail
        ldy     #$07
        lda     (buffer_ptr),y
        cmp     #FN_PROTOCOL_VERSION
        bne     @fail
        clc
        rts
@fail:
        sec
        rts

fhost_print_read_value:
        lda     buffer_ptr
        clc
        adc     #$11
        sta     aws_tmp00
        lda     buffer_ptr+1
        adc     #$00
        sta     aws_tmp01
        ldy     #$00
@loop:
        cpy     aws_tmp12
        beq     @done
        lda     (aws_tmp00),y
        jsr     print_char
        iny
        bne     @loop
@done:
        rts

; Build common AppStore prefix at buffer+6.
; A/X=key ptr, Y=key len.
fhost_build_prefix:
        sta     aws_tmp00
        stx     aws_tmp01
        sty     aws_tmp13

        ldy     #$06
        lda     #FN_PROTOCOL_VERSION
        sta     (buffer_ptr),y
        iny
        lda     #FHOST_NS_LEN
        sta     (buffer_ptr),y
        iny
        lda     #$00
        sta     (buffer_ptr),y
        iny

        ldx     #$00
@copy_ns:
        lda     fhost_ns,x
        sta     (buffer_ptr),y
        iny
        inx
        cpx     #FHOST_NS_LEN
        bne     @copy_ns

        lda     aws_tmp13
        sta     (buffer_ptr),y
        iny
        lda     #$00
        sta     (buffer_ptr),y
        iny

        ; Copy key with a separate loop using aws_tmp02/03 as destination.
        lda     buffer_ptr
        clc
        adc     #($06 + 1 + 2 + FHOST_NS_LEN + 2)
        sta     aws_tmp02
        lda     buffer_ptr+1
        adc     #$00
        sta     aws_tmp03
        ldy     #$00
@copy_key2:
        cpy     aws_tmp13
        beq     @key_done
        lda     (aws_tmp00),y
        sta     (aws_tmp02),y
        iny
        bne     @copy_key2
@key_done:
        rts

fhost_ns:
        .byte   "fujinet-nio"
fhost_key_current_host:
        .byte   "current-host"
fhost_key_current_path:
        .byte   "current-display-path"
