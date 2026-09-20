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

## Temporary sender and pending automation

The owner requested a Halfwind/Converty sender rather than personal Gmail.
Until Google Workspace is configured, the authorized temporary sender is `admin@evergoodsholdings.com`.
This is an existing send-capable alias in the Zoho Mail mailbox whose primary address is `hello@evergoodsholdings.com`.
Select the admin alias explicitly when composing; the mailbox defaults to its primary address.
Replies to the temporary sender return to the existing Zoho mailbox.
On September 20, a manual purchase email was sent from this alias and Zoho confirmed delivery to the recipient's mail server over TLS.
That confirmation does not establish that the buyer opened the email or downloaded or installed Converty.

The intended permanent setup is a Google Workspace `michelle@halfwind.studio` mailbox with `support@halfwind.studio` as a send-capable alias, displayed as Converty Support.
Do not switch the sender or reply-to address until that mailbox, alias, outbound authentication, and replies have been verified.
Domain forwarding alone does not provide authenticated outbound email.
Do not claim a purchase email was sent without a send result from the configured provider.
Stripe receipt history only establishes Stripe receipt delivery, not an independent fulfillment email.
Keep customer email addresses, payment details, and message IDs out of this public repository.

Automatic purchase emails are still not configured.
The authenticated Zoho web session supports manual sending, but is not a server-side integration credential.
Zoho Flow currently opens its initial organization setup; no existing Converty flow was available.
Unattended delivery needs an authorized mail-provider connection or SMTP credential, a deployed Stripe webhook, and persistent duplicate prevention.
Do not extract browser session credentials for use in a worker or repository.
An automatic delivery integration must verify Stripe webhook signatures, filter to this payment link/product, require paid status, handle delayed payment success, and prevent duplicate messages when Stripe retries.
Unrelated account-wide integrations are not proof of Converty delivery.

### Smallest proposed automatic delivery integration

This is a proposed next step, not deployed behavior.
The site is currently a static Vite deployment with no purchase-email function or durable delivery store.
Keep the existing checkout confirmation download available while email automation is added.

- Add a server-side `site/api/stripe-webhook.mjs` function to the existing Vercel project. Read the raw request body and verify `Stripe-Signature` before parsing or acting on the event.
- Handle `checkout.session.completed` and `checkout.session.async_payment_succeeded` only for the configured live account/payment link, requiring `payment_status=paid`. Never send from an unpaid or unrelated session.
- Use the existing Zoho mailbox through authenticated SMTP with TLS. Put credentials in Vercel runtime environment variables, not `VITE_*`, source files, client bundles, or logs. Configure the authorized From alias separately from the SMTP login so moving to Halfwind changes configuration rather than email logic.
- Add a durable delivery table keyed by Checkout Session ID, with an atomic unique claim and states `pending`, `sending`, `sent`, and `needs_review`. Store the provider result after sending. Duplicate webhook deliveries must find the same record rather than send again.
- SMTP and the database do not share a transaction. If the provider may have accepted a message but acknowledgement or persistence fails, mark the attempt for review instead of blindly retrying and risking a duplicate. A process crash while `sending` also requires reconciliation before another attempt.
- Test invalid signatures, unrelated links, unpaid and delayed-paid sessions, concurrent duplicate events, successful delivery, definite rejection, and ambiguous SMTP acceptance before registering the production webhook.

Required runtime settings are `STRIPE_WEBHOOK_SECRET`, `CONVERTY_PAYMENT_LINK_ID`, `SMTP_HOST`, `SMTP_PORT`, `SMTP_USER`, `SMTP_PASSWORD`, `CONVERTY_EMAIL_FROM`, and a server-only durable-store connection.
The initial From value is `admin@evergoodsholdings.com`; the later verified value is `support@halfwind.studio`.
Confirm the account's SMTP host and login in Zoho settings when provisioning the credential.
There is no configured durable store for this site in the repository, so storage and sender authorization must be resolved before this proposal can become a working production integration.
Do not add a paid storage subscription or create a broad mail credential implicitly.

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
