# Assignments

Every uBox create/edit flow can grant five kinds of access. This page explains what each
one is, how the available options are filtered, and what happens when uBox applies them.

## The five assignment categories

| Category | Salesforce object | Notes |
|----------|-------------------|-------|
| **Permission Sets** | `PermissionSetAssignment` | Standalone permission sets — those not owned by a profile and not part of a permission set group |
| **Permission Set Groups** | `PermissionSetAssignment` (group) | Only groups in an **Updated** status (i.e. recalculated and ready to assign) are offered |
| **Permission Set Licenses** | `PermissionSetLicenseAssign` | Only licenses with seats remaining; the picklist label shows availability |
| **Public Groups** | `GroupMember` | Regular public groups only |
| **Package Licenses** | `UserPackageLicense` | Managed-package licenses with seats remaining |

## How availability is filtered

uBox tries to only show you options that will actually work:

- **Permission set licenses** show a count in the label — either `(N available)` or
  `(Unlimited)`. Licenses with **no seats left are hidden** entirely.
- **Package licenses** likewise show `(N available)` and are **hidden when no seats
  remain**.
- **Permission set groups** are only offered when their status is **Updated**; a group
  that's still recalculating won't appear until it's ready.
- **Permission sets** exclude profile-owned permission sets and the aggregate permission
  sets that back permission set groups, so the list stays to the ones you'd actually pick.

## How assignments are applied

Assignments never run in the same transaction as the User insert/update. Instead:

- **On create**, after the User is inserted, uBox enqueues `UserAssignmentQueueable` to
  add all selected assignments.
- **On edit**, uBox diffs your selections against the user's current assignments and
  enqueues `UserUpdateAssignmentQueueable` to apply just the adds and removes.

Running assignments in a separate asynchronous job is what avoids Salesforce's **mixed
DML** restriction (you can't modify a setup object like User and a non-setup record in one
transaction).

### Partial success

Assignments are applied with **partial success** semantics: if one assignment fails (for
example, a license truly ran out between when the form loaded and when the job ran), the
others still succeed. Failures don't roll back the whole batch and don't undo the User that
was already created.

Every batch — successes and failures — is recorded to the
**[activity log](logging.md)**, and the admin who ran it can receive a **desktop/mobile
notification** when processing completes.

!!! tip "Why assignments may lag the form"
    Because the work is asynchronous, a newly created or edited user's assignments can take
    a few seconds to appear after the form says it succeeded. If something looks missing,
    check the [uBox Logs](logging.md) for that action.
