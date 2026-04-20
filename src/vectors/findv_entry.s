; FINDV_ENTRY - File Find Vector
; Handles OSFIND calls for opening/closing files
; Translated from MMFS mmfs100.asm lines 4662-4854

        .export channel_get_cat_entry_yintch
        .export channel_set_dir_drive_yintch
        .export check_file_exists
        .export check_file_not_locked
        .export check_file_not_locked_or_open_y
        .export check_file_not_open_y
        .export check_for_disk_change
        .export close_all_files
        .export close_files_yhandle
        .export close_spool_exec_files
        .export cmd_fs_close
        .export err_file_locked
        .export err_file_open
        .export findv_entry
        .export setup_channel_info_block_yintch
        .export channel_set_dir_drive_get_cat_entry_yintch

        .export findv_createfile
        .export findv_filefound
        .export findv_openchannel
        .export findv_openfile
        .export findv_readorupdate
        .export close_file_yintch
        .export close_files_yhandle
        .export close_file_buftodisk

        .export calling_createfile
        .export chklock_exit

        .import read_fspba_find_cat_entry
        .import a_rolx4
        .import a_rolx5
        .import a_rorx4and3
        .import a_rorx5
        .import channel_buffer_to_disk_yhandle
        .import channel_buffer_to_disk_yintch
        .import check_channel_yhndl_exyintch
        .import create_file_fsp
        .import err_disk
        .import get_cat_firstentry80_fname
        .import get_cat_firstentry80
        .import is_hndlin_use_yintch
        .import load_cur_drv_cat2
        .import parameter_fsp
        .import print_hex
        .import print_newline
        .import print_string
        .import dump_memory_block
        .import read_fspba_reset
        .import remember_axy
        .import remember_xy_only
        .import report_error_cb
        .import save_cat_to_disk
        .import set_current_drive_adrive

        .include "fujinet.inc"

        .segment "CODE"

close_spool_exec_files:
        lda     #$77
        jmp     OSBYTE

cmd_fs_close:
close_all_files_osbyte77:
        jsr     close_spool_exec_files

close_all_files:
        lda     #$00

@close_all_files_loop:
        clc
        adc     #$20
        beq     close_all_files_exit
        tay
        jsr     close_file_yintch
        bne     @close_all_files_loop

channel_set_dir_drive_get_cat_entry_yintch:
        jsr     channel_set_dir_drive_yintch
channel_get_cat_entry_yintch:
        ldx     #$06
@channel_get_cat_loop:
        ; copy the name, which is interweved with attribs at fuji_channel_start
        lda     fuji_ch_name7,y         ; copy filename from channel info to C5
        sta     pws_tmp05,x
        dey
        dey
        dex
        bpl     @channel_get_cat_loop
        jsr     get_cat_firstentry80_fname
        bcc     err_disk_changed
        sty     fuji_cat_file_offset
        ldy     fuji_intch

; an RTS reachable from earlier blocks
close_all_files_exit:
chk_dsk_change_exit:
        rts

channel_set_dir_drive_yintch:
        lda     fuji_ch_dir,y
        and     #$7F
        sta     directory_param
        lda     fuji_ch_flg,y
        jmp     set_current_drive_adrive

check_for_disk_change:
        jsr     remember_axy
        lda     dfs_cat_cycle
        jsr     load_cur_drv_cat2
        cmp     dfs_cat_cycle
        beq     chk_dsk_change_exit

err_disk_changed:
        jsr     err_disk
        .byte   $C8
        .byte   "changed",0

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; FINDV_ENTRY - File Find Vector  
; Handles OSFIND calls for opening/closing files
;
; On entry,
;   The accumulator specifies the operation to be performed:
;
; If A is zero, a file is to be closed:
;   Y contains the handle for the file to be closed.
;   If Y=0, all open files are to be closed.
;
; If A is non zero, a file is to be opened:
;   X and Y point to the file name.
;   (X=low-byte, Y=high-byte)
;   The file name is terminated by carriage return (&0D).
;   The accumulator can take the following values:
;     &40, a file is to be opened for input only.
;     &80, a file is to be opened for output only.
;     &C0, a file is to be opened for update (random access).
; When opening a file for output only, an attempt is made to
; delete the file before opening.
; 
; On exit,
;   X and Y are preserved.
;   A is preserved on closing, and on opening contains the
;   file handle assigned to the file. If A=0 on exit, the file
;   could not be opened.
;   C, N, V and Z are undefined.
;   Interrupt state is preserved, but may be enabled during
;   the call.
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

