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
        .export  fujibus_network_write_ext
        .export  fujibus_network_close
        .export  fujibus_network_translate_configure
        .export  fujibus_write_copy_start

        .export  read_fail
        .export  read_not_ready
        .export  check_read_length
        .export  check_descriptor
        .export  nw_open_before_receive
        .export  nw_open_after_receive
        .export  nw_read_before_receive
        .export  nw_read_after_receive
        .export  nw_json_before_receive
        .export  nw_json_after_receive
        .export  nw_check_ok_response
        .export  nw_build_write_prefix
        .export  nw_build_open_prefix

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
        .importzp aws_tmp10
        .importzp aws_tmp11
        .importzp aws_tmp14
        .importzp aws_tmp15
        .importzp cws_tmp2
        .importzp cws_tmp3
        .importzp cws_tmp6
        .importzp cws_tmp7

        .importzp buffer_ptr
        .importzp fuji_bus_tx_command
        .importzp fuji_bus_tx_device
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
        .import fuji_ch_write_pos_low
        .import fuji_ch_write_pos_mid
        .import fuji_ch_write_pos_hi
        .import fuji_filename_buffer
        .import fuji_intch
        .import fuji_json_path_len
        .import fuji_network_body_len
        .import fuji_network_body_len_hi
        .import fuji_network_buf_cnt
        .import fuji_network_buf_cnt_hi
        .import fuji_network_url_flag
        .import fuji_ext_str_flags
        .import fuji_ext_str_len
        .import fuji_ext_str_len_hi
        .import fuji_ext_str_ptr
        .import copy_aws_tmp00_to_aws_tmp02_a
        .import fujibus_receive_packet_raw
        .import fujibus_set_payload_buffer_ptr
        .import fujibus_send_packet_raw
        .import fujibus_send_packet_scatter_raw
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
        sta     aws_tmp04               ; save method

        lda     fuji_ext_str_flags
        and     #FUJI_EXT_STR_ACTIVE
        beq     @open_buffer_path

        jmp     @open_ext_str_path

@open_buffer_path:
        ; get URL length from fuji_network_url_flag (legacy <=255)
        lda     fuji_network_url_flag
        sta     aws_tmp02               ; url_len
        lda     #$00
        sta     aws_tmp03               ; url_len high = 0

        jsr     nw_build_open_prefix

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

        jmp     @write_trailing

@open_ext_str_path:
        ; url length from fuji_ext_str_len (u16le)
        lda     fuji_ext_str_len
        sta     aws_tmp02
        lda     fuji_ext_str_len_hi
        sta     aws_tmp03

        jsr     nw_build_open_prefix

@write_trailing:
        ; trailing fields start at buffer+11 (after urlLen)
        lda     buffer_ptr
        clc
        adc     #$0B
        sta     cws_tmp6
        lda     buffer_ptr+1
        adc     #$00
        sta     cws_tmp7

        ; headerCount = 0 (u16le)
        lda     #$00
        ldy     #$00
        sta     (cws_tmp6),y
        iny
        sta     (cws_tmp6),y

        ; bodyLenHint (u32le) - one-shot hint for POST/PUT requests
        lda     fuji_network_body_len
        sta     aws_tmp10
        lda     fuji_network_body_len_hi
        sta     aws_tmp11
        lda     aws_tmp04               ; saved method
        cmp     #NET_METHOD_POST
        beq     @body_hint_ok
        cmp     #NET_METHOD_PUT
        beq     @body_hint_ok
        lda     #$00
        sta     aws_tmp10
        sta     aws_tmp11
