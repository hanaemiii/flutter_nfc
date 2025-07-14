package com.example.flutter_locker_project

import android.content.Intent
import android.nfc.NfcAdapter
import android.nfc.Tag
import android.os.Bundle
import android.util.Log
import androidx.lifecycle.ViewModel
import androidx.lifecycle.ViewModelProvider
import androidx.lifecycle.viewModelScope
import com.infineon.smack.sdk.SmackSdk
import com.infineon.smack.sdk.android.AndroidNfcAdapterWrapper
import com.infineon.smack.sdk.log.AndroidSmackLogger
import com.infineon.smack.sdk.nfc.NfcAdapterWrapper
import com.infineon.smack.sdk.smack.DefaultSmackClient
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.time.LocalDateTime
import java.time.ZoneOffset
import kotlin.coroutines.cancellation.CancellationException
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.flow.collect
import kotlinx.coroutines.flow.filterNotNull
import kotlinx.coroutines.flow.retry
import kotlinx.coroutines.flow.take
import kotlinx.coroutines.launch

class MainActivity : FlutterFragmentActivity() {

    companion object {
        private const val CHANNEL = "com.example.flutter_locker_project/smack"
        private const val TAG = "MainActivity"
    }

    private lateinit var smackSdk: SmackSdk
    private lateinit var methodChannel: MethodChannel
    private lateinit var nfcAdapterWrapper: NfcAdapterWrapper
    private lateinit var registrationViewModel: RegistrationViewModel

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)

        // Initialize SmackSdk
        val smackClient = DefaultSmackClient(AndroidSmackLogger())
        nfcAdapterWrapper = AndroidNfcAdapterWrapper()
        smackSdk =
                SmackSdk.Builder(smackClient)
                        .setNfcAdapterWrapper(nfcAdapterWrapper)
                        .setCoroutineDispatcher(Dispatchers.IO)
                        .build()
        smackSdk.onCreate(this)

        // Setup ViewModel
        registrationViewModel =
                ViewModelProvider(this, RegistrationViewModelFactory(smackSdk))
                        .get(RegistrationViewModel::class.java)

        // Observe setup results and forward to Flutter
        registrationViewModel.setupResult.observe(this) { success ->
            Log.d(TAG, "setupResult: $success")
            if (::methodChannel.isInitialized) {
                methodChannel.invokeMethod("setupResult", success)
            }
        }
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        methodChannel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
        methodChannel.setMethodCallHandler { call, result ->
            when (call.method) {
                "setupNewLock" -> {
                    val supervisorKey = call.argument<String>("supervisorKey") ?: ""
                    val newPassword = call.argument<String>("newPassword") ?: ""
                    val userName = call.argument<String>("userName") ?: ""

                    registrationViewModel.setupNewLock(
                            userName,
                            supervisorKey,
                            newPassword,
                            onComplete = { success ->
                                result.success(
                                        if (success) "Password changed"
                                        else "Failed to change password"
                                )
                            }
                    )
                }
                "changePassword" -> {
                    val supervisorKey = call.argument<String>("supervisorKey") ?: ""
                    val newPassword = call.argument<String>("newPassword") ?: ""
                    val userName = call.argument<String>("userName") ?: ""

                    registrationViewModel.changePassword(
                            userName,
                            supervisorKey,
                            newPassword,
                            onComplete = { success ->
                                result.success(
                                        if (success) "Password changed"
                                        else "Failed to change password"
                                )
                            }
                    )
                }
                "unlockLock" -> {
                    val password = call.argument<String>("password") ?: ""
                    val userName = call.argument<String>("userName") ?: ""

                    registrationViewModel.unlockLock(
                            userName,
                            password,
                            onComplete = { success ->
                                result.success(if (success) "Unlocked" else "Failed to unlock")
                            }
                    )
                }
                "lockLock" -> {
                    val password = call.argument<String>("password") ?: ""
                    val userName = call.argument<String>("userName") ?: ""

                    registrationViewModel.lockLock(
                            userName,
                            password,
                            onComplete = { success ->
                                result.success(if (success) "Locked" else "Failed to lock")
                            }
                    )
                }
                else -> result.notImplemented()
            }
        }
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        Log.d(TAG, "onNewIntent called")
        smackSdk.onNewIntent(intent)

        val tag: Tag? = intent.getParcelableExtra(NfcAdapter.EXTRA_TAG, Tag::class.java)
        Log.d(TAG, "Tag detected? ${tag != null}")
        if (::methodChannel.isInitialized) {
            methodChannel.invokeMethod("lockPresent", tag != null)
        }
    }
}

class RegistrationViewModel(private val smackSdk: SmackSdk) : ViewModel() {

    val setupResult = androidx.lifecycle.MutableLiveData<Boolean>()

