package ai.equal.orb.screens

import androidx.compose.ui.graphics.nativeCanvas
import androidx.compose.ui.graphics.drawscope.drawIntoCanvas
import ai.equal.orb.R
import ai.equal.orb.model.AppModel
import ai.equal.orb.model.Step
import ai.equal.orb.ui.EQ
import ai.equal.orb.ui.Txt
import ai.equal.orb.ui.bezierEase
import ai.equal.orb.ui.dm
import ai.equal.orb.ui.hex
import ai.equal.orb.ui.rememberClock
import androidx.compose.foundation.Canvas
import androidx.compose.foundation.Image
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.interaction.MutableInteractionSource
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.navigationBarsPadding
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.drawWithContent
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.geometry.Rect
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.ColorFilter
import androidx.compose.ui.graphics.drawscope.clipRect
import androidx.compose.ui.graphics.drawscope.rotate
import androidx.compose.ui.graphics.graphicsLayer
import androidx.compose.ui.layout.boundsInRoot
import androidx.compose.ui.layout.onGloballyPositioned
import androidx.compose.ui.platform.LocalDensity
import androidx.compose.ui.res.painterResource
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import kotlinx.coroutines.delay

// Dot i starts on a ring of radius 34 and ends on the mark's grid.
private val radial = listOf(Offset(0f, -34f), Offset(29.4f, -17f), Offset(29.4f, 17f), Offset(0f, 34f), Offset(-29.4f, 17f), Offset(-29.4f, -17f))
private val gridPts = listOf(Offset(0f, -13.3f), Offset(16.8f, -13.3f), Offset(16.8f, 13.3f), Offset(0f, 13.3f), Offset(-16.8f, 13.3f), Offset(-16.8f, -13.3f))

/** Wordmark is 480 × 101; at 44 dp tall it is 209.1 dp wide and its mark sits 25.5 dp in. */
private const val LOCK_W = 209.1f
private const val LOCK_H = 44f
private const val MARK_X = 25.5f

private fun slideAt(t: Float) = 79f * (1 - bezierEase((t - 1.85f) / 0.8f, 0.65f, 0f, 0.35f, 1f))

/**
 * Full-green splash. Six dots pop in on a spinning ring, settle into the Equal mark, the lockup
 * slides left as the wordmark wipes in, then the tagline and “made in India” rise.
 * Leaves after 3.8 s (or on tap) — the mark becomes the orb on the first question.
 */
