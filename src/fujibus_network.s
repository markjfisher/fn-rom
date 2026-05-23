; FujiBus Network Commands for BBC Micro
; Implements network device commands using FujiBus protocol
;
; Wire Device ID: 0xFD (FN_DEVICE_NETWORK)
;
; Commands:
;   0x01 - Open
;   0x02 - Read
;   0x03 - Write
;   0x04 - Close

        .export  fujibus_network_open
        .export  fujibus_network_read
        .export  fujibus_network_write
        .export  fujibus_network_close
        .export  fujibus_network_translate_configure
        .export  fujibus_write_copy_start

        .importzp aws_tmp00
        .importzp aws_tmp01
        .importzp aws_tmp02
        .importzp aws_tmp03
        .importzp aws_tmp04
        .importzp aws_tmp05
        .importzp aws_tmp06
        .importzp aws_tmp07
        .importzp aws_tmp08
        .importzp aws_tmp09
        .importzp aws_tmp14
        .importzp aws_tmp15
        .importzp cws_tmp2
        .importzp cws_tmp3
        .importzp cws_tmp6
        .importzp cws_tmp7

        .importzp buffer_ptr
        .importzp fuji_bus_tx_command
        .importzp fuji_bus_tx_device
        .importzp fuji_bus_tx_payload_hi
        .importzp fuji_bus_tx_payload_lo

        .import fuji_ch_bptr_hi
        .import fuji_ch_bptr_low
        .import fuji_ch_bptr_mid
        .import fuji_ch_buf_page
        .import fuji_ch_ext_hi
        .import fuji_ch_ext_low
        .import fuji_ch_ext_mid
        .import fuji_ch_handle_high
        .import fuji_ch_handle_low
        .import fuji_ch_sect_cnt
        .import fuji_filename_buffer
        .import fuji_intch
        .import fuji_json_path_len
        .import fuji_network_buf_cnt
        .import fuji_network_buf_cnt_hi
        .import fuji_network_url_flag
        .import fujibus_receive_packet
        .import fujibus_send_packet
        .import get_fuji_json_path_addr_to_aws_tmp00
        .import network_retry_backoff
        .import network_retry_init

        .include "fujinet.inc"


; uint16_t fujibus_network_open(uint8_t method, uint8_t flags)
;   Input:
;     A = method (NET_METHOD_GET, etc)
;     X = flags (e.g. NET_FLAG_ALLOW_EVICT)
;     fuji_filename_buffer contains the URL (padded with spaces to 64 bytes)
;     fuji_network_url_flag = URL length (number of non-space bytes)
;   Output:
;     A = network handle low byte, X = network handle high byte
;     A=0, X=0 on failure
;
; Open request payload (at buffer+6):
;   +0  version = $01
;   +1  method
;   +2  flags
;   +3  urlLen (u16le)
;   +5  url bytes (urlLen bytes)
;   +5+urlLen  headerCount = 0 (u16le)
;   +5+urlLen+2 bodyLenHint = 0 (u32le)
;   +5+urlLen+6 respHeaderCount = 0 (u16le)
;   [optional] +5+urlLen+8 openExtFlags (u32le)
;   if NET_OPEN_EXT_TRANSLATION:
;     +5+urlLen+12 translationType (u8)
;     +5+urlLen+13 translationFlags (u8)
;     +5+urlLen+14 selectorLen (u16le)
;     +5+urlLen+16 selector bytes (N)

fujibus_network_open:
        stx     aws_tmp05               ; save flags
        pha                             ; save method

        ; get URL length from fuji_network_url_flag
        lda     fuji_network_url_flag
        sta     aws_tmp02               ; url_len
        lda     #$00
        sta     aws_tmp03               ; url_len high = 0

        ; version
        lda     #FN_PROTOCOL_VERSION
        ldy     #$06
        sta     (buffer_ptr),y

        ; method
        pla
        iny                             ; y = 7
        sta     (buffer_ptr),y

        ; flags
        lda     aws_tmp05
        iny                             ; y = 8
        sta     (buffer_ptr),y

        ; urlLen (u16le) at buffer+9 — low byte first
        lda     aws_tmp02               ; urlLen low byte
        iny                             ; y = 9
        sta     (buffer_ptr),y
        lda     #$00                    ; urlLen high byte = 0 (URL < 256 chars)
        iny                             ; y = 10
        sta     (buffer_ptr),y

        ; copy URL from fuji_filename_buffer to buffer+11
        lda     buffer_ptr
        clc
        adc     #$0B
        sta     cws_tmp2
        lda     buffer_ptr+1
        adc     #$00
        sta     cws_tmp3

        ldy     #$00
