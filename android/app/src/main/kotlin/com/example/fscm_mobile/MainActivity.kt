package com.example.fscm_mobile

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import android.content.Context
import android.os.Bundle
import android.os.CancellationSignal
import android.os.ParcelFileDescriptor
import android.print.PageRange
import android.print.PrintAttributes
import android.print.PrintDocumentAdapter
import android.print.PrintManager
import android.webkit.WebView
import android.webkit.WebViewClient

class MainActivity : FlutterActivity() {
    private val printViews = mutableSetOf<WebView>()

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "fscm/label_print")
            .setMethodCallHandler { call, result ->
                if (call.method != "printHtml") {
                    result.notImplemented()
                    return@setMethodCallHandler
                }
                val html = call.argument<String>("html")
                val title = call.argument<String>("title") ?: "FSCM label"
                if (html.isNullOrBlank()) {
                    result.error("invalid_html", "Empty label document", null)
                    return@setMethodCallHandler
                }
                val view = WebView(this)
                printViews.add(view)
                view.settings.javaScriptEnabled = false
                view.webViewClient = object : WebViewClient() {
                    private var submitted = false
                    override fun onPageFinished(webView: WebView, url: String?) {
                        if (submitted) return
                        submitted = true
                        try {
                            val delegate = webView.createPrintDocumentAdapter(title)
                            val adapter = object : PrintDocumentAdapter() {
                                override fun onStart() = delegate.onStart()
                                override fun onLayout(old: PrintAttributes?, new: PrintAttributes?, signal: CancellationSignal?, callback: LayoutResultCallback?, extras: Bundle?) =
                                    delegate.onLayout(old, new, signal, callback, extras)
                                override fun onWrite(pages: Array<out PageRange>?, destination: ParcelFileDescriptor?, signal: CancellationSignal?, callback: WriteResultCallback?) =
                                    delegate.onWrite(pages, destination, signal, callback)
                                override fun onFinish() {
                                    delegate.onFinish()
                                    printViews.remove(webView)
                                    webView.destroy()
                                }
                            }
                            (getSystemService(Context.PRINT_SERVICE) as PrintManager).print(title, adapter, null)
                            result.success(null) // Dialog opened; this does not claim the paper was printed.
                        } catch (error: Exception) {
                            printViews.remove(webView)
                            webView.destroy()
                            result.error("print_failed", error.message, null)
                        }
                    }
                }
                view.loadDataWithBaseURL(null, html, "text/html", "UTF-8", null)
            }
    }

    override fun onDestroy() {
        printViews.forEach { it.destroy() }
        printViews.clear()
        super.onDestroy()
    }
}
