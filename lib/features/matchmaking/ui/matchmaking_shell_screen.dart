import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../model/matchmaking_page.dart';
import 'view_model/matchmaking_view_model.dart';

const _ink = Color(0xFF281950);
const _violet = Color(0xFF7C3AED);
const _border = Color(0xFFD5CFEF);
const _muted = Color(0xFF686082);
const _lavender = Color(0xFFEDE9FE);

class MatchmakingShellScreen extends ConsumerWidget {
  const MatchmakingShellScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(matchmakingViewModelProvider);
    final viewModel = ref.read(matchmakingViewModelProvider.notifier);
    final page = state.page;
    final content = switch (page) {
      MatchmakingPage.discover => DiscoverPage(
          filter: state.selectedFilter,
          filters: state.availableFilters,
          onFilter: viewModel.selectFilter,
          onGo: viewModel.goTo),
      MatchmakingPage.filters => FilterPage(
          onBack: () => viewModel.goTo(MatchmakingPage.discover),
          onApply: () => viewModel.goTo(MatchmakingPage.discover)),
      MatchmakingPage.details => TripDetailsPage(
          onBack: () => viewModel.goTo(MatchmakingPage.discover),
          onRequest: () => viewModel.goTo(MatchmakingPage.request)),
      MatchmakingPage.create => CreateTripPage(
          onBack: () => viewModel.goTo(MatchmakingPage.discover),
          onPublish: () => viewModel.goTo(MatchmakingPage.myTrips)),
      MatchmakingPage.edit => CreateTripPage(
          edit: true,
          onBack: () => viewModel.goTo(MatchmakingPage.myTrips),
          onPublish: () => viewModel.goTo(MatchmakingPage.myTrips)),
      MatchmakingPage.myTrips => MyTripsPage(
          onCreate: () => viewModel.goTo(MatchmakingPage.create),
          onManage: () => viewModel.goTo(MatchmakingPage.manage),
          onEdit: () => viewModel.goTo(MatchmakingPage.edit)),
      MatchmakingPage.request => RequestPage(
          onCancel: () => viewModel.goTo(MatchmakingPage.details),
          onSend: () => viewModel.goTo(MatchmakingPage.sent)),
      MatchmakingPage.sent =>
        RequestSentPage(onBack: () => viewModel.goTo(MatchmakingPage.discover)),
      MatchmakingPage.manage => ManageRequestsPage(
          onApplicant: () => viewModel.goTo(MatchmakingPage.applicant)),
      MatchmakingPage.applicant =>
        ApplicantPage(onBack: () => viewModel.goTo(MatchmakingPage.manage)),
      MatchmakingPage.profile => const ProfilePage(),
    };
    final navPages = {
      MatchmakingPage.discover,
      MatchmakingPage.myTrips,
      MatchmakingPage.profile
    };
    return Scaffold(
      body: SafeArea(child: content),
      bottomNavigationBar: navPages.contains(page)
          ? BottomNav(tab: state.selectedTab, onTap: viewModel.selectTab)
          : null,
      floatingActionButton: page == MatchmakingPage.discover
          ? FloatingActionButton(
              onPressed: () => viewModel.goTo(MatchmakingPage.create),
              backgroundColor: _violet,
              foregroundColor: Colors.white,
              shape: const CircleBorder(),
              child: const Icon(Icons.add),
            )
          : null,
    );
  }
}

class DiscoverPage extends StatelessWidget {
  final String filter;
  final List<String> filters;
  final ValueChanged<String> onFilter;
  final ValueChanged<MatchmakingPage> onGo;
  const DiscoverPage(
      {super.key,
      required this.filter,
      required this.filters,
      required this.onFilter,
      required this.onGo});

  @override
  Widget build(BuildContext context) => ColoredBox(
        color: const Color(0xFFF7F5FB),
        child: Column(children: [
          Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 16, 14),
              child: Row(children: [
                const Text('GoBuddy',
                    style: TextStyle(
                        fontFamily: 'Georgia',
                        fontWeight: FontWeight.w600,
                        letterSpacing: -.8,
                        fontSize: 29,
                        color: _ink)),
                const Spacer(),
                IconButton(
                    onPressed: () => onGo(MatchmakingPage.filters),
                    icon: const Icon(Icons.tune_rounded, color: _ink)),
                IconButton(
                    onPressed: () {},
                    icon: const Icon(Icons.notifications_none_rounded,
                        color: _ink)),
                const Avatar(letter: 'M', size: 34),
              ])),
          SizedBox(
            height: 38,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              children: filters
                  .map(
                    (x) => Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: ChipButton(
                        label: x,
                        active: x == filter,
                        onTap: () => onFilter(x),
                      ),
                    ),
                  )
                  .toList(),
            ),
          ),
          Expanded(
              child: ListView(
                  padding: const EdgeInsets.fromLTRB(16, 18, 16, 96),
                  children: [
                TripCard(
                    onDetails: () => onGo(MatchmakingPage.details),
                    onRequest: () => onGo(MatchmakingPage.request)),
                const SizedBox(height: 18),
                const _SmallDiscoverCard(),
              ])),
        ]),
      );
}

