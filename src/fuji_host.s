; FujiNet host/path interface
; Implements host URI resolution and path handling
; This is part of the Hardware Interface Layer

        .export fuji_resolve_path
        .export _fuji_resolve_path       ; C-friendly label
        .export fuji_set_host
        .export _fuji_set_host           ; C-friendly label
        .export fuji_get_host
        .export _fuji_get_host           ; C-friendly label

        .export fuji_resolve_path_data
        .export fuji_set_host_data
        .export fuji_get_host_data

        .import fuji_begin_transaction
        .import fuji_end_transaction
        .import remember_axy
        .import remember_xy_only
        .import fuji_disk_slot
        .import fuji_current_host_len

        .include "fujinet.inc"

        .segment "CODE"

;//////////////////////////////////////////////////////////////////////
; fuji_resolve_path - Resolve path using FileDevice
; This is the high-level interface that manages transactions
;
; Entry: FUJI_CURRENT_HOST_URI and FUJI_CURRENT_HOST_LEN set
; Exit:  FUJI_CURRENT_HOST_URI/LEN = resolved URI
;        FUJI_CURRENT_DIR_PATH/LEN = display path
;        A = bool (true = success)
;//////////////////////////////////////////////////////////////////////

fuji_resolve_path:
        ; C-friendly alias for calling from C
_fuji_resolve_path:
        jsr     remember_xy_only
        
        ; Call hardware-specific implementation
        jsr     fuji_begin_transaction  ; Protect &BC-&CB
        jsr     fuji_resolve_path_data  ; Hardware-specific (dummy/serial)
        pha                             ; Save return value (bool)
        jsr     fuji_end_transaction    ; Restore &BC-&CB
        pla                             ; Restore return value
        
        rts

;//////////////////////////////////////////////////////////////////////
; fuji_set_host - Set current host URI
; This is the high-level interface that manages transactions
;
; Entry: FUJI_CURRENT_HOST_URI and FUJI_CURRENT_HOST_LEN set
; Exit:  A = bool (true = success)
;//////////////////////////////////////////////////////////////////////

fuji_set_host:
        ; C-friendly alias for calling from C
_fuji_set_host:
        jsr     remember_xy_only
        
        ; Call hardware-specific implementation
        jsr     fuji_begin_transaction  ; Protect &BC-&CB
        jsr     fuji_set_host_data      ; Hardware-specific (dummy/serial)
        pha                             ; Save return value (bool)
        jsr     fuji_end_transaction    ; Restore &BC-&CB
        pla                             ; Restore return value
        
        rts

;//////////////////////////////////////////////////////////////////////
; fuji_get_host - Get current host URI
; This is the high-level interface that manages transactions
;
; Exit:  FUJI_CURRENT_HOST_URI and FUJI_CURRENT_HOST_LEN = current host
;        A = bool (true = success)
;//////////////////////////////////////////////////////////////////////

fuji_get_host:
        ; C-friendly alias for calling from C
_fuji_get_host:
        jsr     remember_xy_only
        
        ; Call hardware-specific implementation
        jsr     fuji_begin_transaction  ; Protect &BC-&CB
        jsr     fuji_get_host_data       ; Hardware-specific (dummy/serial)
        pha                             ; Save return value (bool)
        jsr     fuji_end_transaction    ; Restore &BC-&CB
        pla                             ; Restore return value
        
        rts

.ifdef FUJINET_INTERFACE_DUMMY

; Dummy interface - no-op implementations
fuji_resolve_path_data:
        ; Dummy: just return success
        lda     #$01
        rts

fuji_set_host_data:
        ; Dummy: just return success
        lda     #$01
        rts

fuji_get_host_data:
        ; Dummy: clear the host
        lda     #$00
        sta     fuji_current_host_len
        lda     #$01
        rts

.endif

.ifdef FUJINET_INTERFACE_SERIAL

; Serial interface - call C implementation
        .import _fujibus_resolve_path

; For serial, set host is the same as resolve path (validates and stores)
fuji_resolve_path_data:
fuji_set_host_data:
        jmp     _fujibus_resolve_path

fuji_get_host_data:
        ; TODO: do we need to do anything here when change to a single string and offsets for path?
        ; I don't see the need for host_uri anymore
        ; For serial, the host is stored locally in BBC memory (FUJI_CURRENT_HOST_URI/LEN)
        ; No FujiNet command needed - just return success
        lda     #$01
        rts

.endif

.ifdef FUJINET_INTERFACE_USERPORT

; Userport interface - TODO: implement
fuji_resolve_path_data:
        lda     #$00
        rts

fuji_set_host_data:
        lda     #$00
        rts

fuji_get_host_data:
        lda     #$00
        rts

.endif
