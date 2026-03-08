        .export cmd_fs_flist
        .export cmd_fs_fls

        .import err_bad
        .import fn_file_list_directory
        .import fn_file_resolve_path
        .import fuji_rx_buffer
        .import num_params
        .import param_get_string
        .import print_char
        .import print_newline
        .import print_space
        .import print_string
        .import set_user_flag_x

        .include "fujinet.inc"

        .segment "CODE"

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; cmd_fs_flist / cmd_fs_fls - Handle *FLIST and *FLS commands
;
; Supported forms:
;   *FLIST / *FLS
;       List the current canonical URI directory.
;
;   *FLIST <path> / *FLS <path>
;       Resolve <path> relative to the current selection, then list that target.
;
; FileDevice helper usage:
; - baseUriLen/baseUri are taken from fuji_current_fs_len/fuji_current_fs_uri
; - argLen/arg are taken from fuji_filename_buffer when a path is supplied
; - fn_file_resolve_path handles relative/canonical directory resolution
; - fn_file_list_directory issues the FileDevice ListDirectory request
;
; Protocol fields consumed from the ListDirectory response in fuji_rx_buffer:
; - payload byte 4-5  => returnedCount (u16 LE)
; - each entry then encodes:
;     u8  entryFlags  ; bit0=isDir
;     u8  nameLen
;     u8[] name
;     u64 sizeBytes
;     u64 modifiedUnixTime
; - this command prints the basename plus a simple <DIR>/F marker and skips the
;   16 bytes of size/time metadata per entry after advancing Y past the name
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

cmd_fs_flist:
cmd_fs_fls:
        rts

;         ; Count parameters first so we can distinguish the no-argument listing
;         ; form from the one-argument resolve-and-list form.
;         jsr     num_params
;         cmp     #$00
;         bne     @count_one_check
;         jmp     use_current_uri

; @count_one_check:
;         cmp     #$01
;         beq     @read_arg
;         jmp     bad_path

; @read_arg:

;         ; Read the requested path fragment into fuji_filename_buffer.
;         ; On success A returns the fragment length for aws_tmp05.
;         jsr     param_get_string
;         bcc     @param_bad
;         tax
;         beq     use_current_uri

;         lda     fuji_current_fs_len
;         bne     @have_base_uri
;         jmp     bad_directory

; @have_base_uri:

;         ; Prepare ResolvePath request inputs.
;         ; aws_tmp00/01 -> pointer to current canonical URI base
;         ; aws_tmp02    -> current URI length
;         ; aws_tmp03/04 -> pointer to requested path fragment buffer
;         ; aws_tmp05    -> requested path fragment length
;         txa
;         sta     aws_tmp05
;         lda     #<fuji_current_fs_uri
;         sta     aws_tmp00
;         lda     #>fuji_current_fs_uri
;         sta     aws_tmp01
;         lda     fuji_current_fs_len
;         sta     aws_tmp02
;         lda     #<fuji_filename_buffer
;         sta     aws_tmp03
;         lda     #>fuji_filename_buffer
;         sta     aws_tmp04

;         ; Delegate directory validation + canonicalization to FujiNet-NIO.
;         ; On success the helper refreshes the canonical URI buffers used below.
;         jsr     fn_file_resolve_path
;         bcc     @resolved_ok
;         jmp     bad_directory

; @param_bad:
;         jmp     bad_path

; @resolved_ok:
;         jmp     flist_issue_list

; use_current_uri:
;         ; The current URI must already be selected before *FLIST with no path.
;         lda     fuji_current_fs_len
;         beq     @no_current_uri
;         jmp     flist_issue_list
; @no_current_uri:
;         jmp     bad_directory

; flist_issue_list:
;         lda     fuji_current_fs_len
;         beq     @list_bad_directory
;         jmp     @issue_list

; @list_bad_directory:
;         jmp     bad_directory

; @issue_list:
;         ; Prepare ListDirectory request inputs.
;         ; aws_tmp00/01 -> URI pointer
;         ; aws_tmp02    -> URI length
;         ; aws_tmp03/04 -> startIndex = 0
;         ; aws_tmp05/06 -> maxEntries = 32
;         lda     #<fuji_current_fs_uri
;         sta     aws_tmp00
;         lda     #>fuji_current_fs_uri
;         sta     aws_tmp01
;         lda     fuji_current_fs_len
;         sta     aws_tmp02
;         lda     #$00
;         sta     aws_tmp03
;         sta     aws_tmp04
;         lda     #$20
;         sta     aws_tmp05
;         lda     #$00
;         sta     aws_tmp06

;         jsr     fn_file_list_directory
;         bcs     @list_failed
;         jmp     @list_ok

; @list_failed:
;         jmp     bad_directory

; @list_ok:
;         jsr     print_newline

;         ; Response payload byte 4/5 = returnedCount (u16 LE).
;         lda     fuji_rx_buffer+FN_HEADER_SIZE+1
;         sta     aws_tmp09
;         ldy     #FN_HEADER_SIZE+4
;         lda     fuji_rx_buffer,y
;         sta     aws_tmp06
;         iny
;         lda     fuji_rx_buffer,y
;         sta     aws_tmp07
;         iny

; @entry_loop:
;         lda     aws_tmp06
;         ora     aws_tmp07
;         beq     @done_ok

;         ; entryFlags (bit0=isDir)
;         lda     fuji_rx_buffer,y
;         sta     aws_tmp08
;         iny

;         ; nameLen
;         lda     fuji_rx_buffer,y
;         tax
;         iny

;         cpx     #$00
;         beq     @skip_empty_entry

; @name_loop:
;         cpx     #$00
;         beq     @after_name
;         lda     fuji_rx_buffer,y
;         jsr     print_char
;         iny
;         dex
;         bne     @name_loop

; @after_name:
;         jsr     print_space
;         lda     aws_tmp08
;         and     #$01
;         beq     @print_file_marker
;         jsr     print_string
;         .byte   "<DIR>", 0
;         jmp     @skip_metadata

; @print_file_marker:
;         lda     #'F'
;         jsr     print_char

; @skip_metadata:
;         ; Skip sizeBytes (8 bytes) and modifiedUnixTime (8 bytes).
;         tya
;         clc
;         adc     #$10
;         tay
;         jsr     print_newline
;         jmp     @dec_entry_count

; @skip_empty_entry:
;         ; Empty names are ignored in output but still consume metadata and count.
;         tya
;         clc
;         adc     #$10
;         tay

; @dec_entry_count:
;         ; Decrement returnedCount in aws_tmp06/07.
;         lda     aws_tmp06
;         bne     @dec_low
;         dec     aws_tmp07
; @dec_low:
;         dec     aws_tmp06
;         jmp     @entry_loop

; @done_ok:
;         lda     aws_tmp09
;         and     #$01
;         beq     @success
;         jsr     print_string
;         .byte   "...", 0
;         jsr     print_newline
; @success:
;         ldx     #$00
;         jmp     set_user_flag_x

; bad_directory:
;         jsr     err_bad
;         .byte   $CB
;         .byte   "directory", 0

; bad_path:
;         jsr     err_bad
;         .byte   $CB
;         .byte   "path", 0
