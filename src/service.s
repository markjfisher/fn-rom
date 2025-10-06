; Service call handler

        .export  handle_service
        .export  service12_init_filesystem

        .export  service_table                     ; export to get in lbl file for debugging

        .import  service01_claim_absworkspace
        .import  service02_claim_privworkspace
        .import  service03_autoboot
        .import  service04_unrec_command
        .import  service08_unrec_osword
        .import  service09_help
        .import  service0A_claim_statworkspace
        .import  cmd_fs_fuji

        .import  remember_axy

        .include "fujinet.inc"

        .segment "CODE"

handle_service:
        pha
        lda     PagedROM_PrivWorkspaces, x
        bmi     rom_disabled
        pla

        cmp     #$12
        beq     service12_init_filesystem

        cmp     #$0B            ; only $12 is services above $0B, which is dealt with
        bcs     service_null

        ; jump to the appropriate function according to the command in A
        asl     a
        tax
        lda     service_table+1, x
        pha
        lda     service_table, x
        pha

        txa
        ldx     PagedRomSelector_RAMCopy
        lsr     a
        cmp     #$0B
        bcc     service_null
        adc     #$15

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

.rodata

service_table:
        .word   service_null - 1                        ; 0
        .word   service01_claim_absworkspace - 1        ; 1
        .word   service02_claim_privworkspace - 1       ; 2
        .word   service03_autoboot - 1                  ; 3
        .word   service04_unrec_command - 1             ; 4
        .word   service_null - 1                        ; 5
        .word   service_null - 1                        ; 6
        .word   service_null - 1                        ; 7
        .word   service08_unrec_osword - 1              ; 8
        .word   service09_help - 1                      ; 9
        .word   service0A_claim_statworkspace - 1       ; A
