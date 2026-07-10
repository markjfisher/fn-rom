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

        .export  fujibus_disk_create
        .export  fujibus_disk_mount
        .export  fujibus_disk_read_sector
        .export  fujibus_disk_read_sector_partial
        .export  fujibus_disk_unmount
        .export  fujibus_disk_write_sector
        .export  fujibus_resolve_path
        .export  fd_check_ok_response

        .importzp aws_tmp00
        .importzp aws_tmp01
        .importzp aws_tmp02
        .importzp aws_tmp03
        .importzp aws_tmp06
        .importzp aws_tmp07
        .importzp aws_tmp08
        .importzp aws_tmp09
        .importzp aws_tmp14
        .importzp cws_tmp1
        .importzp cws_tmp2
        .importzp cws_tmp3
        .importzp cws_tmp7

        .importzp buffer_ptr
        .importzp data_ptr
        .importzp fuji_bus_tx_command
        .importzp fuji_bus_tx_device
        .import calc_checksum
        .import calc_checksum_continue
        .import copy_aws_tmp00_to_aws_tmp02_a
        .import fuji_current_dir_len
        .import fuji_current_fs_len
        .import fuji_current_sector
        .import fuji_disk_slot
        .import fujibus_receive_packet
        .import fujibus_set_payload_buffer_ptr
        .import fujibus_send_packet
        .import fuji_link_write_slip_frame_dual
        .import get_fuji_fs_uri_addr_to_aws_tmp00

        .include "fujinet.inc"

DISK_CREATE_TYPE_SSD        = $02
DISK_CREATE_SECTOR_SIZE_LO  = $00
DISK_CREATE_SECTOR_SIZE_HI  = $01
DISK_CREATE_SECTOR_COUNT_0  = $20
DISK_CREATE_SECTOR_COUNT_1  = $03
DISK_CREATE_SECTOR_COUNT_2  = $00
DISK_CREATE_SECTOR_COUNT_3  = $00


; fujibus_disk_create
;   Input:
;     A = create flags (bit0 = overwrite)
;     fuji_current_fs_len / PWS FS URI buffer contain the target URI
;   Output:
;     C clear on success, set on failure

; Payload layout at buffer+6:
;   +0  FN_PROTOCOL_VERSION
;   +1  flags
;   +2  image type (SSD)
;   +3  sector size low  (256)
;   +4  sector size high
;   +5  sector count byte 0 (800)
;   +6  sector count byte 1
;   +7  sector count byte 2
;   +8  sector count byte 3
;   +9  uri_len low
;   +10 uri_len high
;   +11+ uri bytes

fujibus_disk_create:
        sta     cws_tmp7

        lda     #FN_PROTOCOL_VERSION
        ldy     #$06
        sta     (buffer_ptr),y

        lda     cws_tmp7
        iny                                     ; y=7
        sta     (buffer_ptr),y

        lda     #DISK_CREATE_TYPE_SSD
        iny                                     ; y=8
        sta     (buffer_ptr),y

        lda     #DISK_CREATE_SECTOR_SIZE_LO
        iny                                     ; y=9
        sta     (buffer_ptr),y

        lda     #DISK_CREATE_SECTOR_SIZE_HI
        iny                                     ; y=10
        sta     (buffer_ptr),y

        lda     #DISK_CREATE_SECTOR_COUNT_0
        iny                                     ; y=11
        sta     (buffer_ptr),y

        lda     #DISK_CREATE_SECTOR_COUNT_1
        iny                                     ; y=12
        sta     (buffer_ptr),y

        lda     #DISK_CREATE_SECTOR_COUNT_2
        iny                                     ; y=13
        sta     (buffer_ptr),y

        lda     #DISK_CREATE_SECTOR_COUNT_3
        iny                                     ; y=14
        sta     (buffer_ptr),y

        lda     fuji_current_fs_len
        iny                                     ; y=15
        sta     (buffer_ptr),y

        lda     #$00
        iny                                     ; y=16
        sta     (buffer_ptr),y

        lda     buffer_ptr
        clc
        adc     #$11
        sta     aws_tmp02
        lda     buffer_ptr+1
        adc     #$00
        sta     aws_tmp03

        jsr     get_fuji_fs_uri_addr_to_aws_tmp00
        lda     fuji_current_fs_len
        jsr     copy_aws_tmp00_to_aws_tmp02_a

@send_packet:
        lda     #FN_DEVICE_DISK
        sta     fuji_bus_tx_device

        lda     #DISK_CMD_CREATE
        sta     fuji_bus_tx_command

        jsr     fujibus_set_payload_buffer_ptr

        ldx     #$00
        lda     fuji_current_fs_len
        clc
        adc     #$0B
        bcc     :+
        inx
:
        jsr     fujibus_send_packet

        jsr     fujibus_receive_packet
        cmp     #$07
        jsr     fd_check_ok_response
        bcs     @fail

        clc
        rts

@fail:
        sec
        rts

