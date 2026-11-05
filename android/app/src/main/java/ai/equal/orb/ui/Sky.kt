package ai.equal.orb.ui

import android.graphics.Bitmap
import androidx.compose.foundation.Canvas
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.runtime.Composable
import androidx.compose.runtime.remember
import androidx.compose.ui.Modifier
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.geometry.Size
import androidx.compose.ui.graphics.BlendMode
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.ImageShader
import androidx.compose.ui.graphics.ShaderBrush
import androidx.compose.ui.graphics.TileMode
import androidx.compose.ui.graphics.asImageBitmap
import androidx.compose.ui.graphics.drawscope.DrawScope
import androidx.compose.ui.graphics.drawscope.rotate
import androidx.compose.ui.graphics.drawscope.scale
import kotlin.math.floor
import kotlin.random.Random

/**
 * The soft, slowly moving sky behind every onboarding screen: an off-white base, six pastel
 * blobs drifting on long alternating loops, a rotating layer of tinted glows, and fine grain.
 */
@Composable
fun Sky(modifier: Modifier = Modifier) {
    val clock = rememberClock()
    val grain = remember { grainBrush() }
    Canvas(modifier.fillMaxSize()) {
        val t = clock.value
        val d = density
        drawRect(EQ.page)

        // Rotating glow layer (inset −30 %, one turn every 28 s).
        val big = Size(size.width * 1.6f, size.height * 1.6f)
        val origin = Offset(-size.width * 0.3f, -size.height * 0.3f)
        rotate(degrees = (t % 28f) / 28f * 360f, pivot = center) {
            glow(origin, big, hex(0xBAFF29), 0.28f, 0.30f, 0.30f, 0.40f)
            glow(origin, big, hex(0x5BC8F5), 0.22f, 0.75f, 0.65f, 0.35f)
            glow(origin, big, hex(0xFFC59E), 0.30f, 0.40f, 0.85f, 0.30f)
        }

        val w = size.width / d
        val h = size.height / d
        blob(t, d, 0x3FC46E, 0.28f, 340f, 300f, -90f, -60f, 22f, false)
        blob(t, d, 0x8FD8F7, 0.26f, 300f, 260f, w + 110f - 300f, 60f, 27f, true)
        blob(t, d, 0xD4FF7A, 0.34f, 280f, 240f, 30f, 250f, 19f, false)
        blob(t, d, 0x7FDCCF, 0.20f, 360f, 260f, w + 120f - 360f, 420f, 31f, false)
        blob(t, d, 0xFFD6B8, 0.42f, 320f, 260f, -100f, h + 60f - 260f, 24f, true)
        blob(t, d, 0xC9B8FF, 0.26f, 240f, 200f, w + 40f - 240f, h - 40f - 200f, 29f, false)

        drawRect(grain, alpha = 0.12f, blendMode = BlendMode.Overlay)
    }
}

private fun DrawScope.glow(origin: Offset, big: Size, c: Color, a: Float, x: Float, y: Float, r: Float) {
    val center = Offset(origin.x + big.width * x, origin.y + big.height * y)
    drawRect(
        Brush.radialGradient(listOf(c.copy(alpha = a), c.copy(alpha = 0f)), center, big.width * r * 0.7f),
        topLeft = origin, size = big,
    )
}

/**
 * One drifting blob. Offsets follow the prototype's `fxd` keyframes:
 * 0% → (0,0)·1, 50% → (50,−40)·1.15, 100% → (−30,50)·0.95, alternating, ease-in-out.
 * Drawn as a soft-edged ellipse (equivalent to a 46 pt blur without blurring every frame).
 */
private fun DrawScope.blob(t: Float, d: Float, rgb: Long, a: Float, w: Float, h: Float, x: Float, y: Float, period: Float, reversed: Boolean) {
    val cycle = t / period
    var f = cycle - floor(cycle)
    val odd = floor(cycle).toInt() % 2 == 1
    if (odd != reversed) f = 1 - f
    fun ease(v: Float) = v * v * (3 - 2 * v)
    val (k0, k1, p) = if (f < 0.5f) Triple(floatArrayOf(0f, 0f, 1f), floatArrayOf(50f, -40f, 1.15f), ease(f / 0.5f))
    else Triple(floatArrayOf(50f, -40f, 1.15f), floatArrayOf(-30f, 50f, 0.95f), ease((f - 0.5f) / 0.5f))
    val dx = k0[0] + (k1[0] - k0[0]) * p
    val dy = k0[1] + (k1[1] - k0[1]) * p
    val s = k0[2] + (k1[2] - k0[2]) * p
    val cx = (x + w / 2 + dx) * d
    val cy = (y + h / 2 + dy) * d
    val rw = (w + 92) / 2 * d * s
    val rh = (h + 92) / 2 * d * s
    val c = hex(rgb)
    // Radial gradient in a circle, squashed into an ellipse.
    scale(scaleX = 1f, scaleY = rh / rw, pivot = Offset(cx, cy)) {
        drawCircle(
            Brush.radialGradient(
                0f to c.copy(alpha = a), 0.45f to c.copy(alpha = a * 0.85f), 1f to c.copy(alpha = 0f),
                center = Offset(cx, cy), radius = rw,
            ),
            radius = rw, center = Offset(cx, cy),
        )
    }
}

/** Fine film grain: a 160 px noise tile generated once and repeated. */
private fun grainBrush(): ShaderBrush {
    val n = 160
    val bmp = Bitmap.createBitmap(n, n, Bitmap.Config.ARGB_8888)
    val rnd = Random(7)
    for (yy in 0 until n) for (xx in 0 until n) {
        val v = rnd.nextInt(256)
        bmp.setPixel(xx, yy, android.graphics.Color.argb(255, v, v, v))
    }
    return ShaderBrush(ImageShader(bmp.asImageBitmap(), TileMode.Repeated, TileMode.Repeated))
}
