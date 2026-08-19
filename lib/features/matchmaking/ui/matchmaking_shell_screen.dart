import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:uuid/uuid.dart';

import '../../common/ui/widgets/app_module_navigation.dart';
import '../../../routing/routes.dart';
import '../model/matchmaking_models.dart';
import '../model/matchmaking_page.dart';
import 'view_model/matchmaking_view_model_v2.dart';

const _ink = Color(0xFF281950);
const _violet = Color(0xFF7C3AED);
const _border = Color(0xFFD5CFEF);
const _muted = Color(0xFF686082);
const _lavender = Color(0xFFEDE9FE);

class MatchmakingShellScreen extends ConsumerStatefulWidget {
  const MatchmakingShellScreen({
    super.key,
    this.initialPage = MatchmakingPage.discover,
  });

  final MatchmakingPage initialPage;

  @override
  ConsumerState<MatchmakingShellScreen> createState() =>
      _MatchmakingShellScreenState();
}

class _MatchmakingShellScreenState
    extends ConsumerState<MatchmakingShellScreen> {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(matchmakingViewModelV2Provider);
    final viewModel = ref.read(matchmakingViewModelV2Provider.notifier);
    final page = state.page;
    final content = switch (page) {
      MatchmakingPage.discover => DiscoverPage(
          filter: state.selectedFilter,
          trips: state.discoveryTrips,
          savedTripIds: state.savedTripIds,
          filters: state.availableFilters,
          onFilter: viewModel.selectFilter,
          onOpenFilters: () => viewModel.goTo(MatchmakingPage.filters),
          onOpenMyTrips: () => viewModel.goTo(MatchmakingPage.myTrips),
          onDetails: (id) => viewModel.openTrip(id, MatchmakingPage.details),
          onRequest: (id) => viewModel.openTrip(id, MatchmakingPage.request),
          onSave: viewModel.toggleSavedTrip),
      MatchmakingPage.filters => InteractiveFilterPage(
          initialFilters: state.filters,
          onBack: () => viewModel.goTo(MatchmakingPage.discover),
          onApply: viewModel.applyFilters,
          onReset: viewModel.resetFilters),
      MatchmakingPage.details => TripDetailsPage(
          trip: state.selectedTrip!,
          onBack: () => viewModel.goTo(MatchmakingPage.discover),
          onRequest: () => viewModel.goTo(MatchmakingPage.request)),
      MatchmakingPage.create => InteractiveTripFormPage(
          onBack: () => viewModel.goTo(MatchmakingPage.myTrips),
          onPublish: viewModel.saveTrip),
      MatchmakingPage.edit => InteractiveTripFormPage(
          edit: true,
          initialTrip: state.selectedTrip,
          onBack: () => viewModel.goTo(MatchmakingPage.myTrips),
          onPublish: viewModel.saveTrip,
          onDelete: () => viewModel.deleteTrip(state.selectedTrip!.id)),
      MatchmakingPage.myTrips => MyTripsPage(
          trips: state.ownedTrips,
          onBack: () => viewModel.goTo(MatchmakingPage.discover),
          onCreate: () => viewModel.goTo(MatchmakingPage.create),
          onManage: viewModel.openRequests,
          onEdit: (id) => viewModel.openTrip(id, MatchmakingPage.edit),
          onDelete: viewModel.deleteTrip),
      MatchmakingPage.request => RequestPage(
          trip: state.selectedTrip!,
          onCancel: () => viewModel.goTo(MatchmakingPage.details),
          onSend: (message) =>
              viewModel.sendRequest(state.selectedTrip!.id, message)),
      MatchmakingPage.sent =>
        RequestSentPage(onBack: () => viewModel.goTo(MatchmakingPage.discover)),
      MatchmakingPage.manage => ManageRequestsPage(
          trip: state.managedTrip!,
          requests: state.managedRequests,
          applicants: state.applicants,
          onBack: () => viewModel.goTo(MatchmakingPage.myTrips),
          onApplicant: viewModel.openApplicant,
          onDecision: viewModel.decideRequest),
      MatchmakingPage.applicant => ApplicantPage(
          applicant: state.selectedApplicant!,
          request: state.managedRequests.firstWhere(
              (item) => item.applicantId == state.selectedApplicantId),
          onDecision: (id, decision) {
            viewModel.decideRequest(id, decision);
            viewModel.goTo(MatchmakingPage.manage);
          },
          onBack: () => viewModel.goTo(MatchmakingPage.manage)),
      MatchmakingPage.profile => const ProfilePage(),
    };
    return Scaffold(
      body: SafeArea(
          child: Column(children: [
        if (state.isLoading) const LinearProgressIndicator(minHeight: 3),
        if (state.errorMessage != null)
          Material(
              color: const Color(0xFFFFE8E8),
              child: Padding(
                  padding: const EdgeInsets.all(10),
                  child: Row(children: [
                    const Icon(Icons.error_outline, color: Colors.red),
                    const SizedBox(width: 8),
                    Expanded(
                        child: Text('Could not sync with Supabase: '
                            '${state.errorMessage}')),
                    TextButton(
                        onPressed: viewModel.refresh,
                        child: const Text('Retry'))
                  ]))),
        Expanded(child: content)
      ])),
      bottomNavigationBar:
          page == MatchmakingPage.discover || page == MatchmakingPage.myTrips
              ? AppModuleNavigation(
                  selectedIndex: page == MatchmakingPage.myTrips ? 1 : 0,
                )
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
  final List<MatchmakingTrip> trips;
  final Set<String> savedTripIds;
  final List<String> filters;
  final ValueChanged<String> onFilter;
  final VoidCallback onOpenFilters, onOpenMyTrips;
  final ValueChanged<String> onDetails, onRequest, onSave;
  const DiscoverPage(
      {super.key,
      required this.filter,
      required this.trips,
      required this.savedTripIds,
      required this.filters,
      required this.onFilter,
      required this.onOpenFilters,
      required this.onOpenMyTrips,
      required this.onDetails,
      required this.onRequest,
      required this.onSave});

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
                    onPressed: onOpenFilters,
                    icon: const Icon(Icons.tune_rounded, color: _ink)),
                IconButton(
                    tooltip: 'My Trips',
                    onPressed: onOpenMyTrips,
                    icon: const Icon(Icons.luggage_outlined, color: _ink)),
                IconButton(
                    onPressed: () => ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('No new notifications.'))),
                    icon: const Icon(Icons.notifications_none_rounded,
                        color: _ink)),
                InkWell(
                    onTap: () => context.go(Routes.userAccount),
                    customBorder: const CircleBorder(),
                    child: const Avatar(letter: 'M', size: 34)),
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
                for (final trip in trips) ...[
                  TripCard(
                      trip: trip,
                      saved: savedTripIds.contains(trip.id),
                      onSave: () => onSave(trip.id),
                      onDetails: () => onDetails(trip.id),
                      onRequest: () => onRequest(trip.id)),
                  const SizedBox(height: 18),
                ],
                if (trips.isEmpty) const _NoTripsFound(),
              ])),
        ]),
      );
}

