# FundiMtaani — Live Web App Audit (for the iOS wrapper apps)

- **Audited:** 2026-11-07, from the **live code on Kerry's laptop** — `C:\Users\theegr8strr\Downloads\Projects\fundimtaani`, git HEAD `5964e8c` ("Trades manager: visual icon tile picker").
- **Method:** read-only bridge queries (`findstr`, PowerShell line ranges, model reads). Nothing was written to the laptop, nothing pushed or deployed. Brand files were fetched via base64-over-stdout only.
- **Stack:** single-file Flask app (`app.py`, ~5,100 lines) + `models.py` (SQLAlchemy) + Jinja templates + `static/`. Deployed to Vercel (`fundimtaani.me` / `fundimtaani.vercel.app`) with Neon Postgres as the production DB. Local `site_settings.json` on the laptop is legacy — **the DB `site_settings` table is the source of truth** for site status.
- **Counts:** **97 `@app.route` decorators, 93 distinct URL paths** (4 are aliases of the same view), of which **48 are `/admin/*`**.

---

## 1. Route inventory

### Public pages (no login)

| Route | Purpose |
|---|---|
| `/` | Home — featured approved fundis (limit 6) |
| `/fundis` | Fundi directory; AJAX filtering (`?partial=results`, `fetch` in `workers.html`) |
| `/api/suggest` | Search-suggestion JSON (GET, 30 req/min) |
| `/request`, `/post-job` | Same view: post a job request (GET+POST) |
| `/coverage` | Estate coverage page |
| `/guides` | Guides page |
| `/f/<int:worker_id>` | Short link → fundi profile |
| `/fundi/<int:worker_id>`, `/fundi/<int:worker_id>-<slug>` | Fundi profile (same view) |
| `/refer`, `/share`, `/invite` | Same view: invite/share (WhatsApp, X, Facebook) |
| `/waitlist` | Estate waitlist signup (GET+POST) |
| `/privacy`, `/terms`, `/about`, `/for-fundis`, `/contact`, `/help`, `/trust` | Static/info pages (`/contact` has a form) |
| `/saved` | Saved fundis page (JS/localStorage-driven) |
| `/photos/workers/<filename>` | Serves fundi profile photos |
| `/favicon.ico` | Serves `static/img/favicon.svg` as SVG |

### Auth (customer accounts)

| Route | Purpose |
|---|---|
| `/signup` | Register: name, Kenyan phone, email, password (≥8 chars), role customer/technician, 18+ checkbox, ToS/Privacy checkbox; issues email verification code |
| `/login` | Password login, identifier = **email OR phone**; blocked until email verified |
| `/login-code`, `/login-code/verify`, `/api/login-code` | Passwordless login: email → 6-digit code → verify (same neutral response for unregistered emails) |
| `/api/verify-code` | JSON endpoint for the 6-digit email-verification code |
| `/verify-pending`, `/resend-verification` | Verify-email holding page + resend |
| `/forgot-password`, `/reset-password/<token>` | 15-min single-use reset link |
| `/logout` | Logs out |
| `/account` | Account page (GET+POST) |
| `/unsubscribe` | Email unsubscribe (HMAC token, no CSRF) |

### Customer / fundi (logged-in)

| Route | Purpose |
|---|---|
| `/dashboard` | Customer dashboard |
| `/technician` | Fundi dashboard |
| `/technician/documents` (POST) | Fundi re-uploads a verification document |
| `/technician/photo` (POST) | Fundi updates profile photo |
| `/technician/verification/<int:doc_id>` | Fundi views own verification document |
| `/technician/booking/<int:booking_id>/<action>` (POST) | Fundi booking action: `confirm`, `complete`, `cancel` etc. (lifecycle-guarded) |
| `/fundi/<int:worker_id>/review` (POST) | Customer submits a review (5/hr) |
| `/fundi/<int:worker_id>/book` (POST) | Customer creates a booking |
| `/join` | Join wizard **step 1**: name, phone, trade category (or custom trade), estate, rate, experience, bio; one posting per account, resumes where left off |
| `/join/photo` | Join wizard **step 2**: profile photo upload |
| `/join/document` | Join wizard **step 3**: National ID or Passport upload |
| `/join/success/<int:worker_id>` | Join wizard **step 4**: waiting-for-review page |

**Join flow notes:** `_join_step()` = 1 details → 2 photo → 3 document → 4 done/awaiting review. Anonymous joiners are tracked by `session["join_worker_id"]` and linked to the account on signup. A second `before_request` hook (`_enforce_join_complete`) redirects technicians with an incomplete join back to the wizard for every endpoint not on an explicit open list (public pages, auth, join wizard, account, logout are open).

