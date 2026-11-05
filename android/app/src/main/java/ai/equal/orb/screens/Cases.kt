package ai.equal.orb.screens

import androidx.compose.ui.layout.onGloballyPositioned
import ai.equal.orb.model.AppModel
import ai.equal.orb.model.Catalog
import ai.equal.orb.model.Step
import ai.equal.orb.model.UseCase
import ai.equal.orb.ui.EQ
import ai.equal.orb.ui.OrbWithBubble
import ai.equal.orb.ui.PrimaryButton
import ai.equal.orb.ui.Txt
import ai.equal.orb.ui.dm
import ai.equal.orb.ui.hex
import ai.equal.orb.ui.pressable
import ai.equal.orb.ui.rememberTalk
import androidx.compose.animation.animateColorAsState
import androidx.compose.animation.animateContentSize
import androidx.compose.animation.core.Animatable
import androidx.compose.animation.core.CubicBezierEasing
import androidx.compose.animation.core.RepeatMode
import androidx.compose.animation.core.animateFloat
import androidx.compose.animation.core.animateFloatAsState
import androidx.compose.animation.core.infiniteRepeatable
import androidx.compose.animation.core.rememberInfiniteTransition
import androidx.compose.animation.core.tween
import androidx.compose.foundation.Canvas
import androidx.compose.foundation.Image
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxHeight
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.offset
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Check
import androidx.compose.material.icons.filled.PlayArrow
import androidx.compose.runtime.Composable
import androidx.compose.runtime.DisposableEffect
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableFloatStateOf
import androidx.compose.runtime.mutableStateListOf
import androidx.compose.runtime.mutableStateMapOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.produceState
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.blur
import androidx.compose.ui.draw.clip
import androidx.compose.ui.draw.drawWithContent
import androidx.compose.ui.draw.shadow
import androidx.compose.ui.geometry.CornerRadius
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.geometry.Size
import androidx.compose.ui.graphics.BlendMode
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.ColorFilter
import androidx.compose.ui.graphics.CompositingStrategy
import androidx.compose.ui.graphics.graphicsLayer
import androidx.compose.ui.graphics.vector.rememberVectorPainter
import androidx.compose.ui.hapticfeedback.HapticFeedbackType
import androidx.compose.ui.layout.Layout
import androidx.compose.ui.platform.LocalHapticFeedback
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.Constraints
import androidx.compose.ui.unit.dp
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.delay
import kotlinx.coroutines.launch
import kotlin.math.abs
import kotlin.math.max
import kotlin.math.min
import kotlin.math.roundToInt
import kotlin.math.sin

private enum class Phase { Picking, Curating, Curated }

/**
 * “What can I handle for you? Pick any” — ten everyday jobs as two-per-row pills.
 * Continue curates on the same screen: the unpicked pills fade away and the top three picks
 * glide up to the top, keeping their size and wrapping into rows, the orb's dots gather into a
 * spinning ring while the bubble says it's curating, then the picks turn into sample-call cards
 * and the first one starts playing.
 */
