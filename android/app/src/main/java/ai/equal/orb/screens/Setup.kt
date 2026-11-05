package ai.equal.orb.screens

import androidx.compose.ui.draw.alpha
import ai.equal.orb.ui.rememberWallClock
import ai.equal.orb.ui.orbHover
import ai.equal.orb.ui.Tail
import ai.equal.orb.ui.SideBubble
import ai.equal.orb.ui.OrbSlot
import ai.equal.orb.ui.OrbFlight
import ai.equal.orb.model.Permission
import ai.equal.orb.R
import ai.equal.orb.model.AppModel
import ai.equal.orb.model.Catalog
import ai.equal.orb.model.Overlay
import ai.equal.orb.ui.EQ
import ai.equal.orb.ui.OrbBesideBubble
import ai.equal.orb.ui.PrimaryButton
import ai.equal.orb.ui.Txt
import ai.equal.orb.ui.dm
import ai.equal.orb.ui.rememberTalk
import ai.equal.orb.ui.rich
import android.Manifest
import android.content.pm.PackageManager
import android.os.Build
import androidx.activity.compose.rememberLauncherForActivityResult
import androidx.activity.result.contract.ActivityResultContracts
import androidx.compose.animation.core.Animatable
import androidx.compose.animation.core.CubicBezierEasing
import androidx.compose.animation.core.animateFloatAsState
import androidx.compose.animation.core.tween
import androidx.compose.foundation.Image
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.BoxWithConstraints
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Check
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.rememberUpdatedState
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.drawWithContent
import androidx.compose.ui.graphics.BlendMode
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.ColorFilter
import androidx.compose.ui.graphics.CompositingStrategy
import androidx.compose.ui.graphics.graphicsLayer
import androidx.compose.ui.graphics.vector.rememberVectorPainter
import androidx.compose.ui.hapticfeedback.HapticFeedbackType
import androidx.compose.ui.layout.ContentScale
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.platform.LocalHapticFeedback
import androidx.compose.ui.res.painterResource
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.dp
import androidx.core.app.NotificationManagerCompat
import androidx.core.content.ContextCompat
import com.airbnb.lottie.compose.LottieAnimation
import com.airbnb.lottie.compose.LottieCompositionSpec
import com.airbnb.lottie.compose.LottieConstants
import com.airbnb.lottie.compose.rememberLottieComposition
import kotlinx.coroutines.CompletableDeferred
import kotlinx.coroutines.delay
import kotlinx.coroutines.launch

/** Asks for one Android runtime permission and suspends until the user answers. */
@Composable
private fun rememberPermissionAsker(): suspend (String) -> Boolean {
    val context = LocalContext.current
    val pending = remember { mutableStateOf<CompletableDeferred<Boolean>?>(null) }
    val launcher = rememberLauncherForActivityResult(ActivityResultContracts.RequestPermission()) { ok ->
        pending.value?.complete(ok); pending.value = null
    }
    val launch by rememberUpdatedState(launcher)
    return remember {
        val asker: suspend (String) -> Boolean = { perm ->
            if (ContextCompat.checkSelfPermission(context, perm) == PackageManager.PERMISSION_GRANTED) true
            else {
                val d = CompletableDeferred<Boolean>()
                pending.value = d
                launch.launch(perm)
                d.await()
            }
        }
        asker
    }
}

// MARK: - Permissions

/**
 * The orb explains each permission in its own message (stacked like a chat), then the real
 * Android prompt opens — both, one after the other. Only then, if either was refused, Equal's
 * own sheet asks once for whatever is missing. Afterwards Equal asks for call-data consent (once).
 */