class TripCard extends StatelessWidget {
  final VoidCallback onDetails, onRequest;
  const TripCard({super.key, required this.onDetails, required this.onRequest});
  @override
  Widget build(BuildContext context) => Container(
      decoration: _cardDecoration(radius: 24, feed: true),
      clipBehavior: Clip.antiAlias,
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        SizedBox(
            height: 270,
            child: Stack(fit: StackFit.expand, children: [
              const TravelImage(url: _tokyo),
              const DecoratedBox(
                  decoration: BoxDecoration(
                      gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [Colors.transparent, Color(0xCC171025)]))),
              const Positioned(
                  top: 14, left: 14, child: VerifiedBadge(glass: true)),
              const Positioned(top: 14, right: 14, child: _Counter()),
              const Positioned(
                  left: 20,
                  right: 20,
                  bottom: 18,
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Tokyo, Japan',
                            style: TextStyle(
                                fontFamily: 'Georgia',
                                color: Colors.white,
                                fontSize: 27,
                                fontWeight: FontWeight.w600)),
                        SizedBox(height: 5),
                        Text('MAY 14 — MAY 21 · 7 DAYS',
                            style: TextStyle(
                                color: Colors.white,
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                letterSpacing: .7)),
                      ])),
            ])),
        Padding(
            padding: const EdgeInsets.fromLTRB(18, 16, 18, 14),
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Row(children: [
                Avatar(letter: 'E', size: 40, color: Color(0xFFB59BF1)),
                SizedBox(width: 10),
                Expanded(
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                      Text('Sophia Lee',
                          style: TextStyle(
                              color: _ink, fontWeight: FontWeight.w700)),
                      Text('Trip organizer',
                          style: TextStyle(color: _muted, fontSize: 12))
                    ])),
                Text('\$1,800',
                    style: TextStyle(
                        color: _ink, fontWeight: FontWeight.w700, fontSize: 16))
              ]),
              const SizedBox(height: 14),
              const Wrap(spacing: 7, runSpacing: 7, children: [
                ChipButton(label: 'Adventure', small: true),
                ChipButton(label: 'Nature', small: true),
                SlotChip()
              ]),
              const SizedBox(height: 13),
              const Text(
                  'Hiking mountain passes, quiet alpine stays, and long Italian lunches. Looking for kind, curious people who love early starts.',
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(height: 1.45, fontSize: 14, color: _muted)),
            ])),
        Container(
            padding: const EdgeInsets.all(12),
            decoration: const BoxDecoration(
                border: Border(top: BorderSide(color: _border))),
            child: Row(children: [
              IconButton(
                  onPressed: () {},
                  icon:
                      const Icon(Icons.favorite_border_rounded, color: _violet),
                  style: IconButton.styleFrom(
                      side: const BorderSide(color: _border),
                      shape: const CircleBorder())),
              const SizedBox(width: 5),
              Expanded(
                  child: SmallOutline(label: 'View Details', onTap: onDetails)),
              const SizedBox(width: 7),
              Expanded(
                  child:
                      SmallPrimary(label: 'Request to Join', onTap: onRequest)),
            ])),
      ]));
}

class FilterPage extends StatelessWidget {
  final VoidCallback onBack, onApply;
  const FilterPage({super.key, required this.onBack, required this.onApply});
  @override
  Widget build(BuildContext context) => FormPage(
      title: 'Search & filter',
      onBack: onBack,
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const FieldLabel('DESTINATION'),
        const AppField(hint: 'Where would you like to go?'),
        const SizedBox(height: 22),
        const FieldLabel('DATE RANGE'),
        const Row(children: [
          Expanded(
              child: AppField(
                  hint: 'Start date', icon: Icons.calendar_today_outlined)),
          SizedBox(width: 12),
          Expanded(
              child: AppField(
                  hint: 'End date', icon: Icons.calendar_today_outlined))
        ]),
        const SizedBox(height: 22),
        const FieldLabel('BUDGET'),
        const RangeTitle(left: '\$500', right: '\$2,500'),
        const Slider(value: .55, onChanged: _noop),
        const SizedBox(height: 16),
        const FieldLabel('AGE RANGE'),
        const RangeTitle(left: '22', right: '35'),
        const Slider(value: .5, onChanged: _noop),
        const SizedBox(height: 18),
        const FieldLabel('PREFERRED GENDER'),
        const Segmented(),
        const SizedBox(height: 22),
        const FieldLabel('TRAVEL STYLE'),
        const StyleWrap(),
        const SizedBox(height: 32),
        PrimaryButton(label: 'Apply Filters', onTap: onApply),
        const SizedBox(height: 10),
        OutlineButton(label: 'Reset', onTap: () {}),
      ]));
}