@Composable
fun CasesScreen(model: AppModel) {
    val talk = rememberTalk()
    val scope = rememberCoroutineScope()
    val player = remember { SamplePlayer(scope) }
    var phase by remember { mutableStateOf(Phase.Picking) }
    var gridGone by remember { mutableStateOf(false) }
    val top = remember { mutableStateListOf<String>() }
    var open by remember { mutableStateOf<String?>(null) }
    // Where each pill sits in the grid (px), and the move of the kept ones up to the top.
    val pillRects = remember { mutableMapOf<String, androidx.compose.ui.geometry.Rect>() }
    var gridCoords by remember { mutableStateOf<androidx.compose.ui.layout.LayoutCoordinates?>(null) }
    val rearrange = remember { androidx.compose.animation.core.Animatable(0f) }
    val gapPx = with(androidx.compose.ui.platform.LocalDensity.current) { 10.dp.toPx() }
    fun wrapTargets(): Map<String, Offset> {
        val width = gridCoords?.size?.width?.toFloat() ?: return emptyMap()
        var x = 0f; var y = 0f; var rowH = 0f
        return top.mapNotNull { id ->
            val r = pillRects[id] ?: return@mapNotNull null
            if (x > 0 && x + r.width > width) { x = 0f; y += rowH + gapPx; rowH = 0f }
            val at = Offset(x, y)
            x += r.width + gapPx; rowH = max(rowH, r.height)
            id to at
        }.toMap()
    }
    val title = Catalog.title(Catalog.Ask.Cases)
    val rows = Catalog.useCases.chunked(2)

    LaunchedEffect(Unit) { talk.intro(title) }
    DisposableEffect(Unit) { onDispose { player.stop() } }

    fun curate() = scope.launch {
        top.clear(); top.addAll(model.picks.take(3))
        phase = Phase.Curating
        talk.erase()
        talk.full = Catalog.curating
        launch { talk.type(Catalog.curating, 22) }
        // Once the others have faded, the picks glide up to the top in wrapping rows.
        delay(850)
        launch { rearrange.animateTo(1f, androidx.compose.animation.core.spring(dampingRatio = 0.84f, stiffness = 110f)) }
        delay(1750)
        gridGone = true
        delay(380)
        open = top.firstOrNull()
        phase = Phase.Curated
        launch { talk.replace(Catalog.curated) }
        delay(700)
        top.firstOrNull()?.let(Catalog::useCase)?.let { player.play(it, model.displayName) }
    }

    fun openCard(u: UseCase) {
        if (open == u.id) return
        player.stop()
        open = u.id
        scope.launch { delay(350); if (open == u.id) player.play(u, model.displayName) }
    }

    Column(Modifier.fillMaxSize()) {
        OrbWithBubble(
            talk, title, Catalog.playful(Catalog.Ask.Cases),
            modifier = Modifier.fillMaxWidth().padding(top = 10.dp, start = 24.dp, end = 24.dp),
            spinning = phase == Phase.Curating,
        )
        Box(Modifier.weight(1f).fillMaxWidth().fadeEdges(14.dp.value, 40.dp.value)) {
            Column(
                Modifier.fillMaxSize().verticalScroll(rememberScrollState())
                    .padding(horizontal = 24.dp)
                    .padding(top = if (phase == Phase.Curated) 34.dp else 14.dp, bottom = 44.dp)
            ) {
                if (phase == Phase.Curated) {
                    Column(verticalArrangement = Arrangement.spacedBy(10.dp)) {
                        top.forEachIndexed { i, id ->
                            val u = Catalog.useCase(id) ?: return@forEachIndexed
                            SampleCallCard(u, i, open == id, player, onOpen = { openCard(u) }) {
                                if (player.playing == u.id) player.stop() else player.play(u, model.displayName)
                            }
                        }
                    }
                } else {
                    val gone by animateFloatAsState(if (gridGone) 1f else 0f, tween(350), label = "grid")
                    val targets = if (rearrange.value > 0f) wrapTargets() else emptyMap()
                    Column(
                        Modifier.graphicsLayer { alpha = 1 - gone; translationY = -8 * density * gone }
                            .onGloballyPositioned { gridCoords = it },
                        verticalArrangement = Arrangement.spacedBy(10.dp),
                    ) {
                        rows.forEachIndexed { r, row ->
                            BrickRow(row.map { (it.label.length * it.label.length).toFloat() }) {
                                row.forEachIndexed { c, u ->
                                    Box(
                                        Modifier
                                            .onGloballyPositioned { coords ->
                                                val grid = gridCoords ?: return@onGloballyPositioned
                                                if (rearrange.value == 0f && coords.isAttached && grid.isAttached) {
                                                    val p = grid.localPositionOf(coords, Offset.Zero)
                                                    pillRects[u.id] = androidx.compose.ui.geometry.Rect(p, Size(coords.size.width.toFloat(), coords.size.height.toFloat()))
                                                }
                                            }
                                            .graphicsLayer {
                                                val from = pillRects[u.id]?.topLeft
                                                val to = targets[u.id]
                                                if (from != null && to != null) {
                                                    translationX = (to.x - from.x) * rearrange.value
                                                    translationY = (to.y - from.y) * rearrange.value
                                                }
                                            }
                                    ) { Pill(model, u, r * 2 + c, phase, top) }
                                }
                            }
                        }
                    }
                }
            }
        }
        val footerAlpha by animateFloatAsState(if (phase == Phase.Curating) 0f else 1f, tween(300), label = "footer")
        Box(Modifier.padding(horizontal = 24.dp, vertical = 8.dp).graphicsLayer { alpha = footerAlpha }) {
            PrimaryButton("Continue", enabled = model.picks.isNotEmpty() && phase != Phase.Curating) {
                when (phase) {
                    Phase.Picking -> curate()
                    Phase.Curated -> { player.stop(); model.go(Step.PermQ) }
                    Phase.Curating -> {}
                }
            }
        }
    }
}

