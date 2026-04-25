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

        .export  _fujibus_disk_mount
        .export  _fujibus_disk_read_sector
        .export  _fujibus_disk_read_sector_partial
        .export  _fujibus_disk_write_sector
        .export  _fujibus_resolve_path

        .import  _fujibus_receive_packet
        .import  _fujibus_send_packet

        .import  fujibus_write_slip_stream
        .import  fujibus_write_slip_stream_dual
        .import  calc_checksum
        .import  calc_checksum_continue

        .import  get_fuji_fs_uri_addr_to_aws_tmp00
        .import  get_fuji_host_uri_addr_to_aws_tmp00

        .include "fujinet.inc"


; bool fujibus_disk_mount(uint8_t flags)
;   Input:
;     A = flags
;   Output:
;     A = 1 on success, 0 on failure
;     X = 0
;
; Payload layout at buffer+6:
;   +0  FN_PROTOCOL_VERSION
;   +1  (*fuji_disk_slot) + 1
;   +2  flags
;   +3  0
;   +4  0
;   +5  0
;   +6  *fuji_current_fs_len
;   +7  0
;   +8+ current FS URI bytes (source: PWS + FUJI_FS_URI_OFFSET)
;
; Packet:
;   device  = FN_DEVICE_DISK ($FC)
;   command = DISK_CMD_MOUNT ($01)

_fujibus_disk_mount:
        ; flags
        ldy     #$08
        sta     (buffer_ptr),y

        ; fixed payload bytes
        lda     #FN_PROTOCOL_VERSION
        ldy     #$06
        sta     (buffer_ptr),y

        lda     fuji_disk_slot
        clc
        adc     #$01
        ldy     #$07
        sta     (buffer_ptr),y

        lda     #$00
        ldy     #$09
        sta     (buffer_ptr),y
        ldy     #$0A
        sta     (buffer_ptr),y
        ldy     #$0B
        sta     (buffer_ptr),y
        ldy     #$0D
        sta     (buffer_ptr),y

        lda     fuji_current_fs_len
        ldy     #$0C
        sta     (buffer_ptr),y

        ; copy URI string to buffer+14
        lda     buffer_ptr
        clc
        adc     #$0E
        sta     cws_tmp2
        lda     buffer_ptr+1
        adc     #$00
        sta     cws_tmp3

        jsr     get_fuji_fs_uri_addr_to_aws_tmp00

        ldy     #$00
@copy_uri:
        cpy     fuji_current_fs_len
        beq     @send_packet
        lda     (aws_tmp00),y
        sta     (cws_tmp2),y
        iny
        bne     @copy_uri

@send_packet:
        lda     #FN_DEVICE_DISK
        sta     fuji_bus_tx_device

        lda     #DISK_CMD_MOUNT
        sta     fuji_bus_tx_command

        lda     buffer_ptr
        clc
        adc     #$06
        sta     fuji_bus_tx_payload_lo
        lda     buffer_ptr+1
        adc     #$00
        sta     fuji_bus_tx_payload_hi

        ldx     #$00
        lda     fuji_current_fs_len
        clc
        adc     #$08
        bcc     :+
        inx
:
        jsr     _fujibus_send_packet

        ; receive response
        jsr     _fujibus_receive_packet

        ; false if response length == 0
        cpx     #$00
        bne     @check_status
        cmp     #$00
        beq     @fail

        ; optional safety: require at least 7 bytes before reading [6]
        cmp     #$07
        bcc     @fail

@check_status:
        ldy     #$05
        lda     (buffer_ptr),y
        cmp     #$01
        bne     @fail

        ldy     #$06
        lda     (buffer_ptr),y
        bne     @fail

        lda     #$01
        ldx     #$00
        rts

@fail:
        ldx     #$00
        txa
        rts

; bool fujibus_disk_read_sector(void)
;   Uses:
;     buffer payload at +6
;     buffer response
;   Output:
;     A = 1 on success, 0 on failure
;     X = 0
;
; Request payload:
;   tx[6]  = FN_PROTOCOL_VERSION
;   tx[7]  = (*fuji_disk_slot) + 1
;   tx[8]  = *fuji_current_sector
;   tx[9]  = *(fuji_current_sector+1)
;   tx[10] = 0
;   tx[11] = 0
;   tx[12] = 0
;   tx[13] = 1          ; request 256 bytes
;
; Response checks:
;   rx[5] = 1
;   rx[6] = 0
;
; Data:
;   rx[16/17] = data length
;   rx[18+]   = sector data
;   copied to (*data_ptr)
;
; Shared read path uses cws_tmp1 as max bytes to copy from payload start:
;   $00 = copy full payload (256-byte frame or entire short length)
;   nonzero = copy at most that many bytes (DFS tail sector)

