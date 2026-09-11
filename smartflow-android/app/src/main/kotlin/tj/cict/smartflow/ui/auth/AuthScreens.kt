package tj.cict.smartflow.ui.auth

import androidx.compose.animation.AnimatedVisibility
import androidx.compose.animation.expandVertically
import androidx.compose.animation.fadeIn
import androidx.compose.animation.fadeOut
import androidx.compose.animation.shrinkVertically
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.WindowInsets
import androidx.compose.foundation.layout.asPaddingValues
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.ime
import androidx.compose.foundation.layout.imePadding
import androidx.compose.foundation.layout.navigationBars
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.statusBars
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.text.BasicTextField
import androidx.compose.foundation.text.KeyboardActions
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.rounded.ArrowBack
import androidx.compose.material.icons.outlined.Lock
import androidx.compose.material.icons.outlined.Person
import androidx.compose.material.icons.outlined.Phone
import androidx.compose.material.icons.outlined.Visibility
import androidx.compose.material.icons.outlined.VisibilityOff
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.platform.LocalFocusManager
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.input.ImeAction
import androidx.compose.ui.text.input.KeyboardType
import androidx.compose.ui.text.input.PasswordVisualTransformation
import androidx.compose.ui.text.input.VisualTransformation
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import org.koin.androidx.compose.koinViewModel
import tj.cict.smartflow.R
import tj.cict.smartflow.core.network.ApiError
import tj.cict.smartflow.core.util.message
import tj.cict.smartflow.ui.components.AppTextField
import tj.cict.smartflow.ui.components.GhostButton
import tj.cict.smartflow.ui.components.Illustration
import tj.cict.smartflow.ui.components.PageBackground
import tj.cict.smartflow.ui.components.PrimaryButton
import tj.cict.smartflow.ui.components.RoundIconButton
import tj.cict.smartflow.ui.components.Segment
import tj.cict.smartflow.ui.components.SegmentRow
import tj.cict.smartflow.ui.components.SoftCard
import tj.cict.smartflow.ui.components.VSpace
import tj.cict.smartflow.ui.theme.Radius
import tj.cict.smartflow.ui.theme.smart

/** Illustration up top, a white card with the form below. All three auth screens share it. */
@Composable
private fun AuthFrame(
    illustration: Int,
    title: String,
    subtitle: String,
    onBack: (() -> Unit)? = null,
    content: @Composable () -> Unit,
) {
    val top = WindowInsets.statusBars.asPaddingValues().calculateTopPadding()
    val bottom = WindowInsets.navigationBars.asPaddingValues().calculateBottomPadding()
    PageBackground {
        Column(
            Modifier
                .fillMaxSize()
                .verticalScroll(rememberScrollState())
                .imePadding()
                .padding(top = top + 12.dp, bottom = bottom + 20.dp),
        ) {
            if (onBack != null) {
                Row(Modifier.padding(horizontal = 20.dp)) {
                    RoundIconButton(Icons.AutoMirrored.Rounded.ArrowBack, stringResource(R.string.back), onBack)
                }
            }
            Illustration(
                illustration,
                Modifier
                    .fillMaxWidth(0.8f)
                    .align(Alignment.CenterHorizontally)
                    .padding(top = if (onBack != null) 4.dp else 24.dp),
            )
            VSpace(4.dp)
            Column(Modifier.padding(horizontal = 28.dp)) {
                Text(title, style = MaterialTheme.typography.headlineLarge, color = MaterialTheme.smart.ink)
                VSpace(6.dp)
                Text(subtitle, style = MaterialTheme.typography.bodyLarge, color = MaterialTheme.smart.inkSecondary)
            }
            VSpace(20.dp)
            SoftCard(Modifier.padding(horizontal = 20.dp), contentPadding = androidx.compose.foundation.layout.PaddingValues(20.dp)) {
                content()
            }
        }
    }
}

