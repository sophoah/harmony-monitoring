# harmony-monitoring
Monitor Harmony Mainnet and Pangaea Nodes using Systemd, Monit, Telegram etc.

This repo includes scripts and configs for optimally running a Harmony Mainnet or Pangaea Node.

## Configs

### systemd/harmony.service

To run your node using Systemd:

1. `curl -L -o harmony.service https://raw.githubusercontent.com/SebastianJ/harmony-monitoring/master/configs/systemd/harmony.service.conf`
2. Replace all instances of YOUR_NODE_DIR with the absolute path to your node (typically /root if running the node as the root user)
3. Create an empty bls_passkey file: `sudo touch YOUR_NODE_DIR/bls_passkey.txt`
3. `sudo rm -rf /lib/systemd/system/harmony.service && sudo cp harmony.service /lib/systemd/system`
4. `sudo systemctl daemon-reload`
5. `sudo systemctl enable harmony.service`
6. `sudo systemctl start harmony.service`
7. `sudo systemctl status harmony.service`

## Scripts

### node_health.sh

Checks and also fixes some issues with node installations.

The script will try to inform you how to fix certain issue if they are detected.

This node health script has the following features:

1. Supports specifying custom node and wallet directories for those running custom installations.
2. Checks if the *.key and UTC* files are in the correct folders.
3. Checks that all script files and binaries can be found.
4. Automatically parses the wallet address from the wallet binary.
5. Checks that your node is running using the latest bootnodes. It will also check if other node processes are running (i.e. if you're running a node using the old bootnodes)
6. Detects which shard you are running on.
7. Will check your shard's status on https://harmony.one/pga/network
8. Will check your node's online status using https://harmony.one/pga/network.csv
9. Will check your sync status, block count and bingo status using latest/zero*.log. The script will also alert if you're more than 1000 blocks behind the latest reported block number for your shard and it will also report when you haven't received any bingos for more than a day.

#### Requirements
The only requirement is that wget is installed (which it typically is). The rest of the script is normal bash.

#### Installation & Setup

`wget -q https://raw.githubusercontent.com/SebastianJ/harmony-monitoring/master/scripts/node_health.sh && sudo chmod u+x node_health.sh`

#### Running the script

`./node_health.sh -h` will display all options for running the monitoring script.

If you download the script right to your node installation directory you simply just run the script without any parameters:

`./node_health.sh`

If you've installed your node and/or wallet in custom directories you run the script like this:

`./node_health.sh -n /opt/harmony/pangaea/node/ -w /opt/harmony/pangaea/wallet/`

The script is currently defaulting to Pangaea, but it's also compatible with the Mainnet, just pass the -m option to switch from Pangaea to Mainnet:

`./node_health.sh -m`


### node_sentinel.sh

Monitor your node for bingos and receive messages via Telegram if bingos stop working. You can optionally also receive messages every time a successful bingo check happens.

#### Requirements
The only requirement is that curl is installed. The rest of the script is normal bash.

#### Installation & Setup

##### Downloading the script

`curl -LO https://raw.githubusercontent.com/SebastianJ/harmony-monitoring/master/scripts/node_sentinel.sh && sudo chmod u+x node_sentinel.sh`

##### Setting up Telegram

1. Interact with [bot father](https://telegram.me/botfather) and create a new bot. [Bot father](https://telegram.me/botfather) will give you an access token that you need in order to interact with Telegram's HTTP API.

2. Switch to your bot on your Telegram app, click on "/start" or write /start to your bot.

3. Go to https://api.telegram.org/botTHE_ACCESS_TOKEN_BOT_FATHER_GAVE_YOU/getUpdates and look for "chat":{"id":CHAT_ID,"first_name":"FIRST_NAME","username":"USERNAME","type":"private"}. Save the chat id.

#### Running the script

`./node_sentinel.sh -h` will display all options for running the monitoring script.

You should run the monitoring script as the same user that's running your mainnet or Pangaea node.

If you're running your node as root the script will automatically look for bingos in /root/latest/zero*.log, if running the node as a regular user the script will look for bingos in /home/your_username/latest/zero*.log. A custom installation directory can also be supplied to the script using the -p parameter (e.g. -p /opt/harmony/pangaea/node)

The most standard way to run the script is like this:
`./node_sentinel.sh -b YOUR_TELEGRAM_BOT_TOKEN -c YOUR_TELEGRAM_CHAT_ID -a YOUR_HARMONY_WALLET_ADDRESS`

Running the script like above will run the monitoring script and look for bingos in ~/latest/zero*.log, it will also use the token, chat id and wallet address you specified to send messages to Telegram. The script will by default execute once and it will only send Telegram messages when it can't find recent bingos (i.e. when there might be something wrong with your node.)

The most advanced way to run the script is like this:
`./node_sentinel.sh -b YOUR_TELEGRAM_BOT_TOKEN -c YOUR_TELEGRAM_CHAT_ID -n CUSTOM_NODE_PATH -a YOUR_HARMONY_WALLET_ADDRESS -s -d -i 5m`

Running the script like above will look for bingos in CUSTOM_NODE_PATH/latest/zero*.log, it will also use the token, chat id and wallet address you specified to send messages to Telegram. The script will run in an infinite loop and check for bingos every five minutes and it will send all messages (including successful bingo checks) to Telegram.
