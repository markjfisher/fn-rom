REM filename: CHUCK
REM Chuck Norris Jokes Fetcher

url$="https://api.chucknorris.io/jokes/random"

DIM asmTransaction 396

TX_BUFFER_SIZE%=160
RX_BUFFER_SIZE%=512
NET_READ_SIZE%=480
FULL_PAYLOAD%=1024
JSON_VALUE_SIZE%=512

DIM txPacket    TX_BUFFER_SIZE%
DIM rxPacket    RX_BUFFER_SIZE%
DIM fullPayload FULL_PAYLOAD%
DIM jsonValue   JSON_VALUE_SIZE%

REM full_len% = bytes accumulated into fullPayload after a read; jsonValueLen% = bytes in jsonValue
REM net_chunk_err% = 1 if PROCnetwork_append_read_chunk stopped on overflow (caller should ENDPROC)
full_len%=0
jsonValueLen%=0
net_chunk_err%=0

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

PROCasmInit

PRINT "Chuck Norris Random"
PRINT "==================="
PRINT

PROCfetch_joke(url$)
PRINT "pringing..."
PROCprint_value_line
PRINT "Done"

END

REM ============================================
REM PROCEDURE AND FUNCTION DEFINITIONS
REM ============================================

DEF PROCasmInit

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
    \ &79 holds the decoded byte to write into the rx buffer.
    \ &72/&73 = rx buffer capacity
    \ &7E/&7F = current decoded length / write offset
    \ &7A/&7B = current write pointer in rx buffer
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

DEF FNopen_accepted
=((rxPacket?8 AND 1)<>0)

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

REM Copy bytes fullPayload?(start% ..) for length n% into jsonValue? (BBC II string max 255 chars).
DEF PROCcopy_value_bytes(start%, n%)
LOCAL jj%
jsonValueLen%=n%
IF jsonValueLen%>JSON_VALUE_SIZE%+1 THEN jsonValueLen%=JSON_VALUE_SIZE%+1
FOR jj%=0 TO jsonValueLen%-1
  jsonValue?jj%=fullPayload?(start%+jj%)
NEXT jj%
ENDPROC

REM From start% (first char of JSON string value), find closing quote; set jsonValueLen%/jsonValue.
DEF PROCtry_extract_value_at(start%)
LOCAL k%, n%
jsonValueLen%=0
IF start%>=full_len% THEN ENDPROC
FOR k%=start% TO full_len%-1
  IF fullPayload?k%=34 THEN n%=k%-start%:PROCcopy_value_bytes(start%, n%):ENDPROC
NEXT k%
ENDPROC

REM Scan fullPayload for "key":"..." and extract string value into jsonValue? (no full json$).
DEF PROCparse_json_string_value_from_buffer(key$)
LOCAL pat$, pat_len%, i%, j%, match%
jsonValueLen%=0
pat$=CHR$(34)+key$+CHR$(34)+":"+CHR$(34)
pat_len%=LEN(pat$)
IF full_len%<pat_len% THEN ENDPROC
FOR i%=0 TO full_len%-pat_len%
  match%=TRUE
  FOR j%=1 TO pat_len%
    IF match% THEN IF fullPayload?(i%+j%-1)<>ASC(MID$(pat$, j%, 1)) THEN match%=FALSE
  NEXT j%
  IF match% THEN PROCtry_extract_value_at(i%+pat_len%)
  IF jsonValueLen%>0 THEN ENDPROC
NEXT i%
ENDPROC

REM Print value from jsonValue? (avoids string length limit).
DEF PROCprint_value_line
LOCAL j%
IF jsonValueLen%<=0 THEN PRINT "(no value parsed)":ENDPROC
FOR j%=0 TO jsonValueLen%-1
  PRINT CHR$(jsonValue?j%);
NEXT j%
PRINT
ENDPROC

DEF FNnetwork_open(method%, flags%, url$, body_len_hint%)
LOCAL payload_len%, result%
payload_len%=FNbuild_open_payload(method%, flags%, url$, body_len_hint%)
result%=-1
IF FNsend_request_retry(NET_CMD_OPEN, payload_len%, 20)=FALSE THEN =-1
IF FNpacket_status<>NET_STATUS_OK THEN =-1
IF FNopen_accepted=FALSE THEN =-1
result%=FNget_u16le(rxPacket, 11)
=result%

DEF PROCnetwork_close(handle%)
LOCAL payload_len%, ok%
payload_len%=FNbuild_close_payload(handle%)
ok%=FNsend_request_retry(NET_CMD_CLOSE, payload_len%, 20)
IF ok%=FALSE THEN PRINT "CLOSE failed":ENDPROC
IF FNpacket_status<>NET_STATUS_OK THEN PRINT "CLOSE status: ";FNpacket_status
ENDPROC

REM Append one READ chunk from rxPacket into fullPayload (BBC BASIC II: no IF/ENDIF).
DEF PROCnetwork_append_read_chunk(data_len%)
LOCAL I%
net_chunk_err%=0
IF data_len%<=0 THEN ENDPROC
IF full_len%+data_len%>FULL_PAYLOAD%+1 THEN PRINT "Payload too large":net_chunk_err%=1:ENDPROC
FOR I%=0 TO data_len%-1
  fullPayload?(full_len%+I%)=rxPacket?(19+I%)
NEXT
full_len%=full_len%+data_len%
ENDPROC

DEF PROCnetwork_read_all(handle%)
LOCAL offset32%, payload_len%, data_len%, eof%, echo_offset%, ok%
offset32%=0
full_len%=0
REPEAT
  payload_len%=FNbuild_read_payload(handle%, offset32%, NET_READ_SIZE%)
  ok%=FNsend_request_retry(NET_CMD_READ, payload_len%, 4)
  IF ok%=FALSE THEN PRINT "READ failed":ENDPROC
  IF FNpacket_status<>NET_STATUS_OK THEN PRINT "READ status: ";FNpacket_status:ENDPROC
  echo_offset%=FNget_u32le(rxPacket, 13)
  data_len%=FNget_u16le(rxPacket, 17)
  eof%=FNread_response_eof
  PROCnetwork_append_read_chunk(data_len%)
  IF net_chunk_err%=1 THEN ENDPROC
  offset32%=offset32%+data_len%
UNTIL eof%
ENDPROC

DEF PROCfetch_joke(url$)
LOCAL handle%
jsonValueLen%=0
handle%=FNnetwork_open(NET_METHOD_GET, NET_FLAG_ALLOW_EVICT, url$, 0)
IF handle%<0 THEN PRINT "OPEN failed":ENDPROC
PRINT "reading..."
PROCnetwork_read_all(handle%)
PRINT "closing..."
PROCnetwork_close(handle%)
IF full_len%<=0 THEN PRINT "Empty response":ENDPROC
PRINT "parsing..."
PROCparse_json_string_value_from_buffer("value")
PRINT "finished fetch."
ENDPROC
