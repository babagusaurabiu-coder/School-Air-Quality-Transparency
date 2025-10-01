# School Air Quality Transparency System

A comprehensive blockchain-based indoor air quality monitoring system for educational institutions, providing real-time environmental data, ventilation optimization, and community engagement through smart contracts.

## Overview

The School Air Quality Transparency System leverages blockchain technology to create a transparent, decentralized platform for monitoring and improving indoor air quality in schools. This system provides stakeholders with real-time environmental data, automated ventilation recommendations, exposure notifications, and community-driven improvement initiatives.

## Key Features

### 🌡️ Real-Time Environmental Monitoring
- **Multi-Parameter Sensing**: Continuous monitoring of CO2, PM2.5, VOCs, humidity, and temperature
- **Sensor Calibration Tracking**: Built-in metadata for sensor accuracy and calibration schedules
- **Data Integrity**: Blockchain-secured environmental readings with tamper-proof timestamps

### 🌬️ Intelligent Ventilation Optimization
- **HVAC Runtime Analysis**: Automated recommendations for optimal heating, ventilation, and air conditioning operation
- **Predictive Maintenance**: Smart scheduling for filter replacements based on air quality trends
- **Energy Efficiency**: Balance between air quality improvement and energy consumption

### 🚨 Proactive Health Notifications
- **Real-Time Alerts**: Immediate notifications when air quality thresholds are exceeded
- **Exposure Duration Tracking**: Monitor cumulative exposure to poor air quality conditions
- **Actionable Guidance**: Specific recommendations for improving indoor environments

### 📊 Community Engagement Platform
- **Public Dashboards**: Transparent air quality data accessible to parents, teachers, and administrators
- **Micro-Grant System**: Community-funded improvement initiatives for schools with persistent air quality issues
- **Stakeholder Participation**: Democratic voting on improvement priorities and fund allocation

## Smart Contract Architecture

### 1. IAQ Sensor Network Contract (`iaq-sensor-network.clar`)
- Manages sensor registration and data collection
- Handles calibration metadata and sensor validation
- Provides secure data storage and retrieval mechanisms
- Implements access controls for authorized sensors and data consumers

### 2. Ventilation Optimization Contract (`ventilation-optimization.clar`)
- Analyzes environmental data to generate HVAC recommendations
- Schedules predictive maintenance based on usage patterns
- Tracks energy efficiency metrics and optimization outcomes
- Provides automated alerts for system maintenance needs

### 3. Exposure Notifications Contract (`exposure-notifications.clar`)
- Monitors air quality thresholds and exposure durations
- Generates real-time alerts for stakeholders
- Tracks historical exposure patterns and trends
- Implements notification preferences and delivery mechanisms

### 4. Community Dashboard and Grants Contract (`community-dashboard-and-grants.clar`)
- Manages public data visualization and transparency
- Facilitates micro-grant applications and community funding
- Implements voting mechanisms for improvement priorities
- Tracks funding allocation and project outcomes

## Technical Specifications

### Blockchain Platform
- **Platform**: Stacks Blockchain
- **Language**: Clarity Smart Contracts
- **Network**: Mainnet/Testnet compatible

### Data Types Monitored
- **CO2 Levels**: Parts per million (ppm)
- **PM2.5**: Particulate matter concentration (µg/m³)
- **VOCs**: Volatile organic compounds (ppb)
- **Temperature**: Celsius/Fahrenheit
- **Humidity**: Relative humidity percentage

### Threshold Standards
- **CO2**: Alert at >1000 ppm, Critical at >1500 ppm
- **PM2.5**: Alert at >25 µg/m³, Critical at >50 µg/m³
- **VOCs**: Alert at >500 ppb, Critical at >1000 ppb
- **Humidity**: Optimal range 30-60% RH

## Installation & Development

### Prerequisites
- Clarinet CLI installed
- Node.js and npm/yarn
- Git for version control

### Setup
1. Clone the repository
2. Install dependencies: `npm install`
3. Run tests: `clarinet test`
4. Check contracts: `clarinet check`
5. Deploy locally: `clarinet console`

### Testing
The system includes comprehensive unit tests for all smart contracts, covering:
- Sensor data validation and storage
- Ventilation optimization algorithms
- Notification trigger conditions
- Grant allocation and voting mechanisms

## Usage Examples

### Sensor Data Submission
```clarity
(contract-call? .iaq-sensor-network submit-reading 
  "school-001" 
  "classroom-101" 
  u1200 ;; CO2 ppm
  u15   ;; PM2.5 µg/m³
  u300  ;; VOCs ppb
  u22   ;; Temperature °C
  u45   ;; Humidity %
)
```

### Retrieve Optimization Recommendations
```clarity
(contract-call? .ventilation-optimization get-hvac-recommendations "school-001")
```

### Check Alert Status
```clarity
(contract-call? .exposure-notifications get-current-alerts "school-001")
```

## Stakeholder Benefits

### For Schools
- **Data-Driven Decisions**: Make informed choices about ventilation and air quality improvements
- **Automated Monitoring**: Reduce manual oversight while maintaining high environmental standards
- **Community Trust**: Demonstrate commitment to student health through transparent reporting

### For Parents and Students
- **Health Transparency**: Access real-time information about classroom air quality
- **Exposure Awareness**: Understand environmental conditions affecting daily learning
- **Improvement Participation**: Contribute to community-driven enhancement initiatives

### For Administrators
- **Compliance Tracking**: Meet regulatory requirements with automated documentation
- **Resource Optimization**: Balance air quality improvements with operational budgets
- **Performance Analytics**: Track improvement outcomes and return on investment

### For Community
- **Collective Action**: Pool resources for meaningful environmental improvements
- **Democratic Participation**: Vote on priorities and fund allocation
- **Transparency**: Access to comprehensive air quality data and improvement progress

## Roadmap

### Phase 1: Core Infrastructure (Current)
- Deploy basic smart contracts
- Implement sensor data collection
- Establish alert mechanisms

### Phase 2: Advanced Analytics
- Machine learning integration for predictive insights
- Enhanced optimization algorithms
- Cross-school comparison features

### Phase 3: Mobile Applications
- Real-time mobile alerts
- Parent/student dashboard apps
- Community engagement platforms

### Phase 4: Integration Expansion
- HVAC system direct integration
- Weather data correlation
- Regional air quality networks

## Contributing

We welcome contributions from developers, educators, and environmental advocates. Please review our contribution guidelines and submit pull requests for:
- Smart contract improvements
- Testing enhancements
- Documentation updates
- Feature suggestions

## License

This project is licensed under the MIT License - see the LICENSE file for details.

## Contact

For questions, support, or collaboration opportunities, please reach out through our GitHub repository or community channels.

---

*Building healthier learning environments through blockchain transparency and community engagement.*
