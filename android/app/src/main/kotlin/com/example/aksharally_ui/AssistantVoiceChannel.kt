package com.example.aksharally_ui

import android.content.Context
import android.os.Handler
import android.os.Looper
import android.speech.tts.TextToSpeech
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.util.Locale

/** Separate engine: assistant speech never replaces flutter_tts progress callbacks. */
class AssistantVoiceChannel(context: Context, messenger: BinaryMessenger) {
    private val channel = MethodChannel(messenger, "aksharbuddy/assistant")
    private val handler = Handler(Looper.getMainLooper())
    private var engine: TextToSpeech? = null
    private var ready = false
    private var closed = false
    private var failed = false
    private val pending = mutableListOf<Pair<MethodCall, MethodChannel.Result>>()

    init {
        channel.setMethodCallHandler { call, result ->
            if (call.method == "stop") {
                engine?.stop()
                // Cancel speech requested while initialization was still pending.
                val stale = pending.filter { it.first.method == "speak" }
                pending.removeAll(stale.toSet())
                stale.forEach { it.second.error("cancelled", "Speech cancelled", null) }
                result.success(null)
            } else if (closed || failed) {
                result.error("unavailable", "Speech engine unavailable", null)
            } else if (ready) {
                handle(call, result)
            } else {
                pending.add(call to result)
                if (engine == null) {
                    engine = TextToSpeech(context.applicationContext) { status ->
                        handler.post {
                            if (!closed) {
                                ready = status == TextToSpeech.SUCCESS
                                failed = !ready
                                val queue = pending.toList()
                                pending.clear()
                                queue.forEach { (c, r) ->
                                    if (ready) handle(c, r)
                                    else r.error("unavailable", "Install a text-to-speech engine", null)
                                }
                            }
                        }
                    }
                    handler.postDelayed({
                        if (!ready && !closed) {
                            failed = true
                            pending.forEach { it.second.error("timeout", "Speech engine did not start", null) }
                            pending.clear()
                        }
                    }, 8000)
                }
            }
        }
    }

    private fun female(name: String) = Regex("(^|[-_ ])(female|woman|woman1)([-_ ]|$)")
        .containsMatchIn(name.lowercase(Locale.ROOT))

    private fun handle(call: MethodCall, result: MethodChannel.Result) {
        try {
            val tts = engine ?: throw IllegalStateException("No speech engine")
            val language = call.argument<String>("language") ?: "en"
            val voices = tts.voices.orEmpty().filter {
                it.locale.language == language &&
                    !it.features.contains(TextToSpeech.Engine.KEY_FEATURE_NOT_INSTALLED)
            }.sortedWith(compareBy({ it.isNetworkConnectionRequired }, { !female(it.name) }, { -it.quality }, { it.name }))
            when (call.method) {
                "voices" -> result.success(voices.map { mapOf(
                    "name" to it.name, "locale" to it.locale.toLanguageTag(),
                    "female" to female(it.name), "network" to it.isNetworkConnectionRequired
                ) })
                "speak" -> {
                    val text = call.argument<String>("text").orEmpty()
                    val requested = call.argument<String>("voice")
                    val voice = voices.firstOrNull { it.name == requested }
                        ?: voices.firstOrNull { female(it.name) }
                        ?: voices.firstOrNull { it == tts.defaultVoice }
                        ?: voices.firstOrNull()
                    if (voice == null) {
                        result.error("missing_voice", "No installed voice for this language", null)
                        return
                    }
                    tts.stop()
                    tts.language = voice.locale
                    tts.voice = voice
                    tts.setPitch(1.0f)
                    tts.setSpeechRate(0.9f)
                    val status = tts.speak(text, TextToSpeech.QUEUE_FLUSH, null, "assistant-${System.nanoTime()}")
                    if (status == TextToSpeech.ERROR) result.error("speech", "Could not speak", null)
                    else result.success(mapOf("name" to voice.name, "female" to female(voice.name)))
                }
                else -> result.notImplemented()
            }
        } catch (e: Exception) { result.error("speech", e.message, null) }
    }

    fun close() {
        closed = true
        handler.removeCallbacksAndMessages(null)
        pending.forEach { it.second.error("closed", "Assistant closed", null) }
        pending.clear()
        channel.setMethodCallHandler(null)
        engine?.stop()
        engine?.shutdown()
        engine = null
    }
}
