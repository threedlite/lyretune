# Google Play Age Signals API - Android Implementation Guide

This document describes how age verification is implemented in LyreTune using Google's Play Age
Signals API.

Reference implementation: `android/app/src/main/java/com/lyretuner/app/AgeVerificationActivity.kt`.
That file is the source of truth; this document describes it.

The logic is a port of ClassicsViewer's `AgeVerificationActivity` (see that project's
`AGE_VERIFICATION_IMPLEMENTATION.md`). The decision table is identical; only the UI differs -
LyreTune's gate is Compose, ClassicsViewer's is view binding. **Keep the two in step.** If one is
changed, change the other.

## Overview

The Play Age Signals API lets an app ask the Google Play Store for the age range associated with
the user's Play account. The app never sees a date of birth or account identity - only a range such
as "18 and over", plus an indicator of how that range was established.

**This is intended as defence-in-depth, not the primary 18+ control.** The primary control is Play
Console's Restrict Minor Access (§10), which blocks minors from searching for, downloading, or
purchasing the app worldwide - before any of this code runs. **See §10: whether that setting is
enabled for LyreTune has not been recorded in this repository and needs verifying in the Play
Console.** The fail-open branches below assume it is.

This activity's job is narrow: **act on what Play asserts, and nothing more.** It does not attempt
to establish an age Play has not reported, because the app has no means of doing so.

| Play says | Action |
|---|---|
| range >= minimum age | access granted |
| range < minimum age | **denied, terminal, app exits** - authoritative, no override |
| `VERIFICATION_REQUIRED` | **denied**, with a route into Play (§3a) |
| `APP_NOT_OWNED`, `SDK_VERSION_OUTDATED` | **denied** - structural; also stops sideloaded builds |
| anything else | access granted - Play gave no information (§4a) |

**The last row is the common case, not an edge case.** Play returns signals only in Brazil and a few
US states, and even inside a covered state only for accounts created after its cutoff - a Texas
account predating 2026-05-28 still gets `NOT_SHARED`. Denying on it locks out essentially the whole
audience while identifying no additional minor.

An earlier revision of `AgeVerificationActivity.kt` denied on both `NOT_SHARED` and a missing age
range, which is exactly that failure: every user outside the rollout regions was blocked on a screen
telling them to "enable age sharing for LyreTune in the Play Store", a setting most of them have no
way to reach. **Do not restore fail-closed-on-everything.**

## 1. Dependency

`android/app/build.gradle`:

```gradle
dependencies {
    implementation 'com.google.android.play:age-signals:0.0.4'
    // age-signals -> play:core-common pulls fragment 1.1.0, which trips the fatal
    // InvalidFragmentVersionForActivityResult lint check. Pin above the 1.3.0 threshold.
    implementation 'androidx.fragment:fragment:1.8.5'
}

android {
    defaultConfig {
        minSdk 23   // required floor: the age-signals AAR declares minSdkVersion 23
    }
    buildFeatures {
        buildConfig true   // BuildConfig.DEBUG is used by the debug bypass (§5)
    }
}
```

The artifact is `com.google.android.play:age-signals` - note there is no `play-` prefix.

## 2. API surface in 0.0.4

Verified against `age-signals-0.0.4.aar`. **`AgeSignalsResult.userStatus()` does not exist in
0.0.4** - it was present in 0.0.3 and was removed. Code written against 0.0.3 will not compile.
Earlier revisions of this document described that 0.0.3 surface (a single `checkAgeSignals()` call
and a `userStatus()` of `VERIFIED`/`SUPERVISED`/...); all of it is obsolete.