findv_entry:

        and     #$C0                    ; Bit 7=open for output, Bit 6=open for input
        bne     findv_openfile          ; If opening a file
        jsr     remember_axy
        ; fall through to close files

; Close files by handle
; Y = file handle to close
close_files_yhandle:
        tya
        beq     close_all_files_osbyte77
        jsr     check_channel_yhndl_exyintch

close_file_yintch:
        pha
        jsr     is_hndlin_use_yintch
        bcs     close_file_exit
        lda     fuji_ch_bitmask,y
        eor     #$FF
        and     fuji_open_channels
        sta     fuji_open_channels
        lda     fuji_ch_flg,y
        and     #$60
        beq     close_file_exit
        jsr     channel_set_dir_drive_get_cat_entry_yintch
        lda     fuji_ch_flg,y
        and     #$20
        beq     close_file_buftodisk
        ldx     fuji_cat_file_offset
        lda     fuji_ch_ext_low,y
        sta     dfs_cat_file_size,x
        lda     fuji_ch_ext_mid,y
        sta     dfs_cat_file_size+1,x
        lda     fuji_ch_ext_hi,y
        jsr     a_rolx4
        eor     dfs_cat_file_op,x       ; mixed byte
        and     #$30
        eor     dfs_cat_file_op,x
        sta     dfs_cat_file_op,x
        jsr     save_cat_to_disk
        ldy     fuji_intch
close_file_buftodisk:
        jsr     channel_buffer_to_disk_yintch   ; CRITICAL FIX: Y=intch, not handle!
close_file_exit:
        ldx     fuji_saved_x
        pla
        rts

findv_openfile:
        jsr     remember_xy_only        ; Save X, Y as A will be returned
        stx     aws_tmp10               ; YX=Location of filename (MMFS: STX &BA)
        sty     aws_tmp11               ; (MMFS: STY &BB)
        sta     aws_tmp04               ; A=Operation
        bit     aws_tmp04
        php                             ; Save flags
        jsr     read_fspba_reset        ; Copies file name to fuji_filename_buffer (padding to 64 spaces), and to pws_tmp05-pws_tmp11
        jsr     parameter_fsp           ; puts $FF into wild star and wild hash
        jsr     get_cat_firstentry80
        bcs     findv_filefound         ; If file found
        lda     #$00
        plp
calling_createfile:
        bvc     findv_createfile        ; If not read only = write only
        ; A=0=file not found
        rts                             ; EXIT

findv_createfile:
        php                             ; Clear data
        ; A=0 BC-C3=0
        ldx     #$07                    ; 1074-107B=0
findv_loop1:
        sta     aws_tmp12,x
        sta     fuji_filev_hi_addr_buf,x
        dex
        bpl     findv_loop1
        dec     aws_tmp14               ; aws_tmp14 = $FF
        dec     aws_tmp15               ; aws_tmp15 = $FF
        dec     fuji_filev_exec_hi
        dec     fuji_filev_exec_hi+1
.ifdef FUJINET_INTERFACE_DUMMY
        ; DUMMY DISK FIX: Create zero-length files instead of pre-allocating 64 sectors
        ; Our RAM disk (~9 free sectors) can't fit multiple 64-sector files
        ; Files grow dynamically via bp_extendby100/bp_extendtogap as data is written
        lda     #$00
.else
        ; REAL DISK: Pre-allocate 64 sectors ($4000 bytes) as MMFS does
        lda     #$40
.endif
        sta     pws_tmp03               ; End address = A * 256
        jsr     create_file_fsp         ; Creates file with requested size
findv_filefound:
        plp                             ; in case another file created
        php
        bvs     findv_readorupdate      ; If opened for read or update
        jsr     check_file_not_locked_y ; If locked report error
findv_readorupdate:
        jsr     is_file_open_yoffset    ; Exits with Y=intch, A=flag, C=0 if didn't get a channel
        bcc     findv_openchannel       ; If file not open
findv_loop2:
        lda     fuji_ch_name7,y
        bpl     err_file_open           ; If already opened for writing
        plp
        php
        bmi     err_file_open           ; If opening again to write
        jsr     is_file_open_continue   ; ** File can only be opened  **
        bcs     findv_loop2             ; ** once if being written to **