class _NoTripsFound extends StatelessWidget {
  const _NoTripsFound();
  @override
  Widget build(BuildContext context) => Padding(
      padding: const EdgeInsets.symmetric(vertical: 80, horizontal: 24),
      child: Column(children: [
        const Icon(Icons.search_off_rounded, size: 48, color: _muted),
        const SizedBox(height: 14),
        const Text('No trips found', style: _heading),
        const SizedBox(height: 7),
        Text('Try another travel style.',
            textAlign: TextAlign.center,
            style: TextStyle(color: _muted.withValues(alpha: .9))),
      ]));
}

class TripCard extends StatelessWidget {
  final MatchmakingTrip trip;
  final VoidCallback onDetails, onRequest, onSave;
  final bool saved;
  const TripCard(
      {super.key,
      required this.trip,
      required this.onDetails,
      required this.onRequest,
      required this.onSave,
      required this.saved});
  @override
  Widget build(BuildContext context) => Container(
      decoration: _cardDecoration(radius: 24, feed: true),
      clipBehavior: Clip.antiAlias,
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        SizedBox(
            height: 270,
            child: Stack(fit: StackFit.expand, children: [
              TravelImage(url: trip.imageUrl),
              const DecoratedBox(
                  decoration: BoxDecoration(
                      gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [Colors.transparent, Color(0xCC171025)]))),
              Positioned(top: 14, left: 14, child: VerifiedBadge(glass: true)),
              const Positioned(top: 14, right: 14, child: _Counter()),
              Positioned(
                  left: 20,
                  right: 20,
                  bottom: 18,
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(trip.destination,
                            style: TextStyle(
                                fontFamily: 'Georgia',
                                color: Colors.white,
                                fontSize: 27,
                                fontWeight: FontWeight.w600)),
                        SizedBox(height: 5),
                        Text(_dateRange(trip.startDate, trip.endDate),
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
              Row(children: [
                Avatar(
                    letter: trip.hostInitials,
                    size: 40,
                    color: const Color(0xFFB59BF1)),
                const SizedBox(width: 10),
                Expanded(
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                      Text(trip.hostName,
                          style: TextStyle(
                              color: _ink, fontWeight: FontWeight.w700)),
                      const Text('Trip organizer',
                          style: TextStyle(color: _muted, fontSize: 12))
                    ])),
                Text('\$${trip.budget}',
                    style: TextStyle(
                        color: _ink, fontWeight: FontWeight.w700, fontSize: 16))
              ]),
              const SizedBox(height: 14),
              Wrap(spacing: 7, runSpacing: 7, children: [
                ...trip.styles
                    .map((style) => ChipButton(label: style, small: true)),
                SlotChip(spots: trip.spotsLeft)
              ]),
              const SizedBox(height: 13),
              Text(trip.description,
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
                  onPressed: onSave,
                  icon: Icon(
                      saved
                          ? Icons.favorite_rounded
                          : Icons.favorite_border_rounded,
                      color: _violet),
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

class InteractiveFilterPage extends StatefulWidget {
  final VoidCallback onBack, onReset;
  final ValueChanged<MatchmakingFilters> onApply;
  final MatchmakingFilters initialFilters;
  const InteractiveFilterPage(
      {super.key,
      required this.initialFilters,
      required this.onBack,
      required this.onApply,
      required this.onReset});

  @override
  State<InteractiveFilterPage> createState() => _InteractiveFilterPageState();
}

class _InteractiveFilterPageState extends State<InteractiveFilterPage> {
  final _destination = TextEditingController();
  final _start = TextEditingController();
  final _end = TextEditingController();
  RangeValues _budget = const RangeValues(500, 2500);
  RangeValues _ages = const RangeValues(22, 35);
  String _gender = 'Any';
  final _styles = <String>{};
  static const _styleOptions = [
    'Adventure',
    'Foodie',
    'Luxury',
    'Backpacker',
    'Nature',
    'Culture'
  ];

  @override
  void initState() {
    super.initState();
    final filters = widget.initialFilters;
    _destination.text = filters.destination;
    _start.text =
        filters.startDate == null ? '' : _dateInput(filters.startDate!);
    _end.text = filters.endDate == null ? '' : _dateInput(filters.endDate!);
    _budget =
        RangeValues(filters.minBudget.toDouble(), filters.maxBudget.toDouble());
    _ages = RangeValues(filters.minAge.toDouble(), filters.maxAge.toDouble());
    _gender = filters.gender;
    _styles.addAll(filters.styles);
  }

  @override
  void dispose() {
    _destination.dispose();
    _start.dispose();
    _end.dispose();
    super.dispose();
  }

  InputDecoration _decoration(String hint, {IconData? icon}) => InputDecoration(
      hintText: hint,
      suffixIcon: icon == null ? null : Icon(icon, size: 19, color: _muted),
      filled: true,
      fillColor: Colors.white,
      border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: _border)),
      enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: _border)));

  Future<void> _pickDate(TextEditingController controller) async {
    final date = await showDatePicker(
        context: context,
        initialDate: DateTime.now(),
        firstDate: DateTime.now(),
        lastDate: DateTime.now().add(const Duration(days: 3650)));
    if (date != null) {
      controller.text = '${date.day.toString().padLeft(2, '0')}/'
          '${date.month.toString().padLeft(2, '0')}/${date.year}';
    }
  }

  Widget _dateField(TextEditingController controller, String hint) => TextField(
      controller: controller,
      keyboardType: TextInputType.number,
      inputFormatters: const [_DateInputFormatter()],
      decoration: _decoration(hint, icon: Icons.calendar_today_outlined),
      onTap: () => _pickDate(controller));

  void _reset() {
    setState(() {
      _destination.clear();
      _start.clear();
      _end.clear();
      _budget = const RangeValues(0, 10000);
      _ages = const RangeValues(18, 80);
      _gender = 'Any';
      _styles.clear();
    });
    widget.onReset();
  }

  DateTime? _parseOptionalDate(String value) {
    if (value.isEmpty) return null;
    final parts = value.split('/');
    if (parts.length != 3) return null;
    final day = int.tryParse(parts[0]);
    final month = int.tryParse(parts[1]);
    final year = int.tryParse(parts[2]);
    if (day == null || month == null || year == null) return null;
    final date = DateTime(year, month, day);
    return date.day == day && date.month == month && date.year == year
        ? date
        : null;
  }

  void _apply() {
    final start = _parseOptionalDate(_start.text);
    final end = _parseOptionalDate(_end.text);
    if ((_start.text.isNotEmpty && start == null) ||
        (_end.text.isNotEmpty && end == null) ||
        (start != null && end != null && end.isBefore(start))) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Enter a valid date range.')));
      return;
    }
    widget.onApply(MatchmakingFilters(
      destination: _destination.text.trim(),
      startDate: start,
      endDate: end,
      minBudget: _budget.start.round(),
      maxBudget: _budget.end.round(),
      minAge: _ages.start.round(),
      maxAge: _ages.end.round(),
      gender: _gender,
      styles: {..._styles},
    ));
  }