**Booking lifecycle** (`Booking` model): `requested → confirmed → in_progress → completed`, or `cancelled` at any point before completion. Aliases `new`/`contacted`/`done` still work. **Worker status:** `pending → approved | rejected`.

### Admin — `/admin/*` (48 routes, all `@admin_required` except login/TOTP)

| Route | Purpose |
|---|---|
| `/admin/login` | Admin password login (3 attempts/hour, fail-closed if `ADMIN_PASSWORD` unset) |
| `/admin/totp` | Second factor (TOTP code) when a TOTP secret is configured |
| `/admin/mfa` | MFA status/setup page (QR code) |
| `/admin/mfa/regenerate` (POST) | Generate a new TOTP secret (pending) |
| `/admin/mfa/confirm` (POST) | Confirm/activate the new TOTP secret |
| `/admin/logout` | Admin logout |
| `/admin` | Admin dashboard (KPIs, counts) |
| `/admin/bookings` | Booking list + kanban board view |
| `/admin/bookings/board/move` (POST) | Move a booking forward/back/cancel/reopen on the board |
| `/admin/booking/<int:booking_id>/nudge` (POST) | Email-nudge a fundi about a stale (>24h) booking |
| `/admin/booking/<int:booking_id>/<action>` (POST) | Admin sets booking status (requested/confirmed/in_progress/completed/cancelled) |
| `/admin/fundis` | Fundi list |
| `/admin/fundis/pending` | Pending fundi applications queue |
| `/admin/fundis/<int:worker_id>/scorecard` | Fundi scorecard (jobs, completion, rating, repeat rate, reviews) |
| `/admin/fundis/<int:worker_id>/notes` (POST) | Add a fundi coach note |
| `/admin/fundis/<int:worker_id>/notes/<int:note_id>/delete` (POST) | Delete a fundi coach note |
| `/admin/worker/<int:worker_id>/<action>` (POST) | Fundi action: `approve` (publishes + decision email), `reject` (with reason + email), `feature` (toggle), `delete` |
| `/admin/worker/<int:worker_id>/verify-doc/<int:doc_id>` (POST) | Mark a verification document verified |
| `/admin/worker/<int:worker_id>/decline-doc/<int:doc_id>` (POST) | Decline a verification document (with reason) |
| `/admin/verification/<int:doc_id>` | Serve a verification document file (image/PDF) for viewing |
| `/admin/documents` | Verification documents list |
| `/admin/reviews` | Reviews moderation list |
| `/admin/review/<int:review_id>/delete` (POST) | Delete a review |
| `/admin/users` | Users list |
| `/admin/user/<int:user_id>` | User detail |
| `/admin/user/<int:user_id>/<action>` (POST) | User action: `suspend`, `activate`, `role`, `verify_email`, `reset_password` (temp password) |
| `/admin/users.csv` | Download all users as CSV |
| `/admin/export/bookings` | Download all bookings as CSV |
| `/admin/export/workers` | Download all fundis as CSV |
| `/admin/disputes` | Dispute centre (cancelled bookings) |
| `/admin/disputes/<int:booking_id>/status` (POST) | Set dispute status |
| `/admin/disputes/<int:booking_id>/notes` (POST) | Add a dispute note |
| `/admin/disputes/<int:booking_id>/notes/<int:note_id>/delete` (POST) | Delete a dispute note |
| `/admin/waitlist` | Waitlist planner (estates, wa.me links) |
| `/admin/waitlist/launched` (POST) | Mark an estate launched + email its waitlist |
| `/admin/health/email` | Email delivery health (live DNS-over-HTTPS MX/SPF/DKIM/DMARC checks) |
| `/admin/broadcast` | Announcement emails to all/customers/technicians/one trade (Resend, respects unsubscribes) |
| `/admin/trades` | Trade/category manager (add/edit/delete, icon picker; delete blocked when fundis use the trade) |
| `/admin/trade/<int:category_id>/edit` (POST) | Edit a trade category |
| `/admin/trade/<int:category_id>/delete` (POST) | Delete a trade category |
| `/admin/settings` | Platform settings, incl. **site status** (live/maintenance/prelaunch), announcement banner, contacts |
| `/admin/backups` | Backups page (DB stats, per-table rows, activity) |
| `/admin/backups/validate` (POST) | Validate a backup file without touching the live DB |
| `/admin/backups/create` (POST) | Create a backup (single `.sql` file) |
| `/admin/backups/download/<name>` | **Download a backup `.sql` file** |
| `/admin/backups/delete/<name>` (POST) | Delete a backup |
| `/admin/backups/restore` (POST) | Restore from an uploaded backup (rate-limited 3/hr) |
| `/admin/audit` | Audit log (last 200 admin actions) |

