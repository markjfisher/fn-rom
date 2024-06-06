IF NOT(_SWRAM_)
.SERVICE0A_claim_statworkspace
{
; Another ROM wants the absolute workspace

IF _DEBUG
    JSR     PrintString
    EQUB    "Checking Stat Claim "
    NOP
    JSR     PrintAXY
ENDIF


	JSR RememberAXY

; Do I own sws?
	JSR SetPrivateWorkspacePointerB0
	LDY #&D4
	LDA (&B0),Y
	BPL exit			; If pws "full" then sws is not mine

	LDY #&00
	; TODO: what does this need to do for FujiNet?
	; JSR ChannelBufferToDisk_Yhandle
	JSR SaveStaticToPrivateWorkspace	; copy valuable data to private wsp

	JSR SetPrivateWorkspacePointerB0	; Called again?
	LDY #&D4
	LDA #&00			; PWSP?&D4=0 = PWSP "full"
	STA (&B0),Y

	TSX 				; RememberAXY called earlier
	STA &0105,X			; changes value of A in stack to 0
.exit
	RTS
}
ENDIF

;OSARGS A=&FF
; .ChannelBufferToDisk_Yhandle_A0
; 	JSR ReturnWithA0
; .ChannelBufferToDisk_Yhandle
; {
; 	LDA MA+&10C0			; Force buffer save
; 	PHA 				; Save opened channels flag byte
; 	LDA #&00			; Don't update catalogue
; 	STA MA+&1086
; 	TYA 				; A=handle
; 	BNE chbuf1
; 	JSR CloseAllFiles
; 	BEQ chbuf2			; always
; .chbuf1
; 	JSR Check_Yhandle_exists_and_close ; Bug fix to only close file and not update catalogue
; .chbuf2
; 	PLA 				; Restore
; 	STA MA+&10C0
; 	RTS
; }