; fujibus_disk_mount
;   Input:
;     A = flags
;   Output:
;     C clear on success, set on failure
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

fujibus_disk_mount:
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
        sta     aws_tmp02
        lda     buffer_ptr+1
        adc     #$00
        sta     aws_tmp03

        jsr     get_fuji_fs_uri_addr_to_aws_tmp00
        lda     fuji_current_fs_len
        jsr     copy_aws_tmp00_to_aws_tmp02_a

@send_packet:
        lda     #FN_DEVICE_DISK
        sta     fuji_bus_tx_device

        lda     #DISK_CMD_MOUNT
        sta     fuji_bus_tx_command

        jsr     fujibus_set_payload_buffer_ptr

        ldx     #$00
        lda     fuji_current_fs_len
        clc
        adc     #$08
        bcc     :+
        inx
:
        jsr     fujibus_send_packet

        ; receive response
        jsr     fujibus_receive_packet
        cmp     #$07
        jsr     fd_check_ok_response
        bcs     @fail

        clc
        rts

@fail:
        sec
        rts

; fujibus_disk_unmount
;   Output:
;     C clear on success, set on failure
;
; Payload layout at buffer+6:
;   +0  FN_PROTOCOL_VERSION
;   +1  (*fuji_disk_slot) + 1

fujibus_disk_unmount:
        lda     #FN_PROTOCOL_VERSION
        ldy     #$06
        sta     (buffer_ptr),y

        lda     fuji_disk_slot
        clc
        adc     #$01
        iny                             ; y=7
        sta     (buffer_ptr),y

        lda     #FN_DEVICE_DISK
        sta     fuji_bus_tx_device

        lda     #DISK_CMD_UNMOUNT
        sta     fuji_bus_tx_command

        jsr     fujibus_set_payload_buffer_ptr

        ldx     #$00
        lda     #$02
        jsr     fujibus_send_packet

        jsr     fujibus_receive_packet
        cmp     #$08
        jsr     fd_check_ok_response
        bcs     @du_fail

        clc
        rts

@du_fail:
        sec
        rts

; fujibus_disk_read_sector
;   Uses:
;     buffer payload at +6
;     buffer response
;   Output:
;     C clear on success, set on failure
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

        jsr     fujibus_set_payload_buffer_ptr

        lda     #$08
        ldx     #$00
        jsr     fujibus_send_packet

        jsr     fujibus_receive_packet
        cmp     #$12                  ; 18
        jsr     fd_check_ok_response
        bcs     @drc_fail

        clc
        rts

@drc_fail:
        sec
        rts

fujibus_disk_read_sector_partial:
        lda     aws_tmp14
        sta     cws_tmp1
        jmp     disk_read_sector_body

fujibus_disk_read_sector:
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
        clc
        rts

@drs_copy_short:
        dey                             ; y=$10
        lda     (buffer_ptr),y
        beq     @drs_success            ; zero-length payload is allowed

        tax                             ; X = packet payload length
        lda     cws_tmp1
        beq     @drs_short_setup

        txa
        cmp     cws_tmp1
        bcc     @drs_short_cap_smaller  ; cap < pkt -> use cap
        txa                             ; pkt <= cap -> use pkt
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
        sec
        rts

; fujibus_disk_write_sector
;   Input:
;     data_ptr -> 256-byte sector data
;     fuji_disk_slot
;     fuji_current_sector
;   Output:
;     C clear on success, set on failure
;
; Packet is built in buffer: 14-byte header then 256 bytes from (data_ptr).
; Checksum and SLIP are computed over the full 270 bytes without copying the sector into RAM.

; header bytes are:
; FC (disk) 04 (write sector), length 0E 01, 00, 00, 01 (protocol version), disk_slot+1, 

fujibus_disk_write_sector:
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

        lda     #$01
        iny                                     ; Y = 13
        sta     (buffer_ptr),y

        ; Checksum over 14 header bytes from (buffer_ptr) then 256 from (data_ptr)
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
        jsr     fuji_link_write_slip_frame_dual

        jsr     fujibus_receive_packet

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

        clc
        rts

@ws_fail:
        sec
        rts

; fujibus_resolve_path
; obsolete: current HOST/path resolution now lives in FujiNet-NIO AppStore helpers.
fujibus_resolve_path:
        sec
        rts

; Validate a simple disk OK response after FujiBus transport receive.
; Input: A = minimum total packet length, X = received length high.
; Output: C clear = ok, C set = fail.
fd_check_ok_response:
        sta     aws_tmp14
        cpx     #$00
        bne     @fd_len_ok
        cmp     #$00
        beq     @fd_fail
@fd_len_ok:
        cmp     aws_tmp14
        bcc     @fd_fail
        ldy     #$05
        lda     (buffer_ptr),y
        cmp     #$01
        bne     @fd_fail
        iny
        lda     (buffer_ptr),y
        bne     @fd_fail
        clc
        rts
@fd_fail:
        sec
        rts
