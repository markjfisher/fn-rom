; FujiNet FUJI operations
; High-level fuji operations that pass off to the implementation layer
; This layer wraps them in a transaction (TODO: is this always needed?)
; and calls the implementation layer to perform the operation and handle any return values

        .export fuji_reset
        .export fuji_set_host_url_n
        .export fuji_get_hosts

        .import fuji_begin_transaction
        .import fuji_end_transaction

        .import fuji_execute_get_hosts
        .import fuji_execute_set_host_url_n
        .import fuji_execute_reset

        .include "fujinet.inc"

fuji_reset:
        jsr     fuji_begin_transaction
        jsr     fuji_execute_reset
        jmp     fuji_end_transaction


fuji_set_host_url_n:
        jsr     fuji_begin_transaction
        jsr     fuji_execute_set_host_url_n
        jmp     fuji_end_transaction

fuji_get_hosts:
        jsr     fuji_begin_transaction
        jsr     fuji_execute_get_hosts
        jmp     fuji_end_transaction

