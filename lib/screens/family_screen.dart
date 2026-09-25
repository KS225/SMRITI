import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';

import '../data/family_store.dart';
import '../data/memory_store.dart';
import '../models/family_member.dart';
import '../models/memory.dart';
import '../theme/smriti_theme.dart';
import 'memories_screen.dart';

// ============================================================
// USER ROLE
// ============================================================

enum FamilyUserRole {
  patient,
  caregiver,
  supervisor,
}

// ============================================================
// FAMILY SCREEN
// ============================================================

class FamilyScreen extends StatefulWidget {
  final FamilyUserRole userRole;

  const FamilyScreen({
    super.key,
    this.userRole = FamilyUserRole.patient,
  });

  @override
  State<FamilyScreen> createState() => _FamilyScreenState();
}

class _FamilyScreenState extends State<FamilyScreen> {
  final FamilyStore store = FamilyStore.instance;
  final MemoryStore memoryStore = MemoryStore.instance;

  bool get canManageMembers {
    return widget.userRole == FamilyUserRole.caregiver ||
        widget.userRole == FamilyUserRole.supervisor;
  }

  @override
  void initState() {
    super.initState();

    store.addListener(_refresh);
    memoryStore.addListener(_refresh);

    _initializeStores();
  }

  Future<void> _initializeStores() async {
    await Future.wait([
      store.initialize(),
      memoryStore.initialize(),
    ]);

    if (mounted) {
      setState(() {});
    }
  }

  @override
  void dispose() {
    store.removeListener(_refresh);
    memoryStore.removeListener(_refresh);

    super.dispose();
  }

  void _refresh() {
    if (mounted) {
      setState(() {});
    }
  }

  // ============================================================
  // ADD MEMBER
  // ============================================================

