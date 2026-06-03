.ifdef FUJINET_MACHINE_MASTER

        .export service21_claim_hidden_sws
        .export service22_claim_hidden_pws
        .export service24_required_pws
        .export service25_fs_info
        .export service27_reset

        .import paged_rom_priv_ws

        .importzp paged_ram_copy
        .importzp text_pointer

        .include "fujinet.inc"

;33 &21 Indicate static workspace in 'hidden' RAM
; On entry Y contains the current proposed
; upper limit which should be incremented if this is insufficient.
; The ordering in the Master MOS is service call &24; &21; &22; &01; &02; &23,
; in this way the private workspace is counted first (by decrementing from the
; top of hidden RAM) and this is offered as the suggested top of static
; workspace. If this value is not enough a ROM may choose to exceed it during
; service call &21, this new top value is passed back to allocate private
; workspace during service call &22. If this overflows the 'hidden' RAM area any
; overspill is allocated by calls &01 and &02, after which the final top of
; static workspace is known. Under this scheme the static workspace is
; preferentially placed in 'hidden' RAM since it must be contiguous and at a
; fixed address [Master MOS versions]

service21_claim_hidden_sws:
        cpy     #$ca
        bcs     @ok
        ldy     #$ca
@ok:    rts


;34 &22 Claim private workspace in hidden RAM
; The private workspace must first be requested by service call &24, after all
; other requests have taken place this call is issued to assign addresses.
; If you DO want workspace then store the current value of Y
; at (&DF0+ROM SOCKET NUMBER), then increment Y depending on the number of
; pages you require.
; If Y exceeds &DC00 (ie. Y >= &DC on entry) then 'hidden' RAM is full and this
; call should be claimed with A=0. Private workspace will have to be placed in
; user memory by trapping service call &02. [Master MOS versions]

service22_claim_hidden_pws:
        ; This is the actual page (e.g. D9 typically) that we have been given in memory to use
        tya
        sta     paged_rom_priv_ws, x
        lda     #$22
        ; we need 2 pages for our buffers (TODO: shall we increase this for master?)
        iny
        iny
        rts

;36 &24 Indicate private workspace requirements in hidden RAM
; Extra 'hidden' RAM which is overlaid on top of the MOS VDU drivers is available
; on the Master series. This allows service ROMs to claim private and static
; workspace in the same way as service call 1 and 2 but without affecting the
; value of OSHWM and eating into user RAM.
; Decrement Y by the number of pages requested (the actual allocation step is
; later in service call &22) and exit A preserved [Master MOS versions]

service24_required_pws:
        ; claim 2 pages, see service22 above for equivalent grab.
        dey
        dey
        rts

;37 &25 Inform MOS of filing system details
; This is issued by the MOS and need only be trapped by the current
; filing system. It should return 11 bytes the start of which is
; pointed to by the vector at &F2 and &F3. These eleven consist of 8
; bytes (space padded) of ASCii characters describing the filing
; system eg. "NET " then the lowest handle in use then the
; highest handle in use then the filing system number.
; More than one block of 11 can be submitted to allow more than one
; synonym for a filing system to be used, eg. the tape filing system
; submits both "TAPE" and "CFS". Exit with Y incremented
; by (n*11) [Master MOS versions]

service25_fs_info:
        ldx     #$0A
@s25_loop:
        lda     fsinfo, x
        sta     (text_pointer), y
        iny
        dex
        bpl     @s25_loop

        lda     #$25
        ldx     paged_ram_copy
        rts
; 11 bytes of file system information
fsinfo:
        .byte   filesysno
        .byte   filehndl+5
        .byte   filehndl+1
        .byte   "  SFijuF" ; "FujiFS  " backwards

;39 &27 Reset occurred
; A reset has occurred (Ctrl-Break, power on, or BREAK pressed). This service
; call is required because workspace is no longer allocated on a soft reset as
; it was on the BBC-B, so service calls 1 and 2 can no longer be used to infer
; that a reset occurred. [Master MOS versions]

; for fujinet, I'm going to ignore this for now
service27_reset:
;         pha
;         phx
;         phy
;         lda     #$FD
;         ldx     #$00
;         ldy     #$FF
;         jsr     OSBYTE
;         cpx     #$00
;         beq     @s27_softbreak

;         ; avoid "bad sum" error with autoboot with power on (in MMFS)
;         jsr     vid_reset

; @s27_softbreak:
;         ply
;         plx
;         pla
;         rts

; vid_reset:
        rts

.endif