findv_openchannel:
        ldy     fuji_intch              ; Y=intch, it's 0 if nothing was found
        bne     setup_channel_info_block_yintch

err_toomanyfilesopen:
        jsr     report_error_cb
        .byte   $C0
        .byte   "Too many open",0

err_file_open:
        jsr     report_error_cb
        .byte   $C2
        .byte   "Open",0

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; SetupChannelInfoBlock_Yintch
; Sets up channel information block for opened file
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

setup_channel_info_block_yintch:
        lda     #$08
        sta     fuji_channel_scratch    ; just used as a loop counter. No significance to it otherwise.
@chnlblock_loop1:
        lda     dfs_cat_file_s0_start,x ; Copy filename sector (name + dir)
        sta     fuji_channel_start,y    ; to channel info block
        iny
        lda     dfs_cat_file_s1_start,x ; Copy file details sector (load, exec, size, mixed, start sector)
        sta     fuji_channel_start,y
        iny
        inx
        dec     fuji_channel_scratch
        bne     @chnlblock_loop1

        ldx     #$10
        lda     #$00                    ; Clear rest of block, i.e. $1100 + $20 * channel number + $10 ... + $1F
@chnlblock_loop2:
        sta     fuji_channel_start,y
        iny
        dex
        bne     @chnlblock_loop2

        lda     fuji_intch              ; A=intch (3 high bits)
        tay
        jsr     a_rorx5                 ; scale down to 1-7, C will be 0
        adc     #$11                    ; convert to $12 to $18 (although channel is only 1-5, so page becomes $12 to $16)
        sta     fuji_ch_buf_page,y      ; Buffer page high address for this block, i.e. the memory page we give OS to use for file data
        lda     fuji_channel_flag_bit
        sta     fuji_ch_bitmask,y       ; Mask bit
        ora     fuji_open_channels
        sta     fuji_open_channels      ; Set bit in open flag byte

        lda     fuji_ch_1109,y          ; Length0
        adc     #$FF                    ; If Length0>0 C=1
        lda     fuji_ch_110B,y          ; Length1
        adc     #$00
        sta     fuji_ch_1119,y          ; Sector count
        lda     fuji_ch_op,y            ; Mixed byte
        ora     #$0F
        adc     #$00                    ; Add carry flag
        jsr     a_rorx4and3             ; Length2
        sta     fuji_ch_111A,y
        plp
        bvc     chnlblock_setbit5       ; If not read = write
        bmi     chnlblock_setext        ; If updating
        lda     #$80                    ; Set Bit7 = Read Only
        ora     fuji_ch_name7,y
        sta     fuji_ch_name7,y
chnlblock_setext:
        lda     fuji_ch_1109,y          ; EXTENT=file length
        sta     fuji_ch_ext_low,y
        lda     fuji_ch_110B,y
        sta     fuji_ch_ext_mid,y
        lda     fuji_ch_op,y
        jsr     a_rorx4and3
        sta     fuji_ch_ext_hi,y
chnlblock_cont:
        lda     current_drv              ; Set drive
        ora     fuji_ch_flg,y
        sta     fuji_ch_flg,y
        tya                             ; convert intch to handle
        jsr     a_rorx5
        ora     #filehndl               ; &10
        rts                             ; RETURN A=handle

chnlblock_setbit5:
        lda     #$20                    ; Set Bit5 = Update cat file len
        sta     fuji_ch_flg,y           ; when channel closed
        bne     chnlblock_cont          ; always

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; Helper functions
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

check_file_not_locked:
        jsr     read_fspba_find_cat_entry
        bcc     exit_calling_subroutine

check_file_not_locked_y:
        lda     dfs_cat_file_dir,y
        bpl     chklock_exit

err_file_locked:
        jsr     report_error_cb
        .byte   $C3
        .byte   "Locked",0

check_file_not_locked_or_open_y:
        jsr     check_file_not_locked_y

check_file_not_open_y:
        jsr     remember_axy
        jsr     is_file_open_yoffset
        bcc     chklock_exit
        jmp     err_file_open

check_file_exists:
        jsr     read_fspba_find_cat_entry
        bcs     chklock_exit

exit_calling_subroutine:
        pla
        pla
        lda     #$00

chklock_exit:
        rts