class TripDetailsPage extends StatelessWidget {
  final VoidCallback onBack, onRequest;
  const TripDetailsPage(
      {super.key, required this.onBack, required this.onRequest});
  @override
  Widget build(BuildContext context) => Stack(children: [
        ListView(padding: EdgeInsets.zero, children: [
          SizedBox(
              height: 240,
              child: Stack(fit: StackFit.expand, children: [
                const TravelImage(url: _tokyo),
                Positioned(top: 16, left: 16, child: RoundBack(onTap: onBack))
              ])),
          Padding(
              padding: const EdgeInsets.fromLTRB(20, 22, 20, 100),
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Tokyo, Japan', style: _heading),
                    const SizedBox(height: 5),
                    const Text('MAY 14 — MAY 21, 2026', style: _label),
                    const SizedBox(height: 20),
                    const InfoRows(),
                    const SizedBox(height: 24),
                    const FieldLabel('TRIP HOST'),
                    const SizedBox(height: 9),
                    const Row(children: [
                      Avatar(letter: 'E', size: 46, color: Color(0xFFB59BF1)),
                      SizedBox(width: 11),
                      Text('Sophia Lee',
                          style: TextStyle(
                              fontWeight: FontWeight.w700, color: _ink)),
                      SizedBox(width: 8),
                      VerifiedBadge()
                    ]),
                    const SizedBox(height: 24),
                    const FieldLabel('TRAVEL STYLE'),
                    const SizedBox(height: 9),
                    const Wrap(spacing: 8, children: [
                      ChipButton(label: 'Adventure', active: true),
                      ChipButton(label: 'Nature', active: true)
                    ]),
                    const SizedBox(height: 24),
                    const FieldLabel('ABOUT THIS TRIP'),
                    const SizedBox(height: 9),
                    const Text(
                        'Looking for a calm travel companion to explore Tokyo’s neighbourhoods, hidden izakayas, ramen shops, and art museums. I prefer a relaxed pace with some structure and plenty of room for a great conversation.',
                        style: TextStyle(height: 1.65, color: _muted)),
                  ])),
        ]),
        Positioned(
            left: 16,
            right: 16,
            bottom: 16,
            child: PrimaryButton(label: 'Request to Join', onTap: onRequest)),
      ]);
}

class CreateTripPage extends StatelessWidget {
  final VoidCallback onBack, onPublish;
  final bool edit;
  const CreateTripPage(
      {super.key,
      required this.onBack,
      required this.onPublish,
      this.edit = false});
  @override
  Widget build(BuildContext context) => FormPage(
      title: edit ? 'Edit Trip' : 'Create Trip',
      onBack: onBack,
      child: Container(
          padding: const EdgeInsets.all(18),
          decoration: _cardDecoration(),
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const FieldLabel('DESTINATION'),
            AppField(hint: edit ? 'Tokyo, Japan' : 'e.g. Tokyo, Japan'),
            const SizedBox(height: 18),
            Row(children: [
              Expanded(
                  child: AppField(
                      hint: edit ? '12/08/2025' : 'dd/mm/yyyy',
                      icon: Icons.calendar_today_outlined)),
              SizedBox(width: 10),
              Expanded(
                  child: AppField(
                      hint: edit ? '20/08/2025' : 'dd/mm/yyyy',
                      icon: Icons.calendar_today_outlined))
            ]),
            const SizedBox(height: 18),
            const FieldLabel('BUDGET'),
            AppField(
                hint: edit ? '\$1,200 – \$1,800' : 'e.g. \$1,200 – \$1,800'),
            const SizedBox(height: 18),
            const FieldLabel('TRAVEL STYLE'),
            const StyleWrap(),
            const SizedBox(height: 18),
            const FieldLabel('PREFERRED GENDER'),
            const AppField(hint: 'Any', icon: Icons.expand_more),
            const SizedBox(height: 18),
            const FieldLabel('AGE PREFERENCE'),
            const RangeTitle(left: '22', right: '40'),
            const Slider(value: .48, onChanged: _noop),
            const SizedBox(height: 18),
            const FieldLabel('AVAILABLE VACANCIES'),
            AppField(hint: edit ? '2' : 'e.g. 2', icon: Icons.people_outline),
            const SizedBox(height: 18),
            const FieldLabel('DESCRIPTION'),
            AppField(
                hint: edit
                    ? 'Looking for a calm travel companion to explore Tokyo’s neighbourhoods, hidden izakayas, ramen shops, and art museums.'
                    : 'Describe your trip and ideal companion...',
                lines: 4),
            const SizedBox(height: 24),
            PrimaryButton(
                label: edit ? 'Save Changes' : 'Publish Trip',
                onTap: onPublish),
            if (edit) ...[
              const SizedBox(height: 10),
              OutlineButton(label: 'Delete Trip', onTap: onPublish),
            ],
          ])));
}

