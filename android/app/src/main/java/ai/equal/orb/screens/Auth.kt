package ai.equal.orb.screens

import androidx.compose.material.icons.filled.Edit
import ai.equal.orb.model.AppModel
import ai.equal.orb.model.Catalog
import ai.equal.orb.model.Step
import ai.equal.orb.ui.EQ
import ai.equal.orb.ui.LinkButton
import ai.equal.orb.ui.OrbWithBubble
import ai.equal.orb.ui.PrimaryButton
import ai.equal.orb.ui.Txt
import ai.equal.orb.ui.dm
import ai.equal.orb.ui.dmFamily
import ai.equal.orb.ui.glass
import ai.equal.orb.ui.hex
import ai.equal.orb.ui.pressable
import ai.equal.orb.ui.rememberTalk
import ai.equal.orb.ui.riseIn
import androidx.compose.animation.animateColorAsState
import androidx.compose.animation.core.Animatable
import androidx.compose.animation.core.tween
import androidx.compose.foundation.Image
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.BoxScope
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.RowScope
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.text.BasicTextField
import androidx.compose.foundation.text.KeyboardActions
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.ArrowForward
import androidx.compose.material.icons.filled.Check
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateListOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.shadow
import androidx.compose.ui.focus.FocusRequester
import androidx.compose.ui.focus.focusRequester
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.ColorFilter
import androidx.compose.ui.graphics.SolidColor
import androidx.compose.ui.graphics.graphicsLayer
import androidx.compose.ui.graphics.vector.rememberVectorPainter
import androidx.compose.ui.hapticfeedback.HapticFeedbackType
import androidx.compose.ui.platform.LocalFocusManager
import androidx.compose.ui.platform.LocalHapticFeedback
import androidx.compose.ui.text.SpanStyle
import androidx.compose.ui.text.buildAnnotatedString
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.input.ImeAction
import androidx.compose.ui.text.input.KeyboardCapitalization
import androidx.compose.ui.text.input.KeyboardType
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.text.withStyle
import androidx.compose.ui.unit.dp
import kotlinx.coroutines.delay

/**
 * Standard layout of a question screen: content centred in the space between the top bar and
 * the footer, footer pinned to the bottom.
 */
@Composable
fun QuestionLayout(arriving: Boolean = false, main: @Composable BoxScope.() -> Unit, footer: @Composable () -> Unit) {
    Column(Modifier.fillMaxSize()) {
        Box(Modifier.weight(1f).fillMaxWidth().padding(horizontal = 24.dp), contentAlignment = Alignment.Center) { main() }
        Box(Modifier.fillMaxWidth().padding(horizontal = 24.dp).padding(top = 8.dp, bottom = 8.dp).riseIn(arriving, 520, 40.dp, 750)) { footer() }
    }
}

// MARK: - Number

@Composable
fun PhoneScreen(model: AppModel) {
    val talk = rememberTalk()
    val focus = remember { FocusRequester() }
    val arriving = model.arrivingFromSplash
    val title = Catalog.title(Catalog.Ask.Phone)
    val haptics = LocalHapticFeedback.current

    LaunchedEffect(Unit) {
        talk.intro(title, if (arriving) 750 else 420)
        delay(if (arriving) 1000 else 350)
        runCatching { focus.requestFocus() }
    }
    fun send() { if (model.phone.length == 10) model.go(Step.Otp) }

    QuestionLayout(arriving, main = {
        OrbWithBubble(
            talk, title, Catalog.playful(Catalog.Ask.Phone),
            modifier = Modifier.riseIn(arriving, 300),
        )
    }) {
        Column(horizontalAlignment = Alignment.CenterHorizontally) {
            InputPill(filled = model.phone.isNotEmpty(), canSend = model.phone.length == 10, onSend = ::send) {
                Txt("🇮🇳 +91", dm(17f, FontWeight.Medium, EQ.ink))
                Box(Modifier.padding(horizontal = 12.dp).width(1.dp).height(26.dp).background(EQ.ink.copy(alpha = 0.15f)))
                Field(
                    value = model.phone, placeholder = "Mobile number", focus = focus,
                    keyboard = KeyboardOptions(keyboardType = KeyboardType.Phone, imeAction = ImeAction.Done),
                    onDone = ::send,
                ) { v -> model.phone = v.filter(Char::isDigit).take(10) }
            }
            Spacer(Modifier.height(14.dp))
            Row(
                Modifier.pressable { model.whatsapp = !model.whatsapp; haptics.performHapticFeedback(HapticFeedbackType.TextHandleMove) },
                verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(8.dp),
            ) {
                Box(
                    Modifier.size(18.dp)
                        .background(if (model.whatsapp) EQ.green else Color.Transparent, RoundedCornerShape(5.dp))
                        .border(1.5.dp, if (model.whatsapp) EQ.green else EQ.ink.copy(alpha = 0.35f), RoundedCornerShape(5.dp)),
                    contentAlignment = Alignment.Center,
                ) {
                    if (model.whatsapp) Image(rememberVectorPainter(Icons.Filled.Check), null, Modifier.size(13.dp), colorFilter = ColorFilter.tint(Color.White))
                }
                Txt("Send me updates on WhatsApp", dm(14f, color = EQ.ink.copy(alpha = 0.7f)))
            }
            Spacer(Modifier.height(10.dp))
            val link = SpanStyle(color = EQ.greenDeep, fontFamily = dmFamily(12f, FontWeight.Medium), fontWeight = FontWeight.Medium)
            Txt(
                buildAnnotatedString {
                    append("By continuing, you agree to our ")
                    withStyle(link) { append("Terms") }
                    append(" and ")
                    withStyle(link) { append("Privacy Statement") }
                },
                dm(12f, color = EQ.ink.copy(alpha = 0.5f), align = TextAlign.Center),
            )
        }
    }
}

