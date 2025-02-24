# Digital Council DAO

A decentralized autonomous organization (DAO) smart contract built on Clarity, designed for transparent and secure governance.

## Features

- **Secure Motion Creation**: Submit and manage proposals with configurable grace periods
- **Democratic Voting**: Stake-weighted voting system with participation thresholds
- **Emergency Controls**: Admin-controlled emergency halt mechanism
- **Flexible Timing**: Configurable deliberation periods and motion intervals
- **Input Validation**: Comprehensive validation for all user inputs
- **Resource Management**: Built-in stake transfer and management system

## Contract Constants

### Timing Parameters
- Deliberation Period: 144 blocks (~24 hours)
- Motion Interval: 72 blocks (~12 hours)
- Minimum Grace Period: 12 blocks (~2 hours)
- Maximum Grace Period: 1440 blocks (~10 days)

### Threshold Parameters
- Minimum Motion Threshold: 100,000 tokens
- Participation Threshold: 300,000 tokens
- Total Token Supply: 1,000,000 tokens

### Content Limits
- Subject Length: 4-100 characters
- Brief Length: 10-500 characters

## Public Functions

### Motion Management
```clarity
(propose-motion (subject (string-ascii 100)) (brief (string-ascii 500)) (grace-period uint))
(withdraw-motion (motion-id uint))
(implement-motion (motion-id uint))
```

### Voting
```clarity
(cast-ballot (motion-id uint) (in-favor bool))
```

### Stake Management
```clarity
(transfer-stake (amount uint) (recipient principal))
```

### Administrative
```clarity
(set-halt (halt bool))
```

### Read-Only Functions
```clarity
(get-motion (motion-id uint))
(get-ballot (motion-id uint) (member principal))
(get-stake (account principal))
```

## Error Codes

- `ERR-UNAUTHORIZED` (u100): Unauthorized access attempt
- `ERR-MOTION-NOT-FOUND` (u101): Motion ID doesn't exist
- `ERR-INVALID-BALLOT` (u102): Invalid voting attempt
- `ERR-DUPLICATE-VOTE` (u103): User has already voted
- `ERR-MOTION-EXPIRED` (u104): Motion voting period has ended
- `ERR-ALREADY-IMPLEMENTED` (u105): Motion has already been implemented
- `ERR-MOTION-DEFEATED` (u106): Motion did not receive majority support
- `ERR-ZERO-STAKE` (u107): Attempted zero token operation
- `ERR-LOW-PARTICIPATION` (u108): Insufficient participation threshold
- `ERR-INVALID-MOTION` (u109): Invalid motion parameters
- `ERR-MOTION-IN-PROGRESS` (u110): Motion cooldown period not met
- `ERR-INVALID-SUBJECT` (u111): Invalid subject length
- `ERR-INVALID-GRACE-PERIOD` (u112): Invalid grace period duration

## Usage Example

1. Create a new motion:
```clarity
(propose-motion "Update Protocol" "Proposal to upgrade security features" u72)
```

2. Cast a vote:
```clarity
(cast-ballot u1 true)
```

3. Check motion status:
```clarity
(get-motion u1)
```

## Security Considerations

- All user inputs are validated for length and bounds
- Grace periods are enforced for implementation timing
- Stake-weighted voting prevents manipulation
- Emergency halt mechanism for critical situations
- Motion cooldown periods prevent spam

## Development

To deploy and test this contract:

1. Install the Clarity CLI
2. Deploy the contract to a local Stacks chain
3. Run the test suite
4. Monitor through local explorer
