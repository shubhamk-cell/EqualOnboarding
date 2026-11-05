package ai.equal.orb.ui

import androidx.compose.animation.core.Animatable
import androidx.compose.animation.core.CubicBezierEasing
import androidx.compose.animation.core.Spring
import androidx.compose.animation.core.VectorConverter
import androidx.compose.animation.core.animateFloatAsState
import androidx.compose.animation.core.spring
import androidx.compose.animation.core.tween
import androidx.compose.foundation.Canvas
import androidx.compose.foundation.gestures.awaitEachGesture
import androidx.compose.foundation.gestures.awaitFirstDown
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.size
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableFloatStateOf
import androidx.compose.runtime.mutableStateListOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.setValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.geometry.Size
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.Path
import androidx.compose.ui.graphics.drawscope.DrawScope
import androidx.compose.ui.graphics.drawscope.Stroke
import androidx.compose.ui.graphics.drawscope.clipPath
import androidx.compose.ui.graphics.drawscope.rotate
import androidx.compose.ui.graphics.graphicsLayer
import androidx.compose.ui.hapticfeedback.HapticFeedbackType
import androidx.compose.ui.input.pointer.pointerInput
import androidx.compose.ui.platform.LocalHapticFeedback
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.onClick
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.dp
import kotlinx.coroutines.launch
import kotlin.math.abs
import kotlin.math.atan2
import kotlin.math.cos
import kotlin.math.hypot
import kotlin.math.min
import kotlin.math.sin
import kotlin.random.Random

enum class OrbPlay { Tap, Drag }

private class Burst(val start: Float) {
    val angles = List(9) { it / 9f * (Math.PI * 2).toFloat() + Random.nextFloat() * 0.4f }
    val distances = List(9) { 70f + Random.nextFloat() * 30f }
    val sizes = List(9) { 0.6f + Random.nextFloat() * 0.9f }
    val durations = List(9) { 0.7f + Random.nextFloat() * 0.3f }
}

private val spinEase = CubicBezierEasing(0.65f, 0f, 0.35f, 1f)

/**
 * The green orb with the Equal mark: a matte top-lit green ball (matched to the design),
 * a lime halo and a soft ground shadow.
 *
 * Idle: floats up and down on a 3.6 s loop, drifting a little sideways (on the shared clock, so
 * its bubble can float with it), with ripples spreading out every 1.4 s.
 * Tap: jelly squish, a ripple ring, nine lime sparkles and a wave through the dots.
 * Drag: stretches on a rubber band (with a little 3D tilt) and springs back on release.
 * [spinning]: the six dots gather into a ring and revolve while Equal “thinks”.
 *
 * Laid out as a [diameter] square; glow and shadow spill outside it.
 */
