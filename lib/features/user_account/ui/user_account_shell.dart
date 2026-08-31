import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/routing/routes.dart';
import '../../common/ui/widgets/app_module_navigation.dart';
import '../../matchmaking/ui/matchmaking_shell_screen.dart';
import '../../matchmaking/ui/view_model/matchmaking_view_model.dart';
import '../model/user_account_model.dart';
import 'edit_profile_view.dart';
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
class UserAccountScreen extends ConsumerStatefulWidget {
  const UserAccountScreen({super.key});

  @override
  ConsumerState<UserAccountScreen> createState() => _UserAccountScreenState();
}

class _UserAccountScreenState extends ConsumerState<UserAccountScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        // The account sub-pages are held in a long-lived provider. Reset only
        // after the first frame because Riverpod forbids provider mutations
        // while the widget tree is being built.
        final viewModel = ref.read(userAccountViewModelProvider.notifier);
        viewModel.goTo(UserAccountPage.profile);
        viewModel.refresh();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(userAccountViewModelProvider, (previous, next) {
      if (next.error == null || next.error == previous?.error) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(next.error!)));
    });
    final state = ref.watch(userAccountViewModelProvider);
    final viewModel = ref.read(userAccountViewModelProvider.notifier);
    final matchmakingState = ref.watch(matchmakingViewModelProvider);
    final matchmakingViewModel =
        ref.read(matchmakingViewModelProvider.notifier);

    final Widget body;
    if (state.isLoading && state.user == null) {
      body = const Center(child: CircularProgressIndicator(color: _violet));
    } else if (state.user == null) {
      body = _AccountErrorView(
        message: state.error ?? 'Your profile is not available.',
        onRetry: viewModel.refresh,
      );
    } else {
      body = switch (state.page) {
        UserAccountPage.profile => _AccountDashboardView(
            user: state.user!,
            onNavigate: viewModel.goTo,
            onRefresh: viewModel.refresh,
            onVerify: () => context.push(Routes.identityVerification),
            unreadNotificationCount:
                matchmakingState.unreadNotificationCount,
            onEditPhoto: (source) => viewModel.addGalleryImage(source: source),
            onEditBio: (bio) => viewModel.updateProfile(
              UserAccountProfileUpdate(
                profilePhoto: state.user!.profilePhoto,
                username: state.user!.username,
                gender: state.user!.gender,
                nationality: state.user!.nationality,
                bio: bio,
              ),
            ),
            onNotifications: () async {
              await showDialog<void>(
                context: context,
                builder: (context) => MatchmakingNotificationsDialog(
                  notifications: matchmakingState.notifications,
                ),
              );
              await matchmakingViewModel.markNotificationsRead();
            },
          ),
        UserAccountPage.editProfile => EditProfileView(
            user: state.user!,
            isSaving: state.isLoading,
            onBack: () => viewModel.goTo(UserAccountPage.profile),
            onSave: viewModel.updateProfile,
            onSelectImage: (source) =>
                viewModel.selectProfileImage(source: source),
            onVerify: () => context.push(Routes.identityVerification),
          ),
        UserAccountPage.security => _AccountStaticFrame(
            title: 'Security',
            subtitle: 'ACCESS MANAGEMENT',
            description:
                'Manage active authorization keys, session duration thresholds, and multi-factor validation credentials.',
            onBack: () => viewModel.goTo(UserAccountPage.profile),
          ),
      };
    }

    final isAccountDashboard = state.page == UserAccountPage.profile;
    return PopScope(
      canPop: isAccountDashboard,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) viewModel.goTo(UserAccountPage.profile);
      },
      child: Scaffold(
        backgroundColor: const Color(0xFFF7F5FB),
        body: SafeArea(child: body),
        bottomNavigationBar: isAccountDashboard
            ? const AppModuleNavigation(selectedIndex: 4)
            : null,
      ),
    );
  }
}

// ==========================================================================
// 👤 Sub-View: Main Profile Dashboard
// ==========================================================================
class _AccountErrorView extends StatelessWidget {
  const _AccountErrorView({required this.message, required this.onRetry});

