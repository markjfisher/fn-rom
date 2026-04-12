REM filename: CHUCK
REM Chuck Norris Jokes Fetcher

DIM asmTransaction 396
DIM asmJsonParse 350
DIM patBuf 10

DIM category$(11)

category$(0)="animal"
category$(1)="career"
category$(2)="celebrity"
category$(3)="dev"
category$(4)="fashion"
category$(5)="food"
category$(6)="history"
category$(7)="movie"
category$(8)="music"
category$(9)="science"
category$(10)="sport"
category$(11)="travel"

TX_BUFFER_SIZE%=160
RX_BUFFER_SIZE%=420
NET_READ_SIZE%=400
FULL_PAYLOAD%=512
JSON_VALUE_SIZE%=256

DIM txPacket    TX_BUFFER_SIZE%
DIM rxPacket    RX_BUFFER_SIZE%
DIM fullPayload FULL_PAYLOAD%
DIM jsonValue   JSON_VALUE_SIZE%

ttRow%=0
ttCol%=0
ttWord$=""
ttWordLen%=0
ttMaxRows%=13
ttOverflow%=FALSE

status%=0

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

REPEAT
  cat%=RND(12)-1
  url$="https://api.chucknorris.io/jokes/random?category="+category$(cat%)
  PROCfetch_joke(url$)
  PROCshow_joke_page

  TIME=0
  REPEAT UNTIL TIME>=500
UNTIL FALSE
END

REM ###

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
   \ timeout initial
   LDA #&B0
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
   \ timeout data
   LDA #&10
   STA &7D

   .frame_loop
   JSR wait_for_char
   CPX #&01
   BEQ have_frame_ok
   BNE trans_fail
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

REM Generic JSON field finder
REM INPUT:
REM   &80/&81 = payload length
REM   &82/&83 = pattern address
REM   &84/&85 = pattern length
REM   &86/&87 = payload address
REM OUTPUT:
REM   &70/&71 = offset of value start within payload
REM   &72/&73 = value length
REM NOT FOUND:
REM   &70/&71 = &FFFF
REM   &72/&73 = 0