class MyTripsPage extends StatelessWidget {
  final VoidCallback onCreate, onManage, onEdit;
  const MyTripsPage(
      {super.key,
      required this.onCreate,
      required this.onManage,
      required this.onEdit});
  @override
  Widget build(BuildContext context) =>
      ListView(padding: const EdgeInsets.fromLTRB(20, 18, 20, 100), children: [
        const Text('My trips', style: _display),
        const SizedBox(height: 7),
        const Text('Your adventures, all in one place.',
            style: TextStyle(color: _muted)),
        const SizedBox(height: 24),
        CompactTrip(
            destination: 'Tokyo, Japan',
            dates: 'Aug 12 – Aug 20, 2025',
            members: '1 joined',
            onEdit: onEdit,
            onManage: onManage),
        const SizedBox(height: 14),
        CompactTrip(
            destination: 'Bali, Indonesia',
            dates: 'Sep 5 – Sep 15, 2025',
            members: '2 joined',
            image: _bali),
        const SizedBox(height: 14),
        CompactTrip(
            destination: 'Paris, France',
            dates: 'Oct 1 – Oct 8, 2025',
            members: '0 joined',
            image: _paris,
            status: 'Closed'),
        const SizedBox(height: 14),
        CompactTrip(
            destination: 'Kyoto, Japan',
            dates: 'Nov 10 – Nov 18, 2025',
            members: '1 joined',
            image: _kyoto,
            status: 'Draft'),
        const SizedBox(height: 24),
        OutlineButton(label: '+ Create a new trip', onTap: onCreate),
      ]);
}

class RequestPage extends StatelessWidget {
  final VoidCallback onCancel, onSend;
  const RequestPage({super.key, required this.onCancel, required this.onSend});
  @override
  Widget build(BuildContext context) => Center(
      child: SingleChildScrollView(
          padding: const EdgeInsets.all(26),
          child: Column(children: [
            const Avatar(letter: 'M', size: 72, color: _violet),
            const SizedBox(height: 20),
            const Text('Your request', style: _display),
            const SizedBox(height: 8),
            const VerifiedBadge(),
            const SizedBox(height: 12),
            const Text('Joining: Tokyo, Japan',
                textAlign: TextAlign.center, style: TextStyle(color: _muted)),
            const SizedBox(height: 28),
            const Align(
                alignment: Alignment.centerLeft,
                child: FieldLabel('MESSAGE TO SOPHIA')),
            const SizedBox(height: 8),
            const AppField(
                hint:
                    'Introduce yourself and share why this trip feels right for you...',
                lines: 7),
            const Align(
              alignment: Alignment.centerRight,
              child: Padding(
                  padding: EdgeInsets.only(top: 5),
                  child: Text('0 / 500',
                      style: TextStyle(color: _muted, fontSize: 11))),
            ),
            const SizedBox(height: 22),
            PrimaryButton(label: 'Send Request', onTap: onSend),
            const SizedBox(height: 10),
            OutlineButton(label: 'Cancel', onTap: onCancel),
          ])));
}

class RequestSentPage extends StatelessWidget {
  final VoidCallback onBack;
  const RequestSentPage({super.key, required this.onBack});
  @override
  Widget build(BuildContext context) => Center(
      child: Padding(
          padding: const EdgeInsets.all(34),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Container(
                width: 96,
                height: 96,
                decoration: const BoxDecoration(
                    color: _lavender, shape: BoxShape.circle),
                child: const Icon(Icons.check_circle_rounded,
                    color: _violet, size: 50)),
            const SizedBox(height: 26),
            const Text('Request sent!',
                style: TextStyle(
                    fontFamily: 'Georgia',
                    color: _ink,
                    fontSize: 30,
                    fontWeight: FontWeight.w600)),
            const SizedBox(height: 10),
            const Text(
                'Your request has been successfully sent to the trip organizer. They’ll review your profile and get back to you soon.',
                textAlign: TextAlign.center,
                style: TextStyle(color: _muted, height: 1.5)),
            const SizedBox(height: 28),
            SizedBox(
                width: 320,
                child: PrimaryButton(label: 'Back to Discover', onTap: onBack)),
          ])));
}

class ManageRequestsPage extends StatelessWidget {
  final VoidCallback onApplicant;
  const ManageRequestsPage({super.key, required this.onApplicant});
  @override
  Widget build(BuildContext context) =>
      ListView(padding: const EdgeInsets.fromLTRB(20, 18, 20, 30), children: [
        const Text('Requests', style: _display),
        const SizedBox(height: 7),
        const Text('Tokyo, Japan · 3 applicants',
            style: TextStyle(color: _muted)),
        const SizedBox(height: 22),
        ApplicantCard(name: 'Priya Sharma', letter: 'PS', onTap: onApplicant),
        const SizedBox(height: 14),
        const ApplicantCard(
            name: 'Lucas Mendes', letter: 'LM', status: 'Accepted'),
        const SizedBox(height: 14),
        const ApplicantCard(name: 'Yuki Tanaka', letter: 'YT', status: 'Held')
      ]);
}

