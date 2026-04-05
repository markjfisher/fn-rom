REM filename: BWC
REM Bounce World Client proof of concept for BBC BASIC and FujiNet

DIM asmOSBYTE 20
DIM asmOSWRCH 8
DIM asmTransaction 396

TX_BUFFER_SIZE%=320
RX_BUFFER_SIZE%=640
TCP_READ_CHUNK%=256
MAX_SHAPES%=50
SHAPE_DATA_BUFFER_SIZE%=512
SCREEN_WIDTH%=40
SCREEN_HEIGHT%=25
RD_RETRY_LIMIT%=500

DIM txPacket TX_BUFFER_SIZE%
DIM rxPacket RX_BUFFER_SIZE%
DIM responseBuffer RX_BUFFER_SIZE%
DIM shapeDataBuffer SHAPE_DATA_BUFFER_SIZE%
DIM shapeId%(MAX_SHAPES%)
DIM shapeWidth%(MAX_SHAPES%)
DIM shapeOffset%(MAX_SHAPES%)

OSBYTE=&FFF4
OSWRCH=&FFEE

FUJI_DEVICE_NETWORK=&FD

NETPROTO_VERSION=&01

NET_CMD_OPEN=&01
NET_CMD_READ=&02
NET_CMD_WRITE=&03
NET_CMD_CLOSE=&04

NET_METHOD_GET=&01

NET_FLAG_ALLOW_EVICT=&08

NET_STATUS_OK=0
NET_STATUS_DEVICE_BUSY=3
NET_STATUS_NOT_READY=4

SLIP_END=&C0
SLIP_ESCAPE=&DB
SLIP_ESC_END=&DC
SLIP_ESC_ESC=&DD

PROCasmInit
PROCinit_state

MODE 7
PRINT "Bounce World Client POC"
PRINT "======================="
PRINT

PROCget_user_input
PRINT
PRINT "Opening TCP connection..."
handle%=FNnetwork_open(NET_METHOD_GET, NET_FLAG_ALLOW_EVICT, host$, 0)
IF handle%<0 THEN PRINT "OPEN failed":END
PRINT "Handle: ";handle%

clientId%=FNregister_client(handle%, name$)
IF clientId%<=0 THEN PRINT "ADD-CLIENT failed":PROCnetwork_close(handle%):END
PRINT "Client ID: ";clientId%

shapeCount%=FNfetch_shape_count(handle%)
IF shapeCount%<0 THEN PRINT "SHAPE-COUNT failed":PROCnetwork_close(handle%):END
PRINT "Shape count: ";shapeCount%

IF shapeCount%>MAX_SHAPES% THEN PRINT "Too many shapes for buffers":PROCnetwork_close(handle%):END

PROCfetch_shapes(handle%, shapeCount%)

PRINT
PRINT "Fetched shapes"
PRINT "--------------"
PROCprint_shapes_grid(shapeCount%)

PRINT
PRINT "Closing connection"
PROCnetwork_close(handle%)
END

DEF PROCinit_state
host$="tcp://192.168.1.101:9002"
name$="bbc"
clientId%=0
shapeCount%=0
shapeBytesUsed%=0
writeCursor%=0
readCursor%=0
ENDPROC

DEF PROCget_user_input
LOCAL in$
PRINT "Host [";host$;"]";
INPUT LINE in$
IF LEN(in$)>0 THEN host$=in$
PRINT "Name [";name$;"]";
INPUT LINE in$
IF LEN(in$)>0 THEN name$=LEFT$(in$,8)
PRINT "Using host: ";host$
PRINT "Using name: ";name$
ENDPROC

DEF FNregister_client(handle%, name$)
LOCAL cmd$, written%, read%
cmd$="x-add-client "+name$+",2,"+STR$(SCREEN_WIDTH%)+","+STR$(SCREEN_HEIGHT%)
written%=FNsend_tcp_command(handle%, cmd$)
IF written%<>LEN(cmd$) THEN =-1
read%=FNtcp_read_exact(handle%, responseBuffer, 0, 1, RD_RETRY_LIMIT%)
IF read%<>1 THEN =-1
=responseBuffer?0

DEF FNfetch_shape_count(handle%)
LOCAL cmd$, written%, read%
cmd$="x-shape-count"
written%=FNsend_tcp_command(handle%, cmd$)
IF written%<>LEN(cmd$) THEN =-1
read%=FNtcp_read_exact(handle%, responseBuffer, 0, 1, RD_RETRY_LIMIT%)
IF read%<>1 THEN =-1
=responseBuffer?0

