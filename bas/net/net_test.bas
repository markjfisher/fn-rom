REM filename: NETEST
REM FujiNet network connectivity test using single asm send/receive transaction

httpGetURL$="http://192.168.1.101:8080/get"
tcpEchoURL$="tcp://192.168.1.101:7777?halfclose=1"

DIM asmTransaction 375
DIM asmChecksum 50

TX_BUFFER_SIZE%=160
RX_BUFFER_SIZE%=400
NET_READ_SIZE%=380

DIM txPacket TX_BUFFER_SIZE%
DIM rxPacket RX_BUFFER_SIZE%

OSBYTE=&FFF4
OSWRCH=&FFEE

FUJI_DEVICE_NETWORK=&FD

NETPROTO_VERSION=&01

NET_CMD_OPEN=&01
NET_CMD_READ=&02
NET_CMD_WRITE=&03
NET_CMD_CLOSE=&04
NET_CMD_INFO=&05
NET_CMD_INFO_READ=&06

NET_METHOD_GET=&01

NET_FLAG_ALLOW_EVICT=&08

NET_STATUS_OK=0
NET_STATUS_DEVICE_BUSY=3
NET_STATUS_NOT_READY=4

SLIP_END=&C0
SLIP_ESCAPE=&DB
SLIP_ESC_END=&DC
SLIP_ESC_ESC=&DD

ZP_SRC%=&70
ZP_LEN%=&72
ZP_RES%=&74

PROCasmInit

PRINT "FujiNet Network Connectivity Test"
PRINT "================================"
PRINT

PRINT "HTTP GET example"
PRINT "----------------"
PROChttp_get_example
PRINT

PRINT "TCP send/recv example"
PRINT "---------------------"
PROCtcp_sendrecv_example
PRINT

PRINT "Done"
END

REM ============================================
REM PROCEDURE AND FUNCTION DEFINITIONS
REM ============================================

