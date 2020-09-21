#!/bin/bash
check_prime() {
  n=$1
  if [[ $n -lt 2 ]]; then
    return 0
  fi
  
  for ((i=2; i<n; i++)); do
    r=$(($n%$i))
    if [[ $r -eq 0 ]]; then
      return 0
    fi  
  done

  return 1
}

prime_sum()
{
  from=$1
  to=$2

  sum=0
  for (( n=$from; n<=$to; n++ ))
  do
    check_prime $n
    if [[ $? -eq 1 ]]; then
      sum=$(($sum+$n))
    fi
  done
  echo $sum
}

LOG="hw1-q1.log"
prime_sum 1 100 > $LOG
