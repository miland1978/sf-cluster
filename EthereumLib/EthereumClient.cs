// Copyright 2019 DI Miliy Andrew. All Rights Reserved.
// SPDX-License-Identifier: MIT

using DLTech.EthereumLib.Functions;
using Nethereum.Contracts.ContractHandlers;
using Nethereum.Hex.HexTypes;
using Nethereum.JsonRpc.Client;
using Nethereum.Web3;
using Nethereum.Web3.Accounts;
using System;
using System.Collections.Generic;
using System.Numerics;
using System.Threading.Tasks;

namespace DLTech.EthereumLib
{
	public class EthereumClient
	{
		private IClient _client;
		private string _contractAddress;
		private Account _minterAccount;
		private Web3 _minterWeb3Client;
		private IContractTransactionHandler<Mint> _mintHandler;

		public EthereumClient(IClient client, string contractAddress, string minterKey)
		{
			_client = client;
			_contractAddress = contractAddress;
			_minterAccount = new Account(HexToBytes(minterKey));
			_minterWeb3Client = new Web3(_minterAccount, _client);
			_mintHandler = _minterWeb3Client.Eth.GetContractTransactionHandler<Mint>();
		}

		public async Task<BigInteger> GetCurrentMintingNonceAsync()
		{
			string address = _minterAccount.Address;
			HexBigInteger nonce = await _minterWeb3Client.Eth.Transactions.GetTransactionCount.SendRequestAsync(address);
			return nonce;
		}

		public async Task<string> CreateMintTransactionAsync(BigInteger nonce, string toAddress, BigInteger amount)
		{
			var call = new Mint
			{
				To = toAddress,
				Amount = amount,
				Nonce = nonce,
				Gas = 100000,
				GasPrice = 0
			};

			string transaction = await _mintHandler.SignTransactionAsync(_contractAddress, call);
			return transaction;
		}

		public async Task<string> SendAsync(string signedTransaction)
		{
			var hash = await _minterWeb3Client.Eth.Transactions.SendRawTransaction.SendRequestAsync(signedTransaction);
			return hash;
		}

		public async Task<BigInteger> GetBlockNumberAsync()
		{
			HexBigInteger blockNumber = await _minterWeb3Client.Eth.Blocks.GetBlockNumber.SendRequestAsync();
			return blockNumber;
		}

		public async Task<List<string>> DumpBlocksAsync(BigInteger fromHeight, int count = -1)
		{
			BigInteger toHeight = fromHeight + count;
			if (count == -1)
			{
				toHeight = await GetBlockNumberAsync();
			}

			var blocks = new List<string>();
			BigInteger current = fromHeight;
			while (current < toHeight)
			{
				string json = await DumpBlockAsync(current);
				blocks.Add(json);
				current++;
			}

			return blocks;
		}

		private async Task<string> DumpBlockAsync(BigInteger current)
		{
			var block = await _minterWeb3Client.Eth.Blocks.GetBlockWithTransactionsByNumber.SendRequestAsync(new HexBigInteger(current));
			//var json = JsonConvert.SerializeObject(block);
			//json = json.Replace(",", ",\n");
			//return json;
			DateTime epoch = new DateTime(1970, 1, 1, 0, 0, 0, 0, DateTimeKind.Utc);
			DateTime blockTimestamp = epoch.AddSeconds((double)block.Timestamp.Value);
			return $"{current};{block.Transactions.Length};{blockTimestamp.ToLongTimeString()};{(BigInteger)block.GasUsed};{(BigInteger)block.GasLimit}";
		}

		private static byte[] HexToBytes(string hex)
		{
			var result = new byte[hex.Length / 2];
			for (var i = 0; i < result.Length; i++)
			{
				result[i] = Convert.ToByte(hex.Substring(i * 2, 2), 16);
			}

			return result;
		}
	}
}