    fun setupNewLock(
            userName: String,
            supervisorKey: String,
            newPassword: String,
            onComplete: (Boolean) -> Unit
    ) {
        viewModelScope.launch {
            try {
                smackSdk.lockApi
                        .getLock()
                        .retry { e -> e !is CancellationException }
                        .filterNotNull()
                        .take(1)
                        .collect { lock ->
                            val key =
                                    if (lock.isNew) {
                                        smackSdk.lockApi.setLockKey(
                                                lock,
                                                userName,
                                                LocalDateTime.now().toEpochSecond(ZoneOffset.UTC),
                                                supervisorKey,
                                                newPassword
                                        )
                                    } else {
                                        // New password is used to validate existing lock
                                        smackSdk.lockApi.validatePassword(
                                                lock,
                                                userName,
                                                System.currentTimeMillis() / 1000,
                                                newPassword
                                        )
                                    }
                            // Initialize session and unlock with the obtained key
                            smackSdk.lockApi.initializeSession(
                                    lock,
                                    userName,
                                    System.currentTimeMillis() / 1000,
                                    key
                            )
                            smackSdk.lockApi.unlock(lock, key)

                            // Emit success and abort further collection
                            onComplete(true)
                        }
            } catch (e: CancellationException) {
                Log.e("CancellationException", "Failed to set password", e)
                onComplete(false)
            } catch (e: Exception) {
                Log.e("RegistrationViewModel", "setupNewLock failed", e)
                onComplete(false)
            }
        }
    }

    fun changePassword(
            userName: String,
            supervisorKey: String,
            newPassword: String,
            onComplete: (Boolean) -> Unit
    ) {
        viewModelScope.launch {
            try {
                smackSdk.lockApi
                        .getLock()
                        .retry { e -> e !is CancellationException }
                        .filterNotNull()
                        .take(1)
                        .collect { lock ->
                            val timestamp = System.currentTimeMillis() / 1000

                            smackSdk.lockApi.setLockKey(
                                    lock,
                                    userName,
                                    timestamp,
                                    supervisorKey,
                                    newPassword
                            )
                            onComplete(true)
                        }
            } catch (e: CancellationException) {
                Log.e("CancellationException", "Failed to change password", e)
                onComplete(false)
            } catch (e: Exception) {
                Log.e("RegistrationViewModel", "Failed to change password", e)
                onComplete(false)
            }
        }
    }

    fun unlockLock(userName: String, password: String, onComplete: (Boolean) -> Unit) {
        viewModelScope.launch {
            try {
                Log.d("RegistrationViewModel", "starting")

                smackSdk.lockApi
                        .getLock()
                        .retry { e -> e !is CancellationException }
                        .filterNotNull()
                        .take(1)
                        .collect { lock ->
                            val timestamp = System.currentTimeMillis() / 1000
                            Log.d("RegistrationViewModel", "lock goted")

                            val key =
                                    smackSdk.lockApi.validatePassword(
                                            lock,
                                            userName,
                                            timestamp,
                                            password
                                    )
                            smackSdk.lockApi.initializeSession(
                                    lock,
                                    userName,
                                    timestamp,
                                    key,
                            )
                            smackSdk.lockApi.unlock(lock, key)
                            onComplete(true)
                        }
            } catch (e: CancellationException) {
                Log.d("CancellationException", "Unlock cancelled", e)
            } catch (e: Exception) {
                Log.e("RegistrationViewModel", "unlockLock failed", e)
                onComplete(false)
            }
        }
    }

    fun lockLock(userName: String, password: String, onComplete: (Boolean) -> Unit) {
        viewModelScope.launch {
            try {
                Log.d("RegistrationViewModel", "starting")

                smackSdk.lockApi
                        .getLock()
                        .retry { e -> e !is CancellationException }
                        .filterNotNull()
                        .take(1)
                        .collect { lock ->
                            val timestamp = System.currentTimeMillis() / 1000
                            val key =
                                    smackSdk.lockApi.validatePassword(
                                            lock,
                                            userName,
                                            timestamp,
                                            password
                                    )
                            smackSdk.lockApi.initializeSession(lock, userName, timestamp, key)

                            smackSdk.lockApi.lock(lock, key)
                            onComplete(true)
                        }
            } catch (e: CancellationException) {} catch (e: Exception) {
                Log.e("RegistrationViewModel", "lock failed", e)
                onComplete(false)
            }
        }
    }
}

class RegistrationViewModelFactory(private val smackSdk: SmackSdk) : ViewModelProvider.Factory {
    override fun <T : ViewModel> create(modelClass: Class<T>): T {
        if (modelClass.isAssignableFrom(RegistrationViewModel::class.java)) {
            @Suppress("UNCHECKED_CAST") return RegistrationViewModel(smackSdk) as T
        }
        throw IllegalArgumentException("Unknown ViewModel class: ${'$'}{modelClass.name}")
    }
}
