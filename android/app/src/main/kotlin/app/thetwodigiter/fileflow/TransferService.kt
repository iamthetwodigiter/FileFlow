package app.thetwodigiter.fileflow

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.Context
import android.content.Intent
import android.os.Build
import android.os.IBinder
import androidx.core.app.NotificationCompat
import kotlin.math.roundToInt

class TransferService : Service() {
    companion object {
        const val CHANNEL_ID = "fileflow_transfer_channel"
        const val SERVICE_NOTIFICATION_ID = 1001
        const val ACTION_START = "START_TRANSFER"
        const val ACTION_START_CONNECTION = "START_CONNECTION"
        const val ACTION_STOP = "STOP_TRANSFER"
        const val ACTION_UPDATE = "UPDATE_PROGRESS"
        const val EXTRA_FILE_NAME = "file_name"
        const val EXTRA_PROGRESS = "progress"
    }

    override fun onCreate() {
        super.onCreate()
        createNotificationChannel()
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        when (intent?.action) {
            ACTION_START -> {
                val fileName = intent.getStringExtra(EXTRA_FILE_NAME) ?: "File"
                val notification = createServiceNotification(fileName, 0)
                startForeground(SERVICE_NOTIFICATION_ID, notification)
            }
            ACTION_START_CONNECTION -> {
                val deviceName = intent.getStringExtra(EXTRA_FILE_NAME) ?: "Device"
                val notification = createServiceNotification(deviceName, -1)
                startForeground(SERVICE_NOTIFICATION_ID, notification)
            }
            ACTION_UPDATE -> {
                val fileName = intent.getStringExtra(EXTRA_FILE_NAME) ?: "File"
                val progress = intent.getIntExtra(EXTRA_PROGRESS, 0)
                val notification = createServiceNotification(fileName, progress)
                val notificationManager = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
                notificationManager.notify(SERVICE_NOTIFICATION_ID, notification)
            }
            ACTION_STOP -> {
                stopForeground(true)
                stopSelf()
            }
        }
        return START_STICKY
    }

    override fun onBind(intent: Intent?): IBinder? = null

    private fun createNotificationChannel() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(
                CHANNEL_ID,
                "FileFlow Transfers",
                NotificationManager.IMPORTANCE_LOW
            ).apply {
                description = "Shows file transfer progress in background"
            }
            val notificationManager = getSystemService(NotificationManager::class.java)
            notificationManager.createNotificationChannel(channel)
        }
    }

    private fun createServiceNotification(fileName: String, progress: Int): Notification {
        val intent = packageManager.getLaunchIntentForPackage(packageName)
        val pendingIntent = PendingIntent.getActivity(
            this, 0, intent,
            PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT
        )

        val title = if (progress == -1) "Connected" else "Transferring: $fileName"
        val content = if (progress == -1) "Connected to $fileName" else if (progress > 0) "$progress% complete" else "Starting transfer..."

        return NotificationCompat.Builder(this, CHANNEL_ID)
            .setContentTitle(title)
            .setContentText(content)
            .setSmallIcon(android.R.drawable.stat_sys_download)
            .setProgress(100, if (progress == -1) 0 else progress, progress == 0)
            .setOngoing(true)
            .setContentIntent(pendingIntent)
            .setPriority(NotificationCompat.PRIORITY_LOW)
            .build()
    }
}

/**
 * FileFlowNotificationManager singleton for managing all user-facing notifications
 * (separate from the foreground service notification)
 */
object FileFlowNotificationManager {
    private const val CHANNEL_ID = "fileflow_transfer_channel"
    private const val NOTIFICATION_ID_CONNECTION = 2001
    private const val NOTIFICATION_ID_TRANSFER = 2002
    private const val NOTIFICATION_ID_ERROR = 2003

