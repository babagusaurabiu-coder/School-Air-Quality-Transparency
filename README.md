# School Air Quality Transparency

## Overview

The School Air Quality Transparency project is a comprehensive blockchain-based system designed to monitor, analyze, and improve indoor air quality in educational institutions. This system leverages IoT sensors, smart contracts, and community engagement to create a transparent, data-driven approach to ensuring healthy learning environments.

## System Description

Indoor air quality significantly impacts student health, cognitive performance, and learning outcomes. Poor ventilation, high CO2 levels, particulate matter, and volatile organic compounds can lead to decreased concentration, increased illness, and long-term health issues. Our system addresses these challenges through continuous monitoring, automated recommendations, and community-driven improvements.

## Key Features

### Real-time Monitoring
- Continuous tracking of CO2, PM2.5, VOCs, humidity, and temperature
- Sensor calibration metadata for accuracy assurance
- Historical data collection and trend analysis

### Intelligent Ventilation Management
- HVAC runtime optimization based on air quality data
- Predictive maintenance scheduling for air filtration systems
- Energy-efficient ventilation recommendations

### Community Engagement
- Public dashboards with real-time air quality metrics
- Transparent reporting for parents, students, and administrators
- Micro-grant programs for air quality improvements

### Proactive Notifications
- Automated alerts for poor air quality conditions
- Actionable recommendations for immediate improvements
- Stakeholder communication system

## Smart Contracts

### 1. IAQ Sensor Network (`iaq-sensor-network.clar`)
Manages the network of indoor air quality sensors, handling data collection, calibration metadata, and sensor registration.

**Key Functions:**
- Sensor registration and authentication
- Data validation and storage
- Calibration tracking and alerts

### 2. Ventilation Optimization (`ventilation-optimization.clar`)
Provides intelligent recommendations for HVAC systems and maintenance scheduling based on air quality data.

**Key Functions:**
- HVAC runtime calculations
- Filter maintenance scheduling
- Energy efficiency optimization

### 3. Exposure Notifications (`exposure-notifications.clar`)
Monitors air quality thresholds and triggers notifications when conditions require attention.

**Key Functions:**
- Threshold monitoring
- Alert generation and distribution
- Stakeholder notification management

### 4. Community Dashboard and Grants (`community-dashboard-and-grants.clar`)
Manages public data access and administers micro-grants for air quality improvements.

**Key Functions:**
- Public data dashboard management
- Grant application and approval process
- Community engagement tracking

## Technical Architecture

### Blockchain Layer
- **Platform**: Stacks blockchain with Clarity smart contracts
- **Consensus**: Proof of Transfer (PoX) mechanism
- **Data Storage**: On-chain critical data, off-chain sensor readings

### IoT Integration
- **Sensors**: CO2, PM2.5, VOC, humidity, and temperature monitors
- **Connectivity**: Wi-Fi/LoRaWAN for data transmission
- **Edge Processing**: Local data validation and preprocessing

### Data Flow
1. Sensors collect environmental data
2. Data transmitted to blockchain via secure APIs
3. Smart contracts validate and process information
4. Automated analysis triggers recommendations
5. Public dashboards display real-time status
6. Notifications sent for critical conditions

## Benefits

### For Students
- Healthier learning environments
- Improved cognitive performance
- Reduced illness and absenteeism

### For Educators
- Data-driven facility management
- Transparent reporting tools
- Proactive maintenance scheduling

### For Administrators
- Cost-effective ventilation optimization
- Compliance with health standards
- Community trust through transparency

### For Parents
- Real-time visibility into school conditions
- Confidence in child's health and safety
- Participation in improvement initiatives

## Implementation Phases

### Phase 1: Core Infrastructure
- Deploy sensor network contracts
- Establish basic monitoring capabilities
- Create initial dashboard

### Phase 2: Intelligence Layer
- Implement optimization algorithms
- Deploy notification system
- Launch community features

### Phase 3: Community Engagement
- Activate grant program
- Expand public access
- Enable stakeholder participation

## Data Privacy and Security

- Personal information is never collected or stored
- All data is aggregated and anonymized
- Sensor IDs are cryptographically secured
- Public dashboards show only aggregate metrics

## Getting Started

### Prerequisites
- Clarinet CLI installed
- Node.js environment
- Git version control

### Installation
```bash
# Clone the repository
git clone https://github.com/frffrr745-collab/School-Air-Quality-Transparency.git

# Navigate to project directory
cd School-Air-Quality-Transparency

# Install dependencies
npm install

# Check contracts
clarinet check
```

### Testing
```bash
# Run contract tests
clarinet test

# Check syntax
clarinet check
```

## Contributing

We welcome contributions from the community! Please read our contributing guidelines and submit pull requests for any improvements.

## License

This project is licensed under the MIT License - see the LICENSE file for details.

## Contact

For questions, suggestions, or collaboration opportunities, please reach out through our GitHub repository issues.

---

*Building healthier learning environments through transparency and technology.*