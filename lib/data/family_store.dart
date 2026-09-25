import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/family_member.dart';

class FamilyStore extends ChangeNotifier {
  FamilyStore._();

  static final FamilyStore instance = FamilyStore._();

  static const String _storageKey = 'smriti_family_members';
  static const String _photoFolderName = 'family_photos';

  final SharedPreferencesAsync _preferences =
  SharedPreferencesAsync();

  List<FamilyMember> _members = [];

  bool _isInitialized = false;

  // Keeps track of an initialization that is already running.
  // Other parts of the app can wait for it instead of receiving
  // an empty member list.
  Future<void>? _initializationFuture;

  List<FamilyMember> get members {
    return List.unmodifiable(_members);
  }

  bool get isInitialized => _isInitialized;

  // ============================================================
  // INITIALIZE
  // ============================================================

  Future<void> initialize() {
    // Already initialized.
    if (_isInitialized) {
      return Future.value();
    }

    // Initialization is already running somewhere else.
    // Wait for that same initialization to finish.
    if (_initializationFuture != null) {
      return _initializationFuture!;
    }

    // Start one shared initialization operation.
    _initializationFuture = _initializeInternal();

    return _initializationFuture!;
  }

  Future<void> _initializeInternal() async {
    try {
      final savedData =
      await _preferences.getString(_storageKey);

      if (savedData == null || savedData.isEmpty) {
        // First launch: create default family members.
        _members = [
          const FamilyMember(
            id: 'family_001',
            name: 'Priya',
            relationship: 'Daughter',
            memoryNote: 'A loving member of the family.',
          ),
          const FamilyMember(
            id: 'family_002',
            name: 'Raj',
            relationship: 'Son',
            memoryNote: 'A loving member of the family.',
          ),
        ];

        await _saveToStorage();
      } else {
        final List<dynamic> decoded =
        jsonDecode(savedData) as List<dynamic>;

        _members = decoded
            .map(
              (item) => _memberFromJson(
            Map<String, dynamic>.from(
              item as Map,
            ),
          ),
        )
            .toList();
      }

      _isInitialized = true;

      notifyListeners();
    } catch (e) {
      debugPrint(
        'FamilyStore initialization error: $e',
      );

      // Keep the app usable even if stored data
      // cannot be loaded.
      _members = [
        const FamilyMember(
          id: 'family_001',
          name: 'Priya',
          relationship: 'Daughter',
          memoryNote: 'A loving member of the family.',
        ),
        const FamilyMember(
          id: 'family_002',
          name: 'Raj',
          relationship: 'Son',
          memoryNote: 'A loving member of the family.',
        ),
      ];

      _isInitialized = true;

      notifyListeners();
    } finally {
      // Keep the completed Future around. Since _isInitialized
      // is true after this point, future calls will return
      // immediately through the first check.
      _initializationFuture = null;
    }
  }

  // ============================================================
  // ADD
  // ============================================================

  Future<void> addMember(
      FamilyMember member,
      ) async {
    // Make sure storage has been loaded before modifying it.
    await initialize();

    final savedMember =
    await _prepareMemberPhoto(member);

    _members.add(savedMember);

    await _saveToStorage();

    notifyListeners();
  }

  // ============================================================
  // UPDATE
  // ============================================================

  Future<void> updateMember(
      FamilyMember updatedMember,
      ) async {
    await initialize();

    final index = _members.indexWhere(
          (member) => member.id == updatedMember.id,
    );

    if (index == -1) {
      return;
    }

    final oldMember = _members[index];

    final savedMember =
    await _prepareMemberPhoto(updatedMember);

    _members[index] = savedMember;

    // Delete the old photo if a new photo was selected.
    if (oldMember.photoUrl != null &&
        oldMember.photoUrl!.isNotEmpty &&
        oldMember.photoUrl != savedMember.photoUrl) {
      await _deleteStoredPhotoIfNeeded(
        oldMember.photoUrl!,
      );
    }

    await _saveToStorage();

    notifyListeners();
  }

