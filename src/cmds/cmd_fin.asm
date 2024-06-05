.CMD_FIN
    JSR     PrintString
    EQUS    "FIN", &80
    RTS                     ; this is &60, so not negative, hence &80 above