class ApplicantPage extends StatelessWidget {
  final VoidCallback onBack;
  const ApplicantPage({super.key, required this.onBack});
  @override
  Widget build(BuildContext context) => Stack(children: [
        ListView(padding: EdgeInsets.zero, children: [
          Container(
              padding: const EdgeInsets.fromLTRB(20, 18, 20, 30),
              decoration: const BoxDecoration(
                  gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [_lavender, Color(0xFFF3E8FF)])),
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    RoundBack(onTap: onBack),
                    const SizedBox(height: 22),
                    const Center(
                        child: Avatar(letter: 'PS', size: 80, color: _violet)),
                    const SizedBox(height: 12),
                    const Center(child: Text('Priya Sharma', style: _heading)),
                    const SizedBox(height: 6),
                    const Center(
                        child: Row(mainAxisSize: MainAxisSize.min, children: [
                      VerifiedBadge(),
                      SizedBox(width: 7),
                      Text('28 · Female', style: TextStyle(color: _muted))
                    ])),
                    const SizedBox(height: 24),
                    const Row(
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        children: [
                          Stat(number: '12', label: 'TRIPS'),
                          Stat(number: '4.9', label: 'RATING'),
                          Stat(number: '4', label: 'LANGUAGES')
                        ])
                  ])),
          const Padding(
              padding: EdgeInsets.fromLTRB(20, 24, 20, 100),
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    FieldLabel('LANGUAGES'),
                    SizedBox(height: 8),
                    Wrap(spacing: 8, children: [
                      ChipButton(label: 'English'),
                      ChipButton(label: 'Hindi'),
                      ChipButton(label: 'Tamil')
                    ]),
                    SizedBox(height: 24),
                    FieldLabel('TRAVEL STYLE'),
                    SizedBox(height: 8),
                    Wrap(spacing: 8, children: [
                      ChipButton(label: 'Culture', active: true),
                      ChipButton(label: 'Foodie', active: true)
                    ]),
                    SizedBox(height: 24),
                    FieldLabel('ABOUT'),
                    SizedBox(height: 8),
                    Text(
                        'Solo traveller from Mumbai. Visited 18 countries. Love markets, museums, and late-night street food adventures.',
                        style: TextStyle(color: _muted, height: 1.65))
                  ]))
        ]),
        Positioned(
            left: 16,
            right: 16,
            bottom: 16,
            child: Row(children: [
              Expanded(
                  child: StatusButton(
                      label: 'Accept',
                      color: Color(0xFFDCFCE7),
                      text: Color(0xFF16A34A))),
              const SizedBox(width: 8),
              Expanded(
                  child: StatusButton(
                      label: 'Hold',
                      color: Color(0xFFFEF9C3),
                      text: Color(0xFFD97706))),
              const SizedBox(width: 8),
              Expanded(
                  child: StatusButton(
                      label: 'Decline',
                      color: Color(0xFFFEE2E2),
                      text: Color(0xFFDC2626)))
            ]))
      ]);
}

class ProfilePage extends StatelessWidget {
  const ProfilePage({super.key});
  @override
  Widget build(BuildContext context) => Center(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
        const Avatar(letter: 'M', size: 80, color: _violet),
        const SizedBox(height: 14),
        const Text('Morgan Lee', style: _heading),
        const SizedBox(height: 4),
        const Text('morgan@gobuddy.app', style: TextStyle(color: _muted)),
        const SizedBox(height: 26),
        SizedBox(
            width: 260,
            child: OutlineButton(label: 'Edit profile', onTap: () {}))
      ]));
}

class FormPage extends StatelessWidget {
  final String title;
  final VoidCallback onBack;
  final Widget child;
  const FormPage(
      {super.key,
      required this.title,
      required this.onBack,
      required this.child});
  @override
  Widget build(BuildContext context) =>
      ListView(padding: const EdgeInsets.fromLTRB(20, 12, 20, 34), children: [
        Row(children: [
          RoundBack(onTap: onBack),
          const SizedBox(width: 13),
          Text(title, style: _heading)
        ]),
        const SizedBox(height: 28),
        child
      ]);
}

class Avatar extends StatelessWidget {
  final String letter;
  final double size;
  final Color color;
  const Avatar(
      {super.key,
      required this.letter,
      required this.size,
      this.color = _violet});
  @override
  Widget build(BuildContext context) => Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
      child: Text(letter,
          style: TextStyle(
              color: Colors.white,
              fontSize: size * .38,
              fontWeight: FontWeight.w700)));
}

class BottomNav extends StatelessWidget {
  final int tab;
  final ValueChanged<int> onTap;
  const BottomNav({super.key, required this.tab, required this.onTap});
  @override
  Widget build(BuildContext context) => NavigationBar(
          selectedIndex: tab,
          onDestinationSelected: onTap,
          height: 68,
          destinations: const [
            NavigationDestination(
                icon: Icon(Icons.explore_outlined),
                selectedIcon: Icon(Icons.explore),
                label: 'Discover'),
            NavigationDestination(
                icon: Icon(Icons.luggage_outlined),
                selectedIcon: Icon(Icons.luggage),
                label: 'My Trips'),
            NavigationDestination(
                icon: Icon(Icons.person_outline),
                selectedIcon: Icon(Icons.person),
                label: 'Profile')
          ]);
}

class ChipButton extends StatelessWidget {
  final String label;
  final bool active, small;
  final VoidCallback? onTap;
  const ChipButton(
      {super.key,
      required this.label,
      this.active = false,
      this.small = false,
      this.onTap});
  @override
  Widget build(BuildContext context) => InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(999),
      child: Container(
          padding: EdgeInsets.symmetric(
              horizontal: small ? 9 : 14, vertical: small ? 4 : 7),
          decoration: BoxDecoration(
              color: active ? _violet : Colors.white,
              border: Border.all(color: active ? _violet : _border),
              borderRadius: BorderRadius.circular(999)),
          child: Text(label,
              style: TextStyle(
                  color: active ? Colors.white : _muted,
                  fontSize: small ? 11 : 13,
                  fontWeight: FontWeight.w600))));
}

