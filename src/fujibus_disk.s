; FujiBus Disk Commands for BBC Micro
; Implements disk device commands using FujiBus protocol
;
; Wire Device ID: 0xFC (FN_DEVICE_DISK)
;
; Commands:
;   0x01 - Mount
;   0x02 - Unmount
;   0x03 - ReadSector
;   0x04 - WriteSector
;   0x05 - Info
;   0x06 - ClearChanged
;   0x07 - Create


        .include "fujinet.inc"

        .import calc_checksum
        .import _fujibus_receive_packet
        .import _fujibus_slip_encode
        .import _fuji_current_host_uri
        .import _write_serial_data
        .import fuji_current_host_len
        .import pushax

        .segment "CODE"

        .export _fujibus_disk_mount
        .export _fujibus_disk_read_sector
        .export _fujibus_disk_write_sector_current
        .export _fujibus_resolve_path

tx_buffer_size = 96

set_tx_packet_header:
        sta     _fuji_tx_buffer+0
        stx     _fuji_tx_buffer+1
        lda     aws_tmp02
        sta     _fuji_tx_buffer+2
        lda     aws_tmp03
        sta     _fuji_tx_buffer+3
        lda     #$00
        sta     _fuji_tx_buffer+4
        sta     _fuji_tx_buffer+5
        rts

send_small_packet:
        lda     #<_fuji_tx_buffer
        sta     aws_tmp00
        lda     #>_fuji_tx_buffer
        sta     aws_tmp01
        jsr     calc_checksum
        sta     _fuji_tx_buffer+4

        lda     #<_fuji_tx_buffer
        ldx     #>_fuji_tx_buffer
        jsr     pushax
        lda     aws_tmp02
        ldx     aws_tmp03
        jsr     _fujibus_slip_encode

        sta     aws_tmp02
        stx     aws_tmp03
        lda     #<_fuji_rx_buffer
        sta     aws_tmp00
        lda     #>_fuji_rx_buffer
        sta     aws_tmp01
        jmp     _write_serial_data

flush_tx_chunk:
        stx     aws_tmp02
        lda     #$00
        sta     aws_tmp03
        lda     #<_fuji_tx_buffer
        sta     aws_tmp00
        lda     #>_fuji_tx_buffer
        sta     aws_tmp01
        jsr     _write_serial_data
        ldx     #$00
        rts

send_prebuilt_rx_packet:
        lda     #<_fuji_rx_buffer
        sta     aws_tmp00
        lda     #>_fuji_rx_buffer
        sta     aws_tmp01

        ldx     #$00
        lda     #SLIP_END
        sta     _fuji_tx_buffer,x
        inx

@copy_loop:
        lda     aws_tmp02
        ora     aws_tmp03
        beq     @finish

        ldy     #$00
        lda     (aws_tmp00),y
        sta     aws_tmp04

        inc     aws_tmp00
        bne     :+
        inc     aws_tmp01
:
        lda     aws_tmp02
        bne     :+
        dec     aws_tmp03
:
        dec     aws_tmp02

        lda     aws_tmp04
        cmp     #SLIP_END
        beq     @escape_end
        cmp     #SLIP_ESCAPE
        beq     @escape_escape

        cpx     #tx_buffer_size
        bne     :+
        jsr     flush_tx_chunk
:
        lda     aws_tmp04
        sta     _fuji_tx_buffer,x
        inx
        jmp     @copy_loop

@escape_end:
        cpx     #(tx_buffer_size - 1)
        bcc     :+
        jsr     flush_tx_chunk
:
        lda     #SLIP_ESCAPE
        sta     _fuji_tx_buffer,x
        inx
        lda     #SLIP_ESC_END
        sta     _fuji_tx_buffer,x
        inx
        jmp     @copy_loop

@escape_escape:
        cpx     #(tx_buffer_size - 1)
        bcc     :+
        jsr     flush_tx_chunk
:
        lda     #SLIP_ESCAPE
        sta     _fuji_tx_buffer,x
        inx
        lda     #SLIP_ESC_ESC
        sta     _fuji_tx_buffer,x
        inx
        jmp     @copy_loop

@finish:
        cpx     #tx_buffer_size
        bne     :+
        jsr     flush_tx_chunk
:
        lda     #SLIP_END
        sta     _fuji_tx_buffer,x
        inx
        txa
        beq     @done
        jsr     flush_tx_chunk
@done:
        rts