  Future<void> _openAddMember() async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const AddFamilyMemberScreen(),
      ),
    );
  }

  // ============================================================
  // EDIT MEMBER
  // ============================================================

  Future<void> _openEditMember(
      FamilyMember member,
      ) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => AddFamilyMemberScreen(
          member: member,
        ),
      ),
    );
  }

  // ============================================================
  // BUILD
  // ============================================================

  @override
  Widget build(BuildContext context) {
    if (!store.isInitialized) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    final members = store.members;

    return Scaffold(
      appBar: AppBar(
        title: const Text('My Family'),
        actions: [
          IconButton(
            tooltip: 'Add family member',
            icon: const Icon(
              Icons.person_add_rounded,
            ),
            onPressed: _openAddMember,
          ),
        ],
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(
            20,
            10,
            20,
            30,
          ),
          children: [
            const Text(
              'People who are important to you ❤️',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 18,
                color: SmritiTheme.textSecondary,
              ),
            ),

            const SizedBox(height: 20),

            SizedBox(
              width: double.infinity,
              height: 52,
              child: FilledButton.icon(
                onPressed: _openAddMember,
                icon: const Icon(
                  Icons.person_add_rounded,
                ),
                label: const Text(
                  'Add Family Member',
                  style: TextStyle(
                    fontSize: 17,
                  ),
                ),
              ),
            ),

            const SizedBox(height: 26),

            if (members.isEmpty)
              const Padding(
                padding: EdgeInsets.all(30),
                child: Text(
                  'No family members added yet.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 17,
                    color: SmritiTheme.textSecondary,
                  ),
                ),
              ),

            ...members.map(
                  (member) => Padding(
                padding: const EdgeInsets.only(
                  bottom: 16,
                ),
                child: FamilyMemberCard(
                  member: member,
                  canRemove: canManageMembers,
                  onEdit: () => _openEditMember(member),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ============================================================
// FAMILY MEMBER CARD
// ============================================================

class FamilyMemberCard extends StatelessWidget {
  final FamilyMember member;
  final VoidCallback onEdit;
  final bool canRemove;

  final MemoryStore memoryStore =
      MemoryStore.instance;

  FamilyMemberCard({
    super.key,
    required this.member,
    required this.onEdit,
    required this.canRemove,
  });

  @override
  Widget build(BuildContext context) {
    final List<Memory> memories =
    memoryStore.memoriesForPerson(
      member.name,
    );

    ImageProvider? image;

    if (member.photoUrl != null &&
        member.photoUrl!.isNotEmpty &&
        File(member.photoUrl!).existsSync()) {
      image = FileImage(
        File(member.photoUrl!),
      );
    }

    final bool hasPhone =
        member.phoneNumber != null &&
            member.phoneNumber!.isNotEmpty;

    return Material(
      color: SmritiTheme.surface,
      borderRadius: BorderRadius.circular(24),
      child: InkWell(
        borderRadius: BorderRadius.circular(24),
        onTap: () {
          _showMemberDetails(
            context,
            memories,
          );
        },
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: SmritiTheme.border,
            ),
          ),
          child: Stack(
            children: [
              Column(
                children: [
                  CircleAvatar(
                    radius: 48,
                    backgroundColor:
                    SmritiTheme.softGreen,
                    backgroundImage: image,
                    child: image == null
                        ? Text(
                      member.name
                          .substring(0, 1)
                          .toUpperCase(),
                      style: const TextStyle(
                        fontSize: 34,
                        fontWeight:
                        FontWeight.bold,
                        color:
                        SmritiTheme.primary,
                      ),
                    )
                        : null,
                  ),

                  const SizedBox(height: 14),

                  Text(
                    member.name,
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: SmritiTheme.textPrimary,
                    ),
                  ),

                  const SizedBox(height: 4),

                  Text(
                    member.relationship,
                    style: const TextStyle(
                      fontSize: 17,
                      color: SmritiTheme.textSecondary,
                    ),
                  ),

                  // ==================================================
                  // MEMORY COUNT
                  // ==================================================

                  if (memories.isNotEmpty) ...[
                    const SizedBox(height: 10),

                    Container(
                      padding:
                      const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: SmritiTheme.softGreen,
                        borderRadius:
                        BorderRadius.circular(20),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.photo_album_rounded,
                            size: 17,
                            color: SmritiTheme.primary,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            '${memories.length} '
                                '${memories.length == 1 ? 'memory' : 'memories'}',
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight:
                              FontWeight.w600,
                              color:
                              SmritiTheme.primaryDark,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],

                  if (hasPhone) ...[
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment:
                      MainAxisAlignment.center,
                      children: [
                        const Icon(
                          Icons.phone_rounded,
                          size: 17,
                          color:
                          SmritiTheme.textSecondary,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          '+91 ${member.phoneNumber}',
                          style: const TextStyle(
                            fontSize: 16,
                            color:
                            SmritiTheme.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ],

                  const SizedBox(height: 18),

                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: hasPhone
                          ? () {
                        ScaffoldMessenger.of(
                          context,
                        ).showSnackBar(
                          const SnackBar(
                            content: Text(
                              'Calling will be added later.',
                            ),
                          ),
                        );
                      }
                          : null,
                      icon: const Icon(
                        Icons.phone_rounded,
                      ),
                      label: const Text('Call'),
                    ),
                  ),
                ],
              ),

              Positioned(
                top: -6,
                right: -6,
                child: IconButton(
                  tooltip: 'Edit family member',
                  onPressed: onEdit,
                  icon: const Icon(
                    Icons.edit_rounded,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ============================================================
  // MEMBER DETAILS
  // ============================================================

  void _showMemberDetails(
      BuildContext context,
      List<Memory> memories,
      ) {
    ImageProvider? image;

    if (member.photoUrl != null &&
        member.photoUrl!.isNotEmpty &&
        File(member.photoUrl!).existsSync()) {
      image = FileImage(
        File(member.photoUrl!),
      );
    }

    final bool hasPhone =
        member.phoneNumber != null &&
            member.phoneNumber!.isNotEmpty;

    showModalBottomSheet(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (sheetContext) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
              24,
              10,
              24,
              30,
            ),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircleAvatar(
                    radius: 45,
                    backgroundColor:
                    SmritiTheme.softGreen,
                    backgroundImage: image,
                    child: image == null
                        ? Text(
                      member.name
                          .substring(0, 1)
                          .toUpperCase(),
                      style: const TextStyle(
                        fontSize: 32,
                        fontWeight:
                        FontWeight.bold,
                        color:
                        SmritiTheme.primary,
                      ),
                    )
                        : null,
                  ),

                  const SizedBox(height: 14),

                  Text(
                    member.name,
                    style: const TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                    ),
                  ),

                  const SizedBox(height: 6),

                  Text(
                    member.relationship,
                    style: const TextStyle(
                      fontSize: 18,
                      color: SmritiTheme.textSecondary,
                    ),
                  ),

                  if (hasPhone) ...[
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment:
                      MainAxisAlignment.center,
                      children: [
                        const Icon(
                          Icons.phone_rounded,
                          size: 19,
                          color: SmritiTheme.primary,
                        ),
                        const SizedBox(width: 7),
                        Text(
                          '+91 ${member.phoneNumber}',
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ],

                  // ==================================================
                  // MEMORIES WITH THIS PERSON
                  // ==================================================

                  if (memories.isNotEmpty) ...[
                    const SizedBox(height: 24),

                    Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        'Memories with ${member.name}',
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: SmritiTheme.primaryDark,
                        ),
                      ),
                    ),

                    const SizedBox(height: 12),

                    ...memories.map(
                          (memory) => InkWell(
                        onTap: () {
                          Navigator.pop(sheetContext);

                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const MemoriesScreen(),
                            ),
                          );
                        },
                        child: _buildMemoryPreview(memory),
                      ),
                    ),
                  ],

                  // ==================================================
                  // MEMORY NOTE
                  // ==================================================

                  if (member.memoryNote != null &&
                      member.memoryNote!.isNotEmpty) ...[
                    const SizedBox(height: 20),

                    Text(
                      member.memoryNote!,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 17,
                      ),
                    ),
                  ],

                  const SizedBox(height: 24),

                  // ==================================================
                  // REMOVE MEMBER
                  // ==================================================

                  if (canRemove) ...[
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: () {
                          Navigator.pop(
                            sheetContext,
                          );

                          _confirmRemove(
                            context,
                            member,
                          );
                        },
                        icon: const Icon(
                          Icons.delete_outline_rounded,
                        ),
                        label: const Text(
                          'Remove Family Member',
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                  ],

                  // ==================================================
                  // CLOSE
                  // ==================================================

                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: () {
                        Navigator.pop(
                          sheetContext,
                        );
                      },
                      icon: const Icon(
                        Icons.favorite_rounded,
                      ),
                      label: const Text('Close'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  // ============================================================
  // MEMORY PREVIEW
  // ============================================================

  Widget _buildMemoryPreview(Memory memory) {
    ImageProvider? memoryImage;

    if (memory.imageUrl != null &&
        memory.imageUrl!.isNotEmpty &&
        File(memory.imageUrl!).existsSync()) {
      memoryImage = FileImage(
        File(memory.imageUrl!),
      );
    }

    return Container(
      margin: const EdgeInsets.only(
        bottom: 10,
      ),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: SmritiTheme.softGreen,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: SmritiTheme.border,
        ),
      ),
      child: Row(
        children: [
          if (memoryImage != null)
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Image(
                image: memoryImage,
                width: 60,
                height: 60,
                fit: BoxFit.cover,
              ),
            )
          else
            Container(
              width: 60,
              height: 60,
              decoration: BoxDecoration(
                color: SmritiTheme.surface,
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(
                Icons.photo_album_rounded,
                color: SmritiTheme.primary,
              ),
            ),

          const SizedBox(width: 12),

          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  memory.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: SmritiTheme.textPrimary,
                  ),
                ),

                if (memory.date.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    memory.date,
                    style: const TextStyle(
                      fontSize: 14,
                      color: SmritiTheme.textSecondary,
                    ),
                  ),
                ],

                if (memory.location.isNotEmpty) ...[
                  const SizedBox(height: 3),
                  Text(
                    memory.location,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 13,
                      color: SmritiTheme.textSecondary,
                    ),
                  ),
                ],
              ],
            ),
          ),

          const SizedBox(width: 6),

          const Icon(
            Icons.arrow_forward_ios_rounded,
            size: 16,
            color: SmritiTheme.textSecondary,
          ),
        ],
      ),
    );
  }

  // ============================================================
  // REMOVE CONFIRMATION
  // ============================================================

  void _confirmRemove(
      BuildContext context,
      FamilyMember member,
      ) {
    showDialog(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text(
            'Remove family member?',
          ),
          content: Text(
            'Are you sure you want to remove '
                '${member.name} from the family list?',
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(
                  dialogContext,
                );
              },
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () async {
                await FamilyStore.instance
                    .removeMember(member.id);

                if (!dialogContext.mounted) {
                  return;
                }

                Navigator.pop(
                  dialogContext,
                );

                ScaffoldMessenger.of(
                  context,
                ).showSnackBar(
                  SnackBar(
                    content: Text(
                      '${member.name} was removed.',
                    ),
                  ),
                );
              },
              child: const Text('Remove'),
            ),
          ],
        );
      },
    );
  }
}