class VerifiedBadge extends StatelessWidget {
  final bool glass;
  const VerifiedBadge({super.key, this.glass = false});
  @override
  Widget build(BuildContext context) => Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
      decoration: BoxDecoration(
          color: glass ? Colors.white.withValues(alpha: .2) : _lavender,
          borderRadius: BorderRadius.circular(99)),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(Icons.verified_rounded,
            size: 13, color: glass ? Colors.white : _violet),
        const SizedBox(width: 3),
        Text('Verified',
            style: TextStyle(
                color: glass ? Colors.white : _violet,
                fontSize: 11,
                fontWeight: FontWeight.w700))
      ]));
}

class SlotChip extends StatelessWidget {
  const SlotChip({super.key});
  @override
  Widget build(BuildContext context) => Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
          color: const Color(0xFFDCFCE7),
          borderRadius: BorderRadius.circular(99)),
      child: const Text('3 spots left',
          style: TextStyle(
              color: Color(0xFF16803B),
              fontSize: 11,
              fontWeight: FontWeight.w700)));
}

class PrimaryButton extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  const PrimaryButton({super.key, required this.label, required this.onTap});
  @override
  Widget build(BuildContext context) => SizedBox(
      width: double.infinity,
      height: 50,
      child: FilledButton(
          onPressed: onTap,
          style: FilledButton.styleFrom(
              backgroundColor: _violet,
              foregroundColor: Colors.white,
              shape: const StadiumBorder()),
          child: Text(label,
              style:
                  const TextStyle(fontWeight: FontWeight.w700, fontSize: 15))));
}

class OutlineButton extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  const OutlineButton({super.key, required this.label, required this.onTap});
  @override
  Widget build(BuildContext context) => SizedBox(
      width: double.infinity,
      height: 50,
      child: OutlinedButton(
          onPressed: onTap,
          style: OutlinedButton.styleFrom(
              foregroundColor: _ink,
              side: const BorderSide(color: _border),
              shape: const StadiumBorder()),
          child: Text(label,
              style: const TextStyle(fontWeight: FontWeight.w700))));
}

class SmallPrimary extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  const SmallPrimary({super.key, required this.label, required this.onTap});
  @override
  Widget build(BuildContext context) => SizedBox(
      height: 43,
      child: FilledButton(
          onPressed: onTap,
          style: FilledButton.styleFrom(
              backgroundColor: _violet,
              padding: const EdgeInsets.symmetric(horizontal: 8),
              shape: const StadiumBorder()),
          child: Text(label,
              style:
                  const TextStyle(fontSize: 11, fontWeight: FontWeight.w700))));
}

class SmallOutline extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  const SmallOutline({super.key, required this.label, required this.onTap});
  @override
  Widget build(BuildContext context) => SizedBox(
      height: 43,
      child: OutlinedButton(
          onPressed: onTap,
          style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              side: const BorderSide(color: _border),
              shape: const StadiumBorder()),
          child: Text(label,
              style: const TextStyle(
                  fontSize: 11, color: _ink, fontWeight: FontWeight.w700))));
}

class AppField extends StatelessWidget {
  final String hint;
  final IconData? icon;
  final int lines;
  const AppField({super.key, required this.hint, this.icon, this.lines = 1});
  @override
  Widget build(BuildContext context) => TextField(
      maxLines: lines,
      decoration: InputDecoration(
          hintText: hint,
          hintStyle: const TextStyle(color: _muted, fontSize: 14),
          suffixIcon: icon == null ? null : Icon(icon, size: 19, color: _muted),
          filled: true,
          fillColor: Colors.white,
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: _border)),
          enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: _border))));
}

class FieldLabel extends StatelessWidget {
  final String text;
  const FieldLabel(this.text, {super.key});
  @override
  Widget build(BuildContext context) => Text(text, style: _label);
}

class RangeTitle extends StatelessWidget {
  final String left, right;
  const RangeTitle({super.key, required this.left, required this.right});
  @override
  Widget build(BuildContext context) => Padding(
      padding: const EdgeInsets.only(top: 7),
      child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        Text(left,
            style: const TextStyle(fontWeight: FontWeight.w700, color: _ink)),
        Text(right,
            style: const TextStyle(fontWeight: FontWeight.w700, color: _ink))
      ]));
}

class Segmented extends StatelessWidget {
  const Segmented({super.key});
  @override
  Widget build(BuildContext context) => Row(
      children: ['Any', 'Female', 'Male']
          .map((x) => Expanded(
              child: Padding(
                  padding: EdgeInsets.only(right: x == 'Male' ? 0 : 8),
                  child: ChipButton(label: x, active: x == 'Any'))))
          .toList());
}

class StyleWrap extends StatelessWidget {
  const StyleWrap({super.key});
  @override
  Widget build(BuildContext context) =>
      const Wrap(spacing: 8, runSpacing: 8, children: [
        ChipButton(label: 'Adventure', active: true),
        ChipButton(label: 'Foodie'),
        ChipButton(label: 'Luxury'),
        ChipButton(label: 'Backpacker'),
        ChipButton(label: 'Nature', active: true),
        ChipButton(label: 'Culture')
      ]);
}

