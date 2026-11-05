@file:OptIn(ExperimentalTextApi::class)

package ai.equal.orb.ui

import ai.equal.orb.R
import androidx.compose.animation.core.Animatable
import androidx.compose.animation.core.CubicBezierEasing
import androidx.compose.animation.core.Easing
import androidx.compose.animation.core.animateFloatAsState
import androidx.compose.animation.core.tween
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.interaction.MutableInteractionSource
import androidx.compose.foundation.interaction.collectIsPressedAsState
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.KeyboardArrowLeft
import androidx.compose.foundation.Image
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableFloatStateOf
import androidx.compose.runtime.remember
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.composed
import androidx.compose.ui.draw.shadow
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.ColorFilter
import androidx.compose.ui.graphics.Shape
import androidx.compose.ui.graphics.graphicsLayer
import androidx.compose.ui.graphics.vector.rememberVectorPainter
import androidx.compose.ui.platform.LocalDensity
import androidx.compose.ui.res.painterResource
import androidx.compose.ui.text.AnnotatedString
import androidx.compose.ui.text.ExperimentalTextApi
import androidx.compose.ui.text.PlatformTextStyle
import androidx.compose.ui.text.SpanStyle
import androidx.compose.ui.text.TextStyle
import androidx.compose.ui.text.buildAnnotatedString
import androidx.compose.ui.text.font.Font
import androidx.compose.ui.text.font.FontFamily
import androidx.compose.ui.text.font.FontStyle
import androidx.compose.ui.text.font.FontVariation
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.LineHeightStyle
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.text.withStyle
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.TextUnit
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import kotlinx.coroutines.delay

/** Equal AI brand tokens for the orb-bubble onboarding. */
object EQ {
    val green = Color(0xFF00B140)
    val greenDeep = Color(0xFF00843A)
    val greenText = Color(0xFF00602A)
    val greenPress = Color(0xFF00A33B)
    val lime = Color(0xFFBAFF29)
    val voiceTop = Color(0xFF8CEA35)
    val mint = Color(0xFFE8FFED)
    val mintAlt = Color(0xFFE9FCEC)
    val ink = Color(0xFF0B1F12)
    val page = Color(0xFFF7F7F7)
    val secondary = Color(0xFF555555)
    val placeholder = Color(0xFFAAAAAA)
    val hair = Color.Black.copy(alpha = 0.08f)

    /** The push curve every screen change uses: cubic-bezier(.32,.72,0,1). */
    val push: Easing = CubicBezierEasing(0.32f, 0.72f, 0f, 1f)
    /** The house ease: cubic-bezier(.2,0,0,1). */
    val ease: Easing = CubicBezierEasing(0.2f, 0f, 0f, 1f)
    /** Overshooting pop used by the speech bubble: cubic-bezier(.32,1.25,.5,1). */
    val pop: Easing = CubicBezierEasing(0.32f, 1.25f, 0.5f, 1f)
}

fun hex(rgb: Long, alpha: Float = 1f) = Color(0xFF000000 or rgb).copy(alpha = alpha)

// MARK: - Type

private val families = HashMap<String, FontFamily>()

/** DM Sans (variable). Optical size follows the point size, as browsers do, so letterforms match the prototype. */
fun dmFamily(size: Float, weight: FontWeight): FontFamily = families.getOrPut("$size-${weight.weight}") {
    FontFamily(
        Font(
            R.font.dm_sans,
            weight = weight,
            style = FontStyle.Normal,
            variationSettings = FontVariation.Settings(
                FontVariation.weight(weight.weight),
                FontVariation.Setting("opsz", size.coerceIn(9f, 40f)),
            ),
        )
    )
}

fun dm(
    size: Float,
    weight: FontWeight = FontWeight.Normal,
    color: Color = Color.Unspecified,
    lineHeight: Float? = null,
    tracking: Float = 0f,
    align: TextAlign = TextAlign.Unspecified,
) = TextStyle(
    fontFamily = dmFamily(size, weight),
    fontWeight = weight,
    fontSize = size.sp,
    color = color,
    lineHeight = lineHeight?.sp ?: TextUnit.Unspecified,
    letterSpacing = tracking.sp,
    textAlign = align,
    platformStyle = PlatformTextStyle(includeFontPadding = false),
    lineHeightStyle = LineHeightStyle(LineHeightStyle.Alignment.Center, LineHeightStyle.Trim.None),
)

