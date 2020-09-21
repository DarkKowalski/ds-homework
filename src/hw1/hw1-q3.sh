#!/bin/bash
analyze_log()
{
  file=$1

  # count lines and chars
  count=(`wc -lm $file`)
  echo "${count[0]}" # lines
  echo "${count[1]}" # chars

  # calcu elapsed time
  first_log=(`head -n 1 $file`)
  last_log=(`tail -n 1 $file`)
  start_time=${first_log[0]}
  end_time=${last_log[0]}

  # we don't care about the date!
  start_sec=$(date -d "1970-01-01 $start_time" +%s)
  end_sec=$(date -d "1970-01-01 $end_time" +%s)
  echo "$(($end_sec-$start_sec))" # seconds

  # calcu avg, total and count
  var_count=0
  var_sum=0
  while IFS=", " read -a line; do
      var=${line[-1]}
      not_zero=(`echo "$var>0" | bc`)
      if [[ $not_zero -eq 1 ]]; then
        var_count=$((var_count+1))
        var_sum=$(printf "%.2f" `echo "scale=3;$var_sum+$var" | bc`)
      fi
  done < $file

  # avoid dividing by zero
  if [[ $var_count -gt 0 ]]; then
    var_avg=$(printf "%.2f" `echo "scale=3;$var_sum/$var_count" | bc`)
  else
    var_avg=0
  fi

  # echo "records: $var_count"
  # echo "total: $var_sum"
  echo "$var_avg" # average
}

LOG="hw1-q3.log"
analyze_log $1 > $LOG
