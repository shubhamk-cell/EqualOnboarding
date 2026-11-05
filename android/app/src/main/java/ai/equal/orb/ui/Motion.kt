package ai.equal.orb.ui

import androidx.compose.animation.core.Animatable
import androidx.compose.animation.core.LinearOutSlowInEasing
import androidx.compose.animation.core.tween
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.setValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.composed
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.graphics.graphicsLayer
import androidx.compose.ui.layout.boundsInRoot
import androidx.compose.ui.layout.onGloballyPositioned
import kotlinx.coroutines.launch

/** The orb glides in from where the splash mark was (root coordinates, px), growing as it fades up. */
fun Modifier.flyIn(from: Offset?, fromScale: Float = 0.68f): Modifier = composed {
    if (from == null) return@composed this
    val scope = rememberCoroutineScope()
    val progress = remember { Animatable(0f) }
    val alpha = remember { Animatable(0f) }
    var delta by remember { mutableStateOf(Offset.Zero) }
    var measured by remember { mutableStateOf(false) }
    this
        .onGloballyPositioned { c ->
            if (measured) return@onGloballyPositioned
            measured = true
            delta = from - c.boundsInRoot().center
            scope.launch { progress.animateTo(1f, tween(1000, easing = EQ.push)) }
            scope.launch { alpha.animateTo(1f, tween(350, easing = LinearOutSlowInEasing)) }
        }
        .graphicsLayer {
            val v = progress.value
            translationX = delta.x * (1 - v)
            translationY = delta.y * (1 - v)
            scaleX = fromScale + (1 - fromScale) * v
            scaleY = scaleX
            this.alpha = alpha.value
        }
}