; Build read-sector request, send, receive first SLIP frame, validate header
; and status params. Carry clear = ready to read length at [16]/[17] and
; payload at [18+]. Carry set = hard failure (same cases as @fail below).
disk_read_sector_common_recv:
        ; build payload
        lda     #FN_PROTOCOL_VERSION
        ldy     #$06
        sta     (buffer_ptr),y

        lda     fuji_disk_slot
        clc
        adc     #$01
        iny                                     ; y=7
        sta     (buffer_ptr),y

        lda     fuji_current_sector
        iny                                     ; y=8
        sta     (buffer_ptr),y

        lda     fuji_current_sector+1
        iny                                     ; y=9
        sta     (buffer_ptr),y

        lda     #$00
        iny                                     ; y=$0A
        sta     (buffer_ptr),y
        iny                                     ; y=$0B
        sta     (buffer_ptr),y
        iny                                     ; y=$0C
        sta     (buffer_ptr),y

        lda     #$01
        iny                                     ; y=$0D
        sta     (buffer_ptr),y

        lda     #FN_DEVICE_DISK
        sta     fuji_bus_tx_device

        lda     #DISK_CMD_READ_SECTOR
        sta     fuji_bus_tx_command

        lda     buffer_ptr
        clc
        adc     #$06
        sta     fuji_bus_tx_payload_lo
        lda     buffer_ptr+1
        adc     #$00
        sta     fuji_bus_tx_payload_hi

        lda     #$08
        ldx     #$00
        jsr     _fujibus_send_packet

        jsr     _fujibus_receive_packet

        cpx     #$00
        bne     @drc_check_minlen
        cmp     #$00
        beq     @drc_fail

@drc_check_minlen:
        cmp     #$12                  ; 18
        bcc     @drc_fail

        ldy     #$05
        lda     (buffer_ptr),y
        cmp     #$01
        bne     @drc_fail

        iny                             ; y=6
        lda     (buffer_ptr),y
        bne     @drc_fail

        clc
        rts

@drc_fail:
        sec
        rts

_fujibus_disk_read_sector_partial:
        lda     aws_tmp14
        sta     cws_tmp1
        jmp     disk_read_sector_body

_fujibus_disk_read_sector:
        lda     #$00
        sta     cws_tmp1

disk_read_sector_body:
        jsr     disk_read_sector_common_recv
        bcs     @drs_fail

        ; length at rx[16/17]; only 0..256 expected here
        ldy     #$11
        lda     (buffer_ptr),y
        beq     @drs_copy_short
        cmp     #$01
        bne     @drs_fail

        dey                             ; y=$10
        lda     (buffer_ptr),y
        bne     @drs_fail               ; >256 not expected

        lda     buffer_ptr
        clc
        adc     #$12
        sta     cws_tmp2
        lda     buffer_ptr+1
        adc     #$00
        sta     cws_tmp3

        lda     cws_tmp1
        beq     @drs_copy_full_256

        tax
        ldy     #$00
@drs_copy_n:
        lda     (cws_tmp2),y
        sta     (data_ptr),y
        iny
        dex
        bne     @drs_copy_n
        jmp     @drs_success

@drs_copy_full_256:
        ldy     #$00
@drs_copy_256:
        lda     (cws_tmp2),y
        sta     (data_ptr),y
        iny
        bne     @drs_copy_256

@drs_success:
        lda     #$01
        ldx     #$00
        rts

@drs_copy_short:
        dey                             ; y=$10
        lda     (buffer_ptr),y
        beq     @drs_success            ; zero-length payload is allowed

        tax                             ; X = packet payload length
        lda     cws_tmp1
        beq     @drs_short_setup

        stx     cws_tmp7                ; packet payload length
        lda     cws_tmp1
        cmp     cws_tmp7
        bcc     @drs_short_cap_smaller  ; cap < pkt -> use cap
        lda     cws_tmp7                ; pkt <= cap -> use pkt
        jmp     @drs_short_x