@body_hint_ok:
        ldy     #$02
        lda     aws_tmp10
        sta     (cws_tmp6),y
        iny
        lda     aws_tmp11
        sta     (cws_tmp6),y
        iny
        lda     #$00
        sta     (cws_tmp6),y
        iny
        sta     (cws_tmp6),y

        ; clear one-shot body hint after consuming it
        sta     fuji_network_body_len
        sta     fuji_network_body_len_hi

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
        sta     (cws_tmp6),y
        lda     #>NET_OPEN_EXT_TRANSLATION
        iny
        sta     (cws_tmp6),y
        lda     #$00
        iny
        sta     (cws_tmp6),y
        iny
        sta     (cws_tmp6),y

        lda     #$01
        iny
        sta     (cws_tmp6),y
        lda     #$00
        iny
        sta     (cws_tmp6),y

        lda     fuji_json_path_len
        iny
        sta     (cws_tmp6),y
        lda     #$00
        iny
        sta     (cws_tmp6),y

        ; copy selector from PWS to packet buffer
        lda     cws_tmp6
        clc
        adc     #$10
        sta     cws_tmp2
        lda     cws_tmp7
        adc     #$00
        sta     cws_tmp3

        jsr     get_fuji_json_path_addr_to_aws_tmp00
        lda     cws_tmp2
        sta     aws_tmp02
        lda     cws_tmp3
        sta     aws_tmp03
        lda     fuji_json_path_len
        jsr     copy_aws_tmp00_to_aws_tmp02_a

@open_no_translation:
@open_calc_length:
        ; payload length = 13 + urlLen, or 21 + urlLen + selectorLen with translation
        lda     fuji_json_path_len
        beq     @open_no_translation_len
        clc
        adc     #21
        sta     aws_tmp04
        lda     aws_tmp03
        adc     #$00
        sta     aws_tmp05
        lda     aws_tmp02
        clc
        adc     aws_tmp04
        sta     aws_tmp04
        lda     aws_tmp05
        adc     #$00
        sta     aws_tmp05
        jmp     @open_payload_len_done

@open_no_translation_len:
        lda     aws_tmp02
        clc
        adc     #13
        sta     aws_tmp04
        lda     aws_tmp03
        adc     #$00
        sta     aws_tmp05
@open_payload_len_done:

        lda     #FN_DEVICE_NETWORK
        sta     fuji_bus_tx_device
        lda     #NET_CMD_OPEN
        sta     fuji_bus_tx_command

        lda     fuji_ext_str_flags
        and     #(FUJI_EXT_STR_ACTIVE | FUJI_EXT_STR_IS_URL)
        cmp     #(FUJI_EXT_STR_ACTIVE | FUJI_EXT_STR_IS_URL)
        beq     @open_send_scatter_url

        jsr     fujibus_set_payload_buffer_ptr

        lda     aws_tmp04
        ldx     aws_tmp05
        jsr     fujibus_send_packet_raw
        jmp     @open_receive

@open_send_scatter_url:
        ; Region 1: FujiBus header + open prefix through urlLen (11 bytes)
        lda     buffer_ptr
        sta     aws_tmp00
        lda     buffer_ptr+1
        sta     aws_tmp01
        lda     #$0B
        sta     aws_tmp02
        lda     #$00
        sta     aws_tmp03

        ; Region 2: URL bytes in user RAM
        lda     fuji_ext_str_ptr
        sta     aws_tmp06
        lda     fuji_ext_str_ptr+1
        sta     aws_tmp07
        lda     fuji_ext_str_len
        sta     aws_tmp08
        lda     fuji_ext_str_len_hi
        sta     aws_tmp09

        ; Region 3: fixed trailing (+ translation header if present)
        lda     buffer_ptr
        clc
        adc     #$0B
        sta     cws_tmp2
        lda     buffer_ptr+1
        adc     #$00
        sta     cws_tmp3
        lda     fuji_json_path_len
        beq     @open_tail8
        lda     #$10
        clc
        adc     fuji_json_path_len
        sta     cws_tmp6
        lda     #$00
        sta     cws_tmp7
        jmp     @open_do_scatter
@open_tail8:
        lda     #$08
        sta     cws_tmp6
        lda     #$00
        sta     cws_tmp7

@open_do_scatter:
        jsr     fujibus_send_packet_scatter_raw
        lda     #$00
        sta     fuji_ext_str_flags

@open_receive:
        ; receive response
nw_open_before_receive:
        jsr     fujibus_receive_packet_raw
