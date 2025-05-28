package com.example.flutter_locker_project

import android.content.Intent
import android.nfc.NfcAdapter
import android.nfc.Tag
import android.os.Bundle
import android.util.Log
import androidx.appcompat.app.AppCompatActivity
import androidx.lifecycle.ViewModel
import androidx.lifecycle.ViewModelProvider
import androidx.lifecycle.lifecycleScope
import androidx.lifecycle.viewModelScope
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import com.infineon.smack.sdk.SmackSdk
import com.infineon.smack.sdk.smack.DefaultSmackClient
import com.infineon.smack.sdk.log.AndroidSmackLogger
import com.infineon.smack.sdk.nfc.NfcAdapterWrapper
import com.infineon.smack.sdk.android.AndroidNfcAdapterWrapper
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.flow.filterNotNull
import kotlinx.coroutines.flow.first
import kotlinx.coroutines.flow.retry
import kotlinx.coroutines.flow.onEach
import kotlinx.coroutines.launch
import kotlin.coroutines.cancellation.CancellationException

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

        //  Initialize SmackSdk
        val smackClient = DefaultSmackClient(AndroidSmackLogger())
        nfcAdapterWrapper = AndroidNfcAdapterWrapper()
        smackSdk = SmackSdk.Builder(smackClient)
            .setNfcAdapterWrapper(nfcAdapterWrapper)
            .setCoroutineDispatcher(Dispatchers.IO)
            .build()
        smackSdk.onCreate(this)

        //  Setup ViewModel
        registrationViewModel = ViewModelProvider(
            this,
            RegistrationViewModelFactory(smackSdk)
        ).get(RegistrationViewModel::class.java)

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
                    registrationViewModel.setupNewLock(supervisorKey, newPassword)
                    result.success(null)
                }
                else -> result.notImplemented()
            }
        }
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        Log.d(TAG, "onNewIntent called")
        smackSdk.onNewIntent(intent)

        val tag: Tag? = intent.getParcelableExtra(NfcAdapter.EXTRA_TAG)
        Log.d(TAG, "Tag detected? ${'$'}{tag != null}")
        if (::methodChannel.isInitialized) {
            methodChannel.invokeMethod("lockPresent", tag != null)
        }
    }
}

class RegistrationViewModel(private val smackSdk: SmackSdk) : ViewModel() {

    val setupResult = androidx.lifecycle.MutableLiveData<Boolean>()

    fun setupNewLock(supervisorKey: String, newPassword: String) {
        viewModelScope.launch {
            try {
                // Wait for mailbox (tag) connection
                val mailbox = smackSdk.mailboxApi.mailbox
                    .filterNotNull()
                    .first()

                // Once mailbox live, fetch lock
                val lock = smackSdk.lockApi.getLock()
                    .retry { e -> e !is CancellationException }
                    .filterNotNull()
                    .first()
                Log.d("RegistrationViewModel", "Lock fetched: $lock")

                // Depending on new vs existing
                if (!lock.isNew) {
                    val existingKey = smackSdk.lockApi.validatePassword(
                        lock,
                        "MyUserName",
                        System.currentTimeMillis() / 1000,
                        newPassword
                    )
                    smackSdk.lockApi.initializeSession(
                        lock,
                        "MyUserName",
                        System.currentTimeMillis() / 1000,
                        existingKey
                    )
                    smackSdk.lockApi.unlock(lock, existingKey)
                } else {
                    val lockKey = smackSdk.lockApi.setLockKey(
                        lock,
                        "MyUserName",
                        System.currentTimeMillis() / 1000,
                        supervisorKey,
                        newPassword
                    )
                    smackSdk.lockApi.initializeSession(
                        lock,
                        "MyUserName",
                        System.currentTimeMillis() / 1000,
                        lockKey
                    )
                    smackSdk.lockApi.unlock(lock, lockKey)
                }

                setupResult.postValue(true)

            } catch (e: Exception) {
                Log.e("RegistrationViewModel", "setupNewLock failed", e)
                setupResult.postValue(false)
            }
        }
    }
}

class RegistrationViewModelFactory(private val smackSdk: SmackSdk) : ViewModelProvider.Factory {
    override fun <T : ViewModel> create(modelClass: Class<T>): T {
        if (modelClass.isAssignableFrom(RegistrationViewModel::class.java)) {
            @Suppress("UNCHECKED_CAST")
            return RegistrationViewModel(smackSdk) as T
        }
        throw IllegalArgumentException("Unknown ViewModel class: ${'$'}{modelClass.name}")
    }
}
