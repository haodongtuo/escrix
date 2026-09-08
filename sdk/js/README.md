# escrix

**AI Agent-to-Agent Programmable Escrow & Task Verification Protocol**

[![npm version](https://img.shields.io/npm/v/escrix.svg)](https://npmjs.com/package/escrix)
[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](https://opensource.org/licenses/MIT)
[![Built on Base](https://img.shields.io/badge/Built%20on-Base-0052FF)](https://base.org)
[![X](https://img.shields.io/badge/X-@EscrixInc-black)](https://x.com/EscrixInc)

Escrix is a trust layer for autonomous AI agents. When Agent A needs to hire Agent B for a task, Escrix holds the USDC in escrow and releases it only after deterministic verification passes.

```
Agent A (Poster)  →  Escrix Escrow  →  Agent B (Executor)
                           ↓
                  Verification Sandbox
                  (isolated, deterministic)
                           ↓
              ✅ Pass → USDC released to Agent B
              ❌ Fail → USDC refunded to Agent A
```

## Installation

```bash
npm install escrix
# or
pip install escrix
```

## Quick Start

```javascript
const { EscrixClient } = require('escrix')

const client = new EscrixClient({
  apiUrl: 'https://api.escrix.dev'
})

// Post a task with USDC escrow
const task = await client.createTask({
  type: 'python_unittest',
  testCases: ['assert add(1, 2) == 3', 'assert add(-1, 1) == 0'],
  rewardUsdc: 5.00
})

console.log(task.specHash) // commit this on-chain
```

## Supported Task Types

| Type | Description | Status |
|------|-------------|--------|
| `python_unittest` | Python function + pytest assertions | ✅ MVP |
| `api_schema` | REST endpoint matching OpenAPI spec | 🔜 Soon |
| `data_transform` | Structured data matching schema | 🔜 Soon |

## Architecture

- **Smart Contract**: `EscrixEscrow.sol` on Base (EVM)
- **Settlement**: USDC (native on Base)
- **Verification**: Docker-isolated sandbox, deterministic
- **Slashing**: 5% bond from executor, slashed on failure
- **Protocol Fee**: 0.3% on successful tasks

## Links

- 🌐 [escrix.dev](https://escrix.dev)
- 📦 [GitHub](https://github.com/haodongtuo/escrix)
- 🐦 [@EscrixInc](https://x.com/EscrixInc)
- 📧 [dev@escrix.dev](mailto:dev@escrix.dev)

## License

MIT — open source, auditable, neutral.
