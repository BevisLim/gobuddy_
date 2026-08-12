import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../model/user_account_model.dart';
import 'view_model/user_account_view_model.dart';

// ==========================================================================
// 🎨 Core Style Tokens (Sourced directly from the base fork design specs)
// ==========================================================================
const _ink = Color(0xFF281950);
const _violet = Color(0xFF7C3AED);
const _border = Color(0xFFD5CFEF);
const _muted = Color(0xFF686082);

const _heading = TextStyle(
  fontFamily: 'Georgia',
  color: _ink,
  fontSize: 24,
  fontWeight: FontWeight.w600,
  letterSpacing: -.6,
);

const _label = TextStyle(
  color: _muted,
  fontSize: 11,
  fontWeight: FontWeight.w700,
  letterSpacing: .5,
);

BoxDecoration _cardDecoration({double radius = 16, bool feed = false}) =>
    BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(color: _border),
        boxShadow: [
          BoxShadow(
              color: (feed ? _ink : Colors.black)
                  .withValues(alpha: feed ? .12 : .08),
              blurRadius: feed ? 40 : 25,
              offset: feed ? const Offset(0, 8) : const Offset(0, 2))
        ]);

// ==========================================================================
// 🛡️ Main Module Screen Container
// ==========================================================================
class UserAccountScreen extends ConsumerWidget {
  const UserAccountScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(userAccountViewModelProvider);
    final viewModel = ref.read(userAccountViewModelProvider.notifier);

    return Scaffold(
      backgroundColor: const Color(0xFFF7F5FB),
      body: SafeArea(
        child: state.isLoading && state.user == null
            ? const Center(child: CircularProgressIndicator(color: _violet))
            : switch (state.page) {
                UserAccountPage.profile => _AccountDashboardView(
                    user: state.user,
                    onNavigate: viewModel.goTo,
                  ),
                UserAccountPage.editProfile => _AccountEditView(
                    initialName: state.user?.name ?? '',
                    isSaving: state.isLoading,
                    onBack: () => viewModel.goTo(UserAccountPage.profile),
                    onSave: viewModel.updateProfileName,
                  ),
                UserAccountPage.settings => _AccountStaticFrame(
                    title: 'Settings',
                    subtitle: 'PREFERENCES',
                    description: 'Configure push notifications, local database synchronization states, and systemic aesthetic variables.',
                    onBack: () => viewModel.goTo(UserAccountPage.profile),
                  ),
                UserAccountPage.security => _AccountStaticFrame(
                    title: 'Security',
                    subtitle: 'ACCESS MANAGEMENT',
                    description: 'Manage active authorization keys, session duration thresholds, and multi-factor validation credentials.',
                    onBack: () => viewModel.goTo(UserAccountPage.profile),
                  ),
              },
      ),
    );
  }
}

// ==========================================================================
// 👤 Sub-View: Main Profile Dashboard
// ==========================================================================
class _AccountDashboardView extends StatelessWidget {
  final dynamic user; 
  final ValueChanged<UserAccountPage> onNavigate;

  const _AccountDashboardView({required this.user, required this.onNavigate});

  @override
  Widget build(BuildContext context) {
    final String initials = user != null && user.name.trim().isNotEmpty
        ? user.name.trim().split(' ').map((e) => e[0]).take(2).join().toUpperCase()
        : 'U';

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 32, 20, 40),
      children: [
        Center(
          child: Column(
            children: [
              Container(
                width: 88,
                height: 88,
                decoration: BoxDecoration(
                  color: const Color(0xFFEDE9FE),
                  shape: BoxShape.circle,
                  border: Border.all(color: _border, width: 2),
                ),
                alignment: Alignment.center,
                child: Text(
                  initials,
                  style: const TextStyle(color: _violet, fontSize: 30, fontWeight: FontWeight.bold),
                ),
              ),
              const SizedBox(height: 16),
              Text(user?.name ?? 'Guest User', style: _heading),
              const SizedBox(height: 4),
              Text(user?.email ?? 'no-session@gobuddy.app', style: const TextStyle(color: _muted, fontSize: 14)),
              if (user != null && user.phoneNumber.isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(user.phoneNumber, style: const TextStyle(color: _muted, fontSize: 13)),
              ]
            ],
          ),
        ),
        const SizedBox(height: 36),
        _AccountMenuTile(
          icon: Icons.face_retouching_natural_outlined,
          title: 'Update display name details',
          onTap: () => onNavigate(UserAccountPage.editProfile),
        ),
        _AccountMenuTile(
          icon: Icons.tune_rounded,
          title: 'System & app configurations',
          onTap: () => onNavigate(UserAccountPage.settings),
        ),
        _AccountMenuTile(
          icon: Icons.shield_outlined,
          title: 'Security keys & validation setups',
          onTap: () => onNavigate(UserAccountPage.security),
        ),
      ],
    );
  }
}

