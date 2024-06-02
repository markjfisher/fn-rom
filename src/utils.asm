; various utility/helper functions

.osbyte0F_flushinbuf2
    JSR     RememberAXY

.osbyte0F_flushinbuf
    LDA     #&0F
    LDX     #&01
    LDY     #&00
    BEQ     goOSBYTE            ; always

.osbyte03_Aoutstream
    TAX

.osbyte03_Xoutstream
    LDA     #&03
    BNE     goOSBYTE            ; always

.osbyte7E_ackESCAPE2
    JSR     RememberAXY

.osbyte7E_ackESCAPE
    LDA     #&7E
    BNE     goOSBYTE

.osbyte8F_servreq
    LDA     #&8F
    BNE     goOSBYTE

.osbyte_X0YFF
    LDX     #&00

.osbyte_YFF
    LDY     #&FF

.goOSBYTE
    JMP     OSBYTE

.A_rorx6and3
    LSR     A
    LSR     A
.A_rorx4and3
    LSR     A
    LSR     A
.A_rorx2and3
    LSR     A
    LSR     A
    AND     #&03
    RTS

.A_rorx5
    LSR     A
.A_rorx4
    LSR     A
.A_rorx3
    LSR     A
    LSR     A
    LSR     A
    RTS

.A_rolx5
    ASL     A
.A_rolx4
    ASL     A
    ASL     A
    ASL     A
    ASL     A
.getcat_exit
    RTS

.inc_word_AE_and_load
{
    INC     &AE
    BNE     inc_word_AE_exit
    INC     &AF
.inc_word_AE_exit
    LDA     (&AE),Y
    RTS
}