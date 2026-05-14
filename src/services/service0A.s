; Service call 0A - Claim static workspace
        .export  service0A_claim_statworkspace

        .importzp aws_tmp00
        .importzp aws_tmp01

        .import channel_buffer_to_disk_yhandle
        .import remember_axy
        .import save_static_to_private_workspace
        .import set_private_workspace_pointer_aws_tmp00

        .include "fujinet.inc"

        .segment "CODE"

service0A_claim_statworkspace:
        ; Another ROM wants the static workspace
        ; We need to save our state to private workspace if we own it
        jsr     remember_axy

        ; Do I own sws? Check if pws is "full"

        jsr     set_private_workspace_pointer_aws_tmp00
        ; perm_flags+1 offset, this is the "I OWN SWS INDICATOR/PWS full flag", mirrored in fuji_own_sws_indicator... why? not used here
        lda     #<(FUJI_PWS_PERM_FLAGS_OFFSET+1)
        sta     aws_tmp00
        clc
        lda     #>(FUJI_PWS_PERM_FLAGS_OFFSET+1)
        adc     aws_tmp01
        sta     aws_tmp01

        ldy     #$00
        lda     (aws_tmp00),y           ; Check if pws is "full"
        bpl     @exit                   ; If pws "full" then sws is not mine

        ; Save any open file buffers first
        ldy     #$00                    ; Handle 0 = all files
        jsr     channel_buffer_to_disk_yhandle

        ; Save static to private workspace, preserves aws_tmp00/01
        jsr     save_static_to_private_workspace

        ; Mark pws as "empty"
        lda     #$00
        tay                             ; mark "i own" flag as 00
        sta     (aws_tmp00),y

        tsx                             ; RememberAXY called earlier
        sta     $0105,x                 ; changes value of A in stack to 0

@exit:
        rts