  // ============================================================
  // REMOVE
  // ============================================================

  Future<void> removeMember(
      String id,
      ) async {
    await initialize();

    final index = _members.indexWhere(
          (member) => member.id == id,
    );

    if (index == -1) {
      return;
    }

    final member = _members[index];

    _members.removeAt(index);

    if (member.photoUrl != null &&
        member.photoUrl!.isNotEmpty) {
      await _deleteStoredPhotoIfNeeded(
        member.photoUrl!,
      );
    }

    await _saveToStorage();

    notifyListeners();
  }

  // ============================================================
  // SAVE METADATA
  // ============================================================

  Future<void> _saveToStorage() async {
    final data = _members
        .map(_memberToJson)
        .toList();

    await _preferences.setString(
      _storageKey,
      jsonEncode(data),
    );
  }

  // ============================================================
  // PERMANENT PHOTO STORAGE
  // ============================================================

  Future<FamilyMember> _prepareMemberPhoto(
      FamilyMember member,
      ) async {
    final photoPath = member.photoUrl;

    if (photoPath == null || photoPath.isEmpty) {
      return member;
    }

    final sourceFile = File(photoPath);

    if (!await sourceFile.exists()) {
      return member;
    }

    final documentsDirectory =
    await getApplicationDocumentsDirectory();

    final photoDirectory = Directory(
      '${documentsDirectory.path}/$_photoFolderName',
    );

    if (!await photoDirectory.exists()) {
      await photoDirectory.create(
        recursive: true,
      );
    }

    // Already stored permanently.
    if (photoPath.startsWith(
      photoDirectory.path,
    )) {
      return member;
    }

    final extension =
    _getFileExtension(photoPath);

    final fileName =
        '${member.id}_${DateTime.now().millisecondsSinceEpoch}$extension';

    final destinationPath =
        '${photoDirectory.path}/$fileName';

    final copiedFile =
    await sourceFile.copy(destinationPath);

    return FamilyMember(
      id: member.id,
      name: member.name,
      relationship: member.relationship,
      photoUrl: copiedFile.path,
      phoneNumber: member.phoneNumber,
      voiceMessage: member.voiceMessage,
      memoryNote: member.memoryNote,
    );
  }

  String _getFileExtension(String path) {
    final lastDot = path.lastIndexOf('.');

    if (lastDot == -1) {
      return '.jpg';
    }

    return path.substring(lastDot);
  }

  // ============================================================
  // DELETE STORED PHOTO
  // ============================================================

  Future<void> _deleteStoredPhotoIfNeeded(
      String photoPath,
      ) async {
    try {
      final documentsDirectory =
      await getApplicationDocumentsDirectory();

      final photoDirectory =
          '${documentsDirectory.path}/$_photoFolderName';

      // Never delete a photo that is outside
      // SMRITI's own storage.
      if (!photoPath.startsWith(photoDirectory)) {
        return;
      }

      final file = File(photoPath);

      if (await file.exists()) {
        await file.delete();
      }
    } catch (e) {
      debugPrint(
        'Could not delete old family photo: $e',
      );
    }
  }

  // ============================================================
  // JSON
  // ============================================================

  Map<String, dynamic> _memberToJson(
      FamilyMember member,
      ) {
    return {
      'id': member.id,
      'name': member.name,
      'relationship': member.relationship,
      'photoUrl': member.photoUrl,
      'phoneNumber': member.phoneNumber,
      'voiceMessage': member.voiceMessage,
      'memoryNote': member.memoryNote,
    };
  }

  FamilyMember _memberFromJson(
      Map<String, dynamic> json,
      ) {
    return FamilyMember(
      id: json['id'] as String,
      name: json['name'] as String,
      relationship: json['relationship'] as String,
      photoUrl: json['photoUrl'] as String?,
      phoneNumber: json['phoneNumber'] as String?,
      voiceMessage: json['voiceMessage'] as String?,
      memoryNote: json['memoryNote'] as String?,
    );
  }
}