// MARK: - Code

@Composable
fun OtpScreen(model: AppModel) {
    val talk = rememberTalk()
    val title = Catalog.title(Catalog.Ask.Otp)
    val digits = remember { mutableStateListOf<String>() }
    var verifying by remember { mutableStateOf(false) }
    val haptics = LocalHapticFeedback.current
    val spaced = model.phone.let { if (it.length == 10) "${it.take(5)} ${it.takeLast(5)}" else it }

    LaunchedEffect(Unit) {
        talk.intro(title)
        delay(3000)   // give the SMS a moment to “arrive” before the code fills in
        for (d in listOf("4", "8", "2", "7")) {
            delay(380)
            digits.add(d)
            haptics.performHapticFeedback(HapticFeedbackType.TextHandleMove)
        }
        verifying = true
        delay(700)
        model.go(Step.Name)
    }

    QuestionLayout(main = {
        Column(horizontalAlignment = Alignment.CenterHorizontally) {
            OrbWithBubble(talk, title, Catalog.playful(Catalog.Ask.Otp))
            Spacer(Modifier.height(32.dp))
            Row(horizontalArrangement = Arrangement.spacedBy(12.dp)) {
                for (i in 0 until 4) {
                    val filled = i < digits.size
                    OtpCell(if (filled) digits[i] else "", filled, Modifier.weight(1f))
                }
            }
            Txt(
                if (verifying) "Verifying…" else "Reading the SMS automatically…",
                dm(14f, color = EQ.ink.copy(alpha = 0.55f)), Modifier.padding(top = 14.dp),
            )
            Box(Modifier.padding(top = 6.dp)) {
                // The number, with a small pencil to go back and change it.
                Row(
                    Modifier.pressable { model.go(Step.Phone, -1) }.padding(vertical = 6.dp),
                    verticalAlignment = Alignment.CenterVertically,
                    horizontalArrangement = Arrangement.spacedBy(6.dp),
                ) {
                    Txt("+91 $spaced", dm(15f, FontWeight.SemiBold, EQ.ink))
                    Box(Modifier.size(26.dp).background(EQ.green.copy(alpha = 0.12f), CircleShape), contentAlignment = Alignment.Center) {
                        Image(rememberVectorPainter(Icons.Filled.Edit), "Edit number", Modifier.size(14.dp), colorFilter = ColorFilter.tint(EQ.greenDeep))
                    }
                }
            }
        }
    }) {
        PrimaryButton(if (verifying) "Verifying…" else "Confirm", enabled = false, lookEnabled = verifying) {}
    }
}

