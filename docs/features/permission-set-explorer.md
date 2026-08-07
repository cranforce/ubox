# Permission Set Explorer

The **Permission Set Explorer** tab lets you browse permission sets and permission set
groups, see everything they grant, and manage who's assigned — without digging through
Setup.

## Browsing

The Explorer lists both **permission sets** and **permission set groups** together, sorted
by label. Each entry shows its label, API name, namespace (for packaged ones), and whether
it's custom. Select one to open its detail.

## Permission set detail

Selecting a permission set shows everything it grants, resolved to friendly labels:

- **System / user permissions** — every enabled `Permissions*` toggle (e.g. Manage Users,
  API Enabled), shown by label.
- **Object permissions** — per object: Read, Create, Edit, Delete, View All, Modify All.
- **Field-level security** — per object, the fields the permission set grants Read/Edit on.
- **Tab settings** — each tab's visibility. uBox resolves tab references (including
  standard and packaged tabs) back to their real labels.
- **App access** — the apps the permission set makes visible.
- **Custom permissions** — any custom permissions it grants.
- **License** — the permission set's associated license, if any.

### Permission set groups

Selecting a **group** shows the same detail, computed from the group's aggregated
(effective) permissions — i.e. the combined result of all its member permission sets — plus
a **members** list of the individual permission sets that make up the group.

## Who's assigned

For any permission set or group you can view the **assigned users** — their name,
username, and active status. From here you can:

- **Assign** the permission set / group to one or more users. uBox skips users who already
  have it (so re-running is safe) and reports how many were added, skipped, and failed.
- **Unassign** a user by removing their assignment.

Both actions use partial-success semantics and are written to the
**[activity log](logging.md)**.

!!! note "Field permissions are loaded per object"
    Because a permission set can touch many objects, field-level security is fetched for
    one object at a time when you drill into it, keeping the initial detail view fast.