  @override
  Widget build(BuildContext context) => FormPage(
      title: 'Search & filter',
      onBack: widget.onBack,
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const FieldLabel('DESTINATION'),
        TextField(
            controller: _destination,
            decoration: _decoration('Where would you like to go?')),
        const SizedBox(height: 22),
        const FieldLabel('DATE RANGE'),
        const SizedBox(height: 8),
        Row(children: [
          Expanded(child: _dateField(_start, 'Start date')),
          const SizedBox(width: 12),
          Expanded(child: _dateField(_end, 'End date'))
        ]),
        const SizedBox(height: 22),
        const FieldLabel('BUDGET'),
        RangeTitle(
            left: '\$${_budget.start.round()}',
            right: '\$${_budget.end.round()}'),
        RangeSlider(
            values: _budget,
            min: 0,
            max: 10000,
            divisions: 100,
            labels: RangeLabels(
                '\$${_budget.start.round()}', '\$${_budget.end.round()}'),
            onChanged: (value) => setState(() => _budget = value)),
        const SizedBox(height: 16),
        const FieldLabel('AGE RANGE'),
        RangeTitle(
            left: _ages.start.round().toString(),
            right: _ages.end.round().toString()),
        RangeSlider(
            values: _ages,
            min: 18,
            max: 80,
            divisions: 62,
            labels: RangeLabels(
                _ages.start.round().toString(), _ages.end.round().toString()),
            onChanged: (value) => setState(() => _ages = value)),
        const SizedBox(height: 18),
        const FieldLabel('PREFERRED GENDER'),
        const SizedBox(height: 8),
        Row(
            children: ['Any', 'Female', 'Male']
                .map((gender) => Expanded(
                    child: Padding(
                        padding:
                            EdgeInsets.only(right: gender == 'Male' ? 0 : 8),
                        child: ChipButton(
                            label: gender,
                            active: _gender == gender,
                            onTap: () => setState(() => _gender = gender)))))
                .toList()),
        const SizedBox(height: 22),
        const FieldLabel('TRAVEL STYLE'),
        const SizedBox(height: 8),
        Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _styleOptions
                .map((style) => ChipButton(
                    label: style,
                    active: _styles.contains(style),
                    onTap: () => setState(() => _styles.contains(style)
                        ? _styles.remove(style)
                        : _styles.add(style))))
                .toList()),
        const SizedBox(height: 32),
        PrimaryButton(label: 'Apply Filters', onTap: _apply),
        const SizedBox(height: 10),
        OutlineButton(label: 'Reset', onTap: _reset),
      ]));
}

