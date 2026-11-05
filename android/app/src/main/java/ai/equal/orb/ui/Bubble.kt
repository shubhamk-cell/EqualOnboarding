package ai.equal.orb.ui

import androidx.compose.animation.animateColorAsState
import androidx.compose.animation.core.Animatable
import androidx.compose.animation.core.tween
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableIntStateOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.produceState
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.alpha
import androidx.compose.ui.draw.drawBehind
import androidx.compose.ui.geometry.CornerRadius
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.geometry.RoundRect
import androidx.compose.ui.geometry.Size
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.Path
import androidx.compose.ui.graphics.PathOperation
import androidx.compose.ui.graphics.TransformOrigin
import androidx.compose.ui.graphics.asAndroidPath
import androidx.compose.ui.graphics.drawscope.DrawScope
import androidx.compose.ui.graphics.drawscope.drawIntoCanvas
import androidx.compose.ui.graphics.graphicsLayer
import androidx.compose.ui.graphics.nativeCanvas
import androidx.compose.ui.graphics.toArgb
import androidx.compose.ui.layout.Layout
import androidx.compose.ui.text.SpanStyle
import androidx.compose.ui.text.buildAnnotatedString
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.text.withStyle
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.dp
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Job
import kotlinx.coroutines.delay
import kotlinx.coroutines.isActive
import kotlinx.coroutines.launch
import kotlin.math.min

/**
 * What the orb is saying in its bubble. Text is typed in and erased character by character.
 * Every type/erase takes a fresh token, so a newer one silently stops an older one mid-way
 * (the playful lines can interrupt a scripted line and then hand back to it).
 */
class Talk(private val scope: CoroutineScope) {
    var text by mutableStateOf("")
    /** The line the bubble rests on; playful lines always come back to it. */
    var full by mutableStateOf("")
    var typing by mutableStateOf(false)
    /** Mint fill while Equal is being playful. */
    var alt by mutableStateOf(false)
    /** Bumps each time the bubble should pop in again. */
    var popId by mutableIntStateOf(0)

    private var token = 0
    private var lastPlayful = ""
    private var playJob: Job? = null

    /** Pops the bubble in empty (once the orb has landed), then types [line] after a short beat. */
    fun intro(line: String, delayMs: Long = 420, speed: Long = 24) {
        full = line
        text = ""
        popId++
        val my = ++token
        scope.launch {
            OrbFlight.untilLanded()
            delay(delayMs)
            if (my == token) type(line, speed)
        }
    }

    /** Types [line], replacing whatever is shown. Returns false if something newer took over. */
    suspend fun type(line: String, speed: Long = 22): Boolean {
        val my = ++token
        typing = true
        text = ""
        var i = 0
        while (i < line.length) {
            if (my != token) return false
            val cp = line.codePointAt(i)
            val n = Character.charCount(cp)
            text += line.substring(i, i + n)
            i += n
            delay(speed + if (line[i - 1] in ",.—?!") 90 else 0)
        }
        if (my != token) return false
        typing = false
        return true
    }

    suspend fun erase(speed: Long = 8): Boolean {
        val my = ++token
        typing = true
        while (text.isNotEmpty()) {
            if (my != token) return false
            val cut = text.offsetByCodePoints(text.length, -1)
            text = text.substring(0, cut)
            delay(speed)
        }
        return my == token
    }

    /** Erase, then type a new resting line. */
    suspend fun replace(line: String, speed: Long = 22) {
        full = line
        erase()
        type(line, speed)
    }

    /** Someone poked the orb: nod to it with a playful line, then steer back to the question. */
    fun playful(pool: List<String>) {
        val line = pool.filter { it != lastPlayful }.randomOrNull() ?: return
        lastPlayful = line
        playJob?.cancel()
        playJob = scope.launch {
            alt = true
            erase(8)
            if (!type(line, 20) || !isActive) return@launch
            delay(1600)
            if (!isActive || !erase(10)) return@launch
            alt = false
            type(full, 22)
        }
    }
}

@Composable
fun rememberTalk(): Talk {
    val scope = rememberCoroutineScope()
    return remember { Talk(scope) }
}

enum class Tail { Bottom, Left, TopLeft, None }

