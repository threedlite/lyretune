package com.lyretuner.app

import android.content.ActivityNotFoundException
import android.content.Intent
import android.net.Uri
import android.os.Bundle
import android.util.Log
import androidx.activity.ComponentActivity
import androidx.activity.compose.setContent
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.BoxWithConstraints
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.asPaddingValues
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.systemBars
import androidx.compose.foundation.layout.WindowInsets
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.verticalScroll
import androidx.compose.material3.Button
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Surface
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.lifecycle.lifecycleScope
import com.lyretuner.app.ui.theme.LyreTuneTheme
import com.google.android.play.agesignals.AgeSignalsAccessRequest
import com.google.android.play.agesignals.AgeSignalsException
import com.google.android.play.agesignals.AgeSignalsManager
import com.google.android.play.agesignals.AgeSignalsManagerFactory
import com.google.android.play.agesignals.AgeSignalsRequest
import com.google.android.play.agesignals.AgeSignalsResult
import com.google.android.play.agesignals.model.AgeSignalsErrorCode
import com.google.android.play.agesignals.model.AgeSignalsStatus
import kotlinx.coroutines.delay
import kotlinx.coroutines.launch

/**
 * Age gate backed by the Play Age Signals API (com.google.android.play:age-signals:0.0.4).
 *
 * Ported from ClassicsViewer's `AgeVerificationActivity`, which is the reference implementation;
 * keep the two in step. The decision table below is theirs verbatim - only the UI is different
 * (Compose here, view binding there).
 *
 * **This is not the app's primary 18+ control.** That is Play Console's Restrict Minor Access,
 * which stops minors searching for, downloading, or purchasing the app worldwide - before any of
 * this code runs. Everyone reaching this screen already passed that.
 *
 * This activity's job is therefore narrow: act on what Play *asserts*, and nothing more. It does
 * not attempt to establish an age Play has not reported, because the app has no means of doing so.
 *
 *  - Play reports a range >= [MINIMUM_AGE]  -> access granted.
 *  - Play reports a range <  [MINIMUM_AGE]  -> denied, authoritatively, terminal. No override.
 *  - VERIFICATION_REQUIRED -> denied, with a route into Play. Play has identified the user as
 *    being in a jurisdiction where verification is legally mandatory; that denial is meaningful
 *    and is the user's to clear.
 *  - APP_NOT_OWNED / SDK_VERSION_OUTDATED -> denied. Structural problems with the install; this
 *    is also what stops a sideloaded release build.
 *  - Anything else (NOT_SHARED, no age range, unrecognised status, unrecoverable errors) means
 *    Play produced no information. Access is granted, because the store-level gate already
 *    applied and nothing here can add to it.
 *
 * That last case is the common one, not an edge case: Play returns signals only in Brazil and a
 * few US states, and even inside a covered state only for accounts created after the cutoff.
 * Denying on it - as the previous revision of this file did for NOT_SHARED and for a missing age
 * range - locks out essentially the entire audience while identifying no additional minor.
 * **Do not "restore" fail-closed-on-everything.**
 *
 * [BuildConfig.DEBUG] additionally bypasses the gate for sideloaded builds, which are not owned by
 * Play and can never obtain signals. Release builds have no bypass, so the deny paths are only
 * observable in a release build installed through Play.
 *
 * Nothing is cached or persisted. The age range and its source are read, used to make one decision,
 * and discarded; every launch asks Play afresh. There is deliberately no "already verified" flag
 * and no stored age of any kind. Do not add one.
 */
class AgeVerificationActivity : ComponentActivity() {

    private var ageSignalsManager: AgeSignalsManager? = null
    private var retryAttempts = 0