/** `**bold**` runs set in a heavier DM Sans weight; everything else in the base weight. */
fun rich(s: String, size: Float, weight: FontWeight = FontWeight.Normal, bold: FontWeight = FontWeight.SemiBold): AnnotatedString =
    buildAnnotatedString {
        s.split("**").forEachIndexed { i, part ->
            val w = if (i % 2 == 1) bold else weight
            withStyle(SpanStyle(fontFamily = dmFamily(size, w), fontWeight = w)) { append(part) }
        }
    }

@Composable
fun Txt(text: String, style: TextStyle, modifier: Modifier = Modifier, maxLines: Int = Int.MAX_VALUE) =
    androidx.compose.foundation.text.BasicText(text, modifier, style, maxLines = maxLines)

@Composable
fun Txt(text: AnnotatedString, style: TextStyle, modifier: Modifier = Modifier, maxLines: Int = Int.MAX_VALUE) =
    androidx.compose.foundation.text.BasicText(text, modifier, style, maxLines = maxLines)

// MARK: - Surfaces & press feedback

/** Frosted-looking surface for fields, chips and small buttons. */
fun Modifier.glass(shape: Shape, tint: Float = 0.55f, stroke: Color = Color.White.copy(alpha = 0.75f), shadow: Boolean = true) =
    this
        .then(if (shadow) Modifier.shadow(8.dp, shape, ambientColor = hex(0x003214, 0.10f), spotColor = hex(0x003214, 0.10f)) else Modifier)
        .background(Color.White.copy(alpha = tint), shape)
        .border(1.dp, stroke, shape)

/** Tap target with a gentle press-scale and no ripple. */
fun Modifier.pressable(enabled: Boolean = true, scale: Float = 0.97f, onClick: () -> Unit): Modifier = composed {
    val source = remember { MutableInteractionSource() }
    val pressed by source.collectIsPressedAsState()
    val s by animateFloatAsState(if (pressed && enabled) scale else 1f, tween(150), label = "press")
    this
        .graphicsLayer { scaleX = s; scaleY = s }
        .clickable(interactionSource = source, indication = null, enabled = enabled, onClick = onClick)
}

/** Rises in from below with a fade, after a delay (content arriving from the splash). */
fun Modifier.riseIn(active: Boolean, delayMs: Int, distance: Dp = 26.dp, durationMs: Int = 700): Modifier = composed {
    val p = remember { Animatable(if (active) 0f else 1f) }
    LaunchedEffect(active) {
        if (active) {
            delay(delayMs.toLong())
            p.animateTo(1f, tween(durationMs, easing = EQ.push))
        } else p.snapTo(1f)
    }
    val px = with(LocalDensity.current) { distance.toPx() }
    graphicsLayer { alpha = p.value.coerceIn(0f, 1f); translationY = px * (1 - p.value) }
}

/** Big green pill (60dp). Disabled: washed-out green, no shadow. */
@Composable
fun PrimaryButton(text: String, enabled: Boolean = true, lookEnabled: Boolean = false, modifier: Modifier = Modifier, onClick: () -> Unit) {
    val on = enabled || lookEnabled
    val shape = RoundedCornerShape(50)
    Box(
        modifier
            .fillMaxWidth()
            .height(60.dp)
            .pressable(enabled) { onClick() }
            .then(if (on) Modifier.shadow(12.dp, shape, ambientColor = hex(0x00782D, 0.3f), spotColor = hex(0x00782D, 0.45f)) else Modifier)
            .background(if (on) EQ.green else EQ.green.copy(alpha = 0.38f), shape),
        contentAlignment = Alignment.Center,
    ) {
        Txt(text, dm(18f, FontWeight.SemiBold, Color.White.copy(alpha = if (on) 1f else 0.75f), tracking = -0.18f))
    }
}

