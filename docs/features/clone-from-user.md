# Clone from User

Cloning pre-fills the [Create User](create-user.md) form from an existing user so you can
stand up a similar user in seconds instead of re-selecting everything by hand.

## What gets copied

When you clone from a source user, uBox copies:

**User details**

- First / Last Name, Profile (and its User License), Role
- Locale, Language, Time Zone, Email Encoding
- Company, Department, Title
- Full address (Street, City, State, Postal Code, Country — including State/Country codes
  when picklists are enabled)
- Active status
- The feature checkboxes (Marketing, Knowledge, Interaction, Support, CRM Content)

**All assignments**

- Permission sets
- Permission set groups
- Permission set licenses
- Public groups
- Package licenses

## What gets blanked out

Three fields are intentionally **left empty** so you're forced to provide new, unique
values for the new user:

- **Email**
- **Username**
- **Alias**

!!! info "Why these are cleared"
    Email, Username, and Alias must be unique per user. Clearing them prevents you from
    accidentally creating a duplicate of the source user, and lets the
    [auto-generation](create-user.md#the-form) kick back in: type the new Email and the
    Username follows; type the name and the Alias follows.

## Using clone

1. Start a clone from the source user (for example, from a user list action).
2. The Create User form opens pre-populated as described above.
3. Fill in **Email** (and adjust Username/Alias if needed), review the details and
   assignments, then submit.

From there it behaves exactly like a normal [Create User](create-user.md) submission — the
User is inserted synchronously and assignments are applied by a background job.
