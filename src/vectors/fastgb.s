        .export  fastgb
        .export  gbpb_load_blkptr

        .import  cmp_ptr_ext
        .import  gbpbv_table3
        .import  channel_buffer_to_disk_yintch
        .import  channel_flags_clear_bits
        .import  channel_set_dir_drive_get_cat_entry_yintch
        .import  load_mem_block
        .import  save_mem_block

        .import  a_rolx4
        .import  a_rolx5
        .import  updext
        .import  upgbpb

        .include "os.inc"

; This is converted from MMFS version which is converted from https://github.com/tom-seddon/acorn_1770_dfs_disassembly/blob/main/dfs224.asm.txt

fuji_workspace  := $1000

dosram          := fuji_workspace + $60 ; copy of OSGBPB/OSFILE ctrl block; temp filename in *CAT
acc             := dosram + $0D         ; temporary OSGBPB call number
ltemp0          := dosram + $0E         ; temporary count of bytes remaining to transfer
ldlow           := fuji_workspace + $72 ; 4 bytes; load address passed to OSFILE; Tube tx addr
dcby            := fuji_workspace + $C2 ; channel workspace pointer for current open file
seqsem          := fuji_workspace + $DD ; $00=*SPOOL/*EXEC critical, close files on error

seqmap          := fuji_channel_start   ; workspaces for channels $11..$15
seqcat          := seqmap + $00         ; when accessing the catalogue entry
seqlh           := seqcat + $0D         ; top bits exec/length/load/LBA in catalogue entry
seqloc          := seqcat + $0F         ; LSB of starting LBA in catalogue entry
seqpl           := seqmap + $10         ; LSB of sequential pointer (PTR)
seqpm           := seqmap + $11         ; 2MSB of sequential pointer
seqph           := seqmap + $12         ; MSB of sequential pointer
seqlma          := seqmap + $15         ; 2MSB of open file's extent
seqlha          := seqmap + $16         ; MSB of open file's extent
seqdah          := seqmap + $1D         ; MSB of starting LBA

atemp           := aws_tmp04            ; 2 bytes for general ZP pointer
work            := aws_tmp10            ; temporary area
wrkcat          := work + $02           ; load/exec/length/start sector in catalogue format
lodlo           := work + $02           ; LSB load address in OSFILE
lodhi           := work + $03           ; 3MSB load address in OSFILE
lbahi           := work + $08           ; MSB LBA in OSFILE
lbalo           := work + $09           ; LSB LBA in OSFILE
lenlo           := work + $06           ; LSB file length in OSFILE
lenhi           := work + $07           ; 2MSB file length in OSFILE

fastgb:
        jsr     gbpb_load_blkptr        ; set up pointer to user's OSGBPB block
        lda     gbpbv_table3,y          ; get microcode byte from table
        and     #$03                    ; test bit 1 = transfer data
        lsr     A                       ; set C=1 iff preserving PTR
        beq     chain                   ; if not a transfer then pass call downstream
        sty     acc                     ; else save call number
        ldy     #$0C                    ; 13 bytes to copy, $0C..$00:
copyl0:
        lda     (atemp),y               ; copy user's OSGBPB block
        sta     dosram,y                ; to workspace
        dey                             ; loop until 13 bytes copied
        bpl     copyl0
        tay                             ; file handle to Y
        ldx     #$03                    ; 4 bytes to copy, $03..$00:
initl:
        lda     dosram+$05,x            ; copy L in OSGBPB block
        sta     ltemp0,x                ; to working L
        dex                             ; loop until 4 bytes copied
        bpl     initl
        lda     dosram+$09              ; get LSB of P, initial PTR to use for transfer
        bcc     dcptr                   ; if calls 1 or 3 then use P; else 2 or 4 use current PTR
        tya                             ; convert file handle to workspace pointer
        jsr     a_rolx5                 ; (file handle validated later)
        tay                             ; to Y as offset
        lda     seqpl,y                 ; get LSB of file pointer PTR
        clc                             ; clear carry flag for two's complement
dcptr:
        eor     #$FF                    ; take two's complement
        adc     #$01                    ; =no. bytes from start of transfer to a page boundary
        ldy     #$FC                    ; reverse counter, 4 bytes to set:
hdrext:
        ; do header/extender OSGBPB call
        sta     dosram+$05-$FC,y        ; replace L field with number of bytes to move
        lda     #$00                    ; set MSB,2MSB,(3MSB) of user's L to zero
        iny                             ; increment offset
        bne     hdrext                  ; loop until 3 (4) bytes of L replaced
        jsr     subwk                   ; subtract L from working L
        bcc     trailr                  ; if underflow then within one sector, do trailer call
        bne     align                   ; else if remaining working L >= 256 then enter loop
trailr:
        ;else combine header/extender with trailer:
        jsr     addtol                  ; add working L to L
drain:
        lda     #<dosram                ; point to OSGBPB block in workspace
        sta     atemp+$00               ; -read user's block once
        lda     #>dosram                ; upgbpb will write it back once
        sta     atemp+$01
        ldy     acc                     ; restore call number
chain:
        jmp     upgbpb                  ; and pass call downstream

morfst:
        ; done a fast transfer, user's L = $00xxxx00
        lda     ltemp0+$03              ; get MSB of working L
        jsr     testl                   ; test MSB, 2MSB, 3MSB of working L
        bne     dofast                  ; if >= 256 then try another fast transfer
        sta     dosram+$06              ; else set user's L = 0
        sta     dosram+$07
        lda     ltemp0+$00              ; if 0 < working L < 256
        bne     trailr                  ; then do trailer call with L = working L
        clc                             ; else C=0, no bytes remaining:
fgbfin:
        ; working L reached zero or something went wrong:
        php                             ; save carry flag that says which
        jsr     addtol                  ; add remaining request to bytes not transferred
        plp                             ; restore carry flag returned from OSGBPB call
        jsr     gbpb_load_blkptr        ; set up pointer to user's OSGBPB block
        ldy     #$0C                    ; copy 13 bytes of OSGBPB control block
retnl:
        lda     dosram,y                ; from DFS workspace
        sta     (atemp),y               ; to user's address
        dey                             ; loop until 13 bytes copied
        bpl     retnl
        rts                             ; return C=0 OSGBPB succeeded/C=1 OSGBPB failed

setmax:
        ; set fast transfer request = maximum transfer size
        sta     dosram+$07              ; set MSB request = MSB maximum
        ora     dosram+$06
        bne     sectr1                  ; if maximum > 0 then transfer sectors
throw:
        ; working L >= 256, L = $00xxxx00, maximum = 0
        ldy     #$FD                    ; set user's L = 256
        lda     #$01
        bne     hdrext                  ; do extender OSGBPB call to extend file (always)

align:
        jsr     drain                   ; call OSGBPB on workspace control block.
                                        ; this validates the file handle, sets PTR from P,
                                        ; aligns it to a sector boundary, and sets L=0
        bcs     fgbfin                  ; return if call failed else continue transfer
dofast:
        ; working L >= 256, L = $00xxxx00, PTR on sector bdy
        ldx     ltemp0+$03              ; test working L - are there 16 MiB or more to move?
        beq     sclamp                  ; if not then move 1..65535 sectors
        ldx     #$FF                    ; else transfer first 65535 sectors of remainder
sclamp:
        txa
        ora     ltemp0+$02
        sta     dosram+$07              ; set MSB of transfer length = 2MSB of L
        txa
        ora     ltemp0+$01
        tax                             ; hold LSB of transfer length in X
        lda     dcby                    ; get channel workspace offset
        sec
        adc     acc                     ; add 1+call number, 2..5 to workspace offset
        eor     #$04                    ; bit 2 = 1 if writing
        and     #$E4                    ; if writing then point to allocation instead of EXT
        tay
        lda     seqlma,y                ; get 2MSB of channel EXT
        sec
        sbc     dosram+$0A              ; subtract 2MSB of PTR
        sta     dosram+$06              ; =LSB maximum transfer size
        lda     seqlha,y                ; get MSB of EXT
        sbc     dosram+$0B              ; subtract MSB of PTR = MSB maximum
        bcc     throw                   ; if maximum<0 throw back
        cmp     dosram+$07              ; else compare MSB maximum - MSB request
        bcc     setmax                  ; if maximum < request then request = maximum
        bne     sectr0                  ; if maximum > request then transfer sectors
        cpx     dosram+$06              ; else compare LSB request - LSB maximum
        bcs     setmax                  ; if request >= maximum then request = maximum
sectr0:
        ;transfer one or more sectors.
        stx     dosram+$06              ; x=request, hold in 3MSB of L
sectr1:
        ldy     dcby                      ; undo EXT/allocation fudge
        jsr     channel_set_dir_drive_get_cat_entry_yintch    ; ensure open file still in drive
        jsr     channel_buffer_to_disk_yintch                 ; ensure buffer up-to-date on disc L6
        lda     #$3F                      ; b7=0 buffer does not contain PTR, b6=0 buffer not changed
        sta     seqdah,y                  ; set buffer LBA out of range to force re-reading
        jsr     channel_flags_clear_bits  ; clear b7,b6 of channel flags
        lda     dosram+$01                ; copy OSGBPB transfer address
        sta     lodlo                     ; to load address in OSFILE block
        lda     dosram+$02
        sta     lodhi
        lda     dosram+$03
        sta     ldlow+$02
        lda     dosram+$04
        sta     ldlow+$03
        lda     seqloc,y                ; get LSB LBA of start of open file
        clc
        adc     dosram+$0A              ; add 2MSB of PTR
        sta     lbalo                   ; store LSB target LBA in OSFILE block
        lda     seqlh,y                 ; get MSB LBA
        adc     dosram+$0B              ; add MSB of PTR
        and     #$03                    ; mask MSB of target LBA
        sta     lbahi                   ; store MSB target LBA in OSFILE block
        lda     #$00                    ; clear LSB file length in OSFILE block
        sta     lenlo
        lda     dosram+$06              ; copy transfer length
        sta     lenhi                   ; to file length in OSFILE block
        lda     dosram+$07              ; get MSB transfer length
        jsr     a_rolx4                 ; shift b1..b0 to b5..b4
        ora     lbahi                   ; combine with LSB target LBA
        sta     wrkcat+$06              ; pack into last byte of OSFILE block
        lda     acc                     ; (L8826 needs load+exec unpacked, but length packed)
        inc     seqsem                  ; set *SPOOL/*EXEC critical flag (now $00)
        jsr     docmd                   ; transfer ordinary file L5
        dec     seqsem                  ; clear *SPOOL/*EXEC critical flag (now $FF)
        jsr     subwk                   ; subtract amount transferred from working L
        ldy     dosram+$06              ; get and hold LSB number of sectors transferred
        tya
        clc                             ; add to OSGBPB address field
        adc     dosram+$02
        sta     dosram+$02
        ldx     dosram+$07              ; get and hold MSB number of sectors transferred
        txa
        adc     dosram+$03              ; add to OSGBPB address field
        sta     dosram+$03
        bcc     updp                    ; carry out to high byte
        inc     dosram+$04
updp:
        tya                             ; set A=LSB transfer size in sectors
        ldy     dcby                    ; set Y=channel workspace offset
        clc                             ; add to open file's pointer
        adc     seqpm,y
        sta     seqpm,y                 ; update PTR
        sta     dosram+$0A              ; update OSGBPB control block in workspace
        txa                             ; add MSB transfer size to MSB PTR
        adc     seqph,y
        sta     seqph,y
        sta     dosram+$0B              ; (MSB OSGBPB P field cleared by upgbpb)
        tya
        jsr     cmp_ptr_ext             ; compare PTR - EXT
        bcc     doneit                  ; if file not extended then loop
        beq     doneit                  ; if PTR = EXT, at EOF then loop
        				; else PTR > EXT only possible if writing
        jsr     updext                  ; clamp PTR to 0..EXT by raising EXT
doneit:
        jmp     morfst                  ; loop to transfer more sectors

subwk:
        ; Subtract L from working L
        sec                             ; set carry flag for subtract
        ldx     #$FC                    ; reverse counter, 4 bytes to subtract
subwkl:
        lda     ltemp0-$FC,x            ; get byte of working L
        sbc     dosram+$05-$FC,x        ; subtract byte of L in OSGBPB block
        sta     ltemp0-$FC,x            ; update byte of working L
        inx                             ; loop until 4 bytes updated:
        bne subwkl
testl:
        ; Test whether working L >= 256
        ora     ltemp0+$02              ; a=MSB, OR with 2MSB
        ora     ltemp0+$01              ; or with 3MSB
        rts                             ; return Z=1 iff working L < 256

addtol:
        ; add working L to L in OSGBPB block
        clc                             ; clear carry flag for add
        ldx     #$FC                    ; reverse counter, 4 bytes to add:
addl:
        lda     ltemp0-$FC,x            ; get byte of working L
        adc     dosram+$05-$FC,x        ; add to byte of L in OSGBPB block
        sta     dosram+$05-$FC,x        ; update byte of L
        inx                             ; loop until 4 bytes added
        bne     addl
        rts

docmd:
        cmp     #$03
        bcc     dowrcmd
dordcmd:
        jmp     load_mem_block          ; Commands 3/4 as reads
dowrcmd:
        jmp     save_mem_block          ; Command 1/2 are writes


; originally called gbpb_wordB4_word107D, this loads the block parameter pointer into ZP location
gbpb_load_blkptr:
	lda     fuji_gbpbv_blk_save_ptr
	sta     atemp
	lda     fuji_gbpbv_blk_save_ptr+1
	sta     atemp
	rts