DEF PROCasmInit
FOR I%=0 TO 2 STEP 2:P%=asmTransaction
  [OPT I%
   .setup_serial
   LDX #&08:LDY #&00:LDA #&07:JSR OSBYTE
   LDX #&08:LDY #&00:LDA #&08:JSR OSBYTE
   LDX #&01:LDY #&00:LDA #&02:JSR OSBYTE
   LDX #&03:LDY #&00:LDA #&03:JSR OSBYTE
   RTS

   .flush_serial
   LDX #&01:LDY #&00:LDA #&15:JSR OSBYTE
   RTS

   .restore_screen
   LDX #&00:LDY #&00:LDA #&03:JSR OSBYTE
   LDX #&00:LDY #&00:LDA #&02:JSR OSBYTE
   RTS

   .check_rs423
   LDX #&FE:LDY #&FF:LDA #&80:JSR OSBYTE
   TXA
   RTS

   .read_rs423
   LDX #&01:LDY #&00:LDA #&91:JSR OSBYTE
   TYA
   RTS

   .wait_for_char
   JSR check_rs423
   BNE wait_have_char
   LDA &7C
   BNE wait_dec_low
   DEC &7D
   .wait_dec_low
   DEC &7C
   LDA &7C
   ORA &7D
   BNE wait_for_char
   SEC
   RTS

   .wait_have_char
   JSR read_rs423
   RTS

   .send_slip_byte
   CMP #SLIP_END
   BEQ send_esc_end
   CMP #SLIP_ESCAPE
   BEQ send_esc_esc
   JSR OSWRCH
   RTS
   .send_esc_end
   PHA
   LDA #SLIP_ESCAPE
   JSR OSWRCH
   LDA #SLIP_ESC_END
   JSR OSWRCH
   PLA
   RTS
   .send_esc_esc
   PHA
   LDA #SLIP_ESCAPE
   JSR OSWRCH
   LDA #SLIP_ESC_ESC
   JSR OSWRCH
   PLA
   RTS

   .entry
   JSR setup_serial
   JSR flush_serial

   LDA #SLIP_END
   JSR OSWRCH

   LDY #&00
   STY &7E
   STY &7F
   LDA &76
   STA &7A
   LDA &77
   STA &7B

   .send_loop
   LDA &7E
   CMP &74
   BNE send_more
   LDA &7F
   CMP &75
   BEQ send_done
   .send_more
   LDA (&7A),Y
   JSR send_slip_byte
   INC &7A
   BNE send_ptr_ok
   INC &7B
   .send_ptr_ok
   INC &7E
   BNE send_loop
   INC &7F
   CLC
   BCC send_loop

   .send_done
   LDA #SLIP_END
   JSR OSWRCH

   LDY #&00
   STY &7E
   STY &7F
   STY &78
   STY &7C

   LDA &70
   STA &7A
   LDA &71
   STA &7B

   \ Get the response
   LDA #&B0
   STA &7D

   .wait_start
   JSR wait_for_char
   BCC have_start_ok
   BCS trans_fail

   .have_start_ok
   CMP #SLIP_END
   BNE wait_start

   LDA #0
   STA &7C
   LDA #&08
   STA &7D

   .frame_loop
   JSR wait_for_char
   BCC have_frame_ok
   BCS trans_fail
   .have_frame_ok
   STA &79

   LDA &78
   BNE escaped_char

   LDA &79
   CMP #SLIP_END
   BEQ handle_end
   CMP #SLIP_ESCAPE
   BEQ set_escape
   BNE store_char

   .trans_fail
   JSR restore_screen
   LDA #&00
   STA &72
   STA &73
   RTS

   .escaped_char
   LDA #&00
   STA &78
   LDA &79
   CMP #SLIP_ESC_END
   BEQ unesc_end
   CMP #SLIP_ESC_ESC
   BEQ unesc_esc
   BNE trans_fail
   .unesc_end
   LDA #SLIP_END
   BNE store_char
   .unesc_esc
   LDA #SLIP_ESCAPE
   BNE store_char

   .set_escape
   LDA #&01
   STA &78
   BNE frame_loop

   .handle_end
   LDA &7E
   ORA &7F
   BEQ frame_loop
   BNE trans_ok

   .store_char
   LDA &7E
   CMP &72
   BNE store_space
   LDA &7F
   CMP &73
   BEQ trans_fail
   .store_space
   LDY #&00
   LDA &79
   STA (&7A),Y
   INC &7A
   BNE store_ptr_ok
   INC &7B
   .store_ptr_ok
   INC &7E
   BNE no_inc
   INC &7F
   .no_inc
   CLC
   BCC frame_loop

   .trans_ok
   JSR restore_screen
   LDA &7E
   STA &72
   LDA &7F
   STA &73
   RTS
  ]
NEXT I%

FOR I%=0 TO 2 STEP 2:P%=asmChecksum
  [OPT I%

  .calc_checksum
    LDA #0
    STA ZP_RES%

    LDA ZP_LEN%
    ORA ZP_LEN%+1
    BEQ calc_checksum_done

  .calc_checksum_loop
    LDY #0
    LDA (ZP_SRC%),Y

    CLC
    ADC ZP_RES%
    ADC #0
    STA ZP_RES%

    INC ZP_SRC%
    BNE calc_checksum_src_ok
    INC ZP_SRC%+1
  .calc_checksum_src_ok

    LDA ZP_LEN%
    BNE calc_checksum_dec_lo
    DEC ZP_LEN%+1
  .calc_checksum_dec_lo
    DEC ZP_LEN%

    LDA ZP_LEN%
    ORA ZP_LEN%+1
    BNE calc_checksum_loop

  .calc_checksum_done
    LDA ZP_RES%
    RTS

  ]
NEXT I%
calc_checksum%=calc_checksum
ENDPROC

DEF PROCput_u16le(buf, offset%, value%)
buf?offset%=value% AND &FF
buf?(offset%+1)=(value% DIV 256) AND &FF
ENDPROC

DEF PROCput_u32le(buf, offset%, value%)
buf?offset%=value% AND &FF
buf?(offset%+1)=(value% DIV 256) AND &FF
buf?(offset%+2)=(value% DIV 65536) AND &FF
buf?(offset%+3)=(value% DIV 16777216) AND &FF
ENDPROC

DEF FNget_u16le(buf, offset%)
=buf?offset% + 256*buf?(offset%+1)

DEF FNget_u32le(buf, offset%)
=buf?offset% + 256*buf?(offset%+1) + 65536*buf?(offset%+2) + 16777216*buf?(offset%+3)

