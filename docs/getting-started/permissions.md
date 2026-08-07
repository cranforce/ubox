# Access & Permissions

Access to uBox is controlled by a single permission set, **uBox Admin**, that ships with
the package. Assign it to any user who should be able to create, edit, or analyze users.

## Assign the uBox Admin permission set

1. Go to **Setup → Permission Sets**.
2. Open **uBox Admin**.
3. Click **Manage Assignments → Add Assignment**.
4. Select the admins who need access and save.

## What uBox Admin grants

| Category | Access |
|----------|--------|
| **App & tabs** | The uBox app and all of its tabs: Create User, Edit User, Permission Set Explorer, Permissions Comparison, and uBox Logs |
| **Apex** | All uBox controllers and services needed by the UI |
| **Visualforce** | The `UserPermissionsPdf` page (the printable permission report) |
| **uBox Log object** | Create / Read / Edit and **View All** on `uBox_Log__c`, plus all its fields |
| **User permissions** | `ManageInternalUsers` and `AssignPermissionSets` |

!!! warning "These are powerful permissions"
    `ManageInternalUsers` lets a user create and edit **any** internal user, and
    `AssignPermissionSets` lets them grant permission sets. Only assign uBox Admin to
    trusted administrators. uBox records every action to the [activity
    log](../features/logging.md) so these operations are auditable.

## Why these permissions are required

- **`ManageInternalUsers`** — creating and editing User records, and setting passwords in a
  sandbox, all require this permission.
- **`AssignPermissionSets`** — assigning permission sets, permission set groups, and
  permission set licenses requires this permission.

The assignment work runs in `without sharing` Apex jobs after the user is saved, but the
*admin* still needs these permissions for the initial, user-context operations to be
allowed. See [Architecture](../reference/architecture.md) for the full picture.

## Do end users need anything?

No. uBox is an admin tool. The users being *created or edited* need no uBox access — only
the administrators operating uBox do.
