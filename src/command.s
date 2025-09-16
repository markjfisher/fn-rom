; Command handler for star commands
        .include "fujinet.inc"

        .segment "CODE"

handle_command:
        ; Check if this is a FujiNet command
        ; Commands will start with *FN or similar
        ; For now, just return (not handled)
        clc
        rts