DEF PROCcopy_string_to_buffer(buf, offset%, text$)
LOCAL I%
FOR I%=1 TO LEN(text$)
  buf?(offset%+I%-1)=ASC(MID$(text$, I%, 1))
NEXT I%
ENDPROC

DEF PROCcopy_block(src, src_offset%, dst, dst_offset%, count%)
LOCAL I%
FOR I%=0 TO count%-1
  dst?(dst_offset%+I%)=src?(src_offset%+I%)
NEXT I%
ENDPROC

DEF FNchecksum(buf%, len%)
?ZP_SRC%=buf% MOD 256
?(ZP_SRC%+1)=buf% DIV 256
?ZP_LEN%=len% MOD 256
?(ZP_LEN%+1)=len% DIV 256
CALL calc_checksum%
=ZP_RES%?0

DEF FNbuild_fujibus_packet(device%, command%, payload_len%)
LOCAL total_len%
total_len%=6+payload_len%
txPacket?0=device%
txPacket?1=command%
PROCput_u16le(txPacket, 2, total_len%)
txPacket?4=0
txPacket?5=0
txPacket?4=FNchecksum(txPacket, total_len%)
=total_len%

DEF PROCclear_tx_payload(count%)
LOCAL I%
FOR I%=0 TO count%-1
  txPacket?(6+I%)=0
NEXT I%
ENDPROC

DEF FNtransaction(tx_len%)
?&70=rxPacket MOD 256
?&71=rxPacket DIV 256
?&72=RX_BUFFER_SIZE% MOD 256
?&73=RX_BUFFER_SIZE% DIV 256
?&74=tx_len% MOD 256
?&75=tx_len% DIV 256
?&76=txPacket MOD 256
?&77=txPacket DIV 256
CALL asmTransaction+entry-asmTransaction
=?&72 + 256*?&73

DEF FNpacket_checksum_ok
LOCAL pkt_len%, expected%, actual%
pkt_len%=FNget_u16le(rxPacket, 2)
expected%=rxPacket?4
rxPacket?4=0
actual%=FNchecksum(rxPacket, pkt_len%)
rxPacket?4=expected%
=actual%=expected%

DEF FNpacket_status
IF rxPacket?5<>1 THEN =-1
=rxPacket?6

DEF FNsend_request_expect(command%, payload_len%)
LOCAL tx_len%, rx_len%, result%
tx_len%=FNbuild_fujibus_packet(FUJI_DEVICE_NETWORK, command%, payload_len%)
rx_len%=FNtransaction(tx_len%)
result%=TRUE
IF rx_len%=0 THEN result%=FALSE
IF rxPacket?0<>FUJI_DEVICE_NETWORK THEN result%=FALSE
IF rxPacket?1<>command% THEN result%=FALSE
IF FNpacket_checksum_ok=FALSE THEN result%=FALSE
=result%

DEF PROCpause(t%)
TIME=0
REPEAT UNTIL TIME>t%
ENDPROC

DEF FNsend_request_retry(command%, paylen%, retries%)
LOCAL tries%, status%, result%, done%
tries%=1
done%=FALSE
result%=FALSE
REPEAT
  IF FNsend_request_expect(command%, paylen%)=FALSE THEN done%=TRUE
  status%=FNpacket_status
  IF done%=FALSE THEN IF status%=NET_STATUS_DEVICE_BUSY OR status%=NET_STATUS_NOT_READY THEN tries%=tries%+1 ELSE result%=TRUE:done%=TRUE
  IF tries%>retries% THEN done%=TRUE
  IF done%=FALSE THEN PROCpause(50)
UNTIL done%
=result%

DEF FNbuild_open_payload(method%, flags%, url$, body_len_hint%)
LOCAL offset%, url_len%
offset%=0
txPacket?(6+offset%)=NETPROTO_VERSION
offset%=offset%+1
txPacket?(6+offset%)=method%
offset%=offset%+1
txPacket?(6+offset%)=flags%
offset%=offset%+1
url_len%=LEN(url$)
PROCput_u16le(txPacket, 6+offset%, url_len%)
offset%=offset%+2
PROCcopy_string_to_buffer(txPacket, 6+offset%, url$)
offset%=offset%+url_len%
PROCput_u16le(txPacket, 6+offset%, 0)
offset%=offset%+2
PROCput_u32le(txPacket, 6+offset%, body_len_hint%)
offset%=offset%+4
PROCput_u16le(txPacket, 6+offset%, 0)
offset%=offset%+2
=offset%