@copy_url:
        cpy     aws_tmp02
        beq     @write_trailing
        lda     fuji_filename_buffer,y
        sta     (cws_tmp2),y
        iny
        bne     @copy_url

@write_trailing:
        ; URL end position = buffer+11+urlLen
        tya
        clc
        adc     cws_tmp2
        sta     cws_tmp6
        lda     cws_tmp3
        adc     #$00
        sta     cws_tmp7

        ; headerCount = 0 (u16le)
        lda     #$00
        ldy     #$00
        sta     (cws_tmp6),y
        iny
        sta     (cws_tmp6),y

        ; bodyLenHint = 0 (u32le)
        iny
        sta     (cws_tmp6),y
        iny
        sta     (cws_tmp6),y
        iny
        sta     (cws_tmp6),y
        iny
        sta     (cws_tmp6),y

        ; respHeaderCount = 0 (u16le)
        iny
        sta     (cws_tmp6),y
        iny
        sta     (cws_tmp6),y

        ; optional open extension block for translation
        lda     fuji_json_path_len
        beq     @open_no_translation

        lda     #<NET_OPEN_EXT_TRANSLATION
        iny
        sta     (cws_tmp6),y            ; openExtFlags byte 0
        lda     #>NET_OPEN_EXT_TRANSLATION
        iny
        sta     (cws_tmp6),y            ; openExtFlags byte 1
        lda     #$00
        iny
        sta     (cws_tmp6),y            ; openExtFlags byte 2
        iny
        sta     (cws_tmp6),y            ; openExtFlags byte 3

        lda     #$01                    ; Json
        iny
        sta     (cws_tmp6),y
        lda     #$00                    ; translation flags
        iny
        sta     (cws_tmp6),y
        lda     fuji_json_path_len      ; selectorLen low
        iny
        sta     (cws_tmp6),y
        lda     #$00                    ; selectorLen high
        iny
        sta     (cws_tmp6),y

        ; copy selector from PWS to packet buffer
        lda     cws_tmp6
        clc
        adc     #$10                    ; selector starts after respHeaderCount + extFlags + translation block header
        sta     cws_tmp2
        lda     cws_tmp7
        adc     #$00
        sta     cws_tmp3

        jsr     get_fuji_json_path_addr_to_aws_tmp00
        ldx     #$00
@copy_selector:
        cpx     fuji_json_path_len
        beq     @open_calc_length
        ldy     #$00
        lda     (aws_tmp00),y
        sta     (cws_tmp2),y
        inc     aws_tmp00
        bne     :+
        inc     aws_tmp01
:
        inc     cws_tmp2
        bne     :+
        inc     cws_tmp3
:
        inx
        jmp     @copy_selector

@open_no_translation:
@open_calc_length:
        ; total payload length without extension = 5 + urlLen + 2 + 4 + 2 = 13 + urlLen
        ; translation extension adds: 4 extFlags + 1 + 1 + 2 + selectorLen = 8 + selectorLen
        lda     aws_tmp02
        clc
        adc     #13
        ldx     fuji_json_path_len
        beq     :+
        clc
        adc     #8
        adc     fuji_json_path_len
