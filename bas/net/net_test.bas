REM filename: NETEST
REM FujiNet network connectivity test using direct ACIA serial I/O

DIM txPacket 512
DIM rxPacket 512
DIM payload 512

FUJI_DEVICE_NETWORK=&FD

NETPROTO_VERSION=&01

NET_CMD_OPEN=&01
NET_CMD_READ=&02
NET_CMD_WRITE=&03
NET_CMD_CLOSE=&04
NET_CMD_INFO=&05

NET_METHOD_GET=&01

NET_FLAG_ALLOW_EVICT=&08

NET_STATUS_OK=0
NET_STATUS_DEVICE_BUSY=3
NET_STATUS_NOT_READY=4

SLIP_END=&C0
SLIP_ESCAPE=&DB
SLIP_ESC_END=&DC
SLIP_ESC_ESC=&DD

PROCinit_serial

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

DEF PROCinit_serial
?&FE10=&00
?&FE08=&03
?&FE08=&15
ENDPROC

DEF PROCflush_serial_input
LOCAL byte%, limit%
limit%=1024
FOR byte%=1 TO limit%
  IF (?&FE08 AND &01)=0 THEN ENDPROC
  byte%=?&FE09
NEXT byte%
ENDPROC

DEF PROCwait_tx_ready
REPEAT UNTIL (?&FE08 AND &02)<>0
ENDPROC

DEF FNread_acia_byte
IF (?&FE08 AND &01)=0 THEN =-1
=?&FE09

DEF FNwait_acia_byte(limit%)
LOCAL tries%, byte%
FOR tries%=1 TO limit%
  byte%=FNread_acia_byte
  IF byte%>=0 THEN =byte%
NEXT tries%
=-1

DEF FNchecksum(buf, len%)
LOCAL chk%, I%
chk%=0
FOR I%=0 TO len%-1
  chk%=((chk% + buf?I%) DIV 256) + ((chk% + buf?I%) AND 255)
NEXT I%
=chk% AND &FF

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

DEF FNbuild_fujibus_packet(device%, command%, payload_len%)
LOCAL total_len%
total_len%=6+payload_len%
txPacket?0=device%
txPacket?1=command%
PROCput_u16le(txPacket, 2, total_len%)
txPacket?4=0
txPacket?5=0
IF payload_len%>0 THEN PROCcopy_block(payload, 0, txPacket, 6, payload_len%)
txPacket?4=FNchecksum(txPacket, total_len%)
=total_len%

DEF PROCsend_slip_byte(byte%)
IF byte%=SLIP_END THEN PROCwait_tx_ready:?&FE09=SLIP_ESCAPE:PROCwait_tx_ready:?&FE09=SLIP_ESC_END:ENDPROC
IF byte%=SLIP_ESCAPE THEN PROCwait_tx_ready:?&FE09=SLIP_ESCAPE:PROCwait_tx_ready:?&FE09=SLIP_ESC_ESC:ENDPROC
PROCwait_tx_ready
?&FE09=byte%
ENDPROC

DEF PROCsend_slip_frame(buf, len%)
LOCAL I%
PROCflush_serial_input
PROCwait_tx_ready
?&FE09=SLIP_END
FOR I%=0 TO len%-1
  PROCsend_slip_byte(buf?I%)
NEXT I%
PROCwait_tx_ready
?&FE09=SLIP_END
ENDPROC

DEF FNread_slip_frame
LOCAL rx_len%, in_frame%, escape%, byte%
rx_len%=0
in_frame%=FALSE
escape%=FALSE
REPEAT
  IF in_frame%=FALSE THEN byte%=FNwait_acia_byte(1000) ELSE byte%=FNwait_acia_byte(200)
  IF byte%<0 THEN =0
  IF in_frame%=FALSE THEN IF byte%=SLIP_END THEN in_frame%=TRUE:GOTO 800
  IF in_frame%=FALSE THEN GOTO 800
  IF escape%=TRUE THEN GOTO 900
  IF byte%=SLIP_END THEN IF rx_len%>0 THEN =rx_len% ELSE GOTO 800
  IF byte%=SLIP_ESCAPE THEN escape%=TRUE:GOTO 800
  IF rx_len%>=512 THEN =0
  rxPacket?rx_len%=byte%
  rx_len%=rx_len%+1
  800 REM loop
UNTIL FALSE
900 IF byte%=SLIP_ESC_END THEN byte%=SLIP_END ELSE IF byte%=SLIP_ESC_ESC THEN byte%=SLIP_ESCAPE ELSE =0
escape%=FALSE
IF rx_len%>=512 THEN =0
rxPacket?rx_len%=byte%
rx_len%=rx_len%+1
GOTO 800

