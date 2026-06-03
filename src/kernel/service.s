; Service call handler

        .export  handle_service
        .export  service12_init_filesystem
        .export  service_null
        .export  rom_disabled

        .export  service_table                     ; export to get in lbl file for debugging

        .importzp paged_ram_copy

        .import cmd_fs_fuji
        .import paged_rom_priv_ws
        .import remember_axy
        .import service01_claim_absworkspace
        .import service02_claim_privworkspace
        .import service03_autoboot
        .import service04_unrec_command
        .import service08_unrec_osword
        .import service09_help
        .import service0A_claim_statworkspace
        .import text_pointer

        .importzp paged_ram_copy

        .import service21_claim_hidden_sws
        .import service22_claim_hidden_pws
        .import service24_required_pws
        .import service25_fs_info
        .import service27_reset

        .include "fujinet.inc"

        .segment "CODE"

handle_service:
.ifdef FUJINET_MACHINE_MASTER

        bit     paged_rom_priv_ws, x            ; rom disabled if 01xxxxxx or 10xxxxxx
        bpl     @lbl2                           ; if 0x
        bvs     @lbl3                           ; if 11

@lbl1:  rts
@lbl2:  bvs     @lbl1                           ; if 01

; 00 = PWS in normal ram, 11 = PWS in hidden ram
@lbl3:

.else

        pha
        lda     paged_rom_priv_ws, x
        bmi     rom_disabled
        pla

.endif

        cmp     #$12
        beq     service12_init_filesystem

        cmp     #$0B            ; only $12 is serviced above $0B, which is dealt with

.ifdef FUJINET_MACHINE_MASTER
        bcc     @lbl4
        cmp     #$28
        bcs     service_null
        cmp     #$21
        bcc     service_null
        sbc     #$16                    ; get down from high ($21,$27) to table index ($B,$11)
.else
        bcs     service_null
.endif

@lbl4:
        ; jump to the appropriate function according to the command in A
        asl     a
        tax
        lda     service_table+1, x
        pha
        lda     service_table, x
        pha

        txa
        ldx     paged_ram_copy
        lsr     a
        cmp     #$0B
        bcc     service_null
        adc     #$15            ; turn this back into the original service request number, e.g. $24. C=1, so only add $15

        ; this will jmp to the service table location if it drops through from above.
service_null:
        rts

rom_disabled:
        pla
        rts

service12_init_filesystem:
        ; need to understand what this magic number is, in MMFS it's 4, the docs state:
        ;
        ; Select filing system
        ;  On entry Y contains the filing system identity (see OSARGS) to
        ;  change to. This provides a faster way than passing (for example)
        ;  *DISC to OSCLI for programs which make use of more than one
        ;  filing system: eg. files open on a NET and DISK or when copying from
        ;  TAPE to DISC. Therefore this call must be accepted by at least the
        ;  filing system ROM(s) but may be issued by any ROM.
        cpy     #filesysno
        bne     service_null
        ; it is our filesystem number, so load the Fuji FileSystem
        jsr     remember_axy
        jmp     cmd_fs_fuji

; NOTE: These will need to be adjusted for MASTER or SWRAM future work
service_table:
        .word   service_null - 1                        ; 0

.ifdef FUJINET_MACHINE_MASTER
        .word   service_null - 1                        ; use 21 instead for master
.else
        .word   service01_claim_absworkspace - 1        ; 1
.endif

        .word   service02_claim_privworkspace - 1       ; 2
        .word   service03_autoboot - 1                  ; 3
        .word   service04_unrec_command - 1             ; 4
        .word   service_null - 1                        ; 5
        .word   service_null - 1                        ; 6
        .word   service_null - 1                        ; 7
        .word   service08_unrec_osword - 1              ; 8
        .word   service09_help - 1                      ; 9
        .word   service0A_claim_statworkspace - 1       ; $A

.ifdef FUJINET_MACHINE_MASTER
        .word   service21_claim_hidden_sws - 1          ; $21 (index 11 = B)
        .word   service22_claim_hidden_pws - 1          ; $22 (index 12 = C)
        .word   service_null - 1                        ; $23 (index 13 = D)
        .word   service24_required_pws - 1              ; $24 (index 14 = E)
        .word   service25_fs_info - 1                   ; $25 (index 15 = F)
        .word   service_null - 1                        ; $26 (index 16 = $10)
        .word   service27_reset - 1                     ; $27 (index 17 = $11)
.endif
