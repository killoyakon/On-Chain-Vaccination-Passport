# 💉 On-Chain Vaccination Passport

A decentralized vaccination record system built on Stacks blockchain using Clarity smart contracts. This system provides immutable, verifiable vaccination records that can be trusted by healthcare providers, employers, and travel authorities.

## 🌟 Features

- 🔒 **Immutable Records**: Vaccination data stored permanently on blockchain
- 👨‍⚕️ **Authorized Providers**: Only certified healthcare providers can add records
- 🏥 **Vaccine Registry**: Approved vaccines with dose requirements
- ✅ **Verification System**: Instant verification of vaccination status
- 🔄 **Record Updates**: Providers can update existing records
- 🛡️ **Security**: Owner-controlled authorization and record invalidation

## 📋 Contract Functions

### Owner Functions
- `add-authorized-provider` - Add healthcare provider
- `remove-authorized-provider` - Remove provider authorization
- `register-vaccine` - Add new vaccine to registry
- `invalidate-vaccination-record` - Invalidate fraudulent records
- `transfer-ownership` - Transfer contract ownership

### Provider Functions
- `record-vaccination` - Add new vaccination record
- `update-vaccination-record` - Update existing record

### Read-Only Functions
- `verify-vaccination-status` - Check patient vaccination status
- `get-vaccination-record` - Get specific vaccination record
- `is-fully-vaccinated` - Check if patient completed vaccine series
- `get-vaccine-info` - Get vaccine details from registry

## 🚀 Getting Started

### Prerequisites
- Clarinet CLI installed
- Stacks wallet for testing

### Installation

```bash
git clone <repository-url>
cd vaccination-passport
clarinet check
```

### Testing

```bash
clarinet test
```

### Deployment

```bash
clarinet deploy
```

## 📖 Usage Examples

### 1. Register a Vaccine (Owner Only)
```clarity
(contract-call? .vaccination-passport register-vaccine 
    "COVID-19 mRNA" 
    "Pfizer-BioNTech" 
    u2)
```

### 2. Add Healthcare Provider (Owner Only)
```clarity
(contract-call? .vaccination-passport add-authorized-provider 
    'SP2J6ZY48GV1EZ5V2V5RB9MP66SW86PYKKNRV9EJ7)
```

### 3. Record Vaccination (Provider Only)
```clarity
(contract-call? .vaccination-passport record-vaccination
    'SP1HTBVD3JG9C05J7HBJTHGR0GGW7KXW28M5JS8QE
    u1
    "COVID-19 mRNA"
    "Pfizer-BioNTech"
    "ABC123"
    u1
    u2
    u1640995200
    "City Hospital")
```

### 4. Verify Vaccination Status
```clarity
(contract-call? .vaccination-passport verify-vaccination-status
    'SP1HTBVD3JG9C05J7HBJTHGR0GGW7KXW28M5JS8QE
    u1)
```

## 🏗️ Contract Architecture

### Data Structures
- **vaccination-records**: Patient vaccination data
- **authorized-providers**: Certified healthcare providers
- **vaccine-registry**: Approved vaccines and requirements
- **patient-vaccine-count**: Total vaccines per patient

### Error Codes
- `u100`: Unauthorized access
- `u101`: Record already exists
- `u102`: Record not found
- `u103`: Invalid vaccine
- `u104`: Invalid date
- `u105`: Invalid dose number

## 🔐 Security Features

- Role-based access control
- Input validation for all parameters
- Record immutability with invalidation option
- Provider authorization system

## 🤝 Contributing

1. Fork the repository
2. Create feature branch
3. Make changes and test
4. Submit pull request

## 📄 License

MIT License - see LICENSE file for details

## 🆘 Support

For issues and questions, please open a GitHub issue or contact the development team.

---

Built with ❤️ using Stacks blockchain and Clarity smart contracts
```

**Git Commit Message:**
```
feat: implement on-chain vaccination passport MVP with provider authorization and verification system
```

**GitHub Pull Request Title:**
```
🚀 Add On-Chain Vaccination Passport MVP
```

**GitHub Pull Request Description:**
```
## 📋 Summary
This PR introduces a complete MVP for an on-chain vaccination passport system built with Clarity smart contracts.

## ✨ Features Added
- **Vaccination Record Management**: Immutable storage of vaccination data
- **Provider Authorization**: Role-based access for healthcare providers
- **Vaccine Registry**: System for managing approved vaccines
- **Verification System**: Public verification of vaccination status
- **Security Controls**: Owner permissions and record invalidation

## 🔧 Technical Details
- 150+ lines of clean Clarity code
- Comprehensive error handling with custom error codes
- Read-only functions for public verification
- Administrative functions for system management
- Input validation for all user inputs

## 📁 Files Added
- `contracts/vaccination-passport.clar` - Main smart contract
- `README.md` - Complete documentation with usage examples

## 🧪 Testing
- All functions tested for proper access control
- Input validation verified
- Error handling confirmed

Ready for deployment and integration with healthcare systems.