class TripDetailsPage extends StatelessWidget {
  final MatchmakingTrip trip;
  final VoidCallback onBack, onRequest;
  const TripDetailsPage(
      {super.key,
      required this.trip,
      required this.onBack,
      required this.onRequest});
  @override
  Widget build(BuildContext context) => Stack(children: [
        ListView(padding: EdgeInsets.zero, children: [
          SizedBox(
              height: 240,
              child: Stack(fit: StackFit.expand, children: [
                TravelImage(url: trip.imageUrl),
                Positioned(top: 16, left: 16, child: RoundBack(onTap: onBack))
              ])),
          Padding(
              padding: const EdgeInsets.fromLTRB(20, 22, 20, 100),
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(trip.destination, style: _heading),
                    const SizedBox(height: 5),
                    Text(_dateRange(trip.startDate, trip.endDate),
                        style: _label),
                    const SizedBox(height: 20),
                    InfoRows(trip: trip),
                    const SizedBox(height: 24),
                    const FieldLabel('TRIP HOST'),
                    const SizedBox(height: 9),
                    Row(children: [
                      Avatar(
                          letter: trip.hostInitials,
                          size: 46,
                          color: const Color(0xFFB59BF1)),
                      const SizedBox(width: 11),
                      Text(trip.hostName,
                          style: TextStyle(
                              fontWeight: FontWeight.w700, color: _ink)),
                      const SizedBox(width: 8),
                      if (trip.verifiedHost) const VerifiedBadge()
                    ]),
                    const SizedBox(height: 24),
                    const FieldLabel('TRAVEL STYLE'),
                    const SizedBox(height: 9),
                    Wrap(
                        spacing: 8,
                        children: trip.styles
                            .map((style) =>
                                ChipButton(label: style, active: true))
                            .toList()),
                    const SizedBox(height: 24),
                    const FieldLabel('ABOUT THIS TRIP'),
                    const SizedBox(height: 9),
                    Text(trip.description,
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

class InteractiveTripFormPage extends StatefulWidget {
  final VoidCallback onBack;
  final ValueChanged<MatchmakingTrip> onPublish;
  final VoidCallback? onDelete;
  final MatchmakingTrip? initialTrip;
  final bool edit;
  const InteractiveTripFormPage(
      {super.key,
      required this.onBack,
      required this.onPublish,
      this.onDelete,
      this.initialTrip,
      this.edit = false});

  @override
  State<InteractiveTripFormPage> createState() =>
      _InteractiveTripFormPageState();
}

class _InteractiveTripFormPageState extends State<InteractiveTripFormPage> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _destination,
      _start,
      _end,
      _budget,
      _vacancies,
      _description;
  final _styles = <String>{};
  String _gender = 'Any';
  RangeValues _ages = const RangeValues(22, 40);
  static const _styleOptions = [
    'Adventure',
    'Foodie',
    'Luxury',
    'Backpacker',
    'Nature',
    'Culture'
  ];

  @override
  void initState() {
    super.initState();
    final trip = widget.initialTrip;
    _destination = TextEditingController(text: trip?.destination ?? '');
    _start = TextEditingController(
        text: trip == null ? '' : _dateInput(trip.startDate));
    _end = TextEditingController(
        text: trip == null ? '' : _dateInput(trip.endDate));
    _budget = TextEditingController(text: trip?.budget.toString() ?? '');
    _vacancies = TextEditingController(text: trip?.vacancies.toString() ?? '');
    _description = TextEditingController(text: trip?.description ?? '');
    if (trip != null) {
      _styles.addAll(trip.styles);
      _gender = trip.gender;
      _ages = RangeValues(trip.minAge.toDouble(), trip.maxAge.toDouble());
    }
  }

  @override
  void dispose() {
    for (final item in [
      _destination,
      _start,
      _end,
      _budget,
      _vacancies,
      _description
    ]) {
      item.dispose();
    }
    super.dispose();
  }

  InputDecoration _decoration(String hint, {String? prefix, IconData? icon}) =>
      InputDecoration(
          hintText: hint,
          prefixText: prefix,
          suffixIcon: icon == null ? null : Icon(icon, size: 19),
          filled: true,
          fillColor: Colors.white,
          border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: _border)),
          enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: _border)));

  Widget _field(TextEditingController controller, String hint,
          {TextInputType? keyboard,
          List<TextInputFormatter>? formatters,
          String? prefix,
          IconData? icon,
          int lines = 1,
          VoidCallback? onTap}) =>
      TextFormField(
          controller: controller,
          keyboardType: keyboard,
          inputFormatters: formatters,
          maxLines: lines,
          onTap: onTap,
          decoration: _decoration(hint, prefix: prefix, icon: icon),
          validator: (value) =>
              value == null || value.trim().isEmpty ? 'Required' : null);

  Future<void> _pickDate(TextEditingController controller) async {
    final date = await showDatePicker(
        context: context,
        initialDate: DateTime.now(),
        firstDate: DateTime.now(),
        lastDate: DateTime.now().add(const Duration(days: 3650)));
    if (date != null) {
      controller.text = '${date.day.toString().padLeft(2, '0')}/'
          '${date.month.toString().padLeft(2, '0')}/${date.year}';
    }
  }

  void _submit() {
    if (!_formKey.currentState!.validate() || _styles.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Complete all fields and select a travel style.')));
      return;
    }
    final start = _parseDate(_start.text);
    final end = _parseDate(_end.text);
    if (start == null || end == null || end.isBefore(start)) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('End date cannot be earlier than start date.')));
      return;
    }
    widget.onPublish(MatchmakingTrip(
      id: widget.initialTrip?.id ?? const Uuid().v4(),
      destination: _destination.text.trim(),
      startDate: start,
      endDate: end,
      budget: int.parse(_budget.text),
      styles: {..._styles},
      hostId: widget.initialTrip?.hostId ?? 'current-user',
      hostName: widget.initialTrip?.hostName ?? 'Morgan Lee',
      hostInitials: widget.initialTrip?.hostInitials ?? 'ML',
      imageUrl: widget.initialTrip?.imageUrl ?? _tokyo,
      gender: _gender,
      minAge: _ages.start.round(),
      maxAge: _ages.end.round(),
      vacancies: int.parse(_vacancies.text),
      description: _description.text.trim(),
      joined: widget.initialTrip?.joined ?? 0,
      verifiedHost: widget.initialTrip?.verifiedHost ?? true,
      status: widget.initialTrip?.status ?? TripStatus.active,
      isOwned: true,
    ));
  }

  DateTime? _parseDate(String value) {
    final parts = value.split('/');
    if (parts.length != 3) return null;
    final day = int.tryParse(parts[0]);
    final month = int.tryParse(parts[1]);
    final year = int.tryParse(parts[2]);
    if (day == null || month == null || year == null) return null;
    final date = DateTime(year, month, day);
    return date.year == year && date.month == month && date.day == day
        ? date
        : null;
  }

  Future<void> _delete() async {
    final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
                title: const Text('Delete trip?'),
                content: const Text('This action cannot be undone.'),
                actions: [
                  TextButton(
                      onPressed: () => Navigator.pop(context, false),
                      child: const Text('Cancel')),
                  TextButton(
                      onPressed: () => Navigator.pop(context, true),
                      child: const Text('Delete',
                          style: TextStyle(color: Color(0xFFDC2626))))
                ]));
    if (confirmed == true) widget.onDelete?.call();
  }

  @override
  Widget build(BuildContext context) => FormPage(
        title: widget.edit ? 'Edit Trip' : 'Create Trip',
        onBack: widget.onBack,
        child: Form(
            key: _formKey,
            child: Container(
                padding: const EdgeInsets.all(18),
                decoration: _cardDecoration(),
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const FieldLabel('DESTINATION'),
                      _field(_destination, 'e.g. Tokyo, Japan'),
                      const SizedBox(height: 18),
                      Row(children: [
                        Expanded(
                            child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                              const FieldLabel('START DATE'),
                              const SizedBox(height: 8),
                              _field(_start, 'dd/mm/yyyy',
                                  keyboard: TextInputType.number,
                                  formatters: const [_DateInputFormatter()],
                                  icon: Icons.calendar_today_outlined,
                                  onTap: () => _pickDate(_start))
                            ])),
                        const SizedBox(width: 10),
                        Expanded(
                            child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                              const FieldLabel('END DATE'),
                              const SizedBox(height: 8),
                              _field(_end, 'dd/mm/yyyy',
                                  keyboard: TextInputType.number,
                                  formatters: const [_DateInputFormatter()],
                                  icon: Icons.calendar_today_outlined,
                                  onTap: () => _pickDate(_end))
                            ]))
                      ]),
                      const SizedBox(height: 18),
                      const FieldLabel('BUDGET'),
                      _field(_budget, 'e.g. 1800',
                          prefix: '\$ ',
                          keyboard: TextInputType.number,
                          formatters: [FilteringTextInputFormatter.digitsOnly]),
                      const SizedBox(height: 18),
                      const FieldLabel('TRAVEL STYLE'),
                      Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: _styleOptions
                              .map((style) => ChipButton(
                                  label: style,
                                  active: _styles.contains(style),
                                  onTap: () => setState(() =>
                                      _styles.contains(style)
                                          ? _styles.remove(style)
                                          : _styles.add(style))))
                              .toList()),
                      const SizedBox(height: 18),
                      const FieldLabel('PREFERRED GENDER'),
                      DropdownButtonFormField<String>(
                          initialValue: _gender,
                          decoration: _decoration('Select gender'),
                          items: ['Any', 'Female', 'Male']
                              .map((value) => DropdownMenuItem(
                                  value: value, child: Text(value)))
                              .toList(),
                          onChanged: (value) =>
                              setState(() => _gender = value ?? 'Any')),
                      const SizedBox(height: 18),
                      const FieldLabel('AGE PREFERENCE'),
                      RangeTitle(
                          left: _ages.start.round().toString(),
                          right: _ages.end.round().toString()),
                      RangeSlider(
                          values: _ages,
                          min: 18,
                          max: 80,
                          divisions: 62,
                          labels: RangeLabels(_ages.start.round().toString(),
                              _ages.end.round().toString()),
                          onChanged: (value) => setState(() => _ages = value)),
                      const SizedBox(height: 18),
                      const FieldLabel('AVAILABLE VACANCIES'),
                      _field(_vacancies, 'e.g. 2',
                          keyboard: TextInputType.number,
                          formatters: [FilteringTextInputFormatter.digitsOnly],
                          icon: Icons.people_outline),
                      const SizedBox(height: 18),
                      const FieldLabel('DESCRIPTION'),
                      _field(_description,
                          'Describe your trip and ideal companion...',
                          lines: 4),
                      const SizedBox(height: 24),
                      PrimaryButton(
                          label: widget.edit ? 'Save Changes' : 'Publish Trip',
                          onTap: _submit),
                      if (widget.edit) ...[
                        const SizedBox(height: 10),
                        OutlineButton(label: 'Delete Trip', onTap: _delete)
                      ]
                    ]))),
      );
}