@Composable
fun PermissionsScreen(model: AppModel) {
    val talk = rememberTalk()
    val talk2 = rememberTalk()   // the second message, about contacts
    var secondShown by remember { mutableStateOf(false) }
    val ask = rememberPermissionAsker()
    val context = LocalContext.current
    val clock = rememberWallClock()

    LaunchedEffect(Unit) {
        talk.full = Catalog.notifLine
        talk.text = ""
        talk.popId++
        OrbFlight.untilLanded()
        delay(450)
        talk.type(Catalog.notifLine, 22)
        delay(500)

        val notifications = if (Build.VERSION.SDK_INT >= 33) ask(Manifest.permission.POST_NOTIFICATIONS)
        else NotificationManagerCompat.from(context).areNotificationsEnabled()
        delay(250)

        // The contacts question arrives as a new message under the first.
        talk2.full = Catalog.contactsLine
        talk2.text = ""
        secondShown = true
        talk2.popId++
        delay(450)
        talk2.type(Catalog.contactsLine, 22)
        delay(500)
        val contacts = ask(Manifest.permission.READ_CONTACTS)

        val missing = buildList {
            if (!notifications) add(Permission.Notifications)
            if (!contacts) add(Permission.Contacts)
        }
        val fixed = missing.isNotEmpty() && model.present(Overlay.Decline(missing)) == "settings"
        model.perms = listOf(notifications || fixed, contacts || fixed)

        model.askConsentOnce()
        if (model.step == ai.equal.orb.model.Step.PermQ) model.next()
    }

    val art = remember { Animatable(0f) }
    LaunchedEffect(Unit) { delay(200); art.animateTo(1f, tween(600, easing = EQ.push)) }

    BoxWithConstraints(Modifier.fillMaxSize()) {
        // The art takes what's left after the two messages and the (hidden) footer's room, within 160–420 dp.
        val artH = (maxHeight - 110.dp - 18.dp - 230.dp).coerceIn(160.dp, 420.dp)
        Column(
            Modifier.fillMaxSize().padding(bottom = 110.dp),   // the footer is hidden here but keeps its room
            horizontalAlignment = Alignment.CenterHorizontally,
            verticalArrangement = Arrangement.Center,
        ) {
            Box(
                Modifier
                    .fillMaxWidth()
                    .height(artH)
                    .graphicsLayer { alpha = art.value; translationY = 18 * density * (1 - art.value) }
                    .fadeBottom(0.72f),
                contentAlignment = Alignment.TopCenter,
            ) {
                Image(
                    painterResource(R.drawable.permission_art), null,
                    Modifier.width(300.dp).height(408.dp), contentScale = ContentScale.FillWidth, alignment = Alignment.TopCenter,
                )
            }
            Spacer(Modifier.height(18.dp))
            // Orb on the left; the notifications message beside it (pointer at the top), the contacts
            // message under it once it's its turn. Its room is kept from the start so nothing jumps.
            Row(Modifier.fillMaxWidth().padding(horizontal = 24.dp), horizontalArrangement = Arrangement.spacedBy(18.dp)) {
                OrbSlot(56.dp) { (if (secondShown) talk2 else talk).playful(Catalog.playful(Catalog.Ask.PermQ)) }
                Column(Modifier.weight(1f), verticalArrangement = Arrangement.spacedBy(10.dp)) {
                    SideBubble(talk, Catalog.notifLine, Modifier.orbHover(56.dp, clock), 18f, 24f, 18.dp, 14.dp, 20.dp, Tail.TopLeft, hug = true)
                    SideBubble(talk2, Catalog.contactsLine, Modifier.orbHover(56.dp, clock).alpha(if (secondShown) 1f else 0f),
                        18f, 24f, 18.dp, 14.dp, 20.dp, Tail.None, hug = true)
                }
            }
        }
    }
}

// MARK: - Call forwarding over USSD (Android)

/**
 * Android sends missed calls to Equal with carrier call-forwarding codes, one per case:
 * busy, unanswered, unreachable. Each code's carrier reply is shown in turn and its step ticks off.
 */
@Composable
fun AccessScreen(model: AppModel) {
    val talk = rememberTalk()
    val scope = rememberCoroutineScope()
    val haptics = LocalHapticFeedback.current
    var busy by remember { mutableStateOf(false) }
    val title = Catalog.title(Catalog.Ask.Access)

    LaunchedEffect(Unit) { talk.intro(title) }

    SetupLayout(talk, title, details = {
        Column(verticalArrangement = Arrangement.spacedBy(6.dp)) {
            Catalog.forwardingCases.forEachIndexed { i, c -> BulletRow(c, model.forwarded[i] || model.fwdDone) }
        }
    }) {
        PrimaryButton(
            when {
                model.fwdDone -> "Continue"
                busy -> "Setting up…"
                else -> "Set up forwarding"
            },
            enabled = !busy,
        ) {
            if (model.fwdDone) { model.next(); return@PrimaryButton }
            busy = true
            scope.launch {
                Catalog.forwardingCases.forEachIndexed { i, c ->
                    model.present(Overlay.Ussd(c))
                    model.forwarded[i] = true
                    haptics.performHapticFeedback(HapticFeedbackType.TextHandleMove)
                }
                model.fwdDone = true
                busy = false
                haptics.performHapticFeedback(HapticFeedbackType.LongPress)
            }
        }
    }
}

