package com.example.aksharally_ui

import android.content.Context
import android.graphics.Bitmap
import android.graphics.Color
import android.graphics.pdf.PdfRenderer
import android.os.Handler
import android.os.Looper
import android.os.ParcelFileDescriptor
import com.tom_roush.pdfbox.android.PDFBoxResourceLoader
import com.tom_roush.pdfbox.io.MemoryUsageSetting
import com.tom_roush.pdfbox.pdmodel.PDDocument
import com.tom_roush.pdfbox.text.PDFTextStripper
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.util.UUID
import java.util.concurrent.Executors
import kotlin.math.ceil

/** Document I/O only. OCR is exclusively the Flutter ML Kit plugin. */
class LocalPdfChannel(private val context: Context, messenger: BinaryMessenger) {
    private val queue = Executors.newSingleThreadExecutor()
    private val main = Handler(Looper.getMainLooper())
    private data class Session(val file: File, val document: PDDocument)
    private val sessions = mutableMapOf<String, Session>()
    init {
        PDFBoxResourceLoader.init(context.applicationContext)
        MethodChannel(messenger, "aksharbuddy/local_pdf").setMethodCallHandler { call, reply ->
            queue.execute {
                try {
                    val response: Any? = when (call.method) {
                        "open" -> {
                            check(sessions.size < 2) { "Close the current PDF before opening another." }
                            val file = File(requireNotNull(call.argument<String>("path")))
                            require(file.length() in 1..(20L * 1024 * 1024)) { "Choose a PDF up to 20 MB." }
                            val memory = MemoryUsageSetting.setupTempFileOnly().setTempDir(context.cacheDir)
                            val doc = PDDocument.load(file, memory)
                            if (!doc.currentAccessPermission.canExtractContent()) {
                                doc.close(); error("This PDF does not permit text extraction.")
                            }
                            val token = UUID.randomUUID().toString()
                            sessions[token] = Session(file, doc)
                            mapOf("token" to token, "pageCount" to doc.numberOfPages)
                        }
                        "page" -> {
                            val session = sessions[call.argument<String>("token")] ?: error("Reopen this PDF.")
                            val number = requireNotNull(call.argument<Int>("page"))
                            require(number in 1..session.document.numberOfPages) { "Page number is outside this PDF." }
                            val stripper = PDFTextStripper()
                            stripper.startPage = number; stripper.endPage = number
                            stripper.sortByPosition = false
                            val text = stripper.getText(session.document)
                            if (text.isNotBlank() && !text.contains('\uFFFD')) {
                                mapOf("kind" to "native", "text" to text)
                            } else {
                                val target = File(requireNotNull(call.argument<String>("target")))
                                ParcelFileDescriptor.open(session.file, ParcelFileDescriptor.MODE_READ_ONLY).use { fd ->
                                    PdfRenderer(fd).use { renderer ->
                                        renderer.openPage(number - 1).use { page ->
                                            val width = ceil(page.width * 300.0 / 72).toInt()
                                            val height = ceil(page.height * 300.0 / 72).toInt()
                                            require(width.toLong() * height <= 30_000_000) {
                                                "This page is too large for 300 DPI rendering. No resizing was applied."
                                            }
                                            val bitmap = Bitmap.createBitmap(width, height, Bitmap.Config.ARGB_8888)
                                            try {
                                                bitmap.eraseColor(Color.WHITE)
                                                page.render(bitmap, null, null, PdfRenderer.Page.RENDER_MODE_FOR_DISPLAY)
                                                target.outputStream().use { bitmap.compress(Bitmap.CompressFormat.PNG, 100, it) }
                                            } finally { bitmap.recycle() }
                                        }
                                    }
                                }
                                mapOf("kind" to "image", "path" to target.path, "dpi" to 300)
                            }
                        }
                        "close" -> { sessions.remove(call.argument<String>("token"))?.document?.close(); null }
                        else -> error("Unknown document operation")
                    }
                    main.post { reply.success(response) }
                } catch (e: OutOfMemoryError) {
                    main.post { reply.error("PDF_MEMORY", "This page exceeds available memory. No resizing was applied.", e.toString()) }
                } catch (e: Exception) {
                    main.post { reply.error("PDF_INPUT", e.message ?: "Could not read this PDF.", e.toString()) }
                }
            }
        }
    }
    fun close() {
        queue.execute { sessions.values.forEach { try { it.document.close() } catch (_: Exception) {} }; sessions.clear() }
        queue.shutdown()
    }
}
