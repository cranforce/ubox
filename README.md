# uBox

A Salesforce 2GP managed package that replaces the standard "New User" flow with a streamlined, single-page Lightning experience. Create or edit users and assign permission sets, permission set groups, permission set licenses, public groups, and package licenses — all from one screen.

## Install

**Managed Package (recommended):**
[Install uBox v0.4.0.1](https://login.salesforce.com/packaging/installPackage.apexp?p0=04tfj000000GDCbAAO)

**Unlocked Package:**
[Install uBox Unlocked v0.4.0.1](https://login.salesforce.com/packaging/installPackage.apexp?p0=04tfj000000GDHRAA4)

> For sandbox installations, replace `login.salesforce.com` with `test.salesforce.com` in the URL.

After installing, assign the **uBox Admin** permission set to any user who needs access.

## Features

- **Create User** — single-page form with all standard user fields plus five assignment categories
- **Edit User** — search for an existing user, modify fields, and add/remove assignments with automatic diffing
- **Clone from User** — pre-populate the create form from an existing user's configuration
- **Auto-generated fields** — Username mirrors Email and Alias is derived from the user's name, unless manually overridden
- **License-aware profiles** — profile picklist filters automatically based on the selected User License
- **Async assignments** — permission sets, groups, and licenses are assigned via queueable jobs to avoid mixed DML errors
- **Partial success** — individual assignment failures are logged but don't block the overall operation

## Architecture

```
uBox App
├── Create User tab → createUserForm (LWC)
│     ├── userInfoSection — form fields, auto-gen username/alias
│     ├── dualListSection × 5 — perm sets, perm set groups, PSLs, groups, package licenses
│     └── createUser() → UserAssignmentQueueable (async)
│
└── Edit User tab → editUserForm (LWC)
      ├── lightning-record-picker — search for user to edit
      ├── userInfoSection (reused)
      ├── dualListSection × 5 (reused)
      └── updateUser() → diffs assignments → UserUpdateAssignmentQueueable (async)
```

### Apex Classes

| Class | Sharing | Purpose |
|-------|---------|---------|
| `UserManagementController` | `with sharing` | `@AuraEnabled` methods for form metadata, user CRUD, and clone/edit data retrieval |
| `UserAssignmentQueueable` | `without sharing` | Post-creation assignment of perm sets, groups, and licenses |
| `UserUpdateAssignmentQueueable` | `without sharing` | Post-edit assignment diffing — adds new and removes deselected assignments |

### LWC Components

| Component | Exposed | Description |
|-----------|---------|-------------|
| `createUserForm` | Yes | Parent orchestrator for user creation |
| `editUserForm` | Yes | Parent orchestrator for user editing |
| `userInfoSection` | No | Reusable form fields with validation and auto-generation |
| `dualListSection` | No | Thin wrapper around `lightning-dual-listbox` |

### Permission Set: uBox Admin

Grants access to the uBox app, all three Apex classes, both tabs, and the `ManageInternalUsers` and `AssignPermissionSets` user permissions.

## Development

### Prerequisites

- [Salesforce CLI](https://developer.salesforce.com/tools/salesforcecli)
- A Dev Hub org with the `ubox` namespace registered
- A connected default org

### Common Commands

```bash
# Deploy to a connected org
sf project deploy start --source-dir force-app

# Run all Apex tests with coverage
sf apex run test --code-coverage --result-format human

# Run a single test class
sf apex run test --class-names UserManagementControllerTest --result-format human

# Create a scratch org
sf org create scratch -f config/project-scratch-def.json -a ubox-scratch

# Create a managed package version
sf package version create -p uBox -w 10 --code-coverage --installation-key-bypass

# Create an unlocked package version
sf package version create -p "uBox Unlocked" -w 10 --installation-key-bypass
```

### Project Config

- **Namespace:** `ubox`
- **API Version:** 65.0
- **Package type:** 2GP Managed
- **Scratch org edition:** Developer (no special features required)
