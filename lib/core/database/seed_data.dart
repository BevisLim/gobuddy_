import 'package:sqflite/sqflite.dart';

abstract final class SeedData {
  static Future<void> insert(Database db) async {
    final batch = db.batch();
    const travellers = [
      [1, 'Ahmad Faiz', 'ahmad@example.com', 'AF'],
      [2, 'Sarah Lim', 'sarah@example.com', 'SL'],
      [3, 'Ravi Kumar', 'ravi@example.com', 'RK'],
      [4, 'Nurul Ain', 'nurul@example.com', 'NA'],
    ];
    for (final traveller in travellers) {
      batch.insert('travellers', {
        'user_id': traveller[0],
        'name': traveller[1],
        'email': traveller[2],
        'initials': traveller[3],
      });
    }
    batch.insert('trips', {
      'trip_id': 1,
      'trip_name': 'Kuala Lumpur MY',
      'destination': 'Kuala Lumpur, Malaysia',
      'start_date': '2025-07-19T00:00:00.000',
      'end_date': '2025-07-24T00:00:00.000',
    });
    batch.insert('trip_budgets', {
      'budget_id': 1,
      'trip_id': 1,
      'budget_name': 'KL Trip 2025',
      'budget_amount': 3000.0,
      'base_currency': 'MYR',
      'notes': 'Group trip to KL, Malaysia.',
      'created_at': '2025-07-01T09:00:00.000',
      'updated_at': '2025-07-01T09:00:00.000',
    });
    const categories = [
      [1, 'Hotel', 'hotel'],
      [2, 'Flight', 'flight'],
      [3, 'Food', 'food'],
      [4, 'Restaurant', 'restaurant'],
      [5, 'Transportation', 'directions_car'],
      [6, 'Fuel', 'local_gas_station'],
      [7, 'Parking', 'local_parking'],
      [8, 'Shopping', 'shopping_bag'],
      [9, 'Entertainment', 'movie'],
      [10, 'Attraction', 'museum'],
      [11, 'Others', 'more_horiz'],
    ];
    for (final category in categories) {
      batch.insert('expense_categories', {
        'category_id': category[0],
        'name': category[1],
        'icon_name': category[2],
      });
    }

    // The RM34 breakfast expense completes the requested RM2,055 demo total.
    const expenses = [
      [1, 8, 'Shopping (KLCC)', 250.0, 2, '2025-07-19'],
      [2, 10, 'Museum Entry', 45.0, 2, '2025-07-20'],
      [3, 1, 'Hotel Stay', 580.0, 1, '2025-07-20'],
      [4, 2, 'Flight', 760.0, 1, '2025-07-19'],
      [5, 9, 'Entertainment', 180.0, 3, '2025-07-22'],
      [6, 6, 'Fuel', 120.0, 4, '2025-07-23'],
      [7, 4, 'Restaurant', 86.0, 1, '2025-07-23'],
      [8, 3, 'Breakfast', 34.0, 4, '2025-07-24'],
    ];
    for (final item in expenses) {
      final id = item[0] as int;
      final amount = item[3] as double;
      batch.insert('expenses', {
        'expense_id': id,
        'trip_id': 1,
        'category_id': item[1],
        'title': item[2],
        'original_amount': amount,
        'currency_code': 'MYR',
        'exchange_rate': 1.0,
        'base_amount': amount,
        'paid_by_user_id': item[4],
        'expense_date': '${item[5]}T12:00:00.000',
        'split_method': 'equal',
        'created_at': '${item[5]}T12:00:00.000',
        'updated_at': '${item[5]}T12:00:00.000',
      });
      final cents = (amount * 100).round();
      final baseShare = cents ~/ 4;
      var allocated = 0;
      for (var userId = 1; userId <= 4; userId++) {
        final shareCents = userId == 4 ? cents - allocated : baseShare;
        allocated += shareCents;
        batch.insert('expense_participants', {
          'expense_id': id,
          'user_id': userId,
          'share_amount': shareCents / 100,
          'share_percentage': 25.0,
        });
      }
    }
    // Completed external payments reconcile the seeded final balances to:
    // Ahmad +286.50, Sarah -143.25, Ravi -143.25, and Nurul 0.00.
    const settlements = [
      [1, 2, 1, 75.50, 'Bank Transfer'],
      [2, 3, 1, 190.50, 'DuitNow'],
      [3, 4, 1, 359.75, "Touch 'n Go"],
    ];
    for (final settlement in settlements) {
      batch.insert('settlements', {
        'settlement_id': settlement[0],
        'trip_id': 1,
        'payer_id': settlement[1],
        'payee_id': settlement[2],
        'amount': settlement[3],
        'payment_method': settlement[4],
        'settlement_date': '2025-07-24T18:00:00.000',
        'status': 'completed',
        'notes': 'Development seed settlement completed externally.',
        'created_at': '2025-07-24T18:00:00.000',
      });
    }
    await batch.commit(noResult: true);
  }
}