```
AgeSignalsManager
  Task<AgeSignalsAccessResult> requestAgeSignalsAccess(AgeSignalsAccessRequest)
  Task<AgeSignalsResult>       checkAgeSignals(AgeSignalsRequest)

AgeSignalsAccessResult
  Integer ageSignalsStatus()

AgeSignalsResult
  Integer ageLower()  Integer ageUpper()  Integer ageRangeSource()
  String  installId()
  Integer significantChangeStatus()   Date significantChangeApprovalDate()

model.AgeSignalsStatus   UNSPECIFIED=0  SHARED=1  NOT_SHARED=2  VERIFICATION_REQUIRED=3
model.AgeRangeSource     UNSPECIFIED=0  TIER_A=1  TIER_B=2  TIER_C=3  TIER_D=4
model.SignificantChangeStatus  UNSPECIFIED=0  APPROVED=1  PENDING=2  DECLINED=3

model.AgeSignalsErrorCode
   NO_ERROR=0                      API_NOT_AVAILABLE=-1
   PLAY_STORE_NOT_FOUND=-2         NETWORK_ERROR=-3
   PLAY_SERVICES_NOT_FOUND=-4      CANNOT_BIND_TO_SERVICE=-5
   PLAY_STORE_VERSION_OUTDATED=-6  PLAY_SERVICES_VERSION_OUTDATED=-7
   CLIENT_TRANSIENT_ERROR=-8       APP_NOT_OWNED=-9
   SDK_VERSION_OUTDATED=-10        INTERNAL_ERROR=-100
```

The AAR also contributes a transparent `AgeSharingConsentWrapperActivity` to the merged manifest.
It is the UI Play uses for the in-app age-sharing prompt; the app does not declare or launch it
directly.

## 3. Two-step flow

0.0.4 replaced the single `checkAgeSignals()` call with a two-step flow.

**Step 1 - `requestAgeSignalsAccess(AgeSignalsAccessRequest)`.** Takes an `Activity`, because it may
surface Play's in-app age-sharing prompt. Returns an `ageSignalsStatus`:

| Status | Handling in this app |
|---|---|
| `SHARED` | proceed to step 2 |
| `NOT_SHARED` | **access granted** - no information (§4a) |
| `VERIFICATION_REQUIRED` | deny, with an **Open Google Play** button (§3a) |
| `UNSPECIFIED` or an unrecognised value | **access granted** - no information (§4a) |

`NOT_SHARED` is ambiguous by construction. Google documents it as covering "user didn't share age
range, parent rejected the request, **or not eligible**" - and "not eligible" is every account
outside the rollout regions. The API exposes no way to tell a refusal from an ineligibility, so the
status carries no evidence about age and cannot support a denial on its own.

### 3a. VERIFICATION_REQUIRED is a denial the user can clear

This status is not a permanent lockout, and an adult in a covered state does have a way through -
but it runs through the Play Store, not through this app:

1. Play returns `VERIFICATION_REQUIRED`, because the user is in a jurisdiction where verification is
   mandatory and they have not completed it.
2. The user verifies **in the Play Store** - by ID, payment card, selfie, or a third-party service,
   depending on region.
3. They return and tap **Retry**. `requestAgeSignalsAccess` now returns `SHARED`, step 2 runs, and
   an adult is admitted normally.

Step 2 is the weak link: Google publishes **no deep link** to the verification flow, and users do
not find the setting on their own. `openPlayStore()` therefore opens this app's store listing -
where Play surfaces the age check for an age-restricted title - and falls back to the Play Store's
launcher entry, then to an explanatory message if Play is absent entirely. Without that button the
screen only instructs the user to go and verify "in the Google Play Store", which in practice is not
discoverable.

This is deliberately the one status that is **not** waved through. Everywhere else Play's silence
means "no information"; here Play is positively telling us the user is somewhere verification is
legally required. That denial is meaningful and is the user's to clear.

**Step 2 - `checkAgeSignals(AgeSignalsRequest)`.** Only called when status is `SHARED`. Returns the
age range.

Retrying is scoped to the step that failed - `handleFailure()` takes the retry action as a lambda -
so a failure in step 2 does not re-trigger Play's consent prompt. Repeated prompting is undesirable.
The **Retry** button is the exception and deliberately restarts from step 1, because the thing the
user has just gone away and fixed is usually the access status.

## 4. Eligibility decision

The single grant condition:

```kotlin
if (ageLower != null && ageLower >= MINIMUM_AGE) { proceedToApp() }
```

`MINIMUM_AGE` is 18 and must stay a Play age-band lower bound (13, 16 or 18); an open-ended range is
expressed as `ageLower = 18, ageUpper = null`.

`ageLower == null` carries no age information, so it grants access rather than denying.

A reported `ageLower` *below* the minimum is a terminal denial: `allowRetry = false`,
`exitApp = true`, and the app closes after 3 seconds. This is the one place the app has positive
evidence about age, and nothing overrides it.

