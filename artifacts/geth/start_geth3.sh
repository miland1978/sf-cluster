#!/bin/bash
IP=$(hostname -i)
BOOTNODES=$(cat bootnodes.txt)
ADDRESS=$(cat $HOSTNAME/address.txt)
geth --datadir n3/$HOSTNAME/ --syncmode full --port 30310 --rpc --rpcaddr $IP --rpcport 8555 --rpcapi 'personal,db,eth,net,web3,txpool,miner' --bootnodes $BOOTNODES --networkid 1999 --gasprice 1 --unlock $ADDRESS --password passphrase.txt --mine
