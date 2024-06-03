.Param_SyntaxErrorIfNull
	JSR GSINIT_A			; (if no params then syntax error)
	BEQ errSYNTAX			; branch if not null string
	RTS

.errSYNTAX
	JSR ReportError			; Print Syntax error
	EQUB &DC
	EQUS "Syntax: "
	STX &B9				; ?&B9=&100 offset (>0)
	JSR prtcmdAtBCadd1		; add command syntax
	LDA #&00
	JSR prtcmd_prtchr
	JMP &0100			; Cause BREAK!

.prtcmdAtBCadd1
{
	LDA #7				; A=column width
	STA &B8
	LDX &BF				; X=table offset
	CPX #cmdtab4
	BCC prtcmdloop			; All table 4 commands
	LDA #&44			; start with "D"
	JSR prtcmd_prtchr
.prtcmdloop
	INX	 			; If ?&B9=0 then print
	LDA cmdtable1,X			; else it's the &100 offset
	BMI prtcmdloop_exit		; If end of str
	JSR prtcmd_prtchr
	JMP prtcmdloop

.prtcmdloop_exit
	LDY &B8
	BMI prtcmdnospcs
	JSR prtcmd_Print_Y_Spaces_IfNotErr	; print spaces
.prtcmdnospcs
	STX &BF				; ready for next time

	LDA cmdtable1,X			; paramater code
	AND #&7F
	JSR prtcmdparam			; 1st parameter
	JSR A_rorx4			; 2nd parameter

.prtcmdparam
	JSR RememberAXY
	AND #&0F
	BEQ prtcmdparamexit		; no parameter
	TAY 				; Y=parameter no.
	LDA #&20
	JSR prtcmd_prtchr		; print space
	LDX #&FF			; Got to parameter Y
.prtcmdparam_findloop
	INX 				; (Each param starts with bit 7 set)
	LDA parametertable,X
	BPL prtcmdparam_findloop
	DEY
	BNE prtcmdparam_findloop	; next parameter
	AND #&7F			; Clear bit 7 of first chr
.prtcmdparam_loop
	JSR prtcmd_prtchr		;Print parameter
	INX
	LDA parametertable,X
	BPL prtcmdparam_loop
}
.prtcmdparamexit
	RTS

.prtcmd_prtchr
	JSR RememberAXY			; Print chr
	LDX &B9
	BEQ prtcmdparam_prtchr		; If printing help
	INC &B9
	STA &0100,X
	RTS

.prtcmdparam_prtchr
	DEC &B8				; If help print chr
	JMP PrintChrA

.prtcmd_Print_Y_Spaces_IfNotErr
{
	LDA &B9
	BNE prtcmd_yspc_exit		; If printing error exit
	LDA #&20			; Print space
.prtcmd_yspc_loop
	JSR prtcmd_prtchr
	DEY
	BPL prtcmd_yspc_loop
.prtcmd_yspc_exit
	RTS
}
