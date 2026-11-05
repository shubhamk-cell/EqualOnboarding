package ai.equal.orb.screens

import ai.equal.orb.model.art
import ai.equal.orb.model.Permission
import ai.equal.orb.R
import ai.equal.orb.model.AppModel
import ai.equal.orb.model.Overlay
import ai.equal.orb.ui.EQ
import ai.equal.orb.ui.Txt
import ai.equal.orb.ui.Wordmark
import ai.equal.orb.ui.dm
import ai.equal.orb.ui.hex
import ai.equal.orb.ui.pressable
import androidx.compose.animation.AnimatedVisibility
import androidx.compose.animation.fadeOut
import androidx.compose.animation.scaleOut
import androidx.compose.foundation.Canvas
import androidx.compose.foundation.ExperimentalFoundationApi
import androidx.compose.foundation.Image
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.combinedClickable
import androidx.compose.foundation.horizontalScroll
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
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.layout.widthIn
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.KeyboardArrowDown
import androidx.compose.material.icons.filled.KeyboardArrowRight
import androidx.compose.material.icons.filled.MoreVert
import androidx.compose.material.icons.filled.Search
import androidx.compose.material.icons.filled.Settings
import androidx.compose.runtime.Composable
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.draw.rotate
import androidx.compose.ui.draw.shadow
import androidx.compose.ui.geometry.CornerRadius
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.geometry.Size
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.ColorFilter
import androidx.compose.ui.graphics.Path
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.graphics.vector.rememberVectorPainter
import androidx.compose.ui.hapticfeedback.HapticFeedbackType
import androidx.compose.ui.platform.LocalHapticFeedback
import androidx.compose.ui.res.painterResource
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.dp
import kotlinx.coroutines.launch
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale

/**
 * Chats home after onboarding: the pinned Equal AI thread (rule saved), the example rider call,
 * and — if call forwarding was skipped — a card to finish setup.
 * Long-press the logo to replay onboarding.
 */
