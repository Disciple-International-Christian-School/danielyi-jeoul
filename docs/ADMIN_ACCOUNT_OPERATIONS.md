# Personal Admin Account Operations

**Language / 언어:** [English](ADMIN_ACCOUNT_OPERATIONS.md) | [한국어](ADMIN_ACCOUNT_OPERATIONS.ko.md)

> For October 28 eligibility changes and G9 responsibility routing, use [current discipline rules](DISCIPLINE_RULES.md). Earlier designs and snapshots below remain dated historical evidence.

> Purpose: transition Daniel's Scale from shared role accounts to individual authenticated staff accounts while preserving continuity and auditability.

## 1. Why individual accounts

Shared accounts answer:

    Which role did this?

Individual accounts answer:

    Which authenticated operator did this?

Daniel's Scale now stores authenticated actor UUIDs on new records and maintains append-only audit logs. Individual accounts therefore improve operational accountability without changing student-facing behavior.

## 2. Transition policy

Do not delete the existing shared accounts first.

Recommended sequence:

    personal accounts provisioned
    → real workflow tested
    → responsibility scopes confirmed
    → audit trail reviewed
    → shared account use stops
    → shared accounts disabled

Historical rows remain valid even after a shared account is disabled.

## 3. Account creation

Only an active SEONDO lead can open the Admin Accounts console.

Required fields:

- login ID
- display name
- role
- SEONDO responsibility scope
- lead status if applicable

Login ID rules:

    3–32 characters
    lowercase letters
    digits
    . _ -

The system creates the internal synthetic Auth email:

    <login_id>@scale.dics.kr

Operators continue to type only the login ID on the sign-in page.

## 4. Temporary password

The provisioning Edge Function generates a strong random temporary password.

The temporary password:

- is returned to the lead once,
- is never stored in Git,
- is never written to the admins profile table,
- is not shown again in the admin console,
- must be transferred to the intended staff member through an appropriate private channel.

Do not post temporary credentials in GitHub Issue, PR, shared school documents, or public chat logs.

## 5. First login

New personal accounts start with:

    must_change_password = true

After login, the operator cannot access normal Daniel's Scale screens.

Instead the app forces a password-change screen.

Password policy enforced by the application:

- at least 12 characters,
- uppercase,
- lowercase,
- digit,
- special character.

Password completion is handled by the JWT-required Edge Function:

    change-admin-password

The completion flag is cleared only after the real Supabase Auth password update succeeds.

## 6. Responsibility scopes

SEONDO:

    ELEMENTARY = G1–6
    MIDDLE     = G7–9
    HIGH       = G10–12
    ALL        = lead

A lead account is always normalized to:

    role  = SEONDO
    scope = ALL

SASAENG accounts do not receive a discipline scope and cannot be SEONDO lead.

## 7. Disabling an account

Use account deactivation rather than deleting the profile.

Effects:

- private.current_admin_role() returns no operational role,
- protected app routes reject the account,
- past created_by / updated_by relationships remain,
- audit history remains,
- account can be reviewed or reactivated later.

The system blocks removal of the final active SEONDO lead.

## 8. Current transition state

At the time this runbook was created:

    admin profiles                 2
    active admins                  2
    active SEONDO leads            1
    personal accounts provisioned  0
    must-change-password accounts  0

The existing role accounts therefore remain the production fallback.

## 9. Deployment components

Database:

- admins.login_id
- admins.must_change_password
- admins.last_password_changed_at
- admins.provisioned_by
- v_admin_accounts
- register_admin_profile(...)
- update_admin_profile(...)

Edge Functions:

- provision-admin-account
- change-admin-password

Both Edge Functions require a valid JWT.

The Auth Admin API runs only in the Edge Function server environment with the Supabase service credential. It is never exposed to browser JavaScript.

## 10. First rollout checklist

For each real staff account:

1. lead creates the account,
2. lead privately transfers login ID + temporary password,
3. staff member logs in,
4. staff member sets a new password,
5. confirm displayed role and responsibility scope,
6. enter one non-destructive test or use a controlled workflow,
7. verify audit actor name,
8. confirm the operator cannot access out-of-scope screens/data,
9. continue normal use.

Do this gradually before disabling the shared account.

## 11. Final shared-account retirement gate

Disable the legacy shared account only when:

- every required operator has an individual account,
- every account completed first-login password change,
- responsibility scopes are correct,
- lead access has redundancy,
- audit logs show personal actors,
- no daily operational workflow still depends on the shared credential.

Do not delete historical Auth/profile records solely to make the account disappear from daily use.
