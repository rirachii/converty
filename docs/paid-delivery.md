# Paid download delivery

## Current behavior

Verified September 20, 2026.
The production site is https://converty.halfwind.studio and its purchase button uses https://buy.stripe.com/aFa28r12h9bVgdq5wB4ZG00.
The live Stripe account is `acct_1R0Fa8IjB4cpWCRt`, and the payment link is `plink_1UGtgUIjB4cpWCRtN8Am3sj3`.
Other Stripe accounts can share the same display name; verify the account ID before making changes.

The product is a $9 one-time lifetime purchase.
Stripe uses a hosted confirmation message containing the Converty 0.1.2 installer URL, Apple Silicon/macOS 14 requirements, installation help, and the unnotarized early-release disclosure.
This replaced the promise to email access details, which had no verified Converty email-delivery integration.
The message is limited to 500 characters.

The app has no automatic updater.
Customers install updates by quitting Converty, downloading the newer DMG, and replacing the app in Applications.
Publishing a new GitHub release does not update the Stripe message, previously sent emails, or installed apps.

The release repository and installer are currently public.
The paid landing page and post-payment placement of the link do not enforce purchase access to the binary.
Do not describe the installer as protected by payment verification.
Do not add direct installer links to the paid landing page.

## Email setup still pending

The owner requested a Halfwind/Converty sender rather than personal Gmail.
The proposed setup is a `michelle@halfwind.studio` mailbox with `support@halfwind.studio` as a send-capable alias, displayed as Converty Support.
The mailbox, alias, and automatic purchase emails are not configured or verified yet.
Domain forwarding alone does not provide authenticated outbound email.
Do not claim a purchase email was sent without a send result from the configured provider.
Stripe receipt history only establishes Stripe receipt delivery, not an independent fulfillment email.
Keep customer email addresses, payment details, and message IDs out of this public repository.

After the sender is configured, verify both outgoing mail authentication and replies before using it for customer delivery.
An automatic delivery integration must verify Stripe webhook signatures, filter to this payment link/product, require paid status, handle delayed payment success, and prevent duplicate messages when Stripe retries.
Unrelated account-wide integrations are not proof of Converty delivery.

## Purchase email template

Subject: Your Converty download

```text
Hi,

Thank you for buying Converty!

Download Converty 0.1.2 for Apple Silicon Macs:
https://github.com/rirachii/converty/releases/download/v0.1.2/Converty-0.1.2-macOS-arm64.dmg

This version includes the visual video trim bar.
It requires macOS 14 or later and an Apple Silicon Mac (M1 or newer).

Open the DMG, drag Converty into Applications, and open it from there.
This is an early release and is not yet notarized by Apple.
Installation help: https://converty.halfwind.studio/#install

To install a future update, quit Converty and replace the app with the newer download.
The app does not currently check for updates automatically.

If you need help, reply to this email.

Michelle
Converty / Halfwind
```

For delayed fulfillment, add a brief apology for the wait before the download link.
Send only after the intended sender is configured and the purchase is verified.

## Release handoff

1. Publish and verify the versioned installer and corresponding source/license assets using `macos-release.md`.
2. Update the hosted confirmation's installer URL and version, keeping the message under 500 characters.
3. Read the payment link back from Stripe and verify the actual confirmation preview.
4. Update the purchase-email template and any deployed email integration.
5. Verify a successful paid checkout exposes the download without waiting for email; use test mode for payment testing.
6. Verify the email provider's send result separately from checkout success and file-download availability.

Do not send update announcements to prior buyers without explicit authorization.