DEF PROCfetch_shapes(handle%, shapeCount%)
LOCAL cmd$, written%, read%, shapeIndex%, pos%, width%, dataLen%
shapeBytesUsed%=0
cmd$="x-shape-data"
written%=FNsend_tcp_command(handle%, cmd$)
IF written%<>LEN(cmd$) THEN PRINT "WRITE failed":ENDPROC
read%=FNtcp_read_available(handle%, responseBuffer, 0, RX_BUFFER_SIZE%)
IF read%<=0 THEN PRINT "No shape payload":ENDPROC
pos%=0
FOR shapeIndex%=0 TO shapeCount%-1
  IF pos%+2>read% THEN PRINT "Short shape header at ";shapeIndex%:ENDPROC
  shapeId%(shapeIndex%)=responseBuffer?pos%
  pos%=pos%+1
  width%=responseBuffer?pos%
  pos%=pos%+1
  shapeWidth%(shapeIndex%)=width%
  dataLen%=width%*width%
  shapeOffset%(shapeIndex%)=shapeBytesUsed%
  IF pos%+dataLen%>read% THEN PRINT "Short shape data at ";shapeIndex%:ENDPROC
  IF shapeBytesUsed%+dataLen%>SHAPE_DATA_BUFFER_SIZE% THEN PRINT "Shape buffer overflow":ENDPROC
  PROCcopy_block(responseBuffer, pos%, shapeDataBuffer, shapeBytesUsed%, dataLen%)
  PROCconvert_shape_chars(shapeDataBuffer, shapeBytesUsed%, dataLen%)
  shapeBytesUsed%=shapeBytesUsed%+dataLen%
  pos%=pos%+dataLen%
NEXT
PRINT "Shape bytes used: ";shapeBytesUsed%
ENDPROC

DEF PROCprint_shapes_grid(shapeCount%)
LOCAL index%, baseX%, baseY%
FOR index%=0 TO shapeCount%-1
  baseX%=(index% MOD 4)*9
  baseY%=(index% DIV 4)*8+2
  IF baseY%<22 THEN PROCprint_one_shape(index%, baseX%, baseY%)
NEXT
ENDPROC

DEF PROCprint_one_shape(index%, x%, y%)
LOCAL width%, row%, col%, dataOffset%, ch%, line$
width%=shapeWidth%(index%)
dataOffset%=shapeOffset%(index%)
PRINT TAB(x%,y%-1);"ID ";shapeId%(index%);" W ";width%
FOR row%=0 TO width%-1
  line$=""
  FOR col%=0 TO width%-1
    ch%=shapeDataBuffer?(dataOffset% + row%*width% + col%)
    line$=line$+FNmap_shape_char$(ch%)
  NEXT
  PRINT TAB(x%,y%+row%);line$
NEXT
ENDPROC

DEF PROCconvert_shape_chars(buf, offset%, count%)
LOCAL i%, ch%
FOR i%=0 TO count%-1
  ch%=buf?(offset%+i%)
  IF ch%=114 OR ch%=41 OR ch%=76 OR ch%=33 OR ch%=74 OR ch%=116 OR ch%=84 OR ch%=50 OR ch%=43 THEN buf?(offset%+i%)=ASC("+")
  IF ch%=97 OR ch%=98 OR ch%=99 OR ch%=100 OR ch%=105 OR ch%=106 OR ch%=107 OR ch%=108 OR ch%=109 THEN buf?(offset%+i%)=ASC("#")
  IF ch%=101 OR ch%=102 OR ch%=103 OR ch%=104 THEN buf?(offset%+i%)=ASC(".")
NEXT
ENDPROC

DEF FNmap_shape_char$(ch%)
LOCAL out$
IF ch%>=32 AND ch%<127 THEN out$=CHR$(ch%) ELSE out$="?"
=out$

DEF FNsend_tcp_command(handle%, cmd$)
LOCAL written%
written%=FNnetwork_write(handle%, writeCursor%, cmd$, LEN(cmd$))
IF written%>0 THEN writeCursor%=writeCursor%+written%
=written%

