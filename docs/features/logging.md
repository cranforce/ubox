# Activity Logs & Notifications

uBox records the actions it performs so administrators have an audit trail, and it can
notify the admin when asynchronous work finishes.

## The uBox Logs tab

Every significant uBox action writes a **uBox Log** record (`uBox_Log__c`). Open the
**uBox Logs** tab to review them. Two list views ship with the package:

- **All Logs**
- **Error Logs** — filtered to failures, for quickly spotting problems

### What's on each log

| Field | Meaning |
|-------|---------|
| **Action** | The operation — e.g. *Create User*, *Edit User*, *Assign Permission Set*, *Unassign Permission Set Group*, *Set Password* |
| **Target User** | The user the action was performed on (when applicable) |
| **Performed By** | The admin who ran the action |
| **Status** | *Success* or *Error* |
| **Detail** | A JSON summary — for creates/edits this includes the counts of each assignment category; for errors, the failure message |

!!! info "What actions are logged"
    Create User, Edit User, the post-create and post-edit assignment jobs, permission set /
    group assign and unassign from the [Explorer](permission-set-explorer.md), and Set
    Password all write log entries. Passwords are never included in log detail.

### Retention & access

- The uBox Admin permission set grants **View All** on the log object, so admins see all
  entries regardless of ownership.
- Logs are ordinary records — they persist across package upgrades and can be reported on
  like any custom object.

## Completion notifications

uBox defines a custom notification type, **uBox Assignment Complete**, delivered to
**desktop and mobile**. When an assignment job finishes, the admin who initiated it can
receive a notification summarizing the result:

- **"User Assignments Complete"** on success
- **"User Assignment Errors"** when something failed

The notification links to the corresponding uBox Log record, so one click takes you from
the alert to the full detail.

!!! note "Enabling the notification"
    Custom notifications are delivered through Salesforce's notification framework. If your
    admins aren't seeing them, confirm the **uBox Assignment Complete** notification type is
    enabled for the appropriate users under **Setup → Notification Delivery Settings**.
