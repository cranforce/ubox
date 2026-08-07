# Create User

The **Create User** tab replaces the standard "New User" screen. On one page you set the
user's details *and* everything they should be granted, then submit once.

## The form

### User details

Standard User fields, including:

- **First Name / Last Name**
- **Email** — also used to auto-generate the Username (see below)
- **Username** and **Alias** — auto-generated, editable
- **User License** and **Profile**
- **Role**
- **Locale, Language, Time Zone, Email Encoding**
- **Company, Department, Title**
- **Address** (Street, City, State, Postal Code, Country)
- **Active** checkbox
- Feature checkboxes: Marketing User, Knowledge User, Interaction User, Support User,
  Salesforce CRM Content User

!!! info "Auto-generated Username and Alias"
    - **Username** defaults to the **Email** you enter.
    - **Alias** defaults to the user's first initial + last name.

    Both stop auto-updating as soon as you edit them by hand, so you can override either
    without uBox overwriting your value.

### License-aware profiles

When you pick a **User License**, the **Profile** list filters to only the profiles that
belong to that license. This mirrors Salesforce's own rule that a profile is tied to a
single user license, and prevents you from choosing an incompatible combination.

### Address & State/Country picklists

If your org has State & Country/Territory picklists enabled, the State and Country fields
render as dependent picklists (choosing a country filters the available states). If they
aren't enabled, they render as plain text fields. uBox handles both automatically.

## Assignments

Below the user details are five assignment pickers. Each is a dual-list box where you move
items from **Available** to **Selected**:

| Picker | What it assigns |
|--------|-----------------|
| **Permission Sets** | Standalone permission sets (those not owned by a profile or a group) |
| **Permission Set Groups** | Permission set groups in an *Updated* (ready) status |
| **Permission Set Licenses** | Only licenses with availability remaining; the label shows how many are left |
| **Public Groups** | Regular public groups |
| **Package Licenses** | Managed-package licenses with seats remaining |

See **[Assignments](assignments.md)** for exactly how these are applied and what happens
when one fails.

## What happens when you submit

1. uBox validates the required fields and **inserts the User** synchronously.
2. If you selected any assignments, uBox enqueues a background job
   (`UserAssignmentQueueable`) to apply them. Splitting the assignments into a separate
   transaction is what avoids Salesforce's *mixed DML* restriction between User (a setup
   object) and the assignment records.
3. The create action is written to the **[activity log](logging.md)**.

Because assignments run asynchronously, they may take a few moments to appear on the new
user after the form reports success.

!!! tip "Faster setup with Clone"
    If the new user should resemble an existing one, start from
    **[Clone from User](clone-from-user.md)** instead of a blank form — it pre-fills the
    details and every assignment for you.
