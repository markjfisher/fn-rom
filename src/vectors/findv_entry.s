; FINDV_ENTRY - File Find Vector
; Handles OSFIND calls for opening/closing files
; Translated from MMFS mmfs100.asm lines 4662-4854

        .export channel_get_cat_entry_yintch
        .export channel_set_dir_drive_yintch
        .export check_file_exists
        .export check_file_not_locked
        .export check_file_not_locked_or_open_y
        .export check_file_not_open_y
        .export close_all_files
        .export close_files_yhandle
        .export close_spool_exec_files
        .export cmd_fs_close
        .export err_file_locked
        .export err_file_open
        .export findv_entry
        .export setup_channel_info_block_yintch

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
        sta     DirectoryParam
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
.ifdef FN_DEBUG_CLOSE_FILE
        lda     #$CC
        sta     $5006                   ; Debug: CLOSE buffer flush marker
        lda     fuji_ch_flg,y
        sta     $5007                   ; Debug: flags at CLOSE before buffer flush
.endif
        jsr     channel_buffer_to_disk_yintch   ; CRITICAL FIX: Y=intch, not handle!
close_file_exit:
        ldx     fuji_saved_x
        pla
        rts

findv_openfile:
        jsr     remember_xy_only            ; Save A, X, Y  
        stx     aws_tmp10               ; YX=Location of filename (MMFS: STX &BA)
        sty     aws_tmp11               ; (MMFS: STY &BB)
        sta     aws_tmp04               ; A=Operation
        bit     aws_tmp04
        php                             ; Save flags
        jsr     read_fspba_reset
        jsr     parameter_fsp
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
        sta     fuji_buf_1074,x
        dex
        bpl     findv_loop1
        dec     aws_tmp14               ; aws_tmp14 = $FF
        dec     aws_tmp15               ; aws_tmp15 = $FF
        dec     fuji_buf_1076
        dec     fuji_buf_1077
.ifdef FUJINET_INTERFACE_DUMMY
        ; DUMMY DISK FIX: Create zero-length files instead of pre-allocating 64 sectors
        ; Our RAM disk (~9 free sectors) can't fit multiple 64-sector files
        ; Files grow dynamically via bp_extendby100/bp_extendtogap as data is written
        lda     #$00
        sta     pws_tmp03               ; End address = &0000 (zero-length file)
.else
        ; REAL DISK: Pre-allocate 64 sectors ($4000 bytes) as MMFS does
        lda     #$40
        sta     pws_tmp03               ; End address = &4000
.endif
        jsr     create_file_fsp         ; Creates file with requested size
findv_filefound:
        ; sty     fuji_cat_file_offset    ; Store catalog offset for later use
        plp                             ; in case another file created
        php
        bvs     findv_readorupdate      ; If opened for read or update
        jsr     check_file_not_locked_y ; If locked report error
findv_readorupdate:
        jsr     is_file_open_yoffset    ; Exits with Y=intch, A=flag
        bcc     findv_openchannel       ; If file not open
findv_loop2:
        lda     fuji_ch_name7,y
        bpl     err_file_open            ; If already opened for writing
        plp
        php
        bmi     err_file_open            ; If opening again to write
        jsr     is_file_open_continue   ; ** File can only be opened  **
        bcs     findv_loop2             ; ** once if being written to **
findv_openchannel:
        ldy     fuji_intch              ; Y=intch
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
; .ifdef FN_DEBUG
;         ; Preserve all registers during debug
;         php
;         pha
;         txa
;         pha
;         tya
;         pha

;         jsr     print_string
;         .byte   "Channel setup: fuji_cat_file_offset=$"
;         nop
;         lda     fuji_cat_file_offset
;         jsr     print_hex
;         jsr     print_string
;         .byte   " X=$"
;         nop
;         txa
;         jsr     print_hex
;         jsr     print_string
;         .byte   " Y=$"
;         nop
;         tya
;         jsr     print_hex
;         jsr     print_newline