@Composable
fun Orb(
    modifier: Modifier = Modifier,
    diameter: Dp = 112.dp,
    spinning: Boolean = false,
    rings: Boolean = true,
    interactive: Boolean = true,
    onPlay: (OrbPlay) -> Unit = {},
) {
    val clock = rememberClock()
    val wall = rememberWallClock()
    val scope = rememberCoroutineScope()
    val haptics = LocalHapticFeedback.current
    val drag = remember { Animatable(Offset.Zero, Offset.VectorConverter) }   // banded, in dp
    var raw by remember { mutableStateOf(Offset.Zero) }                      // finger travel, in dp
    var tapAt by remember { mutableFloatStateOf(-10f) }
    val bursts = remember { mutableStateListOf<Burst>() }

    // Dots: grid ↔ ring morph, and the ring's revolution (winds back to upright when it stops).
    val morph by animateFloatAsState(if (spinning) 1f else 0f, tween(550, easing = spinEase), label = "morph")
    var spinStart by remember { mutableStateOf<Float?>(null) }
    var stopAt by remember { mutableStateOf<Float?>(null) }
    var stopAngle by remember { mutableFloatStateOf(0f) }
    LaunchedEffect(spinning) {
        val now = clock.value
        if (spinning) { spinStart = now; stopAt = null }
        else spinStart?.let { s -> stopAngle = runAngle(now - s) % 360f; spinStart = null; stopAt = now }
    }

    fun tap() {
        tapAt = clock.value
        bursts.add(Burst(clock.value))
        if (bursts.size > 4) bursts.removeAt(0)
        haptics.performHapticFeedback(HapticFeedbackType.LongPress)
        onPlay(OrbPlay.Tap)
    }

    Box(
        modifier
            .size(diameter)
            .semantics { contentDescription = "Equal AI"; onClick { tap(); true } }
            .graphicsLayer {
                val (sway, hover) = orbHover(wall.value)
                val k = diameter / 112.dp
                translationX = drag.value.x.dp.toPx() + 2.5f * k * sway * density
                translationY = drag.value.y.dp.toPx() - 11f * k * hover * density
            }
            .then(
                if (!interactive) Modifier else Modifier.pointerInput(Unit) {
                    awaitEachGesture {
                        val down = awaitFirstDown()
                        var moved = false
                        while (true) {
                            val ev = awaitPointerEvent()
                            val ch = ev.changes.firstOrNull { it.id == down.id } ?: break
                            val d = (ch.position - down.position) / density   // dp
                            if (!moved && d.getDistance() > 6f) moved = true
                            if (moved) {
                                ch.consume()
                                fun band(x: Float) = x * 0.55f / (1 + abs(x) / 220f)
                                raw = d
                                scope.launch { drag.snapTo(Offset(band(d.x), band(d.y))) }
                            }
                            if (!ch.pressed) break
                        }
                        if (moved) {
                            haptics.performHapticFeedback(HapticFeedbackType.TextHandleMove)
                            raw = Offset.Zero
                            scope.launch { drag.animateTo(Offset.Zero, spring(dampingRatio = 0.42f, stiffness = Spring.StiffnessLow)) }
                            onPlay(OrbPlay.Drag)
                        } else tap()
                    }
                }
            ),
    ) {
        // Halo, ground shadow and ripples (do not tilt with the body).
        Canvas(Modifier.fillMaxSize()) {
            val t = clock.value
            val k = size.width / (112f * density)
            val (sway, hover) = orbHover(wall.value)
            drawGlow(k)
            drawGround(k, hover, sway)
            if (rings) drawRipples(t)
        }
        // Glass body + mark: tilts toward the finger and stretches along the pull; jelly on tap.
        val stretch = min(0.14f, hypot(raw.x, raw.y) / 900f)
        val angle = Math.toDegrees(atan2(raw.y, raw.x).toDouble()).toFloat()
        Box(
            Modifier
                .fillMaxSize()
                .graphicsLayer {
                    rotationY = drag.value.x * 0.35f
                    rotationX = drag.value.y * 0.35f
                    cameraDistance = 8 * density
                    rotationZ = angle
                }
                .graphicsLayer {
                    val (jx, jy) = jelly(clock.value - tapAt)
                    scaleX = (1 + stretch) * jx
                    scaleY = (1 - stretch * 0.7f) * jy
                }
                .graphicsLayer { rotationZ = -angle },
        ) {
            Canvas(Modifier.fillMaxSize()) {
                val t = clock.value
                val k = size.width / (112f * density)
                drawBody(t, k)
                val rot = when {
                    spinStart != null -> runAngle(t - spinStart!!)
                    stopAt != null -> {
                        val p = min(1f, (t - stopAt!!) / 0.55f)
                        stopAngle + (360f - stopAngle) * (1 - (1 - p) * (1 - p) * (1 - p))
                    }
                    else -> 0f
                }
                drawDots(k, morph, rot, t - tapAt)
            }
        }
        // Tap sparkles.
        Canvas(Modifier.fillMaxSize()) {
            val t = clock.value
            val k = size.width / (112f * density)
            bursts.forEach { drawBurst(it, t, k) }
        }
    }
}

private fun runAngle(elapsed: Float) = maxOf(0f, elapsed - 0.45f) * 360f / 1.3f

/** Tap: jelly squish over 720 ms → (sx, sy). */
private fun jelly(e: Float): Pair<Float, Float> {
    if (e < 0 || e > 0.72f) return 1f to 1f
    val xs = floatArrayOf(1f, 1.14f, 0.9f, 1.05f, 1f)
    val ys = floatArrayOf(1f, 0.86f, 1.1f, 0.96f, 1f)
    val ts = floatArrayOf(0f, 0.16f, 0.32f, 0.48f, 0.72f)
    var i = 0
    while (i < 3 && e > ts[i + 1]) i++
    val f = ((e - ts[i]) / (ts[i + 1] - ts[i])).coerceIn(0f, 1f)
    val p = f * f * (3 - 2 * f)
    return (xs[i] + (xs[i + 1] - xs[i]) * p) to (ys[i] + (ys[i + 1] - ys[i]) * p)
}

private fun DrawScope.drawGlow(k: Float) {
    val r = 88f * k * density
    drawCircle(
        Brush.radialGradient(
            0f to hex(0x7AFF5B, 0.5f * 0.85f), 0.43f to hex(0x23EF68, 0.32f * 0.85f), 0.74f to hex(0x11E15A, 0f),
            center = center, radius = r,
        ),
        radius = r, center = center,
    )
}

/** Soft green shadow on the “ground”, shrinking as the orb rises (it stays put while the orb floats). */
private fun DrawScope.drawGround(k: Float, hover: Float, sway: Float) {
    val d = density
    val c = Offset(center.x - 2.5f * k * d * sway, 121f * k * d + 11f * k * d * hover)
    val w = 70f * k * d * (1 - 0.28f * hover) / 2 + 6 * d
    val h = 10f * k * d * (1 - 0.28f * hover) / 2 + 6 * d
    val a = 0.18f * (1 - 0.4f * hover)
    drawOval(
        Brush.radialGradient(listOf(hex(0x09B643, a), hex(0x09B643, 0f)), c, w),
        topLeft = Offset(c.x - w, c.y - h), size = Size(w * 2, h * 2),
    )
}

