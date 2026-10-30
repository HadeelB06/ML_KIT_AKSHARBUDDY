package com.example.aksharally_ui

import android.content.Intent
import android.speech.tts.TextToSpeech
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private var assistant: AssistantVoiceChannel? = null
    private var localPdf: LocalPdfChannel? = null
    override fun onDestroy() {
        assistant?.close()
        localPdf?.close()
        super.onDestroy()
    }
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        assistant = AssistantVoiceChannel(applicationContext, flutterEngine.dartExecutor.binaryMessenger)
        localPdf = LocalPdfChannel(applicationContext, flutterEngine.dartExecutor.binaryMessenger)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "aksharbuddy/voices")
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "settings" -> {
                        try {
                            startActivity(Intent("com.android.settings.TTS_SETTINGS"))
                            result.success(true)
                        } catch (e: Exception) { result.error("settings", "Open Android Settings > Text-to-speech", null) }
                    }
                    "offlineVoices" -> {
                        val engine = call.argument<String>("engine")
                        var probe: TextToSpeech? = null
                        probe = TextToSpeech(applicationContext, { status ->
                            runOnUiThread {
                                try {
                                    val voices = if (status == TextToSpeech.SUCCESS) probe?.voices else null
                                    result.success(voices?.filter {
                                        !it.isNetworkConnectionRequired &&
                                        !it.features.contains(TextToSpeech.Engine.KEY_FEATURE_NOT_INSTALLED)
                                    }?.map { mapOf("name" to it.name, "locale" to it.locale.toLanguageTag()) } ?: emptyList<Map<String,String>>())
                                } catch (e: Exception) { result.error("voices", e.message, null) }
                                finally { probe?.shutdown() }
                            }
                        }, engine)
                    }
                    else -> result.notImplemented()
                }
            }
    }
}
