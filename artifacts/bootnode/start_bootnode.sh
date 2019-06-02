#!/bin/bash
# Copyright 2019 DI Miliy Andrew. All Rights Reserved.
# SPDX-License-Identifier: MIT
IP=$(hostname -i)
bootnode -nodekey testnet.key -addr $IP:30333
