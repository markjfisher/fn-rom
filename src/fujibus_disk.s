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
        .export  _fujibus_disk_write_sector
        .export  _fujibus_resolve_path

        .import  _fujibus_receive_packet
        .import  _fujibus_send_packet

        .import  fujibus_write_slip_stream
        .import  calc_checksum

        .import  pusha
        .import  pushax

        .include "fujinet.inc"


; bool fujibus_disk_mount(uint8_t flags)
;   Input:
;     A = flags
;   Output:
;     A = 1 on success, 0 on failure
;     X = 0
;
; Payload layout at fuji_data_buffer+6:
;   +0  FN_PROTOCOL_VERSION
;   +1  (*fuji_disk_slot) + 1
;   +2  flags
;   +3  0
;   +4  0
;   +5  0
;   +6  *fuji_current_fs_len
;   +7  0
;   +8+ fuji_current_fs_uri[0..len-1]
;
; Packet:
;   device  = FN_DEVICE_DISK ($FC)
;   command = DISK_CMD_MOUNT ($01)

_fujibus_disk_mount:
        ; flags
        sta     fuji_data_buffer+8

        ; fixed payload bytes
        lda     #FN_PROTOCOL_VERSION
        sta     fuji_data_buffer+6

        lda     fuji_disk_slot
        clc
        adc     #$01
        sta     fuji_data_buffer+7

        lda     #$00
        sta     fuji_data_buffer+9
        sta     fuji_data_buffer+10
        sta     fuji_data_buffer+11
        sta     fuji_data_buffer+13

        lda     fuji_current_fs_len
        sta     fuji_data_buffer+12

        ; copy URI string to fuji_data_buffer+14
        ldy     #$00
@copy_uri:
        cpy     fuji_current_fs_len
        beq     @send_packet
        lda     fuji_current_fs_uri,y
        sta     fuji_data_buffer+14,y
        iny
        bne     @copy_uri

@send_packet:
        ; call _fujibus_send_packet(
        ;   FN_DEVICE_DISK,
        ;   DISK_CMD_MOUNT,
        ;   fuji_data_buffer+6,
        ;   8 + fuji_current_fs_len
        ; )

        lda     #FN_DEVICE_DISK
        jsr     pusha

        lda     #DISK_CMD_MOUNT
        jsr     pusha

        lda     #<(fuji_data_buffer+6)
        ldx     #>(fuji_data_buffer+6)
        jsr     pushax

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
        lda     fuji_data_buffer+5
        cmp     #$01
        bne     @fail

        lda     fuji_data_buffer+6
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
;     fuji_data_buffer payload at +6
;     fuji_data_buffer response
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

_fujibus_disk_read_sector:
        ; build payload
        lda     #FN_PROTOCOL_VERSION
        sta     fuji_data_buffer+6

        lda     fuji_disk_slot
        clc
        adc     #$01
        sta     fuji_data_buffer+7

        lda     fuji_current_sector
        sta     fuji_data_buffer+8

        lda     fuji_current_sector+1
        sta     fuji_data_buffer+9

        lda     #$00
        sta     fuji_data_buffer+10
        sta     fuji_data_buffer+11
        sta     fuji_data_buffer+12

        lda     #$01
        sta     fuji_data_buffer+13

        ; send packet:
        ; _fujibus_send_packet(FN_DEVICE_DISK, DISK_CMD_READ_SECTOR, &fuji_data_buffer[6], 8)

        lda     #FN_DEVICE_DISK
        jsr     pusha

        lda     #DISK_CMD_READ_SECTOR
        jsr     pusha

        lda     #<(fuji_data_buffer+6)
        ldx     #>(fuji_data_buffer+6)
        jsr     pushax

        lda     #$08
        ldx     #$00
        jsr     _fujibus_send_packet

        ; receive response
        jsr     _fujibus_receive_packet

        ; fail if response length == 0
        cpx     #$00
        bne     @check_minlen
        cmp     #$00
        beq     @fail

        ; require at least 18 bytes to read status and data-length fields
        cmp     #$12                  ; 18
        bcc     @fail

