# Carryover

Home practice for speech therapy, with the results going back to the therapist.

**App Store display name:** Carryover: Speech Practice
**Bundle id:** `com.cyan0914.carryover`
**Price:** $3.99 one-time. No subscription.

---

## What it is

A speech-language pathologist assigns words between sessions. The family
practices them at home. Then nothing comes back to the therapist except "we
practiced a few times".

This app does three things:

1. **Practices the therapist's actual words.** The family types or picks the
   words from the handout. Not a generic course library.
2. **Records one tap per production.** Got it / Close / Not yet. A parent
   standing next to the child is the judge. No microphone, no scoring
   algorithm.
3. **Produces one page for the next appointment.** Sessions, accuracy per
   word, practice frequency, and the words still below 50%. A PDF the parent
   hands over in the waiting room.

## What it deliberately is not

- **Not a diagnostic tool.** No severity, no percentile, no recommendation. It
  records what a parent observed. This is also the App Store risk boundary: a
  claims-based clinical product needs clinical evidence, a record-keeping tool
  does not.
- **Not a course.** There is no content library to keep growing, no curriculum,
  no lesson progression. The therapist owns the plan.
- **Not a subscription.** See below.

## Why this exists (the evidence)

Pulled from the App Store in November 2026, US storefront, via the iTunes
Search and RSS review APIs.

| Finding | Number |
|---|---|
| Families pay once, at high prices | Proloquo2Go $249.99 · Language Therapy 4-in-1 $89.99 · Apraxia Therapy $29.99 |
| The supply side is stale | In `speech therapy at home` top 10: Word Vault Essential last updated **2020-05**, SpeechBox 2022-12, Apraxia Therapy 2024-08 |
| The leader's one-stars are about billing, not product | Speech Blubs: 85 recent 1-2★ reviews, **59 of them** about subscriptions/charges. Only 10 about crashes |
| The core workflow is broken | Articulation Station: "crashes literally every time I save any data to it. I can't have my data collection means be so unreliable" |
| An incumbent abandoned its own users | Articulation Station moved a $60+ one-time app to subscription; user review: "It should be illegal to charge over $60 for an app years ago and then discontinue that app" |
| Someone is explicitly asking for this | "I hope there are devs who can create similar apps that are affordable for parents and SLPs" |
| Clinical credibility is a real gate | An SLP review on a competitor: "DO NOT DOWNLOAD" because it used non-speech oral motor exercises. → never touch technique, only record execution |

The conclusion that drove the product: the App Store winner in this category
wins on ad spend and dark-pattern billing, not on the product. A solo
developer cannot outspend it, but can beat it on honesty and on the one
workflow it broke.

## Architecture

- SwiftUI, iOS 17+, one target plus a unit test target.
- **No backend.** All data is a single JSON file in Application Support. This
  is the privacy claim, not a shortcut.
- **No accounts.** Nothing to sign up for, nothing to leak.
- **No microphone.** `AVSpeechSynthesizer` for playback only. No speech
  recognition, so no `NSMicrophoneUsageDescription` and no
  `NSSpeechRecognitionUsageDescription` in `Info.plist`. That absence is
  load-bearing.
- StoreKit 2, one non-consumable.

```
CarryoverApp.swift        app entry, environment wiring
Core/
  AppStore.swift          observable state, JSON persistence, derived stats
  Billing.swift           product id and free-session limit
  DesignSystem.swift      palette, cards, button styles
Models/
  Models.swift            Attempt / Session / TargetWord, ReportStats
  WordLibrary.swift       built-in articulation word lists by sound+position
Services/
  WordSpeaker.swift       TTS playback
  ReportBuilder.swift     the one-page PDF
  PurchaseManager.swift   StoreKit 2
Views/
  RootView.swift          first run, tab shell
  HomeView.swift          today's set, streak
  PracticeView.swift      the loop
  SoundPickerView.swift   pick a sound, confirm words
  TargetsView.swift       word management, custom words
  ReportView.swift        stats, PDF share
  SettingsView.swift      export, delete, disclaimers
  PaywallView.swift       one-time unlock
Tests/
  ReportStatsTests.swift  window filtering, accuracy, struggled/mastered
```

Run `xcodegen generate` to produce `Carryover.xcodeproj`.

## Roadmap, in order

1. ~~**Compile and run on a simulator.**~~ Done: CI run 41980201951 builds clean
   and runs 11 unit tests, 0 failures.
2. **Find one SLP to read the PDF layout.** This is the single cheapest
   credibility buy, and the report is the product. If a therapist says "I
   would not read this", the layout changes before anything else is built.
3. ~~**App Store Connect:** register the bundle id, create the non-consumable
   product~~ Done: app record `6831020269`, IAP `6831020655` at $3.99, en-US
   localization set. Still missing: the archive job and a distribution
   certificate/profile for TestFlight.
4. **ASO.** Display name "Carryover: Speech Practice", subtitle targets parent
   language (`speech,delay,toddler,apraxia,articulation,late,talker,practice,therapy,home,carryover,slp`).
5. **Distribution.** The growth loop is the therapist, not the App Store:
   every PDF footer is the ad. Add a line to the PDF: "Made with Carryover"
   plus the App Store short link, once the app exists.

## Open questions

- Does the parent or the SLP pay? Currently the parent. An SLP multi-client
  tier is the obvious v2, but it needs the report to be good first.
- Child ages out of the app in 2-4 years. Churn is structural. That is the
  argument for the one-time price: a subscription fights the natural lifetime.
