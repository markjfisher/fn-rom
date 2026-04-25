; Service call 0A - Claim static workspace
        .export  service0A_claim_statworkspace

        .import  print_axy
        .import  print_string
        .import  remember_axy
        .import  set_private_workspace_pointer_aws_tmp00
        .import  channel_buffer_to_disk_yhandle
        .import  save_static_to_private_workspace

        .include "fujinet.inc"

        .segment "CODE"

service0A_claim_statworkspace:
        ; Another ROM wants the static workspace
        ; We need to save our state to private workspace if we own it

        dbg_string_axy "service0A: "

        jsr     remember_axy

        ; Do I own sws? Check if pws is "full" - why isn't this using fuji_own_sws_indicator?
        ; This uses 17D4 (if PWS is 1700), but fuji_force_reset is 10EF, so not the same thing.
        jsr     set_private_workspace_pointer_aws_tmp00
        ldy     #$D4                    ; fuji_force_reset+1 offset, this is the "I OWN SWS INDICATOR flag"

        lda     (aws_tmp00),y           ; Check if pws is "full"
        bpl     @exit                   ; If pws "full" then sws is not mine

        ; Save any open file buffers first
        ldy     #$00                    ; Handle 0 = all files
        jsr     channel_buffer_to_disk_yhandle

        ; Save static to private workspace
        jsr     save_static_to_private_workspace

        ; Mark pws as "empty"
        ldy     #$D4
        lda     #$00                    ; PWSP+$D4=0 = PWSP "empty"
        sta     (aws_tmp00),y

        ; Change A in stack to 0 (like MMFS)
        tsx                             ; RememberAXY called earlier
        sta     $0105,x                 ; changes value of A in stack to 0

@exit:
        rts
