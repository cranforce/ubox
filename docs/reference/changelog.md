# Changelog

Notable changes per release, newest first. Entries are reconstructed from the package
release history; each version corresponds to a promoted managed-package version in
`sfdx-project.json`.

## 0.16.0 — _in development_

- **[Import into Edit User](../features/export-import.md#adding-permissions-to-an-existing-user-edit-user)** — the same exported `.json` can now be applied to an *existing* user from the Edit User screen to grant the definition's permissions (same org or across orgs). Import here is **permissions-only** (identity and profile are untouched) and **add-only** (existing assignments are never removed).

## 0.15.0 — 2026-08-07

- **New: [Export / Import User Definitions](../features/export-import.md)** — export a user
  (fields plus the *names* of their profile, role, permission sets, permission set groups,
  permission set licenses, public groups, and package licenses) to a portable `.json` file,
  and import it in another org to pre-fill the Create User form. Assignments are matched by
  name so a user can be replicated across sandboxes; anything the target org is missing is
  reported rather than silently dropped.
- Added a public documentation site (this site), built with MkDocs and published to GitHub
  Pages.

## 0.14.0

- **New: [Permissions Comparison](../features/permissions-comparison.md) tab** — pick two
  users and see a side-by-side **A | B** diff of everything that differs between them:
  access mechanisms, system/object/field permissions, tabs, apps, and custom permissions.
- Results are presented as unified A | B tables with **accordion sections** and
  **quick-link navigation** for jumping between categories.
- Performance: bulkified the tab-name resolution query so comparisons involving users with
  many tabs stay within Salesforce query limits.

## 0.13.0

- **New: [User Permission Report](../features/user-permission-report.md)** — generate a
  printable PDF of a user's full effective permissions, with each grant attributed to its
  source (profile, permission set, or permission set group).
- Fix: avoid `queryMore()` on `TabDefinition` in the Permission Set Explorer, preventing
  errors for permission sets that expose many tabs.

## 0.12.0

- **Address fields** added to Create User, Edit User, and Clone (Street, City, State,
  Postal Code, Country).
- **State & Country/Territory picklist (CCP) support** — when picklists are enabled, the
  State and Country fields render as dependent picklists; otherwise they fall back to plain
  text. The package remains installable either way.

## 0.11.0

- Fix: Edit User no longer auto-rewrites fields (such as Username/Alias) while you're
  editing an existing user.

## 0.10.0

- Added a **show-password toggle** to the Set Password modal.

## 0.9.0

- **New: [Set Password](../features/set-password.md) tool** — set a sandbox user's password
  directly (no email required), working around sandboxes that can't deliver
  password-reset emails. Restricted to sandbox orgs.

## 0.8.0

- **New: field-level security viewer** — inspect a user's effective field permissions
  (Read/Edit) per object.
- Enhanced the underlying effective-permission retrieval used across uBox.

## 0.7.0

- Refactored **Edit User** into a two-pane explorer with an embedded **permission
  inspector**, so you can review a user's effective access while editing them.

## 0.6.0

- **New: [Permission Set Explorer](../features/permission-set-explorer.md) tab** — browse
  permission sets and **permission set groups**, see what they grant, and view/manage who's
  assigned.

## 0.5.0

- Reordered the post-save **assignment logic** to handle dependencies between assignment
  types more reliably.
- Consolidated distribution on the **managed** package (dropped the unlocked package build).

## 0.4.0

- User create/edit actions now write their **activity logs asynchronously**, keeping the
  logging out of the main transaction.

## 0.3.0

- Improved error handling and messaging when a user create/edit fails.

## 0.2.0

- Established the **managed-package upgrade path** (ancestor versioning) so future releases
  install as upgrades.
- Fixed async-logging test assertions.

## 0.1.x — Initial release

- Single-page **[Create User](../features/create-user.md)** and
  **[Edit User](../features/edit-user.md)** experience replacing the standard New User flow.
- Assign **permission sets, permission set groups, permission set licenses, public groups,
  and package licenses** in one submit, applied via asynchronous jobs with partial success.
- **[Clone from User](../features/clone-from-user.md)** to pre-fill a new user from an
  existing one.
- **[Activity logging](../features/logging.md)** with `uBox_Log__c` records and desktop /
  mobile **completion notifications**.