  final String message;
  final Future<void> Function() onRetry;

  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.person_off_outlined, color: _muted, size: 42),
              const SizedBox(height: 14),
              Text(message,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: _muted, height: 1.5)),
              const SizedBox(height: 18),
              FilledButton(onPressed: onRetry, child: const Text('Try again')),
            ],
          ),
        ),
      );
}

class _AccountDashboardView extends StatelessWidget {
  final UserAccount user;
  final ValueChanged<UserAccountPage> onNavigate;
  final Future<void> Function() onRefresh;
  final VoidCallback onVerify;
  final int unreadNotificationCount;
  final Future<void> Function() onNotifications;
  final Future<String?> Function(ImageSource source) onEditPhoto;
  final Future<void> Function(String bio) onEditBio;

  const _AccountDashboardView({
    required this.user,
    required this.onNavigate,
    required this.onRefresh,
    required this.onVerify,
    required this.unreadNotificationCount,
    required this.onNotifications,
    required this.onEditPhoto,
    required this.onEditBio,
  });

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: onRefresh,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.only(bottom: 32),
        children: [
          _ProfileHeader(
            user: user,
            onBack: () => context.canPop()
                ? context.pop()
                : context.go(Routes.main),
            unreadNotificationCount: unreadNotificationCount,
            onNotifications: onNotifications,
            onSettings: () => context.push(Routes.settings),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
            child: _ProfileStatsCard(
              onEdit: () => onNavigate(UserAccountPage.editProfile),
              isVerified: user.isVerified,
              onVerify: onVerify,
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
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
            child: _ProfilePhotosCard(
              photos: user.galleryPhotos,
              onEdit: onEditPhoto,
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
            child: _ProfileAboutCard(
              bio: user.bio,
              onEdit: () async {
                final bio = await _showAboutMeEditor(context, user.bio);
                if (bio != null) await onEditBio(bio);
              },
            ),
          ),
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 16, 16, 0),
            child: _ProfileInterestsCard(),
          ),
        ],
      ),
    );
  }
}

class _ProfileHeader extends StatelessWidget {
  final UserAccount user;
  final VoidCallback onBack;
  final VoidCallback onSettings;
  final int unreadNotificationCount;
  final Future<void> Function() onNotifications;

  const _ProfileHeader({
    required this.user,
    required this.onBack,
    required this.onSettings,
    required this.unreadNotificationCount,
    required this.onNotifications,
  });