// ==========================================================================
// 📝 Sub-View: Edit Account Information Input Form
// ==========================================================================
class _AccountEditView extends StatefulWidget {
  final String initialName;
  final bool isSaving;
  final VoidCallback onBack;
  final ValueChanged<String> onSave;

  const _AccountEditView({
    required this.initialName,
    required this.isSaving,
    required this.onBack,
    required this.onSave,
  });

  @override
  State<_AccountEditView> createState() => _AccountEditViewState();
}

class _AccountEditViewState extends State<_AccountEditView> {
  late final TextEditingController _nameController;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.initialName);
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return _AccountLayoutWrapper(
      title: 'Edit Profile',
      onBack: widget.onBack,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('FULL NAME', style: _label),
          const SizedBox(height: 8),
          TextField(
            controller: _nameController,
            enabled: !widget.isSaving,
            decoration: InputDecoration(
              filled: true,
              fillColor: Colors.white,
              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(color: _border),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(color: _border),
              ),
            ),
          ),
          const SizedBox(height: 32),
          InkWell(
            onTap: widget.isSaving ? null : () => widget.onSave(_nameController.text.trim()),
            borderRadius: BorderRadius.circular(12),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 16),
              decoration: BoxDecoration(
                color: widget.isSaving ? _muted : _violet,
                borderRadius: BorderRadius.circular(12),
              ),
              alignment: Alignment.center,
              child: widget.isSaving
                  ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                  : const Text('Save Changes', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
            ),
          ),
        ],
      ),
    );
  }
}

// ==========================================================================
// ⚙️ Sub-View: Static Placeholder Sub-page Frame
// ==========================================================================
class _AccountStaticFrame extends StatelessWidget {
  final String title;
  final String subtitle;
  final String description;
  final VoidCallback onBack;

  const _AccountStaticFrame({
    required this.title,
    required this.subtitle,
    required this.description,
    required this.onBack,
  });

  @override
  Widget build(BuildContext context) {
    return _AccountLayoutWrapper(
      title: title,
      onBack: onBack,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(subtitle, style: _label),
          const SizedBox(height: 12),
          Text(description, style: const TextStyle(color: _muted, height: 1.6, fontSize: 14)),
        ],
      ),
    );
  }
}

// ==========================================================================
// 🛠️ Local Internal Primitive Micro-Components
// ==========================================================================
class _AccountLayoutWrapper extends StatelessWidget {
  final String title;
  final VoidCallback onBack;
  final Widget child;

  const _AccountLayoutWrapper({required this.title, required this.onBack, required this.child});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back_ios_new_rounded, color: _ink, size: 20),
            onPressed: onBack,
          ),
          const SizedBox(height: 16),
          Text(title, style: _heading),
          const SizedBox(height: 24),
          Expanded(child: child),
        ],
      ),
    );
  }
}

class _AccountMenuTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final VoidCallback onTap;

  const _AccountMenuTile({required this.icon, required this.title, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: _cardDecoration(),
      child: ListTile(
        leading: Icon(icon, color: _violet, size: 22),
        title: Text(title, style: const TextStyle(color: _ink, fontWeight: FontWeight.w600, fontSize: 14)),
        trailing: const Icon(Icons.chevron_right_rounded, color: _muted),
        onTap: onTap,
        dense: true,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
    );
  }
}