FOR I%=0 TO 2 STEP 2:P%=asmJsonParse
[OPT I%

.findJsonField

  \ Default return = not found
  LDA #&FF
  STA &70
  STA &71
  LDA #0
  STA &72
  STA &73

  \ payload ptr = input payload address
  LDA &86
  STA &74
  LDA &87
  STA &75

  \ search offset = 0
  LDA #0
  STA &76
  STA &77

  \ remaining payload bytes
  LDA &80
  STA &78
  LDA &81
  STA &79

.searchLoop

  \ if remaining < pattern length => fail
  LDA &79
  CMP &85
  BCS over1
  JMP notFound

.over1
  BNE enoughLeft
  LDA &78
  CMP &84
  BCS enoughLeft
  JMP notFound

.enoughLeft
  JSR matchPattern
  BCS foundPattern

  JSR advanceSearch1
  JMP searchLoop

.foundPattern
  \ Result offset = search offset + pattern length
  CLC
  LDA &76
  ADC &84
  STA &70
  LDA &77
  ADC &85
  STA &71

  \ Advance payload ptr by pattern length
  LDA &84
  STA &8A
  LDA &85
  STA &8B
.advanceByPatternLoop
  LDA &8A
  ORA &8B
  BEQ startValueScan
  JSR advancePayloadOnly1
  SEC
  LDA &8A
  SBC #1
  STA &8A
  LDA &8B
  SBC #0
  STA &8B
  JMP advanceByPatternLoop

.startValueScan
  \ length = 0
  LDA #0
  STA &72
  STA &73

  \ backslash parity = 0
  STA &88

.valueLoop
  \ Out of bytes => fail
  LDA &78
  ORA &79
  BEQ notFound

  LDY #0
  LDA (&74),Y

  CMP #34
  BEQ maybeEndQuote

  CMP #92
  BEQ sawBackslash

  \ ordinary char
  LDA #0
  STA &88
  JSR incLenAndAdvance1
  JMP valueLoop

.sawBackslash
  LDA &88
  EOR #1
  STA &88
  JSR incLenAndAdvance1
  JMP valueLoop

.maybeEndQuote
  \ if backslash parity = 0 then quote ends string
  LDA &88
  BEQ done

  \ escaped quote, include it in length
  LDA #0
  STA &88
  JSR incLenAndAdvance1
  JMP valueLoop

.done
  RTS

.notFound
  LDA #&FF
  STA &70
  STA &71
  LDA #0
  STA &72
  STA &73
  RTS

.matchPattern
  \ Compare payload at &74/&75 against pattern at &82/&83 for &84/&85 bytes
  \ Carry set if match, clear if no match

  \ temp payload ptr = current payload ptr
  LDA &74
  STA &7C
  LDA &75
  STA &7D

  \ temp pattern ptr = pattern ptr
  LDA &82
  STA &7E
  LDA &83
  STA &7F

  \ remaining pattern bytes
  LDA &84
  STA &8A
  LDA &85
  STA &8B

.matchLoop
  LDA &8A
  ORA &8B
  BEQ matchYes

  LDY #0
  LDA (&7C),Y
  CMP (&7E),Y
  BNE matchNo

  \ temp payload ptr++
  INC &7C
  BNE noCarryMP1
  INC &7D
.noCarryMP1

  \ temp pattern ptr++
  INC &7E
  BNE noCarryMP2
  INC &7F
.noCarryMP2

  \ remaining pattern bytes--
  SEC
  LDA &8A
  SBC #1
  STA &8A
  LDA &8B
  SBC #0
  STA &8B

  JMP matchLoop

.matchYes
  SEC
  RTS

.matchNo
  CLC
  RTS

.advanceSearch1
  \ payload ptr++
  INC &74
  BNE noCarryAS1
  INC &75
.noCarryAS1

  \ offset++
  INC &76
  BNE noCarryAS2
  INC &77
.noCarryAS2

  \ remaining--
  SEC
  LDA &78
  SBC #1
  STA &78
  LDA &79
  SBC #0
  STA &79
  RTS

.advancePayloadOnly1
  \ payload ptr++
  INC &74
  BNE noCarryAP1
  INC &75
.noCarryAP1

  \ remaining--
  SEC
  LDA &78
  SBC #1
  STA &78
  LDA &79
  SBC #0
  STA &79
  RTS

.incLenAndAdvance1
  \ length++
  INC &72
  BNE lenNoCarry
  INC &73
.lenNoCarry

  \ payload ptr++
  INC &74
  BNE noCarryLA1
  INC &75
.noCarryLA1

  \ remaining--
  SEC
  LDA &78
  SBC #1
  STA &78
  LDA &79
  SBC #0
  STA &79
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

REM Scan fullPayload for "key":"..." and extract string value into jsonValue? (no full json$).
DEF PROCparse_json_string_value_from_buffer(key$)
LOCAL pat$, pat_len%, i%, j%, match%
jsonValueLen%=0
pat$=CHR$(34)+key$+CHR$(34)+":"+CHR$(34)
pat_len%=LEN(pat$)
IF full_len%<pat_len% THEN GOTO 1500

FOR I%=1 TO pat_len%
  ?(patBuf+I%-1)=ASC(MID$(pat$,I%,1))
NEXT

?&80 = full_len% MOD 256
?&81 = full_len% DIV 256

?&82 = patBuf MOD 256
?&83 = patBuf DIV 256

?&84 = pat_len% MOD 256
?&85 = pat_len% DIV 256

?&86 = fullPayload MOD 256
?&87 = fullPayload DIV 256

CALL findJsonField

pos% = ?&70 + 256*?&71
len% = ?&72 + 256*?&73

IF len%=0 THEN GOTO 1500
PROCcopy_value_bytes(pos%, len%)
1500 REM end proc
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
IF ok%=FALSE THEN PRINT "CLOSE failed":GOTO 1700
status%=FNpacket_status
1700 REM end proc
ENDPROC

REM Append one READ chunk from rxPacket into fullPayload (BBC BASIC II: no IF/ENDIF).
DEF PROCnetwork_append_read_chunk(data_len%)
LOCAL I%
net_chunk_err%=0
IF data_len%<=0 THEN GOTO 1800
IF full_len%+data_len%>FULL_PAYLOAD%+1 THEN net_chunk_err%=1:GOTO 1800
FOR I%=0 TO data_len%-1
  fullPayload?(full_len%+I%)=rxPacket?(19+I%)
NEXT
full_len%=full_len%+data_len%
1800 REM endprod
ENDPROC

DEF PROCnetwork_read_all(handle%)
LOCAL offset32%, payload_len%, data_len%, eof%, echo_offset%, ok%
offset32%=0
full_len%=0
PRINT TAB(0,24);"Doing network_read_all";
REPEAT
  payload_len%=FNbuild_read_payload(handle%, offset32%, NET_READ_SIZE%)
  ok%=FNsend_request_retry(NET_CMD_READ, payload_len%, 4)
  IF ok%=FALSE THEN GOTO 1900
  status%=FNpacket_status
  IF status%<>NET_STATUS_OK THEN GOTO 1900
  echo_offset%=FNget_u32le(rxPacket, 13)
  data_len%=FNget_u16le(rxPacket, 17)
  eof%=FNread_response_eof
  PROCnetwork_append_read_chunk(data_len%)
  IF net_chunk_err%=1 THEN GOTO 1900
  offset32%=offset32%+data_len%
UNTIL eof%
1900 REM exit proc
PRINT TAB(0,24);STRING$(39," ");
ENDPROC

DEF PROCfetch_joke(url$)
LOCAL handle%
jsonValueLen%=0
handle%=FNnetwork_open(NET_METHOD_GET, NET_FLAG_ALLOW_EVICT, url$, 0)
IF handle%<0 THEN full_len%=0:GOTO 2000
PROCnetwork_read_all(handle%)
PROCnetwork_close(handle%)
IF full_len%<=0 THEN full_len%=0:GOTO 2000
PROCparse_json_string_value_from_buffer("value")
2000 REM exit proc
ENDPROC

REM ============================================================
REM Teletext joke page for BBC BASIC II / BBC Micro
REM Uses:
REM   jsonValue      buffer containing joke text
REM   jsonValueLen%  length of joke text
REM
REM Call:
REM   PROCshow_joke_page
REM ============================================================


DEF PROCshow_joke_page
LOCAL row%, i%, c%

CLS
VDU 23,1,0;0;0;0;
PROCtt_header
PROCtt_top_bar
PRINT TAB(0,3);CHR$(147);CHR$(238);STRING$(12,CHR$(172)+CHR$(173)+CHR$(174));CHR$(172);CHR$(189);
FOR row%=0 TO ttMaxRows%-1
  PRINT TAB(0,4+row%);CHR$(147);CHR$(238);CHR$(135);" ";STRING$(34," ");CHR$(147);CHR$(189);
NEXT
PRINT TAB(0,17);CHR$(147);CHR$(238);STRING$(12,CHR$(172)+CHR$(188)+CHR$(236));CHR$(172);CHR$(189);

PROCtt_reset_body

IF jsonValueLen%<=0 THEN PROCtt_print_empty:PROCtt_bottom_bar:PROCtt_footer:GOTO 2200

FOR i%=0 TO jsonValueLen%-1
  c%=jsonValue?i%
  PROCtt_feed_char(c%)
NEXT

PROCtt_flush_word

IF ttOverflow% THEN PROCtt_overflow

PROCtt_bottom_bar
PROCtt_footer

2200 REM end proc
ENDPROC

DEF PROCtt_reset_body
ttRow%=0
ttCol%=0
ttWord$=""
ttWordLen%=0
ttOverflow%=FALSE
ttMaxRows%=13
ENDPROC

DEF PROCtt_header
PRINT CHR$(132);CHR$(157);CHR$(131);CHR$(141);"FUJITEXT 184/1";CHR$(135);"Chuck Norris JOKE    ";
PRINT CHR$(132);CHR$(157);CHR$(131);CHR$(141);"FUJITEXT 184/1";CHR$(135);"Chuck Norris JOKE    ";
ENDPROC

DEF PROCtt_top_bar
PRINT
ENDPROC

DEF PROCtt_bottom_bar
PRINT
ENDPROC

DEF PROCtt_footer
PRINT TAB(0,20);
PRINT CHR$(129);CHR$(157);CHR$(130);STRING$(37, " ");
PRINT CHR$(129);CHR$(157);CHR$(134);"    Next joke in about 10 seconds    ";
PRINT CHR$(129);CHR$(157);CHR$(130);"       MODE 7 Teletext display       ";
PRINT CHR$(129);CHR$(157);CHR$(130);STRING$(37, " ");

ENDPROC

DEF PROCtt_print_empty
PRINT TAB(3,5);"(no value parsed)";
ENDPROC

DEF PROCtt_feed_char(c%)
IF ttOverflow% THEN GOTO 2500

IF c%=13 THEN PROCtt_flush_word:PROCtt_newline:GOTO 2500
IF c%=10 THEN PROCtt_flush_word:PROCtt_newline:GOTO 2500
IF c%=9 THEN c%=32

IF c%=32 THEN PROCtt_flush_word:GOTO 2500

ttWord$=ttWord$+CHR$(c%)
ttWordLen%=ttWordLen%+1

2500 REM end proc
ENDPROC

DEF PROCtt_flush_word
LOCAL needed%

IF ttOverflow% THEN GOTO 2700
IF ttWordLen%=0 THEN GOTO 2700

needed%=ttWordLen%
IF ttCol%>0 THEN needed%=needed%+1

IF ttCol%+needed%>35 THEN PROCtt_newline

IF ttOverflow% THEN GOTO 2700

IF ttCol%>0 THEN PROCtt_putc(32,ttRow%,ttCol%):ttCol%=ttCol%+1

PROCtt_puts(ttWord$,ttRow%,ttCol%)
ttCol%=ttCol%+ttWordLen%
ttWord$=""
ttWordLen%=0
2700 REM end proc
ENDPROC

DEF PROCtt_newline
ttRow%=ttRow%+1
ttCol%=0
IF ttRow%>=ttMaxRows% THEN ttOverflow%=TRUE
ENDPROC

DEF PROCtt_putc(c%,row%,col%)
IF row%>13 THEN GOTO 2800
IF col%>34 THEN GOTO 2800
PRINT TAB(3+col%,5+row%);CHR$(c%);

2800 REM end proc
ENDPROC

DEF PROCtt_puts(s$,row%,col%)
LOCAL k%
FOR k%=1 TO LEN(s$)
  PROCtt_putc(ASC(MID$(s$,k%,1)),row%,col%+k%-1)
NEXT
ENDPROC

DEF PROCtt_overflow
PRINT TAB(35,18);"...";
ENDPROC
