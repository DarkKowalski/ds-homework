#!/bin/bash
REMOTE[0]="user@remote0"
REMOTE[1]="user@remote1"
REMOTE[2]="user@remote2"

WORKDIR="/tmp"
REMOTE_LOGS="./remote_logs"

SCRIPT[0]="hw1-q2.sh"
SCRIPT[1]="hw1-q3.sh"

LOG[0]="hw1-q2.log"
LOG[1]="hw1-q3.log"

deploy()
{
  # Copy scripts to remote hosts
  for remote in "${REMOTE[@]}"; do
    for script in "${SCRIPT[@]}"; do
      echo "Copy $script to $remote:$WORKDIR"
      scp $script $remote:$WORKDIR
    done
  done

  # Run over SSH
  ## uptime
  for remote in "${REMOTE[@]}"; do
    echo "Run ${SCRIPT[0]} on $remote:$WORKDIR"
    ssh -f $remote "cd $WORKDIR && ./${SCRIPT[0]}"

  done
  ## wait
  echo "Waiting remote hosts"
  sleep 1100s
  ## analyze
  for remote in "${REMOTE[@]}"; do
    echo "Run ${SCRIPT[1]} ${LOG[0]} on $remote:$WORKDIR"
    ssh -f $remote "cd $WORKDIR && ./${SCRIPT[1]} ${LOG[0]}"
  done
  
  # Retrieve
  mkdir -p $REMOTE_LOGS
  for remote in "${REMOTE[@]}"; do
    echo "Retrieve ${LOG[1]} from $remote:$WORKDIR"
    scp $remote:$WORKDIR/${LOG[1]} "$REMOTE_LOGS/${remote}.log"
  done
}

analyze()
{
  var_hosts=3
  var_sum=0
  cd $REMOTE_LOGS
  for file in *.log; do
    var=`tail -n 1 $file`
    var_sum=$(printf "%.2f" `echo "scale=3;$var_sum+$var" | bc`)
  done

  # Avoid dividing by zero
  var_avg=0
  if (( $(echo "$var_sum > 0" |bc -l) )); then
    var_avg=$(printf "%.2f" `echo "scale=3;$var_sum/$var_hosts" | bc`)
  fi

  echo $var_avg
}

clean_up()
{
  rm -rf $REMOTE_LOGS
}

deploy
analyze
clean_up
