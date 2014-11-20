#!/bin/bash

function ack {
  cmd_exists ack-grep && command ack-grep "$@"
}
