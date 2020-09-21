#!/bin/bash
print_uptime()
{
  n=$1
  for ((i=0; i<n; i++)); do
    uptime
    sleep 10s
  done
}

LOG="hw1-q2.log"
print_uptime 100 >> $LOG