@OptIn(ExperimentalFoundationApi::class)
@Composable
fun HomeScreen(model: AppModel) {
    val scope = rememberCoroutineScope()
    val haptics = LocalHapticFeedback.current
    val now = remember { SimpleDateFormat("h:mm a", Locale.getDefault()).format(Date()) }
    val context = androidx.compose.ui.platform.LocalContext.current
    val lifecycle = androidx.lifecycle.compose.LocalLifecycleOwner.current
    androidx.compose.runtime.DisposableEffect(lifecycle) {
        model.refreshPermissions(context)
        val obs = androidx.lifecycle.LifecycleEventObserver { _, e ->
            if (e == androidx.lifecycle.Lifecycle.Event.ON_RESUME) model.refreshPermissions(context)
        }
        lifecycle.lifecycle.addObserver(obs)
        onDispose { lifecycle.lifecycle.removeObserver(obs) }
    }

    Box(Modifier.fillMaxSize().background(EQ.page)) {
        Column(Modifier.fillMaxSize()) {
            // Header (runs up under the status bar).
            Row(
                Modifier
                    .fillMaxWidth()
                    .shadow(0.5.dp, RoundedCornerShape(0.dp), ambientColor = EQ.hair, spotColor = EQ.hair)
                    .background(Color.White.copy(alpha = 0.92f))
                    .statusBarsPadding()
                    .padding(horizontal = 24.dp)
                    .padding(top = 18.dp, bottom = 12.dp),
                verticalAlignment = Alignment.CenterVertically,
            ) {
                Box(
                    Modifier.combinedClickable(remember { MutableInteractionSource() }, indication = null, onClick = {}, onLongClick = {
                        haptics.performHapticFeedback(HapticFeedbackType.LongPress); model.restart()
                    })
                ) { Wordmark(24.dp) }
                Spacer(Modifier.weight(1f))
                Row(
                    Modifier.height(36.dp).background(Color.White.copy(alpha = 0.74f), RoundedCornerShape(50))
                        .border(1.dp, EQ.hair, RoundedCornerShape(50)).padding(horizontal = 14.dp),
                    verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(8.dp),
                ) {
                    Box(Modifier.size(8.dp).background(EQ.green, CircleShape))
                    Txt("Available", dm(15f, FontWeight.Medium, EQ.green))
                    Icon(Icons.Filled.KeyboardArrowDown, EQ.secondary, 18.dp)
                }
            }

            Column(Modifier.weight(1f).verticalScroll(rememberScrollState())) {
                // Search.
                Row(
                    Modifier.padding(horizontal = 24.dp).padding(top = 14.dp, bottom = 8.dp),
                    verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(16.dp),
                ) {
                    Row(
                        Modifier.weight(1f).height(48.dp).background(Color.White, RoundedCornerShape(50))
                            .border(1.dp, EQ.hair, RoundedCornerShape(50)).padding(horizontal = 16.dp),
                        verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(12.dp),
                    ) {
                        Icon(Icons.Filled.Search, EQ.placeholder, 20.dp)
                        Txt("Search for names", dm(16f, color = EQ.placeholder))
                    }
                    Box(
                        Modifier.size(40.dp).background(Color.White.copy(alpha = 0.74f), CircleShape).border(1.dp, EQ.hair, CircleShape),
                        contentAlignment = Alignment.Center,
                    ) { Box(Modifier.rotate(90f)) { Icon(Icons.Filled.MoreVert, hex(0x111111), 20.dp) } }
                }

                // Follows what Android has actually granted, including changes made in Settings.
                val missing = model.missingPermissions
                AnimatedVisibility(missing.isNotEmpty(), exit = fadeOut() + scaleOut(targetScale = 0.95f)) {
                    SetupCard(missing, Modifier.padding(horizontal = 24.dp).padding(top = 16.dp)) {
                        scope.launch { model.present(Overlay.Decline(missing)) }
                    }
                }

                Column(Modifier.padding(horizontal = 20.dp)) {
                    // Equal AI thread.
                    Row(Modifier.padding(vertical = 14.dp), horizontalArrangement = Arrangement.spacedBy(14.dp)) {
                        Image(painterResource(R.drawable.equal_avatar), "Equal AI", Modifier.size(56.dp).clip(CircleShape))
                        Column(Modifier.weight(1f)) {
                            Row(verticalAlignment = Alignment.CenterVertically) {
                                Txt("Equal AI", dm(18f, FontWeight.SemiBold, hex(0x111111), tracking = -0.36f))
                                Spacer(Modifier.weight(1f))
                                Txt(now, dm(13f, FontWeight.SemiBold, EQ.green))
                            }
                            // The unread count sits at the end of the message line.
                            Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(10.dp)) {
                                Txt("Saved. I’ll follow it from now on.", dm(17f, color = EQ.secondary), Modifier.weight(1f), maxLines = 1)
                                Badge(1)
                            }
                            ChipRow(listOf("✏️ Add instruction", "💬 Talk to assistant"), read = false)
                        }
                    }
                    Box(Modifier.fillMaxWidth().height(1.dp).background(EQ.hair))
                    // Example rider call.
                    Row(Modifier.padding(vertical = 14.dp), horizontalArrangement = Arrangement.spacedBy(14.dp)) {
                        Box(Modifier.size(56.dp).background(hex(0xFFE9D6), CircleShape), contentAlignment = Alignment.Center) { Txt("🛵", dm(22f)) }
                        Column(Modifier.weight(1f)) {
                            Row(verticalAlignment = Alignment.CenterVertically) {
                                Txt("Delivery rider", dm(18f, FontWeight.SemiBold, hex(0x111111), tracking = -0.36f))
                                Spacer(Modifier.weight(1f))
                                Txt("Example", dm(13f, color = EQ.secondary))
                            }
                            Txt("Rider left your order at the door.", dm(17f, color = EQ.secondary), maxLines = 1)
                            ChipRow(listOf("📞 Call back", "💬 Reply on WhatsApp"), read = true)
                        }
                    }
                }
                Txt(
                    "${model.displayName}, your real calls will show up here.",
                    dm(14f, color = EQ.secondary, lineHeight = 19f, align = TextAlign.Center),
                    Modifier.fillMaxWidth().padding(horizontal = 36.dp).padding(top = 28.dp, bottom = 140.dp),
                )
            }
        }

        // Bottom tab pill + orb FAB.
        Row(
            Modifier
                .align(Alignment.BottomCenter)
                .fillMaxWidth()
                .background(Brush.verticalGradient(0f to EQ.page.copy(alpha = 0f), 0.42f to EQ.page))
                .navigationBarsPadding()
                .padding(top = 12.dp, bottom = 8.dp),
            horizontalArrangement = Arrangement.spacedBy(16.dp, Alignment.CenterHorizontally),
            verticalAlignment = Alignment.CenterVertically,
        ) {
            Row(
                Modifier.shadow(12.dp, RoundedCornerShape(50), spotColor = Color.Black.copy(alpha = 0.12f))
                    .background(Color.White.copy(alpha = 0.95f), RoundedCornerShape(50))
                    .border(1.dp, EQ.hair, RoundedCornerShape(50)).padding(4.dp)
            ) {
                Box {
                    Column(
                        Modifier.shadow(2.5.dp, RoundedCornerShape(50)).background(hex(0xF0F6E5), RoundedCornerShape(50))
                            .padding(horizontal = 26.dp, vertical = 6.dp),
                        horizontalAlignment = Alignment.CenterHorizontally, verticalArrangement = Arrangement.spacedBy(2.dp),
                    ) {
                        ChatGlyph(EQ.green)
                        Txt("Chats", dm(12f, FontWeight.SemiBold, EQ.green))
                    }
                    Box(Modifier.align(Alignment.TopEnd).padding(top = 2.dp, end = 12.dp)) { Badge(1) }
                }
                Column(
                    Modifier.padding(horizontal = 26.dp, vertical = 6.dp),
                    horizontalAlignment = Alignment.CenterHorizontally, verticalArrangement = Arrangement.spacedBy(2.dp),
                ) {
                    Box(Modifier.size(26.dp).background(hex(0xF3D7A8), CircleShape), contentAlignment = Alignment.Center) { Txt("🙂", dm(14f)) }
                    Txt("You", dm(12f, FontWeight.Medium, EQ.secondary))
                }
            }
            Image(
                painterResource(R.drawable.equal_avatar), "Talk to Equal",
                Modifier.size(64.dp)
                    .shadow(14.dp, CircleShape, ambientColor = EQ.green.copy(alpha = 0.4f), spotColor = EQ.green.copy(alpha = 0.5f))
                    .clip(CircleShape)
                    .border(1.dp, Color.White.copy(alpha = 0.55f), CircleShape)
                    .pressable(scale = 0.94f) { model.showToast("Global MYA — not in this prototype") },
            )
        }
    }
}

