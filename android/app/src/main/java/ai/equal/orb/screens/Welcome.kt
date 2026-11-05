package ai.equal.orb.screens

import ai.equal.orb.ui.rememberWallClock
import ai.equal.orb.ui.orbHover
import ai.equal.orb.ui.OrbSlot
import ai.equal.orb.ui.OrbFlight
import ai.equal.orb.model.AppModel
import ai.equal.orb.model.Catalog
import ai.equal.orb.model.Step
import ai.equal.orb.ui.EQ
import ai.equal.orb.ui.Orb
import ai.equal.orb.ui.TopBubble
import ai.equal.orb.ui.Txt
import ai.equal.orb.ui.bezierEase
import ai.equal.orb.ui.dm
import ai.equal.orb.ui.hex
import ai.equal.orb.ui.rememberClock
import ai.equal.orb.ui.rememberTalk
import androidx.compose.animation.core.Animatable
import androidx.compose.animation.core.CubicBezierEasing
import androidx.compose.animation.core.tween
import androidx.compose.foundation.Canvas
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.offset
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.remember
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.blur
import androidx.compose.ui.geometry.CornerRadius
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.geometry.Size
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.drawscope.rotate
import androidx.compose.ui.graphics.graphicsLayer
import androidx.compose.ui.hapticfeedback.HapticFeedbackType
import androidx.compose.ui.platform.LocalHapticFeedback
import androidx.compose.ui.unit.dp
import kotlinx.coroutines.delay
import kotlinx.coroutines.launch
import kotlin.random.Random

/**
 * Welcome moment: confetti falls, sparkles twinkle round a big orb that pops in, and the bubble
 * types the user's name. After 4.8 s the screen grows, blurs and fades into Home.
 */
@Composable
fun WelcomeScreen(model: AppModel) {
    val talk = rememberTalk()
    val title = Catalog.title(Catalog.Ask.Welcome, model.displayName)
    val popped = remember { Animatable(0f) }
    val bye = remember { Animatable(0f) }
    val haptics = LocalHapticFeedback.current

    LaunchedEffect(Unit) {
        talk.intro(title)
        OrbFlight.untilLanded()   // the shared orb glides in and grows big
        launch { popped.animateTo(1f, tween(600, easing = EQ.ease)) }
        haptics.performHapticFeedback(HapticFeedbackType.LongPress)
        delay(4800)
        model.orbLeaving = true   // the orb grows, blurs and fades with the screen
        bye.animateTo(1f, tween(600, easing = EQ.push))
        delay(50)
        model.go(Step.Home)
    }

    Box(
        Modifier
            .fillMaxSize()
            .graphicsLayer { val s = 1 + 0.06f * bye.value; scaleX = s; scaleY = s; alpha = 1 - bye.value }
            .blur((8 * bye.value).dp)
    ) {
        Confetti()
        Column(
            Modifier.align(Alignment.Center).padding(horizontal = 28.dp).padding(bottom = 60.dp),
            horizontalAlignment = Alignment.CenterHorizontally,
            verticalArrangement = Arrangement.spacedBy(18.dp),
        ) {
            val clock = rememberWallClock()
            Box(Modifier.orbHover(162.dp, clock)) { TopBubble(talk, title) }
            Box(contentAlignment = Alignment.Center) {
                Box(Modifier.graphicsLayer { alpha = popped.value }) { Twinkles() }
                OrbSlot(162.dp) { talk.playful(Catalog.playful(Catalog.Ask.Welcome)) }
            }
        }
    }
}

private class Piece(val x: Float, val delay: Float, val duration: Float, val drift: Float, val spin: Float, val color: Color, val w: Float, val h: Float, val round: Boolean)

