# uBox

**Manage the details of users and permissions — in a box.**

uBox is a Salesforce managed package that replaces the standard "New User" screen with a
single-page Lightning experience for creating, editing, and analyzing users. Instead of
bouncing between the New User page, permission set assignment screens, public group
membership, and license management, an admin does it all from one place — and can inspect
exactly what access a user ends up with.

## What you can do

<div class="grid cards" markdown>

- :material-account-plus: **[Create users](features/create-user.md)**
  One form for the user record plus permission sets, permission set groups, permission set
  licenses, public groups, and package licenses.

- :material-account-edit: **[Edit users](features/edit-user.md)**
  Search for an existing user, change their fields, and add or remove assignments — uBox
  computes the difference and only applies what changed.

- :material-content-copy: **[Clone from a user](features/clone-from-user.md)**
  Pre-fill a new user from an existing one's profile, role, and every assignment.

- :material-magnify: **[Explore permission sets](features/permission-set-explorer.md)**
  Browse permission sets and permission set groups, see everything they grant, and view or
  manage who's assigned.

- :material-compare: **[Compare two users](features/permissions-comparison.md)**
  A side-by-side A | B diff of everything that makes two users' access differ.

- :material-file-pdf-box: **[Generate a permission report](features/user-permission-report.md)**
  A printable PDF of a user's effective access, attributed to its source.

</div>

## How it fits together

uBox installs a single Lightning app, **uBox**, with these tabs:

| Tab | Purpose |
|-----|---------|
| **Create User** | Build a new user and all their assignments in one submit |
| **Edit User** | Modify an existing user and diff their assignments |
| **Permission Set Explorer** | Inspect what a permission set / group grants and who has it |
| **Permissions Comparison** | Diff two users' effective access side by side |
| **uBox Logs** | Audit trail of every create, edit, and assignment action |

## New here?

1. **[Install the package](getting-started/installation.md)** into your org.
2. **[Assign the uBox Admin permission set](getting-started/permissions.md)** to your admins.
3. Open the **uBox** app and start with **[Create User](features/create-user.md)**.

!!! note "About this documentation"
    These pages describe how uBox behaves for admins. For how the package is built —
    Apex classes, async assignment jobs, sharing model — see
    **[Architecture](reference/architecture.md)**.
