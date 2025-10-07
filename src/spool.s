        .export  clear_exec_spool_file_handle
        .export  conv_Yhndl_intch_exYintch

        .import  a_rolx5
        .import  osbyte_X0YFF

        .include "fujinet.inc"

        .segment "CODE"

conv_Yhndl_intch_exYintch:
        pha
        tya

@conv_hndl_X_entry:
        cmp     #filehndl
        bcc     @conv_hndl10
        cmp     #filehndl + 8
        bcc     @conv_hndl18

@conv_hndl10:
        lda     #$08
 
@conv_hndl18:
        jsr     a_rolx5
        tay
        pla
        rts

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
        jsr     conv_Yhndl_intch_exYintch
        cpy     $10C2
        rts

@clear_spool_handle_exit:
        rts