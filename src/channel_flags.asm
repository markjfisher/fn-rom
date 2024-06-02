.ChannelFlags_SetBit7
    LDA     #&80                    ; Set/Clear flags (C=0 on exit)
.ChannelFlags_SetBits
    ORA     MA+&1117,Y
    BNE     chnflg_save
.ChannelFlags_ClearBit7
    LDA     #&7F
.ChannelFlags_ClearBits
    AND     MA+&1117,Y
.chnflg_save
    STA     MA+&1117,Y
    CLC
    RTS
