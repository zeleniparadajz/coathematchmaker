package me.coathematchmaker.app

import android.content.ActivityNotFoundException
import android.content.Intent
import android.net.Uri
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "coathematchmaker/maps")
            .setMethodCallHandler { call, result ->
                if (call.method != "openLocation") {
                    result.notImplemented()
                    return@setMethodCallHandler
                }

                val location = call.argument<String>("location")?.trim().orEmpty()
                if (location.isEmpty()) {
                    result.success(null)
                    return@setMethodCallHandler
                }

                val encodedLocation = Uri.encode(location)
                val mapsIntent = Intent(
                    Intent.ACTION_VIEW,
                    Uri.parse("geo:0,0?q=$encodedLocation")
                ).setPackage("com.google.android.apps.maps")

                try {
                    startActivity(mapsIntent)
                } catch (_: ActivityNotFoundException) {
                    val browserIntent = Intent(
                        Intent.ACTION_VIEW,
                        Uri.parse("https://www.google.com/maps/search/?api=1&query=$encodedLocation")
                    )
                    startActivity(browserIntent)
                }

                result.success(null)
            }
    }
}