nw_open_after_receive:

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
        sta     fuji_ext_str_flags
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

        jsr     fujibus_set_payload_buffer_ptr

        lda     #$09                    ; 9 bytes payload (1+2+4+2)
        ldx     #$00
        jsr     fujibus_send_packet_raw

        ; receive response
nw_read_before_receive:
        jsr     fujibus_receive_packet_raw
nw_read_after_receive:

        ; check for valid response
        cpx     #$00
        bne     check_descriptor
        cmp     #$00
        beq     read_fail

check_descriptor:
        ; Need at least FujiBus header so descriptor/status are present
        cmp     #$07
        bcc     read_fail

        sta     aws_tmp05               ; save total packet length

        ; check descriptor byte
        ldy     #$05
        lda     (buffer_ptr),y
        cmp     #$01
        bne     read_fail

        ; check status code
        iny                             ; y = 6
        lda     (buffer_ptr),y
        beq     check_read_length       ; success
        cmp     #$04                    ; NotReady
        beq     read_not_ready
        ; fall through

read_fail:
        lda     #$00
        rts

read_not_ready:
        lda     #$02
        rts

check_read_length:
        ldy     #NET_RESP_FLAGS
        lda     (buffer_ptr),y
        sta     aws_tmp04               ; response flags (e.g. EOF)

        ; minimum length: 7 + 12 = 19 bytes (FujiBus hdr + network protocol hdr)
        lda     aws_tmp05
        cmp     #$13
        bcc     read_fail

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
        beq     read_success

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

read_success:
        lda     aws_tmp04
        and     #NET_READ_FLAG_EOF
        beq     :+

        ; Remote EOF known: set EXT = offset + bytes returned so subsequent
        ; EOF#/BGET# stops locally without retrying NotReady at the same offset.
        ldy     fuji_intch
        lda     fuji_ch_bptr_low,y
        clc
        adc     fuji_network_buf_cnt
        sta     fuji_ch_ext_low,y
        lda     fuji_ch_bptr_mid,y
        adc     fuji_network_buf_cnt_hi
        sta     fuji_ch_ext_mid,y
        ; fujibus_network_read is used from BGET, so the channel PTR is the
        ; canonical request offset throughout this read.
        lda     fuji_ch_bptr_hi,y
        adc     #$00
        sta     fuji_ch_ext_hi,y
:
        lda     #$01
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

        lda     aws_tmp02
        sta     aws_tmp10
        lda     #$00                    ; high byte of byte count is always 00
        sta     aws_tmp11
        jsr     nw_build_write_prefix
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

        jsr     fujibus_set_payload_buffer_ptr

        ldx     aws_tmp15               ; payload size high
        lda     aws_tmp14               ; payload size low
        jsr     fujibus_send_packet_raw

        ; receive response
        jsr     fujibus_receive_packet_raw
        cmp     #$11
        jsr     nw_check_ok_response
        rts


; bool fujibus_network_write_ext(uint16_t handle, uint32_t offset, uint16_t dataLen)
;   Input:
;     fuji_ext_str_ptr / fuji_ext_str_len(_hi) describe the source data in user RAM
;     aws_tmp06/07/08/09 = 32-bit offset (little-endian)
;     Y = intch (to read handle from channel block)
;   Output:
;     C = 0 on success, 1 on failure

