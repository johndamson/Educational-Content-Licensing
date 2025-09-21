# Educational Content Licensing Smart Contract

A comprehensive Clarity smart contract for managing educational content licensing, payments, and access control on the Stacks blockchain.

## Overview

This smart contract enables educators and content creators to monetize their educational materials through a decentralized licensing system. Users can purchase time-based licenses to access educational content, while creators earn revenue through automated payments.

## Features

### Core Functionality
- **Content Creation**: Educators can create and manage educational content with custom pricing
- **License Purchasing**: Users can purchase monthly licenses (1-12 months) for educational content
- **License Extension**: Extend existing licenses without losing access time
- **Access Control**: Automatic validation of license validity and content access
- **Revenue Distribution**: Automatic payment splitting between creators and platform

### Security & Validation
- **Input Sanitization**: All user inputs are validated and sanitized
- **Access Controls**: Creator-only content management, owner-only platform administration
- **Error Handling**: Comprehensive error codes and validation checks
- **Bounds Checking**: Protection against overflow and invalid data

## Contract Architecture

### Data Storage
```clarity
content-registry     // Stores content metadata and earnings
user-licenses       // Tracks user license purchases and expiration
creator-stats       // Creator performance analytics
```

### Constants
- `CONTRACT_OWNER`: Contract deployer with administrative privileges
- `ERR_*`: Comprehensive error code system
- `MAX_*`: Input validation limits

## Public Functions

### Content Management
- `create-content(title, description, price-per-month)` - Create new educational content
- `update-content(content-id, new-title, new-description, new-price)` - Update content details
- `toggle-content-status(content-id)` - Enable/disable content

### Licensing
- `purchase-license(content-id, duration-months)` - Purchase content license
- `extend-license(content-id, additional-months)` - Extend existing license

### Administration
- `update-platform-fee(new-fee)` - Update platform fee percentage (owner only)

## Read-Only Functions

- `has-valid-license(user, content-id)` - Check license validity
- `get-content-info(content-id)` - Retrieve content details
- `get-license-info(user, content-id)` - Get user license information
- `get-creator-stats(creator)` - View creator analytics
- `get-platform-fee()` - Current platform fee percentage

## Usage Examples

### Creating Content
```clarity
(contract-call? .educational-licensing create-content 
  u"Advanced Calculus Course" 
  u"Comprehensive calculus tutorial with examples" 
  u1000000) ;; 1 STX per month
```

### Purchasing License
```clarity
(contract-call? .educational-licensing purchase-license 
  u1     ;; content-id
  u3)    ;; 3 months duration
```

### Checking Access
```clarity
(contract-call? .educational-licensing has-valid-license 
  'SP1ABC...123 
  u1)
```

## Economic Model

### Payment Flow
1. User pays total license cost (price × duration)
2. Platform fee deducted (default 5%)
3. Remaining amount transferred to content creator
4. License activated with expiration date

### Fee Structure
- **Platform Fee**: 5% default (adjustable by contract owner, max 20%)
- **Creator Revenue**: 95% of payment (after platform fee)
- **Payment Token**: STX (native Stacks token)

## Error Codes

| Code | Constant | Description |
|------|----------|-------------|
| u100 | ERR_UNAUTHORIZED | Unauthorized access attempt |
| u101 | ERR_NOT_FOUND | Content or license not found |
| u102 | ERR_ALREADY_EXISTS | Duplicate content creation |
| u103 | ERR_INSUFFICIENT_PAYMENT | Payment amount too low |
| u104 | ERR_EXPIRED_LICENSE | License has expired |
| u105 | ERR_INVALID_DURATION | Invalid duration parameter |
| u106 | ERR_INVALID_INPUT | Invalid input data |

## Security Features

- **Input Validation**: All parameters validated before processing
- **Access Control**: Role-based permissions for sensitive operations
- **Overflow Protection**: Safe arithmetic operations throughout
- **Authorization Checks**: Creator and owner verification
- **Data Sanitization**: Clean input data before storage

## Deployment

1. Deploy contract to Stacks blockchain
2. Contract owner can configure platform fee
3. Creators can begin adding educational content
4. Users can purchase licenses and access content

## License Duration

- **Minimum**: 1 month
- **Maximum**: 12 months per transaction
- **Block Calculation**: ~4,320 blocks per month (based on Stacks block time)
- **Extension**: Unlimited extensions allowed

## Development Notes

- **Language**: Clarity 2.0
- **Blockchain**: Stacks
- **Token Standard**: Native STX transfers
- **Contract Size**: 299 lines (optimized for gas efficiency)

## Testing Recommendations

1. Test content creation with various input sizes
2. Verify payment calculations and distributions
3. Test license expiration and extension logic
4. Validate access control permissions
5. Check error handling for edge cases

## Future Enhancements

- Multi-token support (SIP-010 tokens)
- Bulk license purchases
- Content rating and review system
- Subscription management
- Advanced analytics dashboard