@check_minlen:
        ; status bytes must be [5]=1, [6]=0
        lda     fuji_data_buffer+5
        cmp     #$01
        bne     @fail

        lda     fuji_data_buffer+6
        bne     @fail

        ; length at rx[16/17]
        ; only 0..256 expected here
        lda     fuji_data_buffer+17
        beq     @copy_short
        cmp     #$01
        bne     @fail

        lda     fuji_data_buffer+16
        bne     @fail                 ; >256 not expected

        ; copy exactly 256 bytes from rx[18+] to (*data_ptr)
        ldy     #$00
@copy_256:
        lda     fuji_data_buffer+18,y
        sta     (data_ptr),y
        iny
        bne     @copy_256

        lda     #$01
        ldx     #$00
        rts

@copy_short:
        ldy     #$00
        lda     fuji_data_buffer+16
        beq     @success              ; zero-length payload is allowed

@copy_loop:
        lda     fuji_data_buffer+18,y
        sta     (data_ptr),y
        iny
        cpy     fuji_data_buffer+16
        bne     @copy_loop

@success:
        lda     #$01
        ldx     #$00
        rts

@fail:
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
; Packet is built in fuji_data_buffer:
;   [0]  = FN_DEVICE_DISK
;   [1]  = DISK_CMD_WRITE_SECTOR
;   [2]  = total_len low   ($0E)
;   [3]  = total_len high  ($01)
;   [4]  = checksum
;   [5]  = descriptor (0)
;   [6]  = FN_PROTOCOL_VERSION
;   [7]  = (*fuji_disk_slot) + 1
;   [8]  = *fuji_current_sector
;   [9]  = *(fuji_current_sector+1)
;   [10] = 0
;   [11] = 0
;   [12] = 0
;   [13] = 1              ; 256 bytes
;   [14..269] = sector data
;
; Response:
;   fail if resp_len == 0
;   fail if resp_len < 7
;   fail if rx[6] != 0
;   otherwise success

_fujibus_disk_write_sector:
        ; Build full packet in fuji_data_buffer
        lda     #FN_DEVICE_DISK
        sta     fuji_data_buffer+0

        lda     #DISK_CMD_WRITE_SECTOR
        sta     fuji_data_buffer+1

        lda     #$0E                    ; 270 = $010E
        sta     fuji_data_buffer+2
        lda     #$01
        sta     fuji_data_buffer+3

        lda     #$00
        sta     fuji_data_buffer+4
        sta     fuji_data_buffer+5

        lda     #FN_PROTOCOL_VERSION
        sta     fuji_data_buffer+6

        lda     fuji_disk_slot
        clc
        adc     #$01
        sta     fuji_data_buffer+7

        lda     fuji_current_sector
        sta     fuji_data_buffer+8

        lda     fuji_current_sector+1
        sta     fuji_data_buffer+9

        lda     #$00
        sta     fuji_data_buffer+10
        sta     fuji_data_buffer+11
        sta     fuji_data_buffer+12

        lda     #$01
        sta     fuji_data_buffer+13

        ; Copy 256 bytes from (data_ptr) to fuji_data_buffer+14
        ldy     #$00
@copy_sector:
        lda     (data_ptr),y
        sta     fuji_data_buffer+14,y
        iny
        bne     @copy_sector

        ; Calculate checksum over 270-byte packet
        lda     #<fuji_data_buffer
        sta     aws_tmp00
        lda     #>fuji_data_buffer
        sta     aws_tmp01
        lda     #$0E
        sta     aws_tmp02
        lda     #$01
        sta     aws_tmp03
        jsr     calc_checksum
        sta     fuji_data_buffer+4

        ; Stream packet to serial as SLIP
        lda     #<fuji_data_buffer
        sta     aws_tmp00
        lda     #>fuji_data_buffer
        sta     aws_tmp01
        lda     #$0E
        sta     aws_tmp02
        lda     #$01
        sta     aws_tmp03
        jsr     fujibus_write_slip_stream

        ; Receive response packet
        jsr     _fujibus_receive_packet

        ; Fail if response length == 0
        cpx     #$00
        bne     @check_minlen
        cmp     #$00
        beq     @fail

        ; if low byte < 7, fail
        cmp     #$07
        bcc     @fail
        bcs     @check_status

@check_minlen:
        ; X != 0 means resp_len >= 256, so definitely >= 7
