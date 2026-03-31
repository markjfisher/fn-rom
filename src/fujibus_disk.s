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
        .import  fujibus_write_slip_stream_dual
        .import  calc_checksum
        .import  calc_checksum_continue

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
; Payload layout at buffer+6:
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

        ldy     #$00
@copy_uri:
        cpy     fuji_current_fs_len
        beq     @send_packet
        lda     fuji_current_fs_uri,y
        sta     (cws_tmp2),y
        iny
        bne     @copy_uri

@send_packet:
        lda     #FN_DEVICE_DISK
        jsr     pusha

        lda     #DISK_CMD_MOUNT
        jsr     pusha

        lda     buffer_ptr
        clc
        adc     #$06
        sta     cws_tmp2
        lda     buffer_ptr+1
        adc     #$00
        sta     cws_tmp3
        lda     cws_tmp2
        ldx     cws_tmp3
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

_fujibus_disk_read_sector:
        ; build payload
        lda     #FN_PROTOCOL_VERSION
        ldy     #$06
        sta     (buffer_ptr),y

        lda     fuji_disk_slot
        clc
        adc     #$01
        ldy     #$07
        sta     (buffer_ptr),y

        lda     fuji_current_sector
        ldy     #$08
        sta     (buffer_ptr),y

        lda     fuji_current_sector+1
        ldy     #$09
        sta     (buffer_ptr),y

        lda     #$00
        ldy     #$0A
        sta     (buffer_ptr),y
        ldy     #$0B
        sta     (buffer_ptr),y
        ldy     #$0C
        sta     (buffer_ptr),y

        lda     #$01
        ldy     #$0D
        sta     (buffer_ptr),y

        ; send packet:
        ; _fujibus_send_packet(FN_DEVICE_DISK, DISK_CMD_READ_SECTOR, &buffer[6], 8)

        lda     #FN_DEVICE_DISK
        jsr     pusha

        lda     #DISK_CMD_READ_SECTOR
        jsr     pusha

        lda     buffer_ptr
        clc
        adc     #$06
        sta     cws_tmp2
        lda     buffer_ptr+1
        adc     #$00
        sta     cws_tmp3
        lda     cws_tmp2
        ldx     cws_tmp3
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
        ldy     #$05
        lda     (buffer_ptr),y
        cmp     #$01
        bne     @fail

        ldy     #$06
        lda     (buffer_ptr),y
        bne     @fail

        ; length at rx[16/17]
        ; only 0..256 expected here
        ldy     #$11
        lda     (buffer_ptr),y
        beq     @copy_short
        cmp     #$01
        bne     @fail

        ldy     #$10
        lda     (buffer_ptr),y
        bne     @fail                 ; >256 not expected

        ; copy exactly 256 bytes from rx[18+] to (*data_ptr)
        lda     buffer_ptr
        clc
        adc     #$12
        sta     cws_tmp2
        lda     buffer_ptr+1
        adc     #$00
        sta     cws_tmp3

        ldy     #$00
@copy_256:
        lda     (cws_tmp2),y
        sta     (data_ptr),y
        iny
        bne     @copy_256

        lda     #$01
        ldx     #$00
        rts

@copy_short:
        ldy     #$10
        lda     (buffer_ptr),y
        beq     @success              ; zero-length payload is allowed

        tax
        lda     buffer_ptr
        clc
        adc     #$12
        sta     cws_tmp2
        lda     buffer_ptr+1
        adc     #$00
        sta     cws_tmp3

        ldy     #$00
@copy_loop:
        lda     (cws_tmp2),y
        sta     (data_ptr),y
        iny
        dex
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
; Packet is built in buffer: 14-byte header then 256 bytes from (data_ptr).
; Checksum and SLIP are computed over the full 270 bytes without copying the sector into RAM.

