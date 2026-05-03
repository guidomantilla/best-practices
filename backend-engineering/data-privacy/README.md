# Data Privacy & Compliance for Developers

Practical guide to data protection laws and industry standards worldwide. Written for offshore developers serving clients in US, EU, Brazil, Colombia, and regulated industries (health, finance, payments, AI/ML).

---

## 1. Regulations Map

### By Region

| Region | Law | Data Protected | Breach Notification |
|---|---|---|---|
| **US** | HIPAA | Health (PHI) | 60 days to HHS |
| **US** | GLBA | Financial (NPI) | As soon as possible |
| **US** | CCPA/CPRA | Personal data (CA consumers) | Expeditiously |
| **US** | FERPA | Education records | No federal requirement |
| **US** | COPPA | Children under 13 | FTC notification |
| **EU** | GDPR | All personal data | 72 hours to supervisory authority |
| **Brazil** | LGPD | All personal data | 3 business days to ANPD |
| **Colombia** | Ley 1581/2012 | All personal data (Habeas Data) | 15 business days to SIC |

### By Industry

| Standard | Scope | Nature |
|---|---|---|
| **PCI DSS 4.0** | Payment card data (PAN, CVV, cardholder data) | Industry standard, contractually enforced |
| **SOC 2** | Service organization controls (security, availability, confidentiality) | Audit framework, client-required |
| **EU AI Act** | AI/ML systems operating in or affecting EU | Regulation, effective August 2026 |

---

## 2. US Federal Laws

### 2.1 Health Data — HIPAA

#### What qualifies as PHI
Any individually identifiable health information: name + diagnosis, SSN + treatment records, email + prescription history, biometric data tied to a patient.

#### Developer requirements
- **Encryption**: mandatory in transit (TLS 1.2+) and at rest (AES-256)
- **Access controls**: RBAC, least privilege, MFA for systems handling PHI
- **Audit trail**: log who accessed what, when, and from where
- **BAA** (Business Associate Agreement): required if you're a third party processing PHI
- **Breach notification**: 60 days to notify HHS; individuals without unreasonable delay
- **Data minimization**: only access/store the PHI you actually need
- **Automatic session timeout**: enforce session expiration on systems with PHI access

#### Common violations to avoid
- Logging PHI in plaintext (application logs, error messages, debug output)
- Storing PHI in non-encrypted databases or backups
- Sending PHI via unencrypted email or messaging
- Hardcoding credentials that grant access to PHI systems

### 2.2 Financial Data — GLBA

#### What qualifies as NPI
Any personally identifiable financial information: account numbers, income, SSN, transaction history, credit/debit card data.

#### Developer requirements
- **Safeguards Rule**: documented information security plan
- **Encryption**: financial data encrypted in transit and at rest
- **Access controls**: based on business need-to-know
- **Incident response plan**: documented and tested
- **Risk assessments**: periodic evaluation of threats and controls
- **Vendor management**: third-party servicers must meet same security standards
- **Privacy notices**: application must disclose what data is collected and how it's shared

### 2.3 Consumer Data — CCPA/CPRA + State Laws

As of 2026, 20+ US states have comprehensive privacy laws. CCPA/CPRA (California) is the most stringent.

#### Developer requirements
- **Right to delete**: system must support full deletion of a user's personal data
- **Right to access/export**: users can request a copy of their data (data portability)
- **Opt-out mechanism**: users can opt out of sale/sharing of their data
- **Non-discrimination**: cannot degrade service for users who exercise their rights
- **Minors under 16**: opt-in consent required before processing
- **Sensitive data**: explicit opt-in consent required (health, financial, geolocation, race, biometrics)
- **Neural data** (2026): now classified as sensitive personal information
- **Automated decision-making (ADMT)**: disclosure requirements and consumer opt-out rights

#### What this means in code
- Build a `/me/data` endpoint (or equivalent) for data export
- Build a `/me/delete` endpoint for account/data deletion
- Implement consent management (opt-in/opt-out state per user)
- Track data lineage — know where each piece of PII lives (DB, cache, logs, backups, third-party)
- Define and enforce data retention policies — don't store forever

### 2.4 Education Data — FERPA