DEF FNpacket_total_len
=FNget_u16le(rxPacket, 2)

DEF FNpacket_checksum_ok
LOCAL pkt_len%, expected%, actual%
pkt_len%=FNpacket_total_len
expected%=rxPacket?4
rxPacket?4=0
actual%=FNchecksum(rxPacket, pkt_len%)
rxPacket?4=expected%
=actual%=expected%

DEF FNpacket_status
IF rxPacket?5<>1 THEN =-1
=rxPacket?6

DEF FNsend_request_expect(command%, payload_len%)
LOCAL tx_len%, rx_len%
tx_len%=FNbuild_fujibus_packet(FUJI_DEVICE_NETWORK, command%, payload_len%)
PROCsend_slip_frame(txPacket, tx_len%)
rx_len%=FNread_slip_frame
IF rx_len%=0 THEN =FALSE
IF rxPacket?0<>FUJI_DEVICE_NETWORK THEN =FALSE
IF rxPacket?1<>command% THEN =FALSE
IF FNpacket_checksum_ok=FALSE THEN =FALSE
=TRUE

DEF FNsend_request_retry(command%, payload_len%, retries%)
LOCAL tries%, status%
FOR tries%=1 TO retries%
  IF FNsend_request_expect(command%, payload_len%)=FALSE THEN =FALSE
  status%=FNpacket_status
  IF status%=NET_STATUS_DEVICE_BUSY OR status%=NET_STATUS_NOT_READY THEN GOTO 1000
  =TRUE
  1000 REM retry
NEXT tries%
=TRUE

DEF FNbuild_open_payload(method%, flags%, url$, body_len_hint%)
LOCAL offset%, url_len%
offset%=0
payload?offset%=NETPROTO_VERSION
offset%=offset%+1
payload?offset%=method%
offset%=offset%+1
payload?offset%=flags%
offset%=offset%+1
url_len%=LEN(url$)
PROCput_u16le(payload, offset%, url_len%)
offset%=offset%+2
PROCcopy_string_to_buffer(payload, offset%, url$)
offset%=offset%+url_len%
PROCput_u16le(payload, offset%, 0)
offset%=offset%+2
PROCput_u32le(payload, offset%, body_len_hint%)
offset%=offset%+4
PROCput_u16le(payload, offset%, 0)
offset%=offset%+2
=offset%

DEF FNbuild_info_payload(handle%)
payload?0=NETPROTO_VERSION
PROCput_u16le(payload, 1, handle%)
=3

DEF FNbuild_close_payload(handle%)
payload?0=NETPROTO_VERSION
PROCput_u16le(payload, 1, handle%)
=3

DEF FNbuild_read_payload(handle%, offset32%, max_bytes%)
payload?0=NETPROTO_VERSION
PROCput_u16le(payload, 1, handle%)
PROCput_u32le(payload, 3, offset32%)
PROCput_u16le(payload, 7, max_bytes%)
=9

DEF FNbuild_write_payload(handle%, offset32%, data$, data_len%)
payload?0=NETPROTO_VERSION
PROCput_u16le(payload, 1, handle%)
PROCput_u32le(payload, 3, offset32%)
PROCput_u16le(payload, 7, data_len%)
IF data_len%>0 THEN PROCcopy_string_to_buffer(payload, 9, data$)
=9+data_len%

DEF FNopen_handle_from_response
=FNget_u16le(rxPacket, 11)

DEF FNopen_accepted
=((rxPacket?8 AND 1)<>0)

DEF FNinfo_http_status
=FNget_u16le(rxPacket, 13)

DEF FNinfo_header_len
=FNget_u16le(rxPacket, 23)

DEF FNwrite_bytes_written
=FNget_u16le(rxPacket, 17)

DEF FNread_response_offset
=FNget_u32le(rxPacket, 13)

DEF FNread_response_data_len
=FNget_u16le(rxPacket, 17)

DEF FNread_response_eof
=((rxPacket?8 AND 1)<>0)

DEF PROCprint_ascii_from_payload(offset%, count%)
LOCAL I%, byte%
FOR I%=0 TO count%-1
  byte%=rxPacket?(offset%+I%)
  IF byte%>=32 AND byte%<127 THEN PRINT CHR$(byte%); ELSE PRINT ".";
NEXT I%
PRINT
ENDPROC