class RoundBack extends StatelessWidget {
  final VoidCallback onTap;
  const RoundBack({super.key, required this.onTap});
  @override
  Widget build(BuildContext context) => Material(
      color: Colors.white.withValues(alpha: .94),
      shape: const CircleBorder(),
      child: InkWell(
          onTap: onTap,
          customBorder: const CircleBorder(),
          child: const SizedBox(
              width: 38,
              height: 38,
              child: Icon(Icons.arrow_back, color: _ink, size: 20))));
}

class InfoRows extends StatelessWidget {
  const InfoRows({super.key});
  @override
  Widget build(BuildContext context) => const Column(children: [
        InfoRow(
            icon: Icons.payments_outlined, label: 'Budget', value: '\$1,800'),
        InfoRow(
            icon: Icons.group_outlined,
            label: 'Available slots',
            value: '3 of 6'),
        InfoRow(
            icon: Icons.person_outline,
            label: 'Preferred gender',
            value: 'Any'),
        InfoRow(
            icon: Icons.cake_outlined, label: 'Preferred age', value: '24 — 38')
      ]);
}

class InfoRow extends StatelessWidget {
  final IconData icon;
  final String label, value;
  const InfoRow(
      {super.key,
      required this.icon,
      required this.label,
      required this.value});
  @override
  Widget build(BuildContext context) => Container(
      padding: const EdgeInsets.symmetric(vertical: 14),
      decoration: const BoxDecoration(
          border: Border(bottom: BorderSide(color: _border))),
      child: Row(children: [
        Icon(icon, color: _violet, size: 20),
        const SizedBox(width: 12),
        Text(label, style: const TextStyle(color: _muted)),
        const Spacer(),
        Text(value,
            style: const TextStyle(color: _ink, fontWeight: FontWeight.w700))
      ]));
}

class CompactTrip extends StatelessWidget {
  final String destination;
  final String dates;
  final String members;
  final String image;
  final String status;
  final VoidCallback? onManage;
  final VoidCallback? onEdit;
  const CompactTrip({
    super.key,
    required this.destination,
    required this.dates,
    required this.members,
    this.image = _tokyo,
    this.status = 'Active',
    this.onManage,
    this.onEdit,
  });
  @override
  Widget build(BuildContext context) => Container(
      decoration: _cardDecoration(),
      clipBehavior: Clip.antiAlias,
      child: Column(children: [
        Padding(
            padding: const EdgeInsets.all(12),
            child: Row(children: [
              SizedBox(
                  width: 92,
                  height: 92,
                  child: TravelImage(url: image, radius: 10)),
              const SizedBox(width: 13),
              Expanded(
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                    Row(children: [
                      Expanded(
                          child: Text(destination,
                              style: const TextStyle(
                                  fontFamily: 'Georgia',
                                  fontWeight: FontWeight.w600,
                                  color: _ink,
                                  fontSize: 18))),
                      _Status(label: status)
                    ]),
                    const SizedBox(height: 8),
                    Text(dates, style: _label),
                    const SizedBox(height: 9),
                    Text(members,
                        style: const TextStyle(color: _muted, fontSize: 12))
                  ]))
            ])),
        Container(
            decoration: const BoxDecoration(
                border: Border(top: BorderSide(color: _border))),
            child: Row(children: [
              Expanded(
                  child:
                      TextButton(onPressed: onEdit, child: const Text('Edit'))),
              Expanded(
                  child: TextButton(
                      onPressed: onManage, child: const Text('Requests'))),
              Expanded(
                  child: TextButton(
                      onPressed: () {},
                      child: const Text('Delete',
                          style: TextStyle(color: Color(0xFFDC2626)))))
            ]))
      ]));
}

class ApplicantCard extends StatelessWidget {
  final String name, letter;
  final String status;
  final VoidCallback? onTap;
  const ApplicantCard(
      {super.key,
      required this.name,
      required this.letter,
      this.status = 'Pending',
      this.onTap});
  @override
  Widget build(BuildContext context) => Container(
      padding: const EdgeInsets.all(16),
      decoration: _cardDecoration(),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          InkWell(
              onTap: onTap,
              borderRadius: BorderRadius.circular(24),
              child: Avatar(
                  letter: letter, size: 46, color: const Color(0xFFBB9AF2))),
          const SizedBox(width: 10),
          Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                Row(children: [
                  Text(name,
                      style: const TextStyle(
                          color: _ink, fontWeight: FontWeight.w700)),
                  const SizedBox(width: 5),
                  const VerifiedBadge()
                ]),
                const Text('28 · Female',
                    style: TextStyle(color: _muted, fontSize: 12))
              ])),
          _Status(label: status)
        ]),
        const SizedBox(height: 12),
        const Wrap(spacing: 6, children: [
          ChipButton(label: 'Adventure', small: true),
          ChipButton(label: 'Culture', small: true)
        ]),
        const SizedBox(height: 12),
        const Text(
            '“I love trips that leave space for unexpected detours and good meals.”',
            style: TextStyle(
                fontStyle: FontStyle.italic, color: _muted, height: 1.45)),
        if (status == 'Pending') ...[
          const SizedBox(height: 14),
          Row(children: const [
            Expanded(
                child: StatusButton(
                    label: 'Accept',
                    color: Color(0xFFDCFCE7),
                    text: Color(0xFF16A34A))),
            SizedBox(width: 7),
            Expanded(
                child: StatusButton(
                    label: 'Hold',
                    color: Color(0xFFFEF9C3),
                    text: Color(0xFFD97706))),
            SizedBox(width: 7),
            Expanded(
                child: StatusButton(
                    label: 'Decline',
                    color: Color(0xFFFEE2E2),
                    text: Color(0xFFDC2626)))
          ])
        ]
      ]));
}

