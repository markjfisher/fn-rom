; *COPY command implementation
; Translated from MMFS CMD_COPY (lines 5944-6028) and related functions
; Syntax: *COPY <source drive> <dest drive> <afsp>

        .export cmd_fs_copy
        .export get_copy_data_drives
        .export copy_data_block
        .export cd_swapvars

        .import parameter_afsp
        .import param_syntaxerrorifnull
        .import read_fsp_text_pointer
        .import get_cat_entry
        .import prt_info_msg_yoffset
        .import get_cat_nextentry
        .import param_drive_no_syntax
        .import err_bad_drive
        .import print_string
        .import print_hex
        .import print_newline
        .import create_file_3
        .import load_mem_block
        .import save_mem_block
        .import set_load_addr_to_host
        .import load_cur_drv_cat2
        .import a_rorx4and3
        .import OSBYTE

        .include "fujinet.inc"

        .segment "CODE"

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; cmd_fs_copy - Handle *COPY command
; Translated from MMFS CMD_COPY (lines 5944-6028)
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

cmd_fs_copy:
        jsr     parameter_afsp          ; Set up wildcard characters
        jsr     get_copy_data_drives    ; Get source/dest drives
        jsr     param_syntaxerrorifnull ; Error if no parameter
        jsr     read_fsp_text_pointer   ; Read filename to buffer

        ; Source
        lda     fuji_source_drive       ; Already range-checked drive number
        sta     current_drv
        jsr     get_cat_entry           ; Check if source file exists
                                        ; Returns Y and aws_tmp06=Y+8

@copy_loop1:
        lda     directory_param
        pha
        lda     aws_tmp06               ; Set up by get_cat_entry pointer to next file
        pha
        jsr     prt_info_msg_yoffset
        ldx     #$00

@copy_loop2:
        lda     dfs_cat_file_name,y     ; Source catalog $0E08,Y
        sta     pws_tmp05,x             ; Store filename $C5-$CC
        sta     fuji_buf_1050,x         ; Put filename in buffer $1050,X
        lda     dfs_cat_file_load_addr,y ; Source catalog $0F08,Y
        sta     aws_tmp11,x             ; Load address, exec ... $BB-$C2
        sta     fuji_buf_1047,x         ; $1047,X
        inx
        iny
        cpx     #$08
        bne     @copy_loop2

        ; Create file in destination catalogue
        jsr     cd_swapvars             ; Swap variables
        ; Filename that was at $1050 is now $C5
        ; File attributes that were at $1047 now at $BC

        ; Destination
        lda     fuji_dest_drive         ; Destination drive
        jsr     create_file_3           ; Saves cat. (pass in Drive)

        lda     pws_tmp02               ; Remember sector
        and     #$03
        pha
        lda     pws_tmp03
        pha
        jsr     cd_swapvars             ; Back to source
        pla                             ; Next free sec on dest
        sta     pws_tmp08
        pla
        sta     pws_tmp09

        lda     pws_tmp01               ; Get high bits
        jsr     a_rorx4and3             ; Isolate length top two bits (bits 16 and 17)
        tax
        lda     aws_tmp15               ; Load bits 7-0 of length
        cmp     #$01                    ; C = 1 if file includes partial sector
                                        ; Round up number of sectors required
        lda     pws_tmp00               ; Load bits 15-8 of length
        adc     #$00
        sta     pws_tmp04
        txa
        adc     #$00
        sta     pws_tmp05

        lda     pws_tmp02               ; Get start sector bits 7-0
        sta     pws_tmp06
        lda     pws_tmp01               ; Get start sector bits 9-8
        and     #$03
        sta     pws_tmp07

        jsr     copy_data_block

        ; Source
        lda     fuji_source_drive
        sta     current_drv
        jsr     load_cur_drv_cat2
        pla
        sta     aws_tmp06               ; Restore next file pointer
        pla
        sta     directory_param
        jsr     get_cat_nextentry
        bcs     @copy_loop1
        rts

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; cd_swapvars - Swap variables between source and destination
; Translated from MMFS cd_swapvars (lines 6031-6042)
; Swaps $BA-$CB & $1045-$1056
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

cd_swapvars:
        ldx     #$11                    ; Swap $BA-$CB & $1045-$1056

@cd_swapvars_loop:
        ldy     fuji_buf_1045,x     ; $1045,X
        lda     aws_tmp10,x             ; $BA,X
        sty     aws_tmp10,x             ; $BA,X
        sta     fuji_buf_1045,x     ; $1045,X
        dex
        bpl     @cd_swapvars_loop
        rts

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; get_copy_data_drives - Get source and destination drives
; Translated from MMFS Get_CopyDATA_Drives (lines 5795-5821)
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

