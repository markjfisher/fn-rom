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
;
;   Base URI may overlap fn_tx_buffer (e.g. fuji_current_fs_uri in same region).
;   Copy base URI to a safe area in the TX buffer (offset 32) before building
;   the payload so the @copy_base loop does not read its own writes.
fn_file_resolve_path:
        lda     #$00
        sta     aws_tmp07
        sta     aws_tmp06

        ; Copy base URI to fn_tx_buffer+32 so it cannot overlap payload at +6..24
        ldy     #$00
@precopy_base:
        cpy     aws_tmp02
        beq     @precopy_done
        lda     (aws_tmp00),y
        sta     fn_tx_buffer+32,y
        iny
        bne     @precopy_base
@precopy_done:
        lda     #<(fn_tx_buffer+32)
        sta     aws_tmp00
        lda     #>(fn_tx_buffer+32)
        sta     aws_tmp01

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
        sty     aws_tmp07
        lda     aws_tmp05
        sta     fn_tx_buffer+FN_HEADER_SIZE+3,y
        iny
        lda     #$00
        sta     fn_tx_buffer+FN_HEADER_SIZE+3,y
        iny
        ; Total payload length = 3 (version + base_uri_len) + base_uri_len + 2 (arg_len) = 5 + aws_tmp07
        lda     aws_tmp07
        clc
        adc     #5
        sta     aws_tmp06

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
        ldy     aws_tmp06
        sta     fn_tx_buffer+FN_HEADER_SIZE+3,y
        inx
        iny
        sty     aws_tmp06
        bne     @copy_arg

@send:
        ; fn_build_packet expects aws_tmp00/01 = payload pointer, Y = payload length.
        ; We built the payload at fn_tx_buffer+FN_HEADER_SIZE; pass that pointer so
        ; the copy does not overwrite our data (and so we don't copy from base URI).
        lda     #<(fn_tx_buffer+FN_HEADER_SIZE)
        sta     aws_tmp00
        lda     #>(fn_tx_buffer+FN_HEADER_SIZE)
        sta     aws_tmp01
        ldy     aws_tmp06
        lda     #FN_DEVICE_FILE
        ldx     #FILE_CMD_RESOLVE_PATH
        jsr     fn_build_packet
        jsr     fn_send_packet
        bcs     @error
        jsr     fn_receive_packet
        bcs     @error

        lda     fn_rx_buffer+FN_PARAMS_OFFSET
        bne     @error

        lda     fn_rx_buffer+FN_HEADER_SIZE+0
        cmp     #FN_PROTOCOL_VERSION
        bne     @error

        ; Parse response payload into persistent workspace.
        ; payload: version, flags, reserved(2), resolvedUriLen(2), resolvedUri..., displayPathLen(2), displayPath...
        ldy     #FN_HEADER_SIZE+4
        lda     fn_rx_buffer,y
        sta     fuji_current_fs_len
        iny
        lda     fn_rx_buffer,y
        bne     @error
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
        lda     fn_rx_buffer,y
        bne     @error
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

        ; fn_build_packet expects aws_tmp00/01 = payload pointer, Y = payload length.
        ; Y currently holds payload length (7 + uri_len).
        sty     aws_tmp07
        lda     #<(fn_tx_buffer+FN_HEADER_SIZE)
        sta     aws_tmp00
        lda     #>(fn_tx_buffer+FN_HEADER_SIZE)
        sta     aws_tmp01
        ldy     aws_tmp07
        lda     #FN_DEVICE_FILE
        ldx     #FILE_CMD_LIST_DIRECTORY
        jsr     fn_build_packet
        jsr     fn_send_packet
        bcs     @list_error
        jsr     fn_receive_packet
        bcs     @list_error

        lda     fn_rx_buffer+FN_PARAMS_OFFSET
        bne     @list_error

        lda     fn_rx_buffer+FN_HEADER_SIZE+0
        cmp     #FN_PROTOCOL_VERSION
        bne     @list_error
        clc
        rts

@list_error:
        sec
        rts
