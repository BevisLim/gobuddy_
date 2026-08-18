import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

import '../model/emergency_contact.dart';

final emergencyContactRepositoryProvider = Provider<EmergencyContactRepository>(
  (ref) => SharedPreferencesEmergencyContactRepository(),
);

abstract interface class EmergencyContactRepository {
  Future<List<EmergencyContact>> getContacts(String userId);

  Future<EmergencyContact> addContact({
    required String userId,
    required String name,
    required String phoneNumber,
    required String email,
  });

  Future<void> deleteContact({required String userId, required String contactId});
}

class EmergencyContactValidationException implements Exception {
  final String message;
  const EmergencyContactValidationException(this.message);

  @override
  String toString() => message;
}

class SharedPreferencesEmergencyContactRepository
    implements EmergencyContactRepository {
  static const _keyPrefix = 'safety_emergency_contacts_';
  static final _emailPattern = RegExp(
    r"^[a-zA-Z0-9.!#$%&'*+/=?^_`{|}~-]+@[a-zA-Z0-9-]+(\.[a-zA-Z]+)+$",
  );
  static final _phonePattern = RegExp(r'^\+?[0-9]{7,15}$');

  @override
  Future<List<EmergencyContact>> getContacts(String userId) async {
    if (userId.trim().isEmpty) {
      throw const EmergencyContactValidationException('A signed-in user is required.');
    }
    final preferences = await SharedPreferences.getInstance();
    final encoded = preferences.getString(_key(userId));
    if (encoded == null) return const [];

    final values = jsonDecode(encoded) as List<dynamic>;
    return values
        .map((value) => EmergencyContact.fromJson(value as Map<String, dynamic>))
        .toList(growable: false);
  }

  @override
  Future<EmergencyContact> addContact({
    required String userId,
    required String name,
    required String phoneNumber,
    required String email,
  }) async {
    final cleanUserId = userId.trim();
    final cleanName = name.trim();
    final cleanPhone = _normalisePhone(phoneNumber);
    final cleanEmail = email.trim().toLowerCase();

    if (cleanUserId.isEmpty || cleanName.isEmpty) {
      throw const EmergencyContactValidationException('Name is required.');
    }
    if (!_phonePattern.hasMatch(cleanPhone)) {
      throw const EmergencyContactValidationException(
        'Enter a valid phone number with 7 to 15 digits.',
      );
    }
    if (!_emailPattern.hasMatch(cleanEmail)) {
      throw const EmergencyContactValidationException('Enter a valid email address.');
    }

    final contacts = await getContacts(cleanUserId);
    final duplicate = contacts.any(
      (contact) =>
          _normalisePhone(contact.phoneNumber) == cleanPhone ||
          contact.email.toLowerCase() == cleanEmail,
    );
    if (duplicate) {
      throw const EmergencyContactValidationException(
        'A contact with this phone number or email already exists.',
      );
    }

    final contact = EmergencyContact(
      id: const Uuid().v4(),
      userId: cleanUserId,
      name: cleanName,
      phoneNumber: cleanPhone,
      email: cleanEmail,
      createdAt: DateTime.now().toUtc(),
    );
    await _save(cleanUserId, [...contacts, contact]);
    return contact;
  }

  @override
  Future<void> deleteContact({
    required String userId,
    required String contactId,
  }) async {
    final contacts = await getContacts(userId);
    await _save(
      userId,
      contacts.where((contact) => contact.id != contactId).toList(),
    );
  }

  static String _normalisePhone(String value) {
    final trimmed = value.trim();
    final prefix = trimmed.startsWith('+') ? '+' : '';
    return '$prefix${trimmed.replaceAll(RegExp(r'[^0-9]'), '')}';
  }

  static String _key(String userId) => '$_keyPrefix$userId';

  Future<void> _save(String userId, List<EmergencyContact> contacts) async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.setString(
      _key(userId),
      jsonEncode(contacts.map((contact) => contact.toJson()).toList()),
    );
  }
}
