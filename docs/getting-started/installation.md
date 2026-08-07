# Installation

uBox is distributed as a Salesforce 2GP **managed package**. Installing it adds the uBox
Lightning app, its tabs, Apex, and the `uBox_Log__c` object to your org under the `ubox`
namespace.

## Install the package

1. Log in to the org you want to install into (production or sandbox).
2. Open the install link for the version you want. The current install URL is published in
   the project [README](https://github.com/){: .external } and takes the form:

    ```
    https://login.salesforce.com/packaging/installPackage.apexp?p0=<PACKAGE_VERSION_ID>
    ```

    !!! tip "Installing into a sandbox"
        Replace `login.salesforce.com` with `test.salesforce.com` in the URL.

3. Choose **Install for Admins Only** (recommended) and complete the install.

## After installing

1. Assign the **uBox Admin** permission set to any user who needs access — see
   **[Access & Permissions](permissions.md)**.
2. Open the **App Launcher** and search for **uBox** to open the app.

## Requirements & compatibility

- **Editions:** Any edition that supports managed packages and custom Lightning apps.
- **State & Country picklists:** Fully supported but *not* required. uBox detects whether
  State & Country/Territory picklists are enabled and adapts the address fields
  accordingly — the package installs cleanly either way.
- **Permissions the admin needs:** The uBox Admin permission set grants the
  `ManageInternalUsers` and `AssignPermissionSets` user permissions that the create/edit
  flows depend on. See [Access & Permissions](permissions.md).

## Upgrading

Install a newer package version link into the same org; managed-package upgrades preserve
your data, including the uBox activity logs. See the
[Changelog](../reference/changelog.md) for what changed between versions.
