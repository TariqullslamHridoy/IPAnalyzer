# IPAnalyzer
IPAnalyzer is an IP Address Tracker OSINT ethical hacking tool built for Linux distributions


# 🛡️ IPAnalyzer v2.0 (Pro Edition)

![License](https://img.shields.io/badge/License-BSL--1.0-blue.svg)
![Python](https://img.shields.io/badge/Language-Bash-green.svg)
![OSINT](https://img.shields.io/badge/Category-OSINT-red.svg)

**IPAnalyzer** is a precision OSINT (Open Source Intelligence) tool designed for Private Investigators, Security Researchers, and Ethical Hackers. It leverages the **Tor Network** to provide anonymous IP tracking and deep geolocation data without revealing the investigator's identity.

---

## 🛠️ Key Features
- **🕵️ Professional Anonymity:** All requests are routed through Tor SOCKS5 proxy to prevent DNS leaks.
- **🔄 Dynamic Identity:** Ability to request a new Tor circuit (NEWNYM) for every search to bypass API rate limits.
- **📍 Deep Geolocation:** Fetches City, Region, Country, ISP, ASN, Timezone, and more.
- **🗺️ Visual Mapping:** Generates direct Google Maps links for the target's coordinates.
- **⚡ Automated Setup:** Auto-checks and installs missing dependencies (`tor`, `jq`, `curl`, `netcat`).
- **🚀 Optimized Logic:** Multi-API fallback system (uses `ipapi.co` and `ipwho.is`) to ensure results even if one provider is down.

---

## 📥 Installation

```bash
# Clone the repository
git clone [https://github.com/Tariqullslamhridoy/IPAnalyzer](https://github.com/Tariqullslamhridoy/IPAnalyzer)

# Change directory
cd IPAnalyzer

# Give execution permission
chmod +x ipanalyzer.sh

# Run the tool
./ipanalyzer.sh
