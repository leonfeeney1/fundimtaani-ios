# FundiMtaani — Native Customer App v1 (SwiftUI) — Build Notes

**Date:** 7 November 2026
**API:** Phase 1 blueprint, commit `504b27c` on `leonfeeney1/fundimtaani`
(live: `/api/v1/status` 200 JSON, `site_status: "prelaunch"`).
**Repo:** `leonfeeney1/fundimtaani-ios` (public), new project
`FundiMtaaniNative/`, workflow `.github/workflows/ios-build-native-customer.yml`.
**Status:** structure + contract checks pass (84/84, see below). No Xcode
compile was possible on this Linux VM — the GitHub Actions run is the
first real compile.

## What was built

A genuine native SwiftUI app (iOS 17+, iPhone-only, Swift 5, zero
external dependencies), bundle `me.starford.fundimtaani`, version 1.0
(build 1). NOT a wrapper — no WKWebView anywhere.

**Screens (Phase 1 customer core, audit §3.1 #1–4, #6–13):**
- Launch + mode handling: `GET /api/v1/status` on launch and on every
  return from background. Live → tabs; prelaunch/maintenance → native
  mode screen (real announcement + support contacts from the payload);
  status-call failure → offline screen with Retry. Any gated call
  returning 503 `site_unavailable` re-checks the mode.
- Home: search (trade + estate pickers), Browse by Trade grid, featured
  + recent fundis, live stats, testimonials, How It Works, Coverage.
- Explore: fundi search with trade / estate / text / emergency /
  available-today / minimum-rating filters; sort featured / newest /
  rating / reviews.
- Fundi profile: photo, Verified badge, trade, estate, rating +
  breakdown, reviews, rate, experience, bio, certifications,
  operating hours; Book + WhatsApp buttons; save heart.
- Booking form: date / slot / message → confirmation. DO-NOT-RETRY
  enforced in UI: submit disabled while in flight; a network failure
  shows "unknown outcome — check My Bookings before trying again"
  instead of re-posting.
- My Bookings: own bookings, newest first, status filter, detail
  screen (fundi + dispute case status when one exists).
- Auth: password login, email-code login (request + verify), signup
  (customer / fundi role), email verification (6-digit code, resend
  with optional email correction), forgot / reset password.
- Account: user details from `GET /api/v1/auth/me`, sign out, fundi
  application row (opens the website join page — in-app wizard is
  Phase 2, and the app says so).
- Saved fundis: app-local only (UserDefaults, cached summaries). No
  server model exists yet — audit endpoints #32–34, Phase 2.
- Coverage: the 7 zones from `GET /api/v1/coverage`, never hardcoded.

**API client (`APIClient.swift`):** all 24 Phase 1 endpoints. Same
Flask session cookie as the website (default URLSession config, shared
cookie storage, never cleared). Uniform envelope
`{ok, data}` / `{ok, error:{code, message}}`; error mapping covers
401 / 403 / 404 / 409 / 429 (with `Retry-After`) / 503
`site_unavailable` (with `site_status`). Mutating calls send
`Content-Type: application/json` (the server 400s otherwise).

**Design:** real brand only — deep green #0F4C3A, darker #0A3327,
amber #D97706, WhatsApp #25D366, ink #0F172A, body #334155, light bg
#F8FAFC. System font (Plus Jakarta Sans is a web font). Real logo
mark as AppIcon + launch logo (copied from the wrapper project's
rendered PNGs — same `brand/logo-mark.svg` mark; all PNGs
pixel-verified non-blank, launch logo at 120/240/360). SF Symbols
only, zero emojis. Light + Dark modes. One primary action per screen.

## Structure + contract checks — 84/84 PASS

Script: `/tmp/verify_native.py` (not kept in the repo; rerun from the
workspace if needed). Results 7 Nov 2026:
- `project.pbxproj` parses with the `pbxproj` library (165 objects);
  zero `,,` defects; braces/parens balance; all 16 Swift files on
  disk referenced and in the Sources phase; every referenced ID
  defined; object IDs unique; bundle id `me.starford.fundimtaani`;
  iPhone-only (`TARGETED_DEVICE_FAMILY = 1`); deployment target 17.0;
  `GENERATE_INFOPLIST_FILE = NO`; `INFOPLIST_FILE =
  FundiMtaaniNative/Info.plist`.
- Scheme XML parses; BlueprintIdentifier
  `7505EEE149EEC27D008C2FAA` matches the PBXNativeTarget id.
- `Info.plist` parses: v1.0, UILaunchScreen + LaunchLogo, arm64.
- Assets: all `Contents.json` parse; all referenced PNGs exist and
  are non-blank; 1024 AppIcon present.
- Workflow YAML parses; uses `-scheme FundiMtaaniNative`; uploads
  artifact `FundiMtaaniNative-unsigned-ipa`; path-filtered to
  `FundiMtaaniNative/**`; `CODE_SIGNING_REQUIRED=NO`.
- All 16 Swift files: braces/parens balance, zero emojis.
- API contract: every path the Swift client calls exists as an
  `@api_v1.route` in `api_v1.py` (24/24 routes); all 24 Phase 1
  routes are called by the client; all 37 CodingKeys JSON keys exist
  server-side.
- Live check 7 Nov 2026 ~20:35 EAT: `GET /api/v1/status` → 200 JSON,
  `site_status: "prelaunch"`; `GET /api/v1/health` → 200.

## Deliberate deviations / honest limits

1. **Reset password has no deep link.** The reset email carries a web
   link; the app's reset screen takes the token pasted from it (the
   part after `/reset-password/`). A universal link needs an
   associated-domains entry (Phase 2, needs Kerry's Apple Team ID —
   same as the PremiumSlots passkey AASA item).
2. **Technician signup** continues into the join wizard only in Phase
   2. After verification the app shows the join row that opens
   `https://fundimtaani.me/join` in Safari, labelled as such.
3. **Saved fundis are app-local** (see above).
4. **No live login/search/booking test was possible.** The site is in
   prelaunch: every API call except status/health returns JSON 503
   `site_unavailable`. The client was verified against the documented
   contract (route + JSON-key checks above, plus the live status
   call), not against live discovery/auth calls. Those become testable
   the moment Kerry flips the site live — do NOT ask him to flip it
   for testing.
5. **No Xcode compile here.** The Actions run is the first compile.
   If it fails, read the full log in the signed-in browser and fix
   one error set at a time — do not guess from the step name alone.
6. **Unsigned IPA** (sideloading only). Signed builds need an Apple
   Developer account — none configured.

## Ship / push

Ship `FundiMtaaniNative/` + `.github/workflows/ios-build-native-customer.yml`
to the laptop clone (`C:\Users\theegr8strr\Downloads\Projects\fundimtaani-ios`),
commit explicitly (never `git add -A`), push to main. The workflow
triggers on `FundiMtaaniNative/**` paths. The wrapper projects
(`FundiMtaani/`, `FundiMtaaniAdmin/`) were NOT touched.

## Files

- `FundiMtaaniNative/` — Xcode project (16 Swift files, Assets, Info.plist, README.md)
- `.github/workflows/ios-build-native-customer.yml` — Actions workflow
- `BUILD_NOTES_NATIVE.md` — this file