/** Fades the top and bottom edges of a scrolling area. */
private fun Modifier.fadeEdges(topDp: Float, bottomDp: Float) = this
    .graphicsLayer { compositingStrategy = CompositingStrategy.Offscreen }
    .drawWithContent {
        drawContent()
        val t = topDp * density / size.height
        val b = 1 - bottomDp * density / size.height
        drawRect(
            Brush.verticalGradient(0f to Color.Transparent, t to Color.Black, b to Color.Black, 1f to Color.Transparent),
            blendMode = BlendMode.DstIn,
        )
    }

/**
 * Lays out two pills per row with widths that follow their text (weight = length²),
 * never letting either drop below 40 % of the row.
 */
@Composable
private fun BrickRow(weights: List<Float>, content: @Composable () -> Unit) {
    Layout(content) { ms, c ->
        val total = c.maxWidth
        val gap = 10.dp.roundToPx()
        val h = 64.dp.roundToPx()
        val widths = if (ms.size == 2) {
            val avail = total - gap
            val minW = (total * 0.4f).roundToInt()
            val w1 = (avail * weights[0] / (weights[0] + weights[1])).roundToInt().coerceIn(minW, avail - minW)
            listOf(w1, avail - w1)
        } else listOf(total)
        val ps = ms.mapIndexed { i, m -> m.measure(Constraints.fixed(widths[i], h)) }
        layout(total, h) {
            var x = 0
            ps.forEach { it.place(x, 0); x += it.width + gap }
        }
    }
}

@Composable
private fun Pill(model: AppModel, u: UseCase, index: Int, phase: Phase, top: List<String>) {
    val haptics = LocalHapticFeedback.current
    val on = u.id in model.picks
    val kept = u.id in top
    val fading = phase != Phase.Picking && !kept
    val fade by animateFloatAsState(if (fading) 1f else 0f, tween(450, delayMillis = if (fading) index * 35 else 0, easing = EQ.push), label = "fade")
    val keep by animateFloatAsState(if (kept && phase != Phase.Picking) 1f else 0f, tween(400, easing = CubicBezierEasing(0.34f, 1.56f, 0.64f, 1f)), label = "keep")
    val tick by animateFloatAsState(if (on) 1f else 0f, tween(300, easing = CubicBezierEasing(0.34f, 1.56f, 0.64f, 1f)), label = "tick")
    val fill by animateColorAsState(if (on) EQ.mintAlt else Color.White.copy(alpha = 0.7f), tween(200), label = "fill")
    val rim by animateColorAsState(if (on) EQ.green else Color.White.copy(alpha = 0.95f), tween(200), label = "rim")
    val shape = RoundedCornerShape(20.dp)

    Box(
        Modifier
            .fillMaxSize()
            .graphicsLayer {
                val s = 1 + 0.03f * keep - 0.1f * fade
                scaleX = s; scaleY = s
                alpha = 1 - fade
            }
            .blur((2 * fade).dp)
    ) {
        Row(
            Modifier
                .fillMaxSize()
                .pressable(enabled = phase == Phase.Picking, scale = 0.96f) {
                    if (on) model.picks.remove(u.id) else model.picks.add(u.id)
                    haptics.performHapticFeedback(HapticFeedbackType.TextHandleMove)
                }
                .border(3.dp, EQ.green.copy(alpha = 0.12f * tick), shape)
                .padding(1.5.dp)
                .shadow(if (on) 7.dp else 5.dp, shape, ambientColor = hex(0x00782D, 0.1f), spotColor = hex(if (on) 0x00782D else 0x003214, if (on) 0.16f else 0.08f))
                .background(fill, shape)
                .border(1.5.dp, rim, shape)
                .padding(horizontal = 12.dp),
            verticalAlignment = Alignment.CenterVertically,
            horizontalArrangement = Arrangement.spacedBy(7.dp, Alignment.CenterHorizontally),
        ) {
            Txt(u.emoji, dm(18f))
            Txt(u.label, dm(14.5f, FontWeight.Medium, if (on) EQ.greenText else EQ.ink, lineHeight = 18f, tracking = -0.22f), maxLines = 2)
        }
        // Tick badge on the corner.
        Box(
            Modifier
                .align(Alignment.TopEnd)
                .offset(x = 4.dp, y = (-6).dp)
                .size(20.dp)
                .graphicsLayer { scaleX = 0.4f + 0.6f * tick; scaleY = scaleX; alpha = tick.coerceIn(0f, 1f) }
                .border(2.dp, EQ.page, CircleShape)
                .padding(1.dp)
                .background(EQ.green, CircleShape),
            contentAlignment = Alignment.Center,
        ) {
            Image(rememberVectorPainter(Icons.Filled.Check), null, Modifier.size(13.dp), colorFilter = ColorFilter.tint(Color.White))
        }
    }
}