:       
        sta     aws_tmp02
        lda     #$00
        adc     #$00
        sta     aws_tmp03

        ; set FujiBus TX params
        lda     #FN_DEVICE_NETWORK
        sta     fuji_bus_tx_device

        lda     #NET_CMD_OPEN
        sta     fuji_bus_tx_command

        lda     buffer_ptr
        clc
        adc     #$06
        sta     fuji_bus_tx_payload_lo
        lda     buffer_ptr+1
        adc     #$00
        sta     fuji_bus_tx_payload_hi

        ldx     aws_tmp03
        lda     aws_tmp02
        jsr     fujibus_send_packet

        ; receive response
        jsr     fujibus_receive_packet

        ; check for valid response
        cpx     #$00
        bne     @check_descriptor
        cmp     #$00
        beq     @fail

@check_descriptor:
        ; minimum length: 7 (FujiBus header) + 1 (version) + 1 (flags) + 2 (reserved) + 2 (handle) + 1 (proto_flags) = 14
        cmp     #$0E
        bcc     @fail

        ; check descriptor byte
        ldy     #$05
        lda     (buffer_ptr),y
        cmp     #$01
        bne     @fail

        ; check status code
        iny                             ; y = 6
        lda     (buffer_ptr),y
        bne     @fail

        ; check accepted flag in protocol payload
        ldy     #NET_RESP_FLAGS
        lda     (buffer_ptr),y
        and     #NET_OPEN_FLAG_ACCEPTED
        beq     @fail

        ; extract handle (u16le at NET_RESP_HANDLE)
        ldy     #NET_RESP_HANDLE
        lda     (buffer_ptr),y
        tax
        iny
        lda     (buffer_ptr),y
        tay                             ; Y = handle high byte
        txa                             ; A = handle low byte
        pha
        tya
        tax                             ; X = handle high byte
        pla                             ; A = handle low byte
        rts

@fail:
        lda     #$00
        tax
        rts


; uint16_t fujibus_network_read(uint16_t handle, uint32_t offset, uint16_t max_bytes)
;   Input:
;     fuji_ch_handle_low (y) = handle low byte from channel info
;     fuji_ch_handle_high (y) = handle high byte from channel info
;     aws_tmp06/07/08/09 = 32-bit offset (little-endian)
;     aws_tmp14/15 = max_bytes (u16le)
;     Y = intch (to read handle from channel block)
;   Output:
;     A = 1 on success, 2 on NotReady, 0 on failure/EOF
;     fuji_ch_bptr_low/mid/hi updated to reflect buffer content
;     fuji_network_buf_cnt = number of valid bytes in buffer
;
; Read request payload (at buffer+6):
;   +0  version = $01
;   +1  handle (u16le)
;   +3  offset (u32le)
;   +7  maxBytes (u16le)

fujibus_network_read:
        ; save intch (Y) before using Y as buffer write index
        ; sty     aws_tmp00               ; save intch for handle reads
        tya
        tax                     ; move yintch into X for indexing

        ; build payload at buffer+6
        lda     #FN_PROTOCOL_VERSION
        ldy     #$06
        sta     (buffer_ptr),y

        ; handle (u16le) — read handle from channel block using saved intch
        lda     fuji_ch_handle_low,x
        iny                             ; y = 7
        sta     (buffer_ptr),y
        lda     fuji_ch_handle_high,x
        iny                             ; y = 8
        sta     (buffer_ptr),y

        ; offset (u32le) - from aws_tmp06..09
        lda     aws_tmp06
        iny                             ; y = 9
        sta     (buffer_ptr),y
        lda     aws_tmp07
        iny                             ; y = 10 (A)
        sta     (buffer_ptr),y
        lda     aws_tmp08
        iny                             ; y = 11 (B)
        sta     (buffer_ptr),y
        lda     aws_tmp09
        iny                             ; y = 12 (C)
        sta     (buffer_ptr),y

        ; maxBytes (u16le)
        lda     aws_tmp14
        iny                             ; y = 13 (D)
        sta     (buffer_ptr),y
        lda     aws_tmp15
        iny                             ; y = 14 (E)
        sta     (buffer_ptr),y

        ; set FujiBus TX params
        lda     #FN_DEVICE_NETWORK
        sta     fuji_bus_tx_device

        lda     #NET_CMD_READ
        sta     fuji_bus_tx_command

        lda     buffer_ptr
        clc
        adc     #$06
        sta     fuji_bus_tx_payload_lo
        lda     buffer_ptr+1
        adc     #$00
        sta     fuji_bus_tx_payload_hi

        lda     #$09                    ; 9 bytes payload (1+2+4+2)
        ldx     #$00
        jsr     fujibus_send_packet

        ; receive response
        jsr     fujibus_receive_packet

        ; check for valid response
        cpx     #$00
        bne     @check_descriptor
        cmp     #$00
        beq     @read_fail

