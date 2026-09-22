package app.p2pmessenger.p2p_messenger

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
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            "app.massjj/updates",
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "getInfo" -> {
                    val packageInfo = packageManager.getPackageInfo(packageName, 0)
                    val updateDirectory = File(cacheDir, "massjj-updates").apply { mkdirs() }
                    result.success(
                        mapOf(
                            "version" to (packageInfo.versionName ?: "0.0.0"),
                            "directory" to updateDirectory.absolutePath,
                        ),
                    )
                }
                "installApk" -> installApk(call.arguments as? String, result)
                else -> result.notImplemented()
            }
        }
    }

    private fun installApk(path: String?, result: MethodChannel.Result) {
        if (path == null) {
            result.error("invalid_path", "Missing APK path", null)
            return
        }
        val updateDirectory = File(cacheDir, "massjj-updates").canonicalFile
        val apk = File(path).canonicalFile
        if (!apk.isFile || apk.extension.lowercase() != "apk" || apk.parentFile != updateDirectory) {
            result.error("invalid_path", "APK is outside the update cache", null)
            return
        }
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O &&
            !packageManager.canRequestPackageInstalls()
        ) {
            startActivity(
                Intent(
                    Settings.ACTION_MANAGE_UNKNOWN_APP_SOURCES,
                    Uri.parse("package:$packageName"),
                ),
            )
            result.success("settings")
            return
        }
        val uri = FileProvider.getUriForFile(
            this,
            "$packageName.massjj_updates",
            apk,
        )
        startActivity(
            Intent(Intent.ACTION_VIEW).apply {
                setDataAndType(uri, "application/vnd.android.package-archive")
                addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
            },
        )
        result.success("installer")
    }
}