@Composable
private fun OtpCell(text: String, filled: Boolean, modifier: Modifier) {
    val pop = remember { Animatable(1f) }
    LaunchedEffect(filled) {
        if (filled) {
            pop.animateTo(1.14f, tween(130)); pop.animateTo(1f, tween(170))
        }
    }
    val stroke by animateColorAsState(if (filled) EQ.green else Color.White.copy(alpha = 0.75f), tween(200), label = "otp")
    Box(
        modifier.height(68.dp).graphicsLayer { scaleX = pop.value; scaleY = pop.value }
            .glass(RoundedCornerShape(18.dp), tint = 0.62f, stroke = stroke),
        contentAlignment = Alignment.Center,
    ) { Txt(text, dm(26f, FontWeight.SemiBold, EQ.ink)) }
}

// MARK: - Name

@Composable
fun NameScreen(model: AppModel) {
    val talk = rememberTalk()
    val focus = remember { FocusRequester() }
    val focusManager = LocalFocusManager.current
    val title = Catalog.title(Catalog.Ask.Name)
    var text by remember { mutableStateOf(model.name) }

    LaunchedEffect(Unit) {
        talk.intro(title)
        delay(350)
        runCatching { focus.requestFocus() }
    }
    fun submit() {
        val t = text.trim()
        if (t.isEmpty()) return
        model.name = t
        focusManager.clearFocus()
        model.go(Step.Cases)
    }

    QuestionLayout(main = { OrbWithBubble(talk, title, Catalog.playful(Catalog.Ask.Name)) }) {
        InputPill(filled = text.isNotEmpty(), canSend = text.isNotBlank(), onSend = ::submit) {
            Field(
                value = text, placeholder = "Your name", focus = focus,
                keyboard = KeyboardOptions(capitalization = KeyboardCapitalization.Words, autoCorrectEnabled = false, imeAction = ImeAction.Next),
                onDone = ::submit,
            ) { text = it }
        }
    }
}

// MARK: - Shared input

/**
 * White 60 dp pill holding a field, with the screen's main action merged in as a round green
 * send button at its right end. Gains a green rim once something is typed.
 */
@Composable
fun InputPill(filled: Boolean, canSend: Boolean, onSend: () -> Unit, field: @Composable RowScope.() -> Unit) {
    val rim by animateColorAsState(if (filled) EQ.green else Color.White, tween(200), label = "rim")
    val ring by animateColorAsState(if (filled) EQ.green.copy(alpha = 0.12f) else Color.Transparent, tween(200), label = "ring")
    val send by animateColorAsState(if (canSend) EQ.green else hex(0xBFE6CB), tween(200), label = "send")
    Box(Modifier.fillMaxWidth().border(3.dp, ring, RoundedCornerShape(50)).padding(3.dp)) {
        Row(
            Modifier
                .fillMaxWidth()
                .height(60.dp)
                .shadow(10.dp, RoundedCornerShape(50), ambientColor = hex(0x003214, 0.08f), spotColor = hex(0x003214, 0.12f))
                .background(Color.White, RoundedCornerShape(50))
                .border(1.5.dp, rim, RoundedCornerShape(50))
                .padding(start = 22.dp, end = 8.dp),
            verticalAlignment = Alignment.CenterVertically,
        ) {
            field()
            Box(
                Modifier.size(44.dp)
                    .pressable(canSend, 0.92f) { onSend() }
                    .then(if (canSend) Modifier.shadow(6.dp, CircleShape, spotColor = hex(0x008C32, 0.4f)) else Modifier)
                    .background(send, CircleShape),
                contentAlignment = Alignment.Center,
            ) {
                Image(rememberVectorPainter(Icons.Filled.ArrowForward), "Send", Modifier.size(22.dp), colorFilter = ColorFilter.tint(Color.White))
            }
        }
    }
}

@Composable
private fun RowScope.Field(
    value: String, placeholder: String, focus: FocusRequester, keyboard: KeyboardOptions, onDone: () -> Unit, onChange: (String) -> Unit,
) {
    BasicTextField(
        value = value,
        onValueChange = onChange,
        modifier = Modifier.weight(1f).focusRequester(focus),
        singleLine = true,
        textStyle = dm(18f, FontWeight.Medium, EQ.ink),
        cursorBrush = SolidColor(EQ.green),
        keyboardOptions = keyboard,
        keyboardActions = KeyboardActions(onDone = { onDone() }, onNext = { onDone() }),
        decorationBox = { inner ->
            Box(contentAlignment = Alignment.CenterStart) {
                if (value.isEmpty()) Txt(placeholder, dm(18f, FontWeight.Medium, EQ.ink.copy(alpha = 0.45f)))
                inner()
            }
        },
    )
}
