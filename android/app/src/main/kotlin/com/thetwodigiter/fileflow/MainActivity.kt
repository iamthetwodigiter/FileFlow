package com.thetwodigiter.fileflow

import android.content.Context
import android.content.Intent
import android.net.wifi.WifiManager
import android.os.Build
import android.util.Log
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val NOTIFICATIONS_CHANNEL = "com.fileflow/notifications"
    private val BACKGROUND_CHANNEL = "com.fileflow/background"
    private val MULTICAST_CHANNEL = "com.fileflow/multicast"
    private var multicastLock: WifiManager.MulticastLock? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        // Handle multicast lock for UDP discovery
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, MULTICAST_CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "acquire" -> {
                    acquireMulticastLock()
                    result.success(true)
                }
                "release" -> {
                    releaseMulticastLock()
                    result.success(true)
                }
                else -> result.notImplemented()
            }
        }

        // Handle all notification requests from Flutter
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, NOTIFICATIONS_CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "showConnectionEstablished" -> {
                    val deviceName = call.argument<String>("deviceName") ?: "Device"
                    FileFlowNotificationManager.showConnectionEstablished(this, deviceName)
                    result.success(null)
                }
                "showConnectionRejected" -> {
                    val deviceName = call.argument<String>("deviceName") ?: "Device"
                    val reason = call.argument<String>("reason") ?: "Connection rejected"
                    FileFlowNotificationManager.showConnectionRejected(this, deviceName, reason)
                    result.success(null)
                }
                "showTransferRequest" -> {
                    val deviceName = call.argument<String>("deviceName") ?: "Device"
                    val fileName = call.argument<String>("fileName") ?: "File"
                    val fileSize = (call.argument<Number>("fileSize") ?: 0).toLong()
                    FileFlowNotificationManager.showTransferRequest(this, deviceName, fileName, fileSize)
                    result.success(null)
                }
                "showTransferStarted" -> {
                    val fileName = call.argument<String>("fileName") ?: "File"
                    val isSending = call.argument<Boolean>("isSending") ?: false
                    FileFlowNotificationManager.showTransferStarted(this, fileName, isSending)
                    result.success(null)
                }
                "updateTransferProgress" -> {
                    val fileName = call.argument<String>("fileName") ?: "File"
                    val progress = call.argument<Int>("progress") ?: 0
                    val speedMBps = call.argument<Double>("speedMBps") ?: 0.0
                    val isSending = call.argument<Boolean>("isSending") ?: false
                    FileFlowNotificationManager.updateTransferProgress(this, fileName, progress, speedMBps, isSending)
                    result.success(null)
                }
                "showTransferPaused" -> {
                    val fileName = call.argument<String>("fileName") ?: "File"
                    FileFlowNotificationManager.showTransferPaused(this, fileName)
                    result.success(null)
                }
                "showTransferResumed" -> {
                    val fileName = call.argument<String>("fileName") ?: "File"
                    FileFlowNotificationManager.showTransferResumed(this, fileName)
                    result.success(null)
                }
                "showTransferCompleted" -> {
                    val fileName = call.argument<String>("fileName") ?: "File"
                    val fileSize = (call.argument<Number>("fileSize") ?: 0).toLong()
                    val isSending = call.argument<Boolean>("isSending") ?: false
                    FileFlowNotificationManager.showTransferCompleted(this, fileName, fileSize, isSending)
                    result.success(null)
                }
                "showTransferCancelled" -> {
                    val fileName = call.argument<String>("fileName") ?: "File"
                    val reason = call.argument<String>("reason") ?: "Cancelled"
                    FileFlowNotificationManager.showTransferCancelled(this, fileName, reason)
                    result.success(null)
                }
                "showError" -> {
                    val title = call.argument<String>("title") ?: "Error"
                    val message = call.argument<String>("message") ?: "An error occurred"
                    FileFlowNotificationManager.showError(this, title, message)
                    result.success(null)
                }
                else -> result.notImplemented()
            }
        }

        // Handle background transfer service (foreground service for keeping transfers alive)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, BACKGROUND_CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "startService" -> {
                    val fileName = call.argument<String>("fileName") ?: "File"
                    startTransferService(fileName)
                    result.success(null)
                }
                "updateProgress" -> {
                    val fileName = call.argument<String>("fileName") ?: "File"
                    val progress = call.argument<Int>("progress") ?: 0
                    updateServiceProgress(fileName, progress)
                    result.success(null)
                }
                "startConnectionService" -> {
                    val deviceName = call.argument<String>("deviceName") ?: "Device"
                    startConnectionService(deviceName)
                    result.success(null)
                }
                "stopService" -> {
                    stopTransferService()
                    result.success(null)
                }
                else -> result.notImplemented()
            }
        }
    }

    private fun startConnectionService(deviceName: String) {
        val intent = Intent(this, TransferService::class.java).apply {
            action = TransferService.ACTION_START_CONNECTION
            putExtra(TransferService.EXTRA_FILE_NAME, deviceName)
        }
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            startForegroundService(intent)
        } else {
            startService(intent)
        }
    }

    private fun startTransferService(fileName: String) {
        val intent = Intent(this, TransferService::class.java).apply {
            action = TransferService.ACTION_START
            putExtra(TransferService.EXTRA_FILE_NAME, fileName)
        }
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            startForegroundService(intent)
        } else {
            startService(intent)
        }
    }

    private fun updateServiceProgress(fileName: String, progress: Int) {
        val intent = Intent(this, TransferService::class.java).apply {
            action = TransferService.ACTION_UPDATE
            putExtra(TransferService.EXTRA_FILE_NAME, fileName)
            putExtra(TransferService.EXTRA_PROGRESS, progress)
        }
        startService(intent)
    }

    private fun stopTransferService() {
        val intent = Intent(this, TransferService::class.java).apply {
            action = TransferService.ACTION_STOP
        }
        startService(intent)
    }

    private fun acquireMulticastLock() {
        try {
            if (multicastLock == null) {
                val wifiManager = applicationContext.getSystemService(Context.WIFI_SERVICE) as WifiManager
                multicastLock = wifiManager.createMulticastLock("FileFlowMulticast")
                multicastLock?.setReferenceCounted(true)
            }
            
            if (multicastLock?.isHeld == false) {
                multicastLock?.acquire()
                Log.d("FileFlow", "✅ Multicast lock acquired")
            }
        } catch (e: Exception) {
            Log.e("FileFlow", "❌ Failed to acquire multicast lock: ${e.message}")
        }
    }

    private fun releaseMulticastLock() {
        try {
            if (multicastLock?.isHeld == true) {
                multicastLock?.release()
                Log.d("FileFlow", "✅ Multicast lock released")
            }
        } catch (e: Exception) {
            Log.e("FileFlow", "❌ Failed to release multicast lock: ${e.message}")
        }
    }

    override fun onDestroy() {
        super.onDestroy()
        releaseMulticastLock()
    }
}