    fun createNotificationChannel(context: Context) {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(
                CHANNEL_ID,
                "FileFlow Transfers",
                NotificationManager.IMPORTANCE_DEFAULT
            ).apply {
                description = "Notifications for file transfers and connections"
            }
            val notificationManager = context.getSystemService(NotificationManager::class.java)
            notificationManager.createNotificationChannel(channel)
        }
    }

    fun showConnectionRequest(context: Context, deviceName: String) {
        createNotificationChannel(context)
        val notification = NotificationCompat.Builder(context, CHANNEL_ID)
            .setContentTitle("Connection Request")
            .setContentText("$deviceName is requesting to connect")
            .setSmallIcon(android.R.drawable.ic_dialog_info)
            .setPriority(NotificationCompat.PRIORITY_HIGH)
            .setAutoCancel(true)
            .build()

        val notificationManager = context.getSystemService(NotificationManager::class.java)
        notificationManager.notify(NOTIFICATION_ID_CONNECTION, notification)
    }

    fun showConnectionEstablished(context: Context, deviceName: String) {
        createNotificationChannel(context)
        val notification = NotificationCompat.Builder(context, CHANNEL_ID)
            .setContentTitle("Connected to Device")
            .setContentText("Successfully connected to $deviceName")
            .setSmallIcon(android.R.drawable.ic_dialog_info)
            .setPriority(NotificationCompat.PRIORITY_DEFAULT)
            .setAutoCancel(true)
            .build()

        val notificationManager = context.getSystemService(NotificationManager::class.java)
        notificationManager.notify(NOTIFICATION_ID_CONNECTION, notification)
    }

    fun showConnectionRejected(context: Context, deviceName: String, reason: String) {
        createNotificationChannel(context)
        val notification = NotificationCompat.Builder(context, CHANNEL_ID)
            .setContentTitle("Connection Rejected")
            .setContentText("$deviceName rejected connection: $reason")
            .setSmallIcon(android.R.drawable.ic_dialog_alert)
            .setPriority(NotificationCompat.PRIORITY_HIGH)
            .setAutoCancel(true)
            .build()

        val notificationManager = context.getSystemService(NotificationManager::class.java)
        notificationManager.notify(NOTIFICATION_ID_CONNECTION, notification)
    }

    fun showTransferRequest(context: Context, deviceName: String, fileName: String, fileSize: Long) {
        createNotificationChannel(context)
        val sizeMB = (fileSize / (1024.0 * 1024.0) * 100).roundToInt() / 100.0
        val notification = NotificationCompat.Builder(context, CHANNEL_ID)
            .setContentTitle("Transfer Request from $deviceName")
            .setContentText("$fileName ($sizeMB MB)")
            .setSmallIcon(android.R.drawable.ic_dialog_info)
            .setPriority(NotificationCompat.PRIORITY_HIGH)
            .setAutoCancel(true)
            .build()

        val notificationManager = context.getSystemService(NotificationManager::class.java)
        notificationManager.notify(NOTIFICATION_ID_TRANSFER, notification)
    }

    fun showTransferStarted(context: Context, fileName: String, isSending: Boolean) {
        createNotificationChannel(context)
        val action = if (isSending) "Sending" else "Receiving"
        val notification = NotificationCompat.Builder(context, CHANNEL_ID)
            .setContentTitle("$action: $fileName")
            .setContentText("Starting transfer...")
            .setSmallIcon(android.R.drawable.ic_menu_upload)
            .setProgress(100, 0, true)
            .setOngoing(true)
            .build()

        val notificationManager = context.getSystemService(NotificationManager::class.java)
        notificationManager.notify(NOTIFICATION_ID_TRANSFER, notification)
    }

    fun updateTransferProgress(
        context: Context,
        fileName: String,
        progress: Int,
        speedMBps: Double,
        isSending: Boolean
    ) {
        createNotificationChannel(context)
        val action = if (isSending) "Sending" else "Receiving"
        val speedText = String.format("%.1f MB/s", speedMBps)
        val notification = NotificationCompat.Builder(context, CHANNEL_ID)
            .setContentTitle("$action: $fileName")
            .setContentText("$progress% • $speedText")
            .setSmallIcon(android.R.drawable.ic_menu_upload)
            .setProgress(100, progress, false)
            .setOngoing(true)
            .build()

        val notificationManager = context.getSystemService(NotificationManager::class.java)
        notificationManager.notify(NOTIFICATION_ID_TRANSFER, notification)
    }

    fun showTransferPaused(context: Context, fileName: String) {
        createNotificationChannel(context)
        val notification = NotificationCompat.Builder(context, CHANNEL_ID)
            .setContentTitle("Transfer Paused")
            .setContentText("$fileName")
            .setSmallIcon(android.R.drawable.ic_media_pause)
            .setPriority(NotificationCompat.PRIORITY_DEFAULT)
            .setOngoing(true)
            .build()

        val notificationManager = context.getSystemService(NotificationManager::class.java)
        notificationManager.notify(NOTIFICATION_ID_TRANSFER, notification)
    }

    fun showTransferResumed(context: Context, fileName: String) {
        createNotificationChannel(context)
        val notification = NotificationCompat.Builder(context, CHANNEL_ID)
            .setContentTitle("Transfer Resumed")
            .setContentText("$fileName")
            .setSmallIcon(android.R.drawable.ic_media_play)
            .setPriority(NotificationCompat.PRIORITY_DEFAULT)
            .setOngoing(true)
            .build()

        val notificationManager = context.getSystemService(NotificationManager::class.java)
        notificationManager.notify(NOTIFICATION_ID_TRANSFER, notification)
    }

    fun showTransferCompleted(context: Context, fileName: String, fileSize: Long, isSending: Boolean) {
        createNotificationChannel(context)
        val sizeMB = (fileSize / (1024.0 * 1024.0) * 100).roundToInt() / 100.0
        val action = if (isSending) "Sent" else "Received"
        val notification = NotificationCompat.Builder(context, CHANNEL_ID)
            .setContentTitle("$action Successfully")
            .setContentText("$fileName ($sizeMB MB)")
            .setSmallIcon(android.R.drawable.ic_dialog_info)
            .setPriority(NotificationCompat.PRIORITY_DEFAULT)
            .setAutoCancel(true)
            .build()

        val notificationManager = context.getSystemService(NotificationManager::class.java)
        notificationManager.notify(NOTIFICATION_ID_TRANSFER, notification)
    }

    fun showTransferCancelled(context: Context, fileName: String, reason: String) {
        createNotificationChannel(context)
        val notification = NotificationCompat.Builder(context, CHANNEL_ID)
            .setContentTitle("Transfer Failed")
            .setContentText("$reason - $fileName")
            .setSmallIcon(android.R.drawable.ic_dialog_alert)
            .setPriority(NotificationCompat.PRIORITY_HIGH)
            .setAutoCancel(true)
            .build()

        val notificationManager = context.getSystemService(NotificationManager::class.java)
        notificationManager.notify(NOTIFICATION_ID_ERROR, notification)
    }

    fun showError(context: Context, title: String, message: String) {
        createNotificationChannel(context)
        val notification = NotificationCompat.Builder(context, CHANNEL_ID)
            .setContentTitle(title)
            .setContentText(message)
            .setSmallIcon(android.R.drawable.ic_dialog_alert)
            .setPriority(NotificationCompat.PRIORITY_HIGH)
            .setAutoCancel(true)
            .build()

        val notificationManager = context.getSystemService(NotificationManager::class.java)
        notificationManager.notify(NOTIFICATION_ID_ERROR, notification)
    }
}