@Composable
private fun Icon(v: ImageVector, tint: Color, size: Dp) =
    Image(rememberVectorPainter(v), null, Modifier.size(size), colorFilter = ColorFilter.tint(tint))

@Composable
private fun ChatGlyph(color: Color) {
    Canvas(Modifier.size(22.dp)) {
        val d = density
        drawRoundRect(color, Offset(2 * d, 2 * d), Size(18 * d, 14 * d), CornerRadius(4 * d))
        drawPath(Path().apply { moveTo(5 * d, 15 * d); lineTo(5 * d, 20 * d); lineTo(10 * d, 15 * d); close() }, color)
    }
}

@Composable
private fun Badge(count: Int) {
    Box(
        Modifier.widthIn(min = 18.dp).height(18.dp)
            .background(EQ.green, RoundedCornerShape(50))
            .padding(horizontal = 4.dp),
        contentAlignment = Alignment.Center,
    ) { Txt("$count", dm(11f, FontWeight.SemiBold, Color.White)) }
}

@Composable
private fun ChipRow(items: List<String>, read: Boolean) {
    Row(
        Modifier.padding(top = 8.dp).horizontalScroll(rememberScrollState()),
        horizontalArrangement = Arrangement.spacedBy(12.dp),
    ) {
        items.forEach { text ->
            Row(
                Modifier.height(36.dp)
                    .background(Color.White, RoundedCornerShape(50))
                    .background(
                        if (read) Brush.verticalGradient(listOf(Color.White, hex(0xEBEBEB)))
                        else Brush.verticalGradient(listOf(EQ.lime.copy(alpha = 0.01f), EQ.lime.copy(alpha = 0.18f))),
                        RoundedCornerShape(50),
                    )
                    .border(1.dp, if (read) Color.Black.copy(alpha = 0.08f) else EQ.green.copy(alpha = 0.36f), RoundedCornerShape(50))
                    .padding(horizontal = 14.dp),
                verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(6.dp),
            ) {
                Txt(text, dm(14f, color = hex(0x111111)))
                Icon(Icons.Filled.KeyboardArrowRight, EQ.secondary, 16.dp)
            }
        }
        Spacer(Modifier.width(12.dp))
    }
}

/** Banner for whichever permissions are still off; opens the matching sheet. */
@Composable
private fun SetupCard(missing: List<Permission>, modifier: Modifier, onClick: () -> Unit) {
    val (title, message) = when (missing) {
        listOf(Permission.Notifications) -> "Enable Notifications" to "Allow notifications so you never miss an update from me"
        listOf(Permission.Contacts) -> "Enable Contacts" to "Allow contacts so I can recognise the people you know"
        else -> "Enable Permissions" to "Allow notifications and contacts for real-time call recognition"
    }
    Box(
        modifier.fillMaxWidth().pressable(scale = 0.98f) { onClick() }
            .shadow(10.dp, RoundedCornerShape(22.dp), spotColor = Color.Black.copy(alpha = 0.1f))
            .background(Brush.horizontalGradient(listOf(hex(0xFFE8D6), hex(0xFFF4EA))), RoundedCornerShape(22.dp))
            .padding(16.dp)
    ) {
        Column(Modifier.widthIn(max = 220.dp)) {
            Txt(title, dm(17f, FontWeight.SemiBold, hex(0x111111), tracking = -0.34f))
            Txt(
                message,
                dm(12.5f, color = EQ.secondary, lineHeight = 17f), Modifier.padding(top = 2.dp, bottom = 12.dp),
            )
            Row(
                Modifier.height(32.dp).background(hex(0xE8620A), RoundedCornerShape(50)).padding(horizontal = 14.dp),
                verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(6.dp),
            ) {
                Icon(Icons.Filled.Settings, Color.White, 15.dp)
                Txt("Open settings", dm(13f, FontWeight.SemiBold, Color.White))
            }
        }
        Image(painterResource(missing.art), null, Modifier.align(Alignment.CenterEnd).size(84.dp))
    }
}