@check_status:
        ; old C only checked rx[6] == 0
        lda     fuji_data_buffer+6
        bne     @fail

        lda     #$01
        ldx     #$00
        rts

@fail:
        lda     #$00
        ldx     #$00
        rts


; bool fujibus_resolve_path(void)
;   Input:
;     fuji_current_host_uri
;     fuji_current_host_len
;   Output:
;     fuji_current_host_uri = resolved URI
;     fuji_current_host_len = resolved URI length
;     fuji_current_dir_path = display path
;     fuji_current_dir_len  = display path length
;   Returns:
;     A = 1 on success, 0 on failure
;     X = 0
;
; Request payload at fuji_data_buffer+6:
;   [6]      = FN_PROTOCOL_VERSION
;   [7]      = base_uri_len low
;   [8]      = base_uri_len high (0)
;   [9..]    = base_uri
;   [9+len]  = arg_len low  = 0
;   [10+len] = arg_len high = 0
;
; Payload length = 5 + uri_len

_fujibus_resolve_path:
        ; uri_len = *fuji_current_host_len
        lda     fuji_current_host_len
        sta     fuji_data_buffer+7

        ; payload[0] = FN_PROTOCOL_VERSION
        lda     #FN_PROTOCOL_VERSION
        sta     fuji_data_buffer+6

        ; base_uri_len high = 0
        lda     #$00
        sta     fuji_data_buffer+8

        ; copy base_uri to tx[9...]
        ldy     #$00
@copy_base_uri:
        cpy     fuji_current_host_len
        beq     @finish_request
        lda     fuji_current_host_uri,y
        sta     fuji_data_buffer+9,y
        iny
        bne     @copy_base_uri

@finish_request:
        ; arg_len = 0
        lda     #$00
        sta     fuji_data_buffer+9,y
        sta     fuji_data_buffer+10,y

        ; send:
        ; _fujibus_send_packet(FN_DEVICE_FILE, FILE_CMD_RESOLVE_PATH, &fuji_data_buffer[6], 5 + uri_len)

        lda     #FN_DEVICE_FILE
        jsr     pusha

        lda     #FILE_CMD_RESOLVE_PATH
        jsr     pusha

        lda     #<(fuji_data_buffer+6)
        ldx     #>(fuji_data_buffer+6)
        jsr     pushax

        ldx     #$00
        lda     fuji_current_host_len
        clc
        adc     #$05
        bcc     :+
        inx
:
        jsr     _fujibus_send_packet

        ; receive response
        jsr     _fujibus_receive_packet

        ; fail if response length == 0
        cpx     #$00
        bne     @check_status
        cmp     #$00
        beq     @fail

        ; require at least 13 bytes to access rx[12]
        cmp     #$0D
        bcc     @fail

@check_status:
        ; rx[5] must be 1
        lda     fuji_data_buffer+5
        cmp     #$01
        bne     @fail

        ; rx[6] must be 0
        lda     fuji_data_buffer+6
        bne     @fail

        ; rx[7] must be FN_PROTOCOL_VERSION
        lda     fuji_data_buffer+7
        cmp     #FN_PROTOCOL_VERSION
        bne     @fail

        ; resolved_uri_len = rx[11] (low byte)
        lda     fuji_data_buffer+11
        sta     fuji_current_host_len

        ; copy resolved_uri from rx[13...]
        ldy     #$00
@copy_resolved_uri:
        cpy     fuji_current_host_len
        beq     @get_dir_len
        lda     fuji_data_buffer+13,y
        sta     fuji_current_host_uri,y
        iny
        bne     @copy_resolved_uri

@get_dir_len:
        ; uri_end = 12 + host_len
        ; dir_len = rx[uri_end + 1] = rx[13 + host_len]
        lda     fuji_data_buffer+13,y
        sta     fuji_current_dir_len

        ; copy dir path from rx[uri_end + 3] = rx[15 + host_len]
        ldx     #$00
@copy_dir_path:
        cpx     fuji_current_dir_len
        beq     @success
        lda     fuji_data_buffer+15,y
        sta     fuji_current_dir_path,x
        iny
        inx
        bne     @copy_dir_path

@success:
        lda     #$01
        ldx     #$00
        rts

@fail:
        lda     #$00
        ldx     #$00
        rts