class _DateInputFormatter extends TextInputFormatter {
  const _DateInputFormatter();
  @override
  TextEditingValue formatEditUpdate(
      TextEditingValue oldValue, TextEditingValue newValue) {
    final digits = newValue.text.replaceAll(RegExp(r'\D'), '');
    final clipped = digits.substring(0, digits.length.clamp(0, 8));
    final buffer = StringBuffer();
    for (var i = 0; i < clipped.length; i++) {
      if (i == 2 || i == 4) buffer.write('/');
      buffer.write(clipped[i]);
    }
    final text = buffer.toString();
    return TextEditingValue(
        text: text, selection: TextSelection.collapsed(offset: text.length));
  }
}

class MyTripsPage extends StatelessWidget {
  final VoidCallback onBack, onCreate;
  final List<MatchmakingTrip> trips;
  final ValueChanged<String> onManage, onEdit, onDelete;
  const MyTripsPage(
      {super.key,
      required this.trips,
      required this.onBack,
      required this.onCreate,
      required this.onManage,
      required this.onDelete,
      required this.onEdit});
  @override
  Widget build(BuildContext context) =>
      ListView(padding: const EdgeInsets.fromLTRB(20, 18, 20, 100), children: [
        Row(children: [
          RoundBack(onTap: onBack),
          const SizedBox(width: 13),
          const Text('My trips', style: _display),
        ]),
        const SizedBox(height: 7),
        const Text('Your adventures, all in one place.',
            style: TextStyle(color: _muted)),
        const SizedBox(height: 16),
        OutlineButton(label: '+ Create a new trip', onTap: onCreate),
        const SizedBox(height: 24),
        if (trips.isEmpty) const _NoTripsFound(),
        for (final trip in trips) ...[
          CompactTrip(
              destination: trip.destination,
              dates: _dateRange(trip.startDate, trip.endDate),
              members: '${trip.joined} joined',
              image: trip.imageUrl,
              status: _statusLabel(trip.status),
              onEdit: () => onEdit(trip.id),
              onManage: () => onManage(trip.id),
              onDelete: () => onDelete(trip.id)),
          const SizedBox(height: 14),
        ],
      ]);
}

