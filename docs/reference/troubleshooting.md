# Troubleshooting

## A new user's assignments didn't appear immediately

Assignments are applied by an **asynchronous background job** after the user is saved, so
they can lag the form's success message by a few seconds. Refresh the user after a moment.
If they still don't show, open the **[uBox Logs](../features/logging.md)** tab (or its
**Error Logs** view) and find the assignment action for that user — a failure will be
recorded there with the reason.

## An assignment silently failed

uBox uses **partial success**: if one item in a batch fails, the rest still succeed and the
user is not rolled back. The failed item is written to the log with its error message.
Common causes:

- A **permission set license or package license ran out of seats** between when the form
  loaded and when the job ran.
- The user's **profile/license is incompatible** with a permission set license.

## "Set Password is only available in sandbox orgs"

The [Set Password](../features/set-password.md) feature is intentionally blocked in
production. Use a normal password-reset/welcome email flow for production users. Confirm
you're in a sandbox if you expected it to work.

## A profile I expected isn't in the list

The **Profile** picklist is filtered by the selected **User License**. Pick the correct
license first; only profiles tied to that license appear. This mirrors Salesforce's own
one-license-per-profile rule.

## A permission set group isn't offered for assignment

Only groups in an **Updated** status are selectable. If a group was recently changed it may
still be **recalculating** — wait for Salesforce to finish updating it, then reload.

## Address shows text fields instead of picklists (or vice-versa)

uBox adapts to your org: if **State & Country/Territory picklists** are enabled you get
dependent picklists; if not, you get plain text fields. This is expected behavior, not a
bug — change it under **Setup → State and Country/Territory Picklists** if desired.

## I don't see uBox in the App Launcher

You need the **uBox Admin** permission set. See
[Access & Permissions](../getting-started/permissions.md).

## Admins aren't receiving completion notifications

Confirm the **uBox Assignment Complete** notification type is enabled for the relevant
users under **Setup → Notification Delivery Settings**. See
[Activity Logs & Notifications](../features/logging.md).
