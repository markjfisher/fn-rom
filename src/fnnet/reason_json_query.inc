fnnet_reason_json_query:
        jsr     fnnet_load_ext_str
        bcs     fnnet_fail

        lda     #(FUJI_EXT_STR_ACTIVE | FUJI_EXT_STR_IS_JSON)
        jsr     fnnet_set_flags_and_len

        ldy     #$06
        lda     (aws_tmp00),y
        tay
        jsr     check_channel_yhndl_exyintch
        bcs     fnnet_json_bad_channel

        sty     aws_tmp02

        jsr     fujibus_network_translate_configure
        bcs     fnnet_json_query_failed

        lda     #$00
        sta     fuji_json_path_len      ; immediate translate should not affect future OPEN requests
        beq     fnnet_exit

fnnet_json_bad_channel:
        jsr     fnnet_clear_ext_state
        lda     #FNNET_STATUS_BAD_CHANNEL
        bne     fnnet_exit

fnnet_json_query_failed:
        ; Match *FJSON soft-fail behaviour: translated read becomes immediate EOF,
        ; and the caller can inspect the non-zero fnnet status to distinguish it.
        ldy     aws_tmp02
        lda     #$00
        jsr     fnnet_clear_channel_read_state_y
        jsr     fnnet_clear_ext_state
        lda     #FNNET_STATUS_JSON_QUERY_FAILED
        bne     fnnet_exit
