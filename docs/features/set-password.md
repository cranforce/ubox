# Set Password (Sandbox)

Sandboxes frequently can't deliver the welcome / password-reset emails that Salesforce
normally sends when you create a user, which leaves new sandbox users unable to log in.
uBox includes a **Set Password** helper to work around this.

## What it does

Set Password sets a user's password **directly**, without sending any email. This lets you
create a user in a sandbox and immediately give them working credentials.

## Sandbox only

!!! warning "This feature is restricted to sandboxes"
    Set Password is **only available in sandbox orgs**. In production, uBox blocks the
    operation — production users should receive a proper password-reset/welcome email, and
    setting passwords directly there would bypass that flow. Attempting it in production
    returns an error.

## Requirements

- The org must be a **sandbox**.
- You must have the **`ManageInternalUsers`** permission (included in
  [uBox Admin](../getting-started/permissions.md)). Salesforce requires it for the
  underlying password-set operation.
- You must select a user and provide a non-blank password.

## Privacy & auditing

- The password is **never written to the logs**. uBox records that a Set Password action
  occurred (and against which user), but the log detail deliberately excludes the password
  value.
- Both successful and failed attempts are recorded to the
  **[activity log](logging.md)**.

!!! note "Why it runs as a separate logged action"
    The log entry is written asynchronously so that recording it doesn't collide with the
    password-set (a setup operation) as a *mixed DML* error.