@check_descriptor:
        ; Need at least FujiBus header so descriptor/status are present
        cmp     #$07
        bcc     @read_fail

        sta     aws_tmp05               ; save total packet length

        ; check descriptor byte
        ldy     #$05
        lda     (buffer_ptr),y
        cmp     #$01
        bne     @read_fail

        ; check status code
        iny                             ; y = 6
        lda     (buffer_ptr),y
        beq     @check_read_length       ; success
        cmp     #$04                    ; NotReady
        beq     @read_not_ready
        bne     @read_fail

@check_read_length:
        lda     aws_tmp05
        ; minimum length: 7 + 12 = 19 bytes (FujiBus hdr + network protocol hdr)
        cmp     #$13
        bcc     @read_fail

        ; get dataLen from response (u16le at NET_RESP_DATALEN = buffer+17)
        ldy     #NET_RESP_DATALEN
        lda     (buffer_ptr),y
        sta     aws_tmp02               ; dataLen low
        iny
        lda     (buffer_ptr),y
        sta     aws_tmp03               ; dataLen high

        ; store count for caller (u16le)
        lda     aws_tmp02
        sta     fuji_network_buf_cnt
        lda     aws_tmp03
        sta     fuji_network_buf_cnt_hi

        ; copy data from buffer+19 to channel buffer page
        ; channel buffer page is at fuji_ch_buf_page,y (where Y=intch was saved)
        ldy     fuji_intch
        lda     fuji_ch_buf_page,y
        sta     aws_tmp01               ; dest high byte
        lda     #$00
        sta     aws_tmp00               ; dest low byte

        ; source = buffer_ptr + NET_RESP_DATA (19)
        lda     buffer_ptr
        clc
        adc     #NET_RESP_DATA
        sta     cws_tmp2
        lda     buffer_ptr+1
        adc     #$00
        sta     cws_tmp3

        ldy     #$00
@copy_data:
        lda     aws_tmp02
        ora     aws_tmp03
        beq     @read_success

        lda     (cws_tmp2),y
        sta     (aws_tmp00),y

        inc     cws_tmp2
        bne     :+
        inc     cws_tmp3
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
        jmp     @copy_data

@read_success:
        lda     #$01
        rts

@read_not_ready:
        lda     #$02
        rts

@read_fail:
        lda     #$00
        rts


; bool fujibus_network_write(uint16_t handle, uint32_t offset, uint16_t dataLen)
;   Input:
;     aws_tmp02 = dataLen (u8) — PRESERVED
;     aws_tmp06/07/08/09 = 32-bit offset (little-endian)
;     Y = intch (to read handle from channel block)
;     Data at channel buffer page (fuji_ch_buf_page,y), offset 0
;   Output:
;     C = 0 on success, 1 on failure
;
; Write request payload (at buffer+6):
;   +0  version = $01
;   +1  handle (u16le)
;   +3  offset (u32le)
;   +7  dataLen (u16le)
;   +9  data (dataLen bytes)

