import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../repository/identity_review_repository.dart';

class IdentityReviewsScreen extends StatefulWidget {
  const IdentityReviewsScreen({super.key});

  @override
  State<IdentityReviewsScreen> createState() => _IdentityReviewsScreenState();
}

class _IdentityReviewsScreenState extends State<IdentityReviewsScreen> {
  final _repository = const AdminIdentityReviewRepository();
  late Future<bool> _access;
  late Future<List<AdminIdentityReview>> _queue;

  @override
  void initState() {
    super.initState();
    _access = _repository.isAdmin();
    _queue = _access.then(
      (allowed) => allowed ? _repository.fetchQueue() : const [],
    );
  }

  void _reload() => _queue = _repository.fetchQueue();

  Future<void> _refresh() async {
    setState(_reload);
    await _queue;
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Identity reviews')),
    body: FutureBuilder<bool>(
      future: _access,
      builder: (context, accessSnapshot) {
        if (accessSnapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (accessSnapshot.data != true) {
          return const _MessageView(
            icon: Icons.lock_outline_rounded,
            message: 'Admin access is required to review identities.',
          );
        }
        return _buildQueue();
      },
    ),
  );

  Widget _buildQueue() => FutureBuilder<List<AdminIdentityReview>>(
    future: _queue,
    builder: (context, snapshot) {
      if (snapshot.connectionState == ConnectionState.waiting) {
        return const Center(child: CircularProgressIndicator());
      }
      if (snapshot.hasError) {
        return _MessageView(
          icon: Icons.error_outline,
          message: snapshot.error.toString(),
          action: FilledButton(
            onPressed: _refresh,
            child: const Text('Try again'),
          ),
        );
      }
      final reviews = snapshot.data ?? const [];
      if (reviews.isEmpty) {
        return RefreshIndicator(
          onRefresh: _refresh,
          child: const _MessageView(
            icon: Icons.verified_user_outlined,
            message: 'No identity verifications need review.',
            scrollable: true,
          ),
        );
      }
      return RefreshIndicator(
        onRefresh: _refresh,
        child: ListView.separated(
          padding: const EdgeInsets.all(16),
          itemCount: reviews.length,
          separatorBuilder: (_, _) => const SizedBox(height: 12),
          itemBuilder: (context, index) {
            final review = reviews[index];
            return Card(
              child: ListTile(
                leading: const CircleAvatar(
                  child: Icon(Icons.manage_search_rounded),
                ),
                title: Text(review.displayName),
                subtitle: Text(
                  review.submittedAt == null
                      ? 'In Review'
                      : 'Submitted ${DateFormat.yMMMd().add_jm().format(review.submittedAt!.toLocal())}',
                ),
                trailing: const Icon(Icons.chevron_right_rounded),
                onTap: () async {
                  await Navigator.of(context).push<void>(
                    MaterialPageRoute(
                      builder: (_) => _IdentityReviewDetailsScreen(
                        verificationId: review.id,
                        repository: _repository,
                      ),
                    ),
                  );
                  await _refresh();
                },
              ),
            );
          },
        ),
      );
    },
  );
}

class _IdentityReviewDetailsScreen extends StatefulWidget {
  const _IdentityReviewDetailsScreen({
    required this.verificationId,
    required this.repository,
  });

  final String verificationId;
  final AdminIdentityReviewRepository repository;

  @override
  State<_IdentityReviewDetailsScreen> createState() =>
      _IdentityReviewDetailsScreenState();
}

class _IdentityReviewDetailsScreenState
    extends State<_IdentityReviewDetailsScreen> {
  late Future<AdminIdentityReviewDetails> _details;
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    _details = widget.repository.fetchDetails(widget.verificationId);
  }