// MARK: - Sample call card

/**
 * One curated pick: header with the job and who calls; when open, a player bar whose
 * waveform fills as the pretend call plays, with a live timer.
 */
@Composable
private fun SampleCallCard(u: UseCase, index: Int, isOpen: Boolean, player: SamplePlayer, onOpen: () -> Unit, onPlay: () -> Unit) {
    val playing = player.playing == u.id
    val done = u.id in player.done
    val bars = remember(index) { List(34) { j -> 6f + (abs(sin(j * 1.7 + index)) * 18).roundToInt() } }
    val shape = RoundedCornerShape(24.dp)
    val rim by animateColorAsState(if (isOpen) EQ.green.copy(alpha = 0.35f) else Color.White, tween(350), label = "cardRim")
    val appear = remember { Animatable(0f) }
    LaunchedEffect(Unit) { delay(index * 120L); appear.animateTo(1f, tween(500, easing = EQ.push)) }

    Column(
        Modifier
            .fillMaxWidth()
            .graphicsLayer {
                alpha = appear.value
                translationY = 14 * density * (1 - appear.value)
                val s = 0.97f + 0.03f * appear.value; scaleX = s; scaleY = s
            }
            .shadow(if (isOpen) 16.dp else 10.dp, shape, ambientColor = hex(0x003214, 0.08f), spotColor = hex(if (isOpen) 0x00782D else 0x003214, if (isOpen) 0.2f else 0.1f))
            .background(
                if (isOpen) Brush.verticalGradient(0f to hex(0xF0FCEE), 0.7f to Color.White) else Brush.verticalGradient(listOf(Color.White, Color.White)),
                shape,
            )
            .border(1.5.dp, rim, shape)
            .clip(shape)
            .animateContentSize(tween(450, easing = EQ.push))
    ) {
        Row(
            Modifier.fillMaxWidth().pressable(scale = 0.99f) { onOpen() }.padding(horizontal = 14.dp, vertical = 12.dp),
            verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(12.dp),
        ) {
            Box(Modifier.size(44.dp).background(hex(Catalog.cardTints[index % 3]), RoundedCornerShape(14.dp)), contentAlignment = Alignment.Center) {
                Txt(u.emoji, dm(21f))
            }
            Txt(u.label, dm(15.5f, FontWeight.SemiBold, EQ.ink, lineHeight = 20f), Modifier.weight(1f))
            if (!isOpen) {
                Box(Modifier.size(34.dp).background(EQ.mintAlt, CircleShape), contentAlignment = Alignment.Center) {
                    Image(rememberVectorPainter(Icons.Filled.PlayArrow), "Play", Modifier.size(18.dp), colorFilter = ColorFilter.tint(EQ.greenPress))
                }
            }
        }
        if (isOpen) {
            Row(
                Modifier
                    .padding(start = 14.dp, end = 14.dp, bottom = 14.dp)
                    .fillMaxWidth()
                    .background(Color.White.copy(alpha = 0.9f), RoundedCornerShape(50))
                    .border(1.dp, EQ.green.copy(alpha = 0.12f), RoundedCornerShape(50))
                    .padding(start = 10.dp, end = 12.dp, top = 10.dp, bottom = 10.dp),
                verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(12.dp),
            ) {
                // Finished calls go back to the light play button the closed cards use.
                Box(
                    Modifier.size(40.dp).pressable(scale = 0.92f) { onPlay() }
                        .then(
                            if (done) Modifier.background(EQ.mintAlt, CircleShape)
                            else Modifier.shadow(5.dp, CircleShape, spotColor = EQ.greenPress.copy(alpha = 0.4f))
                                .background(Brush.verticalGradient(listOf(hex(0x5BDB6A), EQ.greenPress)), CircleShape)
                        ),
                    contentAlignment = Alignment.Center,
                ) {
                    when {
                        playing -> Canvas(Modifier.size(14.dp)) {   // pause
                            val w = size.width * 0.28f
                            drawRoundRect(Color.White, Offset(size.width * 0.12f, 0f), Size(w, size.height), CornerRadius(2f))
                            drawRoundRect(Color.White, Offset(size.width * 0.6f, 0f), Size(w, size.height), CornerRadius(2f))
                        }
                        done -> Image(rememberVectorPainter(Icons.Filled.PlayArrow), "Play again", Modifier.size(22.dp), colorFilter = ColorFilter.tint(EQ.greenPress))
                        else -> Image(rememberVectorPainter(Icons.Filled.PlayArrow), "Play", Modifier.size(22.dp), colorFilter = ColorFilter.tint(Color.White))
                    }
                }
                val progress = player.progress[u.id] ?: 0f
                Row(Modifier.weight(1f).height(30.dp), horizontalArrangement = Arrangement.spacedBy(2.5.dp), verticalAlignment = Alignment.CenterVertically) {
                    bars.forEachIndexed { j, h ->
                        val lit = done || j.toFloat() / bars.size < progress
                        val color by animateColorAsState(if (lit) EQ.green else EQ.ink.copy(alpha = 0.15f), tween(200), label = "bar")
                        Box(Modifier.weight(1f).height(h.dp).background(color, RoundedCornerShape(2.dp)))
                    }
                }
                val label by produceState(player.timeLabel(u.id), u.id, playing) {
                    while (true) { value = player.timeLabel(u.id); delay(250) }
                }
                Txt(label, dm(12.5f, color = EQ.ink.copy(alpha = 0.5f)))
            }
        }
    }
}