DEF FNtcp_read_exact(handle%, dst_buf, dst_offset%, total_len%, retries%)
LOCAL totalRead%, chunkLen%, state%, dataLen%, eof%, echoOffset%, tries%
totalRead%=0
tries%=0
REPEAT
  chunkLen%=total_len%-totalRead%
  IF chunkLen%>TCP_READ_CHUNK% THEN chunkLen%=TCP_READ_CHUNK%
  state%=FNnetwork_read_chunk(handle%, readCursor%, chunkLen%)
  IF state%=NET_STATUS_NOT_READY THEN tries%=tries%+1 ELSE tries%=0
  IF state%<0 THEN =totalRead%
  IF state%=NET_STATUS_NOT_READY AND tries%>retries% THEN =totalRead%
  IF state%=NET_STATUS_NOT_READY THEN PROCpause
  IF state%=NET_STATUS_OK THEN dataLen%=FNread_response_data_len
  IF state%=NET_STATUS_OK THEN eof%=FNread_response_eof
  IF state%=NET_STATUS_OK THEN echoOffset%=FNread_response_offset
  IF state%=NET_STATUS_OK THEN IF echoOffset%<>readCursor% THEN PRINT "READ offset mismatch":=totalRead%
  IF state%=NET_STATUS_OK THEN IF dataLen%=0 AND eof%=0 THEN =totalRead%
  IF state%=NET_STATUS_OK THEN IF totalRead%+dataLen%>total_len% THEN dataLen%=total_len%-totalRead%
  IF state%=NET_STATUS_OK THEN IF dataLen%>0 THEN PROCcopy_block(rxPacket, 19, dst_buf, dst_offset%+totalRead%, dataLen%)
  IF state%=NET_STATUS_OK THEN totalRead%=totalRead%+dataLen%
  IF state%=NET_STATUS_OK THEN readCursor%=readCursor%+dataLen%
  IF state%=NET_STATUS_OK THEN IF eof% AND totalRead%<total_len% THEN =totalRead%
UNTIL totalRead%>=total_len%
=totalRead%

DEF FNtcp_read_available(handle%, dst_buf, dst_offset%, max_len%)
LOCAL state%, dataLen%, eof%, echoOffset%
state%=FNnetwork_read_chunk(handle%, readCursor%, max_len%)
IF state%=NET_STATUS_NOT_READY THEN =0
IF state%<0 THEN =-1
dataLen%=FNread_response_data_len
eof%=FNread_response_eof
echoOffset%=FNread_response_offset
IF echoOffset%<>readCursor% THEN PRINT "READ offset mismatch":=-1
IF dataLen%>0 THEN PROCcopy_block(rxPacket, 19, dst_buf, dst_offset%, dataLen%)
readCursor%=readCursor%+dataLen%
IF dataLen%=0 AND eof%=1 THEN =0
=dataLen%

DEF FNnetwork_read_chunk(handle%, offset32%, max_bytes%)
LOCAL payload_len%, ok%, status%
payload_len%=FNbuild_read_payload(handle%, offset32%, max_bytes%)
ok%=FNsend_request_expect(NET_CMD_READ, payload_len%)
IF ok%=FALSE THEN =-1
status%=FNpacket_status
IF status%=NET_STATUS_OK THEN =NET_STATUS_OK
IF status%=NET_STATUS_NOT_READY THEN =NET_STATUS_NOT_READY
IF status%=NET_STATUS_DEVICE_BUSY THEN =NET_STATUS_NOT_READY
=-1

DEF PROCpause
LOCAL t%
FOR t%=1 TO 200:NEXT
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

DEF FNchecksum(buf, len%)
LOCAL chk%, I%
chk%=0
FOR I%=0 TO len%-1
  chk%=((chk% + buf?I%) DIV 256) + ((chk% + buf?I%) AND 255)
NEXT I%
=chk% AND &FF

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
LOCAL tx_len%, rx_len%, result%
tx_len%=FNbuild_fujibus_packet(FUJI_DEVICE_NETWORK, command%, payload_len%)
rx_len%=FNtransaction(tx_len%)
result%=TRUE
IF rx_len%=0 THEN result%=FALSE
IF rxPacket?0<>FUJI_DEVICE_NETWORK THEN result%=FALSE
IF rxPacket?1<>command% THEN result%=FALSE
IF FNpacket_checksum_ok=FALSE THEN result%=FALSE
=result%

DEF FNsend_request_retry(command%, payload_len%, retries%)
LOCAL tries%, status%, result%, done%
tries%=1
done%=FALSE
result%=FALSE
REPEAT
  IF FNsend_request_expect(command%, payload_len%)=FALSE THEN done%=TRUE
  status%=FNpacket_status
  IF done%=FALSE THEN IF status%=NET_STATUS_DEVICE_BUSY OR status%=NET_STATUS_NOT_READY THEN tries%=tries%+1 ELSE result%=TRUE:done%=TRUE
  IF tries%>retries% THEN done%=TRUE
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