#### Developer requirements
- No disclosure of student records without written consent
- Students/parents can inspect and correct their records
- Directory information (name, email) may be disclosed only if students are notified and given opt-out opportunity
- Access controls limiting who can view student records

### 2.5 Children's Data — COPPA

#### Developer requirements
- Verifiable parental consent before collecting data from children under 13
- Clear, understandable privacy notice
- Data minimization — collect only what's necessary
- Secure storage and deletion upon request
- No behavioral advertising targeted at children

---

## 3. EU — GDPR

The General Data Protection Regulation. Applies to any processing of data from individuals in the EU, regardless of where the company is located.

### Core principles
- **Lawfulness**: must have a legal basis to process (consent, contract, legitimate interest, legal obligation, vital interest, public task)
- **Purpose limitation**: collect data only for specified, explicit purposes
- **Data minimization**: only what's necessary
- **Accuracy**: keep data correct and up to date
- **Storage limitation**: don't keep it longer than needed
- **Integrity & confidentiality**: protect against unauthorized access, loss, destruction
- **Accountability**: you must demonstrate compliance, not just claim it

### Developer requirements
- **Privacy by Design**: embed privacy into architecture from the start, not as an afterthought
- **DPIA** (Data Protection Impact Assessment): mandatory for high-risk processing (profiling, large-scale sensitive data, systematic monitoring)
- **Consent**: must be freely given, specific, informed, unambiguous. No pre-checked boxes. Easy withdrawal.
- **Right to erasure** ("right to be forgotten"): delete personal data on request
- **Right to portability**: export data in machine-readable format
- **Right to object**: users can object to processing based on legitimate interest
- **Data breach notification**: 72 hours to supervisory authority; without undue delay to individuals if high risk
- **DPO** (Data Protection Officer): required for public authorities, large-scale monitoring, or large-scale sensitive data processing
- **Cross-border transfers**: require adequacy decisions, SCCs, or BCRs for data leaving EEA

### What GDPR adds beyond CCPA
- **Legal basis required** — you need a reason to process, not just an opt-out
- **72-hour breach notification** — tighter than any US law
- **DPIAs** — formal risk assessments before processing
- **Accountability principle** — must prove compliance proactively
- **Fines**: up to €20M or 4% of global annual turnover (whichever is higher)

---

## 4. Brazil — LGPD

Lei Geral de Proteção de Dados. Modeled after GDPR. Applies to any processing of data from individuals in Brazil, regardless of company location.

### Developer requirements
- **Legal basis**: 10 bases available (consent, contract, legitimate interest, legal obligation, credit protection, etc.)
- **Consent**: must be free, informed, unambiguous, for specific purposes. Easy revocation.
- **Data subject rights**: access, correction, anonymization, blocking, deletion, portability
- **Response times**: detailed access within 15 days; corrections and deletions immediately
- **DPO**: controllers must appoint one (small businesses exempt unless high-risk processing)
- **Breach notification**: 3 business days to ANPD (national authority) and data subjects
- **Data minimization**: collect only what's necessary for the stated purpose
- **RNBD registration**: register databases containing personal data with the SIC's National Database Registry

### Penalties
- Up to 2% of revenue in Brazil, max R$50 million per violation

---

## 5. Colombia — Ley 1581/2012 (Habeas Data)

Constitutional right to privacy. Applies to any processing of personal data of individuals in Colombia.

### Core principles
Legality, purpose limitation, freedom, truthfulness, transparency, restricted access, security, confidentiality.

### Developer requirements
- **Prior express consent**: required before any data collection/processing
- **Privacy policy**: comprehensive, publicly accessible, clear language
- **Data subject rights**: know, update, rectify, delete data. Request portability.
- **RNBD registration**: register all databases with the Superintendence of Industry and Commerce (SIC)
- **Breach notification**: 15 business days to SIC from detection
- **Data classification**: Colombian law distinguishes public, semi-private, private, and sensitive data — each with different processing rules
- **Cross-border transfers**: only to countries with adequate protection levels, or with express consent

### Penalties
- Fines up to 2,000 minimum monthly wages (~COP $2.6B / ~$650K USD)
- Temporary or permanent database suspension

---

## 6. PCI DSS 4.0 — Payment Card Data