fujibus_network_write:
        tya
        tax                             ; move intch into X for indexing

        ; version
        lda     #FN_PROTOCOL_VERSION
        ldy     #$06
        sta     (buffer_ptr),y

        ; handle (u16le)
        lda     fuji_ch_handle_low,x
        iny                             ; y=7
        sta     (buffer_ptr),y
        lda     fuji_ch_handle_high,x
        iny                             ; y=8
        sta     (buffer_ptr),y

        ; offset (u32le) — from aws_tmp06..09
        lda     aws_tmp06
        iny                             ; y=9
        sta     (buffer_ptr),y
        lda     aws_tmp07
        iny                             ; y=10 (A)
        sta     (buffer_ptr),y
        lda     aws_tmp08
        iny                             ; y=11 (B)
        sta     (buffer_ptr),y
        lda     aws_tmp09
        iny                             ; y=12 (C)
        sta     (buffer_ptr),y

        ; dataLen (u8) — from input aws_tmp02, extended to 16 bit
        lda     aws_tmp02
        iny                             ; y=13 (D)
        sta     (buffer_ptr),y
        lda     #$00                    ; high byte of byte count is always 00
        iny                             ; y=14 (E)
        sta     (buffer_ptr),y
        ; OPTIMIZATION: store 00 in source low byte while A=0
        sta     aws_tmp00

        ; save original dataLen for payload size calculation
        sta     aws_tmp15               ; high byte of total payload (aw_tmp15 was maxBytes high)

        lda     aws_tmp02               ; reload the data length
        ; total payload = 9 + dataLen
        clc
        adc     #$09
        sta     aws_tmp14               ; low byte
        bcc     fujibus_write_copy_start
        lda     #$01
        sta     aws_tmp15               ; high byte, can never be larger than 255+9

        ; Copy data from channel buffer page (offset 0) to buffer+15
fujibus_write_copy_start:
        ldy     fuji_intch
        lda     fuji_ch_buf_page,y
        sta     aws_tmp01               ; source high byte (buffer page)

        ; THIS IS DONE ABOVE WHILE A=0
        ; lda     #$00
        ; sta     aws_tmp00               ; source low byte = 0

        ; dest = buffer_ptr + 15
        lda     buffer_ptr
        clc
        adc     #$0F
        sta     cws_tmp2
        lda     buffer_ptr+1
        adc     #$00
        sta     cws_tmp3

        ; at this point, we can only have a count of $FF max in tmp02/03
        ; it cannot be 00 meaning there are 00 bytes, as we've already checked the write
        ; count in fuji_ch_write_count, which is a single byte, so we can safely
        ; just set y to aws_tmp02, loop over all bytes with y as counter
        ; this reduces 16 bit copy of 33 bytes to about 13
        ldy     aws_tmp02
@copy_wr_data:
        cpy     #$00
        beq     @send_write

        dey                             ; y in range (0, tmp_aws02-1)

        lda     (aws_tmp00),y
        sta     (cws_tmp2),y
        ; carry is set from the cpy, as it's always greater than 00 until we have to exit
        bcs     @copy_wr_data

@send_write:
        ; set FujiBus TX params
        lda     #FN_DEVICE_NETWORK
        sta     fuji_bus_tx_device

        lda     #NET_CMD_WRITE
        sta     fuji_bus_tx_command

        lda     buffer_ptr
        clc
        adc     #$06
        sta     fuji_bus_tx_payload_lo
        lda     buffer_ptr+1
        adc     #$00
        sta     fuji_bus_tx_payload_hi

        ldx     aws_tmp15               ; payload size high
        lda     aws_tmp14               ; payload size low
        jsr     fujibus_send_packet

        ; receive response
        jsr     fujibus_receive_packet

        ; check for valid response
        cpx     #$00
        bne     @wr_check_desc
        cmp     #$00
        beq     @wr_fail

@wr_check_desc:
        ; minimum: 7 + 6 + 4 = 17 bytes
        cmp     #$11
        bcc     @wr_fail

        ; check descriptor byte
        ldy     #$05
        lda     (buffer_ptr),y
        cmp     #$01
        bne     @wr_fail

        ; check status code
        iny
        lda     (buffer_ptr),y
        bne     @wr_fail

        clc
        rts

@wr_fail:
        sec
        rts

; bool fujibus_network_close(uint16_t handle)
;   Input:
;     fuji_ch_handle_low (y) = handle low byte
;     fuji_ch_handle_high (y) = handle high byte
;     Y = intch
;   Output:
;     C = 0 on success, 1 on failure
;
; Close request payload (at buffer+6):
;   +0  version = $01
;   +1  handle (u16le)

