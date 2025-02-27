# System Smart Contract

## Development & Deployment Instructions

### Environment Setup

To set up `foundry` environment, run:

```bash
curl -L https://foundry.paradigm.xyz | bash
source ~/.bashrc
foundryup
```

Install dependencies:

```bash
forge install
```

### Development & Testing

To compile artifacts:

```bash
forge compile
```

To run the test suite:

```bash
forge test -vv
```

To inspect the call tree:

```bash
forge test -vvvv
```