Admin-only helpers with no route of their own: `admin_export_bookings()` (CSV builder used by the export routes).

---

## 2. Site modes

`_site_status()` (app.py ~2858) reads the DB `site_settings` table (key `site_status`), defaulting to `"live"`; an unknown value also falls back to `"live"`. Legacy one-way migration: if `site_status` is `"live"` but the old boolean `maintenance_mode` is truthy, the effective status is `"maintenance"` — a site in maintenance never silently flips back to live.

| Mode | Value | Public response | Page |
|---|---|---|---|
| Live | `live` | Normal (200) | — |
| Maintenance | `maintenance` | **503** | `templates/maintenance.html` |
| Pre-launch | `prelaunch` | **503** | `templates/prelaunch.html` |

**The gate** (`_maintenance_check`, `@app.before_request`): only paths starting with `/admin` or `/static` bypass it. **Everything else returns 503 in maintenance/prelaunch mode** — including `/`, `/fundis`, `/api/suggest`, `/favicon.ico`, `/photos/workers/<...>`, and the JSON APIs. There is **no `/health` route and no `/api/status` or any JSON endpoint that exposes the mode** — mode is only visible from the HTTP status code (200 vs 503) and which template is served. The setting is changed in `/admin/settings` (form field `site_status`, saved to the DB via `_save_site_settings()`).

**Live check (2026-11-07):** `https://fundimtaani.me` returned **HTTP 503** when fetched — the gate is currently active, i.e. the site is in maintenance **or** prelaunch mode. The two cannot be distinguished from the outside (both are 503); the exact value in the Neon DB could not be read from the laptop (its venv has no Postgres driver installed — see "Could not verify").

---

## 3. Auth

- **Customer login methods — both:** (a) **password** login at `/login`, identifier = email **or** phone + password (Werkzeug `password_hash`; 10 attempts/hr + 5 failures/15 min per IP); (b) **passwordless email code** at `/login-code` → `/login-code/verify` (6-digit code, SHA-256 stored, 10-min expiry, burned after 5 wrong attempts, 3 codes/hr per account; no code is sent for unregistered emails, neutral message either way).
- **Email verification (signup):** 6-digit code, SHA-256 stored, 10-min expiry, burned after 5 wrong attempts. **Login is blocked until the email is verified** (redirect to `/verify-pending`); accounts may exist with no email (legacy) and are prompted to add one. Signup requires name, Kenyan phone (unique), email (unique), password ≥ 8 chars, role = customer or technician, 18+ confirmation, ToS/Privacy acceptance.
- **Session cookie:** Flask's default cookie, name **`session`** (no custom `SESSION_COOKIE_NAME` set). `HttpOnly`, `SameSite=Lax`, `Secure` unless `FLASK_DEBUG` is on, `PERMANENT_SESSION_LIFETIME` = **4 hours**. Customer session keys: `user_id`, `user_role`, `session_version` (bumped on password change — stale sessions are dropped by `current_user()`). CSRF token lives in `session["_csrf_token"]` and is enforced by a global `before_request` (`csrf_protect`) on **every** POST/PUT/DELETE/PATCH (form field `csrf_token` or `X-CSRFToken` header; only `/unsubscribe` is exempt, it uses its own HMAC token).
- **Fundi join flow:** signup as technician (or anonymous `/join` first, linked on signup) → step 1 details → step 2 photo → step 3 ID/passport → step 4 waiting page. One Worker per account (`User.worker_profile`, 1-to-1). A technician logging in with an incomplete/pending join is forced back to the wizard or waiting page (`_post_login_target`); approved technicians land on `/technician`, customers on `/dashboard`.
- **Admin login:** **password first** (`ADMIN_PASSWORD` env var, compared with `hmac.compare_digest`, no default — login is disabled if unset), **then TOTP second factor if configured** (`/admin/totp`, pyotp, `valid_window=1`; secret lives in the DB `site_settings` key `admin_totp_secret`, legacy fallback `ADMIN_TOTP_SECRET` env var, migrates into the DB on first read). Password-only still works when no TOTP secret is set. Admin login also sends a login-alert email (new browser/device only) and is audited. Rate limit: 3 attempts/hour.
- **Are admin and customer sessions separate?** Same cookie jar, different flags: customer = `session["user_id"]` (+ role), admin = `session["admin"]=True` + `session["admin_hash"]` (first 16 chars of SHA-256 of the current `ADMIN_PASSWORD` — rotating the password invalidates admin sessions). `log_in_user()` calls `session.clear()`, so logging in as a customer wipes an admin session and vice-versa in the same WebView. Admin routes check only the `admin` flag (`admin_required`); customer routes check `user_id`/`user_role`. A `User` can also have role `admin`, but the admin console does **not** use the User login — it uses the separate `ADMIN_PASSWORD` gate.

