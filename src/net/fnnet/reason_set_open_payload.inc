; Reason &09: arm a complete Network Open v1 payload in caller RAM.
; Same pointer/length block as reason &04, max512. Zero length cancels.
fnnet_reason_set_open_payload:
        jsr fnnet_load_ext_str
        bcs @invalid
        lda fuji_ext_str_len_hi
        bne @length_ok
        lda fuji_ext_str_len
        cmp #13
        bcc @invalid
@length_ok:
        clc
        lda fuji_ext_str_ptr
        adc fuji_ext_str_len
        lda fuji_ext_str_ptr+1
        adc fuji_ext_str_len_hi
        bcs @invalid
        lda fuji_ext_str_ptr
        sta aws_tmp06
        lda fuji_ext_str_ptr+1
        sta aws_tmp07
        ldy #0
        lda (aws_tmp06),y
        cmp #1
        bne @invalid
        ldy #2
        lda (aws_tmp06),y
        sta fuji_network_open_flags
        lda #FUJI_EXT_STR_ACTIVE | FUJI_EXT_STR_IS_URL | FUJI_EXT_STR_OPEN_ARMED | FUJI_EXT_STR_OPEN_PAYLOAD
        sta fuji_ext_str_flags
        lda #FNNET_STATUS_OK
        jmp fnnet_exit
@invalid:
        jsr fnnet_clear_ext_state
        lda #0
        sta fuji_network_open_flags
        jmp fnnet_fail