DEF FNnetwork_open(method%, flags%, url$, body_len_hint%)
LOCAL payload_len%
payload_len%=FNbuild_open_payload(method%, flags%, url$, body_len_hint%)
IF FNsend_request_retry(NET_CMD_OPEN, payload_len%, 100)=FALSE THEN =-1
IF FNpacket_status<>NET_STATUS_OK THEN =-1
IF FNopen_accepted=FALSE THEN =-1
=FNopen_handle_from_response

DEF PROCnetwork_info(handle%)
LOCAL payload_len%, header_len%
payload_len%=FNbuild_info_payload(handle%)
IF FNsend_request_retry(NET_CMD_INFO, payload_len%, 100)=FALSE THEN PRINT "INFO failed":ENDPROC
IF FNpacket_status<>NET_STATUS_OK THEN PRINT "INFO status: ";FNpacket_status:ENDPROC
PRINT "Info handle:       ";FNget_u16le(rxPacket, 11)
PRINT "Info http status:  ";FNinfo_http_status
header_len%=FNinfo_header_len
PRINT "Info header bytes: ";header_len%
IF header_len%>0 THEN PROCprint_ascii_from_payload(25, header_len%)
ENDPROC

DEF PROCnetwork_close(handle%)
LOCAL payload_len%
payload_len%=FNbuild_close_payload(handle%)
IF FNsend_request_retry(NET_CMD_CLOSE, payload_len%, 100)=FALSE THEN PRINT "CLOSE failed":ENDPROC
IF FNpacket_status<>NET_STATUS_OK THEN PRINT "CLOSE status: ";FNpacket_status
ENDPROC

DEF FNnetwork_write(handle%, offset32%, data$, data_len%)
LOCAL payload_len%
payload_len%=FNbuild_write_payload(handle%, offset32%, data$, data_len%)
IF FNsend_request_retry(NET_CMD_WRITE, payload_len%, 200)=FALSE THEN =-1
IF FNpacket_status<>NET_STATUS_OK THEN =-1
=FNwrite_bytes_written

DEF PROCnetwork_read_all(handle%)
LOCAL offset32%, payload_len%, data_len%, eof%, echo_offset%
offset32%=0
REPEAT
  payload_len%=FNbuild_read_payload(handle%, offset32%, 256)
  IF FNsend_request_retry(NET_CMD_READ, payload_len%, 500)=FALSE THEN PRINT "READ failed":ENDPROC
  IF FNpacket_status<>NET_STATUS_OK THEN PRINT "READ status: ";FNpacket_status:ENDPROC
  echo_offset%=FNread_response_offset
  data_len%=FNread_response_data_len
  eof%=FNread_response_eof
  PRINT "Read offset: ";echo_offset%;" len: ";data_len%;" eof: ";eof%
  IF data_len%>0 THEN PROCprint_ascii_from_payload(19, data_len%)
  offset32%=offset32%+data_len%
UNTIL eof%
ENDPROC

DEF PROChttp_get_example
LOCAL handle%, url$
url$="http://192.168.1.101:8080/get"
PRINT "Opening: ";url$
handle%=FNnetwork_open(NET_METHOD_GET, NET_FLAG_ALLOW_EVICT, url$, 0)
IF handle%<0 THEN PRINT "OPEN failed":ENDPROC
PRINT "Handle: ";handle%
PROCnetwork_info(handle%)
PROCnetwork_read_all(handle%)
PROCnetwork_close(handle%)
ENDPROC

DEF PROCtcp_halfclose(handle%, offset32%)
LOCAL written%
written%=FNnetwork_write(handle%, offset32%, "", 0)
IF written%<0 THEN PRINT "Halfclose WRITE failed" ELSE PRINT "Halfclose sent"
ENDPROC

DEF PROCtcp_sendrecv_example
LOCAL handle%, url$, data$, written%
url$="tcp://192.168.1.101:7777?halfclose=1"
data$="hello world"
PRINT "Opening: ";url$
handle%=FNnetwork_open(NET_METHOD_GET, NET_FLAG_ALLOW_EVICT, url$, 0)
IF handle%<0 THEN PRINT "OPEN failed":ENDPROC
PRINT "Handle: ";handle%
PRINT "Writing: ";data$
written%=FNnetwork_write(handle%, 0, data$, LEN(data$))
IF written%<0 THEN PRINT "WRITE failed":PROCnetwork_close(handle%):ENDPROC
PRINT "Written: ";written%
PROCtcp_halfclose(handle%, written%)
PROCnetwork_info(handle%)
PROCnetwork_read_all(handle%)
PROCnetwork_close(handle%)
ENDPROC