;         ; Dump catalog data where we expect HELLO file info
;         jsr     print_string
;         .byte   "Catalog s0 at $0E10: "
;         nop
;         lda     #$10            ; $0E10 = $0E08 + 8 (HELLO offset)
;         ldx     #$0E
;         ldy     #$08
;         jsr     dump_memory_block

;         jsr     print_string
;         .byte   "Catalog s1 at $0F10: "
;         nop
;         lda     #$10            ; $0F10 = $0F08 + 8 (HELLO offset)  
;         ldx     #$0F
;         ldy     #$08
;         jsr     dump_memory_block

;         ; Restore all registers
;         pla
;         tay
;         pla
;         tax
;         pla
;         plp
; .endif

        lda     #$08
        sta     fuji_channel_block_size
chnlblock_loop1:
        lda     dfs_cat_file_s0_start,x         ; Copy filename sector (name + dir)
        sta     fuji_channel_start,y            ; to channel info block
        iny
        lda     dfs_cat_file_s1_start,x         ; Copy file details sector (load, exec, size, mixed, start sector)
        sta     fuji_channel_start,y
        iny
        inx
        dec     fuji_channel_block_size
        bne     chnlblock_loop1

        ldx     #$10
        lda     #$00                    ; Clear rest of block
chnlblock_loop2:
        sta     fuji_channel_start,y
        iny
        dex
        bne     chnlblock_loop2

        lda     fuji_intch              ; A=intch
        tay
        jsr     a_rorx5
        adc     #$11                    ; Buffer page
        sta     fuji_ch_buf_page,y      ; Buffer page
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
        lda     CurrentDrv              ; Set drive
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

is_file_open_yoffset:
        ; Check if file is already open and allocate channel if not
        ; Based on MMFS IsFileOpen_Yoffset (lines 4855-4906)
        lda     #$00
        sta     fuji_intch              ; MA+&10C2 = 0
        lda     #$08
        sta     aws_tmp05               ; &B5 = Channel flag bit
        tya
        tax                             ; X = cat offset
        ldy     #$A0                    ; Y = intch (start from channel &A0)
fop_main_loop:
        sty     aws_tmp03               ; &B3 = intch
        txa                             ; save X
        pha
        lda     #$08
        sta     aws_tmp02               ; &B2 = cmpfn_loop counter
        lda     aws_tmp05               ; A = flag bit
        bit     fuji_open_channels      ; MA+&10C0
        beq     fop_channelnotopen      ; If channel not open
        lda     fuji_ch_flg,y           ; MA+&1117,Y
        eor     CurrentDrv
        and     #$03
        bne     fop_nothisfile          ; If not current drv?
fop_cmpfn_loop:
        lda     dfs_cat_file_name,x             ; MA+&0E08,X - Compare filename
        eor     fuji_channel_start,y      ; MA+&1100,Y
        and     #$7F
        bne     fop_nothisfile
        inx
        iny
        iny
        dec     aws_tmp02               ; &B2
        bne     fop_cmpfn_loop
        sec
        bcs     fop_matchifcset         ; always
fop_channelnotopen:
        sty     fuji_intch              ; MA+&10C2 = Y=intch = allocated to new channel
        sta     fuji_channel_flag_bit   ; MA+&10C1 = A=Channel Flag Bit
fop_nothisfile:
        sec
        lda     aws_tmp03               ; &B3
        sbc     #$20
        sta     aws_tmp03               ; intch=intch-&20
        asl     aws_tmp05               ; flag bit << 1
        clc
fop_matchifcset:
        pla                             ; restore X
        tax
        ldy     aws_tmp03               ; Y=intch
        lda     aws_tmp05               ; A=flag bit
        bcs     fop_exit
        bne     fop_main_loop           ; If flag bit <> 0
fop_exit:
        rts                             ; Exit: A=flag Y=intch

