package ai.equal.orb.overlays

import androidx.compose.ui.res.painterResource
import ai.equal.orb.model.art
import ai.equal.orb.model.Permission
import ai.equal.orb.model.AppModel
import ai.equal.orb.model.Overlay
import ai.equal.orb.ui.EQ
import ai.equal.orb.ui.PrimaryButton
import ai.equal.orb.ui.Txt
import ai.equal.orb.ui.dm
import ai.equal.orb.ui.hex
import ai.equal.orb.ui.pressable
import android.content.Intent
import android.net.Uri
import android.provider.Settings
import androidx.activity.compose.BackHandler
import androidx.compose.animation.AnimatedVisibility
import androidx.compose.animation.core.Animatable
import androidx.compose.animation.core.CubicBezierEasing
import androidx.compose.animation.core.tween
import androidx.compose.animation.fadeIn
import androidx.compose.animation.fadeOut
import androidx.compose.animation.scaleIn
import androidx.compose.animation.scaleOut
import androidx.compose.foundation.Image
import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.interaction.MutableInteractionSource
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.navigationBarsPadding
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.statusBarsPadding
import androidx.compose.foundation.layout.widthIn
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Close
import androidx.compose.material.icons.filled.Settings
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableIntStateOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.shadow
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.ColorFilter
import androidx.compose.ui.graphics.RectangleShape
import androidx.compose.ui.graphics.graphicsLayer
import androidx.compose.ui.graphics.vector.rememberVectorPainter
import androidx.compose.ui.hapticfeedback.HapticFeedbackType
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.platform.LocalHapticFeedback
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.text.style.TextDecoration
import androidx.compose.ui.unit.dp
import kotlinx.coroutines.delay
import kotlinx.coroutines.launch

/**
 * Draws whichever modal surface the model is presenting. Each one animates itself in and,
 * when closed, animates out before handing its result back to the flow.
 */
@Composable
fun OverlayHost(model: AppModel) {
    when (val o = model.overlay) {
        Overlay.Consent -> ConsentDialog(model)
        is Overlay.Decline -> DeclineSheet(model, o.missing)
        is Overlay.Ussd -> CarrierReply(model, o.case)
        null -> {}
    }
}

/** Call-data consent: Equal's own dialog, asked once. */
@Composable
private fun ConsentDialog(model: AppModel) {
    val scope = rememberCoroutineScope()
    val p = remember { Animatable(0f) }
    LaunchedEffect(Unit) { p.animateTo(1f, tween(380, easing = CubicBezierEasing(0.32f, 1.2f, 0.5f, 1f))) }
    fun close(r: String) = scope.launch { p.animateTo(0f, tween(250, easing = EQ.push)); model.resolve(r) }
    BackHandler { close("deny") }

    Box(Modifier.fillMaxSize(), contentAlignment = Alignment.Center) {
        Box(
            Modifier.fillMaxSize().graphicsLayer { alpha = p.value.coerceIn(0f, 1f) }.background(hex(0x0A140C, 0.32f))
                .clickable(remember { MutableInteractionSource() }, indication = null) {}
        )
        Column(
            Modifier
                .padding(horizontal = 22.dp)
                .widthIn(max = 340.dp)
                .graphicsLayer {
                    val v = p.value
                    alpha = v.coerceIn(0f, 1f); translationY = 20 * density * (1 - v)
                    val s = 0.96f + 0.04f * v; scaleX = s; scaleY = s
                }
                .shadow(30.dp, RoundedCornerShape(28.dp))
                .background(Color.White, RoundedCornerShape(28.dp))
                .padding(start = 20.dp, end = 20.dp, top = 26.dp, bottom = 20.dp)
        ) {
            Txt("Allow Equal to process your call data?", dm(21f, FontWeight.Bold, EQ.ink, lineHeight = 27f, tracking = -0.42f))
            Spacer(Modifier.height(14.dp))
            Txt(
                "To identify callers, detect spam, and respond on your behalf, Equal shares limited call data — including caller ID, audio transcripts, and contact context — with our AI partners.",
                dm(14.5f, color = hex(0x2B2B2B), lineHeight = 21f),
            )
            Spacer(Modifier.height(14.dp))
            Txt("Your data is used only to power your assistant. It is never sold or used for advertising.", dm(14.5f, color = hex(0x2B2B2B), lineHeight = 21f))
            Row(Modifier.padding(top = 20.dp), horizontalArrangement = Arrangement.spacedBy(10.dp)) {
                Box(
                    Modifier.weight(1f).height(50.dp).pressable { close("deny") }.background(hex(0xE3E3E3), RoundedCornerShape(50)),
                    contentAlignment = Alignment.Center,
                ) { Txt("Don’t allow", dm(16f, FontWeight.SemiBold, hex(0x111111))) }
                Box(
                    Modifier.weight(1f).height(50.dp).pressable { close("allow") }.background(EQ.green, RoundedCornerShape(50)),
                    contentAlignment = Alignment.Center,
                ) { Txt("Allow", dm(16f, FontWeight.SemiBold, Color.White)) }
            }
        }
    }
}