---

## 4. Branding

Fetched live from `static/img/` on the laptop into `~/workspace/fundimtaani-ios/brand/` — **real files, not redrawn**. Byte sizes match the laptop exactly.

| File | Size | SHA-256 (first 16) | Notes |
|---|---|---|---|
| `brand/logo.svg` | 1,325 B | `8122b9bcc82c96cb` | Main logo, 320×68 viewBox; deep-green `#0F4C3A` rounded-square emblem + wordmark |
| `brand/logo-white.svg` | 1,352 B | `07701685b927991a` | White version (dark backgrounds, emails) |
| `brand/logo-mark.svg` | 693 B | `5f7518792715b60f` | Mark/emblem only — use for the app icon base |
| `brand/favicon.svg` | 755 B | `bc311a4c2dec8e9d` | Served at `/favicon.ico` (`image/svg+xml`) |
| `brand/logo-white-email.png` | 17,662 B | `dce05211e20a85a7` | PNG, 640×136, RGBA |

Brand colours in the live CSS/templates: primary `#0F4C3A`, hover `#0A3327`, accent `#D97706`, WhatsApp `#25D366`, ink `#0F172A`, body `#334155`. Font: Plus Jakarta Sans (Google Fonts — see gotchas).

---

## 5. WebView gotchas checklist (WKWebView wrapper)

- [ ] **Top-level load only, never an iframe.** The site sends `Content-Security-Policy: frame-ancestors 'none'` and `X-Frame-Options: DENY`. A WKWebView loading `https://fundimtaani.me` directly is fine; embedding it in an iframe or another web view is blocked.
- [ ] **Session cookies must persist.** Auth is entirely cookie-based (`session` cookie, 4-hour lifetime). Use a persistent `WKWebsiteDataStore` (default, non-ephemeral) and do **not** clear cookies on app restart. Both apps need their **own** data store — customer and admin sessions wipe each other in the same jar (`session.clear()` on login).
- [ ] **CSRF on every POST.** All forms carry a hidden `csrf_token`; the two JSON code endpoints (`/api/verify-code`, `/api/login-code`) are also POSTs under the same guard. A wrapper that replays POSTs natively must send the token; loading pages in the WebView as-is works unchanged.
- [ ] **File inputs work natively — but there is no `capture` attribute.** Join photo (`accept=".png,.jpg,.jpeg,.webp"`), join document (`accept=".pdf,.png,.jpg,.jpeg,.webp"`), technician photo/document re-uploads, and admin backup restore (`accept=".sql,.zip"`) all use plain `<input type="file">`. iOS will offer Take Photo / Photo Library / Files automatically. No extra native camera code is needed; do **not** add `capture` handling.
- [ ] **Permissions-Policy header:** `geolocation=()`, `microphone=()`, `camera=(self)`, `payment=()`. No geolocation or microphone is used anywhere (zero matches in templates/JS); camera is allowed for the same origin only.
- [ ] **No location, push, or native APIs in the site.** No `navigator.geolocation`, no `getUserMedia`, no service worker, no web manifest. Nothing in the site needs a native handler except the scheme links below.
- [ ] **`wa.me` links are everywhere and must leave the WebView.** Fundi cards, fundi profiles, saved page, contact, footer, maintenance/prelaunch pages, admin disputes/dashboard/waitlist — all `https://wa.me/...` with `target="_blank"`. Intercept in `decidePolicyForNavigationAction` and open in WhatsApp/Safari. Same for `tel:` links (Call button on fundi profile + saved page) and `mailto:` links (support email in footer/contact/help/terms).
- [ ] **`target="_blank"` is used heavily** (all wa.me links, admin document/photo viewers, share links on `/refer` — WhatsApp, X, Facebook). A WKWebView with no `createWebViewWith` handler will silently swallow these. Implement the delegate to open them externally (or in a new in-app tab for admin document viewing).
- [ ] **Downloads (admin app only).** `/admin/backups/download/<name>` (`.sql` file, plain GET link), `/admin/users.csv`, `/admin/export/bookings`, `/admin/export/workers` (CSV), plus a `download="fundimtaani-qr.png"` link in `base.html` (invite QR). Implement `WKDownloadDelegate` / a download handler in the admin app, or these taps will do nothing. Verification documents (`/admin/verification/<id>`) are served inline (image/PDF) and open in new tabs.
- [ ] **CDN + font dependency — the site needs the internet.** Bootstrap 5.3.3 CSS/JS comes from `cdn.jsdelivr.net` and fonts from Google Fonts (CSP allows both). Offline the site degrades badly; the wrapper should show its own offline state rather than a broken page.
- [ ] **AJAX is same-origin only.** `fetch("/api/suggest?q=...")` (search suggestions) and `/fundis?partial=results` (filtering without reload) are same-origin GETs — no CORS work needed. `connect-src 'self'` in the CSP confirms this.
- [ ] **Rate limits will bite a wrapper that retries aggressively.** Login 10/hr, admin login 3/hr, signup 10/hr, code verify 10/15 min, uploads 10/hr, backup restore 3/hr. Do not auto-retry failed logins; surface the server's 429 page.
- [ ] **Error pages are branded HTML, not JSON.** 400/403/404/429/500 all render `templates/errors/*.html` with the correct status. A wrapper can detect these by status code (429 = rate-limited, 503 = site mode, see §2).
- [ ] **Maintenance/prelaunch pages are part of the customer app's job.** Both modes return the *same* 503 status — the wrapper tells them apart only by which page the WebView loaded (`maintenance.html` vs `prelaunch.html`, distinguishable by page title/body). Both pages contain a wa.me link to `+254799242459`.
- [ ] **Admin app must not be reachable from the customer app.** There is no public link to the admin console anywhere on the site (deliberate). The admin app must hard-code its own entry URL; the customer app must not deep-link to `/admin`.
- [ ] **Technician gate affects fundi logins in the customer app.** A technician whose join is incomplete is redirected to the wizard/waiting page on almost every endpoint — the wrapper must follow redirects, not treat them as errors.

