package ai.equal.orb.ui

import ai.equal.orb.model.AppModel
import ai.equal.orb.model.Step
import androidx.compose.animation.core.Animatable
import androidx.compose.animation.core.Spring
import androidx.compose.animation.core.spring
import androidx.compose.animation.core.tween
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.size
import androidx.compose.runtime.Composable
import androidx.compose.runtime.CompositionLocalProvider
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.compositionLocalOf
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberUpdatedState
import androidx.compose.runtime.setValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.blur
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.graphics.graphicsLayer
import androidx.compose.ui.layout.LayoutCoordinates
import androidx.compose.ui.layout.onGloballyPositioned
import androidx.compose.ui.platform.LocalDensity
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.dp
import kotlinx.coroutines.delay
import kotlinx.coroutines.launch

/**
 * One orb for the whole flow. Each screen leaves an [OrbSlot] where its orb belongs; [OrbStage]
 * draws the single orb there, and when the step changes it glides and resizes into the new
 * screen's slot. Bubbles wait for it to land ([OrbFlight.landing]) before they pop in.
 */
object OrbFlight {
    /** When the orb settles into the current screen's slot (uptime ms). */
    @Volatile var landing = 0L

    /** Called on every step change: the orb is on its way. */
    fun departing() { landing = android.os.SystemClock.uptimeMillis() + 620 }

    fun msUntilLanded() = (landing - android.os.SystemClock.uptimeMillis()).coerceAtLeast(0)

    suspend fun untilLanded() { delay(msUntilLanded()) }
}

/** Where the current screen wants the orb (px, in its screen's coordinates), and how. */
data class OrbSpot(val center: Offset, val diameter: Float, val spinning: Boolean, val rings: Boolean)

/** The step a screen was built for, and that screen's root. A leaving screen keeps its old step. */
class ScreenFrame(val step: Step) { var root: LayoutCoordinates? = null }

val LocalScreenFrame = compositionLocalOf<ScreenFrame?> { null }
val LocalAppModel = compositionLocalOf<AppModel?> { null }

/** Wraps one flow screen: gives its slots a frame to measure against, unaffected by the slide-in. */
@Composable
fun FlowScreen(model: AppModel, step: Step, content: @Composable () -> Unit) {
    val frame = remember(step) { ScreenFrame(step) }
    CompositionLocalProvider(LocalScreenFrame provides frame, LocalAppModel provides model) {
        Box(Modifier.fillMaxSize().onGloballyPositioned { frame.root = it }) { content() }
    }
}

/** An empty space the size of the orb, which tells the stage where it is. */
@Composable
fun OrbSlot(diameter: Dp, spinning: Boolean = false, rings: Boolean = true, onPlay: (OrbPlay) -> Unit = {}) {
    val model = LocalAppModel.current ?: return
    val frame = LocalScreenFrame.current
    val play by rememberUpdatedState(onPlay)
    var center by remember { mutableStateOf<Offset?>(null) }
    val px = with(LocalDensity.current) { diameter.toPx() }

    fun report() {
        val c = center ?: return
        if (frame == null || frame.step != model.step) return
        model.orbOnPlay = { play(it) }
        model.place(OrbSpot(c, px, spinning, rings))
    }
    LaunchedEffect(spinning) { report() }
    Spacer(
        Modifier
            .size(diameter)
            .onGloballyPositioned { coords ->
                val root = frame?.root ?: return@onGloballyPositioned
                if (!root.isAttached || !coords.isAttached) return@onGloballyPositioned
                // Position within the screen itself, so the screen's slide-in doesn't drag the orb along.
                val c = root.localPositionOf(coords, Offset(coords.size.width / 2f, coords.size.height / 2f))
                if (c != center) { center = c; report() }
            }
    )
}

/** Draws the flow's one orb at the current spot, gliding between spots. */
@Composable
fun OrbStage(model: AppModel) {
    val spot = model.orbSpot ?: return
    val density = LocalDensity.current
    val x = remember { Animatable(spot.center.x) }
    val y = remember { Animatable(spot.center.y) }
    val d = remember { Animatable(spot.diameter) }
    var placed by remember { mutableStateOf(false) }
    val leaving = remember { Animatable(0f) }

    LaunchedEffect(spot) {
        val start = if (!placed) model.takeSplashStart() else null
        if (!placed && start != null) {
            // First screen after the splash: rise out of where the splash's mark was.
            x.snapTo(start.x); y.snapTo(start.y); d.snapTo(spot.diameter * 0.68f)
            placed = true
            val ease = tween<Float>(1000, easing = EQ.push)
            launch { x.animateTo(spot.center.x, ease) }
            launch { y.animateTo(spot.center.y, ease) }
            launch { d.animateTo(spot.diameter, ease) }
            return@LaunchedEffect
        }
        if (!placed) {
            x.snapTo(spot.center.x); y.snapTo(spot.center.y); d.snapTo(spot.diameter)
            placed = true
            return@LaunchedEffect
        }
        val glide = spring<Float>(dampingRatio = 0.86f, stiffness = 65f)
        launch { x.animateTo(spot.center.x, glide) }
        launch { y.animateTo(spot.center.y, glide) }
        launch { d.animateTo(spot.diameter, glide) }
    }
    LaunchedEffect(model.orbLeaving) {
        if (model.orbLeaving) leaving.animateTo(1f, tween(600, easing = EQ.push)) else leaving.snapTo(0f)
    }

    val base = 128.dp
    val basePx = with(density) { base.toPx() }
    Box(Modifier.fillMaxSize()) {
        Orb(
            Modifier
                .graphicsLayer {
                    val s = d.value / basePx
                    translationX = x.value - basePx / 2
                    translationY = y.value - basePx / 2
                    scaleX = s * (1 + 0.06f * leaving.value); scaleY = scaleX
                    alpha = 1 - leaving.value
                }
                // Only while fading out: Android's blur clips to the view, even at zero.
                .then(if (leaving.value > 0f) Modifier.blur((8 * leaving.value).dp, androidx.compose.ui.draw.BlurredEdgeTreatment.Unbounded) else Modifier),
            diameter = base, spinning = spot.spinning, rings = spot.rings,
        ) { model.orbOnPlay?.invoke(it) }
    }
}

/** Floats a view in step with the orb's idle hover, so a bubble rides with the orb it belongs to. */
fun Modifier.orbHover(diameter: Dp, clock: androidx.compose.runtime.State<Float>): Modifier = graphicsLayer {
    val (sway, hover) = orbHover(clock.value)
    val k = diameter.value / 112f
    translationX = 2.5f * k * sway * density
    translationY = -11f * k * hover * density
}