/**
 * Shown once both system prompts have been answered (or from Home's banner), in one of three
 * versions: notifications refused, contacts refused, or both.
 */
@Composable
private fun DeclineSheet(model: AppModel, missing: List<Permission>) {
    val both = missing.size > 1
    val notifications = missing == listOf(Permission.Notifications)
    val title = when {
        both -> "Enable Permissions"
        notifications -> "Notification permission required"
        else -> "Contact permission required"
    }
    val message = when {
        both -> "Allow notifications and contacts access to recognise calls and update you in real time."
        notifications -> "Allow Equal AI to send you notifications to avoid missing important updates"
        else -> "Allow Equal AI to access your contacts so I can recognise the people you know when they call"
    }
    val scope = rememberCoroutineScope()
    val context = LocalContext.current
    val p = remember { Animatable(0f) }
    LaunchedEffect(Unit) { p.animateTo(1f, tween(420, easing = EQ.push)) }
    fun close(r: String) = scope.launch { p.animateTo(0f, tween(380, easing = EQ.push)); model.resolve(r) }
    BackHandler { close("dismiss") }

    Box(Modifier.fillMaxSize()) {
        Box(
            Modifier.fillMaxSize().graphicsLayer { alpha = p.value }.background(Color.Black.copy(alpha = 0.38f))
                .clickable(remember { MutableInteractionSource() }, indication = null) { close("dismiss") }
        )
        Box(
            Modifier
                .align(Alignment.BottomCenter)
                .fillMaxWidth()
                .graphicsLayer { translationY = size.height * 1.05f * (1 - p.value) }
                .background(EQ.page, RoundedCornerShape(topStart = 36.dp, topEnd = 36.dp))
                .clickable(remember { MutableInteractionSource() }, indication = null) {}
                .navigationBarsPadding()
                .padding(start = 24.dp, end = 24.dp, top = 28.dp, bottom = 12.dp)
        ) {
            Column(Modifier.fillMaxWidth(), horizontalAlignment = Alignment.CenterHorizontally) {
                Image(
                    painterResource(missing.art), null,
                    Modifier.padding(top = 4.dp, bottom = 14.dp).size(112.dp),
                )
                Txt(
                    title,
                    dm(22f, FontWeight.Bold, EQ.ink, lineHeight = 28f, tracking = -0.44f, align = TextAlign.Center),
                )
                Txt(
                    message,
                    dm(16f, color = EQ.ink.copy(alpha = 0.6f), lineHeight = 23f, align = TextAlign.Center),
                    Modifier.widthIn(max = 320.dp).padding(top = 10.dp, bottom = 24.dp),
                )
                Row(
                    Modifier.fillMaxWidth().height(56.dp)
                        .pressable {
                            context.startActivity(
                                Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS, Uri.fromParts("package", context.packageName, null))
                                    .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                            )
                            model.showToast("Allowed in Settings")
                            close("settings")
                        }
                        .shadow(10.dp, RoundedCornerShape(50), spotColor = EQ.green.copy(alpha = 0.4f))
                        .background(EQ.green, RoundedCornerShape(50)),
                    horizontalArrangement = Arrangement.spacedBy(8.dp, Alignment.CenterHorizontally),
                    verticalAlignment = Alignment.CenterVertically,
                ) {
                    Image(rememberVectorPainter(Icons.Filled.Settings), null, Modifier.size(20.dp), colorFilter = ColorFilter.tint(Color.White))
                    Txt("Open settings", dm(17f, FontWeight.SemiBold, Color.White))
                }
                Box(Modifier.padding(top = 14.dp).pressable { close("skip") }.padding(horizontal = 10.dp, vertical = 6.dp)) {
                    Txt("Continue anyway", dm(16f, FontWeight.SemiBold, EQ.ink).copy(textDecoration = TextDecoration.Underline))
                }
            }
            Box(
                Modifier.align(Alignment.TopEnd).size(48.dp).pressable { close("dismiss") }
                    .shadow(4.dp, CircleShape).background(Color.White, CircleShape),
                contentAlignment = Alignment.Center,
            ) { Image(rememberVectorPainter(Icons.Filled.Close), "Close", Modifier.size(20.dp), colorFilter = ColorFilter.tint(EQ.ink)) }
        }
    }
}