DEF FNbuild_info_payload(handle%)
txPacket?6=NETPROTO_VERSION
PROCput_u16le(txPacket, 7, handle%)
=3

DEF FNbuild_close_payload(handle%)
txPacket?6=NETPROTO_VERSION
PROCput_u16le(txPacket, 7, handle%)
=3

DEF FNbuild_read_payload(handle%, offset32%, max_bytes%)
txPacket?6=NETPROTO_VERSION
PROCput_u16le(txPacket, 7, handle%)
PROCput_u32le(txPacket, 9, offset32%)
PROCput_u16le(txPacket, 13, max_bytes%)
=9

DEF FNbuild_write_payload(handle%, offset32%, data$, data_len%)
txPacket?6=NETPROTO_VERSION
PROCput_u16le(txPacket, 7, handle%)
PROCput_u32le(txPacket, 9, offset32%)
PROCput_u16le(txPacket, 13, data_len%)
IF data_len%>0 THEN PROCcopy_string_to_buffer(txPacket, 15, data$)
=9+data_len%

DEF PROCprint_ascii_from_payload(offset%, count%)
LOCAL I%, byte%
FOR I%=0 TO count%-1
  byte%=rxPacket?(offset%+I%)
  IF byte%>=32 AND byte%<127 THEN PRINT CHR$(byte%); ELSE PRINT ".";
NEXT I%
PRINT
ENDPROC

DEF FNnetwork_open(method%, flags%, url$, body_len_hint%)
LOCAL paylen%, result%, status%, accepted%
paylen%=FNbuild_open_payload(method%, flags%, url$, body_len_hint%)

IF FNsend_request_retry(NET_CMD_OPEN, paylen%, 200)=FALSE THEN =-1

status%=FNpacket_status
IF status%<>NET_STATUS_OK THEN =-1

accepted%=((rxPacket?8 AND 1)<>0)
IF accepted%=FALSE THEN =-1

result%=FNget_u16le(rxPacket, 11)
=result%

DEF PROCnetinfo_get(handle%)
LOCAL payload_len%, header_len%, ok%, offset32%, chunk_len%, eof%, echo_offset%, status%

PRINT "Info handle:       ";FNget_u16le(rxPacket, 11)
PRINT "Info http status:  ";FNget_u16le(rxPacket, 13)
header_len%=FNget_u32le(rxPacket, 23)
PRINT "Info header bytes: ";header_len%
offset32%=0
IF header_len%=0 THEN GOTO 1500

REPEAT
  status%=NET_STATUS_NOT_READY
  eof%=FALSE
  chunk_len%=0

  payload_len%=FNbuild_info_read_payload(handle%, offset32%, NET_READ_SIZE%)
  ok%=FNsend_request_retry(NET_CMD_INFO_READ, payload_len%, 2000)
  IF ok%=FALSE THEN PRINT "INFO_READ failed"
  IF ok%=TRUE THEN status%=FNpacket_status
  IF status%=NET_STATUS_OK THEN echo_offset%=FNget_u32le(rxPacket, 13):chunk_len%=FNget_u16le(rxPacket, 17):eof%=((rxPacket?8 AND 1)<>0)
  IF status%=NET_STATUS_OK AND echo_offset%<>offset32% THEN PRINT "INFO_READ offset mismatch":ok%=FALSE
  IF ok%=TRUE AND chunk_len%>0 THEN PROCprint_ascii_from_payload(19, chunk_len%)
  IF ok%=TRUE AND status%=NET_STATUS_OK THEN offset32%=offset32%+chunk_len%
UNTIL (eof%=TRUE OR ok%=FALSE OR status%<>NET_STATUS_OK)
1500 REM endproc
ENDPROC

DEF PROCnetwork_info(handle%)
LOCAL payload_len%, ok%, status%

status%=NET_STATUS_NOT_READY
payload_len%=FNbuild_info_payload(handle%)
ok%=FNsend_request_retry(NET_CMD_INFO, payload_len%, 2000)
IF ok%=FALSE THEN PRINT "INFO failed"
IF ok%=TRUE THEN status%=FNpacket_status
IF ok%=TRUE AND status%=NET_STATUS_OK THEN PRINT "INFO status: ";status%:PROCnetinfo_get(handle%)
ENDPROC

