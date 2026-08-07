# Permissions Comparison

The **Permissions Comparison** tab answers a question admins ask constantly: *"Why can this
user do something that user can't?"* Pick two users and uBox shows a side-by-side **A | B**
diff of everything that differs between them — and **only** what differs.

## Running a comparison

1. Open the **Permissions Comparison** tab.
2. Select **User A** and **User B** (they must be two different users).
3. uBox computes each user's effective access and returns the differences.

If the two users have identical effective access, uBox tells you there are no differences.

## What gets compared

The comparison covers both the *mechanisms* that grant access and the *effective access*
those mechanisms produce.

**Access mechanisms**

- **Profile** — flagged when the two users have different profiles
- **Permission sets** — which each user has that the other doesn't
- **Permission set groups**
- **Public groups**
- **Permission set licenses**
- **Package licenses**

**Effective permissions**

- **System permissions** — user-permission toggles one user has and the other doesn't
- **Object permissions** — objects present for only one user, plus objects both can access
  but with **different** CRUD (Read/Create/Edit/Delete/View All/Modify All)
- **Field security** — fields where Read/Edit differ between the two users
- **Tab settings** — tabs whose visibility differs
- **App access** — apps one user can see and the other can't
- **Custom permissions** — custom permissions held by only one user

## Reading the results

For each category, results are grouped as:

- **Only A** — present for User A but not User B
- **Only B** — present for User B but not User A
- **Different** — present for both, but configured differently (shown with both A and B
  values so you can see exactly how they diverge)

The diff is computed on the server, so the results you see are just the deltas — there's no
wading through everything the two users have in common.

!!! tip "Comparison vs. the single-user report"
    Use **Permissions Comparison** to explain a *difference between two users*. Use the
    **[User Permission Report](user-permission-report.md)** to document *one user's*
    complete access.