class RequestPage extends StatefulWidget {
  final MatchmakingTrip trip;
  final VoidCallback onCancel;
  final bool Function(String message) onSend;
  const RequestPage(
      {super.key,
      required this.trip,
      required this.onCancel,
      required this.onSend});

  @override
  State<RequestPage> createState() => _RequestPageState();
}

class _RequestPageState extends State<RequestPage> {
  final _controller = TextEditingController();
  String? _error;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

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
            Text('Joining: ${widget.trip.destination}',
                textAlign: TextAlign.center, style: TextStyle(color: _muted)),
            const SizedBox(height: 28),
            Align(
                alignment: Alignment.centerLeft,
                child: FieldLabel(
                    'MESSAGE TO ${widget.trip.hostName.toUpperCase()}')),
            const SizedBox(height: 8),
            AppField(
                hint:
                    'Introduce yourself and share why this trip feels right for you...',
                lines: 7,
                controller: _controller,
                maxLength: 500,
                onChanged: (_) => setState(() => _error = null)),
            Align(
              alignment: Alignment.centerRight,
              child: Padding(
                  padding: EdgeInsets.only(top: 5),
                  child: Text('${_controller.text.length} / 500',
                      style: const TextStyle(color: _muted, fontSize: 11))),
            ),
            if (_error != null) ...[
              const SizedBox(height: 6),
              Text(_error!, style: const TextStyle(color: Color(0xFFDC2626))),
            ],
            const SizedBox(height: 22),
            PrimaryButton(
                label: 'Send Request',
                onTap: () {
                  if (!widget.onSend(_controller.text)) {
                    setState(() => _error = 'Enter a message before sending.');
                  }
                }),
            const SizedBox(height: 10),
            OutlineButton(label: 'Cancel', onTap: widget.onCancel),
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
  final VoidCallback onBack;
  final MatchmakingTrip trip;
  final List<JoinRequest> requests;
  final List<MatchmakingApplicant> applicants;
  final ValueChanged<String> onApplicant;
  final void Function(String, ApplicantDecision) onDecision;
  const ManageRequestsPage(
      {super.key,
      required this.onBack,
      required this.onApplicant,
      required this.trip,
      required this.requests,
      required this.applicants,
      required this.onDecision});

