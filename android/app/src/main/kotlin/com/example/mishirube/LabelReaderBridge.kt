package com.example.mishirube

import android.content.Context
import android.net.Uri
import com.google.mlkit.vision.common.InputImage
import com.google.mlkit.vision.text.TextRecognition
import com.google.mlkit.vision.text.chinese.ChineseTextRecognizerOptions
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.io.File

/**
 * Reads the text in a photo on the phone, for
 * lib/backend/ai/label_reader.dart. ML Kit's Chinese model is bundled
 * with the app, so it works offline and the photo never leaves the
 * device. Each line comes back with where it sat, as a fraction of the
 * photo, so Dart can put a label's rows back together.
 */
class LabelReaderBridge(private val context: Context) {
    private val recognizer by lazy {
        TextRecognition.getClient(ChineseTextRecognizerOptions.Builder().build())
    }

    fun handle(call: MethodCall, result: MethodChannel.Result) {
        if (call.method != "recognizeText") {
            result.notImplemented()
            return
        }
        val path = call.argument<String>("path")
        if (path == null) {
            result.error("badArguments", null, null)
            return
        }
        val image = try {
            // Reads the photo's orientation, so a sideways shot is read upright.
            InputImage.fromFilePath(context, Uri.fromFile(File(path)))
        } catch (error: Exception) {
            result.error("failed", error.message, null)
            return
        }
        val width = image.width.toDouble().coerceAtLeast(1.0)
        val height = image.height.toDouble().coerceAtLeast(1.0)
        recognizer.process(image)
            .addOnSuccessListener { text ->
                result.success(
                    text.textBlocks.flatMap { it.lines }.mapNotNull { line ->
                        val box = line.boundingBox ?: return@mapNotNull null
                        mapOf(
                            "text" to line.text,
                            "left" to box.left / width,
                            "top" to box.top / height,
                            "width" to box.width() / width,
                            "height" to box.height() / height,
                        )
                    }
                )
            }
            .addOnFailureListener { error -> result.error("failed", error.message, null) }
    }
}
