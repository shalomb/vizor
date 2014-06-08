#!/bin/bash

TIMEZONE='GMT Standard Time'
PXE_HOST="$(hostname -f)"   # Host delivering PXE/HTTP, etc
RAZOR_HOST="$(hostname -f)"

TIMEZONE="$TZ"
KEYMAP="$XKBLAYOUT"
ROOT_PASSWD='***REMOVED***'

