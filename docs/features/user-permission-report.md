# User Permission Report

uBox can generate a **printable PDF** of a single user's effective access — useful for
access reviews, audits, and handing documentation to security or compliance teams.

## What the report contains

The report consolidates a user's **effective** access (profile + all permission sets +
permission set groups, folded together), with each grant attributed back to its source:

- **User header** — name, active status, profile, and role
- **Grant sources** — the profile, permission sets, and permission set groups that
  contribute access (grants elsewhere in the report reference these)
- **Public groups** the user belongs to
- **Permission set licenses** and **package licenses** assigned
- **System / user permissions**
- **Object permissions** (CRUD + View All / Modify All)
- **Field-level security** — per object, the fields the user can read/edit
- **Tab settings**
- **App access**
- **Custom permissions**

Because grants are attributed to their source, the report shows not just *that* a user has
an access, but *where it comes from*.

## Generating the report

The report is a Visualforce page rendered as PDF. It's reached at:

```
/apex/ubox__UserPermissionsPdf?id=<userId>
```

where `<userId>` is the Id of the user to report on. The page includes the generation
timestamp so a saved or printed copy is self-dating.

!!! note "Access requirement"
    The **uBox Admin** permission set grants access to the underlying `UserPermissionsPdf`
    page. Users without it can't open the report. See
    [Access & Permissions](../getting-started/permissions.md).

## Report vs. comparison vs. explorer

| Tool | Best for |
|------|----------|
| **User Permission Report** | Documenting **one user's** full effective access |
| **[Permissions Comparison](permissions-comparison.md)** | Explaining the **difference between two users** |
| **[Permission Set Explorer](permission-set-explorer.md)** | Understanding what a **permission set / group** grants and who has it |