class StatusButton extends StatelessWidget {
  final String label;
  final Color color, text;
  const StatusButton(
      {super.key,
      required this.label,
      required this.color,
      required this.text});
  @override
  Widget build(BuildContext context) => SizedBox(
      height: 42,
      child: TextButton(
          onPressed: () {},
          style: TextButton.styleFrom(
              backgroundColor: color,
              foregroundColor: text,
              shape: const StadiumBorder()),
          child: Text(label,
              style:
                  const TextStyle(fontWeight: FontWeight.w700, fontSize: 12))));
}

class _Status extends StatelessWidget {
  final String label;
  const _Status({required this.label});
  @override
  Widget build(BuildContext context) {
    final c = label == 'Active'
        ? const Color(0xFF16A34A)
        : label == 'Draft' || label == 'Held'
            ? const Color(0xFFD97706)
            : _muted;
    return Container(
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
        decoration: BoxDecoration(
            border: Border.all(color: c.withValues(alpha: .25)),
            borderRadius: BorderRadius.circular(99)),
        child: Text(label,
            style: TextStyle(
                color: c, fontSize: 10, fontWeight: FontWeight.w700)));
  }
}

class _Counter extends StatelessWidget {
  const _Counter();
  @override
  Widget build(BuildContext context) => Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: .22),
          borderRadius: BorderRadius.circular(99)),
      child: const Text('1 / 4',
          style: TextStyle(
              color: Colors.white, fontSize: 11, fontWeight: FontWeight.w700)));
}

class _SmallDiscoverCard extends StatelessWidget {
  const _SmallDiscoverCard();
  @override
  Widget build(BuildContext context) => Container(
      height: 170,
      decoration: _cardDecoration(radius: 20),
      clipBehavior: Clip.antiAlias,
      child: Row(children: [
        const Expanded(child: TravelImage(url: _kyoto)),
        Expanded(
            child: Padding(
                padding: EdgeInsets.all(16),
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text('Kyoto, Japan',
                          style: TextStyle(
                              fontFamily: 'Georgia',
                              fontSize: 20,
                              fontWeight: FontWeight.w600,
                              color: _ink)),
                      SizedBox(height: 8),
                      Text('OCT 8 — OCT 15', style: _label),
                      SizedBox(height: 10),
                      Text('Culture · Foodie',
                          style: TextStyle(color: _muted, fontSize: 12))
                    ])))
      ]));
}

class TravelImage extends StatelessWidget {
  final String url;
  final double? radius;
  const TravelImage({super.key, required this.url, this.radius});
  @override
  Widget build(BuildContext context) => ClipRRect(
      borderRadius:
          radius == null ? BorderRadius.zero : BorderRadius.circular(radius!),
      child: Image.network(url,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) =>
              const ColoredBox(color: Color(0xFFEDE9FE))));
}

class Stat extends StatelessWidget {
  final String number, label;
  const Stat({super.key, required this.number, required this.label});
  @override
  Widget build(BuildContext context) => Column(children: [
        Text(number,
            style: const TextStyle(
                fontFamily: 'Georgia',
                fontSize: 22,
                color: _ink,
                fontWeight: FontWeight.w600)),
        Text(label, style: _label)
      ]);
}

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
const _display = TextStyle(
    fontFamily: 'Georgia',
    color: _ink,
    fontSize: 29,
    fontWeight: FontWeight.w600,
    letterSpacing: -.9);
const _heading = TextStyle(
    fontFamily: 'Georgia',
    color: _ink,
    fontSize: 24,
    fontWeight: FontWeight.w600,
    letterSpacing: -.6);
const _label = TextStyle(
    color: _muted,
    fontSize: 11,
    fontWeight: FontWeight.w700,
    letterSpacing: .5);
void _noop(double _) {}
const _tokyo =
    'https://images.unsplash.com/photo-1518005020951-eccb494ad742?auto=format&fit=crop&w=1200&q=85';
const _kyoto =
    'https://images.unsplash.com/photo-1493976040374-85c8e12f0c0e?auto=format&fit=crop&w=900&q=85';
const _bali =
    'https://images.unsplash.com/photo-1537996194471-e657df975ab4?auto=format&fit=crop&w=900&q=85';
const _paris =
    'https://images.unsplash.com/photo-1502602898657-3e91760cbb34?auto=format&fit=crop&w=900&q=85';