/**
 * Rounded bubble with a comic-book pointer (narrow base, sides curving slightly in, sharp tip),
 * unioned so the overlap never shows a seam.
 */
private fun bubblePath(size: Size, tail: Tail, radius: Float, d: Float): Path {
    val body = Path().apply {
        val r = min(radius, size.height / 2)
        addRoundRect(RoundRect(0f, 0f, size.width, size.height, CornerRadius(r, r)))
    }
    val t = Path()
    fun quad(ox: Float, oy: Float, vararg pts: Float) {
        // pts: start, then (control, end) pairs — all in dp from (ox, oy).
        t.moveTo(ox + pts[0] * d, oy + pts[1] * d)
        var i = 2
        while (i + 3 < pts.size) {
            t.quadraticTo(ox + pts[i] * d, oy + pts[i + 1] * d, ox + pts[i + 2] * d, oy + pts[i + 3] * d)
            i += 4
        }
        t.close()
    }
    when (tail) {
        // 24 wide at the bubble, tip 15 below it, pointing straight down at the orb.
        Tail.Bottom -> quad(size.width / 2, size.height, -12f, -2f, -3f, 3f, 0f, 15f, 3f, 3f, 12f, -2f)
        // 18 tall at the bubble, tip 12 out to the left, pointing at the orb beside it.
        Tail.Left -> quad(0f, size.height / 2, 2f, -9f, -3f, -2f, -12f, 1f, -3f, 3f, 2f, 9f)
        // Off the top-left corner, its sharp tip out to the left near the top.
        Tail.TopLeft -> quad(0f, 0f, 8f, 8f, -2f, 10f, -14f, 4f, -4f, 13f, 6f, 26f)
        Tail.None -> {}
    }
    return Path().apply { op(body, t, PathOperation.Union) }
}

private fun DrawScope.drawBubble(tail: Tail, radius: Dp, fill: Color) {
    val path = bubblePath(size, tail, radius.toPx(), density).asAndroidPath()
    drawIntoCanvas { c ->
        val paint = android.graphics.Paint(android.graphics.Paint.ANTI_ALIAS_FLAG).apply {
            color = fill.toArgb()
            setShadowLayer(11 * density, 0f, 8 * density, hex(0x00280F, 0.13f).toArgb())
        }
        c.nativeCanvas.drawPath(path, paint)
        paint.setShadowLayer(1 * density, 0f, 0.5f * density, hex(0x001E0A, 0.10f).toArgb())
        c.nativeCanvas.drawPath(path, paint)
    }
}

/** Live typed text followed by a blinking green caret while typing. */
@Composable
private fun TypedText(talk: Talk, size: Float, lineHeight: Float, align: TextAlign, modifier: Modifier = Modifier) {
    val blink by produceState(true) { while (true) { delay(400); value = !value } }
    val s = buildAnnotatedString {
        append(talk.text)
        if (talk.typing) withStyle(SpanStyle(color = if (blink) EQ.green else Color.Transparent, fontWeight = FontWeight.Medium)) { append("|") }
    }
    Txt(s, dm(size, FontWeight.SemiBold, EQ.ink, lineHeight = lineHeight, tracking = -0.02f * size, align = align), modifier)
}

/** Re-runs the bubble's pop-in (scale .4 → 1, rising 24 dp, with overshoot) whenever [id] changes. */
@Composable
private fun BubblePop(id: Int, origin: TransformOrigin, content: @Composable () -> Unit) {
    val p = remember { Animatable(0f) }
    LaunchedEffect(id) {
        p.snapTo(0f)
        OrbFlight.untilLanded()
        p.animateTo(1f, tween(550, easing = EQ.pop))
    }
    Box(Modifier.graphicsLayer {
        val v = p.value
        scaleX = 0.4f + 0.6f * v; scaleY = scaleX
        translationY = 24 * density * (1 - v)
        alpha = v.coerceIn(0f, 1f)
        transformOrigin = origin
    }) { content() }
}

/**
 * White speech bubble that rises out of the orb, tail pointing down at it. It hugs the text as
 * it types; the layout reserves room for the full line up front so typing never shifts the page.
 */
