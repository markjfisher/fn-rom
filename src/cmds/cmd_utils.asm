IF _UTILS_ OR _ROMS_
	\ *HELP UTILS
.CMD_UTILS
	TYA
	LDX #cmdtab2			; cmd table 2
	LDY #cmdtab2size		; Don't include last command (i.e. MMFS)
	BNE Prthelp_Xtable		; always
ENDIF

