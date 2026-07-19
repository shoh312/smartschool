import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../core/design_tokens.dart';
import '../providers/auth_provider.dart';
import '../routes/app_routes.dart';
import 'package:smartschool_app/generated/app_localizations.dart';

class RegistrationDetailsScreen extends StatefulWidget {
  final String phoneNumber;

  const RegistrationDetailsScreen({super.key, required this.phoneNumber});

  @override
  State<RegistrationDetailsScreen> createState() => _RegistrationDetailsScreenState();
}

class _RegistrationDetailsScreenState extends State<RegistrationDetailsScreen> {
  final _nameController = TextEditingController();

  Future<void> _completeRegistration() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) return;

    final success = await context.read<AuthProvider>().registerParent(widget.phoneNumber, name);
    if (success && mounted) {
      Navigator.pushNamedAndRemoveUntil(context, AppRoutes.parentDashboard, (route) => false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context)!;
    
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(l10n.createAccount),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: 12),
            Center(
              child: Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: AppGradients.primary,
                  shape: BoxShape.circle,
                  boxShadow: AppShadows.colored(AppColors.primary),
                ),
                child: const Icon(Icons.person_add_alt_1_rounded, size: 40, color: Colors.white),
              ),
            ),
            const SizedBox(height: 28),
            Text(
              l10n.lastStep,
              style: theme.textTheme.headlineLarge,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 10),
            Text(
              l10n.tellUsName(widget.phoneNumber),
              style: theme.textTheme.bodyMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: AppRadius.xlRadius,
                border: Border.all(color: AppColors.border),
                boxShadow: AppShadows.raised,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  TextField(
                    controller: _nameController,
                    autofocus: true,
                    textCapitalization: TextCapitalization.words,
                    decoration: InputDecoration(
                      labelText: l10n.fullName,
                      hintText: l10n.fullNameHint,
                      prefixIcon: const Icon(Icons.person_outline_rounded, size: 20),
                    ),
                    onSubmitted: (_) => _completeRegistration(),
                  ),
                  const SizedBox(height: 24),
                  ElevatedButton(
                    onPressed: _completeRegistration,
                    child: Text(l10n.completeRegistration),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            Text(
              l10n.termsAndPrivacy,
              style: theme.textTheme.bodySmall?.copyWith(color: AppColors.textMuted),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