get_copy_data_drives:
        jsr     param_drive_no_syntax   ; Get drives & calc ram & msg
        sta     fuji_source_drive       ; Source drive
        jsr     param_drive_no_syntax
        sta     fuji_dest_drive         ; Destination drive

        cmp     fuji_source_drive
        beq     @baddrv                 ; Drives must be different!

        tya
        pha
        jsr     calc_ram                ; Calc ram available
        jsr     print_string            ; Copying from:
        .byte   "Copying from :", 0
        lda     fuji_source_drive
        jsr     print_hex
        jsr     print_string
        .byte   " to :", 0
        lda     fuji_dest_drive
        jsr     print_hex
        jsr     print_newline
        pla
        tay
        clc
        rts

@baddrv:
        jmp     err_bad_drive

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; calc_ram - Calculate amount of RAM available for buffer
; Translated from MMFS CalcRAM (lines 4420-4430)
; Calculates HIMEM - PAGE and stores in fuji_ram_buffer_size
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

calc_ram:
        lda     #$83
        jsr     OSBYTE                  ; YX=OSHWM (PAGE)
        sty     fuji_page
        lda     #$84
        jsr     OSBYTE                  ; YX=HIMEM
        tya
        sec
        sbc     fuji_page
        sta     fuji_ram_buffer_size    ; HIMEM page - OSHWM page
        rts

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; copy_data_block - Copy sectors from source to destination
; Translated from MMFS CopyDATABLOCK (lines 6045-6132)
; Entry:
;   $C4 $C5 = Size in sectors
;   $C6 $C7 = Start sector
;   $C8 $C9 = Destination sector
;   fuji_source_drive = source drive
;   fuji_dest_drive = destination drive
; ZP Usage:
;   $BC $BD = Start address of buffer
;   $C0 = Always zero (bytes in last sector)
;   $C1 = Number of sectors to copy limited by ram size
;   $C2 $C3 = First sector of current block to read or write
;   $C4 $C5 = Number of sectors left to copy
;   $C6 $C7 = Start source sector (local)
;   $C8 $C9 = Next free sector for destination (local)
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

copy_data_block:
        lda     #$00                    ; Move or copy sectors
        sta     aws_tmp12               ; Word $C4 = size of block
        sta     pws_tmp00
        lda     fuji_page               ; Buffer address (PAGE)
        sta     aws_tmp13
        beq     @cd_loopentry           ; Always

@cd_loop:
        ldy     pws_tmp04
        cpy     fuji_ram_buffer_size    ; Size of buffer (RAMBufferSize)
        lda     pws_tmp05
        sbc     #$00
        bcc     @cd_part                ; If size < size of buffer
        ldy     fuji_ram_buffer_size

@cd_part:
        sty     pws_tmp01               ; Number of sectors to copy in this pass

        lda     pws_tmp06               ; $C2/$C3 = Block start sector
        sta     pws_tmp03               ; Start sec = Word $C6
        lda     pws_tmp07
        sta     pws_tmp02

        lda     fuji_source_drive       ; Source drive
        sta     current_drv

        ; Source
        jsr     set_load_addr_to_host   ; $1074 = $1075 = 255
        jsr     load_mem_block            ; Pass in $BC $BD $C2 $C3, $C1 $C0

        lda     fuji_dest_drive         ; Destination drive
        sta     current_drv

        lda     pws_tmp08               ; $C2/$C3 = Block start sector
        sta     pws_tmp03               ; Start sec = Word $C8
        lda     pws_tmp09
        sta     pws_tmp02

        ; Destination
        jsr     set_load_addr_to_host   ; $1074 = $1075 = 255
        jsr     save_mem_block

        lda     pws_tmp01               ; Word $C8 += $C1
        clc                             ; Dest sector start
        adc     pws_tmp08
        sta     pws_tmp08
        bcc     @cd_inc1
        inc     pws_tmp09

@cd_inc1:
        lda     pws_tmp01               ; Word $C6 += $C1
        clc                             ; Source sector start
        adc     pws_tmp06
        sta     pws_tmp06
        bcc     @cd_inc2
        inc     pws_tmp07

@cd_inc2:
        sec                             ; Word $C4 -= $C1
        lda     pws_tmp04               ; Sector counter
        sbc     pws_tmp01
        sta     pws_tmp04
        bcs     @cd_loopentry
        dec     pws_tmp05

@cd_loopentry:
        lda     pws_tmp04
        ora     pws_tmp05
        bne     @cd_loop                ; If Word $C4 <> 0
        rts