## 4a. No signal means access is granted

Implemented by `proceedWithoutSignal()`. Reached for `NOT_SHARED`, an unrecognised status, a missing
age range, a manager that cannot be constructed, and any transient error that survives bounded
retries.

Access is granted, because **Restrict Minor Access (§10) is expected to have already gated
acquisition at the store**, worldwide, and there is nothing further this app can establish. This is
not a weakening of the age requirement - it is declining to deny an audience the API was never able
to describe.

### Do not add a self-declared date of birth

ClassicsViewer shipped a date-of-birth picker on this path in 0.8.134 and removed it in 0.8.135. Do
not add one here:

- **It adds no assurance.** A minor who lied to Google about their birthday will also lie to a date
  picker. It stops only honest minors - who were already stopped at the store.
- **Both ways of shipping it are unacceptable.** Persisting the outcome means an "already verified"
  flag, which the never-persist rule below forbids. Not persisting it means prompting on every
  single launch.

**NEVER cache or persist age signals.** No stored age range, no "already verified" flag, no age
values in release logs - `handleAgeSignalsResult()` guards its value logging with
`BuildConfig.DEBUG`, and release builds log the decision, not the data. Every launch asks Play
afresh. The app stores nothing age-related at all.

### Offline behaviour

A device with no network produces `NETWORK_ERROR`, which retries a bounded number of times and then
grants access - so a release build does not deny access offline. This matters more for LyreTune than
it did for ClassicsViewer: the tuner is fully functional offline and declares no internet permission
of its own.

`ageRangeSource` is logged in debug builds but not enforced. If a stronger standard of proof is
wanted, the tier can be added to the condition - but note that requiring a high tier will also
exclude adults who have never completed a strong verification with Play.

## 5. Error handling

No error path grants access directly on the first failure. Two codes are terminal denials; the rest
are transient conditions that say nothing about the user's age, so after bounded retries
(3 attempts, 2s apart) they grant access rather than locking the user out.

| Code | Handling |
|---|---|
| `APP_NOT_OWNED` (-9) | **deny, terminal** - app was not installed by Play |
| `SDK_VERSION_OUTDATED` (-10) | **deny, terminal** - prompt to update the app |
| `NETWORK_ERROR` (-3) | bounded auto-retry -> access granted |
| `PLAY_STORE_NOT_FOUND` (-2), `PLAY_SERVICES_NOT_FOUND` (-4) | bounded auto-retry -> access granted |
| `API_NOT_AVAILABLE` (-1), `PLAY_STORE_VERSION_OUTDATED` (-6) | bounded auto-retry -> access granted |
| `PLAY_SERVICES_VERSION_OUTDATED` (-7) | bounded auto-retry -> access granted |
| `CANNOT_BIND_TO_SERVICE` (-5), `CLIENT_TRANSIENT_ERROR` (-8), `INTERNAL_ERROR` (-100) | bounded auto-retry -> access granted |
| unknown code, or a non-`AgeSignalsException` | bounded auto-retry -> access granted |
| manager construction throws | access granted |

`APP_NOT_OWNED` stays terminal on purpose: it is the check that stops a sideloaded release build from
reaching the app, so the fail-open paths cannot be used to bypass Play distribution. The retry
messages name the remediation before access is granted, so a user who can fix the underlying problem
is told how.

`API_NOT_AVAILABLE` means the Play Store on the device is too old. It does **not** indicate an
unsupported region.

### Debug bypass

```kotlin
if (BuildConfig.DEBUG &&
    (errorCode == AgeSignalsErrorCode.APP_NOT_OWNED ||
     errorCode == AgeSignalsErrorCode.CANNOT_BIND_TO_SERVICE)) {
    proceedToApp()
    return
}
```

Sideloaded debug builds are not owned by Play and can never obtain signals, so the gate is
untestable locally without this. `BuildConfig.DEBUG` is a compile-time `false` in release, and with
`minifyEnabled true` R8 removes the branch entirely. **The deny behaviour is therefore only
observable in a release build installed through Play** (for example via an internal testing track).
A debug build will always open.

## 6. Manifest

`AgeVerificationActivity` is the launcher activity, so the gate runs before anything else:

```xml
<activity
    android:name=".AgeVerificationActivity"
    android:exported="true"
    android:theme="@style/Theme.LyreTune">
    <intent-filter>
        <action android:name="android.intent.action.MAIN" />
        <category android:name="android.intent.category.LAUNCHER" />
    </intent-filter>
</activity>

<activity android:name=".MainActivity" android:exported="false" ... />
```

`MainActivity` and every other activity are non-exported, so no other app can start them directly.
`onBackPressed()` is overridden to a no-op, so back cannot dismiss the gate.

No `<queries>` entry is needed for the Play Store intents in `openPlayStore()`: an app can always
see the package that installed it, and `com.android.vending` is exempt from package-visibility
filtering for that reason.

## 7. UI notes (LyreTune-specific)

The screen is Compose, not the XML layout ClassicsViewer uses. Two details are load-bearing:

- **State lives on the activity**, as `mutableStateOf` properties (`message`, `showProgress`,
  `showRetry`, `showPlayStore`), not in `remember` inside the composable. The Play API is
  callback-based, and a `LaunchedEffect(retryAttempts)` arrangement cannot express "retry only the
  step that failed" (§3) - it re-runs the whole flow, re-triggering Play's consent prompt.
- **`BoxWithConstraints` + `heightIn(min = maxHeight)` inside `verticalScroll`.** The denial messages
  run to several paragraphs and overflow a small screen. A plain
  `fillMaxSize().verticalScroll(...)` on a `Column` collapses it to wrap-content, which silently
  breaks `Arrangement.Center` and pins the content to the top.

The app is edge-to-edge under `targetSdk 36`, so the content is padded by
`WindowInsets.systemBars.asPaddingValues()`, matching `MainActivity`.

## 8. Notes and limitations

- **No permissions required.** The API works over an IPC binding to the Play Store; the app declares
  no internet permission. The Play Store performs the network work.
- **Play installs only.** Sideloaded builds return `APP_NOT_OWNED` and are denied in release.
- **Repackaging defeats the gate.** Anyone who rebuilds the APK can remove the check. Play Integrity
  is the countermeasure and is not currently integrated.
- **`TIER_A` age ranges are self-declared** on the Google account, so the gate does not stop a minor
  who entered a false birthday. Enforcing a higher tier is possible but excludes many adults.
- **The runtime gate cannot restrict a minor Play does not identify.** Outside the rollout regions
  the app receives no age information at all, so its only real protection there is the store-level
  Restrict Minor Access (§10).
- **`significantChangeStatus()` / `significantChangeApprovalDate()` are not handled.** They relate to
  parent-approved changes for supervised accounts.
- **No test seam.** `AgeVerificationActivity` calls `AgeSignalsManagerFactory.create()` directly, so
  the `FakeAgeSignalsManager` in `com.google.android.play.agesignals.testing` cannot be injected.
  Exhaustive branch testing would require introducing one. The fake supports
  `setNextAgeSignalsAccessResult`, `setNextRequestAgeSignalsAccessException`,
  `setNextAgeSignalsResult` and `setNextAgeSignalsException`, and both result builders are public.
- **Regional and jurisdictional behaviour has not been verified by this project.** Claims about what
  Play returns in a given country, and about what any law or Play policy requires, should be checked
  against Google's primary documentation.

## 9. Regional availability - why the fail-open branches exist

Carried over from ClassicsViewer's audit, checked 2026-07-26. **Treat this table as indicative, not
authoritative** - coverage is expanding as US state laws take effect, and Google's own availability
page lags the rollout.

| Region | Law | Status |
|---|---|---|
| Brazil | Digital ECA | signals returned since 2026-03-17 |
| Texas, USA | SB2420 | signals returned for accounts **created after 2026-05-28** |
| Utah, USA | App Store Accountability Act | in effect since 2026-05-07 |
| Louisiana, USA | HB570 | in effect since 2026-07-01 |
| Alabama, California, USA | - | scheduled January 2027 |
| Everywhere else | - | no signals - `requestAgeSignalsAccess` returns `NOT_SHARED` |

Google's own availability page (last updated 2026-07-21) still names only Brazil and Texas; the Utah
and Louisiana statutory dates are not in dispute, but whether Play returns signals there is not
confirmed.