fujibus_network_write_ext:
        tya
        tax                             ; move intch into X for indexing

        lda     fuji_ext_str_len
        sta     aws_tmp10
        lda     fuji_ext_str_len_hi
        sta     aws_tmp11
        jsr     nw_build_write_prefix

        lda     #FN_DEVICE_NETWORK
        sta     fuji_bus_tx_device

        lda     #NET_CMD_WRITE
        sta     fuji_bus_tx_command

        ; scatter region 1 = full FujiBus header + write prefix through dataLen (15 bytes)
        lda     buffer_ptr
        sta     aws_tmp00
        lda     buffer_ptr+1
        sta     aws_tmp01
        lda     #$0F
        sta     aws_tmp02
        lda     #$00
        sta     aws_tmp03

        ; scatter region 2 = user RAM body bytes
        lda     fuji_ext_str_ptr
        sta     aws_tmp06
        lda     fuji_ext_str_ptr+1
        sta     aws_tmp07
        lda     fuji_ext_str_len
        sta     aws_tmp08
        lda     fuji_ext_str_len_hi
        sta     aws_tmp09

        ; no region 3
        lda     #$00
        sta     cws_tmp2
        sta     cws_tmp3
        sta     cws_tmp6
        sta     cws_tmp7

        jsr     fujibus_send_packet_scatter_raw

        ; receive response
        jsr     fujibus_receive_packet_raw
        cmp     #$11                    ; minimum: 7 + 10 bytes protocol response
        jsr     nw_check_ok_response
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

        jsr     fujibus_set_payload_buffer_ptr

        lda     #$03                    ; 3 bytes payload
        ldx     #$00
        jsr     fujibus_send_packet_raw

        ; receive response
        jsr     fujibus_receive_packet_raw
        ; minimum: 7 + 4 = 11 bytes
        cmp     #$0B
        jsr     nw_check_ok_response
        rts


; bool fujibus_network_translate_configure(uint16_t handle)
;   Input:
;     fuji_ch_handle_low (y) = handle low byte
;     fuji_ch_handle_high (y) = handle high byte
;     Y = intch
;     JSON path in PWS buffer (set by *FJSON via get_fuji_json_path_addr_to_aws_tmp00)
;     fuji_json_path_len = length of JSON path string
;   Output:
;     C = 0 on success, 1 on failure
;
; TranslateConfigure request payload (at buffer+6):
;   +0  version = $01
;   +1  handle (u16le)
;   +3  translationType (u8)
;   +4  translationFlags (u8)
;   +5  selectorLen (u16le)
;   +7  selector bytes (N)

fujibus_network_translate_configure:
        sty     fuji_intch              ; canonical channel id for the full request/retry flow
        jsr     network_retry_init

fnjq_build_request:
        ; version
        lda     #FN_PROTOCOL_VERSION
        ldy     #$06
        sta     (buffer_ptr),y

        ; handle (u16le)
        ldy     fuji_intch
        lda     fuji_ch_handle_low,y
        ldy     #$07
        sta     (buffer_ptr),y
        ldy     fuji_intch
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
        lda     fuji_ext_str_flags
        and     #FUJI_EXT_STR_IS_JSON
        bne     fnjq_ext_sel_len
        lda     fuji_json_path_len
        iny
        sta     (buffer_ptr),y
        lda     #$00
        iny
        sta     (buffer_ptr),y
        jmp     fnjq_path_source
fnjq_ext_sel_len:
        lda     fuji_ext_str_len
        iny
        sta     (buffer_ptr),y
        lda     fuji_ext_str_len_hi
        iny
        sta     (buffer_ptr),y

fnjq_path_source:
        lda     fuji_ext_str_flags
        and     #(FUJI_EXT_STR_ACTIVE | FUJI_EXT_STR_IS_JSON)
        cmp     #(FUJI_EXT_STR_ACTIVE | FUJI_EXT_STR_IS_JSON)
        beq     fnjq_send_scatter

        ; Copy JSON path from PWS buffer to packet buffer
        sty     aws_tmp02               ; save dest buffer index (Y = 11 after pathLen)
        jsr     get_fuji_json_path_addr_to_aws_tmp00
        ; aws_tmp00/01 = PWS + FUJI_JSON_PATH_OFFSET

        ldx     #$00
        ldy     #$0D                    ; dest index after selectorLen
        sty     aws_tmp02
        jmp     fnjq_copy_path

