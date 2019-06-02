#!/bin/bash
# Copyright 2019 DI Miliy Andrew. All Rights Reserved.
# SPDX-License-Identifier: MIT
IP=$(hostname -i)
BOOTNODES=$(cat bootnodes.txt)
ADDRESS=$(cat n5/$HOSTNAME/address.txt)
geth --datadir n5/$HOSTNAME/ init n5/testnet.json
sleep 10
geth --datadir n5/$HOSTNAME/ --syncmode full --port 30310 --rpc --rpcaddr $IP --rpcport 8555 --rpcapi 'personal,db,eth,net,web3,txpool,miner' --bootnodes $BOOTNODES --networkid 1999 --gasprice 1 --unlock $ADDRESS --password passphrase.txt --mine