/** Low-key text link (“I’ll do this later”). */
@Composable
fun LinkButton(text: String, color: Color = EQ.ink.copy(alpha = 0.65f), size: Float = 15f, weight: FontWeight = FontWeight.Medium, onClick: () -> Unit) {
    Box(Modifier.pressable(scale = 0.96f) { onClick() }.padding(horizontal = 12.dp, vertical = 7.dp)) {
        Txt(text, dm(size, weight, color))
    }
}

/** 48dp frosted circle with a chevron (back). */
@Composable
fun BackButton(onClick: () -> Unit) {
    Box(
        Modifier.size(48.dp).pressable { onClick() }.glass(CircleShape, tint = 0.28f, stroke = Color.White.copy(alpha = 0.45f)),
        contentAlignment = Alignment.Center,
    ) {
        Image(rememberVectorPainter(Icons.Filled.KeyboardArrowLeft), "Back", Modifier.size(30.dp), colorFilter = ColorFilter.tint(EQ.ink))
    }
}

/** Frosted “Skip” capsule. */
@Composable
fun SkipButton(onClick: () -> Unit) {
    Box(
        Modifier.height(36.dp).pressable(scale = 0.96f) { onClick() }
            .glass(RoundedCornerShape(50), tint = 0.42f, stroke = Color.White.copy(alpha = 0.6f), shadow = false)
            .padding(horizontal = 14.dp),
        contentAlignment = Alignment.Center,
    ) { Txt("Skip", dm(15f, FontWeight.SemiBold, EQ.ink.copy(alpha = 0.7f))) }
}

/** The green wordmark (template image tinted). */
@Composable
fun Wordmark(height: Dp = 24.dp, color: Color = EQ.green, modifier: Modifier = Modifier) {
    Image(
        painterResource(R.drawable.wordmark), "equal ai",
        modifier.size(width = height * (480f / 101f), height = height),
        colorFilter = ColorFilter.tint(color),
    )
}

/** CSS `cubic-bezier(x1,y1,x2,y2)` evaluated at progress `x`. */
fun bezierEase(x: Float, x1: Float, y1: Float, x2: Float, y2: Float): Float {
    if (x <= 0f) return 0f
    if (x >= 1f) return 1f
    fun bx(t: Float) = 3 * (1 - t) * (1 - t) * t * x1 + 3 * (1 - t) * t * t * x2 + t * t * t
    fun by(t: Float) = 3 * (1 - t) * (1 - t) * t * y1 + 3 * (1 - t) * t * t * y2 + t * t * t
    fun dx(t: Float) = 3 * (1 - t) * (1 - t) * x1 + 6 * (1 - t) * t * (x2 - x1) + 3 * t * t * (1 - x2)
    var t = x
    repeat(6) {
        val d = dx(t)
        if (kotlin.math.abs(d) < 1e-6f) return@repeat
        t = (t - (bx(t) - x) / d).coerceIn(0f, 1f)
    }
    return by(t)
}

/** Seconds since this composable entered the composition, ticking every frame. */
/**
 * Seconds on a clock shared by every caller (frame time, wrapped hourly), so separate views can
 * move in step — the orb's hover and the bubbles that float with it.
 */
@Composable
fun rememberWallClock(): androidx.compose.runtime.State<Float> {
    val t = remember { mutableFloatStateOf(0f) }
    LaunchedEffect(Unit) {
        while (true) androidx.compose.runtime.withFrameNanos { t.floatValue = (it / 1_000_000L % 3_600_000L) / 1000f }
    }
    return t
}

/** The orb's idle float at time [t]: (sideways sway −1…1, rise 0…1). */
fun orbHover(t: Float): Pair<Float, Float> =
    kotlin.math.sin(2 * Math.PI * t / 7.2).toFloat() to (1 - kotlin.math.cos(2 * Math.PI * t / 3.6)).toFloat() / 2

@Composable
fun rememberClock(): androidx.compose.runtime.State<Float> {
    val t = remember { mutableFloatStateOf(0f) }
    LaunchedEffect(Unit) {
        val start = androidx.compose.runtime.withFrameNanos { it }
        while (true) androidx.compose.runtime.withFrameNanos { t.floatValue = (it - start) / 1e9f }
    }
    return t
}
