        .export  clear_exec_spool_file_handle

        .import  conv_yhndl_intch_exyintch
        .import  osbyte_X0YFF

        .include "fujinet.inc"

        .segment "CODE"


clear_exec_spool_file_handle:
        lda     #$C6                                ; X = *EXEC file handle
        jsr     osbyte_X0YFF
        txa
        beq     @clear_spool_handle
        jsr     @convert_Xhndl_exYintch
        bne     @clear_spool_handle
        lda     #$C6                                ; Clear *EXEC file handle
        bne     @osbyte_X0Y0

@clear_spool_handle:
        lda     #$C7
        jsr     osbyte_X0YFF
        jsr     @convert_Xhndl_exYintch
        bne     @clear_spool_handle_exit
        lda     #$C7

@osbyte_X0Y0:
        ldx     #$00
        ldy     #$00
        jmp     OSBYTE

@convert_Xhndl_exYintch:
        txa
        tay
        jsr     conv_yhndl_intch_exyintch
        cpy     $10C2
        rts

@clear_spool_handle_exit:
        rts