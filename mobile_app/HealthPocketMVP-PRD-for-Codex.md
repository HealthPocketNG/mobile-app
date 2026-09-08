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

Users configure a recurring healthcare savings plan, contribute consistently,
build an ongoing health balance, and eventually use those funds for
healthcare-related spending.

The MVP is focused on validating saving behavior, not building a complete healthcare payments ecosystem.

---

# 2. MVP Objective

The primary objective of the MVP is to answer a single question:

**Will users consistently save money for healthcare through HealthPocket?**

The MVP should prioritize:

- User onboarding
- Savings plan setup
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
- Recurring Savings Plan Setup

#### Dashboard

- Current Balance
- Savings Plan Summary
- What Your Balance Can Cover
- Activity Feed

#### Savings

- Set Savings Amount and Frequency
- Edit Savings Plan
- Pause Savings Plan
- Resume Savings Plan
- Record mock contributions
- View contribution history
- View a zero-balance encouragement state

#### Family Pocket

- Create Family Pocket
- Invite Member
- View Members
- Remove Contributor (Admin only)
- Shared Balance
- Shared Contribution History

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

- Create Savings Plan
- Update Savings Amount and Frequency
- Pause and Resume Savings Plan
- Record Contribution (Savings Record)
- Calculate Current Health Balance
- Calculate Informational Healthcare Coverage Guidance

Each contribution must be linked to either a user's personal HealthPocket or a
Family Pocket and must update the relevant calculated balance. Savings plans
do not have target balances and never become "completed." In Month 2, a
contribution is a product record only; it must not imply real-money movement
until a banking/payment partner is integrated.

#### Activity Tracking

- Contribution (Savings Record) History
- User Activity Logs
- Savings Plan and Family Pocket Activity Feed

#### Family Pocket

- Create Pocket
- Join Pocket
- Invite Members
- Shared Contributions
- Role Management
- Admin Removal of Contributors
- Shared Contribution History and Shared Balance

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

- Configure how much to save daily, weekly, or monthly
- Edit, pause, and resume their savings plan
- Build an ongoing healthcare balance without a required target
- View contribution history
- Monitor savings activity
- See informational examples of healthcare expenses their current balance may
  help cover

The "What your balance can cover" experience is guidance only. It must not be
presented as insurance coverage, a medical guarantee, a provider quote, or a
promise that a particular treatment will be fully paid for.

---

## Family Pocket

Users can collaborate through a shared healthcare balance. A Family Pocket
does not have a target amount or completion progress.

### Roles

#### Admin

- Creates Pocket
- Invites Members
- Removes Contributors
- Manages Pocket Membership

#### Contributor

- Contributes Funds
- Views Shared Balance and Activity

#### Beneficiary

- Intended healthcare recipient

Role architecture should remain extensible.

Only an Admin may remove a Contributor. The founding Admin cannot be removed
through the standard contributor-removal action. Removing a member does not
delete or reverse their historical contributions.

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

## Personal HealthPocket

```text
PersonalHealthPocket
- id
- userId
- currency
- status (active | restricted | closed)
- createdAt
- updatedAt
```

The displayed personal balance is calculated from completed personal
contributions. It is not a goal-progress value.

## Savings Plan

```text
SavingsPlan
- id
- userId
- personalHealthPocketId
- contributionAmount
- frequency (daily | weekly | monthly)
- startDate
- nextContributionDate (optional)
- status (active | paused)
- fundingSourceId (optional; unavailable until a payment partner exists)
- createdAt
- updatedAt
```

A user has one default personal HealthPocket savings plan in the MVP. Editing
the plan changes future contribution instructions; it does not alter historical
contribution records.

## Contribution (Savings Record)

```text
Contribution
- id
- contributorUserId
- personalHealthPocketId (optional; required when familyPocketId is absent)
- savingsPlanId (optional; identifies the plan that prompted the record)
- familyPocketId (optional; required when personalHealthPocketId is absent)
- amount
- currency
- status (recorded | completed | reversed)
- source (mock | manual | provider)
- note (optional)
- createdAt
```

`Contribution` is the canonical record for savings history and balances. A
Personal HealthPocket or Family Pocket balance is calculated from its completed
contributions; do not maintain an unrelated transaction history. The `source`
field keeps the MVP provider-agnostic and makes future payment integrations
replaceable.

## Family Pocket

```text
FamilyPocket
- id
- name
- currency
- status (active | archived)
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
- role (admin | contributor | beneficiary)
- invitationStatus (pending | accepted)
- joinedAt
- removedAt (optional)
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

## Savings, Family, and Activity Rules

- Only completed contributions count toward a personal or Family Pocket
  balance.
- A paused savings plan stops future scheduled contribution instructions but
  does not close the user's HealthPocket or erase its balance.
- Manual contribution records may still be added in the mock MVP. Actual bank
  debits must not be implied before payment infrastructure exists.
- A contribution creates an associated activity record for the contributor;
  shared-pocket activity is visible to its members according to their role.
- Family Pockets do not have targets or completion states.
- Only a Family Pocket Admin may remove a Contributor. Membership removal must
  preserve historical contribution and activity records.
- Healthcare coverage guidance is derived from configurable reference-cost
  bands and the current balance; it is informational and must carry no promise
  of insurance or provider pricing.
- The MVP must not create payouts, transfers, automatic debits, or settlements.

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
- Users configure healthcare savings plans.
- Users actively use the application.
- Users return regularly.
- Family Pocket receives adoption.
- Product feedback validates demand.

The MVP is not considered successful because of integrations, partnerships, or advanced infrastructure.

The MVP succeeds when real users consistently save for healthcare.