@Composable
fun TopBubble(talk: Talk, reserve: String, fontSize: Float = 18f, lineHeight: Float = 23f, maxWidth: Dp = 300.dp) {
    val fill by animateColorAsState(if (talk.alt) EQ.mintAlt else Color.White, tween(250), label = "bubble")
    val pad = Modifier.padding(start = 20.dp, end = 20.dp, top = 14.dp, bottom = 15.dp)
    Layout(content = {
        Box(pad) { Txt(reserve, dm(fontSize, FontWeight.SemiBold, lineHeight = lineHeight, tracking = -0.02f * fontSize, align = TextAlign.Center)) }
        BubblePop(talk.popId, TransformOrigin(0.42f, 1.2f)) {
            Box(Modifier.drawBehind { drawBubble(Tail.Bottom, 22.dp, fill) }.then(pad)) {
                TypedText(talk, fontSize, lineHeight, TextAlign.Center)
            }
        }
    }) { ms, c ->
        val cc = c.copy(minWidth = 0, minHeight = 0, maxWidth = min(c.maxWidth, maxWidth.roundToPx()))
        val r = ms[0].measure(cc)
        val v = ms[1].measure(cc)
        layout(r.width, r.height) { v.place((r.width - v.width) / 2, r.height - v.height) }
    }
}

/**
 * The compact bubble beside a small orb (permissions and setup screens). The pointer comes out
 * of the middle, the top corner (first of a stack of messages), or not at all (the messages after
 * it); stacked messages hang from the top and grow down as they type. [hug] sizes it to its text.
 */
@Composable
fun SideBubble(talk: Talk, reserve: String, modifier: Modifier = Modifier, fontSize: Float = 17f, lineHeight: Float = 22f,
               padH: Dp = 16.dp, padV: Dp = 12.dp, radius: Dp = 18.dp, tail: Tail = Tail.Left, hug: Boolean = false) {
    val fill by animateColorAsState(if (talk.alt) EQ.mintAlt else Color.White, tween(250), label = "bubble")
    val pad = Modifier.padding(horizontal = padH, vertical = padV)
    val middle = tail == Tail.Left
    Box(modifier, contentAlignment = if (middle) Alignment.CenterStart else Alignment.TopStart) {
        Box(pad.alpha(0f)) { Txt(reserve, dm(fontSize, FontWeight.SemiBold, lineHeight = lineHeight, tracking = -0.02f * fontSize)) }
        BubblePop(talk.popId, TransformOrigin(-0.05f, if (middle) 0.5f else 0.1f)) {
            Box((if (hug) Modifier else Modifier.fillMaxWidth()).drawBehind { drawBubble(tail, radius, fill) }.then(pad)) {
                TypedText(talk, fontSize, lineHeight, TextAlign.Start, if (hug) Modifier else Modifier.fillMaxWidth())
            }
        }
    }
}

/** Big orb with the bubble above it (number, code, name, picks, welcome). */
@Composable
fun OrbWithBubble(
    talk: Talk, reserve: String, playful: List<String>,
    modifier: Modifier = Modifier, orbDiameter: Dp = 128.dp, spinning: Boolean = false,
) {
    val clock = rememberWallClock()
    Column(modifier, horizontalAlignment = Alignment.CenterHorizontally, verticalArrangement = Arrangement.spacedBy(18.dp)) {
        Box(Modifier.orbHover(orbDiameter, clock)) { TopBubble(talk, reserve) }
        OrbSlot(orbDiameter, spinning = spinning) { talk.playful(playful) }
    }
}

/** Small orb (56 dp) with the bubble beside it (permissions, forwarding). */
@Composable
fun OrbBesideBubble(
    talk: Talk, reserve: String, playful: List<String>, modifier: Modifier = Modifier, rings: Boolean = false,
    fontSize: Float = 17f, lineHeight: Float = 22f, padH: Dp = 16.dp, padV: Dp = 12.dp, radius: Dp = 18.dp,
) {
    val clock = rememberWallClock()
    Row(modifier, verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(14.dp)) {
        OrbSlot(56.dp, rings = rings) { talk.playful(playful) }
        SideBubble(talk, reserve, Modifier.weight(1f).orbHover(56.dp, clock), fontSize, lineHeight, padH, padV, radius)
    }
}