/**
 * What the carrier shows after a forwarding code: “Calling…”, then the registrations land one
 * by one. Dismiss, or it closes itself after 6 s.
 */
@Composable
private fun CarrierReply(model: AppModel, case: String) {
    val scope = rememberCoroutineScope()
    val haptics = LocalHapticFeedback.current
    val shown = remember { Animatable(0f) }
    var lines by remember { mutableIntStateOf(0) }
    var ready by remember { mutableStateOf(false) }
    var closed by remember { mutableStateOf(false) }
    val kinds = listOf("Voice", "Data", "Fax", "SMS")
    fun close() {
        if (closed) return
        closed = true
        scope.launch { shown.animateTo(0f, tween(200)); model.resolve("done") }
    }
    BackHandler { close() }
    LaunchedEffect(Unit) {
        shown.animateTo(1f, tween(250))
        delay(450)
        ready = true
        for (i in kinds.indices) { lines = i + 1; delay(260) }
        haptics.performHapticFeedback(HapticFeedbackType.LongPress)
        delay((6000 - 700 - 260 * kinds.size).toLong())
        close()
    }

    Box(
        Modifier.fillMaxSize().graphicsLayer { alpha = shown.value }.background(Color.Black)
            .clickable(remember { MutableInteractionSource() }, indication = null) {}
            .statusBarsPadding()
            .padding(top = 52.dp, start = 28.dp, end = 28.dp),
    ) {
        Column(Modifier.fillMaxWidth(), horizontalAlignment = Alignment.CenterHorizontally) {
            Txt("Calling…", dm(15f, color = Color.White.copy(alpha = 0.6f)), Modifier.padding(bottom = 22.dp))
            kinds.forEachIndexed { i, k ->
                AnimatedVisibility(i < lines, enter = fadeIn(tween(350)) + scaleIn(tween(350), initialScale = 0.98f)) {
                    val c = if (i == 0) Color.White else Color.White.copy(alpha = 0.55f)
                    Column(Modifier.padding(bottom = 14.dp), horizontalAlignment = Alignment.CenterHorizontally) {
                        Txt("Setting Registration Succeeded", dm(14f, FontWeight.Bold, c))
                        Txt("$k Call Forwarding", dm(14f, color = c))
                        Txt(case, dm(14f, color = c))
                    }
                }
            }
            Box(
                Modifier.padding(top = 20.dp).graphicsLayer { alpha = if (ready) 1f else 0f }
                    .height(44.dp).pressable(ready) { close() }.background(Color.White, RoundedCornerShape(50))
                    .padding(horizontal = 44.dp),
                contentAlignment = Alignment.Center,
            ) { Txt("Dismiss", dm(15f, FontWeight.SemiBold, Color.Black)) }
        }
    }
}

/** Toast pill above the bottom. */
@Composable
fun ToastHost(text: String?) {
    Box(Modifier.fillMaxSize().navigationBarsPadding().padding(bottom = 96.dp, start = 24.dp, end = 24.dp), contentAlignment = Alignment.BottomCenter) {
        AnimatedVisibility(text != null, enter = fadeIn(tween(200)) + scaleIn(tween(200), initialScale = 0.9f), exit = fadeOut(tween(250))) {
            var last by remember { mutableStateOf("") }
            if (text != null) last = text
            Box(
                Modifier.shadow(12.dp, RoundedCornerShape(50)).background(hex(0x161618, 0.92f), RoundedCornerShape(50))
                    .padding(horizontal = 16.dp, vertical = 10.dp)
            ) { Txt(last, dm(13f, FontWeight.Medium, Color.White, align = TextAlign.Center)) }
        }
    }
}