copy_rx_payload_to_dataptr:
        lda     data_ptr
        sta     aws_tmp00
        lda     data_ptr+1
        sta     aws_tmp01
        lda     #<(_fuji_rx_buffer + 18)
        sta     aws_tmp08
        lda     #>(_fuji_rx_buffer + 18)
        sta     aws_tmp09
        lda     _fuji_rx_buffer+16
        sta     aws_tmp02
        lda     _fuji_rx_buffer+17
        sta     aws_tmp03

@loop:
        lda     aws_tmp02
        ora     aws_tmp03
        beq     @done

        ldy     #$00
        lda     (aws_tmp08),y
        sta     (aws_tmp00),y

        inc     aws_tmp08
        bne     :+
        inc     aws_tmp09
:
        inc     aws_tmp00
        bne     :+
        inc     aws_tmp01
:
        lda     aws_tmp02
        bne     :+
        dec     aws_tmp03
:
        dec     aws_tmp02
        jmp     @loop

@done:
        rts

return_receive_success:
        lda     #$01
        rts

return_receive_failure:
        lda     #$00
        rts

_fujibus_disk_mount:
        sta     fuji_disk_flags
        sta     aws_tmp14
        lda     fuji_current_fs_len
        clc
        adc     #14
        sta     aws_tmp02
        lda     #$00
        sta     aws_tmp03
        ldx     #DISK_CMD_MOUNT
        lda     #FN_DEVICE_DISK
        jsr     set_tx_packet_header

        lda     fuji_disk_slot
        sta     fuji_disk_slot
        sta     _fuji_tx_buffer+7
        inc     _fuji_tx_buffer+7
        lda     aws_tmp14
        sta     _fuji_tx_buffer+8
        lda     #FN_PROTOCOL_VERSION
        sta     _fuji_tx_buffer+6
        lda     #$00
        sta     _fuji_tx_buffer+9
        sta     _fuji_tx_buffer+10
        sta     _fuji_tx_buffer+11
        lda     fuji_current_fs_len
        sta     _fuji_tx_buffer+12
        lda     #$00
        sta     _fuji_tx_buffer+13

        ldy     #$00
@copy_uri:
        cpy     fuji_current_fs_len
        beq     @send
        lda     _fuji_current_fs_uri,y
        sta     _fuji_tx_buffer+14,y
        iny
        bne     @copy_uri

@send:
        jsr     send_small_packet
        jsr     _fujibus_receive_packet
        sta     aws_tmp02
        stx     aws_tmp03
        txa
        ora     aws_tmp02
        bne     :+
        jmp     return_receive_failure
:
        lda     _fuji_rx_buffer+5
        cmp     #$01
        bne     return_receive_failure
        lda     _fuji_rx_buffer+6
        bne     return_receive_failure
        lda     #$01
        rts

_fujibus_disk_read_sector:
        lda     #14
        sta     aws_tmp02
        lda     #$00
        sta     aws_tmp03
        ldx     #DISK_CMD_READ_SECTOR
        lda     #FN_DEVICE_DISK
        jsr     set_tx_packet_header

        lda     #FN_PROTOCOL_VERSION
        sta     _fuji_tx_buffer+6
        lda     fuji_disk_slot
        clc
        adc     #$01
        sta     _fuji_tx_buffer+7
        lda     fuji_current_sector
        sta     _fuji_tx_buffer+8
        lda     fuji_current_sector+1
        sta     _fuji_tx_buffer+9
        lda     #$00
        sta     _fuji_tx_buffer+10
        sta     _fuji_tx_buffer+11
        sta     _fuji_tx_buffer+12
        lda     #$01
        sta     _fuji_tx_buffer+13

        jsr     send_small_packet
        jsr     _fujibus_receive_packet
        sta     aws_tmp02
        stx     aws_tmp03
        txa
        ora     aws_tmp02
        bne     :+
        jmp     return_receive_failure
:

        jsr     copy_rx_payload_to_dataptr
        lda     #$01
        rts

