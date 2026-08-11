# Export / Import User Definitions

**Clone** is great *within* one org, but it copies record IDs — which don't exist in any
other org. **Export / Import** solves the cross-org case: capture a user's definition by
**name** in one org, then recreate an equivalent user in another (for example, replicating
the same admin across several sandboxes).

## How it works

- **Export** (from Edit User) writes a portable `.json` file describing the user's fields
  plus the *names* of their profile, role, permission sets, permission set groups,
  permission set licenses, public groups, and package licenses.
- **Import** reads that file and resolves those names to the **target org's** IDs. You can
  import in two places:
    - **Create User** — pre-fills a brand-new user from the definition.
    - **Edit User** — *adds* the definition's permissions to an existing user (same org or
      different), without changing their identity or profile.

Because assignments are matched by name, the file works in any org that has the same
profiles, permission sets, groups, and packages — regardless of their internal IDs.

## Exporting a user

1. Open the **Edit User** tab and select the user.
2. Click **Export Definition**.
3. A file named `ubox-user-<LastName>-<timestamp>.json` downloads.

!!! note "If the download is blocked"
    Some browser or security configurations block programmatic downloads. If that happens,
    uBox shows the JSON in a read-only box instead — copy it and save it as a `.json` file
    yourself.

## Importing as a new user (Create User)

1. Open the **Create User** tab.
2. Click **Import Definition** and choose a previously exported `.json` file. (Or click
   **Paste JSON** and paste the file's contents.)
3. The form pre-fills from the definition. A note panel appears summarizing anything that
   needs your attention (see below).
4. Enter a new **Email**, **Username**, and **Alias**, review the rest, and click
   **Create User**.

!!! warning "Email, Username, and Alias are always cleared on import"
    Usernames must be globally unique across **all** Salesforce orgs, so importing never
    reuses the source user's email/username/alias. The original values are shown in the note
    panel purely as a reference while you fill in new ones.

## Adding permissions to an existing user (Edit User)

The same `.json` can be applied to an **existing** user to grant them the definition's
permissions — in the same org or a different one.

1. Open the **Edit User** tab and select the user.
2. Click **Import Definition** (or **Paste JSON**) and choose the file.
3. The definition's assignments are **added** to the user's current selections. Review the
   permission set / group / license lists, then click **Save Changes** to apply.

This mode is deliberately narrow and safe:

- **Permissions only.** Only the five assignment categories are touched. The user's name,
  email, username, profile, role, locale, and address are **left exactly as they are** —
  importing never changes a user's identity or profile.
- **Add-only.** Imported assignments are *added* to what the user already has; nothing is
  removed. If you want to drop an existing assignment, deselect it manually before saving.

Anything in the definition that doesn't exist in this org is listed in the note panel and
skipped, exactly as on the create flow.

!!! tip "Common use"
    Grant a user the same permission bundle as a template user: export the template once,
    then import it onto each user via Edit User and Save.

## What "unresolved" means

Import follows a simple rule: **bring in everything that exists in the target org, and warn
about the rest.** If the definition names something the target org doesn't have — a
permission set that isn't installed, a public group that doesn't exist, a license with no
match — that item is listed in the note panel and simply left unselected. The user is never
created with silently dropped access; you decide whether to add a substitute manually.

If the **profile** itself can't be matched, the form leaves the Profile field empty and
flags it — pick an appropriate profile before creating the user.

## How names are matched

| Item | Matched on |
|------|-----------|
| Profile | Profile name |
| Role | Role API (developer) name |
| Permission set | API name + namespace |
| Permission set group | Developer name + namespace |
| Permission set license | Developer name |
| Public group | Group API (developer) name |
| Package license | Namespace prefix |

Only assignable items are offered on import — the same availability rules as the
[Create User](create-user.md) pickers apply (e.g. only permission set groups in an *Updated*
status, only active licenses).

## Export/Import vs. Clone

| | [Clone](clone-from-user.md) | Export / Import |
|--|--------|-----------------|
| Works across orgs | ❌ (copies IDs) | ✅ (matches by name) |
| Produces a reusable file | ❌ | ✅ `.json` |
| Best for | Duplicating a user in the same org | Replicating a user across sandboxes |

## Auditing

Exports are recorded in the **[uBox Logs](logging.md)** as an *Export User* action. The
resulting user creation is logged as usual by the create flow.