@Composable
fun SplashScreen(model: AppModel) {
    val clock = rememberClock()
    var lockRect by remember { mutableStateOf(Rect.Zero) }
    val density = LocalDensity.current.density

    fun leave() {
        if (model.step != Step.Splash) return
        val t = clock.value
        model.splashMark = Offset(lockRect.left + (MARK_X + slideAt(t)) * density, lockRect.center.y)
        model.arrivingFromSplash = true
        model.direction = 1
        model.step = Step.Phone
    }

    LaunchedEffect(Unit) {
        delay(3800)
        leave()
    }

    Box(
        Modifier
            .fillMaxSize()
            .clickable(remember { MutableInteractionSource() }, indication = null) { leave() }
            .semantics { contentDescription = "Equal AI. India’s No. 1 AI Call Assistant." },
    ) {
        // Background: lime → green diagonal with a soft white highlight.
        val res = androidx.compose.ui.platform.LocalContext.current.resources
        val pattern = remember {
            // The pattern is drawn at 3× (392 × 446 pt); scale it to this screen's density.
            val bmp = android.graphics.BitmapFactory.decodeResource(res, ai.equal.orb.R.drawable.splash_pattern,
                android.graphics.BitmapFactory.Options().apply { inScaled = false })
            android.graphics.Paint(android.graphics.Paint.ANTI_ALIAS_FLAG or android.graphics.Paint.FILTER_BITMAP_FLAG).apply {
                shader = android.graphics.BitmapShader(bmp, android.graphics.Shader.TileMode.REPEAT, android.graphics.Shader.TileMode.REPEAT).apply {
                    setLocalMatrix(android.graphics.Matrix().apply { val k = res.displayMetrics.density / 3f; setScale(k, k) })
                }
                alpha = (0.16f * 255).toInt()
            }
        }
        Canvas(Modifier.fillMaxSize()) {
            drawRect(
                Brush.linearGradient(
                    0f to hex(0xBFFF3A), 0.45f to hex(0x4ADB45), 1f to EQ.green,
                    start = Offset(size.width * 0.32f, 0f), end = Offset(size.width * 0.68f, size.height),
                )
            )
            drawRect(
                Brush.radialGradient(
                    listOf(Color.White.copy(alpha = 0.22f), Color.White.copy(alpha = 0f)),
                    center = Offset(size.width * 0.3f, size.height * 0.2f), radius = size.width * 0.7f,
                )
            )
            // Subtle doodle texture from the Figma splash (BG pattern 5), tiled in white at 16 %.
            drawIntoCanvas { c ->
                c.nativeCanvas.drawRect(0f, 0f, size.width, size.height, pattern)
            }
        }

        Column(
            Modifier.align(Alignment.Center),
            horizontalAlignment = Alignment.CenterHorizontally,
            verticalArrangement = Arrangement.spacedBy(16.dp),
        ) {
            // Lockup: mark (the six dots) + wordmark wiping in.
            Box(
                Modifier
                    .size(LOCK_W.dp, LOCK_H.dp)
                    .onGloballyPositioned { lockRect = it.boundsInRoot() }
                    .graphicsLayer { translationX = slideAt(clock.value) * this.density }
            ) {
                Image(
                    painterResource(R.drawable.wordmark), null,
                    Modifier
                        .size(LOCK_W.dp, LOCK_H.dp)
                        .drawWithContent {
                            val wipe = bezierEase((clock.value - 1.9f) / 0.8f, 0.65f, 0f, 0.35f, 1f)
                            // The mark part (left 30 %) stays hidden — the dots stand in for it.
                            clipRect(left = size.width * 0.3f, right = size.width * (0.3f + 0.7f * wipe)) {
                                this@drawWithContent.drawContent()
                            }
                        }
                        .graphicsLayer { alpha = bezierEase((clock.value - 1.9f) / 0.8f, 0.65f, 0f, 0.35f, 1f) },
                    colorFilter = ColorFilter.tint(Color.White),
                )
                Canvas(Modifier.size(LOCK_W.dp, LOCK_H.dp)) {
                    val t = clock.value
                    val d = this.density
                    val c = Offset(MARK_X * d, LOCK_H / 2 * d)
                    val spin = 360f * bezierEase(t / 1.8f, 0.65f, 0f, 0.35f, 1f)
                    val form = bezierEase((t - 0.8f) / 1.0f, 0.65f, 0f, 0.35f, 1f)
                    rotate(spin, c) {
                        for (i in 0 until 6) {
                            val pin = bezierEase((t - i * 0.06f) / 0.45f, 0.22f, 1f, 0.36f, 1f)
                            if (pin <= 0f) continue
                            val p = radial[i] + (gridPts[i] - radial[i]) * form
                            val center = c + p * d
                            val r = 8.7f * d * pin
                            if (form < 1f) drawCircle(
                                Brush.radialGradient(listOf(Color.White.copy(alpha = 0.6f * (1 - form) * pin), Color.Transparent), center, r * 2.2f),
                                r * 2.2f, center,
                            )
                            drawCircle(Color.White.copy(alpha = pin.coerceIn(0f, 1f)), r, center)
                        }
                    }
                }
            }
            // Tagline with laurels.
            Row(
                Modifier
                    .introUp(clock.value, 2.45f)
                    .background(Color.White.copy(alpha = 0.18f), RoundedCornerShape(16.dp))
                    .border(1.dp, Color.White.copy(alpha = 0.3f), RoundedCornerShape(16.dp))
                    .padding(horizontal = 18.dp, vertical = 10.dp),
                verticalAlignment = Alignment.CenterVertically,
                horizontalArrangement = Arrangement.spacedBy(12.dp),
            ) {
                Image(painterResource(R.drawable.laurel_left), null, Modifier.size(24.dp, 48.dp))
                Txt("India’s No. 1\nAI Call Assistant", dm(15f, FontWeight.SemiBold, Color.White, lineHeight = 20f, align = TextAlign.Center))
                Image(painterResource(R.drawable.laurel_right), null, Modifier.size(24.dp, 48.dp))
            }
        }

        Box(
            Modifier
                .align(Alignment.BottomCenter)
                .navigationBarsPadding()
                .padding(bottom = 22.dp)
                .introUp(clock.value, 2.65f)
                .background(Color.White.copy(alpha = 0.18f), RoundedCornerShape(50))
                .border(1.dp, Color.White.copy(alpha = 0.3f), RoundedCornerShape(50))
                .padding(horizontal = 14.dp, vertical = 6.dp)
        ) { Txt("🇮🇳 Proudly made in India", dm(12f, FontWeight.Medium, Color.White)) }
    }
}

private fun Modifier.introUp(t: Float, at: Float) = graphicsLayer {
    val p = bezierEase((t - at) / 0.5f, 0.2f, 0.8f, 0.2f, 1f)
    alpha = p
    translationY = 12 * density * (1 - p)
}