_fujibus_disk_write_sector_current:
        lda     #$0E
        sta     aws_tmp02
        lda     #$01
        sta     aws_tmp03

        lda     #FN_DEVICE_DISK
        sta     _fuji_rx_buffer+0
        lda     #DISK_CMD_WRITE_SECTOR
        sta     _fuji_rx_buffer+1
        lda     #$0E
        sta     _fuji_rx_buffer+2
        lda     #$01
        sta     _fuji_rx_buffer+3
        lda     #$00
        sta     _fuji_rx_buffer+4
        sta     _fuji_rx_buffer+5
        lda     #FN_PROTOCOL_VERSION
        sta     _fuji_rx_buffer+6
        lda     fuji_disk_slot
        clc
        adc     #$01
        sta     _fuji_rx_buffer+7
        lda     fuji_current_sector
        sta     _fuji_rx_buffer+8
        lda     fuji_current_sector+1
        sta     _fuji_rx_buffer+9
        lda     #$00
        sta     _fuji_rx_buffer+10
        sta     _fuji_rx_buffer+11
        sta     _fuji_rx_buffer+12
        lda     #$01
        sta     _fuji_rx_buffer+13

        lda     data_ptr
        sta     aws_tmp08
        lda     data_ptr+1
        sta     aws_tmp09
        ldy     #$00
@copy_sector:
        lda     (aws_tmp08),y
        sta     _fuji_rx_buffer+14,y
        iny
        bne     @copy_sector

        lda     #<(_fuji_rx_buffer)
        sta     aws_tmp00
        lda     #>(_fuji_rx_buffer)
        sta     aws_tmp01
        lda     #$0E
        sta     aws_tmp02
        lda     #$01
        sta     aws_tmp03
        jsr     calc_checksum
        sta     _fuji_rx_buffer+4

        lda     #$0E
        sta     aws_tmp02
        lda     #$01
        sta     aws_tmp03
        jsr     send_prebuilt_rx_packet

        jsr     _fujibus_receive_packet
        sta     aws_tmp02
        stx     aws_tmp03
        txa
        ora     aws_tmp02
        bne     :+
        jmp     return_receive_failure
:
        lda     aws_tmp03
        bne     :+
        lda     aws_tmp02
        cmp     #$07
        bcs     :+
        jmp     return_receive_failure
:
        lda     _fuji_rx_buffer+6
        beq     :+
        jmp     return_receive_failure
:
        lda     #$01
        rts

_fujibus_resolve_path:
        lda     fuji_current_host_len
        clc
        adc     #11
        sta     aws_tmp02
        lda     #$00
        sta     aws_tmp03
        ldx     #FILE_CMD_RESOLVE_PATH
        lda     #FN_DEVICE_FILE
        jsr     set_tx_packet_header

        lda     #FN_PROTOCOL_VERSION
        sta     _fuji_tx_buffer+6
        lda     fuji_current_host_len
        sta     _fuji_tx_buffer+7
        lda     #$00
        sta     _fuji_tx_buffer+8

        ldy     #$00
@copy_host:
        cpy     fuji_current_host_len
        beq     @finish_request
        lda     _fuji_current_host_uri,y
        sta     _fuji_tx_buffer+9,y
        iny
        bne     @copy_host

@finish_request:
        lda     fuji_current_host_len
        tay
        lda     #$00
        sta     _fuji_tx_buffer+9,y
        sta     _fuji_tx_buffer+10,y

        jsr     send_small_packet
        jsr     _fujibus_receive_packet
        sta     aws_tmp02
        stx     aws_tmp03
        txa
        ora     aws_tmp02
        bne     :+
        jmp     return_receive_failure
:

        lda     _fuji_rx_buffer+5
        cmp     #$01
        beq     :+
        jmp     return_receive_failure
:
        lda     _fuji_rx_buffer+6
        beq     :+
        jmp     return_receive_failure
:
        lda     _fuji_rx_buffer+7
        cmp     #FN_PROTOCOL_VERSION
        beq     :+
        jmp     return_receive_failure
:

        lda     _fuji_rx_buffer+11
        sta     fuji_current_host_len

        ldy     #$00
@copy_resolved_uri:
        cpy     fuji_current_host_len
        beq     @read_dir_len
        lda     _fuji_rx_buffer+13,y
        sta     _fuji_current_host_uri,y
        iny
        bne     @copy_resolved_uri

@read_dir_len:
        ldy     fuji_current_host_len
        lda     _fuji_rx_buffer+13,y
        sta     fuji_current_dir_len

        lda     #<(_fuji_rx_buffer + 15)
        clc
        adc     fuji_current_host_len
        sta     aws_tmp08
        lda     #>(_fuji_rx_buffer + 15)
        adc     #$00
        sta     aws_tmp09

        ldy     #$00
@copy_dir:
        cpy     fuji_current_dir_len
        bne     :+
        jmp     return_receive_success
:
        lda     (aws_tmp08),y
        sta     _fuji_current_dir_path,y
        iny
        bne     @copy_dir

        lda     #$01
        rts
