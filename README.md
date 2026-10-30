# FARM (Flutter app)

Mobile/web wallet for FARM: send/receive, QR pay, deposit/withdraw, payment requests, business tools (payment links, invoices, payouts, developer API, projects), investments, Mkulima AI assistant & agent payments, travel (hotels/flights) and x402.

## Setup
1. Flutter stable (`flutter --version`), then `flutter pub get`.
2. `cp .env.example .env` and fill values (never commit `.env`).
3. Run: `flutter run --dart-define-from-file=.env` · Build: `flutter build apk --dart-define-from-file=.env` / `flutter build web --dart-define-from-file=.env`.
4. Tests: `flutter test`.

## .env keys
All optional with safe defaults (`lib/core/config/env.dart`): `API_URL`, `API_BASE_URL`, `BACKEND_URL`, `FRONTEND_URL`, `APP_SCHEME`, `APP_HOST`, `SUPABASE_URL`, `SUPABASE_ANON_KEY` (see `.env.example`). Point `API_BASE_URL` at the backend `/api/v1`.

## Architecture
- `lib/core/` — config, API client, auth/session, theme (black/white/grey brand).
- `lib/pages/<feature>/` — one folder per feature: dashboard, send_receive, q_r_scanner, depositpage, withdrawpage, payment_requests, business, merchant_*, investments / investment_marketplace / project_details, assistant + mkulima + agent_payments, travel, x402, kyc, security, settings, superadmin.
- Business features call the backend business endpoints; the AI assistant actions require PIN confirmation.

## Screen map
See [docs/SCREENS.md](docs/SCREENS.md) (screenshot index of every screen).