/**
 * Plays the pretend calls: words land every 170 ms with a 380 ms beat between lines;
 * progress is the share of characters spoken. One call at a time.
 */
class SamplePlayer(private val scope: CoroutineScope) {
    var playing by mutableStateOf<String?>(null)
    val progress = mutableStateMapOf<String, Float>()
    val done = mutableStateListOf<String>()
    private val started = HashMap<String, Long>()
    private val frozen = HashMap<String, Int>()
    private var token = 0

    fun play(u: UseCase, name: String) {
        val my = ++token
        playing = u.id
        done.remove(u.id)
        progress[u.id] = 0f
        started[u.id] = System.currentTimeMillis()
        frozen.remove(u.id)
        val lines = Catalog.script(u, name)
        val total = lines.sumOf { it.second.length }.toFloat()
        scope.launch {
            var spoken = 0f
            for ((_, line) in lines) {
                for (w in line.split(" ")) {
                    if (my != token) return@launch
                    spoken += w.length + 1
                    progress[u.id] = min(1f, spoken / total)
                    delay(170)
                }
                delay(380)
            }
            if (my != token) return@launch
            freeze(u.id)
            playing = null
            done.add(u.id)
            progress[u.id] = 1f
        }
    }

    fun stop() {
        token++
        playing?.let(::freeze)
        playing = null
    }

    private fun freeze(id: String) {
        started[id]?.let { frozen[id] = ((System.currentTimeMillis() - it) / 1000).toInt() }
    }

    fun timeLabel(id: String): String {
        val s = if (playing == id) started[id]?.let { ((System.currentTimeMillis() - it) / 1000).toInt() } ?: 0 else frozen[id] ?: 0
        return "0:%02d".format(s)
    }
}
