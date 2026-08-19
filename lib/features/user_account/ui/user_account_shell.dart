import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/routing/routes.dart';
import '../../common/ui/widgets/app_module_navigation.dart';
import '../model/user_account_model.dart';
import 'view_model/user_account_view_model.dart';

// ==========================================================================
// 🎨 Core Style Tokens (Sourced directly from the base fork design specs)
// ==========================================================================
const _ink = Color(0xFF281950);
const _violet = Color(0xFF7C3AED);
const _border = Color(0xFFD5CFEF);
const _muted = Color(0xFF686082);
const _bgSubtle = Color(0xFFF7F5FB);
const _surface = Colors.white;

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
                    user: state.user!,
                    isSaving: state.isLoading,
                    onBack: () => viewModel.goTo(UserAccountPage.profile),
                    onSave: viewModel.updateProfile,
                    onSelectImage: viewModel.selectProfileImage,
                    onVerify: () => context.push(Routes.identityVerification),
                  ),
                UserAccountPage.security => _AccountStaticFrame(
                    title: 'Security',
                    subtitle: 'ACCESS MANAGEMENT',
                    description:
                        'Manage active authorization keys, session duration thresholds, and multi-factor validation credentials.',
                    onBack: () => viewModel.goTo(UserAccountPage.profile),
                  ),
              },
      ),
      bottomNavigationBar: state.page == UserAccountPage.profile
          ? const AppModuleNavigation(selectedIndex: 4)
          : null,
    );
  }
}

// ==========================================================================
// 👤 Sub-View: Main Profile Dashboard
// ==========================================================================
class _AccountDashboardView extends StatelessWidget {
  final UserAccount? user;
  final ValueChanged<UserAccountPage> onNavigate;

  const _AccountDashboardView({required this.user, required this.onNavigate});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.only(bottom: 32),
      children: [
        _ProfileHeader(
          user: user,
          onBack: () => Navigator.maybePop(context),
          onSettings: () => context.push(Routes.settings),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
          child: _ProfileStatsCard(
            onEdit: () => onNavigate(UserAccountPage.editProfile),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
          child: _AccountMenuTile(
            icon: Icons.health_and_safety_outlined,
            title: 'Emergency contacts',
            onTap: () => context.push(Routes.emergencyContacts),
          ),
        ),
        const Padding(
          padding: EdgeInsets.fromLTRB(16, 16, 16, 0),
          child: _ProfilePhotosCard(),
        ),
        const Padding(
          padding: EdgeInsets.fromLTRB(16, 16, 16, 0),
          child: _ProfileAboutCard(),
        ),
        const Padding(
          padding: EdgeInsets.fromLTRB(16, 16, 16, 0),
          child: _ProfileInterestsCard(),
        ),
      ],
    );
  }
}

class _ProfileHeader extends StatelessWidget {
  final UserAccount? user;
  final VoidCallback onBack;
  final VoidCallback onSettings;

  const _ProfileHeader({
    required this.user,
    required this.onBack,
    required this.onSettings,
  });

