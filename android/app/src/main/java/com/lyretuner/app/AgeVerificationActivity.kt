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
import com.google.android.play.agesignals.AgeSignalsException
import com.google.android.play.agesignals.AgeSignalsManager
import com.google.android.play.agesignals.AgeSignalsManagerFactory
import com.google.android.play.agesignals.AgeSignalsRequest
import com.google.android.play.agesignals.AgeSignalsResult
import com.google.android.play.agesignals.model.AgeSignalsErrorCode
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
        var retryAttempts by remember { mutableIntStateOf(0) }

        LaunchedEffect(retryAttempts) {
            isLoading = true
            showRetry = false
            message = "Verifying age requirements..."
            checkAgeSignals(
                attempt = retryAttempts,
                onMessage = { message = it },
                onShowRetry = { showRetry = it },
                onLoading = { isLoading = it }
            )
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

                if (showRetry) {
                    Button(onClick = { retryAttempts++ }) {
                        Text("Retry")
                    }
                }
            }
        }
    }

    private suspend fun checkAgeSignals(
        attempt: Int,
        onMessage: (String) -> Unit,
        onShowRetry: (Boolean) -> Unit,
        onLoading: (Boolean) -> Unit
    ) {
        val manager = ageSignalsManager
        if (manager == null) {
            Log.w(TAG, "AgeSignalsManager not available - allowing access")
            proceedToApp()
            return
        }

        val request = AgeSignalsRequest.builder().build()

        manager.checkAgeSignals(request)
            .addOnSuccessListener { result ->
                handleResult(result)
            }
            .addOnFailureListener { exception ->
                Log.e(TAG, "Age signals check failed", exception)
                val errorCode = (exception as? AgeSignalsException)?.errorCode

                when (errorCode) {
                    AgeSignalsErrorCode.NETWORK_ERROR -> {
                        handleRetryableError(
                            attempt = attempt,
                            message = "No internet connection.\n\nAge verification requires internet.",
                            onMessage = onMessage,
                            onShowRetry = onShowRetry,
                            onLoading = onLoading,
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
                    AgeSignalsErrorCode.PLAY_SERVICES_VERSION_OUTDATED -> {
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
                            retryDelayMs = 2000
                        )
                    }
                }
            }
    }

    @Suppress("CAST_NEVER_SUCCEEDS")
    private fun handleResult(result: AgeSignalsResult) {
        val statusValue = result.userStatus() as? Int ?: -1
        val ageLower: Int? = result.ageLower()
        val ageUpper: Int? = result.ageUpper()

        Log.d(TAG, "Result - status: $statusValue, ageLower: $ageLower, ageUpper: $ageUpper")

        val isEligible = when {
            statusValue == 0 -> true  // VERIFIED = adult
            ageLower != null && ageLower >= 7 -> true
            ageLower == null && ageUpper == null -> true // No data = unsupported region
            else -> false
        }

        if (isEligible) {
            proceedToApp()
        } else {
            showAgeRestriction()
        }
    }

    private fun handleRetryableError(
        attempt: Int,
        message: String,
        onMessage: (String) -> Unit,
        onShowRetry: (Boolean) -> Unit,
        onLoading: (Boolean) -> Unit,
        retryDelayMs: Long
    ) {
        onLoading(false)

        if (attempt < MAX_RETRY_ATTEMPTS) {
            val nextAttempt = attempt + 1
            onMessage("$message\n\nRetrying... ($nextAttempt/$MAX_RETRY_ATTEMPTS)")

            val request = AgeSignalsRequest.builder().build()
            android.os.Handler(mainLooper).postDelayed({
                ageSignalsManager?.checkAgeSignals(request)
                    ?.addOnSuccessListener { result -> handleResult(result) }
                    ?.addOnFailureListener {
                        if (nextAttempt >= MAX_RETRY_ATTEMPTS) {
                            onMessage("$message\n\nPlease check your connection and tap Retry.")
                            onShowRetry(true)
                        } else {
                            handleRetryableError(
                                attempt = nextAttempt,
                                message = message,
                                onMessage = onMessage,
                                onShowRetry = onShowRetry,
                                onLoading = onLoading,
                                retryDelayMs = retryDelayMs
                            )
                        }
                    }
            }, retryDelayMs)
        } else {
            onMessage("$message\n\nPlease check your connection and tap Retry.")
            onShowRetry(true)
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
                            text = "This app is restricted to users 7 years of age and older.",
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
    }
}
