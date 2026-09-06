# HealthPocket MVP PRD

**Version:** MVP v1.0\
**Status:** Pre-MVP Build\
**Timeline:** September–December 2026\
**Audience:** Codex, Claude Code, Cursor, Engineering Team

# Design Tokens/System

**Font:** Geomini
**Color palette:**
    **Primary:** Teal
    **Secondary:** Pinkish Red
    **Accent (minimal use only):** Brownish Gold — reserved for small highlight moments (e.g. tier-unlock states, premium/coverage indicators), not for large surface areas

*An existing interactive concept prototype exists for reference: https://healthpocket-dashboard.netlify.app/*

---

# 1. Product Overview

HealthPocket is a healthcare-focused savings platform that helps Nigerians prepare financially for medical expenses before emergencies occur.

Users create healthcare savings goals, contribute consistently, track progress, and eventually use those funds for healthcare-related spending.

The MVP is focused on validating saving behavior, not building a complete healthcare payments ecosystem.

---

# 2. MVP Objective

The primary objective of the MVP is to answer a single question:

**Will users consistently save money for healthcare through HealthPocket?**

The MVP should prioritize:

- User onboarding
- Savings goal creation
- Savings tracking
- Family savings collaboration
- User retention
- Product trust

The MVP should not prioritize:

- Complex banking integrations
- Automated investment systems
- Hospital settlement infrastructure
- Large-scale compliance architecture
- Enterprise-grade scaling

---

# 3. Product Principles

Every implementation decision should follow these principles:

### Simplicity First

Build the simplest solution that solves the problem.

### Reliability Over Complexity

A stable application is more valuable than advanced infrastructure.

### Validation Before Scale

Prove users want the product before building large systems.

### Partner Agnostic

Do not tightly couple architecture to any bank, hospital, payment provider, or asset manager.

### Mobile First

The mobile application is the primary product experience.

---

# 4. MVP Timeline

## Month 1 — September 2026

### Goal

Build a complete production-quality Flutter application interface.

No external integrations are required.

No real money movement is required.

No hospital partnerships are required.

### Features

#### Authentication

- Splash Screen
- Welcome Screen
- Sign Up
- Login
- OTP Verification
- Forgot Password

#### User Onboarding

- Personal Information
- KYC Screens
- Savings Goal Setup
- Healthcare Goal Setup

#### Dashboard

- Current Balance
- Savings Goal Progress
- Goal Summary
- Activity Feed

#### Savings

- Create Savings Goal
- Edit Savings Goal
- Pause Goal
- Resume Goal
- Record mock contributions
- View contribution history

#### Family Pocket

- Create Family Pocket
- Invite Member
- View Members
- Shared Goal Progress

#### Profile

- Account Information
- Security Settings
- Notification Preferences
- Help & Support

### Deliverables

By the end of Month 1:

- Complete Design System
- Complete Flutter UI
- Navigation Architecture
- State Management Structure
- Mock Data Integration
- End-to-End User Flow Demonstrations

The application should feel production-ready even when backed by mock data.

---

## Month 2 — October 2026

### Goal

Convert the UI into a functional MVP.

### Core Features

#### Authentication

- User Registration
- User Login
- Session Management
- Secure Authentication

#### User Profiles

- Profile Management
- KYC Data Storage

#### Savings Engine

- Create Goal
- Update Goal
- Pause and Resume Goal
- Record Contribution (Savings Record)
- Track Progress
- Goal Completion Logic

Each contribution must be linked to an individual goal or Family Pocket and
must update the relevant displayed progress. In Month 2, this is a product
record only; it must not imply real-money movement until a banking/payment
partner is integrated.

#### Activity Tracking

- Contribution (Savings Record) History
- User Activity Logs
- Goal and Family Pocket Activity Feed

#### Family Pocket

- Create Pocket
- Join Pocket
- Invite Members
- Shared Contributions
- Role Management
- Shared Contribution History and Shared Goal Progress

### Optional Partner Features

If hospital partnerships are secured during October:

#### Hospital Directory

- Partner Listing
- Hospital Profiles
- Search Functionality

No payment infrastructure should be built yet.

---

## Month 3 — November 2026

### Goal

Support active beta users.

### Focus Areas

