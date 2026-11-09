package dev.fluttermuse.flutter_muse_android

import android.os.Handler
import android.os.Looper
import io.flutter.plugin.common.EventChannel

/**
 * Single event stream from native to Dart.
 *
 * Every event is a map with an `"event"` key. High-rate data/artifact packets
 * are queued and delivered in batches (`"event": "packets"`) to keep platform
 * channel overhead low (EEG alone arrives at 256 packets/s per headband).
 * Other events flush the queue first so ordering is preserved.
 *
 * Safe to call from any thread: everything is marshalled to the main thread,
 * which is the only thread allowed to talk to an [EventChannel.EventSink].
 */
internal class EventEmitter(private val mainHandler: Handler) : EventChannel.StreamHandler {
    private var sink: EventChannel.EventSink? = null
    private val pending = ArrayList<Any?>()
    private var flushScheduled = false

    /** Batch window for data packets; `0` sends each packet immediately. */
    var batchIntervalMs: Long = 16

    private val flushRunnable = Runnable {
        flushScheduled = false
        flushPackets()
    }

    override fun onListen(arguments: Any?, events: EventChannel.EventSink) {
        sink = events
    }

    override fun onCancel(arguments: Any?) {
        sink = null
        pending.clear()
    }

    fun emit(event: Map<String, Any?>) = onMain {
        flushPackets()
        sink?.success(event)
    }

    /** Queues one encoded packet (see [Codec.encodeDataPacket]). */
    fun emitPacket(packet: List<Any?>) = onMain {
        if (sink == null) return@onMain
        pending.add(packet)
        if (batchIntervalMs <= 0) {
            flushPackets()
        } else if (!flushScheduled) {
            flushScheduled = true
            mainHandler.postDelayed(flushRunnable, batchIntervalMs)
        }
    }

    private fun flushPackets() {
        if (flushScheduled) {
            mainHandler.removeCallbacks(flushRunnable)
            flushScheduled = false
        }
        if (pending.isEmpty()) return
        val batch = ArrayList(pending)
        pending.clear()
        sink?.success(mapOf("event" to "packets", "packets" to batch))
    }

    private inline fun onMain(crossinline block: () -> Unit) {
        if (Looper.myLooper() == Looper.getMainLooper()) block() else mainHandler.post { block() }
    }
}