---

## 6. Wrapper design implications

**Customer app:** entry URL `https://fundimtaani.me/` in a WKWebView with a persistent, private cookie store; mode detection is purely by HTTP status — 200 = live, 503 = maintenance or prelaunch (distinguish the two by the loaded page's content, since there is no health/status endpoint to query). On 503 the app should show the site's own page as-is (it already explains the state and links to WhatsApp) rather than replacing it with a native screen. Navigation handling must open `wa.me`, `tel:` and `mailto:` links externally, handle `target="_blank"`, and let file inputs use the system picker for the join wizard (photo + ID/passport). No native auth, push, camera, or location code is needed — the site's password/email-code login, email verification, and booking/review flows all run inside the WebView on the existing session cookie.

**Admin app:** a separate app with its **own** cookie store, entry URL `https://fundimtaani.me/admin` (the `/admin` prefix bypasses the maintenance/prelaunch gate, so the admin app stays usable while the public site is down). It must support the password + optional TOTP login flow, file downloads (`.sql` backups and CSV exports via a download delegate), `target="_blank"` document/photo viewers, and the same wa.me/tel/mailto handling as the customer app — admin pages link out to WhatsApp for fundis, clients, and waitlist contacts. Because `session.clear()` on login wipes the other session type, the two apps must never share a cookie store.

## Could not verify

1. **Exact live `site_status` value (maintenance vs prelaunch).** `fundimtaani.me` returns HTTP 503, which proves the gate is active, but both modes return 503. The value lives in the Neon DB `site_settings` table; the laptop's venv has **no Postgres driver installed** (`psycopg2`/`psycopg` both missing, `pip list` shows none), so a read-only DB probe from the laptop was not possible. A one-line read against Neon (or the admin Settings page) will settle it.
2. **Whether admin TOTP is actually configured on the live DB** (i.e. whether `/admin/login` currently goes to `/admin/totp`). Same blocker as (1) — `admin_totp_secret` presence in `site_settings` could not be read. Code-wise TOTP is optional: password-only login works when no secret is set.
3. **Live runtime behaviour** (actual login, wizard upload, backup download in a real WKWebView) — code-level audit only; no live session was created and no test data was submitted.