Industry standard for any system that stores, processes, or transmits cardholder data. Contractually required by card networks (Visa, Mastercard, etc.). Not a law but non-compliance means losing the ability to process payments.

### What qualifies as cardholder data
Primary Account Number (PAN), cardholder name, expiration date, service code, CVV/CVC, PIN.

### Developer requirements (v4.0.1, fully enforced 2025)
- **Never store CVV/CVC or PIN** after authorization — ever
- **Encrypt PAN** at rest (AES-256) and in transit (TLS 1.2+). Mask when displayed (show only last 4 digits)
- **MFA required** for all access to cardholder data environment
- **Passwords**: minimum 12 characters (8 if system doesn't support 12)
- **Secure development lifecycle**: security integrated into CI/CD, code reviews, SAST
- **Logging**: log all access to cardholder data and system components; retain logs 12 months (3 months immediately available)
- **Vulnerability scanning**: quarterly ASV scans, annual penetration testing
- **Script integrity**: monitor and validate payment page scripts (anti-skimming)
- **Segmentation**: isolate cardholder data environment from the rest of the network
- **Key management**: documented key rotation, split knowledge, dual control

### Key principle
Minimize what you store. If you don't need the card data, don't touch it — use a tokenization service (Stripe, Adyen, etc.) and let them handle PCI compliance.

---

## 7. SOC 2

Audit framework by AICPA. Not a law, but enterprise US clients almost universally require it. Evaluates your controls against 5 Trust Service Criteria.

### The 5 criteria
| Criteria | What it covers |
|---|---|
| **Security** (required) | Protection against unauthorized access (firewalls, access controls, MFA, encryption) |
| **Availability** | System uptime, DR, monitoring, incident response |
| **Processing Integrity** | Data processing is complete, valid, accurate, timely |
| **Confidentiality** | Data classified as confidential is protected (encryption, access controls) |
| **Privacy** | Personal data handled per privacy notice (collection, use, retention, disclosure, disposal) |

### Developer relevance
- SOC 2 Type II audits examine your controls **over time** (6-12 months), not a point-in-time snapshot
- You need to demonstrate: access controls, change management, monitoring, incident response, encryption, backup/recovery
- Automated evidence collection matters — auditors want logs, not word documents
- If your client requires SOC 2, your code and infrastructure are part of the audit scope

---

## 8. AI/ML Data — EU AI Act + Emerging Regulations

The EU AI Act (effective August 2, 2026) is the first comprehensive AI regulation. US states and other jurisdictions are following.

### Risk classification
| Risk Level | Examples | Requirements |
|---|---|---|
| **Unacceptable** | Social scoring, manipulative AI, real-time biometric ID in public spaces | Banned |
| **High-risk** | Healthcare AI, credit scoring, recruitment, law enforcement, critical infrastructure | Full compliance (see below) |
| **Limited risk** | Chatbots, AI-generated content | Transparency obligations (label as AI) |
| **Minimal risk** | Spam filters, video game AI | No specific requirements |

### Developer requirements for high-risk AI
- **Risk management system**: continuous monitoring and mitigation throughout lifecycle
- **Data governance**: high-quality, bias-controlled training datasets
- **Technical documentation**: full system documentation, retained 10 years
- **Human oversight**: human-in-the-loop for decisions with significant effects
- **Transparency**: users must know they're interacting with AI and how decisions are made
- **Conformity assessment**: completed before market placement
- **Post-market monitoring**: ongoing surveillance of system performance and risks

### Training data requirements
- **Copyright compliance**: check if data sources have copyright reservations; exclude or license accordingly
- **Data source disclosure**: must publish summary of content used for training
- **Bias assessment**: evaluate and mitigate bias in training datasets
- **Lawfully obtained**: verify legal basis for all training data

### General-purpose AI (GPAI) — all providers
- Provide technical documentation and usage instructions
- Comply with EU Copyright Directive
- Publish training data summaries
- Label AI-generated content

### CCPA 2026 additions for AI
- **Neural data**: classified as sensitive personal information
- **Automated decision-making (ADMT)**: consumers can opt out; businesses must disclose logic, data used, and expected outcomes

### Penalties
- EU AI Act: up to €35M or 7% of global annual turnover for unacceptable risk violations; €15M or 3% for high-risk breaches
- CCPA/ADMT: $7,500 per intentional violation

---

## 9. Cross-Cutting Checklist

Regardless of which law or standard applies, these are universal:

### Encryption
```
[x] TLS 1.2+ for all data in transit
[x] AES-256 for data at rest
[x] Encrypted backups
[x] Certificate management automated (no expired certs)
```

### Secrets Management
```
[x] Secrets in a secret manager (Vault, AWS Secrets Manager, GCP Secret Manager)
[x] Never in source code, logs, config files, or environment variables in plain text
[x] Rotate credentials on a defined schedule
[x] Scan repos for leaked secrets (gitleaks, trufflehog)
```

### Access Control
```
[x] RBAC + least privilege
[x] MFA for sensitive systems
[x] Service accounts scoped to minimum permissions
[x] Session timeouts enforced
[x] Authentication via industry standards (OAuth 2.0, OIDC, JWT)
```

### Audit & Logging
```
[x] Log access to sensitive data (who, what, when, from where)
[x] Never log PII/PHI/NPI in plaintext
[x] Centralized logging (ELK, Splunk, Datadog)
[x] Log retention policy defined and enforced
[x] Tamper-evident logs (immutable storage)
```

### User Rights
```
[x] Data export endpoint (portability)
[x] Data deletion endpoint (right to be forgotten / right to erasure)
[x] Consent management (opt-in/opt-out per purpose)
[x] Privacy notice/policy accessible in the application
[x] Breach notification process documented and tested
```

### Data Lifecycle
```
[x] Data classification defined (public, internal, confidential, restricted)
[x] Retention periods defined per data type
[x] Automated purge/anonymization after retention expires
[x] Data inventory — know where PII lives across all systems
[x] Third-party data sharing agreements in place
```

### Vulnerability Management
```
[x] Dependencies scanned for CVEs regularly
[x] SAST/DAST integrated in CI/CD
[x] Container images scanned before deployment
[x] Patch management process defined
[x] Penetration testing on a regular schedule
```

---

## 10. Penalties Overview

| Law/Standard | Max Penalty |
|---|---|
| HIPAA | $2.1M per violation category/year; criminal up to $250K + 10 years |
| GLBA | $100K per violation (institution); $10K (individual) |
| CCPA/CPRA | $7,500 per intentional violation; private right of action for breaches |
| FERPA | Loss of federal funding |
| COPPA | $53K+ per violation (FTC) |
| GDPR | €20M or 4% of global annual turnover |
| LGPD | 2% of revenue in Brazil, max R$50M |
| Ley 1581 (Colombia) | Up to 2,000 minimum monthly wages (~$650K USD); database suspension |
| PCI DSS | $5K-$100K/month in fines from card networks; loss of processing ability |
| EU AI Act | €35M or 7% of global turnover (unacceptable risk); €15M or 3% (high-risk) |

---

## References

### US
- https://www.hhs.gov/hipaa/for-professionals/privacy/laws-regulations/index.html
- https://www.techtarget.com/searchsecurity/tip/State-of-data-privacy-laws
- https://www.osano.com/us-data-privacy-laws
- https://www.wiley.law/alert-SECURE-Act-US-House-Introduces-New-National-Privacy-Framework
- https://iapp.org/resources/article/us-state-privacy-legislation-tracker

### EU
- https://secureprivacy.ai/blog/gdpr-compliance-2026
- https://www.cnil.fr/en/gdpr-developers-guide
- https://artificialintelligenceact.eu/
- https://www.augmentcode.com/guides/eu-ai-act-2026

### Brazil
- https://lgpd-brazil.info/
- https://iapp.org/news/a/an-overview-of-brazils-lgpd

### Colombia
- https://secureprivacy.ai/blog/colombia-data-protection-law
- https://www.dlapiperdataprotection.com/index.html?t=law&c=CO

### PCI DSS
- https://www.upguard.com/blog/pci-compliance
- https://securitywall.co/blog/pci-dss-v4-changes-2026

### SOC 2
- https://www.aicpa-cima.com/topic/audit-assurance/audit-and-assurance-greater-than-soc-2
