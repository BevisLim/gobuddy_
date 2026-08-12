import 'package:path/path.dart' as path;
import 'package:sqflite/sqflite.dart';

import 'seed_data.dart';

class AppDatabase {
  AppDatabase._();
  static final AppDatabase instance = AppDatabase._();

  Database? _database;

  Future<Database> get database async => _database ??= await _open();

  Future<Database> _open() async {
    final databasePath =
        path.join(await getDatabasesPath(), 'gobuddy_expenses.db');
    return openDatabase(
      databasePath,
      version: 1,
      onConfigure: (db) => db.execute('PRAGMA foreign_keys = ON'),
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE travellers (
            user_id INTEGER PRIMARY KEY,
            name TEXT NOT NULL,
            email TEXT,
            profile_photo TEXT,
            initials TEXT NOT NULL
          )''');
        await db.execute('''
          CREATE TABLE trips (
            trip_id INTEGER PRIMARY KEY,
            trip_name TEXT NOT NULL,
            destination TEXT NOT NULL,
            start_date TEXT NOT NULL,
            end_date TEXT NOT NULL
          )''');
        await db.execute('''
          CREATE TABLE trip_budgets (
            budget_id INTEGER PRIMARY KEY AUTOINCREMENT,
            trip_id INTEGER NOT NULL UNIQUE,
            budget_name TEXT NOT NULL,
            budget_amount REAL NOT NULL CHECK (budget_amount > 0),
            base_currency TEXT NOT NULL,
            notes TEXT,
            created_at TEXT NOT NULL,
            updated_at TEXT NOT NULL,
            FOREIGN KEY (trip_id) REFERENCES trips(trip_id) ON DELETE CASCADE
          )''');
        await db.execute('''
          CREATE TABLE expense_categories (
            category_id INTEGER PRIMARY KEY,
            name TEXT NOT NULL UNIQUE,
            icon_name TEXT NOT NULL
          )''');
        await db.execute('''
          CREATE TABLE expenses (
            expense_id INTEGER PRIMARY KEY AUTOINCREMENT,
            trip_id INTEGER NOT NULL,
            paid_by_user_id INTEGER NOT NULL,
            category_id INTEGER NOT NULL,
            title TEXT NOT NULL,
            original_amount REAL NOT NULL CHECK (original_amount > 0),
            currency_code TEXT NOT NULL,
            exchange_rate REAL NOT NULL CHECK (exchange_rate > 0),
            base_amount REAL NOT NULL CHECK (base_amount > 0),
            expense_date TEXT NOT NULL,
            notes TEXT,
            split_method TEXT NOT NULL DEFAULT 'equal',
            created_at TEXT NOT NULL,
            updated_at TEXT NOT NULL,
            FOREIGN KEY (trip_id) REFERENCES trips(trip_id) ON DELETE CASCADE,
            FOREIGN KEY (paid_by_user_id) REFERENCES travellers(user_id) ON DELETE RESTRICT,
            FOREIGN KEY (category_id) REFERENCES expense_categories(category_id) ON DELETE RESTRICT
          )''');
        await db.execute('''
          CREATE TABLE expense_participants (
            expense_id INTEGER NOT NULL,
            user_id INTEGER NOT NULL,
            share_amount REAL NOT NULL CHECK (share_amount >= 0),
            share_percentage REAL,
            PRIMARY KEY (expense_id, user_id),
            FOREIGN KEY (expense_id) REFERENCES expenses(expense_id) ON DELETE CASCADE,
            FOREIGN KEY (user_id) REFERENCES travellers(user_id) ON DELETE RESTRICT
          )''');
        await db.execute('''
          CREATE TABLE expense_receipts (
            receipt_id INTEGER PRIMARY KEY AUTOINCREMENT,
            expense_id INTEGER NOT NULL UNIQUE,
            image_path TEXT NOT NULL,
            uploaded_at TEXT NOT NULL,
            FOREIGN KEY (expense_id) REFERENCES expenses(expense_id) ON DELETE CASCADE
          )''');
        await db.execute('''
          CREATE TABLE settlements (
            settlement_id INTEGER PRIMARY KEY AUTOINCREMENT,
            trip_id INTEGER NOT NULL,
            payer_id INTEGER NOT NULL,
            payee_id INTEGER NOT NULL,
            amount REAL NOT NULL CHECK (amount > 0),
            payment_method TEXT NOT NULL,
            settlement_date TEXT NOT NULL,
            status TEXT NOT NULL CHECK (status IN ('pending','completed','rejected')),
            notes TEXT,
            created_at TEXT NOT NULL,
            CHECK (payer_id != payee_id),
            FOREIGN KEY (trip_id) REFERENCES trips(trip_id) ON DELETE CASCADE,
            FOREIGN KEY (payer_id) REFERENCES travellers(user_id) ON DELETE RESTRICT,
            FOREIGN KEY (payee_id) REFERENCES travellers(user_id) ON DELETE RESTRICT
          )''');
        await db.execute('''
          CREATE TABLE settlement_receipts (
            receipt_id INTEGER PRIMARY KEY AUTOINCREMENT,
            settlement_id INTEGER NOT NULL UNIQUE,
            image_path TEXT NOT NULL,
            uploaded_at TEXT NOT NULL,
            FOREIGN KEY (settlement_id) REFERENCES settlements(settlement_id) ON DELETE CASCADE
          )''');
        await db.execute('CREATE INDEX idx_expenses_trip ON expenses(trip_id)');
        await db.execute(
            'CREATE INDEX idx_expenses_payer ON expenses(paid_by_user_id)');
        await db.execute(
            'CREATE INDEX idx_participants_user ON expense_participants(user_id)');
        await db.execute(
            'CREATE INDEX idx_settlements_trip_status ON settlements(trip_id, status)');
        await SeedData.insert(db);
      },
    );
  }

  Future<void> close() async {
    await _database?.close();
    _database = null;
  }
}
