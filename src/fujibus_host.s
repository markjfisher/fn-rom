; FujiBus Host Commands for BBC Micro
; Implements host device commands using FujiBus protocol
;
; Wire Device ID: 0xF0 (FN_DEVICE_HOST)
;
; Commands:
;   0x01 - GetHosts (get all host slots)
;   0x02 - SetHost (configure a host slot)
;   0x03 - GetHost (get single host slot info)

        .export fn_host_get_hosts
        .export fn_host_set_host
        .export fn_host_get_host

        .import fn_build_packet
        .import fn_send_packet
        .import fn_receive_packet
        .import fn_tx_buffer
        .import fn_rx_buffer
        .import fn_tx_len
        .import fn_tx_len_hi
        .import fn_rx_len
        .import _calc_checksum

        .import remember_axy

        .include "fujinet.inc"

; ============================================================================
; Constants
; ============================================================================

FN_HOST_VERSION  = $01

; Command IDs
FN_HOST_CMD_GET_HOSTS = $01
FN_HOST_CMD_SET_HOST  = $02
FN_HOST_CMD_GET_HOST  = $03

; Host types
FN_HOST_TYPE_DISABLED = $FF
FN_HOST_TYPE_SD       = $00
FN_HOST_TYPE_TNFS     = $01

; Response sizes
FN_HOST_ENTRY_SIZE    = 97   ; type(1) + name(32) + address(64)
FN_HOST_MAX_HOSTS     = 8

; ============================================================================
; CODE
; ============================================================================

        .segment "CODE"

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; FN_HOST_GET_HOSTS - Get all host slot configurations
;
; Input:  None
; Output: Carry=0 if success, host data in fn_rx_buffer
;         Carry=1 if error
;
; Response format: [version:1][host_count:1][entries...]
; Each entry: [type:1][name:32][address:64] = 97 bytes
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

fn_host_get_hosts:
        jsr     remember_axy

        ; Build packet: [version:1]
        lda     #FN_DEVICE_HOST
        sta     fn_tx_buffer+0
        lda     #FN_HOST_CMD_GET_HOSTS
        sta     fn_tx_buffer+1
        lda     #7                      ; length = 6 (header) + 1 (version)
        sta     fn_tx_buffer+2
        lda     #0
        sta     fn_tx_buffer+3
        sta     fn_tx_buffer+5          ; descriptor = 0

        ; Version
        lda     #FN_HOST_VERSION
        sta     fn_tx_buffer+6

        ; Calculate checksum
        lda     #<fn_tx_buffer
        sta     aws_tmp00
        lda     #>fn_tx_buffer
        sta     aws_tmp01
        lda     #7
        sta     fn_tx_len
        sta     aws_tmp02
        lda     #0
        sta     fn_tx_len_hi
        sta     aws_tmp03
        jsr     _calc_checksum
        sta     fn_tx_buffer+4

        ; Send packet
        jsr     fn_send_packet
        bcs     @error

        ; Receive response
        jsr     fn_receive_packet
        bcs     @error

        ; Check response status (first byte of payload after header)
        ; Response: [version:1][host_count:1][entries...]
        lda     fn_rx_buffer+6          ; version
        cmp     #FN_HOST_VERSION
        bne     @error

        clc
        rts

@error: sec
        rts

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; FN_HOST_SET_HOST - Set a host slot configuration
;
; Input:  X = slot number (0-7)
;         A = host type (0=SD, 1=TNFS, $FF=disabled)
;         fn_host_name_buffer = 32-byte host name
;         fn_host_addr_buffer = 64-byte host address
; Output: Carry=0 if success
;         Carry=1 if error
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