_fujibus_disk_write_sector:
        lda     #FN_DEVICE_DISK
        ldy     #$00
        sta     (buffer_ptr),y

        lda     #DISK_CMD_WRITE_SECTOR
        ldy     #$01
        sta     (buffer_ptr),y

        lda     #$0E                    ; 270 = $010E
        ldy     #$02
        sta     (buffer_ptr),y
        lda     #$01
        ldy     #$03
        sta     (buffer_ptr),y

        lda     #$00
        ldy     #$04
        sta     (buffer_ptr),y
        ldy     #$05
        sta     (buffer_ptr),y

        lda     #FN_PROTOCOL_VERSION
        ldy     #$06
        sta     (buffer_ptr),y

        lda     fuji_disk_slot
        clc
        adc     #$01
        ldy     #$07
        sta     (buffer_ptr),y

        lda     fuji_current_sector
        ldy     #$08
        sta     (buffer_ptr),y

        lda     fuji_current_sector+1
        ldy     #$09
        sta     (buffer_ptr),y

        lda     #$00
        ldy     #$0A
        sta     (buffer_ptr),y
        ldy     #$0B
        sta     (buffer_ptr),y
        ldy     #$0C
        sta     (buffer_ptr),y

        lda     #$01
        ldy     #$0D
        sta     (buffer_ptr),y

        ; Checksum over 14 header bytes then 256 from (data_ptr)
        lda     buffer_ptr
        sta     aws_tmp00
        lda     buffer_ptr+1
        sta     aws_tmp01
        lda     #$0E
        sta     aws_tmp02
        lda     #$00
        sta     aws_tmp03
        jsr     calc_checksum

        lda     data_ptr
        sta     aws_tmp00
        lda     data_ptr+1
        sta     aws_tmp01
        lda     #$00
        sta     aws_tmp02
        lda     #$01
        sta     aws_tmp03
        jsr     calc_checksum_continue

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
        bcs     @ws_check_status

@ws_check_minlen:
@ws_check_status:
        ldy     #$06
        lda     (buffer_ptr),y
        bne     @ws_fail

        lda     #$01
        ldx     #$00
        rts

@ws_fail:
        lda     #$00
        ldx     #$00
        rts

; bool fujibus_resolve_path(void)

_fujibus_resolve_path:
        lda     fuji_current_host_len
        ldy     #$07
        sta     (buffer_ptr),y

        lda     #FN_PROTOCOL_VERSION
        ldy     #$06
        sta     (buffer_ptr),y

        lda     #$00
        ldy     #$08
        sta     (buffer_ptr),y

        lda     buffer_ptr
        clc
        adc     #$09
        sta     cws_tmp2
        lda     buffer_ptr+1
        adc     #$00
        sta     cws_tmp3

        ldy     #$00
@copy_base_uri:
        cpy     fuji_current_host_len
        beq     @finish_request
        lda     fuji_current_host_uri,y
        sta     (cws_tmp2),y
        iny
        bne     @copy_base_uri

@finish_request:
        lda     #$00
        sta     (cws_tmp2),y
        iny
        sta     (cws_tmp2),y

        lda     #FN_DEVICE_FILE
        jsr     pusha

        lda     #FILE_CMD_RESOLVE_PATH
        jsr     pusha

        lda     buffer_ptr
        clc
        adc     #$06
        sta     cws_tmp2
        lda     buffer_ptr+1
        adc     #$00
        sta     cws_tmp3
        lda     cws_tmp2
        ldx     cws_tmp3
        jsr     pushax

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
        bcc     @rp_fail

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

        ldy     #$00
@copy_resolved_uri:
        cpy     fuji_current_host_len
        beq     @get_dir_len
        lda     (cws_tmp2),y
        sta     fuji_current_host_uri,y
        iny
        bne     @copy_resolved_uri

@get_dir_len:
        lda     (cws_tmp2),y
        sta     fuji_current_dir_len

        lda     buffer_ptr
        clc
        adc     #$0F
        sta     cws_tmp2
        lda     buffer_ptr+1
        adc     #$00
        sta     cws_tmp3

        ldx     #$00
@copy_dir_path:
        cpx     fuji_current_dir_len
        beq     @rp_success
        lda     (cws_tmp2),y
        sta     fuji_current_dir_path,x
        iny
        inx
        bne     @copy_dir_path

@rp_success:
        lda     #$01
        ldx     #$00
        rts

@rp_fail:
        lda     #$00
        ldx     #$00
        rts