  MatchmakingApplicant _applicant(String id) =>
      applicants.firstWhere((item) => item.id == id);
  @override
  Widget build(BuildContext context) =>
      ListView(padding: const EdgeInsets.fromLTRB(20, 18, 20, 30), children: [
        Row(children: [
          RoundBack(onTap: onBack),
          const SizedBox(width: 13),
          const Text('Requests', style: _display),
        ]),
        const SizedBox(height: 7),
        Text('${trip.destination} · ${requests.length} applicants',
            style: TextStyle(color: _muted)),
        const SizedBox(height: 22),
        for (final request in requests) ...[
          ApplicantCard(
              applicant: _applicant(request.applicantId),
              onTap: () => onApplicant(request.applicantId),
              status: _decisionLabel(request.decision),
              onDecision: (decision) => onDecision(request.id, decision)),
          const SizedBox(height: 14),
        ]
      ]);
}

class ApplicantPage extends StatelessWidget {
  final MatchmakingApplicant applicant;
  final JoinRequest request;
  final VoidCallback onBack;
  final void Function(String, ApplicantDecision) onDecision;
  const ApplicantPage(
      {super.key,
      required this.applicant,
      required this.request,
      required this.onBack,
      required this.onDecision});
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
                    Center(
                        child: Avatar(
                            letter: applicant.initials,
                            size: 80,
                            color: _violet)),
                    const SizedBox(height: 12),
                    Center(child: Text(applicant.name, style: _heading)),
                    const SizedBox(height: 6),
                    Center(
                        child: Row(mainAxisSize: MainAxisSize.min, children: [
                      if (applicant.verified) const VerifiedBadge(),
                      const SizedBox(width: 7),
                      Text('${applicant.age} · ${applicant.gender}',
                          style: const TextStyle(color: _muted))
                    ])),
                    const SizedBox(height: 24),
                    Row(
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        children: [
                          Stat(number: '${applicant.trips}', label: 'TRIPS'),
                          Stat(number: '${applicant.rating}', label: 'RATING'),
                          Stat(
                              number: '${applicant.languages.length}',
                              label: 'LANGUAGES')
                        ])
                  ])),
          Padding(
              padding: EdgeInsets.fromLTRB(20, 24, 20, 100),
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    FieldLabel('LANGUAGES'),
                    SizedBox(height: 8),
                    Wrap(
                        spacing: 8,
                        children: applicant.languages
                            .map((value) => ChipButton(label: value))
                            .toList()),
                    SizedBox(height: 24),
                    FieldLabel('TRAVEL STYLE'),
                    SizedBox(height: 8),
                    Wrap(
                        spacing: 8,
                        children: applicant.styles
                            .map((value) =>
                                ChipButton(label: value, active: true))
                            .toList()),
                    SizedBox(height: 24),
                    FieldLabel('ABOUT'),
                    SizedBox(height: 8),
                    Text(applicant.bio,
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
                      text: Color(0xFF16A34A),
                      onTap: () =>
                          onDecision(request.id, ApplicantDecision.accepted))),
              const SizedBox(width: 8),
              Expanded(
                  child: StatusButton(
                      label: 'Hold',
                      color: Color(0xFFFEF9C3),
                      text: Color(0xFFD97706),
                      onTap: () =>
                          onDecision(request.id, ApplicantDecision.held))),
              const SizedBox(width: 8),
              Expanded(
                  child: StatusButton(
                      label: 'Decline',
                      color: Color(0xFFFEE2E2),
                      text: Color(0xFFDC2626),
                      onTap: () =>
                          onDecision(request.id, ApplicantDecision.declined)))
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
            child: OutlineButton(
                label: 'Open account',
                onTap: () => context.go(Routes.userAccount)))
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
  final int spots;
  const SlotChip({super.key, this.spots = 3});
  @override
  Widget build(BuildContext context) => Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
          color: const Color(0xFFDCFCE7),
          borderRadius: BorderRadius.circular(99)),
      child: Text('$spots ${spots == 1 ? 'spot' : 'spots'} left',
          style: const TextStyle(
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
  final TextEditingController? controller;
  final ValueChanged<String>? onChanged;
  final int? maxLength;
  const AppField(
      {super.key,
      required this.hint,
      this.icon,
      this.lines = 1,
      this.controller,
      this.onChanged,
      this.maxLength});
  @override
  Widget build(BuildContext context) => TextField(
      controller: controller,
      onChanged: onChanged,
      maxLength: maxLength,
      buildCounter:
          (_, {required currentLength, required isFocused, maxLength}) => null,
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
  final MatchmakingTrip trip;
  const InfoRows({super.key, required this.trip});
  @override
  Widget build(BuildContext context) => Column(children: [
        InfoRow(
            icon: Icons.payments_outlined,
            label: 'Budget',
            value: '\$${trip.budget}'),
        InfoRow(
            icon: Icons.group_outlined,
            label: 'Available slots',
            value: '${trip.spotsLeft} of ${trip.vacancies}'),
        InfoRow(
            icon: Icons.person_outline,
            label: 'Preferred gender',
            value: trip.gender),
        InfoRow(
            icon: Icons.cake_outlined,
            label: 'Preferred age',
            value: '${trip.minAge} — ${trip.maxAge}')
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
  final VoidCallback? onDelete;
  const CompactTrip({
    super.key,
    required this.destination,
    required this.dates,
    required this.members,
    this.image = _tokyo,
    this.status = 'Active',
    this.onManage,
    this.onEdit,
    this.onDelete,
  });

  Future<void> _confirmDelete(BuildContext context) async {
    if (onDelete == null) return;
    final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
                title: const Text('Delete trip?'),
                content:
                    Text('Delete $destination? This action cannot be undone.'),
                actions: [
                  TextButton(
                      onPressed: () => Navigator.pop(context, false),
                      child: const Text('Cancel')),
                  TextButton(
                      onPressed: () => Navigator.pop(context, true),
                      child: const Text('Delete',
                          style: TextStyle(color: Color(0xFFDC2626))))
                ]));
    if (confirmed == true) onDelete?.call();
  }

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
                      onPressed: onDelete == null
                          ? null
                          : () => _confirmDelete(context),
                      child: const Text('Delete',
                          style: TextStyle(color: Color(0xFFDC2626)))))
            ]))
      ]));
}

