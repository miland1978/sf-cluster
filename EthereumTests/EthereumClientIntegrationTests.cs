// Copyright 2019 DI Miliy Andrew. All Rights Reserved.
// SPDX-License-Identifier: MIT

using DLTech.EthereumLib;
using FluentAssertions;
using Nethereum.Hex.HexTypes;
using Nethereum.JsonRpc.Client;
using Nethereum.RPC;
using Nethereum.Signer;
using System;
using System.Collections.Generic;
using System.Diagnostics;
using System.Linq;
using System.Numerics;
using System.Threading.Tasks;
using Xunit;

namespace DLTech.EthereumTests
{
	public class EthereumClientIntegrationTests
	{
		private const string NodeUrl0 = "http://40.118.124.167:3600";
		private const string NodeUrl1 = "http://40.118.124.167:3601";
		private const string NodeUrl2 = "http://40.118.124.167:3602";
		private const string ContractAddress = "0x58F1D1010964e9f20d398d1c7d42254699Dea503";
		private const string MinterKey = "216ab7306b67c04cf1d04951c95afbd16756101cfa0a1f9569eca38672714fae";

		private readonly IClient _client0;
		private readonly IClient _client1;
		private readonly IClient _client2;

		public EthereumClientIntegrationTests()
		{
			_client0 = new RpcClient(new Uri(NodeUrl0));
			_client1 = new RpcClient(new Uri(NodeUrl1));
			_client2 = new RpcClient(new Uri(NodeUrl2));
		}

		//[Fact]
		[Fact(Skip = "manual")]
		public async Task Connect()
		{
			var api = new EthApiService(_client0);
			HexBigInteger hex = await api.Blocks.GetBlockNumber.SendRequestAsync();
			long count = (long)(BigInteger)hex;
			Debug.WriteLine(count);
			count.Should().BeGreaterThan(1);
		}

		//[Fact]
		[Fact(Skip = "manual")]
		public async Task SendMintTransactions()
		{
			int count = 30000;
			var client = new EthereumClient(_client0, ContractAddress, MinterKey);

			Stopwatch sw = Stopwatch.StartNew();
			List<List<EthECKey>> targetKeyBatches = GenerateKeys(count);
			Debug.WriteLine($"Generated {targetKeyBatches.Sum(x => x.Count)} keys in {sw.Elapsed}");

			BigInteger nonceStart = await client.GetCurrentMintingNonceAsync();

			sw.Restart();
			List<List<string>> transactionBatches = CreateAndSignTransactions(client, targetKeyBatches, nonceStart);
			Debug.WriteLine($"Created {transactionBatches.Sum(x => x.Count)} transactions in {sw.Elapsed}");

			BigInteger blockNumber = await client.GetBlockNumberAsync();
			Debug.WriteLine($"BlockNumber on start {blockNumber}");

			EthereumClient[] clients = new[] {
				new EthereumClient(_client0, ContractAddress, MinterKey),
				new EthereumClient(_client1, ContractAddress, MinterKey),
				new EthereumClient(_client2, ContractAddress, MinterKey)
			};
			sw.Restart();
			List<string> transactionHashes = SendTransactions(clients, transactionBatches);
			Debug.WriteLine($"Sent {transactionBatches.Sum(x => x.Count)} transactions in {sw.Elapsed}");
		}

		private static List<List<EthECKey>> GenerateKeys(int count)
		{
			int taskCount = 8;
			var tasks = new List<Task<List<EthECKey>>>();
			for (int t = 0; t < taskCount; t++)
			{
				int taskId = t;
				Task<List<EthECKey>> task = Task.Run(() =>
				{
					var keys = new List<EthECKey>();
					for (int i = 0; i < count / taskCount; i++)
					{
						keys.Add(EthECKey.GenerateKey());
					}
					return keys;
				});

				tasks.Add(task);
			}

			var result = new List<List<EthECKey>>();
			foreach (var task in tasks)
			{
				result.Add(task.Result);
			}

			return result;
		}

		private List<List<string>> CreateAndSignTransactions(EthereumClient client, List<List<EthECKey>> keyBatches, BigInteger nonceStart)
		{
			int taskCount = keyBatches.Count;
			var tasks = new List<Task<List<string>>>();
			for (int t = 0; t < taskCount; t++)
			{
				int taskId = t;
				List<EthECKey> keyBatch = keyBatches[t];
				Task<List<string>> task = Task.Run(async () =>
				{
					var transactions = new List<string>();
					for (int i = 0; i < keyBatch.Count; i++)
					{
						EthECKey ecKey = keyBatch[i];
						BigInteger nonce = nonceStart + i * taskCount + taskId;
						string tx = await client.CreateMintTransactionAsync(nonce, ecKey.GetPublicAddress(), 1000000);
						transactions.Add(tx);
					}

					return transactions;
				});

				tasks.Add(task);
			}

			var result = new List<List<string>>();
			foreach (var task in tasks)
			{
				result.Add(task.Result);
			}

			return result;
		}

		private List<string> SendTransactions(EthereumClient[] clients, List<List<string>> transactionBatches)
		{
			int taskCount = transactionBatches.Count;
			var tasks = new List<Task<List<string>>>();
			for (int t = 0; t < taskCount; t++)
			{
				int taskId = t;
				var transactions = transactionBatches[t];
				EthereumClient client = clients[taskId % clients.Length];
				Task<List<string>> task = Task.Run(async () =>
				{
					var hashes = new List<string>();
					for (int i = 0; i < transactions.Count; i++)
					{
						string transaction = transactions[i];
						string hash = await client.SendAsync(transaction);
						hashes.Add(hash);
					}

					return hashes;
				});

				tasks.Add(task);
			}

			var result = new List<string>();
			foreach (var task in tasks)
			{
				result.AddRange(task.Result);
			}

			return result;
		}

		//[Fact]
		[Fact(Skip = "manual")]
		public async Task DumpBlocks()
		{
			BigInteger from = 369;

			var client = new EthereumClient(_client0, ContractAddress, MinterKey);

			List<string> blocks = await client.DumpBlocksAsync(from, 50);
			foreach (string block in blocks)
			{
				Debug.WriteLine(block);
			}
		}
	}
}