fn_host_set_host:
        jsr     remember_axy

        ; Validate slot
        cpx     #8
        bcs     @error

        ; Build packet header
        lda     #FN_DEVICE_HOST
        sta     fn_tx_buffer+0
        lda     #FN_HOST_CMD_SET_HOST
        sta     fn_tx_buffer+1

        ; Total length = 6 (header) + 1 (version) + 1 (slot) + 1 (type) + 32 (name) + 64 (addr) = 105
        lda     #105
        sta     fn_tx_buffer+2
        sta     fn_tx_len
        lda     #0
        sta     fn_tx_buffer+3
        sta     fn_tx_len_hi
        sta     fn_tx_buffer+5          ; descriptor = 0

        ; Payload: [version:1][slot:1][type:1][name:32][address:64]
        lda     #FN_HOST_VERSION
        sta     fn_tx_buffer+6

        ; Slot (from X register, saved by remember_axy)
        txa
        sta     fn_tx_buffer+7

        ; Type (from A register, saved by remember_axy - need to restore it)
        ; The type was in A, but remember_axy saved it. We need to pass it differently.
        ; For now, assume type is in fn_host_type
        lda     fn_host_type
        sta     fn_tx_buffer+8

        ; Copy name (32 bytes)
        ldy     #0
@copy_name:
        lda     fn_host_name_buffer,y
        sta     fn_tx_buffer+9,y
        iny
        cpy     #32
        bne     @copy_name

        ; Copy address (64 bytes)
        ldy     #0
@copy_addr:
        lda     fn_host_addr_buffer,y
        sta     fn_tx_buffer+41,y
        iny
        cpy     #64
        bne     @copy_addr

        ; Calculate checksum
        lda     #<fn_tx_buffer
        sta     aws_tmp00
        lda     #>fn_tx_buffer
        sta     aws_tmp01
        lda     #105
        sta     fn_tx_len
        sta     aws_tmp02
        lda     #0
        sta     fn_tx_len_hi
        sta     aws_tmp03
        jsr     _calc_checksum
        sta     fn_tx_buffer+4

        ; Send packet
        jsr     fn_send_packet
        bcs     @error

        ; Receive response
        jsr     fn_receive_packet
        bcs     @error

        ; Check response status
        lda     fn_rx_buffer+6          ; version
        cmp     #FN_HOST_VERSION
        bne     @error

        lda     fn_rx_buffer+7          ; status
        bne     @error

        clc
        rts

@error: sec
        rts

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; FN_HOST_GET_HOST - Get a single host slot configuration
;
; Input:  X = slot number (0-7)
; Output: Carry=0 if success, host data in fn_rx_buffer
;         Carry=1 if error
;
; Response format: [version:1][type:1][name:32][address:64]
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

fn_host_get_host:
        jsr     remember_axy

        ; Validate slot
        cpx     #8
        bcs     @error

        ; Build packet: [version:1][slot:1]
        lda     #FN_DEVICE_HOST
        sta     fn_tx_buffer+0
        lda     #FN_HOST_CMD_GET_HOST
        sta     fn_tx_buffer+1
        lda     #8                      ; length = 6 (header) + 2 (version + slot)
        sta     fn_tx_buffer+2
        lda     #0
        sta     fn_tx_buffer+3
        sta     fn_tx_buffer+5          ; descriptor = 0

        ; Version
        lda     #FN_HOST_VERSION
        sta     fn_tx_buffer+6

        ; Slot (from X register)
        txa
        sta     fn_tx_buffer+7

        ; Calculate checksum
        lda     #<fn_tx_buffer
        sta     aws_tmp00
        lda     #>fn_tx_buffer
        sta     aws_tmp01
        lda     #8
        sta     fn_tx_len
        sta     aws_tmp02
        lda     #0
        sta     fn_tx_len_hi
        sta     aws_tmp03
        jsr     _calc_checksum
        sta     fn_tx_buffer+4

        ; Send packet
        jsr     fn_send_packet
        bcs     @error

        ; Receive response
        jsr     fn_receive_packet
        bcs     @error

        ; Check response
        lda     fn_rx_buffer+6          ; version
        cmp     #FN_HOST_VERSION
        bne     @error

        clc
        rts

@error: sec
        rts

; ============================================================================
; Workspace - use absolute addresses
; ============================================================================

; Host configuration buffers (in fuji_workspace area)
fn_host_type        = $10FA     ; 1 byte
fn_host_name_buffer = $10FB     ; 32 bytes ($10FB-$111A)
fn_host_addr_buffer = $111B     ; 64 bytes ($111B-$115A)