fnjq_send_scatter:
        lda     #FN_DEVICE_NETWORK
        sta     fuji_bus_tx_device
        lda     #NET_CMD_TRANSLATE_CONFIGURE
        sta     fuji_bus_tx_command

        lda     buffer_ptr
        sta     aws_tmp00
        lda     buffer_ptr+1
        sta     aws_tmp01
        lda     #$0D                    ; 6 FujiBus + 7 payload through selectorLen
        sta     aws_tmp02
        lda     #$00
        sta     aws_tmp03

        lda     fuji_ext_str_ptr
        sta     aws_tmp06
        lda     fuji_ext_str_ptr+1
        sta     aws_tmp07
        lda     fuji_ext_str_len
        sta     aws_tmp08
        lda     fuji_ext_str_len_hi
        sta     aws_tmp09

        lda     #$00
        sta     cws_tmp2
        sta     cws_tmp3
        sta     cws_tmp6
        sta     cws_tmp7

        jsr     fujibus_send_packet_scatter_raw
        lda     #$00
        sta     fuji_ext_str_flags
        jmp     fnjq_receive

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

        jsr     fujibus_set_payload_buffer_ptr

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
        jsr     fujibus_send_packet_raw

fnjq_receive:
        ; receive response
nw_json_before_receive:
        jsr     fujibus_receive_packet_raw
nw_json_after_receive:

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
        ldy     fuji_intch
        sta     fuji_ch_ext_low,y
        ldy     #$0E
        lda     (buffer_ptr),y          ; size mid
        ldy     fuji_intch
        sta     fuji_ch_ext_mid,y
        ldy     #$0F
        lda     (buffer_ptr),y          ; size high
        sta     aws_tmp04               ; upper 24 bits after validation below
        iny
        lda     (buffer_ptr),y          ; size upper24-31, ignored unless non-zero
        beq     :+
        lda     #$FF
        sta     aws_tmp04
:

        ; Update EXT/PTR in channel block
        ldy     fuji_intch

        lda     aws_tmp04
        sta     fuji_ch_ext_hi,y

        lda     #$00
        sta     fuji_ch_bptr_low,y
        sta     fuji_ch_bptr_mid,y
        sta     fuji_ch_bptr_hi,y

        sta     fuji_ch_sect_cnt,y      ; clear stale buffer count

        clc
        rts

fnjq_jq_fail:
        sec
        rts

; Validate a simple network OK response after FujiBus transport receive.
; Input: A = minimum total packet length, X = received length high.
; Output: C clear = ok, C set = fail.
nw_check_ok_response:
        sta     aws_tmp04
        cpx     #$00
        bne     @check_len
        cmp     #$00
        beq     @fail
@check_len:
        cmp     aws_tmp04
        bcc     @fail
        ldy     #$05
        lda     (buffer_ptr),y
        cmp     #$01
        bne     @fail
        iny
        lda     (buffer_ptr),y
        bne     @fail
        clc
        rts
@fail:
        sec
        rts

; Build common Network Write request payload prefix at buffer+6.
; Input: X = intch, aws_tmp06..11 = offset (u32le) + dataLen (u16le).
nw_build_write_prefix:
        lda     #FN_PROTOCOL_VERSION
        ldy     #$06
        sta     (buffer_ptr),y
        lda     fuji_ch_handle_low,x
        iny
        sta     (buffer_ptr),y
        lda     fuji_ch_handle_high,x
        iny
        sta     (buffer_ptr),y
        ldx     #$00
@copy_offset_and_len:
        lda     aws_tmp06,x
        iny
        sta     (buffer_ptr),y
        inx
        cpx     #$06
        bcc     @copy_offset_and_len
        rts

; Build common Network Open request prefix at buffer+6.
; Input: aws_tmp02/03 = urlLen, aws_tmp04 = method, aws_tmp05 = flags.
nw_build_open_prefix:
        lda     #FN_PROTOCOL_VERSION
        ldy     #$06
        sta     (buffer_ptr),y
        lda     aws_tmp04
        iny
        sta     (buffer_ptr),y
        lda     aws_tmp05
        iny
        sta     (buffer_ptr),y
        lda     aws_tmp02
        iny
        sta     (buffer_ptr),y
        lda     aws_tmp03
        iny
        sta     (buffer_ptr),y
        rts
