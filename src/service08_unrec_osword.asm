; OSWORD 7F is Floppy Disk operataion
; See https://beebwiki.mdfs.net/OSWORD_%267F


.SERVICE08_unrec_OSWORD
{
	; BP12K_NEST
	JSR RememberAXY
{

IF _DEBUG
    JSR     PrintString
    EQUB    "OSWORD "
	LDA 	&EF
	JSR 	PrintHex
	JSR 	PrintNewLine
ENDIF


	; LDY &EF				; Y = Osword call
	; BMI exit			; Y > &7F
	; CPY #&7D
	; BCC exit			; Y < &7D

	; ; Test if MMFS by checking OSFILE vector.

	; LDA &213			; Check of the low OSFILE vector is pointing
	; CMP #&FF            ; to the corresponding extended vector.
	; BNE notMMFS
	; LDA &212
	; CMP #&1B
	; BNE notMMFS
	; LDA &0DBC			; Rom number in extended vector.
	; CMP &F4				; Is it our ROM?
	; BNE exit

	; JSR ReturnWithA0

	; LDX &F0				; Osword X reg
	; STX &B0
	; LDX &F1				; Osword Y reg
	; STX &B1

	; LDY &EF
	; INY
	; BPL notOSWORD7F

	; PHP
	; CLI
	; JSR Osword7F_8271_Emulation	; OSWORD &7F 8271 emulation, handles 53/57/4B commands
	; PLP
.notMMFS
.exit
}
	RTS

; .notOSWORD7F
; 	JSR Set_CurDirDrv_ToDefaults_and_load		; Load catalogue
; 	INY
; 	BMI OSWORD7E

; 	LDY #&00			; OSWORD &7D return cycle no.
; 	LDA MA+&0F04
; 	STA (&B0),Y
; 	RTS

; .OSWORD7E
; 	LDA #&00			; OSWORD &7E
; 	TAY
; 	STA (&B0),Y
; 	INY
; 	LDA MA+&0F07			; sector count LB
; 	STA (&B0),Y
; 	INY
; 	LDA MA+&0F06			; sector count HB
; 	AND #&03
; 	STA (&B0),Y
; 	INY
; 	LDA #&00			; result
; 	STA (&B0),Y
; 	RTS
}