  @override
  Widget build(BuildContext context) => SizedBox(
        height: 410,
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
                      user.backgroundPhoto,
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
                  Positioned(
                    top: 14,
                    right: 62,
                    child: _FrostedIconButton(
                      icon: Icons.notifications_none_rounded,
                      badgeCount: unreadNotificationCount,
                      onTap: onNotifications,
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
                ],
              ),
            ),
            Positioned(
              top: 205,
              left: 0,
              right: 0,
              child: Center(
                child: Semantics(
                  button: true,
                  label: 'View profile photo',
                  child: GestureDetector(
                    onTap: () => _showProfilePhotoPreview(
                      context,
                      user.profilePhoto,
                    ),
                    child: Container(
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
                            user.profilePhoto,
                            fallback: 'assets/images/avatar.webp',
                          ),
                          fit: BoxFit.cover,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
            Positioned(
              top: 330,
              left: 20,
              right: 20,
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Flexible(
                        child: Text(
                          _profileDisplayName(user),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: _ink,
                            fontSize: 30,
                            height: 1.1,
                            fontWeight: FontWeight.w800,
                            letterSpacing: -.5,
                          ),
                        ),
                      ),
                      if (user.isVerified) ...[
                        const SizedBox(width: 8),
                        const Icon(
                          Icons.verified_rounded,
                          color: _violet,
                          size: 23,
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _profileSummary(user),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: _muted,
                      fontSize: 15,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
}

class _ProfileStatsCard extends StatelessWidget {
  final VoidCallback onEdit;
  final bool isVerified;
  final VoidCallback onVerify;

  const _ProfileStatsCard({
    required this.onEdit,
    required this.isVerified,
    required this.onVerify,
  });

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(18),
        decoration: _cardDecoration(),
        child: Column(children: [
          const Row(children: [
            Expanded(child: _ProfileStat(number: '—', label: 'TRIPS')),
            SizedBox(height: 38, child: VerticalDivider(color: _border)),
            Expanded(child: _ProfileStat(number: '—', label: 'CITIES')),
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
          if (!isVerified) ...[
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: OutlinedButton.icon(
                onPressed: onVerify,
                icon: const Icon(Icons.verified_user_outlined),
                label: const Text(
                  'Verify Identity',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
                style: OutlinedButton.styleFrom(
                  foregroundColor: _violet,
                  side: const BorderSide(color: _violet),
                  shape: const StadiumBorder(),
                ),
              ),
            ),
          ],
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
  const _ProfilePhotosCard({
    required this.photos,
    required this.onEdit,
  });

  final List<String> photos;
  final Future<String?> Function(ImageSource source) onEdit;

  @override
  Widget build(BuildContext context) {
    final visiblePhotos = photos.take(3).toList(growable: false);
    final hiddenPhotoCount = photos.length > 3 ? photos.length - 2 : 0;

    return _ProfileCard(
        title: 'Photos',
        onEdit: () => _choosePhotoSource(context),
        child: photos.isEmpty
            ? const Text(
                'No travel photos added yet.',
                style: TextStyle(color: _muted, height: 1.6),
              )
            : LayoutBuilder(
                builder: (context, constraints) {
                  const spacing = 10.0;
                  final tileSize = constraints.maxWidth.isFinite
                      ? ((constraints.maxWidth - spacing * 2) / 3)
                          .clamp(0.0, 104.0)
                          .toDouble()
                      : 104.0;

                  return Row(
                    children: [
                      for (var index = 0;
                          index < visiblePhotos.length;
                          index++) ...[
                        if (index > 0) const SizedBox(width: spacing),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: Semantics(
                            button: true,
                            label: index == 2 && hiddenPhotoCount > 0
                                ? 'View all ${photos.length} photos'
                                : 'Open photo ${index + 1} full screen',
                            child: GestureDetector(
                              onTap: index == 2 && hiddenPhotoCount > 0
                                  ? () => _openGallery(context)
                                  : () => _openPhotoViewer(context, index),
                              child: SizedBox.square(
                                dimension: tileSize,
                                child: Stack(
                                  fit: StackFit.expand,
                                  children: [
                                    Image(
                                      image: _accountImageProvider(
                                        visiblePhotos[index],
                                      ),
                                      fit: BoxFit.cover,
                                    ),
                                    if (index == 2 && hiddenPhotoCount > 0) ...[
                                      ColoredBox(
                                        color:
                                            Colors.black.withValues(alpha: .52),
                                      ),
                                      Center(
                                        child: Text(
                                          '+$hiddenPhotoCount',
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontSize: 24,
                                            fontWeight: FontWeight.w700,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ],
                  );
                },
              ),
      );
  }

  void _openGallery(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => _UserPhotoGalleryScreen(photos: photos),
      ),
    );
  }

  void _openPhotoViewer(BuildContext context, int initialIndex) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => _FullScreenPhotoViewer(
          photos: photos,
          initialIndex: initialIndex,
        ),
      ),
    );
  }

  Future<void> _choosePhotoSource(BuildContext context) async {
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const ListTile(
                title: Text(
                  'Add a travel photo',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
              ListTile(
                leading: const Icon(Icons.camera_alt_outlined),
                title: const Text('Take a photo'),
                subtitle: const Text('Use your device camera'),
                onTap: () => Navigator.pop(sheetContext, ImageSource.camera),
              ),
              ListTile(
                leading: const Icon(Icons.photo_library_outlined),
                title: const Text('Choose from gallery'),
                subtitle: const Text('Upload an existing photo'),
                onTap: () => Navigator.pop(sheetContext, ImageSource.gallery),
              ),
            ],
          ),
        ),
      ),
    );
    if (source != null) await onEdit(source);
  }
}

class _UserPhotoGalleryScreen extends StatelessWidget {
  const _UserPhotoGalleryScreen({required this.photos});

  final List<String> photos;

  @override
  Widget build(BuildContext context) => Scaffold(
        backgroundColor: _surface,
        appBar: AppBar(
          backgroundColor: _surface,
          foregroundColor: _ink,
          surfaceTintColor: Colors.transparent,
          title: const Text(
            'Photos',
            style: TextStyle(fontWeight: FontWeight.w700),
          ),
        ),
        body: GridView.builder(
          padding: const EdgeInsets.all(16),
          gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
            maxCrossAxisExtent: 180,
            mainAxisSpacing: 10,
            crossAxisSpacing: 10,
          ),
          itemCount: photos.length,
          itemBuilder: (context, index) => Semantics(
            button: true,
            image: true,
            label:
                'Open gallery photo ${index + 1} of ${photos.length} full screen',
            child: GestureDetector(
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => _FullScreenPhotoViewer(
                    photos: photos,
                    initialIndex: index,
                  ),
                ),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Image(
                  image: _accountImageProvider(photos[index]),
                  fit: BoxFit.cover,
                ),
              ),
            ),
          ),
        ),
      );
}

class _FullScreenPhotoViewer extends StatefulWidget {
  const _FullScreenPhotoViewer({
    required this.photos,
    required this.initialIndex,
  });

  final List<String> photos;
  final int initialIndex;

  @override
  State<_FullScreenPhotoViewer> createState() =>
      _FullScreenPhotoViewerState();
}

class _FullScreenPhotoViewerState extends State<_FullScreenPhotoViewer> {
  late final PageController _pageController;
  late int _currentIndex;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
    _pageController = PageController(initialPage: widget.initialIndex);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        backgroundColor: Colors.black,
        appBar: AppBar(
          backgroundColor: Colors.black,
          foregroundColor: Colors.white,
          surfaceTintColor: Colors.transparent,
          title: Text('${_currentIndex + 1} of ${widget.photos.length}'),
        ),
        body: PageView.builder(
          controller: _pageController,
          itemCount: widget.photos.length,
          onPageChanged: (index) => setState(() => _currentIndex = index),
          itemBuilder: (context, index) => Semantics(
            image: true,
            label:
                'Full-size photo ${index + 1} of ${widget.photos.length}',
            child: Center(
              child: Image(
                image: _accountImageProvider(widget.photos[index]),
                width: double.infinity,
                height: double.infinity,
                fit: BoxFit.contain,
              ),
            ),
          ),
        ),
      );
}

class _ProfileAboutCard extends StatelessWidget {
  const _ProfileAboutCard({required this.bio, required this.onEdit});

  final String bio;
  final VoidCallback onEdit;

  @override
      Widget build(BuildContext context) => _ProfileCard(
        title: 'About Me',
        onEdit: onEdit,
        child: Text(
          bio.isEmpty ? 'Not set' : bio,
          style: const TextStyle(color: _muted, height: 1.7),
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
              Text('Not set', style: TextStyle(color: _muted)),
              SizedBox(height: 22),
              Text('INTERESTS', style: _label),
              SizedBox(height: 9),
              Text('Not set', style: TextStyle(color: _muted)),
            ]),
      );
}

class _ProfileCard extends StatelessWidget {
  final String title;
  final Widget child;
  final bool edit;
  final VoidCallback? onEdit;

  const _ProfileCard({
    required this.title,
    required this.child,
    this.edit = true,
    this.onEdit,
  }) : assert(!edit || onEdit != null);

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
                onPressed: onEdit,
                icon: const Icon(Icons.edit_outlined, color: _violet),
                tooltip: 'Edit $title',
              ),
          ]),
          const SizedBox(height: 12),
          child,
        ]),
      );
}

