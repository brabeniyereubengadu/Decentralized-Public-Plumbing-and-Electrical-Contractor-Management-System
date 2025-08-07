# Decentralized Public Plumbing and Electrical Contractor Management System

A comprehensive blockchain-based system for managing plumbing and electrical contractor licensing, permits, inspections, and apprenticeship programs using Clarity smart contracts on the Stacks blockchain.

## System Overview

This system consists of five interconnected smart contracts that manage the complete lifecycle of plumbing and electrical contractor operations:

### 1. Master Plumber Licensing Contract (`plumber-licensing.clar`)
- Issues and tracks licenses for plumbing contractors and journeymen
- Manages license renewals and status updates
- Tracks contractor qualifications and certifications
- Handles license suspensions and reinstatements

### 2. Electrical Contractor Certification Contract (`electrical-certification.clar`)
- Manages licenses for electricians and electrical installation companies
- Tracks different certification levels (apprentice, journeyman, master)
- Handles specialty certifications (industrial, residential, commercial)
- Manages certification renewals and continuing education requirements

### 3. Permit Application Processing Contract (`permit-processing.clar`)
- Streamlines applications for plumbing and electrical work permits
- Tracks permit status from application to completion
- Manages permit fees and payments
- Links permits to licensed contractors

### 4. Code Compliance Inspection Contract (`inspection-management.clar`)
- Schedules and tracks inspections to ensure work meets building codes
- Manages inspector assignments and availability
- Records inspection results and compliance status
- Handles re-inspections and violations

### 5. Apprenticeship Program Coordination Contract (`apprenticeship-coordination.clar`)
- Manages training programs for new plumbers and electricians
- Tracks apprentice progress and milestones
- Coordinates with licensed contractors for mentorship
- Manages program completion and certification pathways

## Key Features

### Transparency and Accountability
- All licensing, permits, and inspections are recorded on-chain
- Public verification of contractor credentials
- Immutable audit trail of all activities

### Automated Workflows
- Smart contract automation reduces manual processing
- Automatic status updates and notifications
- Streamlined renewal processes

### Compliance Management
- Built-in code compliance checking
- Automated violation tracking
- Integration between permits and inspections

### Training and Development
- Comprehensive apprenticeship program management
- Progress tracking and milestone verification
- Seamless transition from apprentice to licensed contractor

## Contract Architecture

Each contract is designed to be independent while maintaining logical connections:

- **Data Integrity**: All contracts use consistent data structures and validation
- **Access Control**: Role-based permissions for different user types
- **Error Handling**: Comprehensive error codes and validation
- **Upgradability**: Contracts designed with future enhancements in mind

## Getting Started

### Prerequisites
- Clarinet CLI installed
- Node.js and npm for testing
- Basic understanding of Clarity smart contracts

### Installation
\`\`\`bash
git clone <repository-url>
cd contractor-management-system
npm install
clarinet check
\`\`\`

### Running Tests
\`\`\`bash
npm test
\`\`\`

### Deployment
\`\`\`bash
clarinet deploy
\`\`\`

## Usage Examples

### Issuing a Plumber License
\`\`\`clarity
(contract-call? .plumber-licensing issue-license
'SP1HTBVD3JG9C05J7HBJTHGR0GGW7KX17ECNWWALK
"John Smith"
"Master Plumber"
u365)
\`\`\`

### Applying for a Permit
\`\`\`clarity
(contract-call? .permit-processing apply-for-permit
"Residential Plumbing Installation"
'SP1HTBVD3JG9C05J7HBJTHGR0GGW7KX17ECNWWALK
u1000000)
\`\`\`

### Scheduling an Inspection
\`\`\`clarity
(contract-call? .inspection-management schedule-inspection
u1
'SP2HTBVD3JG9C05J7HBJTHGR0GGW7KX17ECNWWALK
u1640995200)
\`\`\`

## Error Codes

Each contract uses standardized error codes:
- `u100-199`: General validation errors
- `u200-299`: Permission and access errors
- `u300-399`: Business logic errors
- `u400-499`: Data integrity errors
- `u500-599`: System errors

## Contributing

1. Fork the repository
2. Create a feature branch
3. Write tests for new functionality
4. Ensure all tests pass
5. Submit a pull request

## License

This project is licensed under the MIT License - see the LICENSE file for details.

## Support

For questions and support, please open an issue in the GitHub repository.
