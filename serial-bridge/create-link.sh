#!/bin/bash

echo "Creating permanent endpoints:"
echo "  /tmp/fn-tty       for fujinet LWS"
echo "  /tmp/inject-tty   for sending data to fujinet"

socat -d -d -ls -v \
  PTY,raw,echo=0,link=/tmp/fn-tty,mode=660,group=uucp \
  PTY,raw,echo=0,link=/tmp/inject-tty,mode=660,group=uucp
