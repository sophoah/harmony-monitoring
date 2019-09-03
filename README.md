# harmony-monitoring
Monitor Harmony Mainnet and Pangaea Nodes using Systemd, Monit, Telegram etc.

This repo includes scripts and configs for optimally running a Harmony Mainnet or Pangaea Node.

## Configs

### systemd/harmony.service

To run your node using Systemd:

1. `curl -LO https://raw.githubusercontent.com/SebastianJ/harmony-monitoring/master/configs/systemd/harmony.service.conf`
2. Replace all instances of YOUR_NODE_DIR with the absolute path to your node (typically /root if running the node as the root user)
3. Create an empty bls_passkey file: `sudo touch YOUR_NODE_DIR/bls_passkey.txt`
3. `sudo rm -rf /lib/systemd/system/harmony.service && sudo cp harmony.service /lib/systemd/system`
4. `sudo systemctl daemon-reload`
5. `sudo systemctl enable harmony.service`
6. `sudo systemctl start harmony.service`
7. `sudo systemctl status harmony.service`

## Scripts

### telegram_sentinel.sh

#### Requirements
The only requirement is that curl is installed. The rest of the script is normal bash.

#### Installation

`curl -LO https://raw.githubusercontent.com/SebastianJ/harmony-monitoring/master/scripts/telegram_sentinel.sh && sudo chmod u+x telegram_sentinel.sh`

Telegram:

1. Interact with [bot father](https://telegram.me/botfather) and create a new bot. [Bot father](https://telegram.me/botfather) will give you an access token that you need in order to interact with Telegram's HTTP API.

2. Switch to your bot on your Telegram app, click on "/start" or write /start to your bot.

3. Go to https://api.telegram.org/botTHE_ACCESS_TOKEN_BOT_FATHER_GAVE_YOU/getUpdates and look for "chat":{"id":CHAT_ID,"first_name":"FIRST_NAME","username":"USERNAME","type":"private"}. Save the chat id.

#### Invocation

`./telegram_sentinel.sh -h` will display all options for running the monitoring script.

You should run the monitoring script as the same user that's running your mainnet or Pangaea node.

If you're running your node as root the script will automatically look for bingos in /root/latest/zero*.log, if running the node as a regular user the script will look for bingos in /home/your_username/latest/zero*.log. A custom installation directory can also be supplied to the script using the -p parameter (e.g. -p /opt/harmony/pangaea/node)

The most standard way to run the script is like this:
`./telegram_sentinel.sh -t YOUR_TELEGRAM_BOT_TOKEN -c YOUR_TELEGRAM_CHAT_ID -a YOUR_HARMONY_WALLET_ADDRESS`

Running the script like above will run the monitoring script and look for bingos in ~/latest/zero*.log, it will also use the token, chat id and wallet address you specified to send messages to Telegram. The script will by default execute once and it will only send Telegram messages when it can't find recent bingos (i.e. when there might be something wrong with your node.)

The most advanced way to run the script is like this:
`./telegram_sentinel.sh -t YOUR_TELEGRAM_BOT_TOKEN -c YOUR_TELEGRAM_CHAT_ID -p CUSTOM_NODE_PATH -a YOUR_HARMONY_WALLET_ADDRESS -s -d -i 5m`

Running the script like above will look for bingos in CUSTOM_NODE_PATH/latest/zero*.log, it will also use the token, chat id and wallet address you specified to send messages to Telegram. The script will run in an infinite loop and check for bingos every five minutes and it will send all messages (including successful bingo checks) to Telegram.