  Future<void> _decide(String decision) async {
    final controller = TextEditingController();
    final reason = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(switch (decision) {
          'Declined' => 'Reject verification',
          'Resubmitted' => 'Request resubmission',
          _ => 'Approve verification',
        }),
        content: TextField(
          controller: controller,
          autofocus: true,
          maxLength: 1000,
          maxLines: 4,
          decoration: InputDecoration(
            labelText: switch (decision) {
              'Declined' => 'Rejection reason',
              'Resubmitted' => 'Resubmission instructions',
              _ => 'Review note',
            },
            hintText: switch (decision) {
              'Declined' =>
                'Explain what failed and what the user should correct.',
              'Resubmitted' =>
                'Explain what the user must capture or provide again.',
              _ => 'Record why this verification is approved.',
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              final value = controller.text.trim();
              if (value.isNotEmpty) Navigator.pop(context, value);
            },
            child: Text(switch (decision) {
              'Declined' => 'Reject',
              'Resubmitted' => 'Request resubmission',
              _ => 'Approve',
            }),
          ),
        ],
      ),
    );
    controller.dispose();
    if (reason == null || !mounted) return;
    setState(() => _submitting = true);
    try {
      await widget.repository.submitDecision(
        verificationId: widget.verificationId,
        decision: decision,
        reason: reason,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(switch (decision) {
            'Declined' => 'Verification rejected in Didit.',
            'Resubmitted' => 'Resubmission requested in Didit.',
            _ => 'Verification approved in Didit.',
          }),
        ),
      );
      Navigator.pop(context);
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.toString())));
      setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Review identity')),
    body: FutureBuilder<AdminIdentityReviewDetails>(
      future: _details,
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          if (snapshot.hasError) {
            return _MessageView(
              icon: Icons.error_outline,
              message: snapshot.error.toString(),
            );
          }
          return const Center(child: CircularProgressIndicator());
        }
        final details = snapshot.data!;
        final facts = _decisionFacts(details.decision);
        final images = _decisionImages(details.decision);
        return ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
          children: [
            Text(
              details.review.displayName,
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 4),
            const Text('Didit status: In Review'),
            const SizedBox(height: 20),
            ...facts.map(
              (fact) => Card(
                child: ListTile(title: Text(fact.$1), subtitle: Text(fact.$2)),
              ),
            ),
            if (images.isNotEmpty) ...[
              const SizedBox(height: 12),
              Text('Evidence', style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 8),
              ...images.map(
                (url) => Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Image.network(
                      url,
                      fit: BoxFit.contain,
                      errorBuilder: (_, _, _) => const ListTile(
                        leading: Icon(Icons.broken_image_outlined),
                        title: Text('Evidence image unavailable'),
                      ),
                    ),
                  ),
                ),
              ),
            ],
            const SizedBox(height: 20),
            OutlinedButton.icon(
              onPressed: _submitting ? null : () => _decide('Resubmitted'),
              icon: const Icon(Icons.replay_rounded),
              label: const Text('Request resubmission'),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _submitting ? null : () => _decide('Declined'),
                    icon: const Icon(Icons.close_rounded),
                    label: const Text('Reject'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton.icon(
                    onPressed: _submitting ? null : () => _decide('Approved'),
                    icon: _submitting
                        ? const SizedBox.square(
                            dimension: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.check_rounded),
                    label: const Text('Approve'),
                  ),
                ),
              ],
            ),
          ],
        );
      },
    ),
  );
}

List<(String, String)> _decisionFacts(Map<String, dynamic> decision) {
  final facts = <(String, String)>[];
  void visit(Object? value, String path) {
    if (value is Map) {
      for (final entry in value.entries) {
        final key = entry.key.toString();
        final next = path.isEmpty ? key : '$path · $key';
        if (entry.value is String ||
            entry.value is num ||
            entry.value is bool) {
          if (!key.toLowerCase().contains('image') &&
              !key.toLowerCase().contains('video') &&
              !key.toLowerCase().contains('token')) {
            facts.add((_label(next), entry.value.toString()));
          }
        } else {
          visit(entry.value, next);
        }
      }
    } else if (value is List) {
      for (var i = 0; i < value.length; i++) {
        visit(value[i], path);
      }
    }
  }

  visit(decision, '');
  return facts.take(80).toList(growable: false);
}

List<String> _decisionImages(Map<String, dynamic> decision) {
  final images = <String>{};
  void visit(Object? value, String key) {
    if (value is Map) {
      for (final entry in value.entries) {
        visit(entry.value, entry.key.toString());
      }
    } else if (value is List) {
      for (final item in value) {
        visit(item, key);
      }
    } else if (value is String &&
        key.toLowerCase().contains('image') &&
        Uri.tryParse(value)?.isScheme('https') == true) {
      images.add(value);
    }
  }

  visit(decision, '');
  return images.take(12).toList(growable: false);
}

String _label(String value) => value
    .replaceAll('_', ' ')
    .split(' · ')
    .map(
      (part) =>
          part.isEmpty ? part : '${part[0].toUpperCase()}${part.substring(1)}',
    )
    .join(' · ');

class _MessageView extends StatelessWidget {
  const _MessageView({
    required this.icon,
    required this.message,
    this.action,
    this.scrollable = false,
  });

  final IconData icon;
  final String message;
  final Widget? action;
  final bool scrollable;

  @override
  Widget build(BuildContext context) {
    final child = Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 48),
            const SizedBox(height: 12),
            Text(message, textAlign: TextAlign.center),
            if (action != null) ...[const SizedBox(height: 16), action!],
          ],
        ),
      ),
    );
    if (!scrollable) return child;
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      children: [
        SizedBox(height: MediaQuery.sizeOf(context).height * .7, child: child),
      ],
    );
  }
}
