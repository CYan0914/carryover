# RevenueCat setup for Carryover

The app code is ready. It reads an Apple SDK key from the build settings and
reports purchases and first launches through RevenueCat. Until the steps below
are done, the app keeps using StoreKit 2 directly and nothing reaches RC.

## 1. Create the account and app

1. Sign up at <https://app.revenuecat.com/signup> and create a project.
2. **Add app** → platform **iOS** → bundle ID `com.cyan0914.carryover`.
3. Copy the **Apple API key** from that app's settings page. It starts with
   `appl_`. This is the public SDK key, not a secret.

## 2. Connect Apple so sales show up

In the same RC app page, open the **Apple App Store** integration:

1. Upload an App Store Connect API key. One already exists locally:
   - Key ID: `PF9CB25RD4`
   - Issuer ID: `f0d0bff9-293f-4889-a334-88a813a60ec8`
   - Private key file: `C:\Users\Cyan\Desktop\Code&Doc\AuthKey_PF9CB25RD4.p8`
   - RC needs a key with **App Manager** access. If this one is not accepted,
     create a new key with that role in App Store Connect → Users and Access →
     Integrations → Team Keys.
2. Add the product: **Products** → `com.cyan0914.carryover.full`, type
   **Non-consumable**, price from App Store Connect.
3. Create an **Entitlement** with identifier exactly `unlock` (this is the
   value in `Core/Billing.swift`) and attach the product to it.
4. Put that entitlement into the **Offering** RC serves as `current`. If it is
   not in the current offering, the paywall has no package to show.
5. Enable **Server Notifications** with the Sandbox URL RC gives you, and add
   the same URL in App Store Connect → the app → App Information.

## 3. Put the key into CI

Add a repository secret named `REVENUECAT_API_KEY` with the `appl_...` value:

```bash
gh secret set REVENUECAT_API_KEY --repo CYan0914/carryover
```

The archive job passes it into the build. Local builds and the screenshot job
stay key-less on purpose, so demo runs never create fake customers in RC.

## 4. Ship a build

Run the existing `Build Carryover` workflow with `create_ipa: true`. That
produces a TestFlight build with RC live. After a real install and a sandbox
purchase, the RC dashboard should show:

- **Charts → Revenue** for the sale
- **Charts → New Customers** for the first launch
- **Customers** with an anonymous ID, no name or practice data

## Privacy label

The App Store privacy questionnaire must now declare **Purchases** as data
collected by a third-party SDK. Practice records are still never transmitted;
`docs/privacy.html` has been updated to say this.
