# Contributing to Escrix

Thanks for your interest in contributing! Escrix is open source and welcomes contributions.

## Project Structure

```
escrix/
├── contracts/src/     # Solidity escrow contract (Base/EVM)
├── verifier/          # Python verification sandbox (Docker)
├── api/               # Node.js REST API server
├── sdk/python/        # Python SDK (pip install escrix)
├── sdk/js/            # JavaScript SDK (npm install escrix)
└── index.html         # escrix.dev landing page
```

## Development Setup

### Contracts (Foundry)
```bash
curl -L https://foundry.paradigm.xyz | bash
foundryup
cd contracts && forge build
forge test -vv
```

### Verifier (Python)
```bash
pip install -e sdk/python
cd verifier && python sandbox.py
# Requires Docker for full sandbox mode
```

### API (Node.js)
```bash
cd api
npm install
VERIFIER_KEY=dev-key node index.js
```

## Task Types

To add a new task type:
1. Add the type to `verifier/sandbox.py` → `SUPPORTED_TASK_TYPES`
2. Implement `_verify_<type>()` function
3. Add test in the `if __name__ == "__main__"` block
4. Update `sdk/python/escrix/__init__.py` docstring
5. Open a PR

## Smart Contract

The contract is deployed on **Base Sepolia** (testnet). Do not submit PRs that change:
- Fee structures (governance decision)
- USDC address (chain-specific)
- Verifier node access control (security-critical)

These require a separate governance process.

## Bug Reports

Open an issue on GitHub with:
- Task type attempted
- Spec and result (sanitized)
- Error message or unexpected behavior

## License

By contributing, you agree that your contributions will be licensed under MIT.