fujibus_network_close:
        ldx     fuji_intch

        ; version
        lda     #FN_PROTOCOL_VERSION
        ldy     #$06
        sta     (buffer_ptr),y

        ; handle (u16le) — read handle from channel block using saved intch
        lda     fuji_ch_handle_low,x
        iny                                     ; y=7
        sta     (buffer_ptr),y
        lda     fuji_ch_handle_high,x
        iny                                     ; y=8
        sta     (buffer_ptr),y

        ; set FujiBus TX params
        lda     #FN_DEVICE_NETWORK
        sta     fuji_bus_tx_device

        lda     #NET_CMD_CLOSE
        sta     fuji_bus_tx_command

        lda     buffer_ptr
        clc
        adc     #$06
        sta     fuji_bus_tx_payload_lo
        lda     buffer_ptr+1
        adc     #$00
        sta     fuji_bus_tx_payload_hi

        lda     #$03                    ; 3 bytes payload
        ldx     #$00
        jsr     fujibus_send_packet

        ; receive response
        jsr     fujibus_receive_packet

        ; check for valid response
        cpx     #$00
        bne     @check_descriptor
        cmp     #$00
        beq     @close_fail

@check_descriptor:
        ; minimum: 7 + 4 = 11 bytes
        cmp     #$0B
        bcc     @close_fail

        ; check descriptor byte
        ldy     #$05
        lda     (buffer_ptr),y
        cmp     #$01
        bne     @close_fail

        ; check status code
        iny                             ; y = 6
        lda     (buffer_ptr),y
        bne     @close_fail

        clc
        rts

@close_fail:
        sec
        rts


; bool fujibus_network_translate_configure(uint16_t handle)
;   Input:
;     fuji_ch_handle_low (y) = handle low byte
;     fuji_ch_handle_high (y) = handle high byte
;     Y = intch
;     JSON path in PWS buffer (set by *FJSON via get_fuji_json_path_addr_to_aws_tmp00)
;     fuji_json_path_len = length of JSON path string
;   Output:
;     A = 1 on success, 0 on failure
;
; TranslateConfigure request payload (at buffer+6):
;   +0  version = $01
;   +1  handle (u16le)
;   +3  translationType (u8)
;   +4  translationFlags (u8)
;   +5  selectorLen (u16le)
;   +7  selector bytes (N)

fujibus_network_translate_configure:
        sty     aws_tmp00               ; save intch (for handle byte reading)
        sty     cws_tmp3                ; also save in location not clobbered by path copy
        tya
        pha                             ; push intch on stack (survives send/receive)
        jsr     network_retry_init

fnjq_build_request:
        ; version
        lda     #FN_PROTOCOL_VERSION
        ldy     #$06
        sta     (buffer_ptr),y

        ; handle (u16le) — use cws_tmp3 (preserved across path copy, unlike aws_tmp00)
        ldy     cws_tmp3
        lda     fuji_ch_handle_low,y
        ldy     #$07
        sta     (buffer_ptr),y
        ldy     cws_tmp3
        lda     fuji_ch_handle_high,y
        ldy     #$08
        sta     (buffer_ptr),y

        ; translationType / translationFlags / selectorLen
        lda     #$01                    ; Json
        ldy     #$09
        sta     (buffer_ptr),y
        lda     #$00                    ; translationFlags
        iny
        sta     (buffer_ptr),y
        lda     fuji_json_path_len
        iny
        sta     (buffer_ptr),y
        lda     #$00
        iny
        sta     (buffer_ptr),y          ; high byte = 0
        iny

        ; Copy JSON path from PWS buffer to packet buffer
        sty     aws_tmp02               ; save dest buffer index (Y = 11 after pathLen)
        jsr     get_fuji_json_path_addr_to_aws_tmp00
        ; aws_tmp00/01 = PWS + FUJI_JSON_PATH_OFFSET

        ldx     #$00                    ; byte count
