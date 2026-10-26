package dev.efa_tech.eve_fit_assistant

import android.content.Intent
import android.net.Uri
import android.os.Build
import android.provider.Settings
import androidx.core.content.FileProvider
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File

class MainActivity : FlutterActivity() {
    private lateinit var installChannel: MethodChannel
    private lateinit var systemUiChannel: MethodChannel

    init {
        System.loadLibrary("rust_lib_eve_fit_assistant")
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        installChannel = MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            CHANNEL_NAME,
        )
        systemUiChannel = MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            SYSTEM_UI_CHANNEL_NAME,
        )
        systemUiChannel.setMethodCallHandler { call, result ->
            when (call.method) {
                // Edge-to-edge only takes effect on Android 10 (API 29) and
                // later; Dart gates the transparent navigation bar on this.
                "getSdkInt" -> result.success(Build.VERSION.SDK_INT)

                else -> result.notImplemented()
            }
        }

        installChannel.setMethodCallHandler { call, result ->
            when (call.method) {
                "getSupportedAbis" -> {
                    val abis = Build.SUPPORTED_ABIS?.toList() ?: emptyList<String>()
                    result.success(abis)
                }

                "canRequestPackageInstalls" -> {
                    val allowed = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                        packageManager.canRequestPackageInstalls()
                    } else {
                        true
                    }
                    result.success(allowed)
                }

                "openInstallPermissionSettings" -> {
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                        val intent = Intent(
                            Settings.ACTION_MANAGE_UNKNOWN_APP_SOURCES,
                            Uri.parse("package:$packageName"),
                        )
                        try {
                            startActivity(intent)
                        } catch (e: Exception) {
                            result.error("OPEN_SETTINGS_FAILED", e.message, null)
                            return@setMethodCallHandler
                        }
                    }
                    result.success(null)
                }

                "installApk" -> {
                    val path = call.argument<String>("path")
                    if (path == null) {
                        result.error("INVALID_ARGUMENT", "Missing APK path", null)
                        return@setMethodCallHandler
                    }
                    try {
                        installApk(path)
                        result.success(null)
                    } catch (e: Exception) {
                        result.error("INSTALL_FAILED", e.message, null)
                    }
                }

                else -> result.notImplemented()
            }
        }
    }

    private fun installApk(path: String) {
        val file = File(path)
        val uri = FileProvider.getUriForFile(
            this,
            "${packageName}.fileprovider",
            file,
        )
        val intent = Intent(Intent.ACTION_VIEW).apply {
            setDataAndType(uri, "application/vnd.android.package-archive")
            flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_GRANT_READ_URI_PERMISSION
        }
        startActivity(intent)
    }

    companion object {
        private const val CHANNEL_NAME = "dev.efa_tech.eve_fit_assistant/installer"
        private const val SYSTEM_UI_CHANNEL_NAME = "dev.efa_tech.eve_fit_assistant/system_ui"
    }
}