/** Walkthrough on top (looping Lottie), small orb + bubble, the step details, footer at the bottom. */
@Composable
private fun SetupLayout(
    talk: ai.equal.orb.ui.Talk, title: String,
    details: @Composable () -> Unit, footer: @Composable () -> Unit,
) {
    BoxWithConstraints(Modifier.fillMaxSize()) {
        val heroH = (maxHeight - 400.dp).coerceIn(170.dp, 300.dp)
        Column(Modifier.fillMaxSize()) {
            LottieHero(R.raw.ussd, Modifier.fillMaxWidth().height(heroH))
            Column(Modifier.padding(horizontal = 24.dp)) {
                OrbBesideBubble(talk, title, Catalog.playful(Catalog.Ask.Access), Modifier.padding(top = 20.dp, bottom = 12.dp))
                Box(Modifier.padding(top = 20.dp)) { details() }
            }
            Spacer(Modifier.weight(1f).heightIn(min = 8.dp))
            Box(Modifier.padding(horizontal = 24.dp).padding(bottom = 8.dp)) { footer() }
        }
    }
}

/** Looping walkthrough; rises in once the screen has landed and fades out at the bottom. */
@Composable
private fun LottieHero(res: Int, modifier: Modifier) {
    val composition by rememberLottieComposition(LottieCompositionSpec.RawRes(res))
    val shown = remember { Animatable(0f) }
    LaunchedEffect(Unit) { delay(450); shown.animateTo(1f, tween(700, easing = EQ.ease)) }
    Box(
        modifier.graphicsLayer {
            alpha = shown.value
            translationY = 24 * density * (1 - shown.value)
            val s = 0.96f + 0.04f * shown.value; scaleX = s; scaleY = s
        }.fadeBottom(0.78f),
        contentAlignment = Alignment.Center,
    ) {
        LottieAnimation(composition, iterations = LottieConstants.IterateForever, modifier = Modifier.fillMaxSize(), contentScale = ContentScale.Fit)
    }
}

/** Solid to [solidUntil], then fades to transparent at the bottom edge. */
fun Modifier.fadeBottom(solidUntil: Float) = this
    .graphicsLayer { compositingStrategy = CompositingStrategy.Offscreen }
    .drawWithContent {
        drawContent()
        drawRect(Brush.verticalGradient(0f to Color.Black, solidUntil to Color.Black, 1f to Color.Transparent), blendMode = BlendMode.DstIn)
    }

/** A step in a list: grey dot, or a green tick that pops in once done. */
@Composable
fun BulletRow(text: String, done: Boolean) {
    val tick by animateFloatAsState(if (done) 1f else 0f, tween(350, easing = CubicBezierEasing(0.34f, 1.56f, 0.64f, 1f)), label = "tick")
    Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(8.dp)) {
        Box(Modifier.size(18.dp), contentAlignment = Alignment.Center) {
            if (tick < 0.5f) Box(Modifier.size(7.dp).graphicsLayer { alpha = 1 - tick * 2 }.background(EQ.ink.copy(alpha = 0.45f), CircleShape))
            Box(
                Modifier.size(18.dp).graphicsLayer { scaleX = 0.4f + 0.6f * tick; scaleY = scaleX; alpha = tick.coerceIn(0f, 1f) }
                    .background(EQ.green, CircleShape),
                contentAlignment = Alignment.Center,
            ) { Image(rememberVectorPainter(Icons.Filled.Check), null, Modifier.size(12.dp), colorFilter = ColorFilter.tint(Color.White)) }
        }
        Txt(rich(text, 15f), dm(15f, color = EQ.ink, lineHeight = 20f))
    }
}
