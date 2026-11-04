# Homeroom Web Push

**Language / 언어:** [English](HOMEROOM_PUSH.md) | [한국어](HOMEROOM_PUSH.ko.md)

Teachers open `/teacher` and use their registered Google account. Core staff accounts and current-term class assignments are shared identity data. They grant only the class-scoped portal RPC, not discipline editing or administrator access. Email confirmation is checked against `auth.users`; editable JWT user metadata is never used for authorization.

The teacher opts in on each device. iOS requires a Home Screen web app. Browser notification permission alone does not register a device: the authenticated subscription RPC must succeed. Sign-out disables this device's subscription. Closing the page preserves registration; opening a notification requires authentication again if the session has expired.

The database polls the existing `v_reflections` eligibility view each minute. MISSING and DOUBLE transitions produce separate events. Existing eligible statuses are baselined, and subscriptions only receive events observed after activation. The delivery worker rechecks current eligibility, active staff, verified account email, current-term class assignment and active subscription. It leases ten jobs per invocation, retries up to five attempts and disables expired endpoints after HTTP 404/410. A stable notification tag reduces duplicates after an uncertain delivery acknowledgement; exactly-once delivery is not guaranteed.

VAPID keys and the dispatch token are stored in a private table with no client access. The Edge Function validates its dispatch token independently, and service-only RPCs expose worker configuration and deliveries. Push endpoints are restricted to supported Google, Mozilla and Apple push services. Notification payloads contain no student names or discipline details. Opening a notification always uses the fixed same-origin teacher route.

Operational identities and keys are seeded outside Git. `core.staff_accounts` holds allowed confirmed emails; `core.homeroom_staff` references existing `core.classes` UUIDs. Keep these assignments synchronized when a term or teacher changes. A changed email or disabled staff immediately blocks portal access and cancels pending deliveries. Remove obsolete subscriptions as part of staff offboarding.

Validation: build/typecheck, rollback SQL checks in `supabase/tests/homeroom_push.sql`, service worker tests, and successful empty-queue production worker invocation. Actual Google redirect completion and delivery on teacher phones remain rollout checks; neither is established by database tests. Run a test notification before inviting other teachers to opt in. If Google returns to another app, add the exact `/teacher` URL to Supabase Auth's redirect allowlist without removing existing apps.