is_file_open_continue:
        txa
        pha
        jmp     fop_nothisfile

; find either a matching file by name and same drive as an open channel
; or the lowest channel that is not open.

is_file_open_yoffset:
        ; Check if file is already open and allocate channel if not
        ; Based on MMFS IsFileOpen_Yoffset (lines 4855-4906)
        lda     #$00
        sta     fuji_intch              ; start at intch = 0, thus if there are no channels available, we exit with intch = 0

        lda     #$08
        sta     aws_tmp05               ; Channel flag bit %0000 1000, this is channel 5 (to start) mask for the open channels

        tya                             ; move the Y offset into X
        tax                             ; X = cat offset
        
        ; Y = intch, 1010 0000 is "int channel 5" (start from channel offset &A0).
        ; Channel offsets from $1100 are each $20 bytes long, with A0 being channel 5.
        ; This is very clever. It's also the high 3 bits as an index, A0 = [101]0 0000, which is [5] in binary
        ldy     #$A0
fop_main_loop:
        sty     aws_tmp03               ; keep intch in tmp03
        txa                             ; save X
        pha

        lda     #$08
        sta     aws_tmp02               ; name matching counter

        lda     aws_tmp05               ; A = flag bit. 1000 0000 => channel 1, 0100 0000 => channel 2, etc.
        bit     fuji_open_channels      ; A (starts with 0000 1000) AND fuji_open_channels tells us if that channel is currently open if the mask matches
        beq     fop_channelnotopen      ; channel is not open, need to keep looking, but mark this as potentially the lowest channel slot we can use

        lda     fuji_ch_flg,y           ; read drive of current open channel
        eor     current_drv             ; if it matches, lower 2 bits will be 00
        and     #$03
        bne     fop_nothisfile          ; Didn't match the drive, so can't be a match, jump and check next location

        ; we have an open channel with a matching drive, check if this also matches on filename
fop_cmpfn_loop:
        lda     dfs_cat_file_name,x     ; Check the Catalog information against the channel info's file name
        eor     fuji_channel_start,y
        and     #$7F                    ; are all 7 lower bits matching?
        bne     fop_nothisfile          ; names didn't match (ignoring high bit)

        inx                             ; the catalog data indexed by X is contiguous
        iny
        iny                             ; channel info names are interwoven every other byte, so need to skip 2 at a time
        dec     aws_tmp02               ; counter for whole name match
        bne     fop_cmpfn_loop          ; potential match still, keep looping...

        ; if we get here, we found a match
        sec
        bcs     fop_matchifcset         ; always

        ; this will be a not-this-file scenario too.
        ; during looping we either don't match anything, so channel 1 is finally picked, or we match something higher up.
        ; extremely efficient way of ensuring when we exit we get the lowest index file open, or we get the one matching the name,
        ; so if nothing is open, eventually this would return INTCH = 20 (channel 1), and flag_bit = %1000 0000, as the next loop would exit due to flag being = 0
fop_channelnotopen:
        sty     fuji_intch              ; save the attempted intch, it's allocated to a new channel if no name matches
        sta     fuji_channel_flag_bit   ; store the Channel Flag Bit Mask, it indicates the channel number where %1000 0000 would be channel 1, %0100 0000 would be channel 2, ...
fop_nothisfile:
        sec
        lda     aws_tmp03
        sbc     #$20
        sta     aws_tmp03               ; intch=intch-&20, which is the channel info block size, so A0 -> 80 -> 60 -> 40 -> 20 are 5 channel offsets
        asl     aws_tmp05               ; flag bit << 1, this starts as %0000 1000 for channel 5, and moves left until a channel is found, or becomes 0 and exit
        clc
fop_matchifcset:
        pla                             ; restore X
        tax
        ldy     aws_tmp03               ; Y=intch
        lda     aws_tmp05               ; A=flag bit
        bcs     fop_exit                ; do we need to loop again? C was set if we found matching file name
        ; eventually, the A value (channel flag bit) becomes 00 if no channels are available via ASL above.
        ; we've already checked if C = 0, so if A becomes 0 this exits function with A=0, C=0, 
        bne     fop_main_loop           ; If flag bit <> 0
fop_exit:
        rts                             ; Exit: A=flag (1000 000 for channel 1, 0100 0000 for channel 2, etc) Y=intch if slot available/found, C=1 if it got a channel