DEF FNopen_handle_from_response
=FNget_u16le(rxPacket, 11)

DEF FNopen_accepted
=((rxPacket?8 AND 1)<>0)

DEF FNwrite_bytes_written
=FNget_u16le(rxPacket, 17)

DEF FNread_response_offset
=FNget_u32le(rxPacket, 13)

DEF FNread_response_data_len
=FNget_u16le(rxPacket, 17)

DEF FNread_response_eof
=((rxPacket?8 AND 1)<>0)

DEF FNnetwork_open(method%, flags%, url$, body_len_hint%)
LOCAL payload_len%, result%
payload_len%=FNbuild_open_payload(method%, flags%, url$, body_len_hint%)
result%=-1
IF FNsend_request_retry(NET_CMD_OPEN, payload_len%, 100)=FALSE THEN =-1
IF FNpacket_status<>NET_STATUS_OK THEN =-1
IF FNopen_accepted=FALSE THEN =-1
result%=FNopen_handle_from_response
=result%

DEF PROCnetwork_close(handle%)
LOCAL payload_len%, ok%
payload_len%=FNbuild_close_payload(handle%)
ok%=FNsend_request_retry(NET_CMD_CLOSE, payload_len%, 100)
IF ok%=FALSE THEN PRINT "CLOSE failed":ENDPROC
IF FNpacket_status<>NET_STATUS_OK THEN PRINT "CLOSE status: ";FNpacket_status
ENDPROC

DEF FNnetwork_write(handle%, offset32%, data$, data_len%)
LOCAL payload_len%, result%
payload_len%=FNbuild_write_payload(handle%, offset32%, data$, data_len%)
result%=-1
IF FNsend_request_retry(NET_CMD_WRITE, payload_len%, 200)=FALSE THEN =-1
IF FNpacket_status<>NET_STATUS_OK THEN =-1
result%=FNwrite_bytes_written
=result%

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

DEF PROCasmInit
FOR I%=0 TO 2 STEP 2:P%=asmOSBYTE
  [OPT I%
   LDA &70
   LDX &71
   LDY &72
   JSR OSBYTE
   STA &70
   STX &71
   STY &72
   RTS
  ]
NEXT I%

FOR I%=0 TO 2 STEP 2:P%=asmOSWRCH
  [OPT I%
   LDA &70
   JSR OSWRCH
   RTS
  ]
NEXT I%

FOR I%=0 TO 2 STEP 2:P%=asmTransaction
  [OPT I%
   .setup_serial
   LDX #&08
   LDY #&00
   LDA #&07
   JSR OSBYTE
   LDX #&08
   LDY #&00
   LDA #&08
   JSR OSBYTE
   LDX #&01
   LDY #&00
   LDA #&02
   JSR OSBYTE
   LDX #&03
   LDY #&00
   LDA #&03
   JSR OSBYTE
   RTS

   .flush_serial
   LDX #&01
   LDY #&00
   LDA #&15
   JSR OSBYTE
   RTS

   .restore_screen
   LDX #&00
   LDY #&00
   LDA #&03
   JSR OSBYTE
   LDX #&00
   LDY #&00
   LDA #&02
   JSR OSBYTE
   RTS

   .check_rs423
   LDA #&80
   LDX #&FE
   LDY #&FF
   JSR OSBYTE
   TXA
   RTS

   .read_rs423
   LDA #&91
   LDX #&01
   LDY #&00
   JSR OSBYTE
   BCS read_fail
   TYA
   LDX #&01
   RTS
   .read_fail
   LDX #&00
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
   LDX #&00
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
   JMP send_loop

   .send_done
   LDA #SLIP_END
   JSR OSWRCH

   LDY #&00
   STY &7E
   STY &7F
   STY &78
   LDA &70
   STA &7A
   LDA &71
   STA &7B

   LDA #0
   STA &7C
   LDA #&4F
   STA &7D

   .wait_start
   JSR wait_for_char
   CPX #&01
   BEQ have_start_ok
   BNE trans_fail
   .have_start_ok
   CMP #SLIP_END
   BNE wait_start

   LDA #0
   STA &7C
   LDA #&08
   STA &7D

   .frame_loop
   JSR wait_for_char
   CPX #&01
   BEQ have_frame_ok
   BNE trans_fail
   .have_frame_ok
   STA &79

   LDA #0
   STA &7C
   LDA #&02
   STA &7D

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
   JMP frame_loop

   .trans_ok
   JSR restore_screen
   LDA &7E
   STA &72
   LDA &7F
   STA &73
   RTS

  ]
NEXT I%
ENDPROC
