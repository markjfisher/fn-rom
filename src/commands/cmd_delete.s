; *DELETE command - Delete a file
; Translated from MMFS mmfs100.asm lines 1886-1895

        .export cmd_fs_delete

        .import parameter_fsp
        .import param_syntaxerrorifnull_getcatentry_fsptxtp
        .import prt_info_msg_yoffset
        .import delete_cat_entry_yfileoffset
        .import save_cat_to_disk

        .segment "CODE"

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; cmd_fs_delete - *DELETE command
; Deletes a named file from the catalog
; Translated from MMFS lines 1886-1895 (CMD_DELETE)
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

cmd_fs_delete:
        ; Get filename parameter from command line
        jsr     parameter_fsp
        
        ; Find file in catalog (throws error if not found or null)
        jsr     param_syntaxerrorifnull_getcatentry_fsptxtp
        
        ; Print "filename" message
        jsr     prt_info_msg_yoffset
        
        ; Delete the catalog entry (checks if locked/open)
        jsr     delete_cat_entry_yfileoffset
        
        ; Save updated catalog to disk
        jmp     save_cat_to_disk