    // Screen state. Held on the activity rather than in the composable so the callback-based
    // Play flow can drive it without re-entering composition, and so a retry can re-run only the
    // step that failed.
    private var message by mutableStateOf(checkingMessage())
    private var showProgress by mutableStateOf(true)
    private var showRetry by mutableStateOf(false)
    private var showPlayStore by mutableStateOf(false)

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)

        setContent {
            LyreTuneTheme {
                AgeVerificationScreen()
            }
        }

        startVerification()
    }

    @Composable
    private fun AgeVerificationScreen() {
        Surface(
            modifier = Modifier.fillMaxSize(),
            color = MaterialTheme.colorScheme.background
        ) {
            // The denial messages run to several paragraphs and can be taller than a small screen,
            // so the content scrolls. heightIn(min = viewport) keeps it vertically centred while it
            // still fits - a plain verticalScroll would collapse the Column to wrap-content and
            // pin everything to the top.
            BoxWithConstraints(
                modifier = Modifier
                    .fillMaxSize()
                    .padding(WindowInsets.systemBars.asPaddingValues())
            ) {
                val viewportHeight = maxHeight
                Column(
                    modifier = Modifier
                        .fillMaxWidth()
                        .verticalScroll(rememberScrollState())
                        .heightIn(min = viewportHeight)
                        .padding(32.dp),
                    horizontalAlignment = Alignment.CenterHorizontally,
                    verticalArrangement = Arrangement.Center
                ) {
                    Text(
                        text = "Age Verification",
                        style = MaterialTheme.typography.headlineMedium,
                        color = MaterialTheme.colorScheme.onBackground
                    )

                    Spacer(modifier = Modifier.height(16.dp))

                    Text(
                        text = message,
                        style = MaterialTheme.typography.bodyLarge,
                        textAlign = TextAlign.Center,
                        color = MaterialTheme.colorScheme.onBackground
                    )

                    if (showProgress) {
                        Spacer(modifier = Modifier.height(32.dp))
                        CircularProgressIndicator(
                            color = MaterialTheme.colorScheme.primary
                        )
                    }

                    // Shown for VERIFICATION_REQUIRED, which is the one denial a user can act on
                    // themselves. Without it the screen only tells them to go and verify somewhere
                    // in the Play Store, which is not discoverable.
                    if (showPlayStore) {
                        Spacer(modifier = Modifier.height(16.dp))
                        Button(onClick = { openPlayStore() }) {
                            Text("Open Google Play")
                        }
                    }

                    if (showRetry) {
                        Spacer(modifier = Modifier.height(16.dp))
                        Button(onClick = {
                            retryAttempts = 0
                            startVerification()
                        }) {
                            Text("Retry")
                        }
                    }
                }
            }
        }
    }

    /**
     * Creates the manager on first use, then runs the check. The Retry button is always wired, so
     * it stays functional even when manager creation is what failed.
     */
    private fun startVerification() {
        if (ageSignalsManager == null) {
            ageSignalsManager = try {
                AgeSignalsManagerFactory.create(applicationContext)
            } catch (e: Exception) {
                Log.e(TAG, "Failed to create AgeSignalsManager", e)
                // Play can never answer on this device. An absence of information, not evidence
                // the user is under age.
                proceedWithoutSignal("manager unavailable")
                return
            }
        }

        requestAccess()
    }

    // Step 1 of the 0.0.4 flow. Surfaces Play's in-app age-sharing prompt when applicable and
    // reports whether signals are available to this app.
    private fun requestAccess() {
        val manager = ageSignalsManager ?: run {
            proceedWithoutSignal("manager unavailable")
            return
        }

        showChecking()

        Log.d(TAG, "Requesting age signals access (attempt ${retryAttempts + 1}/$MAX_RETRY_ATTEMPTS)")

        val accessRequest = AgeSignalsAccessRequest.builder()
            .setActivity(this)
            .build()

        manager.requestAgeSignalsAccess(accessRequest)
            .addOnSuccessListener { accessResult ->
                val status = accessResult.ageSignalsStatus() ?: AgeSignalsStatus.UNSPECIFIED
                Log.d(TAG, "Age signals access status: $status")

                when (status) {
                    AgeSignalsStatus.SHARED -> fetchAgeSignals()

                    // Ambiguous by design. Google documents this as covering "user didn't share
                    // age range, parent rejected the request, or not eligible" - and "not
                    // eligible" is every account outside the rollout, including accounts inside a
                    // covered state that predate its cutoff. It carries no evidence about age.
                    AgeSignalsStatus.NOT_SHARED -> proceedWithoutSignal("NOT_SHARED")

                    // The one status that is genuinely informative without being an age range:
                    // Play is telling us this user is somewhere verification is mandatory and has
                    // not completed it. Denial here is meaningful, and the user can clear it.
                    AgeSignalsStatus.VERIFICATION_REQUIRED -> denyFinal(
                        "This app is restricted to users $MINIMUM_AGE years of age and older.\n\n" +
                            "Google Play requires you to verify your age before it can confirm this.\n\n" +
                            "Tap Open Google Play to verify (you may be asked for ID, a card, or a " +
                            "selfie), then return here and tap Retry.",
                        allowRetry = true,
                        showPlayStore = true
                    )

                    // UNSPECIFIED or a value added by a future SDK: no usable signal either way.
                    else -> proceedWithoutSignal("status $status")
                }
            }
            .addOnFailureListener { exception ->
                handleFailure(exception) { requestAccess() }
            }
    }

    // Step 2. Only reached when access status is SHARED.
    private fun fetchAgeSignals() {
        val manager = ageSignalsManager ?: run {
            proceedWithoutSignal("manager unavailable")
            return
        }

        manager.checkAgeSignals(AgeSignalsRequest.builder().build())
            .addOnSuccessListener { result ->
                handleAgeSignalsResult(result)
            }
            .addOnFailureListener { exception ->
                // Access already succeeded; retry only this step so Play's consent prompt is
                // not re-triggered repeatedly.
                handleFailure(exception) { fetchAgeSignals() }
            }
    }

    private fun handleAgeSignalsResult(result: AgeSignalsResult) {
        val ageLower: Int? = result.ageLower()
        val ageUpper: Int? = result.ageUpper()
        val ageRangeSource: Int? = result.ageRangeSource()

        // The values returned by Play are never persisted and never leave this method. They are
        // written to the log only in debug builds; release builds log the decision, not the data.
        if (BuildConfig.DEBUG) {
            Log.d(TAG, "Age signals result - ageRangeSource: $ageRangeSource, ageLower: $ageLower, ageUpper: $ageUpper")
        }

        // MINIMUM_AGE must be a Play age-band lower bound (13, 16 or 18); an open-ended range is
        // reported as ageLower = 18 with ageUpper = null.
        if (ageLower != null && ageLower >= MINIMUM_AGE) {
            Log.d(TAG, "Age requirement met, proceeding to app")
            proceedToApp()
            return
        }

        if (ageLower == null) {
            // Access was granted but no range came back. Again an absence of information.
            Log.w(TAG, "No age range returned")
            proceedWithoutSignal("no age range")
            return
        }

        // The one place the app has positive evidence the user is under age. Terminal.
        Log.w(TAG, "Age requirement not met - denying access")
        denyFinal(
            "This app is restricted to users $MINIMUM_AGE years of age and older.\n\n" +
                "You do not meet the age requirement to use this application.",
            allowRetry = false,
            // A confirmed under-age result closes the app rather than leaving the user on a screen
            // they can re-trigger checks from.
            exitApp = true
        )
    }

    /**
     * Maps an API failure to an outcome. [retryAction] re-runs only the step that failed.
     *
     * Only two error codes are terminal denials. The rest describe a broken or unavailable Play
     * connection, which says nothing about the user's age, so after bounded retries they defer to
     * the store-level gate rather than locking the user out.
     */
    private fun handleFailure(exception: Exception, retryAction: () -> Unit) {
        val errorCode = (exception as? AgeSignalsException)?.errorCode
        Log.e(TAG, "Age signals call failed (errorCode: $errorCode)", exception)

        // Debug builds are sideloaded and are not owned by Play, so signals are unobtainable and
        // the gate is untestable locally. Release builds never take this branch: BuildConfig.DEBUG
        // is a compile-time false, so R8 removes it entirely.
        if (BuildConfig.DEBUG &&
            (errorCode == AgeSignalsErrorCode.APP_NOT_OWNED ||
                errorCode == AgeSignalsErrorCode.CANNOT_BIND_TO_SERVICE)
        ) {
            Log.w(TAG, "DEBUG build: bypassing age gate for errorCode $errorCode")
            proceedToApp()
            return
        }

        when (errorCode) {
            // Terminal: the app must be installed by Play for signals to be available. This is
            // also what prevents a sideloaded release build from reaching the app.
            AgeSignalsErrorCode.APP_NOT_OWNED -> denyFinal(
                "Age verification is required to use this app.\n\n" +
                    "This copy was not installed by Google Play. Please install the app from Google Play.",
                allowRetry = false
            )

            // Terminal: this app ships an SDK version Play no longer supports.
            AgeSignalsErrorCode.SDK_VERSION_OUTDATED -> denyFinal(
                "Age verification is required to use this app.\n\n" +
                    "This version of the app is out of date. Please update it from Google Play.",
                allowRetry = false
            )

            AgeSignalsErrorCode.NETWORK_ERROR -> retryThenProceed(
                "Checking age requirements requires an internet connection.",
                retryAction
            )

            AgeSignalsErrorCode.PLAY_STORE_NOT_FOUND,
            AgeSignalsErrorCode.PLAY_SERVICES_NOT_FOUND,
            AgeSignalsErrorCode.API_NOT_AVAILABLE,
            AgeSignalsErrorCode.PLAY_STORE_VERSION_OUTDATED,
            AgeSignalsErrorCode.PLAY_SERVICES_VERSION_OUTDATED,
            AgeSignalsErrorCode.CANNOT_BIND_TO_SERVICE,
            AgeSignalsErrorCode.CLIENT_TRANSIENT_ERROR,
            AgeSignalsErrorCode.INTERNAL_ERROR -> retryThenProceed(
                "Age requirements could not be checked with Google Play.",
                retryAction
            )

            // Unknown error code, or an exception that is not an AgeSignalsException.
            else -> retryThenProceed(
                "Age requirements could not be checked with Google Play.",
                retryAction
            )
        }
    }

    /** Auto-retries a transient failure a bounded number of times, then defers to the store gate. */
    private fun retryThenProceed(message: String, retryAction: () -> Unit) {
        if (retryAttempts < MAX_RETRY_ATTEMPTS) {
            retryAttempts++
            showProgress = true
            showRetry = false
            showPlayStore = false
            this.message = "$message\n\nRetrying... (Attempt $retryAttempts/$MAX_RETRY_ATTEMPTS)"

            lifecycleScope.launch {
                delay(RETRY_DELAY_MS)
                retryAction()
            }
        } else {
            proceedWithoutSignal("retries exhausted")
        }
    }

    /**
     * Play produced no usable information about this user.
     *
     * Access is granted, because Restrict Minor Access has already gated acquisition at the store
     * and there is nothing further this app can establish. This is not a weakening of the age
     * requirement - it is declining to deny an audience the API was never able to describe.
     */
    private fun proceedWithoutSignal(reason: String) {
        Log.d(TAG, "No usable Play age signal ($reason) - deferring to store-level restriction")
        proceedToApp()
    }

    /**
     * Sends the user to Google Play so they can resolve a VERIFICATION_REQUIRED status.
     *
     * Google documents no deep link to the age verification flow itself, so this opens this app's
     * store listing - the place Play surfaces the age check for an age-restricted title - and falls
     * back to the Play Store's own launcher entry if that cannot be resolved.
     */
    private fun openPlayStore() {
        val listing = Intent(Intent.ACTION_VIEW, Uri.parse("market://details?id=$packageName"))
        try {
            startActivity(listing)
            return
        } catch (e: ActivityNotFoundException) {
            Log.w(TAG, "Could not open Play Store listing", e)
        }

        val playStore = packageManager.getLaunchIntentForPackage(PLAY_STORE_PACKAGE)
        if (playStore != null) {
            startActivity(playStore)
        } else {
            Log.w(TAG, "Play Store is not installed; cannot direct user to verification")
            message = "The Google Play Store is not available on this device, so your age cannot " +
                "be verified. Install or enable the Play Store, then tap Retry."
            showPlayStore = false
        }
    }

    private fun showChecking() {
        showProgress = true
        showRetry = false
        showPlayStore = false
        message = checkingMessage()
    }

    /**
     * Terminal denial. There is no path to MainActivity from here.
     *
     * @param allowRetry shows a Retry button that re-runs the full check, so the user can act on
     *   the remediation described in [message].
     * @param exitApp closes the app after [EXIT_DELAY_MS] instead of leaving the user on this
     *   screen. Used for a confirmed under-age result.
     * @param showPlayStore offers a route into Google Play, for denials the user can clear there.
     */
    private fun denyFinal(
        message: String,
        allowRetry: Boolean,
        exitApp: Boolean = false,
        showPlayStore: Boolean = false,
    ) {
        showProgress = false
        this.message = message
        showRetry = allowRetry
        this.showPlayStore = showPlayStore

        if (exitApp) {
            lifecycleScope.launch {
                delay(EXIT_DELAY_MS) // let the user read the message first
                finishAffinity()
            }
        }
    }

    private fun proceedToApp() {
        startActivity(Intent(this, MainActivity::class.java))
        finish() // Don't allow back navigation to verification screen
    }

    @Deprecated("Use onBackPressedDispatcher")
    override fun onBackPressed() {
        // Prevent the back button from dismissing the gate on OS versions that still route here.
        // The activity is the launcher and never starts MainActivity unless verification passed,
        // so finishing early cannot expose app content.
    }

    private fun checkingMessage() =
        "Checking age requirements...\nThis app is only available for users $MINIMUM_AGE and older."

    companion object {
        private const val TAG = "AgeVerification"
        private const val PLAY_STORE_PACKAGE = "com.android.vending"
        private const val MAX_RETRY_ATTEMPTS = 3
        private const val RETRY_DELAY_MS = 2000L
        private const val EXIT_DELAY_MS = 3000L

        /** Must match a Play age-band lower bound: 13, 16, or 18 by default. */
        private const val MINIMUM_AGE = 18
    }
}