  @override
  Widget build(BuildContext context) => SizedBox(
        height: 350,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            SizedBox(
              height: 285,
              width: double.infinity,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  Image(
                    image: _accountImageProvider(
                      user?.backgroundPhoto,
                      fallback: _coverPhotoUrl,
                    ),
                    fit: BoxFit.cover,
                  ),
                  const DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [Colors.transparent, Color(0x99281950)],
                      ),
                    ),
                  ),
                  Positioned(
                    top: 14,
                    left: 16,
                    child: _FrostedIconButton(
                      icon: Icons.arrow_back_rounded,
                      onTap: onBack,
                    ),
                  ),
                  const Positioned(
                    top: 14,
                    right: 62,
                    child: _FrostedIconButton(
                      icon: Icons.notifications_none_rounded,
                    ),
                  ),
                  Positioned(
                    top: 14,
                    right: 16,
                    child: _FrostedIconButton(
                      icon: Icons.settings_outlined,
                      onTap: onSettings,
                    ),
                  ),
                  Positioned(
                    left: 16,
                    right: 16,
                    bottom: 24,
                    child: Column(
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Flexible(
                              child: Text(
                                user?.fullName ??
                                    user?.username ??
                                    'Guest User',
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontFamily: 'Georgia',
                                  color: Colors.white,
                                  fontSize: 25,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                            if (user?.isVerified == true) ...[
                              const SizedBox(width: 7),
                              const _VerifiedBadge(),
                            ],
                          ],
                        ),
                        const SizedBox(height: 6),
                        Text(
                            user?.gender == null
                                ? 'Profile details not added'
                                : user!.gender!,
                            style: const TextStyle(
                                color: Color(0xE6FFFFFF),
                                fontWeight: FontWeight.w600)),
                        const SizedBox(height: 3),
                        const Text('Joined January 2023',
                            style: TextStyle(
                                color: Color(0xB3FFFFFF), fontSize: 12)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Positioned(
              top: 205,
              left: 0,
              right: 0,
              child: Center(
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Container(
                      width: 112,
                      height: 112,
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                            color: const Color(0x59FFFFFF), width: 3),
                        boxShadow: const [
                          BoxShadow(
                              color: _violet, blurRadius: 0, spreadRadius: 4)
                        ],
                      ),
                      child: ClipOval(
                        child: Image(
                          image: _accountImageProvider(
                            user?.profilePhoto,
                            fallback: 'assets/images/avatar.webp',
                          ),
                          fit: BoxFit.cover,
                        ),
                      ),
                    ),
                    Positioned(
                      right: -2,
                      bottom: 1,
                      child: Container(
                        width: 32,
                        height: 32,
                        decoration: BoxDecoration(
                          color: _violet,
                          shape: BoxShape.circle,
                          border: Border.all(color: _surface, width: 2),
                        ),
                        child: const Icon(Icons.camera_alt_outlined,
                            color: Colors.white, size: 16),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      );
}

class _ProfileStatsCard extends StatelessWidget {
  final VoidCallback onEdit;
  const _ProfileStatsCard({required this.onEdit});

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(18),
        decoration: _cardDecoration(),
        child: Column(children: [
          const Row(children: [
            Expanded(child: _ProfileStat(number: '12', label: 'TRIPS')),
            SizedBox(height: 38, child: VerticalDivider(color: _border)),
            Expanded(child: _ProfileStat(number: '8', label: 'CITIES')),
          ]),
          const SizedBox(height: 18),
          SizedBox(
            width: double.infinity,
            height: 50,
            child: FilledButton(
              onPressed: onEdit,
              style: FilledButton.styleFrom(
                backgroundColor: _violet,
                foregroundColor: Colors.white,
                shape: const StadiumBorder(),
              ),
              child: const Text('Edit Profile',
                  style: TextStyle(fontWeight: FontWeight.w700)),
            ),
          ),
        ]),
      );
}

class _ProfileStat extends StatelessWidget {
  final String number;
  final String label;
  const _ProfileStat({required this.number, required this.label});

  @override
  Widget build(BuildContext context) => Column(children: [
        Text(number,
            style: const TextStyle(
                fontFamily: 'Georgia',
                fontSize: 22,
                color: _ink,
                fontWeight: FontWeight.w600)),
        Text(label, style: _label),
      ]);
}

class _AccountMenuTile extends StatelessWidget {
  const _AccountMenuTile({
    required this.icon,
    required this.title,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Ink(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
            decoration: _cardDecoration(),
            child: Row(
              children: [
                Icon(icon, color: _violet),
                const SizedBox(width: 14),
                Expanded(
                  child: Text(
                    title,
                    style: const TextStyle(
                      color: _ink,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                const Icon(
                  Icons.chevron_right_rounded,
                  color: _muted,
                ),
              ],
            ),
          ),
        ),
      );
}

class _ProfilePhotosCard extends StatelessWidget {
  const _ProfilePhotosCard();

  @override
  Widget build(BuildContext context) => _ProfileCard(
        title: 'Photos',
        child: Column(children: const [
          _PhotoSlot(url: _galleryPhotoOne, height: 170),
          SizedBox(height: 10),
          Row(children: [
            Expanded(child: _PhotoSlot(url: _galleryPhotoTwo, height: 112)),
            SizedBox(width: 10),
            Expanded(child: _PhotoSlot(url: _galleryPhotoThree, height: 112)),
          ]),
        ]),
      );
}

class _ProfileAboutCard extends StatelessWidget {
  const _ProfileAboutCard();

  @override
  Widget build(BuildContext context) => const _ProfileCard(
        title: 'About Me',
        child: Text(
          'I enjoy slow mornings, good local food, and finding the small places that make every trip memorable. Always happy to share an itinerary or discover somewhere new together.',
          style: TextStyle(color: _muted, height: 1.7),
        ),
      );
}

class _ProfileInterestsCard extends StatelessWidget {
  const _ProfileInterestsCard();

  @override
  Widget build(BuildContext context) => _ProfileCard(
        title: 'Style & Interests',
        edit: false,
        child: const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('TRAVEL STYLE', style: _label),
              SizedBox(height: 9),
              Wrap(spacing: 8, runSpacing: 8, children: [
                _PillTag(label: '🏄 Adventure'),
                _PillTag(label: '🎒 Backpacker'),
              ]),
              SizedBox(height: 22),
              Text('INTERESTS', style: _label),
              SizedBox(height: 9),
              Wrap(spacing: 8, runSpacing: 8, children: [
                _PillTag(label: 'Food & Cuisine'),
                _PillTag(label: 'Hiking'),
                _PillTag(label: 'Museums'),
                _PillTag(label: 'Photography'),
              ]),
            ]),
      );
}

class _ProfileCard extends StatelessWidget {
  final String title;
  final Widget child;
  final bool edit;
  const _ProfileCard(
      {required this.title, required this.child, this.edit = true});

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(18),
        decoration: _cardDecoration(),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Text(title,
                style: const TextStyle(
                    color: _ink, fontSize: 18, fontWeight: FontWeight.w700)),
            const Spacer(),
            if (edit)
              IconButton(
                onPressed: () {},
                icon: const Icon(Icons.edit_outlined, color: _violet),
                tooltip: 'Edit $title',
              ),
          ]),
          const SizedBox(height: 12),
          child,
        ]),
      );
}