class ApplicantCard extends StatelessWidget {
  final MatchmakingApplicant applicant;
  final String status;
  final VoidCallback? onTap;
  final ValueChanged<ApplicantDecision>? onDecision;
  const ApplicantCard(
      {super.key,
      required this.applicant,
      this.status = 'Pending',
      this.onTap,
      this.onDecision});
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
                  letter: applicant.initials,
                  size: 46,
                  color: const Color(0xFFBB9AF2))),
          const SizedBox(width: 10),
          Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                Row(children: [
                  Text(applicant.name,
                      style: const TextStyle(
                          color: _ink, fontWeight: FontWeight.w700)),
                  const SizedBox(width: 5),
                  if (applicant.verified) const VerifiedBadge()
                ]),
                Text('${applicant.age} · ${applicant.gender}',
                    style: const TextStyle(color: _muted, fontSize: 12))
              ])),
          _Status(label: status)
        ]),
        const SizedBox(height: 12),
        Wrap(
            spacing: 6,
            children: applicant.styles
                .map((value) => ChipButton(label: value, small: true))
                .toList()),
        const SizedBox(height: 12),
        Text('“${applicant.introduction}”',
            style: TextStyle(
                fontStyle: FontStyle.italic, color: _muted, height: 1.45)),
        if (status == 'Pending') ...[
          const SizedBox(height: 14),
          Row(children: [
            Expanded(
                child: StatusButton(
                    label: 'Accept',
                    color: Color(0xFFDCFCE7),
                    text: Color(0xFF16A34A),
                    onTap: () => onDecision?.call(ApplicantDecision.accepted))),
            const SizedBox(width: 7),
            Expanded(
                child: StatusButton(
                    label: 'Hold',
                    color: Color(0xFFFEF9C3),
                    text: Color(0xFFD97706),
                    onTap: () => onDecision?.call(ApplicantDecision.held))),
            const SizedBox(width: 7),
            Expanded(
                child: StatusButton(
                    label: 'Decline',
                    color: Color(0xFFFEE2E2),
                    text: Color(0xFFDC2626),
                    onTap: () => onDecision?.call(ApplicantDecision.declined)))
          ])
        ] else if (status == 'Held') ...[
          const SizedBox(height: 14),
          Row(children: [
            Expanded(
                child: StatusButton(
                    label: 'Accept',
                    color: const Color(0xFFDCFCE7),
                    text: const Color(0xFF16A34A),
                    onTap: () => onDecision?.call(ApplicantDecision.accepted))),
            const SizedBox(width: 7),
            Expanded(
                child: StatusButton(
                    label: 'Delete',
                    color: const Color(0xFFFEE2E2),
                    text: const Color(0xFFDC2626),
                    onTap: () => onDecision?.call(ApplicantDecision.declined)))
          ])
        ]
      ]));
}

class StatusButton extends StatelessWidget {
  final String label;
  final Color color, text;
  final VoidCallback? onTap;
  const StatusButton(
      {super.key,
      required this.label,
      required this.color,
      required this.text,
      this.onTap});
  @override
  Widget build(BuildContext context) => SizedBox(
      height: 42,
      child: TextButton(
          onPressed: onTap,
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

class TravelImage extends StatelessWidget {
  final String url;
  final double? radius;
  const TravelImage({super.key, required this.url, this.radius});
  @override
  Widget build(BuildContext context) => ClipRRect(
      borderRadius:
          radius == null ? BorderRadius.zero : BorderRadius.circular(radius!),
      child: CachedNetworkImage(
          imageUrl: url,
          fit: BoxFit.cover,
          placeholder: (_, __) => const ColoredBox(color: Color(0xFFEDE9FE)),
          errorWidget: (_, __, ___) => const ColoredBox(
              color: Color(0xFFEDE9FE),
              child: Icon(Icons.image_not_supported_outlined))));
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

String _dateInput(DateTime date) => '${date.day.toString().padLeft(2, '0')}/'
    '${date.month.toString().padLeft(2, '0')}/${date.year}';

String _dateRange(DateTime start, DateTime end) =>
    '${_dateInput(start)} — ${_dateInput(end)}';

String _statusLabel(TripStatus status) => switch (status) {
      TripStatus.active => 'Active',
      TripStatus.closed => 'Closed',
      TripStatus.draft => 'Draft',
    };
const _tokyo =
    'https://images.unsplash.com/photo-1518005020951-eccb494ad742?auto=format&fit=crop&w=1200&q=85';

String _decisionLabel(ApplicantDecision? decision) => switch (decision) {
      ApplicantDecision.accepted => 'Accepted',
      ApplicantDecision.held => 'Held',
      ApplicantDecision.declined => 'Declined',
      _ => 'Pending',
    };
