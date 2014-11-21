#!/bin/bash

function razor {
  log "razor $@"
  command razor "$@" | \
    grep -vEi -e '^$' -e '^From' -e '^Query' -e ' *command:' -e '^Try'
  return "${PIPESTATUS[0]}"
}