@drs_short_cap_smaller:
        lda     cws_tmp1
@drs_short_x:
        tax

@drs_short_setup:
        lda     buffer_ptr
        clc
        adc     #$12
        sta     cws_tmp2
        lda     buffer_ptr+1
        adc     #$00
        sta     cws_tmp3

        ldy     #$00
@drs_copy_loop:
        lda     (cws_tmp2),y
        sta     (data_ptr),y
        iny
        dex
        bne     @drs_copy_loop

        jmp     @drs_success

@drs_fail:
        lda     #$00
        ldx     #$00
        rts

; bool fujibus_disk_write_sector(void)
;   Input:
;     data_ptr -> 256-byte sector data
;     fuji_disk_slot
;     fuji_current_sector
;   Output:
;     A = 1 on success, 0 on failure
;     X = 0
;
; Packet is built in buffer: 14-byte header then 256 bytes from (data_ptr).
; Checksum and SLIP are computed over the full 270 bytes without copying the sector into RAM.

; header bytes are:
; FC (disk) 04 (write sector), length 0E 01, 00, 00, 01 (protocol version), disk_slot+1, 

_fujibus_disk_write_sector:
        lda     #FN_DEVICE_DISK
        ldy     #$00
        sta     (buffer_ptr),y

        lda     #DISK_CMD_WRITE_SECTOR
        iny                                     ; Y = 1
        sta     (buffer_ptr),y

        ; length
        lda     #$0E                            ; 270 = $010E
        iny                                     ; Y = 2
        sta     (buffer_ptr),y
        ; while A is 0E, store it in tmp02 for first checksum
        sta     aws_tmp02

        lda     #$01
        iny                                     ; Y = 3
        sta     (buffer_ptr),y

        ; 
        lda     #$00
        iny                                     ; Y = 4
        sta     (buffer_ptr),y
        iny                                     ; Y = 5
        sta     (buffer_ptr),y

        lda     #FN_PROTOCOL_VERSION
        iny                                     ; Y = 6
        sta     (buffer_ptr),y

        lda     fuji_disk_slot
        clc
        adc     #$01
        iny                                     ; Y = 7
        sta     (buffer_ptr),y

        lda     fuji_current_sector
        iny                                     ; Y = 8
        sta     (buffer_ptr),y

        lda     fuji_current_sector+1
        iny                                     ; Y = 9
        sta     (buffer_ptr),y

        ; I don't think it's worth putting this into the previous section where A=00, as we'd end up doing multiple ldy commands so we lose clarity and don't save any bytes
        lda     #$00
        iny                                     ; Y = 10
        sta     (buffer_ptr),y
        iny                                     ; Y = 11
        sta     (buffer_ptr),y
        iny                                     ; Y = 12
        sta     (buffer_ptr),y

        ; whilc A = 0, write tmp03 for the hi byte of the checksum length, so save a few bytes
        sta     aws_tmp03

        lda     #$01
        iny                                     ; Y = 13
        sta     (buffer_ptr),y

        ; Checksum over 14 header bytes from (buffer_ptr) then 256 from (data_ptr)
        lda     buffer_ptr
        sta     aws_tmp00
        lda     buffer_ptr+1
        sta     aws_tmp01

        ; already set above for both these bytes
        ; lda     #$0E
        ; sta     aws_tmp02
        ; lda     #$00
        ; sta     aws_tmp03
        jsr     calc_checksum

        lda     data_ptr
        sta     aws_tmp00
        lda     data_ptr+1
        sta     aws_tmp01

        ; tmp02/03 are both currently 00 from the previous checksum calculation
        ; so just inc aws_tmp03 to 1, so we have 256 in 02/03
        inc     aws_tmp03
        jsr     calc_checksum_continue

        ; write checksum to byte 4
        ldy     #$04
        sta     (buffer_ptr),y


        lda     buffer_ptr
        sta     aws_tmp00
        lda     buffer_ptr+1
        sta     aws_tmp01
        lda     #$0E
        sta     aws_tmp02
        lda     #$00
        sta     aws_tmp03

        lda     data_ptr
        sta     aws_tmp06
        lda     data_ptr+1
        sta     aws_tmp07
        lda     #$00
        sta     aws_tmp08
        lda     #$01
        sta     aws_tmp09
        jsr     fujibus_write_slip_stream_dual

        jsr     _fujibus_receive_packet

        cpx     #$00
        bne     @ws_check_minlen
        cmp     #$00
        beq     @ws_fail

        cmp     #$07
        bcc     @ws_fail
        ; fall through to status check
        ; bcs     @ws_check_status

