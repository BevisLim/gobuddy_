import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_mvvm_riverpod/features/collaboration/ui/state/collaboration_preview_state.dart';
import 'package:flutter_mvvm_riverpod/features/collaboration/ui/view_model/collaboration_preview_view_model.dart';

void main() {
  ProviderContainer createContainer() {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    return container;
  }

  test('mutes and removes a group member', () {
    final container = createContainer();
    final notifier = container.read(
      collaborationPreviewViewModelProvider.notifier,
    );

    notifier.muteMember('aina', '1 Hour');
    expect(
      container
          .read(collaborationPreviewViewModelProvider)
          .members
          .single
          .isMuted,
      isTrue,
    );

    notifier.removeMember('aina');
    expect(
      container.read(collaborationPreviewViewModelProvider).members,
      isEmpty,
    );
  });

  test('pins and edits a timeline activity', () {
    final container = createContainer();
    final notifier = container.read(
      collaborationPreviewViewModelProvider.notifier,
    );
    const edited = PreviewActivity(
      title: 'Edited activity',
      location: 'Kuala Lumpur',
    );

    notifier.toggleActivityPin('day-1-lunch');
    notifier.saveActivityForKey('day-1-lunch', edited);

    final state = container.read(collaborationPreviewViewModelProvider);
    expect(state.pinnedActivityKeys, contains('day-1-lunch'));
    expect(state.activityOverrides['day-1-lunch']?.title, 'Edited activity');
  });

  test('submits one vote for a single-choice poll', () {
    final container = createContainer();
    final notifier = container.read(
      collaborationPreviewViewModelProvider.notifier,
    );

    notifier.selectVote('Explore Asakusa');

    expect(
      container
          .read(collaborationPreviewViewModelProvider)
          .poll
          .selectedOptions,
      equals(['Explore Asakusa']),
    );
  });

  test('adds a shared file to the collaboration workspace', () {
    final container = createContainer();
    final notifier = container.read(
      collaborationPreviewViewModelProvider.notifier,
    );

    notifier.addSharedFile(
      const PreviewSharedFile(
        name: 'booking.pdf',
        title: 'Hotel booking',
        category: 'Hotel Voucher',
        sizeBytes: 1200,
      ),
    );

    final file = container
        .read(collaborationPreviewViewModelProvider)
        .sharedFiles
        .single;
    expect(file.name, 'booking.pdf');
    expect(file.title, 'Hotel booking');
  });
}
