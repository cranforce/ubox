# Architecture

This page describes how uBox is built, for developers and technically-minded admins. For
task-oriented docs, start with [Features](../features/create-user.md).

## Overview

uBox is a Salesforce **2GP managed package** (namespace `ubox`) consisting of one
Lightning app, five tabs, a set of Lightning web components, Apex controllers and
asynchronous jobs, a custom object for logging, a Visualforce PDF page, and a custom
notification type.

## Tabs and their entry components

| Tab | Root LWC (exposed) |
|-----|--------------------|
| Create User | `createUserForm` |
| Edit User | `editUserForm` |
| Permission Set Explorer | `permissionSetExplorer` |
| Permissions Comparison | `permissionComparison` |
| uBox Logs | `uBox_Log__c` object tab |

Supporting components (not individually exposed) include `userInfoSection`,
`dualListSection`, `userList`, `permissionSetList`, `permissionSetDetail`,
`userPermissionInspector`, `fieldSecurityViewer`, and `setPasswordModal`.

## Apex layer

| Class | Sharing | Responsibility |
|-------|---------|----------------|
| `UserManagementController` | `with sharing` | Form metadata; user create/edit/clone; effective-permission and FLS computation; sandbox password set; address (State/Country) metadata |
| `UserAssignmentQueueable` | `without sharing` | Applies all assignments after a user is **created** |
| `UserUpdateAssignmentQueueable` | `without sharing` | Applies the **diffed** adds/removes after a user is **edited** |
| `PermissionSetExplorerController` | `with sharing` | Permission set / group detail, members, assigned users, assign/unassign |
| `PermissionComparisonController` | `with sharing` | Server-side diff of two users' access |
| `UserPermissionsPdfController` | `with sharing` | Backs the `UserPermissionsPdf` Visualforce report |
| `uBoxLogService` | `without sharing` | Writes `uBox_Log__c` entries and sends completion notifications |

## Key design decisions

### Synchronous user DML, asynchronous assignments

Both create and edit insert/update the **User synchronously**, then enqueue a Queueable to
handle assignments. User is a *setup* object; assignment records (permission set
assignments, group members, etc.) are *non-setup*. Modifying both in one transaction raises
a **mixed DML** error, so the assignment work is deliberately deferred into its own
transaction.

### Diff-based edits

On edit, `updateUser` reads the user's current assignments, compares them to the submitted
selections, and enqueues only the **adds and removes** — so re-saving an unchanged user
does no assignment DML at all.

### Partial-success assignment

Assignment DML uses `Database.insert(..., false)` semantics: individual failures are
collected and logged without rolling back the rest or undoing the already-created user.

### Effective-permission computation is shared

`UserManagementController.getUserEffectivePermissions` (and the companion FLS method) is the
single source of truth for "what does this user effectively have." Both the
**[Comparison](../features/permissions-comparison.md)** and the
**[PDF report](../features/user-permission-report.md)** build on it rather than
re-implementing the aggregation.

### Tab-name resolution

`PermissionSetTabSetting.Name` can be an API name or an internal id (standard, custom, or
packaged). uBox resolves these against `TabDefinition` by name, by durable id, and by a
core-id suffix match to display friendly labels. Queries materialize results into lists
(with limits) because `TabDefinition` doesn't support `queryMore()`.

### State & Country picklist portability

Because `StateCode` / `CountryCode` fields only exist when State & Country/Territory
picklists are enabled, all references to them are **dynamic**. This keeps the managed
package installable in orgs that don't have picklists enabled, while still supporting
dependent country → state selection where they do.

### Logging and notifications

`uBoxLogService` writes to `uBox_Log__c`. Logs that accompany setup operations (like Set
Password) are written via an `@future` method so the non-setup log insert runs in its own
transaction — again avoiding mixed DML. The service can also send a **uBox Assignment
Complete** custom notification to the initiating admin, linked to the log record.

## Project facts

- **Namespace:** `ubox`
- **Package type:** 2GP managed
- **API version:** 65.0

## Building and testing

```bash
# Deploy source to a connected org
sf project deploy start --source-dir force-app

# Run all Apex tests with coverage
sf apex run test --code-coverage --result-format human

# Create a scratch org
sf org create scratch -f config/project-scratch-def.json -a ubox-scratch

# Create a managed package version
sf package version create -p uBox -w 10 --code-coverage --installation-key-bypass
```