@ws_check_minlen:
@ws_check_status:
        ldy     #$06
        lda     (buffer_ptr),y
        bne     @ws_fail

        ldx     #$00
        lda     #$01
        rts

@ws_fail:
        ldx     #$00
        txa
        rts

; bool fujibus_resolve_path(void)

_fujibus_resolve_path:

        lda     #FN_PROTOCOL_VERSION
        ldy     #$06
        sta     (buffer_ptr),y

        lda     fuji_current_host_len
        iny                                     ; y = 7
        sta     (buffer_ptr),y

        lda     #$00
        iny                                     ; y = 8
        sta     (buffer_ptr),y

        lda     buffer_ptr
        clc
        adc     #$09
        sta     cws_tmp2
        lda     buffer_ptr+1
        adc     #$00
        sta     cws_tmp3

        jsr     get_fuji_host_uri_addr_to_aws_tmp00
        ldy     #$00
@copy_base_uri:
        cpy     fuji_current_host_len
        beq     @finish_request
        lda     (aws_tmp00),y
        sta     (cws_tmp2),y
        iny
        bne     @copy_base_uri

@finish_request:
        lda     #$00
        sta     (cws_tmp2),y
        iny
        sta     (cws_tmp2),y

        lda     #FN_DEVICE_FILE
        sta     fuji_bus_tx_device

        lda     #FILE_CMD_RESOLVE_PATH
        sta     fuji_bus_tx_command

        lda     buffer_ptr
        clc
        adc     #$06
        sta     fuji_bus_tx_payload_lo
        lda     buffer_ptr+1
        adc     #$00
        sta     fuji_bus_tx_payload_hi

        ldx     #$00
        lda     fuji_current_host_len
        clc
        adc     #$05
        bcc     :+
        inx
:
        jsr     _fujibus_send_packet

        jsr     _fujibus_receive_packet

        cpx     #$00
        bne     @rp_check_status
        cmp     #$00
        beq     @rp_fail

        cmp     #$0D
        bcs     @rp_check_status

; put rp_fail into branch range
@rp_fail:
        lda     #$00
        ; ldx     #$00
        rts


@rp_check_status:
        ldy     #$05
        lda     (buffer_ptr),y
        cmp     #$01
        bne     @rp_fail

        ldy     #$06
        lda     (buffer_ptr),y
        bne     @rp_fail

        ldy     #$07
        lda     (buffer_ptr),y
        cmp     #FN_PROTOCOL_VERSION
        bne     @rp_fail

        ldy     #$0B
        lda     (buffer_ptr),y
        sta     fuji_current_host_len

        lda     buffer_ptr
        clc
        adc     #$0D
        sta     cws_tmp2
        lda     buffer_ptr+1
        adc     #$00
        sta     cws_tmp3

        jsr     get_fuji_host_uri_addr_to_aws_tmp00
        ldy     #$00
@copy_resolved_uri:
        cpy     fuji_current_host_len
        beq     @get_dir_len
        lda     (cws_tmp2),y
        sta     (aws_tmp00),y
        iny
        bne     @copy_resolved_uri

@get_dir_len:
        ; path_len u16le immediately after URI bytes in RX packet
        lda     (cws_tmp2),y
        sta     fuji_current_dir_len

        ; Display path is the suffix of the resolved URI (same bytes as wire path);
        ; fuji_dir_path_ptr() = host_uri + (host_len - dir_len). Clamp if inconsistent.
        lda     fuji_current_dir_len
        cmp     fuji_current_host_len
        beq     @dir_len_ok
        bcc     @dir_len_ok
        lda     #$00
        sta     fuji_current_dir_len
@dir_len_ok:
        ; Optional NUL after URI for C-style use when host_len < 80
        jsr     get_fuji_host_uri_addr_to_aws_tmp00
        ldy     fuji_current_host_len
        cpy     #80
        bcs     @rp_success
        lda     #$00
        sta     (aws_tmp00),y

@rp_success:
        lda     #$01
        rts
