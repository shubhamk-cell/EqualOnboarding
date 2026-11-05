package ai.equal.orb

import android.os.Bundle
import androidx.activity.ComponentActivity
import androidx.activity.compose.setContent
import androidx.activity.enableEdgeToEdge

class MainActivity : ComponentActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        enableEdgeToEdge()
        // Debug builds: `adb shell am start -n ai.equal.onboarding.orbbubble/ai.equal.orb.MainActivity --es startStep access`
        val start = if (BuildConfig.DEBUG) intent.getStringExtra("startStep") else null
        setContent { OrbApp(start) }
    }
}