/** 46 pieces of confetti falling once, each with its own delay, drift and spin. */
@Composable
private fun Confetti() {
    val clock = rememberClock()
    val colors = listOf(0xBAFF29L, 0x8CEA35L, 0x00B140L, 0xFFFFFFL, 0xFFC59EL, 0x5BC8F5L, 0xFFE25CL)
    val pieces = remember {
        List(46) { i ->
            val round = i % 3 == 0
            Piece(
                Random.nextFloat(), Random.nextFloat() * 1.4f, 2.4f + Random.nextFloat() * 1.8f, Random.nextFloat() * 80 - 40,
                Random.nextFloat() * 720 - 360, hex(colors[i % colors.size]),
                6 + Random.nextFloat() * 6, if (round) 6 + Random.nextFloat() * 4 else 10 + Random.nextFloat() * 8, round,
            )
        }
    }
    Canvas(Modifier.fillMaxSize()) {
        val t = clock.value
        val d = density
        for (p in pieces) {
            val raw = (t - p.delay) / p.duration
            if (raw <= 0f || raw >= 1f) continue
            val e = bezierEase(raw, 0.25f, 0.6f, 0.4f, 1f)
            val a = if (raw < 0.85f) 1f else 1 - (raw - 0.85f) / 0.15f
            val c = Offset(p.x * size.width + p.drift * d * e, -24 * d + (size.height * 1.05f + 24 * d) * e)
            rotate(p.spin * e, c) {
                val sz = Size(p.w * d, p.h * d)
                val tl = Offset(c.x - sz.width / 2, c.y - sz.height / 2)
                if (p.round) drawOval(p.color.copy(alpha = a), tl, sz)
                else drawRoundRect(p.color.copy(alpha = a), tl, sz, CornerRadius(2 * d))
            }
        }
    }
}

/** Eight ✦ sparkles around the orb, each scaling, turning and fading on a 2.2 s loop. */
@Composable
private fun Twinkles() {
    val clock = rememberClock()
    val spots = listOf(
        floatArrayOf(-96f, -66f, 20f, 0f), floatArrayOf(100f, -52f, 15f, 0.3f), floatArrayOf(-112f, 34f, 13f, 0.6f),
        floatArrayOf(108f, 58f, 19f, 0.15f), floatArrayOf(-46f, -112f, 12f, 0.45f), floatArrayOf(52f, -114f, 16f, 0.75f),
        floatArrayOf(-70f, 104f, 14f, 0.9f), floatArrayOf(76f, 108f, 12f, 0.35f),
    )
    Box(Modifier.size(1.dp), contentAlignment = Alignment.Center) {
        spots.forEach { s ->
            Box(
                Modifier.offset(s[0].dp, s[1].dp).graphicsLayer {
                    val (sc, turn, a) = twinkle(clock.value - s[3])
                    scaleX = sc; scaleY = sc; rotationZ = turn; alpha = a
                }
            ) {
                Txt("✦", dm(s[2], color = Color.White).copy(shadow = androidx.compose.ui.graphics.Shadow(EQ.lime.copy(alpha = 0.8f), blurRadius = 14f)))
            }
        }
    }
}

/** Keyframes: 0/100% → scale 0, 0°, 0 · 40% → 1.15, 45°, 1 · 70% → 0.8, 90°, 0.7. */
private fun twinkle(t: Float): Triple<Float, Float, Float> {
    if (t <= 0f) return Triple(0f, 0f, 0f)
    val p = (t % 2.2f) / 2.2f
    fun mix(a: Float, b: Float, f: Float) = a + (b - a) * (f * f * (3 - 2 * f))
    return when {
        p < 0.4f -> { val f = p / 0.4f; Triple(mix(0f, 1.15f, f), mix(0f, 45f, f), mix(0f, 1f, f)) }
        p < 0.7f -> { val f = (p - 0.4f) / 0.3f; Triple(mix(1.15f, 0.8f, f), mix(45f, 90f, f), mix(1f, 0.7f, f)) }
        else -> { val f = (p - 0.7f) / 0.3f; Triple(mix(0.8f, 0f, f), mix(90f, 0f, f), mix(0.7f, 0f, f)) }
    }
}
