# Edit User

The **Edit User** tab loads an existing user into the same rich form used for creation, so
you can change their details and adjust their assignments in one place.

## Editing a user

1. Open the **Edit User** tab.
2. Use the user picker to search for and select the user to edit.
3. uBox loads their current field values **and** their existing assignments — every
   permission set, permission set group, permission set license, public group, and package
   license already selected.
4. Change whatever you need and submit.

The form fields behave the same as on [Create User](create-user.md), including
license-aware profile filtering and the adaptive address fields.

## How assignment changes are applied (diffing)

You don't manage "add" and "remove" separately — you just adjust the selected lists to
reflect the end state you want. On submit, uBox compares the selections against the user's
current assignments and computes the difference for each category:

- Items you **added** to a list are assigned.
- Items you **removed** from a list are unassigned.
- Items left unchanged are untouched.

This applies independently to all five categories (permission sets, permission set groups,
permission set licenses, public groups, package licenses).

## What happens when you submit

1. uBox **updates the User record** synchronously.
2. If any assignments changed, it enqueues a background job
   (`UserUpdateAssignmentQueueable`) that performs the adds and removes. As with creation,
   running this in a separate transaction avoids *mixed DML* errors.
3. The edit action is written to the **[activity log](logging.md)**.

If nothing about the assignments changed, no background job is enqueued — only the User
update runs.

!!! note "Role can be cleared"
    Unlike creation, editing lets you *remove* a user's role: clear the Role field and
    submit, and uBox sets the user's role to none.

## Inspecting a user's effective access

While reviewing a user you often want to know not just what's *assigned* but what access
those assignments actually *add up to*. From the edit experience you can inspect the
user's **effective permissions** — the combined system permissions, object CRUD, field
security, tabs, apps, and custom permissions — with each grant attributed to the profile,
permission set, or group it comes from. For a printable version, see the
**[User Permission Report](user-permission-report.md)**.
