#!/bin/bash

socat -d -d -ls -v \
  PTY,raw,echo=0,link=/tmp/fn-tty,mode=660,group=uucp \
  PTY,raw,echo=0,link=/tmp/inject-tty,mode=660,group=uucp