// ============================================================
// ADD / EDIT FAMILY MEMBER SCREEN
// ============================================================

class AddFamilyMemberScreen
    extends StatefulWidget {
  final FamilyMember? member;

  const AddFamilyMemberScreen({
    super.key,
    this.member,
  });

  @override
  State<AddFamilyMemberScreen> createState() =>
      _AddFamilyMemberScreenState();
}

class _AddFamilyMemberScreenState
    extends State<AddFamilyMemberScreen> {
  final ImagePicker _picker =
  ImagePicker();

  final TextEditingController
  _nameController =
  TextEditingController();

  final TextEditingController
  _phoneController =
  TextEditingController();

  final TextEditingController
  _memoryController =
  TextEditingController();

  final TextEditingController
  _customRelationshipController =
  TextEditingController();

  final GlobalKey<FormState>
  _formKey =
  GlobalKey<FormState>();

  String _relationship = 'Daughter';

  XFile? _selectedImage;

  bool _removeExistingPhoto = false;

  bool _isSaving = false;

  final List<String> _relationships = [
    'Mother',
    'Father',
    'Daughter',
    'Son',
    'Grandmother',
    'Grandfather',
    'Sister',
    'Brother',
    'Spouse',
    'Granddaughter',
    'Grandson',
    'Friend',
    'Caregiver',
    'Other',
  ];

  bool get _isEditing =>
      widget.member != null;

  @override
  void initState() {
    super.initState();

    final member = widget.member;

    if (member != null) {
      _nameController.text =
          member.name;

      _phoneController.text =
          member.phoneNumber ?? '';

      _memoryController.text =
          member.memoryNote ?? '';

      if (_relationships.contains(
        member.relationship,
      )) {
        _relationship =
            member.relationship;
      } else {
        _relationship = 'Other';

        _customRelationshipController
            .text =
            member.relationship;
      }

      if (member.photoUrl != null &&
          member.photoUrl!.isNotEmpty &&
          File(member.photoUrl!)
              .existsSync()) {
        _selectedImage = XFile(
          member.photoUrl!,
        );
      }
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _memoryController.dispose();
    _customRelationshipController
        .dispose();

    super.dispose();
  }

  // ============================================================
  // PICK IMAGE
  // ============================================================

  Future<void> _pickImage() async {
    try {
      final XFile? image =
      await _picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 85,
      );

      if (image == null) {
        return;
      }

      setState(() {
        _selectedImage = image;
        _removeExistingPhoto = false;
      });
    } catch (e) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context)
          .showSnackBar(
        const SnackBar(
          content: Text(
            'Unable to select the photo.',
          ),
        ),
      );
    }
  }

  // ============================================================
  // PHONE VALIDATION
  // ============================================================

  String? _validatePhone(
      String? value,
      ) {
    final phone =
        value?.trim() ?? '';

    // Phone is optional.
    if (phone.isEmpty) {
      return null;
    }

    if (!RegExp(
      r'^[6-9]\d{9}$',
    ).hasMatch(phone)) {
      return 'Enter a valid 10-digit mobile number';
    }

    return null;
  }

  // ============================================================
  // CUSTOM RELATIONSHIP VALIDATION
  // ============================================================

  String? _validateCustomRelationship(
      String? value,
      ) {
    if (_relationship != 'Other') {
      return null;
    }

    final relationship =
        value?.trim() ?? '';

    if (relationship.isEmpty) {
      return 'Please enter the relationship';
    }

    return null;
  }

  // ============================================================
  // SAVE / UPDATE
  // ============================================================

  Future<void> _saveMember() async {
    if (_isSaving) {
      return;
    }

    if (!_formKey.currentState!
        .validate()) {
      return;
    }

    final name =
    _nameController.text.trim();

    if (name.isEmpty) {
      ScaffoldMessenger.of(context)
          .showSnackBar(
        const SnackBar(
          content: Text(
            'Please enter the family member\'s name.',
          ),
        ),
      );

      return;
    }

    final phone =
    _phoneController.text.trim();

    String relationship =
        _relationship;

    if (_relationship == 'Other') {
      relationship =
          _customRelationshipController
              .text
              .trim();
    }

    final member = FamilyMember(
      // Keep the same ID while editing.
      id: widget.member?.id ??
          'family_${DateTime.now().millisecondsSinceEpoch}',

      name: name,

      relationship: relationship,

      photoUrl: _removeExistingPhoto
          ? null
          : _selectedImage?.path,

      phoneNumber:
      phone.isEmpty ? null : phone,

      memoryNote:
      _memoryController.text
          .trim()
          .isEmpty
          ? null
          : _memoryController.text
          .trim(),

      // Preserve these fields for
      // future features.
      voiceMessage:
      widget.member?.voiceMessage,
    );

    setState(() {
      _isSaving = true;
    });

    try {
      if (_isEditing) {
        await FamilyStore.instance
            .updateMember(member);
      } else {
        await FamilyStore.instance
            .addMember(member);
      }

      if (!mounted) {
        return;
      }

      Navigator.pop(context);
    } catch (e) {
      if (!mounted) {
        return;
      }

      setState(() {
        _isSaving = false;
      });

      ScaffoldMessenger.of(context)
          .showSnackBar(
        const SnackBar(
          content: Text(
            'Unable to save the family member.',
          ),
        ),
      );
    }
  }

  // ============================================================
  // BUILD
  // ============================================================

  @override
  Widget build(BuildContext context) {
    final bool isOther =
        _relationship == 'Other';

    return Scaffold(
      appBar: AppBar(
        title: Text(
          _isEditing
              ? 'Edit Family Member'
              : 'Add Family Member',
        ),
      ),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: ListView(
            padding:
            const EdgeInsets.fromLTRB(
              20,
              20,
              20,
              30,
            ),
            children: [
              // =================================================
              // PHOTO
              // =================================================

              Center(
                child: GestureDetector(
                  onTap: _isSaving
                      ? null
                      : _pickImage,
                  child: CircleAvatar(
                    radius: 65,
                    backgroundColor:
                    SmritiTheme.softGreen,
                    backgroundImage:
                    _selectedImage !=
                        null
                        ? FileImage(
                      File(
                        _selectedImage!
                            .path,
                      ),
                    )
                        : null,
                    child:
                    _selectedImage ==
                        null
                        ? const Icon(
                      Icons
                          .add_a_photo_rounded,
                      size: 40,
                      color:
                      SmritiTheme
                          .primary,
                    )
                        : null,
                  ),
                ),
              ),

              const SizedBox(height: 10),

              Text(
                _selectedImage == null
                    ? 'Add a photo'
                    : 'Tap photo to change',
                textAlign:
                TextAlign.center,
                style: const TextStyle(
                  fontSize: 16,
                  color:
                  SmritiTheme
                      .textSecondary,
                ),
              ),

              if (_isEditing &&
                  _selectedImage != null) ...[
                const SizedBox(height: 10),

                TextButton.icon(
                  onPressed: _isSaving
                      ? null
                      : () {
                    setState(() {
                      _selectedImage =
                      null;
                      _removeExistingPhoto =
                      true;
                    });
                  },
                  icon: const Icon(
                    Icons
                        .delete_outline_rounded,
                  ),
                  label: const Text(
                    'Remove Photo',
                  ),
                ),
              ],

              const SizedBox(height: 30),

              // =================================================
              // NAME
              // =================================================

              TextFormField(
                controller:
                _nameController,
                textCapitalization:
                TextCapitalization
                    .words,
                decoration:
                const InputDecoration(
                  labelText: 'Name',
                  hintText:
                  'Enter their name',
                  prefixIcon: Icon(
                    Icons.person_rounded,
                  ),
                ),
                validator: (value) {
                  final name =
                      value?.trim() ??
                          '';

                  if (name.isEmpty) {
                    return 'Please enter their name';
                  }

                  if (name.length < 2) {
                    return 'Name is too short';
                  }

                  return null;
                },
              ),

              const SizedBox(height: 18),

              // =================================================
              // RELATIONSHIP
              // =================================================

              DropdownButtonFormField<
                  String>(
                initialValue:
                _relationship,
                decoration:
                const InputDecoration(
                  labelText:
                  'Relationship',
                  prefixIcon: Icon(
                    Icons
                        .family_restroom_rounded,
                  ),
                ),
                items: _relationships
                    .map(
                      (relationship) =>
                      DropdownMenuItem(
                        value:
                        relationship,
                        child: Text(
                          relationship,
                        ),
                      ),
                )
                    .toList(),
                onChanged: _isSaving
                    ? null
                    : (value) {
                  if (value ==
                      null) {
                    return;
                  }

                  setState(() {
                    _relationship =
                        value;

                    if (value !=
                        'Other') {
                      _customRelationshipController
                          .clear();
                    }
                  });
                },
              ),

              // =================================================
              // OTHER RELATIONSHIP
              // =================================================

              if (isOther) ...[
                const SizedBox(
                  height: 18,
                ),

                TextFormField(
                  controller:
                  _customRelationshipController,
                  textCapitalization:
                  TextCapitalization
                      .words,
                  decoration:
                  const InputDecoration(
                    labelText:
                    'Enter relationship',
                    hintText:
                    'Example: Uncle, Aunt, Cousin',
                    prefixIcon: Icon(
                      Icons
                          .people_alt_rounded,
                    ),
                  ),
                  validator:
                  _validateCustomRelationship,
                ),
              ],

              const SizedBox(height: 18),

              // =================================================
              // PHONE
              // =================================================

              TextFormField(
                controller:
                _phoneController,
                keyboardType:
                TextInputType.number,
                inputFormatters: [
                  FilteringTextInputFormatter
                      .digitsOnly,
                ],
                maxLength: 10,
                decoration:
                const InputDecoration(
                  labelText:
                  'Phone Number',
                  hintText:
                  'Enter 10-digit mobile number',
                  prefixText: '+91 ',
                  prefixIcon: Icon(
                    Icons.phone_rounded,
                  ),
                  counterText: '',
                ),
                validator:
                _validatePhone,
              ),

              const SizedBox(height: 8),

              const Text(
                'Phone number is optional. '
                    'If entered, use a valid Indian mobile number.',
                style: TextStyle(
                  fontSize: 13,
                  color:
                  SmritiTheme
                      .textSecondary,
                ),
              ),

              const SizedBox(height: 18),

              // =================================================
              // MEMORY NOTE
              // =================================================

              TextFormField(
                controller:
                _memoryController,
                maxLines: 4,
                decoration:
                const InputDecoration(
                  labelText:
                  'Memory note',
                  hintText:
                  'Example: She visits every Sunday.',
                  prefixIcon: Icon(
                    Icons.favorite_rounded,
                  ),
                  alignLabelWithHint:
                  true,
                ),
              ),

              const SizedBox(height: 30),

              // =================================================
              // SAVE
              // =================================================

              SizedBox(
                height: 56,
                child: FilledButton.icon(
                  onPressed: _isSaving
                      ? null
                      : _saveMember,
                  icon: _isSaving
                      ? const SizedBox(
                    width: 22,
                    height: 22,
                    child:
                    CircularProgressIndicator(
                      strokeWidth: 2,
                    ),
                  )
                      : Icon(
                    _isEditing
                        ? Icons
                        .check_rounded
                        : Icons
                        .save_rounded,
                  ),
                  label: Text(
                    _isSaving
                        ? 'Saving...'
                        : _isEditing
                        ? 'Save Changes'
                        : 'Save Family Member',
                    style:
                    const TextStyle(
                      fontSize: 18,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}