class _PhotoSlot extends StatelessWidget {
  final String url;
  final double height;
  const _PhotoSlot({required this.url, required this.height});

  @override
  Widget build(BuildContext context) => CustomPaint(
        painter: _DashedBorderPainter(),
        child: Container(
          height: height,
          decoration: BoxDecoration(
            color: _bgSubtle,
            borderRadius: BorderRadius.circular(12),
          ),
          clipBehavior: Clip.antiAlias,
          child: Stack(fit: StackFit.expand, children: [
            Image.network(url,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) =>
                    const ColoredBox(color: _bgSubtle)),
            DecoratedBox(
                decoration: BoxDecoration(color: _ink.withValues(alpha: .18))),
            const Center(
                child: Icon(Icons.camera_alt_outlined,
                    color: Colors.white, size: 25)),
          ]),
        ),
      );
}

class _DashedBorderPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    const radius = Radius.circular(12);
    final path = Path()
      ..addRRect(RRect.fromRectAndRadius(Offset.zero & size, radius));
    final paint = Paint()
      ..color = _border
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    for (final metric in path.computeMetrics()) {
      for (double distance = 0; distance < metric.length; distance += 8) {
        canvas.drawPath(metric.extractPath(distance, distance + 4), paint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _PillTag extends StatelessWidget {
  final String label;
  const _PillTag({required this.label});

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: _surface,
          border: Border.all(color: _border),
          borderRadius: BorderRadius.circular(99),
        ),
        child: Text(label,
            style: const TextStyle(
                color: _ink, fontSize: 12, fontWeight: FontWeight.w600)),
      );
}

class _FrostedIconButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onTap;
  const _FrostedIconButton({required this.icon, this.onTap});

  @override
  Widget build(BuildContext context) => Material(
        color: Colors.white.withValues(alpha: .15),
        shape: const StadiumBorder(),
        child: InkWell(
          onTap: onTap,
          customBorder: const StadiumBorder(),
          child: SizedBox(
              width: 38,
              height: 38,
              child: Icon(icon, color: Colors.white, size: 20)),
        ),
      );
}

class _VerifiedBadge extends StatelessWidget {
  const _VerifiedBadge();

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
        decoration: BoxDecoration(
            color: const Color(0x337C3AED),
            borderRadius: BorderRadius.circular(99)),
        child: const Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(Icons.verified_rounded, size: 13, color: Colors.white),
          SizedBox(width: 3),
          Text('Verified',
              style: TextStyle(
                  color: Colors.white,
                  fontSize: 11,
                  fontWeight: FontWeight.w700)),
        ]),
      );
}

const _coverPhotoUrl =
    'https://images.unsplash.com/photo-1498307833015-e7b400441eb8?auto=format&fit=crop&w=1200&q=85';
const _galleryPhotoOne =
    'https://images.unsplash.com/photo-1493976040374-85c8e12f0c0e?auto=format&fit=crop&w=900&q=85';
