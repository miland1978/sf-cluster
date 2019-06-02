// Copyright 2019 DI Miliy Andrew. All Rights Reserved.
// SPDX-License-Identifier: MIT

using Nethereum.ABI.FunctionEncoding.Attributes;
using Nethereum.Contracts;
using System.Numerics;

namespace DLTech.EthereumLib.Functions
{
	[Function("burn", "bool")]
	public class Burn : FunctionMessage
	{
		[Parameter("uint256", "_value", 1)]
		public BigInteger Amount { get; set; }
	}
}