fnjq_copy_path:
        cpx     fuji_json_path_len
        beq     fnjq_send_translate_configure

        ; Read from PWS: advance pointer for each byte (can't use (zp),X)
        ldy     #$00
        lda     (aws_tmp00),y
        pha                             ; save byte
        ; Advance PWS pointer
        lda     aws_tmp00
        clc
        adc     #$01
        sta     aws_tmp00
        lda     aws_tmp01
        adc     #$00
        sta     aws_tmp01
        ; Write to packet buffer
        ldy     aws_tmp02
        pla
        sta     (buffer_ptr),y
        inc     aws_tmp02
        inx
        jmp     fnjq_copy_path

fnjq_send_translate_configure:
        ; set FujiBus TX params
        lda     #FN_DEVICE_NETWORK
        sta     fuji_bus_tx_device

        lda     #NET_CMD_TRANSLATE_CONFIGURE
        sta     fuji_bus_tx_command

        lda     buffer_ptr
        clc
        adc     #$06
        sta     fuji_bus_tx_payload_lo
        lda     buffer_ptr+1
        adc     #$00
        sta     fuji_bus_tx_payload_hi

        ; payload size = 7 (ver+handle+type+flags+selectorLen) + selectorLen
        lda     fuji_json_path_len
        clc
        adc     #$07
        bcc     fnjq_payload_hi_zero
        ldx     #$01
        jmp     fnjq_send_jq
fnjq_payload_hi_zero:
        ldx     #$00
fnjq_send_jq:
        jsr     fujibus_send_packet

        ; receive response
        jsr     fujibus_receive_packet

        ; check for valid response
        cpx     #$00
        bne     fnjq_jq_check_desc
        cmp     #$00
        beq     fnjq_jq_fail

fnjq_jq_check_desc:
        ; Save total length for later size validation
        sta     aws_tmp02

        ; Must be at least 7 bytes (FujiBus header)
        cmp     #$07
        bcc     fnjq_jq_fail

        ; check descriptor byte (always in header at buffer+5)
        ldy     #$05
        lda     (buffer_ptr),y
        cmp     #$01
        bne     fnjq_jq_fail

        ; check status code (always in header at buffer+6)
        iny
        lda     (buffer_ptr),y
        beq     fnjq_jq_check_len            ; 0 = success, verify full length
        cmp     #$04                     ; 4 = NotReady: body not yet cached
        beq     fnjq_jq_retry
        bne     fnjq_jq_fail                 ; other error

fnjq_jq_check_len:
        ; Success response: minimum 7 + 1 + 1 + 2 + 2 + 4 = 17 bytes
        lda     aws_tmp02               ; restore total length from earlier
        cmp     #$11
        bcc     fnjq_jq_fail
        beq     fnjq_jq_success         ; we had a success code before we checked the length, so we can jump to success now

fnjq_jq_retry:
        jsr     network_retry_backoff
        bcs     fnjq_jq_fail
        jmp     fnjq_build_request

fnjq_jq_success:
        ; Read translatedSize from response (u32le at buffer+13)
        ldy     #$0D
        lda     (buffer_ptr),y          ; size low
        sta     aws_tmp02               ; save low
        iny
        lda     (buffer_ptr),y          ; size mid
        sta     aws_tmp03               ; save high
        iny
        lda     (buffer_ptr),y          ; size high
        sta     aws_tmp04
        iny
        lda     (buffer_ptr),y          ; size upper24-31, ignored unless non-zero
        beq     :+
        lda     #$FF
        sta     aws_tmp04
:

        ; Update EXT/PTR in channel block
        pla                             ; restore intch from stack
        tay
        sty     fuji_intch              ; set for BGET's @net_eof handler

        lda     aws_tmp02
        sta     fuji_ch_ext_low,y
        lda     aws_tmp03
        sta     fuji_ch_ext_mid,y
        lda     aws_tmp04
        sta     fuji_ch_ext_hi,y

        lda     #$00
        sta     fuji_ch_bptr_low,y
        sta     fuji_ch_bptr_mid,y
        sta     fuji_ch_bptr_hi,y

        sta     fuji_ch_sect_cnt,y      ; clear stale buffer count

        lda     #$01
        rts

fnjq_jq_fail:
        pla                             ; balance stack (intch was pushed at start)
        lda     #$00
        rts
