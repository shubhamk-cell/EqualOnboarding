package ai.equal.orb

import ai.equal.orb.model.AppModel
import ai.equal.orb.model.Step
import ai.equal.orb.overlays.OverlayHost
import ai.equal.orb.overlays.ToastHost
import ai.equal.orb.screens.AccessScreen
import ai.equal.orb.screens.CasesScreen
import ai.equal.orb.screens.HomeScreen
import ai.equal.orb.screens.NameScreen
import ai.equal.orb.screens.OtpScreen
import ai.equal.orb.screens.PermissionsScreen
import ai.equal.orb.screens.PhoneScreen
import ai.equal.orb.screens.SplashScreen
import ai.equal.orb.screens.WelcomeScreen
import ai.equal.orb.ui.BackButton
import ai.equal.orb.ui.EQ
import ai.equal.orb.ui.SkipButton
import ai.equal.orb.ui.Sky
import ai.equal.orb.ui.riseIn
import android.app.Activity
import androidx.activity.compose.BackHandler
import androidx.compose.animation.AnimatedContent
import androidx.compose.animation.EnterTransition
import androidx.compose.animation.ExitTransition
import androidx.compose.animation.core.animateFloatAsState
import androidx.compose.animation.core.tween
import androidx.compose.animation.fadeIn
import androidx.compose.animation.fadeOut
import androidx.compose.animation.scaleOut
import androidx.compose.animation.slideInHorizontally
import androidx.compose.animation.slideOutHorizontally
import androidx.compose.animation.togetherWith
import androidx.compose.foundation.background
import androidx.compose.foundation.gestures.detectTapGestures
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.imePadding
import androidx.compose.foundation.layout.navigationBarsPadding
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.statusBarsPadding
import androidx.compose.runtime.Composable
import androidx.compose.runtime.SideEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.graphicsLayer
import androidx.compose.ui.input.pointer.pointerInput
import androidx.compose.ui.platform.LocalDensity
import androidx.compose.ui.platform.LocalFocusManager
import androidx.compose.ui.platform.LocalView
import androidx.compose.ui.unit.dp
import androidx.core.view.WindowCompat
import ai.equal.orb.ui.FlowScreen
import ai.equal.orb.ui.OrbStage
import androidx.compose.ui.layout.onGloballyPositioned
import androidx.compose.ui.layout.positionInRoot

/**
 * Stages the app: the green splash, the onboarding flow on its moving sky, and Home.
 * Modal surfaces (consent, decline sheets, carrier replies) and the toast sit on top.
 */
@Composable
fun OrbApp(startStep: String?) {
    val scope = rememberCoroutineScope()
    val model = remember {
        AppModel(scope).apply {
            Step.entries.firstOrNull { it.name.equals(startStep, ignoreCase = true) }?.let {
                step = it; name = "Shubham"; phone = "9876543210"; picks.addAll(listOf("task_door", "bank", "task_med"))
            }
        }
    }

    // Light status-bar icons on the green splash, dark everywhere else.
    val view = LocalView.current
    SideEffect {
        val window = (view.context as? Activity)?.window ?: return@SideEffect
        WindowCompat.getInsetsController(window, view).apply {
            isAppearanceLightStatusBars = model.step != Step.Splash
            isAppearanceLightNavigationBars = model.step != Step.Splash
        }
    }
    BackHandler(enabled = model.overlay == null && model.step.onSky && model.step.hasBack) { model.back() }

    val slidePx = with(LocalDensity.current) { 24.dp.roundToPx() }
    Box(Modifier.fillMaxSize().background(EQ.page)) {
        val skyAlpha by animateFloatAsState(if (model.step.onSky) 1f else 0f, tween(450), label = "sky")
        if (skyAlpha > 0f) Sky(Modifier.graphicsLayer { alpha = skyAlpha })

        val stage = when (model.step) { Step.Splash -> 0; Step.Home -> 2; else -> 1 }
        AnimatedContent(
            targetState = stage,
            transitionSpec = {
                when {
                    // The splash dissolves into the sky: grows 6 %, fades (the flow brings its own choreography).
                    initialState == 0 && targetState == 1 -> (EnterTransition.None togetherWith
                        (fadeOut(tween(760, easing = EQ.push)) + scaleOut(tween(760, easing = EQ.push), targetScale = 1.06f)))
                        .apply { targetContentZIndex = -1f }
                    // Home slides in 24 dp from the right as it fades up.
                    targetState == 2 -> (fadeIn(tween(320, easing = EQ.ease)) +
                        slideInHorizontally(tween(320, easing = EQ.ease)) { slidePx }) togetherWith ExitTransition.None
                    else -> fadeIn(tween(350)) togetherWith fadeOut(tween(350))
                }
            },
            label = "stage",
        ) { s ->
            when (s) {
                0 -> SplashScreen(model)
                1 -> FlowContainer(model)
                else -> HomeScreen(model)
            }
        }

        OverlayHost(model)
        ToastHost(model.toast)
    }
}

/**
 * The onboarding screens: a fixed top bar (back / skip) over the current screen, which pushes
 * in from the side. The orb isn't part of the screens: one shared orb glides between them.
 * Tapping anywhere that isn't a control puts the keyboard away.
 */
@Composable
private fun FlowContainer(model: AppModel) {
    val focus = LocalFocusManager.current
    Column(
        Modifier
            .fillMaxSize()
            .pointerInput(Unit) { detectTapGestures { focus.clearFocus() } }
            .statusBarsPadding()
            .navigationBarsPadding()
            .imePadding()
    ) {
        TopBar(model)
        Box(Modifier.weight(1f).fillMaxWidth().onGloballyPositioned { model.contentOrigin = it.positionInRoot() }) {
        OrbStage(model)
        AnimatedContent(
            targetState = model.step,
            transitionSpec = {
                // iOS-style push: the new screen slides in a full width; the old one drifts a third of the way and fades.
                val dir = model.direction
                slideInHorizontally(tween(560, easing = EQ.push)) { it * dir } togetherWith
                    (slideOutHorizontally(tween(504, easing = EQ.push)) { -(it * 0.32f * dir).toInt() } + fadeOut(tween(504, easing = EQ.push)))
            },
            modifier = Modifier.fillMaxSize(),
            label = "push",
        ) { st ->
            FlowScreen(model, st) {
                when (st) {
                    Step.Phone -> PhoneScreen(model)
                    Step.Otp -> OtpScreen(model)
                    Step.Name -> NameScreen(model)
                    Step.Cases -> CasesScreen(model)
                    Step.PermQ -> PermissionsScreen(model)
                    Step.Access -> AccessScreen(model)
                    Step.Welcome -> WelcomeScreen(model)
                    else -> Box(Modifier.fillMaxSize())
                }
            }
        }
        }
    }
}

/** Back on the left, Skip on the right. Swaps instantly (it doesn't slide with the screen). */
@Composable
private fun TopBar(model: AppModel) {
    Row(
        Modifier
            .fillMaxWidth()
            .height(58.dp)
            .padding(horizontal = 24.dp)
            .padding(top = 10.dp)
            .riseIn(model.arrivingFromSplash && model.step == Step.Phone, delayMs = 350, distance = (-8).dp, durationMs = 600),
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.SpaceBetween,
    ) {
        if (model.step.hasBack) BackButton { model.back() } else Spacer(Modifier.size(48.dp))
        if (model.step.skippable) SkipButton { model.skip() }
    }
}
