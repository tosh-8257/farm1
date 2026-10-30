# Tap to pay (app)

- **Entry:** Send & Receive shows "Pay by tap" and "Receive by tap" only when `GET /nfc-pay/config` says the feature is enabled (backend `NFC_PAY_ENABLED`).
- **Receive** (`TapReceivePage`):
  - You enter an amount; the backend creates a signed request that lasts about 60 seconds and can be used once.
  - On Android with HCE and NFC on, `FarmPayHceService` (Kotlin, `android/app/src/main/kotlin/.../FarmPayHceService.kt`) emulates a Type 4 NDEF tag with `farmpay:<token>`.
  - Otherwise (iOS, web, NFC off) the same token is shown as a QR code automatically. You can also switch to the QR by hand.
  - The screen shows a countdown, the merchant fee or payer fee, and what you receive. It polls the status and shows Paid or Expired.
- **Pay** (`TapPayPage`):
  - On Android with NFC, `nfc_manager` reads the tag; otherwise the camera scans the QR. The main QR scanner also recognises `farmpay:` codes.
  - The app resolves the token on the backend, then shows the payee, the amount, your exact fee and the total. You confirm with your PIN.
  - Amounts never come from the tag.
- **States:** loading, empty form, error with retry, expired and paid.

## Needs real-device testing
- Android ↔ Android HCE: tag discovery, AID `D2760000850101` routing, a locked screen (`requireDeviceUnlock=true`), and a conflict with another payment app set as the default.
- `nfc_manager` reading the emulated Type 4 tag on a range of Android phones.
- iOS: NFC reading is deliberately not used. It would need the Core NFC entitlement and a provisioning profile. iOS uses the QR path.
