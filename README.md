# uBox

A Salesforce 2GP managed package that replaces the standard "New User" flow with a streamlined, single-page Lightning experience, and adds tooling to analyze and move user permissions. Create, edit, clone, export/import, compare, and report on users and their access — all from one app.

## 📖 Documentation

Full documentation — installation, feature guides, and architecture — is published at
**[cranforce.github.io/ubox](https://cranforce.github.io/ubox/)**.

## Install

[Install uBox v0.15.0.2](https://login.salesforce.com/packaging/installPackage.apexp?p0=04tfj000000QKBBAA4)

> For sandbox installations, replace `login.salesforce.com` with `test.salesforce.com` in the URL.

After installing, assign the **uBox Admin** permission set to any user who needs access.

## Features

> For the complete, up-to-date feature guides see the [documentation site](https://cranforce.github.io/ubox/).

- **Create User** — single-page form with all standard user fields plus five assignment categories
- **Edit User** — search for an existing user, modify fields, and add/remove assignments with automatic diffing
- **Clone from User** — pre-populate the create form from an existing user's configuration
- **Export / Import** — export a user definition (fields + assignment *names*) to a portable `.json` file and import it in another org to recreate the user; unmatched items are reported, not silently dropped
- **Permission Set Explorer** — browse permission sets / groups, see what they grant, and view or manage who's assigned
- **Permissions Comparison** — side-by-side A | B diff of two users' effective access
- **User Permission Report** — printable PDF of a user's effective permissions, attributed to their source
- **Set Password (sandbox)** — set a sandbox user's password directly, without email
- **Activity logs & notifications** — every action is written to `uBox_Log__c`, with desktop/mobile completion notifications
- **License-aware profiles**, **auto-generated Username/Alias**, **async assignments** (mixed-DML-safe), and **partial success**

## Architecture

The **uBox** app exposes five tabs: Create User, Edit User, Permission Set Explorer, Permissions Comparison, and uBox Logs.

```
Create User → createUserForm ─┐
Edit User   → editUserForm  ──┤ userInfoSection + dualListSection × 5
                              └→ create/updateUser() → *AssignmentQueueable (async)
Export/Import → exportUserDefinition() / prepareImport() (IDs ⇄ names)
Permission Set Explorer → permissionSetExplorer
Permissions Comparison  → permissionComparison
uBox Logs → uBox_Log__c
```

### Apex Classes

| Class | Sharing | Purpose |
|-------|---------|---------|
| `UserManagementController` | `with sharing` | Form metadata, user CRUD, clone, **export/import**, effective-permission + FLS engine, sandbox password, CCP metadata |
| `UserAssignmentQueueable` | `without sharing` | Post-creation assignment of perm sets, groups, and licenses |
| `UserUpdateAssignmentQueueable` | `without sharing` | Post-edit assignment diffing — adds new and removes deselected assignments |
| `PermissionSetExplorerController` | `with sharing` | Permission set / group detail, members, assigned users, assign/unassign |
| `PermissionComparisonController` | `with sharing` | Server-side diff of two users' effective access |
| `UserPermissionsPdfController` | `with sharing` | Backs the `UserPermissionsPdf` Visualforce report |
| `uBoxLogService` | `without sharing` | Writes `uBox_Log__c` entries and sends completion notifications |

### Key LWC Components

Exposed roots: `createUserForm`, `editUserForm`, `permissionSetExplorer`, `permissionComparison`. Supporting (not exposed): `userInfoSection`, `dualListSection`, `userList`, `permissionSetList`, `permissionSetDetail`, `userPermissionInspector`, `fieldSecurityViewer`, `setPasswordModal`.

### Permission Set: uBox Admin

Grants the uBox app, all uBox Apex classes, the `UserPermissionsPdf` page, all five tabs, access to `uBox_Log__c`, and the `ManageInternalUsers` + `AssignPermissionSets` user permissions.

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

# Create a managed package version (use --code-coverage before promoting)
sf package version create -p uBox -w 10 --code-coverage --installation-key-bypass

# Promote a version to released (required before installing into production)
sf package version promote --package uBox@x.y.z-n
```

### Project Config

- **Namespace:** `ubox`
- **API Version:** 65.0
- **Package type:** 2GP Managed
- **Scratch org edition:** Developer (no special features required)
