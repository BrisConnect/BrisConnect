package com.example.brisconnect

import android.app.Activity
import android.content.Intent
import android.content.pm.PackageManager
import android.net.Uri
import android.os.Build
import android.os.Bundle
import androidx.core.content.FileProvider
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.io.File

private const val PACKAGE_INSTAGRAM = "com.instagram.android"
private const val PACKAGE_FACEBOOK = "com.facebook.katana"

class MainActivity : FlutterActivity() {

    companion object {
        const val CHANNEL = "com.brisconnect/social_story"
        const val FACEBOOK_APP_ID = "822209667547948"
        private const val REQUEST_SHARE_TO_STORY = 9001
    }

    private var pendingStoryResult: MethodChannel.Result? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "shareToInstagramStory" -> shareToInstagramStory(call, result)
                    "shareToFacebookStory" -> shareToFacebookStory(call, result)
                    else -> result.notImplemented()
                }
            }
    }

    private fun shareToInstagramStory(call: MethodCall, result: MethodChannel.Result) {
        val imageData = call.argument<ByteArray>("imageData")
        val link = call.argument<String>("link") ?: ""
        if (imageData == null) {
            result.error("INVALID_ARGUMENT", "imageData required", null)
            return
        }

        if (!isPackageInstalled(PACKAGE_INSTAGRAM)) {
            result.error("APP_NOT_INSTALLED", "Instagram is not installed", null)
            return
        }

        val mimeType = call.argument<String>("mimeType") ?: "image/png"
        val extension = when (mimeType) {
            "image/png" -> "png"
            "image/webp" -> "webp"
            "image/gif" -> "gif"
            else -> "jpg"
        }
        val file = writeTempFile(imageData, "instagram_story", extension)
        val uri = FileProvider.getUriForFile(this, "${packageName}.fileprovider", file)

        grantUriPermission(PACKAGE_INSTAGRAM, uri, Intent.FLAG_GRANT_READ_URI_PERMISSION)

        // Strategy 1: Instagram's direct story composer intent.
        val storyIntent = Intent("com.instagram.share.ADD_TO_STORY").apply {
            setDataAndType(uri, mimeType)
            putExtra("source_application", FACEBOOK_APP_ID)
            if (link.isNotEmpty()) {
                putExtra("content_url", link)
            }
            addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
        }

        if (tryStartActivityForResult(storyIntent, result)) return

        // Strategy 2: Generic ACTION_SEND targeted at Instagram.
        val sendIntent = Intent(Intent.ACTION_SEND).apply {
            type = mimeType
            putExtra(Intent.EXTRA_STREAM, uri)
            putExtra(Intent.EXTRA_TEXT, link)
            `package` = PACKAGE_INSTAGRAM
            addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
        }

        if (tryStartActivityForResult(sendIntent, result)) return

        result.success("fallback")
    }

    private fun shareToFacebookStory(call: MethodCall, result: MethodChannel.Result) {
        val imageData = call.argument<ByteArray>("imageData")
        val link = call.argument<String>("link") ?: ""
        if (imageData == null) {
            result.error("INVALID_ARGUMENT", "imageData required", null)
            return
        }

        if (!isPackageInstalled(PACKAGE_FACEBOOK)) {
            result.error("APP_NOT_INSTALLED", "Facebook is not installed", null)
            return
        }

        val mimeType = call.argument<String>("mimeType") ?: "image/png"
        val extension = when (mimeType) {
            "image/png" -> "png"
            "image/webp" -> "webp"
            "image/gif" -> "gif"
            else -> "jpg"
        }
        val file = writeTempFile(imageData, "facebook_story", extension)
        val uri = FileProvider.getUriForFile(this, "${packageName}.fileprovider", file)

        grantUriPermission(PACKAGE_FACEBOOK, uri, Intent.FLAG_GRANT_READ_URI_PERMISSION)

        // Strategy 1: Facebook's direct story composer intent.
        val storyIntent = Intent("com.facebook.stories.ADD_TO_STORY").apply {
            setDataAndType(uri, mimeType)
            putExtra("com.facebook.platform.extra.APPLICATION_ID", FACEBOOK_APP_ID)
            if (link.isNotEmpty()) {
                putExtra("content_url", link)
            }
            addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
        }

        if (tryStartActivityForResult(storyIntent, result)) return

        // Strategy 2: Generic ACTION_SEND targeted at Facebook.
        val sendIntent = Intent(Intent.ACTION_SEND).apply {
            type = mimeType
            putExtra(Intent.EXTRA_STREAM, uri)
            putExtra(Intent.EXTRA_TEXT, link)
            `package` = PACKAGE_FACEBOOK
            addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
        }

        if (tryStartActivityForResult(sendIntent, result)) return

        result.success("fallback")
    }

    private fun tryStartActivityForResult(intent: Intent, result: MethodChannel.Result): Boolean {
        return try {
            val resolved = packageManager.resolveActivity(intent, 0) != null
            if (!resolved) return false
            startActivityForResult(intent, REQUEST_SHARE_TO_STORY)
            pendingStoryResult = result
            true
        } catch (e: Exception) {
            false
        }
    }

    private fun isPackageInstalled(packageName: String): Boolean {
        return try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
                packageManager.getPackageInfo(packageName, PackageManager.PackageInfoFlags.of(0L))
            } else {
                @Suppress("DEPRECATION")
                packageManager.getPackageInfo(packageName, 0)
            }
            true
        } catch (e: PackageManager.NameNotFoundException) {
            false
        }
    }

    private fun writeTempFile(data: ByteArray, prefix: String, extension: String): File {
        val dir = File(cacheDir, "brisconnect_share").apply { mkdirs() }
        val file = File(dir, "${prefix}_${System.currentTimeMillis()}.$extension")
        file.writeBytes(data)
        return file
    }

    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)
        if (requestCode == REQUEST_SHARE_TO_STORY) {
            // Result codes from Instagram/Facebook are unreliable; treat the
            // user returning to the app as completion.
            pendingStoryResult?.success(true)
            pendingStoryResult = null
        }
    }
}
