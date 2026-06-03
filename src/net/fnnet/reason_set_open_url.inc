fnnet_reason_set_open_url:
        jsr     fnnet_load_ext_str
        bcs     fnnet_fail

        lda     #FUJI_EXT_STR_ACTIVE | FUJI_EXT_STR_IS_URL | FUJI_EXT_STR_OPEN_ARMED
        sta     fuji_ext_str_flags
        lda     #FNNET_STATUS_OK
        jmp     fnnet_exit
