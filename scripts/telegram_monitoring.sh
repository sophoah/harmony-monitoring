#!/bin/bash

usage () {
   cat << EOT
Usage: $0 [option] command
Options:
   -t token       the bot's Telegram API token
   -c chat_id     the chat id of where to send the bot's messages
   -p path        the path of the node directory (without an ending slash) - will default to the current user's home directory if no path is provided
   -a address     the address of the node that is monitored
   -i interval    interval between checking for bingos (30s, 1m, 30m, 1h etc.)
   -s             send telegram messages for successful checks (and not only for failed checks) - expects true/false. Defaults to false (i.e. only sending messages when the node is offline)
   -d             if the process should be daemonized / run in an endless loop (e.g. if running it using Systemd and not Cron)
   -h             print this help
EOT
}

while getopts "t:c:p:a:i:sdh" opt; do
  case ${opt} in
    t)
      telegram_bot_token="${OPTARG}"
      ;;
    c)
      telegram_chat_id="${OPTARG}"
      ;;
    p)
      node_path="${OPTARG}"
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
      echo "Bingo file doesn't exist"
      echo $current_bingo > $bingo_file
      previous_bingo=$current_bingo
    fi
  fi
}

parse_current_bingo() {
  if ls $node_path/latest/zerolog*.log 1> /dev/null 2>&1; then
    current_bingo=`tac $node_path/latest/zerolog*.log | grep -am 1 "BINGO" | grep -oam 1 -E "\"time\":\"([0-9]*\-[0-9]*\-[0-9]*T?[0-9]*:[0-9]*:[0-9]*)+(\.?[0-9]*)(\+[0-9]*:[0-9]*)[^\"]*\"" | grep -oam 1 -E "(([0-9]*\-[0-9]*\-[0-9]*T?[0-9]*:[0-9]*:[0-9]*)+(\.?[0-9]*)(\+[0-9]*:[0-9]*)[^\"]*)" | sed "s/\..*//" | sed -e 's/T/ /g'`
  else
    echo "Can't find $node_path/latest/zerolog*.log - are you sure you've entered the correct node path ($node_path)?"
    exit 1
  fi
}

parse_timestamp() {
  timestamp=$(date -d "${1}" +"%s")
  timestamp=$((10#$timestamp))
}

compare_bingos() {
  parse_timestamp "$1"
  current_timestamp=$timestamp

  parse_timestamp "$2"
  previous_timestamp=$timestamp
  
  if (( $current_timestamp > $previous_timestamp )); then
    echo "NODE $node_address IS ONLINE! New bingo happened $1! Previous recorded bingo was $2."
    
    if [ "$send_success_messages" = true ]; then
      send_telegram_message "<b>NODE $node_address IS ONLINE</b>%0A%0ANew bingo happened <i>$1</i>!%0A%0APrevious recorded bingo was <i>$2</i>."
    fi
  else
    echo "NODE $node_address IS OFFLINE! Can't find any recent bingos! Previous recorded bingo was $2."
    send_telegram_message "<b>NODE $node_address IS OFFLINE</b>%0A%0ACan't find any recent bingos!%0A%0APrevious recorded bingo was <i>$2</i>."
  fi
}

send_telegram_message() {
  url="https://api.telegram.org/bot$telegram_bot_token/sendMessage"
  curl -s -X POST $url -d chat_id=$telegram_chat_id -d text="$1" -d parse_mode="HTML" >> /dev/null
}

echo "Running monitoring script as $executing_user!"

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