DEF FNbuild_info_read_payload(handle%, offset32%, max_bytes%)
txPacket?6=NETPROTO_VERSION
PROCput_u16le(txPacket, 7, handle%)
PROCput_u32le(txPacket, 9, offset32%)
PROCput_u16le(txPacket, 13, max_bytes%)
=9

DEF PROCnetwork_close(handle%)
LOCAL paylen%,ok%
paylen%=FNbuild_close_payload(handle%)
ok%=FNsend_request_retry(NET_CMD_CLOSE, paylen%, 200)
ENDPROC

DEF FNnetwork_write(handle%, offset32%, data$, data_len%)
LOCAL payload_len%, result%, status%
payload_len%=FNbuild_write_payload(handle%, offset32%, data$, data_len%)
result%=-1
IF FNsend_request_retry(NET_CMD_WRITE, payload_len%, 2000)=FALSE THEN =-1
status%=FNpacket_status
IF status%<>NET_STATUS_OK THEN =-1
result%=FNget_u16le(rxPacket, 17)
=result%

DEF FNnetwork_append_read_chunk(dlen%)
LOCAL I%
IF dlen%<=0 THEN =TRUE
IF full_len%+dlen%>FULL_PAYLOAD%+1 THEN =FALSE
FOR I%=0 TO dlen%-1
  fullPayload?(full_len%+I%)=rxPacket?(19+I%)
NEXT
full_len%=full_len%+dlen%
=TRUE

DEF PROCnetwork_read_all(handle%)
LOCAL offset32%, paylen%, dlen%, eof%, ok%, status%
offset32%=0
full_len%=0
REPEAT
  status%=NET_STATUS_NOT_READY
  eof%=FALSE
  dlen%=0
  paylen%=FNbuild_read_payload(handle%, offset32%, NET_READ_SIZE%)
  ok%=FNsend_request_retry(NET_CMD_READ, paylen%, 2000)
  IF ok%=TRUE THEN status%=FNpacket_status
  IF status%=NET_STATUS_OK THEN dlen%=FNget_u16le(rxPacket, 17):eof%=((rxPacket?8 AND 1)<>0)
  IF dlen%>0 THEN offset32%=offset32%+dlen%:PROCprint_ascii_from_payload(19, dlen%)
UNTIL (eof%=TRUE OR ok%=FALSE OR status%<>NET_STATUS_OK)
ENDPROC

DEF PROChttp_get_example
LOCAL handle%
PRINT "Opening: ";httpGetURL$
handle%=FNnetwork_open(NET_METHOD_GET, NET_FLAG_ALLOW_EVICT, httpGetURL$, 0)
IF handle%<0 THEN PRINT "OPEN failed":GOTO 2000
PRINT "Handle: ";handle%
PROCnetwork_info(handle%)
PROCnetwork_read_all(handle%)
PROCnetwork_close(handle%)
2000 REM endproc
ENDPROC

DEF PROCtcp_halfclose(handle%, offset32%)
LOCAL written%
written%=FNnetwork_write(handle%, offset32%, "", 0)
IF written%<0 THEN PRINT "Halfclose WRITE failed" ELSE PRINT "Halfclose sent"
ENDPROC

DEF PROCtcp_sendrecv_example
LOCAL handle%, url$, data$, written%
data$="hello world"
PRINT "Opening: ";tcpEchoURL$
handle%=FNnetwork_open(NET_METHOD_GET, NET_FLAG_ALLOW_EVICT, tcpEchoURL$, 0)
IF handle%<0 THEN PRINT "OPEN failed":GOTO 2500
PRINT "Handle: ";handle%
PRINT "Writing: ";data$
written%=FNnetwork_write(handle%, 0, data$, LEN(data$))
IF written%<0 THEN PRINT "WRITE failed":PROCnetwork_close(handle%):GOTO 2500
PRINT "Written: ";written%
PROCtcp_halfclose(handle%, written%)
PROCnetwork_info(handle%)
PROCnetwork_read_all(handle%)
PROCnetwork_close(handle%)
2500 REM endproc
ENDPROC
