package tj.cict.smartflow

import android.os.Bundle
import androidx.activity.compose.setContent
import androidx.activity.enableEdgeToEdge
import androidx.appcompat.app.AppCompatActivity
import androidx.core.splashscreen.SplashScreen.Companion.installSplashScreen
import tj.cict.smartflow.ui.navigation.AppRoot
import tj.cict.smartflow.ui.theme.SmartFlowTheme

// AppCompatActivity rather than ComponentActivity: per-app language on
// Android 12 and below goes through AppCompatDelegate, and that only works
// from an AppCompat activity.
class MainActivity : AppCompatActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        installSplashScreen()
        super.onCreate(savedInstanceState)
        enableEdgeToEdge()
        // Portrait by default; the live-video screen flips this for itself.
        requestedOrientation = android.content.pm.ActivityInfo.SCREEN_ORIENTATION_PORTRAIT
        setContent {
            SmartFlowTheme {
                AppRoot()
            }
        }
    }
}
