fnnet_reason_stash_json:
        jsr     fnnet_load_ext_str
        bcs     fnnet_fail

        lda     #FUJI_EXT_STR_IS_JSON
        jsr     fnnet_set_flags_and_len
        lda     #FNNET_STATUS_OK
        beq     fnnet_exit
