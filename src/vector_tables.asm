; Vector table copied to &0212
.vectors_table
    EQUW    &FF1B    ; FILEV
    EQUW    &FF1E    ; ARGSV
    EQUW    &FF21    ; BGETV
    EQUW    &FF24    ; BPUTV
    EQUW    &FF27    ; GBPBV
    EQUW    &FF2A    ; FINDV
    EQUW    &FF2D    ; FSCV

; Extended vector table
.extendedvectors_table
    EQUW    FILEV_ENTRY
    BRK
    EQUW    ARGSV_ENTRY
    BRK
    EQUW    BGETV_ENTRY
    BRK
    EQUW    BPUTV_ENTRY
    BRK
    EQUW    GBPBV_ENTRY
    BRK
    EQUW    FINDV_ENTRY
    BRK
    EQUW    FSCV_ENTRY
    BRK

; OSFSC table 1 low bytes
.fscv_table1
    EQUB    LO(fscv0_starOPT-1)
    EQUB    LO(fscv1_EOF_Yhndl-1)
    EQUB    LO(fscv2_4_11_starRUN-1)
    EQUB    LO(fscv3_unreccommand-1)
    EQUB    LO(fscv2_4_11_starRUN-1)
    EQUB    LO(fscv5_starCAT-1)
    EQUB    LO(fscv6_shutdownfilesys-1)
    EQUB    LO(fscv7_hndlrange-1)
    EQUB    LO(fscv_osabouttoproccmd-1)
    EQUB    LO(fscv9_starEX-1)
    EQUB    LO(fscv10_starINFO-1)
    EQUB    LO(fscv2_4_11_starRUN-1)


; OSFSC table 2 high bytes
.fscv_table2
    EQUB    HI(fscv0_starOPT-1)
    EQUB    HI(fscv1_EOF_Yhndl-1)
    EQUB    HI(fscv2_4_11_starRUN-1)
    EQUB    HI(fscv3_unreccommand-1)
    EQUB    HI(fscv2_4_11_starRUN-1)
    EQUB    HI(fscv5_starCAT-1)
    EQUB    HI(fscv6_shutdownfilesys-1)
    EQUB    HI(fscv7_hndlrange-1)
    EQUB    HI(fscv_osabouttoproccmd-1)
    EQUB    HI(fscv9_starEX-1)
    EQUB    HI(fscv10_starINFO-1)
    EQUB    HI(fscv2_4_11_starRUN-1)

; OSFILE tables
.finv_tablelo
    EQUB    LO(osfileFF_loadfiletoaddr-1)
    EQUB    LO(osfile0_savememblock-1)
    EQUB    LO(osfile1_updatecat-1)
    EQUB    LO(osfile2_wrloadaddr-1)
    EQUB    LO(osfile3_wrexecaddr-1)
    EQUB    LO(osfile4_wrattribs-1)
    EQUB    LO(osfile5_rdcatinfo-1)
    EQUB    LO(osfile6_delfile-1)

.finv_tablehi
    EQUB    HI(osfileFF_loadfiletoaddr-1)
    EQUB    HI(osfile0_savememblock-1)
    EQUB    HI(osfile1_updatecat-1)
    EQUB    HI(osfile2_wrloadaddr-1)
    EQUB    HI(osfile3_wrexecaddr-1)
    EQUB    HI(osfile4_wrattribs-1)
    EQUB    HI(osfile5_rdcatinfo-1)
    EQUB    HI(osfile6_delfile-1)

; GBPB tables
.gbpbv_table1
    EQUB    LO(NotCmdTable2)
    EQUB    LO(gbpb_putbytes)
    EQUB    LO(gbpb_putbytes)
    EQUB    LO(gbpb_getbyteSAVEBYTE)
    EQUB    LO(gbpb_getbyteSAVEBYTE)
    EQUB    LO(gbpb5_getmediatitle)
    EQUB    LO(gbpb6_rdcurdirdevice)
    EQUB    LO(gbpb7_rdcurlibdevice)
    EQUB    LO(gbpb8_rdfilescurdir)

.gbpbv_table2
    EQUB    HI(NotCmdTable2)
    EQUB    HI(gbpb_putbytes)
    EQUB    HI(gbpb_putbytes)
    EQUB    HI(gbpb_getbyteSAVEBYTE)
    EQUB    HI(gbpb_getbyteSAVEBYTE)
    EQUB    HI(gbpb5_getmediatitle)
    EQUB    HI(gbpb6_rdcurdirdevice)
    EQUB    HI(gbpb7_rdcurlibdevice)
    EQUB    HI(gbpb8_rdfilescurdir)

.gbpbv_table3
    EQUB    &04
    EQUB    &02
    EQUB    &03
    EQUB    &06
    EQUB    &07
    EQUB    &04
    EQUB    &04
    EQUB    &04
    EQUB    &04
