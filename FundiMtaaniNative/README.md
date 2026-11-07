# FundiMtaani (native customer app, v1)

A genuine native SwiftUI app for FundiMtaani — not a WebView wrapper.
It talks to the live website through the real JSON API
(`https://fundimtaani.me/api/v1`, Phase 1 blueprint, commit `504b27c`
on `leonfeeney1/fundimtaani`).

## What v1 does (Phase 1 customer core)

- **Mode handling:** on launch the app calls `GET /api/v1/status`. While
  the site is in pre-launch or maintenance it shows a native mode
  screen (real announcement text + support contacts from the server),
  never the site's 503 HTML. Offline gets its own screen with Retry.
- **Home:** search (trade + estate), Browse by Trade, featured and
  recently-joined fundis, live stats, testimonials, How It Works,
  Coverage.
- **Explore:** fundi search with trade / estate / text / emergency /
  available-today / minimum-rating filters and featured / newest /
  rating / reviews sorting.
- **Fundi profile:** photo, Verified badge, trade, estate, rating +
  breakdown, reviews, rate, experience, bio, certifications,
  operating hours; Book + WhatsApp buttons; save to Saved.
- **Booking:** date / slot / message form, confirmation screen.
  Creates a Booking (status `requested`); no payment step exists —
  customers pay fundis directly.
- **My Bookings:** own bookings, newest first, filterable by status,
  with a detail screen (including dispute case status when one exists).
- **Auth:** password login, email-code login, signup (customer or
  fundi), email verification (6-digit code), forgot / reset password.
  Auth is the same Flask session cookie as the website, kept in the
  shared cookie storage — the app never stores a password or a token.
- **Saved fundis:** app-local only in v1 (there is no server model;
  the website keeps saved fundis in localStorage). Cross-device saved
  needs the Phase 2 `SavedFundi` model.

## What v1 does NOT do (Phase 2)

Join-as-fundi wizard, reviews, technician dashboard, request-a-job,
account email change, static pages, waitlist, refer/share. The
fundi-application rows in Account open the website's join page for
now, and say so in the app.

## Honest limits

- **The live site is in pre-launch right now.** Every API call except
  `status`/`health` returns JSON 503 `site_unavailable` until Kerry
  flips the site live. The app handles that gracefully (mode screen),
  but login, search, and booking cannot be exercised against the live
  API until then. The API client was verified against the documented
  contract (mocked responses + the live status call), not against live
  discovery/auth calls.
- **Reset password has no deep link yet.** The reset email carries a
  web link; the app's reset screen takes the token pasted from it.
  A universal link needs an associated-domains entry (Phase 2).
- **Unsigned IPA.** The build below produces an unsigned IPA for
  sideloading (AltStore / Sideloadly / TrollStore), exactly like the
  wrapper builds. A signed build needs an Apple Developer account and
  a signing identity — none is configured here.
- **No push notifications, payments, or chat.** None exist on the
  website either; contact happens over WhatsApp outside the system.

## Open / run

Requires Xcode 16+ on a Mac, iOS 17+ target. Open
`FundiMtaaniNative.xcodeproj`, pick the `FundiMtaaniNative` scheme,
run on a simulator or a device.

## Build the unsigned IPA (GitHub Actions)

`.github/workflows/ios-build-native-customer.yml` (repo root) runs on
pushes to `FundiMtaaniNative/**`: simulator build (Debug), then a
Release archive with `CODE_SIGNING_ALLOWED=NO`,
`CODE_SIGN_IDENTITY=""`, `CODE_SIGNING_REQUIRED=NO`, zipped as
`FundiMtaaniNative-unsigned.ipa` and uploaded as the artifact
`FundiMtaaniNative-unsigned-ipa` (30-day retention).

## Files

- `FundiMtaaniNativeApp.swift` — entry, mode check on launch and on
  return from background.
- `Brand.swift` — real brand colours, trade icon map, photo URL rules.
- `Models.swift` — Codable models, field-for-field from `api_v1.py`.
- `APIClient.swift` — all 24 Phase 1 endpoints, session-cookie auth,
  envelope + error mapping (401 / 403 / 404 / 409 / 429 / 503
  `site_unavailable`).
- `AppState.swift` — site mode + signed-in user.
- `ContentView` (in the App file) — loading / mode / live tabs.
- `ModeView.swift` — pre-launch / maintenance / offline screens.
- `SharedViews.swift` — fundi cards, photos, stars, error banners.
- `HomeView.swift`, `FundiListView.swift`, `FundiDetailView.swift`,
  `BookingFormView.swift`, `BookingsView.swift`, `AuthViews.swift`
  (login, code login, signup, verify, forgot, reset),
  `AccountView.swift`, `SavedView.swift`, `CoverageView.swift`.
- `Assets.xcassets` — real logo mark as AppIcon + launch logo
  (rendered from `brand/logo-mark.svg`, same mark as the website).