@Composable
private fun ErrorLine(error: ApiError?) {
    AnimatedVisibility(error != null, enter = expandVertically() + fadeIn(), exit = shrinkVertically() + fadeOut()) {
        val c = MaterialTheme.smart
        Box(
            Modifier
                .fillMaxWidth()
                .padding(bottom = 12.dp)
                .clip(RoundedCornerShape(Radius.sm))
                .background(c.roseSoft)
                .padding(horizontal = 14.dp, vertical = 10.dp),
        ) {
            Text(error?.message().orEmpty(), style = MaterialTheme.typography.bodyMedium, color = c.rose, fontWeight = FontWeight.SemiBold)
        }
    }
}

// ================================================================ Login

@Composable
fun LoginScreen(onNeedsPassword: (String) -> Unit, vm: AuthViewModel = koinViewModel()) {
    val ui by vm.login.collectAsStateWithLifecycle()
    var showPassword by remember { mutableStateOf(false) }
    val focus = LocalFocusManager.current

    AuthFrame(R.drawable.ill_school, stringResource(R.string.login_title), stringResource(R.string.login_subtitle)) {
        SegmentRow(Modifier.fillMaxWidth()) {
            Segment(stringResource(R.string.role_parent), ui.tab == 0) { vm.setTab(0) }
            Segment(stringResource(R.string.role_student), ui.tab == 1) { vm.setTab(1) }
            Segment(stringResource(R.string.role_teacher), ui.tab == 2) { vm.setTab(2) }
            Segment(stringResource(R.string.role_director), ui.tab == 3) { vm.setTab(3) }
        }
        VSpace(16.dp)
        ErrorLine(ui.error)
        if (ui.school) {
            TeacherForm(ui, vm, showPassword, onTogglePassword = { showPassword = !showPassword })
        } else if (!ui.student) {
            AppTextField(
                value = ui.phone,
                onValueChange = vm::onPhone,
                label = stringResource(R.string.phone_label),
                leading = Icons.Outlined.Phone,
                keyboardOptions = KeyboardOptions(keyboardType = KeyboardType.Phone, imeAction = ImeAction.Next),
            )
            VSpace(12.dp)
            AppTextField(
                value = ui.password,
                onValueChange = vm::onPassword,
                label = stringResource(R.string.password_label),
                leading = Icons.Outlined.Lock,
                trailing = { EyeToggle(showPassword) { showPassword = !showPassword } },
                visualTransformation = if (showPassword) VisualTransformation.None else PasswordVisualTransformation(),
                keyboardOptions = KeyboardOptions(keyboardType = KeyboardType.Password, imeAction = ImeAction.Done),
                keyboardActions = KeyboardActions(onDone = { focus.clearFocus(); vm.submitLogin(onNeedsPassword) }),
            )
            VSpace(18.dp)
            PrimaryButton(
                stringResource(R.string.login_button),
                onClick = { focus.clearFocus(); vm.submitLogin(onNeedsPassword) },
                loading = ui.busy,
                enabled = ui.phone.digits().length >= 9,
            )
            VSpace(6.dp)
            // Same SMS flow as first sign-up: the server lets any registered
            // number ask for a code, and set-password overwrites the old one.
            Box(Modifier.fillMaxWidth(), contentAlignment = Alignment.Center) {
                GhostButton(
                    stringResource(R.string.login_forgot),
                    onClick = { focus.clearFocus(); onNeedsPassword(ui.phone.digits()) },
                    enabled = ui.phone.digits().length >= 9,
                )
            }
            VSpace(4.dp)
            Text(
                stringResource(R.string.login_first_time),
                style = MaterialTheme.typography.bodySmall,
                color = MaterialTheme.smart.inkTertiary,
                textAlign = TextAlign.Center,
                modifier = Modifier.fillMaxWidth(),
            )
        } else {
            AppTextField(
                value = ui.username,
                onValueChange = vm::onUsername,
                label = stringResource(R.string.username_label),
                leading = Icons.Outlined.Person,
                keyboardOptions = KeyboardOptions(keyboardType = KeyboardType.Text, imeAction = ImeAction.Next, autoCorrectEnabled = false),
            )
            VSpace(12.dp)
            AppTextField(
                value = ui.studentPassword,
                onValueChange = vm::onStudentPassword,
                label = stringResource(R.string.password_label),
                leading = Icons.Outlined.Lock,
                trailing = { EyeToggle(showPassword) { showPassword = !showPassword } },
                visualTransformation = if (showPassword) VisualTransformation.None else PasswordVisualTransformation(),
                keyboardOptions = KeyboardOptions(keyboardType = KeyboardType.Password, imeAction = ImeAction.Done),
                keyboardActions = KeyboardActions(onDone = { focus.clearFocus(); vm.submitStudentLogin() }),
            )
            VSpace(18.dp)
            PrimaryButton(
                stringResource(R.string.login_button),
                onClick = { focus.clearFocus(); vm.submitStudentLogin() },
                loading = ui.busy,
                enabled = ui.username.isNotBlank() && ui.studentPassword.isNotEmpty(),
            )
            VSpace(14.dp)
            Text(
                stringResource(R.string.student_login_hint),
                style = MaterialTheme.typography.bodySmall,
                color = MaterialTheme.smart.inkTertiary,
                textAlign = TextAlign.Center,
                modifier = Modifier.fillMaxWidth(),
            )
        }
    }
}

