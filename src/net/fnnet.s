; FujiNet OSWORD &78 API for long URIs and JSON paths.
; Parameter block layout: see docs/fnnet-api.md
; Handler bodies live in fnnet/*.inc (single CODE object for local branches).

        .export fnnet_dispatch

        .importzp aws_tmp00
        .importzp aws_tmp01
        .importzp aws_tmp02
        .importzp aws_tmp06
        .importzp aws_tmp07
        .importzp aws_tmp08
        .importzp aws_tmp09
        .importzp aws_tmp14
        .importzp aws_tmp15

        .import check_channel_yhndl_exyintch
        .import fuji_ch_bptr_hi
        .import fuji_ch_bptr_low
        .import fuji_ch_bptr_mid
        .import fuji_ch_ext_hi
        .import fuji_ch_ext_low
        .import fuji_ch_ext_mid
        .import fuji_intch
        .import fuji_ch_sect_cnt
        .import fuji_ch_write_count
        .import fuji_ch_write_pos_low
        .import fuji_ch_write_pos_mid
        .import fuji_ch_write_pos_hi
        .import fuji_ext_str_flags
        .import fuji_ext_str_len
        .import fuji_ext_str_len_hi
        .import fuji_ext_str_ptr
        .import fuji_json_path_len
        .import fuji_network_body_len
        .import fuji_network_body_len_hi
        .import fuji_network_content_profile
        .import fuji_network_open_flags
        .import fujibus_network_translate_configure
        .import fujibus_network_write_ext
        .import network_flush_write

        .include "fujinet.inc"

        .segment "CODE"

; Core dispatcher: X/Y=parameter block, reason at (block)+0.
fnnet_dispatch:
        stx     aws_tmp00
        stx     aws_tmp14
        sty     aws_tmp01
        sty     aws_tmp15

        ldy     #$00
        lda     (aws_tmp00),y
        cmp     #$06
        bcs     fnnet_dispatch_fail
        tax
        lda     fnnet_jmp_hi,x
        pha
        lda     fnnet_jmp_lo,x
        pha
        rts

.feature line_continuations +
        ; Reason index -> handler (reasons &00..&05)
        .define FNNET_JMP_TABLE \
                fnnet_reason_json_query          - 1, \
                fnnet_reason_set_body_len        - 1, \
                fnnet_reason_write_data          - 1, \
                fnnet_reason_set_content_profile - 1, \
                fnnet_reason_set_open_url        - 1, \
                fnnet_reason_set_open_flags      - 1

fnnet_jmp_lo: .lobytes FNNET_JMP_TABLE
fnnet_jmp_hi: .hibytes FNNET_JMP_TABLE
.feature line_continuations -

fnnet_dispatch_fail:
        jmp     fnnet_fail

        .include "fnnet/ext_str.inc"
        .include "fnnet/reason_json_query.inc"
        .include "fnnet/reason_set_body_len.inc"
        .include "fnnet/exit.inc"
        .include "fnnet/reason_write_data.inc"
        .include "fnnet/reason_set_content_profile.inc"
        .include "fnnet/reason_set_open_url.inc"
        .include "fnnet/reason_set_open_flags.inc"
