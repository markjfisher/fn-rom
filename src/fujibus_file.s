        .export fn_file_resolve_path
        .export fn_file_list_directory

        .import fn_build_packet
        .import fn_send_packet
        .import fn_receive_packet
        .import fn_tx_buffer
        .import fn_rx_buffer

        .include "fujinet.inc"

        .segment "CODE"

; BBC-side helper for FileDevice ResolvePath (0x05)
; Input:
;   aws_tmp00/01 = pointer to base URI
;   aws_tmp02    = base URI length
;   aws_tmp03/04 = pointer to argument string
;   aws_tmp05    = argument length
; Output on success:
;   fuji_current_fs_uri / fuji_current_fs_len updated with resolved URI
;   fuji_current_dir_path / fuji_current_dir_len updated with display path
;   C clear on success, set on failure
fn_file_resolve_path:
        lda     #FN_PROTOCOL_VERSION
        sta     fn_tx_buffer+FN_HEADER_SIZE+0

        lda     aws_tmp02
        sta     fn_tx_buffer+FN_HEADER_SIZE+1
        lda     #$00
        sta     fn_tx_buffer+FN_HEADER_SIZE+2

        ldy     #$00
@copy_base:
        cpy     aws_tmp02
        beq     @copy_arg_len
        lda     (aws_tmp00),y
        sta     fn_tx_buffer+FN_HEADER_SIZE+3,y
        iny
        bne     @copy_base

@copy_arg_len:
        lda     aws_tmp05
        sta     fn_tx_buffer+FN_HEADER_SIZE+3,y
        iny
        lda     #$00
        sta     fn_tx_buffer+FN_HEADER_SIZE+3,y
        iny

        ldx     #$00
@copy_arg:
        cpx     aws_tmp05
        beq     @send
        txa
        pha
        txa
        tay
        lda     (aws_tmp03),y
        pla
        tax
        ldy     aws_tmp07
        sta     fn_tx_buffer+FN_HEADER_SIZE+3,y
        inx
        iny
        sty     aws_tmp07
        bne     @copy_arg

@send:
        tya
        clc
        adc     #$03
        tay
        lda     #FN_DEVICE_FILE
        ldx     #FILE_CMD_RESOLVE_PATH
        jsr     fn_build_packet
        jsr     fn_send_packet
        bcs     @error
        jsr     fn_receive_packet
        bcs     @error

        ; Parse response payload into persistent workspace.
        ; payload: version, flags, reserved(2), resolvedUriLen(2), resolvedUri..., displayPathLen(2), displayPath...
        ldy     #FN_HEADER_SIZE+4
        lda     fn_rx_buffer,y
        sta     fuji_current_fs_len
        iny
        ; ignore high byte for now
        iny
        ldx     #$00
@copy_resolved:
        cpx     fuji_current_fs_len
        beq     @copy_resolved_term
        lda     fn_rx_buffer,y
        sta     fuji_current_fs_uri,x
        iny
        inx
        bne     @copy_resolved
@copy_resolved_term:
        lda     #$00
        sta     fuji_current_fs_uri,x

        lda     fn_rx_buffer,y
        sta     fuji_current_dir_len
        iny
        ; ignore high byte
        iny
        ldx     #$00
@copy_display:
        cpx     fuji_current_dir_len
        beq     @copy_display_term
        lda     fn_rx_buffer,y
        sta     fuji_current_dir_path,x
        iny
        inx
        bne     @copy_display
@copy_display_term:
        lda     #$00
        sta     fuji_current_dir_path,x
        clc
        rts

@error:
        sec
        rts

; BBC-side helper for FileDevice ListDirectory (0x02)
; Input:
;   aws_tmp00/01 = pointer to URI
;   aws_tmp02    = URI length
;   aws_tmp03    = startIndex low
;   aws_tmp04    = startIndex high
;   aws_tmp05    = maxEntries low
;   aws_tmp06    = maxEntries high
; Output:
;   response packet left in fn_rx_buffer for caller to print/consume
;   C clear on success, set on failure
fn_file_list_directory:
        lda     #FN_PROTOCOL_VERSION
        sta     fn_tx_buffer+FN_HEADER_SIZE+0
        lda     aws_tmp02
        sta     fn_tx_buffer+FN_HEADER_SIZE+1
        lda     #$00
        sta     fn_tx_buffer+FN_HEADER_SIZE+2

        ldy     #$00
@copy_uri:
        cpy     aws_tmp02
        beq     @write_paging
        lda     (aws_tmp00),y
        sta     fn_tx_buffer+FN_HEADER_SIZE+3,y
        iny
        bne     @copy_uri

@write_paging:
        lda     aws_tmp03
        sta     fn_tx_buffer+FN_HEADER_SIZE+3,y
        iny
        lda     aws_tmp04
        sta     fn_tx_buffer+FN_HEADER_SIZE+3,y
        iny
        lda     aws_tmp05
        sta     fn_tx_buffer+FN_HEADER_SIZE+3,y
        iny
        lda     aws_tmp06
        sta     fn_tx_buffer+FN_HEADER_SIZE+3,y
        iny

        tya
        clc
        adc     #$03
        tay
        lda     #FN_DEVICE_FILE
        ldx     #FILE_CMD_LIST_DIRECTORY
        jsr     fn_build_packet
        jsr     fn_send_packet
        bcs     @list_error
        jsr     fn_receive_packet
        bcs     @list_error
        clc
        rts

@list_error:
        sec
        rts