@Composable
private fun TeacherForm(ui: LoginUi, vm: AuthViewModel, showPassword: Boolean, onTogglePassword: () -> Unit) {
    val c = MaterialTheme.smart
    val focus = LocalFocusManager.current
    AppTextField(
        value = ui.email, onValueChange = vm::onEmail, label = stringResource(R.string.email_label), leading = Icons.Outlined.Person,
        keyboardOptions = KeyboardOptions(keyboardType = KeyboardType.Email, imeAction = ImeAction.Next, autoCorrectEnabled = false),
    )
    VSpace(12.dp)
    AppTextField(
        value = ui.teacherPassword, onValueChange = vm::onTeacherPassword, label = stringResource(R.string.password_label), leading = Icons.Outlined.Lock,
        trailing = { EyeToggle(showPassword, onTogglePassword) },
        visualTransformation = if (showPassword) VisualTransformation.None else PasswordVisualTransformation(),
        keyboardOptions = KeyboardOptions(keyboardType = KeyboardType.Password, imeAction = ImeAction.Done),
        keyboardActions = KeyboardActions(onDone = { focus.clearFocus(); vm.submitTeacherLogin() }),
    )
    VSpace(18.dp)
    PrimaryButton(
        stringResource(R.string.login_button), onClick = { focus.clearFocus(); vm.submitTeacherLogin() }, loading = ui.busy,
        enabled = ui.email.isNotBlank() && ui.teacherPassword.isNotEmpty(),
    )
    VSpace(14.dp)
    Text(if (ui.director) stringResource(R.string.director_login_hint) else stringResource(R.string.teacher_login_hint), style = MaterialTheme.typography.bodySmall, color = c.inkTertiary, textAlign = TextAlign.Center, modifier = Modifier.fillMaxWidth())
}

@Composable
private fun EyeToggle(shown: Boolean, onToggle: () -> Unit) {
    IconButton(onClick = onToggle) {
        Icon(if (shown) Icons.Outlined.VisibilityOff else Icons.Outlined.Visibility, null, tint = MaterialTheme.smart.inkTertiary)
    }
}

// =============================================================== Verify

@Composable
fun VerifyScreen(
    phone: String,
    onBack: () -> Unit,
    onVerified: (setupToken: String, fullName: String) -> Unit,
    vm: AuthViewModel = koinViewModel(),
) {
    val ui by vm.verify.collectAsStateWithLifecycle()
    LaunchedEffect(phone) { vm.requestCode(phone) }

    val shown = ui.phoneMasked.ifEmpty { "+$phone" }
    AuthFrame(R.drawable.ill_phone_sms, stringResource(R.string.verify_title), stringResource(R.string.verify_subtitle, shown), onBack) {
        ErrorLine(ui.error)
        if (!ui.delivered) {
            val c = MaterialTheme.smart
            Box(
                Modifier.fillMaxWidth().padding(bottom = 12.dp).clip(RoundedCornerShape(Radius.sm)).background(c.amberSoft).padding(14.dp, 10.dp),
            ) {
                Text(stringResource(R.string.verify_not_delivered), style = MaterialTheme.typography.bodyMedium, color = c.amber, fontWeight = FontWeight.SemiBold)
            }
        }
        CodeBoxes(ui.code, vm::onCode, onDone = { vm.submitCode(phone, onVerified) })
        VSpace(18.dp)
        PrimaryButton(
            stringResource(R.string.verify_button),
            onClick = { vm.submitCode(phone, onVerified) },
            loading = ui.busy,
            enabled = ui.code.length == 6,
        )
        VSpace(6.dp)
        Box(Modifier.fillMaxWidth(), contentAlignment = Alignment.Center) {
            GhostButton(
                text = if (ui.resendIn > 0) stringResource(R.string.verify_resend_in, ui.resendIn) else stringResource(R.string.verify_resend),
                onClick = { vm.requestCode(phone) },
                enabled = ui.resendIn == 0 && !ui.sending,
            )
        }
    }
}

