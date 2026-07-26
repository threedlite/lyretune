package com.lyretuner.app

import android.content.Intent
import android.os.Bundle
import android.util.Log
import androidx.activity.ComponentActivity
import androidx.activity.compose.setContent
import androidx.compose.foundation.layout.*
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
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

class AgeVerificationActivity : ComponentActivity() {

    private var ageSignalsManager: AgeSignalsManager? = null

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)

        try {
            ageSignalsManager = AgeSignalsManagerFactory.create(applicationContext)
        } catch (e: Exception) {
            Log.e(TAG, "Failed to create AgeSignalsManager", e)
        }

        setContent {
            LyreTuneTheme {
                AgeVerificationScreen()
            }
        }
    }

    @Composable
    private fun AgeVerificationScreen() {
        var message by remember { mutableStateOf("Verifying age requirements...") }
        var isLoading by remember { mutableStateOf(true) }
        var showRetry by remember { mutableStateOf(false) }
        var showPlayStore by remember { mutableStateOf(false) }
        var retryAttempts by remember { mutableIntStateOf(0) }
        var autoRetryDelayMs by remember { mutableStateOf<Long?>(null) }

        LaunchedEffect(retryAttempts) {
            isLoading = true
            showRetry = false
            showPlayStore = false
            message = "Verifying age requirements..."
            requestAccessThenCheck(
                attempt = retryAttempts,
                onMessage = { message = it },
                onShowRetry = { showRetry = it },
                onShowPlayStore = { showPlayStore = it },
                onLoading = { isLoading = it },
                onScheduleRetry = { autoRetryDelayMs = it }
            )
        }

        // Auto-retry after a transient failure, without blocking the main thread.
        LaunchedEffect(autoRetryDelayMs) {
            val delayMs = autoRetryDelayMs ?: return@LaunchedEffect
            delay(delayMs)
            autoRetryDelayMs = null
            retryAttempts++
        }

        Surface(
            modifier = Modifier.fillMaxSize(),
            color = MaterialTheme.colorScheme.background
        ) {
            Column(
                modifier = Modifier
                    .fillMaxSize()
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

                Spacer(modifier = Modifier.height(32.dp))

                if (isLoading) {
                    CircularProgressIndicator(
                        color = MaterialTheme.colorScheme.primary
                    )
                }

                if (showPlayStore) {
                    Button(onClick = { openPlayStore() }) {
                        Text("Open Play Store")
                    }
                    Spacer(modifier = Modifier.height(12.dp))
                }

                if (showRetry || showPlayStore) {
                    Button(onClick = { retryAttempts++ }) {
                        Text("Retry")
                    }
                }
            }
        }
    }

    /**
     * Step 1 of the Play Age Signals flow: ask for access. Age signals are only
     * readable once Play reports SHARED, so checkAgeSignals() must not be called
     * before this succeeds.
     */
    private fun requestAccessThenCheck(
        attempt: Int,
        onMessage: (String) -> Unit,
        onShowRetry: (Boolean) -> Unit,
        onShowPlayStore: (Boolean) -> Unit,
        onLoading: (Boolean) -> Unit,
        onScheduleRetry: (Long) -> Unit
    ) {
        val manager = ageSignalsManager
        if (manager == null) {
            Log.w(TAG, "AgeSignalsManager not available - allowing access")
            proceedToApp()
            return
        }

        val accessRequest = AgeSignalsAccessRequest.builder()
            .setActivity(this)
            .build()

        manager.requestAgeSignalsAccess(accessRequest)
            .addOnSuccessListener { accessResult ->
                when (val status = accessResult.ageSignalsStatus()) {
                    AgeSignalsStatus.SHARED -> {
                        Log.d(TAG, "Age signals shared - reading age range")
                        checkAgeSignals(
                            manager, attempt, onMessage, onShowRetry,
                            onShowPlayStore, onLoading, onScheduleRetry
                        )
                    }
                    AgeSignalsStatus.VERIFICATION_REQUIRED -> {
                        // Mandatory-verification jurisdiction with an unknown age.
                        // Play shows no in-app prompt here; the user must resolve
                        // this in the Play Store app.
                        Log.w(TAG, "Age verification required in Play Store")
                        onLoading(false)
                        onShowPlayStore(true)
                        onMessage(
                            "Your age needs to be verified before using this app.\n\n" +
                                "Open the Play Store to verify, then tap Retry."
                        )
                    }
                    AgeSignalsStatus.NOT_SHARED -> {
                        // Declined, or sharing unavailable here. Age is unknown, so
                        // it cannot be ruled out that the user is under MIN_AGE.
                        Log.w(TAG, "Age signals not shared - blocking access")
                        blockUnverified(
                            "This app requires your age range to be shared with it.\n\n" +
                                "Enable age sharing for LyreTune in the Play Store, " +
                                "then tap Retry.",
                            onMessage, onShowRetry, onShowPlayStore, onLoading,
                            showPlayStore = true
                        )
                    }
                    else -> {
                        Log.w(TAG, "Unexpected age signals status: $status - blocking access")
                        blockUnverified(
                            "Your age could not be verified.\n\nTap Retry to try again.",
                            onMessage, onShowRetry, onShowPlayStore, onLoading,
                            showPlayStore = false
                        )
                    }
                }
            }
            .addOnFailureListener { exception ->
                Log.e(TAG, "Age signals access request failed", exception)
                handleFailure(
                    exception, attempt, onMessage, onShowRetry,
                    onShowPlayStore, onLoading, onScheduleRetry
                )
            }
    }

    /** Step 2: read the age range. Only valid once access reported SHARED. */
    private fun checkAgeSignals(
        manager: AgeSignalsManager,
        attempt: Int,
        onMessage: (String) -> Unit,
        onShowRetry: (Boolean) -> Unit,
        onShowPlayStore: (Boolean) -> Unit,
        onLoading: (Boolean) -> Unit,
        onScheduleRetry: (Long) -> Unit
    ) {
        manager.checkAgeSignals(AgeSignalsRequest.builder().build())
            .addOnSuccessListener { result ->
                handleResult(result, onMessage, onShowRetry, onShowPlayStore, onLoading)
            }
            .addOnFailureListener { exception ->
                Log.e(TAG, "Age signals check failed", exception)
                handleFailure(
                    exception, attempt, onMessage, onShowRetry,
                    onShowPlayStore, onLoading, onScheduleRetry
                )
            }
    }

    private fun handleFailure(
        exception: Exception,
        attempt: Int,
        onMessage: (String) -> Unit,
        onShowRetry: (Boolean) -> Unit,
        onShowPlayStore: (Boolean) -> Unit,
        onLoading: (Boolean) -> Unit,
        onScheduleRetry: (Long) -> Unit
    ) {
        when ((exception as? AgeSignalsException)?.errorCode) {
            AgeSignalsErrorCode.NETWORK_ERROR -> {
                handleRetryableError(
                    attempt = attempt,
                    message = "No internet connection.\n\nAge verification requires internet.",
                    onMessage = onMessage,
                    onShowRetry = onShowRetry,
                    onLoading = onLoading,
                    onScheduleRetry = onScheduleRetry,
                    retryDelayMs = 3000
                )
            }
            AgeSignalsErrorCode.CANNOT_BIND_TO_SERVICE,
            AgeSignalsErrorCode.APP_NOT_OWNED -> {
                Log.w(TAG, "Not a Play Store install - allowing access")
                proceedToApp()
            }
            AgeSignalsErrorCode.API_NOT_AVAILABLE -> {
                Log.w(TAG, "API not available in region - allowing access")
                proceedToApp()
            }
            AgeSignalsErrorCode.PLAY_STORE_NOT_FOUND,
            AgeSignalsErrorCode.PLAY_SERVICES_NOT_FOUND,
            AgeSignalsErrorCode.PLAY_STORE_VERSION_OUTDATED,
            AgeSignalsErrorCode.PLAY_SERVICES_VERSION_OUTDATED,
            AgeSignalsErrorCode.SDK_VERSION_OUTDATED -> {
                Log.w(TAG, "Play Store/Services issue - allowing access")
                proceedToApp()
            }
            else -> {
                handleRetryableError(
                    attempt = attempt,
                    message = "Verification failed: ${exception.message}",
                    onMessage = onMessage,
                    onShowRetry = onShowRetry,
                    onLoading = onLoading,
                    onScheduleRetry = onScheduleRetry,
                    retryDelayMs = 2000
                )
            }
        }
    }

    private fun handleResult(
        result: AgeSignalsResult,
        onMessage: (String) -> Unit,
        onShowRetry: (Boolean) -> Unit,
        onShowPlayStore: (Boolean) -> Unit,
        onLoading: (Boolean) -> Unit
    ) {
        val ageLower: Int? = result.ageLower()
        val ageUpper: Int? = result.ageUpper()
        val ageRangeSource: Int? = result.ageRangeSource()

        Log.d(TAG, "Result - ageLower: $ageLower, ageUpper: $ageUpper, source: $ageRangeSource")

        when {
            // Confirmed at or above the minimum age. MIN_AGE must be a band lower
            // bound: every user below the lowest band reports ageLower = 0.
            ageLower != null && ageLower >= MIN_AGE -> proceedToApp()

            // Confirmed below the minimum age - terminal, no retry.
            ageLower != null -> {
                Log.w(TAG, "User below minimum age ($ageLower) - blocking access")
                showAgeRestriction()
            }

            // No range returned. Play sends this both for "not sharing" and for
            // some verified adults, so it does NOT prove the user is >= MIN_AGE.
            else -> {
                Log.w(TAG, "No age range returned - blocking access")
                blockUnverified(
                    "Your age range was not provided by Google Play.\n\n" +
                        "Enable age sharing for LyreTune in the Play Store, then tap Retry.",
                    onMessage, onShowRetry, onShowPlayStore, onLoading,
                    showPlayStore = true
                )
            }
        }
    }

    /** Blocks access, leaving the user a way to fix the cause and retry. */
    private fun blockUnverified(
        message: String,
        onMessage: (String) -> Unit,
        onShowRetry: (Boolean) -> Unit,
        onShowPlayStore: (Boolean) -> Unit,
        onLoading: (Boolean) -> Unit,
        showPlayStore: Boolean
    ) {
        onLoading(false)
        onMessage(message)
        onShowPlayStore(showPlayStore)
        onShowRetry(true)
    }

    private fun handleRetryableError(
        attempt: Int,
        message: String,
        onMessage: (String) -> Unit,
        onShowRetry: (Boolean) -> Unit,
        onLoading: (Boolean) -> Unit,
        onScheduleRetry: (Long) -> Unit,
        retryDelayMs: Long
    ) {
        onLoading(false)

        if (attempt < MAX_RETRY_ATTEMPTS) {
            onMessage("$message\n\nRetrying... (${attempt + 1}/$MAX_RETRY_ATTEMPTS)")
            // Re-runs the whole access-then-check flow, not just checkAgeSignals.
            onScheduleRetry(retryDelayMs)
        } else {
            onMessage("$message\n\nPlease check your connection and tap Retry.")
            onShowRetry(true)
        }
    }

    private fun openPlayStore() {
        val uri = android.net.Uri.parse("market://details?id=$packageName")
        val intent = Intent(Intent.ACTION_VIEW, uri).apply {
            setPackage("com.android.vending")
        }
        try {
            startActivity(intent)
        } catch (e: android.content.ActivityNotFoundException) {
            Log.w(TAG, "Play Store app not available, falling back to browser", e)
            startActivity(
                Intent(
                    Intent.ACTION_VIEW,
                    android.net.Uri.parse("https://play.google.com/store/apps/details?id=$packageName")
                )
            )
        }
    }

    private fun proceedToApp() {
        startActivity(Intent(this, MainActivity::class.java))
        finish()
    }

    private fun showAgeRestriction() {
        setContent {
            LyreTuneTheme {
                Surface(
                    modifier = Modifier.fillMaxSize(),
                    color = MaterialTheme.colorScheme.background
                ) {
                    Column(
                        modifier = Modifier
                            .fillMaxSize()
                            .padding(32.dp),
                        horizontalAlignment = Alignment.CenterHorizontally,
                        verticalArrangement = Arrangement.Center
                    ) {
                        Text(
                            text = "Age Restriction",
                            style = MaterialTheme.typography.headlineMedium,
                            color = MaterialTheme.colorScheme.onBackground
                        )
                        Spacer(modifier = Modifier.height(16.dp))
                        Text(
                            text = "This app is restricted to users $MIN_AGE years of age and older.",
                            style = MaterialTheme.typography.bodyLarge,
                            textAlign = TextAlign.Center,
                            color = MaterialTheme.colorScheme.onBackground
                        )
                    }
                }
            }
        }

        android.os.Handler(mainLooper).postDelayed({
            finishAffinity()
        }, 3000)
    }

    @Deprecated("Use onBackPressedDispatcher")
    override fun onBackPressed() {
        // Block back button during verification
    }

    companion object {
        private const val TAG = "AgeVerification"
        private const val MAX_RETRY_ATTEMPTS = 3

        /** Must match a Play age-band lower bound: 13, 16, or 18 by default. */
        private const val MIN_AGE = 18
    }
}
