package ai.equal.orb.model

import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableIntStateOf
import androidx.compose.runtime.mutableStateListOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.setValue
import ai.equal.orb.ui.OrbFlight
import ai.equal.orb.ui.OrbPlay
import ai.equal.orb.ui.OrbSpot
import android.Manifest
import android.content.Context
import android.content.pm.PackageManager
import android.os.Build
import androidx.compose.ui.geometry.Offset
import androidx.core.app.NotificationManagerCompat
import androidx.core.content.ContextCompat
import kotlinx.coroutines.CompletableDeferred
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Job
import kotlinx.coroutines.delay
import kotlinx.coroutines.launch

/**
 * Every stop on the Android journey, in order (the prototype's Android branch): after the code
 * is confirmed the flow runs name → picks (with sample calls) → permissions → call forwarding
 * over USSD → welcome → home. There is no tracking prompt and no Live Voicemail step on Android.
 */
enum class Step {
    Splash, Phone, Otp, Name, Cases, PermQ, Access, Welcome, Home;

    /** Steps with a Skip button in the top bar. */
    val skippable get() = this == Cases || this == PermQ
    val hasBack get() = this != Phone && this != Welcome
    val onSky get() = this != Splash && this != Home
}

enum class Permission { Notifications, Contacts }

/** The 3D art for whatever is missing: a bell, a contacts book, or a gear for both. */
val List<Permission>.art: Int
    get() = when {
        size > 1 -> ai.equal.orb.R.drawable.perm_gear
        firstOrNull() == Permission.Notifications -> ai.equal.orb.R.drawable.perm_bell
        else -> ai.equal.orb.R.drawable.perm_contacts
    }

/** Modal surfaces drawn above the flow. */
sealed interface Overlay {
    data object Consent : Overlay
    /** Equal's sheet after the system prompts, for whichever permissions were refused. */
    data class Decline(val missing: List<Permission>) : Overlay
    data class Ussd(val case: String) : Overlay
}

class AppModel(private val scope: CoroutineScope) {
    var step by mutableStateOf(Step.Splash)
    /** +1 pushes forward (new screen from the right), −1 goes back. */
    var direction by mutableIntStateOf(1)
    /** True only for the first screen after the splash, which arrives with its own choreography. */
    var arrivingFromSplash by mutableStateOf(false)
    /** Where the splash's Equal mark was on screen when it left (root coordinates, px). */
    var splashMark: Offset? = null

    var phone by mutableStateOf("")
    var name by mutableStateOf("")
    var whatsapp by mutableStateOf(true)
    val picks = mutableStateListOf<String>()
    var consentAsked = false
    /** One tick per forwarding case (busy / unanswered / unreachable). */
    val forwarded = mutableStateListOf(false, false, false)
    var fwdDone by mutableStateOf(false)
    /** Notifications, contacts: granted? (null = not asked yet, which counts as off too.) */
    var perms by mutableStateOf(listOf<Boolean?>(null, null))

    /** The flow's one orb: where it sits, what tapping it does, and whether it's fading away. */
    var orbSpot by mutableStateOf<OrbSpot?>(null)
    var orbLeaving by mutableStateOf(false)
    var orbOnPlay: ((OrbPlay) -> Unit)? = null
    /** Top-left of the flow's screen area in root coordinates (to place the splash mark in it). */
    var contentOrigin = Offset.Zero

    var overlay by mutableStateOf<Overlay?>(null)
    var toast by mutableStateOf<String?>(null)
    private var toastJob: Job? = null
    private var pending: CompletableDeferred<String>? = null

    val displayName get() = name.ifBlank { "Keshav" }

    // MARK: Navigation

    fun go(to: Step, dir: Int = 1) {
        direction = dir
        arrivingFromSplash = false
        if (to != Step.Home) OrbFlight.departing()
        step = to
    }

    fun next() {
        val all = Step.entries
        all.getOrNull(step.ordinal + 1)?.let { go(it) }
    }

    fun back() {
        when (step) {
            Step.Otp -> go(Step.Phone, -1)
            Step.Name -> go(Step.Home)          // first setup question: leaving it goes home, as in the prototype
            Step.Cases -> go(Step.Name, -1)
            Step.PermQ -> go(Step.Cases, -1)
            Step.Access -> go(Step.PermQ, -1)
            else -> {}
        }
    }

    fun skip() = next()

    /** Starts the whole thing again (long-press the logo on Home). */
    fun restart() {
        phone = ""; name = ""; whatsapp = true; picks.clear()
        consentAsked = false; fwdDone = false
        for (i in forwarded.indices) forwarded[i] = false
        overlay = null; toast = null
        orbSpot = null; orbLeaving = false
        arrivingFromSplash = false; direction = 1
        step = Step.Splash
    }

    // MARK: Orb

    fun place(spot: OrbSpot) {
        if (spot != orbSpot) orbSpot = spot
    }

    /** The splash mark in the flow's coordinates, once (the orb's first flight starts there). */
    fun takeSplashStart(): Offset? = splashMark?.let { it - contentOrigin }.also { splashMark = null }

    // MARK: Permissions

    /** Permissions still off. */
    val missingPermissions: List<Permission>
        get() = (if (perms[0] == true) emptyList() else listOf(Permission.Notifications)) +
            (if (perms[1] == true) emptyList() else listOf(Permission.Contacts))

    /** Reads what Android actually has granted (it may have changed in Settings). */
    fun refreshPermissions(context: Context) {
        val notifications = if (Build.VERSION.SDK_INT >= 33)
            ContextCompat.checkSelfPermission(context, Manifest.permission.POST_NOTIFICATIONS) == PackageManager.PERMISSION_GRANTED
        else NotificationManagerCompat.from(context).areNotificationsEnabled()
        val contacts = ContextCompat.checkSelfPermission(context, Manifest.permission.READ_CONTACTS) == PackageManager.PERMISSION_GRANTED
        perms = listOf(notifications, contacts)
    }

    // MARK: Overlays

    /** Shows an overlay and waits until it is resolved with a result string. */
    suspend fun present(o: Overlay): String {
        pending?.complete("superseded")
        val d = CompletableDeferred<String>()
        pending = d
        overlay = o
        return d.await()
    }

    fun resolve(result: String) {
        val d = pending
        pending = null
        overlay = null
        d?.complete(result)
    }

    /** Equal's own consent for processing call data. Asked once. */
    suspend fun askConsentOnce() {
        if (consentAsked) return
        consentAsked = true
        if (present(Overlay.Consent) != "allow") {
            showToast("You can turn this on later in Settings — Equal can’t answer calls without it")
        }
    }

    fun showToast(text: String) {
        toastJob?.cancel()
        toast = text
        toastJob = scope.launch { delay(1800); toast = null }
    }
}