**None of this affects the code.** `AgeVerificationActivity` hardcodes no region list and never asks
where the user is - it reacts only to the status Play returns. A user in a newly covered state simply
starts getting `SHARED` or `VERIFICATION_REQUIRED` instead of `NOT_SHARED`, and is routed correctly
with no code change. This table exists to explain *why* the fail-open branches are needed, not to
drive any behaviour.

The load-bearing fact is only this: the overwhelming majority of the world is not covered by any of
these laws and gets `NOT_SHARED`.

Google states plainly that **use of the API is not mandatory**: *"Google Play doesn't mandate the use
of these features."* Its sanctioned purpose is narrow: *"You may only use information from the Play
Age Signals API to provide age-appropriate content and experiences in compliance with laws."* Nothing
in Google's policy requires denying access to users who return `NOT_SHARED`.

### SDK version

`0.0.4` is current. The docs path `/google/play/age-signals/v3/` is **not** a newer version - it
documents `0.0.3`, which Google marks as no longer supported. The Maven group index
(`dl.google.com/dl/android/maven2/com/google/android/play/group-index.xml`) lists
`0.0.1-beta01, 0.0.1-beta02, 0.0.1, 0.0.2, 0.0.3, 0.0.4`. No upgrade widens regional coverage.

## 10. Restrict Minor Access (Play Console, store-level)

**Status for LyreTune: NOT VERIFIED - check this in the Play Console.** This repository has no record
of the setting, and it cannot be determined from the source. The fail-open branches in §4a assume the
store-level restriction is doing the worldwide gating; if LyreTune's listing is not restricted to 18+
then the runtime gate is, in practice, the only 18+ control, and outside the rollout regions it
grants access to everyone. Two coherent positions follow, and this is a product decision:

1. **Keep the 18+ posture** - enable Restrict Minor Access as described below, and the gate becomes
   defence-in-depth exactly as in ClassicsViewer.
2. **Decide LyreTune is not an 18+ app** - a tuner has no age-restricted content, in which case the
   gate can be removed outright rather than left as a screen that never denies anyone.

What it does: *"users determined to be under 18 will not be able to search for, download or purchase
the app."* Age is taken from *"the age provided in their Google Account or when our systems indicate
that a user may be under 18."* Unlike everything in §9, it keys off Google Account age rather than
the per-jurisdiction signal programme, so it applies worldwide.

**Location.** "Target audience and content" is **not** a left-menu item - it is a section on the
**App content** page (*Policy > App content*, in some navigations *Monitor and improve > Policy and
programs > App content*), with a Start/Manage button.

**The checkbox is conditionally rendered - this is why it looks absent:**

1. On **App content**, find the **Target audience and content** row -> **Start** / **Manage**.
2. On the **Target age** step, tick **18 and over** and untick every other age group. It must be the
   only one selected.
3. The Restrict Minor Access checkbox appears **on that same screen** once, and only once, that is
   true. With any other age group still ticked it does not render.

Prerequisite: the Target audience section is not reachable until the ads declaration, app access
instructions, and privacy policy are all complete.

It is **independent of the IARC content rating**; the rating questionnaire and the target-audience
declaration are separate controls.

### Limits

- **Not retroactive.** *"Users who have already installed the app will continue to be able to use it,
  but will not be able to renew existing subscriptions or make new purchases."*
- **Self-declared age.** Google Account age is user-entered on many accounts - the same class of
  assurance as `TIER_A`, not verified ID.
- **Narrows the audience declaration** to 18+ only, which affects discoverability. For a tuner app
  this is a real cost with no content-policy benefit - see the decision in §10 above.
- **Mandatory only for real-money gambling and dating/matchmaking apps.** For everything else it is
  opt-in.

### Relationship to the in-app gate

| Layer | Mechanism | Covers |
|---|---|---|
| Acquisition | Restrict Minor Access | search, download, purchase - worldwide |
| Runtime | `AgeVerificationActivity` | existing installs, verified signals in covered jurisdictions |

Enabling the Console setting does not make the gate redundant (it is not retroactive, and it does not
run at launch), and the gate does not depend on the Console setting being enabled - but the gate's
fail-open branches are only defensible while the store-level restriction exists.

Sources: Play Console Help 9867159 (Manage target audience and app content settings) and 16302250
(Age-Restricted Content and Functionality). Checked 2026-07-26.