/** Six boxes drawn over one invisible text field, so paste and autofill still work. */
@Composable
private fun CodeBoxes(code: String, onChange: (String) -> Unit, onDone: () -> Unit) {
    val c = MaterialTheme.smart
    BasicTextField(
        value = code,
        onValueChange = onChange,
        keyboardOptions = KeyboardOptions(keyboardType = KeyboardType.NumberPassword, imeAction = ImeAction.Done),
        keyboardActions = KeyboardActions(onDone = { onDone() }),
        singleLine = true,
        decorationBox = {
            Row(Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                repeat(6) { i ->
                    val ch = code.getOrNull(i)?.toString().orEmpty()
                    val active = i == code.length
                    Box(
                        Modifier
                            .weight(1f)
                            .height(56.dp)
                            .clip(RoundedCornerShape(Radius.sm))
                            .background(if (ch.isNotEmpty()) c.brandTint else c.surfaceSoft)
                            .border(1.5.dp, if (active) c.brand else if (ch.isNotEmpty()) c.brandSoft else c.border, RoundedCornerShape(Radius.sm)),
                        contentAlignment = Alignment.Center,
                    ) {
                        Text(ch, style = MaterialTheme.typography.headlineSmall, color = c.brandDeep)
                    }
                }
            }
        },
    )
}

// ========================================================== Set password

@Composable
fun SetPasswordScreen(setupToken: String, initialName: String, onBack: () -> Unit, vm: AuthViewModel = koinViewModel()) {
    val ui by vm.setup.collectAsStateWithLifecycle()
    LaunchedEffect(initialName) { vm.seedName(initialName) }
    var showPassword by remember { mutableStateOf(false) }
    val focus = LocalFocusManager.current

    AuthFrame(R.drawable.ill_shield, stringResource(R.string.setup_title), stringResource(R.string.setup_subtitle), onBack) {
        ErrorLine(ui.error)
        AppTextField(
            value = ui.name,
            onValueChange = vm::onName,
            label = stringResource(R.string.setup_name),
            leading = Icons.Outlined.Person,
            keyboardOptions = KeyboardOptions(keyboardType = KeyboardType.Text, imeAction = ImeAction.Next),
        )
        VSpace(12.dp)
        AppTextField(
            value = ui.password,
            onValueChange = vm::onNewPassword,
            label = stringResource(R.string.setup_password),
            leading = Icons.Outlined.Lock,
            trailing = {
                IconButton(onClick = { showPassword = !showPassword }) {
                    Icon(if (showPassword) Icons.Outlined.VisibilityOff else Icons.Outlined.Visibility, null, tint = MaterialTheme.smart.inkTertiary)
                }
            },
            visualTransformation = if (showPassword) VisualTransformation.None else PasswordVisualTransformation(),
            keyboardOptions = KeyboardOptions(keyboardType = KeyboardType.Password, imeAction = ImeAction.Done),
            keyboardActions = KeyboardActions(onDone = { focus.clearFocus(); vm.submitSetup(setupToken) }),
        )
        VSpace(18.dp)
        PrimaryButton(
            stringResource(R.string.setup_button),
            onClick = { focus.clearFocus(); vm.submitSetup(setupToken) },
            loading = ui.busy,
            enabled = ui.password.length >= 4,
        )
    }
}
