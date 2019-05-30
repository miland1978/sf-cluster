#!/bin/bash
IP=$(hostname -i)
bootnode -nodekey testnet.key -addr $IP:30333