Future<String?> _showAboutMeEditor(
  BuildContext context,
  String currentBio,
) async {
  var bio = currentBio;
  return showDialog<String>(
    context: context,
    builder: (dialogContext) => AlertDialog(
        title: const Text('About Me'),
        content: TextFormField(
          initialValue: currentBio,
          autofocus: true,
          minLines: 4,
          maxLines: 7,
          maxLength: 500,
          onChanged: (value) => bio = value,
          decoration: const InputDecoration(
            hintText: 'Tell other travellers about yourself',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(
              dialogContext,
              bio.trim(),
            ),
            child: const Text('Save'),
          ),
        ],
      ),
  );
}

class _FrostedIconButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onTap;
  final int badgeCount;

  const _FrostedIconButton({
    required this.icon,
    this.onTap,
    this.badgeCount = 0,
  });

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
              child: Badge(
                isLabelVisible: badgeCount > 0,
                label: Text(badgeCount > 99 ? '99+' : '$badgeCount'),
                child: Icon(icon, color: Colors.white, size: 20),
              )),
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
  late final TextEditingController _nationalityController;
  late final TextEditingController _bioController;
  String? _gender;
  String? _backgroundPhoto;
  String? _profilePhoto;

  @override
  void initState() {
    super.initState();
    _usernameController = TextEditingController(text: widget.user.username);
    _nationalityController =
        TextEditingController(text: widget.user.nationality);
    _bioController = TextEditingController(text: widget.user.bio);
    _gender = widget.user.gender;
    _backgroundPhoto = widget.user.backgroundPhoto;
    _profilePhoto = widget.user.profilePhoto;
  }

  @override
  void dispose() {
    _usernameController.dispose();
    _nationalityController.dispose();
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
              label: 'NATIONALITY',
              controller: _nationalityController,
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
        nationality: _nationalityController.text.trim(),
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

Future<void> _showProfilePhotoPreview(
  BuildContext context,
  String? profilePhoto,
) {
  return showDialog<void>(
    context: context,
    barrierColor: Colors.black87,
    builder: (dialogContext) => Dialog(
      insetPadding: const EdgeInsets.all(20),
      backgroundColor: Colors.transparent,
      child: Stack(
        alignment: Alignment.topRight,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(18),
            child: ColoredBox(
              color: Colors.black,
              child: AspectRatio(
                aspectRatio: 1,
                child: InteractiveViewer(
                  minScale: 1,
                  maxScale: 4,
                  child: Image(
                    image: _accountImageProvider(profilePhoto),
                    fit: BoxFit.contain,
                  ),
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(8),
            child: IconButton.filled(
              onPressed: () => Navigator.of(dialogContext).pop(),
              style: IconButton.styleFrom(
                backgroundColor: Colors.black54,
                foregroundColor: Colors.white,
              ),
              icon: const Icon(Icons.close_rounded),
            ),
          ),
        ],
      ),
    ),
  );
}

String _profileDisplayName(UserAccount user) {
  final fullName = user.fullName?.trim();
  if (fullName != null && fullName.isNotEmpty) return fullName;
  final username = user.username.trim();
  return username.isEmpty ? 'Profile incomplete' : username;
}

String _profileSummary(UserAccount user) {
  final nationality = user.nationality?.trim();
  final nationalityLabel = nationality == null || nationality.isEmpty
      ? 'Nationality not added'
      : _nationalityWithFlag(nationality);
  final age = _ageFromDateOfBirth(user.dateOfBirth);
  final gender = user.gender?.trim();

  return [
    nationalityLabel,
    age == null ? 'Age not added' : '$age',
    gender == null || gender.isEmpty ? 'Gender not added' : gender,
  ].join('  |  ');
}

String _nationalityWithFlag(String nationality) {
  return switch (nationality.toLowerCase()) {
    'malaysia' || 'malaysian' =>
        '${String.fromCharCodes([0x1F1F2, 0x1F1FE])} Malaysia',
    _ => nationality,
  };
}

int? _ageFromDateOfBirth(DateTime? dateOfBirth) {
  if (dateOfBirth == null) return null;
  final today = DateTime.now();
  var age = today.year - dateOfBirth.year;
  final birthdayHasPassed = today.month > dateOfBirth.month ||
      (today.month == dateOfBirth.month && today.day >= dateOfBirth.day);
  if (!birthdayHasPassed) age--;
  return age < 0 ? null : age;
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
