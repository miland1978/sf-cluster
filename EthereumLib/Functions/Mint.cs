// Copyright 2019 DI Miliy Andrew. All Rights Reserved.
// SPDX-License-Identifier: MIT

using Nethereum.ABI.FunctionEncoding.Attributes;
using Nethereum.Contracts;
using System.Numerics;

namespace DLTech.EthereumLib.Functions
{
	[Function("mint", "bool")]
	public class Mint : FunctionMessage
	{
		[Parameter("address", "_to", 1)]
		public string To { get; set; }

		[Parameter("uint256", "_value", 2)]
		public BigInteger Amount { get; set; }
	}
}