/** Three ripples, 4.2 s each, staggered by 1.4 s. */
private fun DrawScope.drawRipples(t: Float) {
    for (i in 0 until 3) {
        var p = ((t - i * 1.4f) % 4.2f) / 4.2f
        if (p < 0) p += 1
        val e = bezierEase(p, 0.2f, 0.6f, 0.3f, 1f)
        val a = if (p < 0.12f) 0.42f * (p / 0.12f) else 0.42f * (1 - (p - 0.12f) / 0.88f)
        drawCircle(Color.White.copy(alpha = 0.5f * a / 0.42f * 0.42f), radius = size.width / 2 * (1 + 0.42f * e), style = Stroke(1f * density))
    }
}

/** Matte green, lit from the top left: yellow-green → green → deep green (sampled from the design's orb). */
private fun DrawScope.drawBody(@Suppress("UNUSED_PARAMETER") t: Float, k: Float) {
    val d = density
    val r = size.width / 2
    // Drop shadow beneath the ball.
    drawCircle(
        Brush.radialGradient(listOf(hex(0x09B643, 0.28f), hex(0x09B643, 0f)), center + Offset(0f, 12f * k * d), r * 1.12f),
        radius = r * 1.12f, center = center + Offset(0f, 12f * k * d),
    )
    drawCircle(
        Brush.linearGradient(
            0f to hex(0x7BE040), 0.3f to hex(0x5AD646), 0.55f to hex(0x3ACC49), 1f to hex(0x00BD4F),
            start = Offset(size.width * 0.35f, 0f), end = Offset(size.width * 0.62f, size.height),
        ),
        radius = r,
    )
}

private val grid = listOf(Offset(10f, 10f), Offset(30f, 10f), Offset(50f, 10f), Offset(10f, 39f), Offset(30f, 39f), Offset(50f, 39f))
private val ring = List(6) { i ->
    val a = Math.toRadians(i * 60.0 - 90.0)
    Offset((30 + 23 * cos(a)).toFloat(), (24.5 + 23 * sin(a)).toFloat())
}

/** The six-dot Equal mark (60 × 49 view box, r = 10), 48 × 39 pt at the base size. */
private fun DrawScope.drawDots(k: Float, morph: Float, rotation: Float, sinceTap: Float) {
    val d = density
    val w = 48f * k * d
    val h = 39f * k * d
    val sx = w / 60f
    val sy = h / 49f
    val left = center.x - w / 2
    val top = center.y - h / 2
    val pivot = Offset(left + 30f * sx, top + 24.5f * sy)
    rotate(rotation, pivot) {
        for (i in 0 until 6) {
            val p = grid[i] + (ring[i] - grid[i]) * morph
            // Tap: a little wave through the dots.
            val delay = (i % 3) * 0.07f + (i / 3) * 0.04f
            val e = sinceTap - delay
            var hop = 0f; var hs = 1f
            if (e in 0f..0.42f) {
                val q = if (e < 0.17f) e / 0.17f else 1 - (e - 0.17f) / 0.25f
                val qq = q * q * (3 - 2 * q)
                hop = -4f * qq; hs = 1 + 0.12f * qq
            }
            val c = Offset(left + p.x * sx, top + (p.y + hop) * sy)
            val rad = 10f * sx * (1 - 0.44f * morph) * hs
            drawCircle(hex(0x093421, 0.22f), rad + 0.5f * d, c + Offset(0f, 1f * k * d))
            drawCircle(Color.White.copy(alpha = 0.92f), rad, c)
        }
    }
}

/** Ripple ring + lime sparkles for one tap. */
private fun DrawScope.drawBurst(b: Burst, t: Float, k: Float) {
    val el = t - b.start
    if (el < 0 || el > 1.1f) return
    val d = density
    val rp = min(1f, el / 0.8f)
    drawCircle(
        Color.White.copy(alpha = 0.7f * 0.8f * (1 - rp)),
        radius = size.width / 2 * (1 + 0.75f * bezierEase(rp, 0.2f, 0.7f, 0.3f, 1f)), style = Stroke(1.5f * d),
    )
    for (i in 0 until 9) {
        val p = min(1f, el / b.durations[i])
        val e = bezierEase(p, 0.15f, 0.7f, 0.3f, 1f)
        val c = center + Offset(cos(b.angles[i]) * b.distances[i] * e * k * d, sin(b.angles[i]) * b.distances[i] * e * k * d)
        val r = 4f * d * b.sizes[i] * (1 - e)
        if (r <= 0f) continue
        drawCircle(
            Brush.radialGradient(0f to Color.White.copy(alpha = 1 - p), 0.45f to hex(0xD9FF7A, 1 - p), 0.75f to hex(0xBAFF29, 0f), center = c, radius = r),
            radius = r, center = c,
        )
    }
}