const _galleryPhotoTwo =
    'https://images.unsplash.com/photo-1537996194471-e657df975ab4?auto=format&fit=crop&w=900&q=85';
const _galleryPhotoThree =
    'https://images.unsplash.com/photo-1502602898657-3e91760cbb34?auto=format&fit=crop&w=900&q=85';

// ==========================================================================
// 📝 Sub-View: Edit Account Information Input Form
// ==========================================================================
class _AccountEditView extends StatefulWidget {
  final UserAccount user;
  final bool isSaving;
  final VoidCallback onBack;
  final ValueChanged<UserAccountProfileUpdate> onSave;
  final Future<String?> Function() onSelectImage;
  final VoidCallback onVerify;

  const _AccountEditView({
    required this.user,
    required this.isSaving,
    required this.onBack,
    required this.onSave,
    required this.onSelectImage,
    required this.onVerify,
  });

  @override
  State<_AccountEditView> createState() => _AccountEditViewState();
}

class _AccountEditViewState extends State<_AccountEditView> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _usernameController;
  late final TextEditingController _countryController;
  late final TextEditingController _bioController;
  String? _gender;
  String? _backgroundPhoto;
  String? _profilePhoto;

  @override
  void initState() {
    super.initState();
    _usernameController = TextEditingController(text: widget.user.username);
    _countryController = TextEditingController(text: widget.user.country);
    _bioController = TextEditingController(text: widget.user.bio);
    _gender = widget.user.gender;
    _backgroundPhoto = widget.user.backgroundPhoto;
    _profilePhoto = widget.user.profilePhoto;
  }

  @override
  void dispose() {
    _usernameController.dispose();
    _countryController.dispose();
    _bioController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return _AccountLayoutWrapper(
      title: 'Edit Profile',
      onBack: widget.onBack,
      child: Form(
        key: _formKey,
        child: ListView(
          children: [
            Row(
              children: [
                Expanded(
                  child: _PhotoPicker(
                    label: 'BACKGROUND PHOTO',
                    imagePath: _backgroundPhoto,
                    icon: Icons.landscape_outlined,
                    onTap: widget.isSaving
                        ? null
                        : () => _selectPhoto(isBackground: true),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _PhotoPicker(
                    label: 'PROFILE PHOTO',
                    imagePath: _profilePhoto,
                    icon: Icons.person_outline_rounded,
                    circular: true,
                    onTap: widget.isSaving
                        ? null
                        : () => _selectPhoto(isBackground: false),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            _EditField(
              label: 'USERNAME',
              controller: _usernameController,
              enabled: !widget.isSaving,
              validator: (value) => value == null || value.trim().isEmpty
                  ? 'Username is required'
                  : null,
            ),
            const SizedBox(height: 18),
            _VerifiedIdentityField(
              label: 'FULL NAME',
              value: widget.user.fullName,
              isVerified: widget.user.isVerified,
            ),
            const SizedBox(height: 18),
            DropdownButtonFormField<String>(
              initialValue: _gender,
              decoration: _editInputDecoration('GENDER'),
              items: const ['Female', 'Male', 'Non-binary', 'Prefer not to say']
                  .map((value) => DropdownMenuItem(
                        value: value,
                        child: Text(value),
                      ))
                  .toList(),
              onChanged: widget.isSaving
                  ? null
                  : (value) => setState(() => _gender = value),
            ),
            const SizedBox(height: 18),
            _VerifiedIdentityField(
              label: 'DATE OF BIRTH',
              value: widget.user.dateOfBirth == null
                  ? null
                  : _formatDate(widget.user.dateOfBirth!),
              isVerified: widget.user.isVerified,
            ),
            const SizedBox(height: 18),
            _EditField(
              label: 'COUNTRY',
              controller: _countryController,
              enabled: !widget.isSaving,
            ),
            const SizedBox(height: 18),
            _EditField(
              label: 'BIO',
              controller: _bioController,
              enabled: !widget.isSaving,
              maxLines: 4,
            ),
            if (!widget.user.isVerified) ...[
              const SizedBox(height: 24),
              OutlinedButton.icon(
                onPressed: widget.isSaving ? null : widget.onVerify,
                icon: const Icon(Icons.verified_user_outlined),
                label: const Text('Verify Identity'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: _violet,
                  minimumSize: const Size.fromHeight(52),
                  side: const BorderSide(color: _border),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ],
            const SizedBox(height: 16),
            FilledButton(
              onPressed: widget.isSaving ? null : _save,
              style: FilledButton.styleFrom(
                backgroundColor: _violet,
                foregroundColor: Colors.white,
                minimumSize: const Size.fromHeight(52),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: widget.isSaving
                  ? const SizedBox.square(
                      dimension: 20,
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2,
                      ),
                    )
                  : const Text(
                      'Save Changes',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Future<void> _selectPhoto({required bool isBackground}) async {
    final path = await widget.onSelectImage();
    if (path == null || !mounted) return;
    setState(() {
      if (isBackground) {
        _backgroundPhoto = path;
      } else {
        _profilePhoto = path;
      }
    });
  }

  void _save() {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    widget.onSave(
      UserAccountProfileUpdate(
        backgroundPhoto: _backgroundPhoto,
        profilePhoto: _profilePhoto,
        username: _usernameController.text.trim(),
        gender: _gender,
        country: _countryController.text.trim(),
        bio: _bioController.text.trim(),
      ),
    );
  }
}

class _PhotoPicker extends StatelessWidget {
  const _PhotoPicker({
    required this.label,
    required this.imagePath,
    required this.icon,
    required this.onTap,
    this.circular = false,
  });

  final String label;
  final String? imagePath;
  final IconData icon;
  final VoidCallback? onTap;
  final bool circular;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: _label),
        const SizedBox(height: 8),
        InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Container(
            height: 112,
            decoration: BoxDecoration(
              color: _bgSubtle,
              shape: circular ? BoxShape.circle : BoxShape.rectangle,
              borderRadius: circular ? null : BorderRadius.circular(16),
              border: Border.all(color: _border),
              image: imagePath == null
                  ? null
                  : DecorationImage(
                      image: _accountImageProvider(imagePath),
                      fit: BoxFit.cover,
                    ),
            ),
            alignment: Alignment.center,
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: const BoxDecoration(
                color: _surface,
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: _violet, size: 22),
            ),
          ),
        ),
      ],
    );
  }
}

class _EditField extends StatelessWidget {
  const _EditField({
    required this.label,
    required this.controller,
    required this.enabled,
    this.validator,
    this.maxLines = 1,
  });

  final String label;
  final TextEditingController controller;
  final bool enabled;
  final String? Function(String?)? validator;
  final int maxLines;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: _label),
        const SizedBox(height: 8),
        TextFormField(
          controller: controller,
          enabled: enabled,
          validator: validator,
          maxLines: maxLines,
          decoration: _editInputDecoration(),
        ),
      ],
    );
  }
}

class _VerifiedIdentityField extends StatelessWidget {
  const _VerifiedIdentityField({
    required this.label,
    required this.value,
    required this.isVerified,
  });

  final String label;
  final String? value;
  final bool isVerified;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: _label),
        const SizedBox(height: 8),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 15),
          decoration: BoxDecoration(
            color: _bgSubtle,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: _border),
          ),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  isVerified
                      ? value ?? 'Verified information unavailable'
                      : 'Verify identity to add this information',
                  style: TextStyle(
                    color: isVerified ? _ink : _muted,
                    fontSize: 14,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Icon(
                isVerified ? Icons.verified_rounded : Icons.lock_outline,
                color: isVerified ? _violet : _muted,
                size: 20,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

InputDecoration _editInputDecoration([String? label]) {
  return InputDecoration(
    labelText: label,
    filled: true,
    fillColor: _surface,
    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(10),
      borderSide: const BorderSide(color: _border),
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(10),
      borderSide: const BorderSide(color: _border),
    ),
  );
}

ImageProvider<Object> _accountImageProvider(
  String? path, {
  String fallback = 'assets/images/avatar.webp',
}) {
  final resolved = path == null || path.isEmpty ? fallback : path;
  if (resolved.startsWith('http://') || resolved.startsWith('https://')) {
    return NetworkImage(resolved);
  }
  if (resolved.startsWith('assets/')) return AssetImage(resolved);
  return FileImage(File(resolved));
}

String _formatDate(DateTime date) {
  final month = date.month.toString().padLeft(2, '0');
  final day = date.day.toString().padLeft(2, '0');
  return '${date.year}-$month-$day';
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
          Text(description,
              style: const TextStyle(color: _muted, height: 1.6, fontSize: 14)),
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

  const _AccountLayoutWrapper(
      {required this.title, required this.onBack, required this.child});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back_ios_new_rounded,
                color: _ink, size: 20),
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
