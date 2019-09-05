#!/bin/bash

usage () {
   cat << EOT
Usage: $0 [option] command
Options:
   -b token       the bot's Telegram API token
   -c chat_id     the chat id of where to send the bot's messages
   -n path        the path of the node directory - defaults to the current user's home directory if no path is provided
   -w path        the path of the wallet directory - defaults to the current user's home directory if no path is provided
   -a address     the address of the node that is monitored
   -i interval    interval between checking for bingos (30s, 1m, 30m, 1h etc.)
   -s             send telegram messages for successful checks (and not only for failed checks).
   -d             if the process should be daemonized / run in an endless loop (e.g. if running it using Systemd and not Cron)
   -h             print this help
EOT
}

while getopts "b:c:n:w:a:i:sdh" opt; do
  case ${opt} in
    b)
      telegram_bot_token="${OPTARG}"
      ;;
    c)
      telegram_chat_id="${OPTARG}"
      ;;
    n)
      node_path="${OPTARG%/}"
      ;;
    w)
      wallet_path="${OPTARG%/}"
      ;;
    a)
      node_address="${OPTARG}"
      ;;
    i)
      interval="${OPTARG}"
      ;;
    s)
      send_success_messages=true
      ;;
    d)
      daemonize=true
      ;;
    h|*)
      usage
      exit 1
      ;;
  esac
done

shift $((OPTIND-1))

#
# Variables
#

# Interval between bingo checks
# E.g: 30s => 30 seconds, 1m => 1 minute, 1h => 1 hour
if [ -z "$interval" ]; then
  interval=1m
fi

executing_user=`whoami`

if [ -z "$node_path" ]; then
  node_path=${HOME}
fi

bingo_file="bingos"

#
# Main functions
#
check_bingo() {
  parse_current_bingo
  
  if [ -z "$current_bingo" ]; then
    echo "Can't find a recent bingo - something's wrong!"
    send_telegram_message "<b>Node $node_address OFFLINE</b> - can't find any bingo messages!"
  else
    if test -f $bingo_file; then
      previous_bingo=`cat $bingo_file`
      
      if [ -z "$previous_bingo" ]; then
        rm -rf $bingo_file
      else
        compare_bingos "$current_bingo" "$previous_bingo"
        rm -rf $bingo_file
        echo $current_bingo > $bingo_file
      fi
      
    else
      echo $current_bingo > $bingo_file
      previous_bingo=$current_bingo
      compare_bingos "$current_bingo" "$previous_bingo"
    fi
  fi
}

compare_bingos() {
  parse_timestamp "$1"
  current_timestamp=$timestamp

  parse_timestamp "$2"
  previous_timestamp=$timestamp
  
  if (( $current_timestamp > $previous_timestamp )); then
    echo "NODE $node_address IS ONLINE! New bingo occurred $1! Previous recorded bingo occurred $2."
    
    if [ "$send_success_messages" = true ]; then
      send_telegram_message "<b>NODE $node_address IS ONLINE</b>%0A%0ANew bingo occurred <i>$1</i>!%0A%0APrevious recorded bingo occurred <i>$2</i>."
    fi
  
  elif (( $current_timestamp == $previous_timestamp )); then
    echo "NODE $node_address IS ONLINE! No new bingos have occurred since $2."
    
    if [ "$send_success_messages" = true ]; then
      send_telegram_message "<b>NODE $node_address IS ONLINE</b>%0A%0AThe current bingo is the same as the previously recorded bingo (<i>$2</i>)."
    fi
    
  else
    echo "NODE $node_address IS OFFLINE! Can't find any recent bingos! Previous recorded bingo occurred $2."
    send_telegram_message "<b>NODE $node_address IS OFFLINE</b>%0A%0ACan't find any recent bingos!%0A%0APrevious recorded bingo occurred <i>$2</i>."
  fi
}


#
# Helper methods
#
parse_current_bingo() {
  parse_from_zerolog "bingo"
  current_bingo=$parsed_zerolog_value
}

parse_sync_status() {
  parse_from_zerolog "sync"
  current_sync_status=$parsed_zerolog_value
  
  if [ -z "$current_sync_status" ]; then
    node_synced=false
  else
    node_synced=true
  fi
}

parse_current_block() {
  parse_from_zerolog "block"
  current_block=$parsed_zerolog_value
  convert_to_integer "$current_block"
  current_block=$converted
}

parse_from_zerolog() {
  if ls $node_path/latest/zerolog*.log 1> /dev/null 2>&1; then
    case $1 in
    bingo)
      parsed_zerolog_value=`tac ${node_path}/latest/zerolog*.log | grep -am 1 "BINGO" | grep -oam 1 -E "\"time\":\"([0-9]*\-[0-9]*\-[0-9]*T?[0-9]*:[0-9]*:[0-9]*)+(\.?[0-9]*)(\+[0-9]*:[0-9]*)[^\"]*\"" | grep -oam 1 -E "(([0-9]*\-[0-9]*\-[0-9]*T?[0-9]*:[0-9]*:[0-9]*)+(\.?[0-9]*)(\+[0-9]*:[0-9]*)[^\"]*)" | sed "s/\..*//" | sed -e 's/T/ /g'`
      ;;
    block)
      parsed_zerolog_value=`tac ${node_path}/latest/zerolog*.log | grep -oam 1 -E "\"(blockNumber|myBlock)\":[0-9\"]*" | grep -oam 1 -E "[0-9]+"`
      ;;
    sync)
      parsed_zerolog_value=`tac ${node_path}/latest/zerolog*.log | grep -oam 1 "Node is now IN SYNC"`
      ;;
    *)
      ;;
    esac
  else
    error_message "Can't find ${node_path}/latest/zerolog*.log - are you sure you've entered the correct node path ($node_path)?"
  fi
}

parse_timestamp() {
  timestamp=$(date -d "${1}" +"%s")
  timestamp=$((10#$timestamp))
}

send_telegram_message() {
  url="https://api.telegram.org/bot$telegram_bot_token/sendMessage"
  curl -s -X POST $url -d chat_id=$telegram_chat_id -d text="$1" -d parse_mode="HTML" >> /dev/null
}

#
# Program execution
#
if [ "$daemonize" = true ]; then
  # Run in an infinite loop
  while [ 1 ]
  do
    check_bingo
    sleep $interval
  done
else
  check_bingo
fi