- Stability
- Performance
- Analytics
- User Feedback
- Bug Fixes
- Product Refinement

### Partner Features (Only If Partnerships Exist)

#### QR Health Payments (Version 1)

- Hospital Whitelist
- QR Generation
- QR Validation
- Usage Tracking

Settlement can remain manual.

Avoid building complex payment infrastructure at this stage.

---

# 5. Core Features

## Individual Savings

Users can:

- Create healthcare savings goals
- Track progress toward goals
- View contribution history
- Monitor savings activity

---

## Family Pocket

Users can collaborate on shared healthcare savings goals.

### Roles

#### Admin

- Creates Pocket
- Invites Members
- Manages Goal

#### Contributor

- Contributes Funds
- Tracks Progress

#### Beneficiary

- Intended healthcare recipient

Role architecture should remain extensible.

---

# 6. Deferred Features

The following features are intentionally excluded from the MVP.

## Banking Integrations

Deferred until user behavior is validated.

## Automated Daily Debits

Deferred until banking partnerships exist.

## T-Bill Integration

Deferred until licensed asset-manager partnerships exist.

## Yield Tracking

Dependent on investment infrastructure.

## Automated Hospital Settlement

Deferred until hospital network expansion.

## Advanced Compliance Infrastructure

Deferred until scaling requirements justify implementation.

---

# 7. Core Data Models

## User

```text
User
- id
- firstName
- lastName
- email
- phone
- kycStatus
- createdAt
```

## Savings Goal

```text
SavingsGoal
- id
- userId
- title
- targetAmount
- currentAmount
- currency
- status (active | paused | completed)
- targetDate (optional)
- createdAt
- updatedAt
```

## Contribution (Savings Record)

```text
Contribution
- id
- contributorUserId
- savingsGoalId (optional; required when familyPocketId is absent)
- familyPocketId (optional; required when savingsGoalId is absent)
- amount
- currency
- status (recorded | completed | reversed)
- source (mock | manual | provider)
- note (optional)
- createdAt
```

`Contribution` is the canonical record for savings history and progress. A
goal or Family Pocket balance is calculated from its completed contributions;
do not maintain an unrelated transaction history. The `source` field keeps
the MVP provider-agnostic and makes future payment integrations replaceable.

## Family Pocket

```text
FamilyPocket
- id
- name
- goalAmount
- currentAmount
- currency
- status (active | completed)
- createdBy
- createdAt
- updatedAt
```

## Family Member

```text
FamilyMember
- id
- pocketId
- userId
- role
- joinedAt
```

## Activity Record

```text
ActivityRecord
- id
- userId
- activityType
- metadata
- relatedEntityType
- relatedEntityId
- createdAt
```

## Savings and Activity Rules

- Only completed contributions count toward a goal or Family Pocket balance.
- A paused goal accepts no new contributions until it is resumed.
- A contribution creates an associated activity record for the contributor;
  shared-pocket activity is visible to its members according to their role.
- Goal completion occurs when the calculated balance reaches or exceeds its
  target amount. The MVP must not create payouts, transfers, or settlements.

---

# 8. Technical Direction

## Frontend

- Flutter
- Mobile First

## Backend

- API Driven
- Modular Monolith

## Database

- Use either Firestore (a document database) or a relational database, based
  on the selected Month 2 backend.
- Keep data access behind repository interfaces so the choice is replaceable.

## Architecture

Build a modular monolith.

Do not introduce microservices during MVP development.

Prioritize maintainability and development speed.

---

# 9. Engineering Constraints

When implementing HealthPocket:

1. Build MVP before scalability features.
2. Avoid unnecessary infrastructure.
3. Assume no active banking partnership.
4. Assume no active investment partnership.
5. Assume no active hospital payment integration.
6. Keep providers abstract and replaceable.
7. Prioritize user experience.
8. Prioritize shipping speed.
9. Prioritize reliability over sophistication.

---

# 10. Definition of MVP Success

HealthPocket MVP is successful if:

- Users complete onboarding.
- Users create healthcare savings goals.
- Users actively use the application.
- Users return regularly.
- Family Pocket receives adoption.
- Product feedback validates demand.

The MVP is not considered successful because of integrations, partnerships, or advanced infrastructure.

The MVP succeeds when real users consistently save for healthcare.
