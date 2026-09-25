import 'dart:async';
import 'dart:io';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:record/record.dart';

import '../data/family_store.dart';
import '../data/memory_store.dart';
import '../models/family_member.dart';
import '../models/memory.dart';
import '../theme/smriti_theme.dart';

class AddMemoryScreen extends StatefulWidget {
  final Memory? memory;

  const AddMemoryScreen({
    super.key,
    this.memory,
  });

  bool get isEditing => memory != null;

  @override
  State<AddMemoryScreen> createState() =>
      _AddMemoryScreenState();
}

class _AddMemoryScreenState
    extends State<AddMemoryScreen> {
  final _formKey = GlobalKey<FormState>();

  final _titleController =
  TextEditingController();

  final _descriptionController =
  TextEditingController();

  final _locationController =
  TextEditingController();

  final ImagePicker _imagePicker =
  ImagePicker();

  final AudioRecorder _recorder =
  AudioRecorder();

  final AudioPlayer _audioPlayer =
  AudioPlayer();

  final FamilyStore _familyStore =
      FamilyStore.instance;

  final MemoryStore _memoryStore =
      MemoryStore.instance;

  DateTime _selectedDate =
  DateTime.now();

  String? _newImagePath;
  String? _existingImagePath;

  String? _newVoicePath;
  String? _existingVoicePath;

  bool _isRecording = false;
  bool _isPlaying = false;
  bool _isSaving = false;

  Duration _recordingDuration =
      Duration.zero;

  Timer? _recordingTimer;

  final Set<String> _selectedPeople =
  <String>{};

  List<FamilyMember> get _familyMembers =>
      _familyStore.members;

  bool _isFamilyLoading = true;

  @override
  void initState() {
    super.initState();

    _loadMemory();
    _initializeFamilyStore();
  }

  Future<void> _initializeFamilyStore() async {
    await _familyStore.initialize();

    if (!mounted) {
      return;
    }

    setState(() {
      _isFamilyLoading = false;
    });
  }

  void _loadMemory() {
    final memory = widget.memory;

    if (memory == null) {
      return;
    }

    _titleController.text =
        memory.title;

    _descriptionController.text =
        memory.description;

    _locationController.text =
        memory.location;

    _selectedPeople.addAll(
      memory.people,
    );

    _existingImagePath =
        memory.imageUrl;

    _existingVoicePath =
        memory.voiceMessage;

    final parsedDate =
    DateTime.tryParse(memory.date);

    if (parsedDate != null) {
      _selectedDate = parsedDate;
    }
  }

  @override
  void dispose() {
    _recordingTimer?.cancel();

    _recorder.dispose();

    _audioPlayer.dispose();

    _titleController.dispose();
    _descriptionController.dispose();
    _locationController.dispose();

    super.dispose();
  }

  // ============================================================
  // IMAGE
  // ============================================================

  Future<void> _pickImage() async {
    try {
      final picked =
      await _imagePicker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 85,
      );

      if (picked == null) {
        return;
      }

      setState(() {
        _newImagePath =
            picked.path;
      });
    } catch (_) {
      _showMessage(
        'Unable to select the photo.',
      );
    }
  }

  Future<void> _removeImage() async {
    final oldPath =
        _existingImagePath;

    final newPath =
        _newImagePath;

    if (newPath != null) {
      setState(() {
        _newImagePath = null;
      });
    }

    if (oldPath != null) {
      await _memoryStore
          .deleteMemoryImage(oldPath);

      if (mounted) {
        setState(() {
          _existingImagePath = null;
        });
      }
    }
  }

  // ============================================================
  // DATE
  // ============================================================

  Future<void> _pickDate() async {
    final picked =
    await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate:
      DateTime(1900),
      lastDate:
      DateTime.now(),
    );

    if (picked == null) {
      return;
    }

    setState(() {
      _selectedDate = picked;
    });
  }

  // ============================================================
  // FAMILY MEMBERS
  // ============================================================

  void _togglePerson(
      FamilyMember member,
      ) {
    setState(() {
      if (_selectedPeople
          .contains(member.name)) {
        _selectedPeople
            .remove(member.name);
      } else {
        _selectedPeople
            .add(member.name);
      }
    });
  }

  // ============================================================
  // VOICE RECORDING
  // ============================================================

  Future<void> _startRecording() async {
    try {
      final permission = await _recorder.hasPermission();

      debugPrint('🎙️ MIC PERMISSION: $permission');

      if (!permission) {
        _showMessage(
          'Microphone permission is required.',
        );
        return;
      }

      final path = await _memoryStore.createMemoryAudioPath(
        extension: 'wav',
      );

      debugPrint('🎙️ RECORDING PATH: $path');

      const config = RecordConfig(
        encoder: AudioEncoder.wav,
        sampleRate: 44100,
        numChannels: 1,
      );

      debugPrint('🎙️ STARTING WAV RECORDING');

      await _recorder.start(
        config,
        path: path,
      );

      debugPrint('🎙️ RECORDING STARTED');

      setState(() {
        _newVoicePath = path;
        _isRecording = true;
        _recordingDuration = Duration.zero;
      });

      _recordingTimer?.cancel();

      _recordingTimer = Timer.periodic(
        const Duration(seconds: 1),
            (_) {
          if (!mounted || !_isRecording) {
            return;
          }

          setState(() {
            _recordingDuration +=
            const Duration(seconds: 1);
          });
        },
      );
    } catch (e, stackTrace) {
      debugPrint('❌ RECORDING START ERROR: $e');
      debugPrint('$stackTrace');

      _showMessage(
        'Unable to start recording.',
      );
    }
  }

  Future<void> _stopRecording() async {
    try {
      debugPrint('🎙️ STOPPING RECORDING');

      final path = await _recorder.stop();

      _recordingTimer?.cancel();
      _recordingTimer = null;

      debugPrint('🎙️ RECORDER RETURNED PATH: $path');

      if (path != null) {
        final file = File(path);

        final exists = await file.exists();

        debugPrint('🎙️ FILE EXISTS: $exists');

        if (exists) {
          final size = await file.length();

          debugPrint('🎙️ FILE SIZE: $size bytes');
        }
      }

      if (!mounted) {
        return;
      }

      setState(() {
        _isRecording = false;
      });

      if (path == null || path.isEmpty) {
        debugPrint('❌ RECORDING PATH IS NULL/EMPTY');

        setState(() {
          _newVoicePath = null;
        });

        return;
      }

      setState(() {
        _newVoicePath = path;
      });

      debugPrint('✅ RECORDING SAVED: $path');
    } catch (e, stackTrace) {
      debugPrint('❌ RECORDING STOP ERROR: $e');
      debugPrint('$stackTrace');

      _showMessage(
        'Unable to stop recording.',
      );
    }
  }

  Future<void> _toggleRecording() async {
    if (_isRecording) {
      await _stopRecording();
    } else {
      await _startRecording();
    }
  }

  // ============================================================
  // VOICE PLAYBACK
  // ============================================================

  String? get _activeVoicePath {
    return _newVoicePath ??
        _existingVoicePath;
  }

  Future<void>
  _toggleVoicePlayback() async {
    final path =
        _activeVoicePath;

    if (path == null) {
      return;
    }

    final file =
    File(path);

    if (!await file.exists()) {
      _showMessage(
        'Voice recording could not be found.',
      );
      return;
    }

    try {
      if (_isPlaying) {
        await _audioPlayer.stop();

        if (mounted) {
          setState(() {
            _isPlaying = false;
          });
        }

        return;
      }

      await _audioPlayer.play(
        DeviceFileSource(path),
      );

      if (mounted) {
        setState(() {
          _isPlaying = true;
        });
      }

      _audioPlayer.onPlayerComplete
          .first
          .then((_) {
        if (!mounted) {
          return;
        }

        setState(() {
          _isPlaying = false;
        });
      });
    } catch (_) {
      _showMessage(
        'Unable to play the voice recording.',
      );
    }
  }

  Future<void> _removeVoice() async {
    await _audioPlayer.stop();

    final newPath =
        _newVoicePath;

    final oldPath =
        _existingVoicePath;

    if (newPath != null) {
      await _memoryStore
          .deleteMemoryAudio(
        newPath,
      );
    }

    if (oldPath != null &&
        oldPath != newPath) {
      await _memoryStore
          .deleteMemoryAudio(
        oldPath,
      );
    }

    if (!mounted) {
      return;
    }

    setState(() {
      _newVoicePath = null;
      _existingVoicePath = null;
      _isPlaying = false;
      _recordingDuration =
          Duration.zero;
    });
  }

  // ============================================================
  // SAVE MEMORY
  // ============================================================

  Future<void> _saveMemory() async {
    if (!_formKey.currentState!
        .validate()) {
      return;
    }

    if (_selectedPeople.isEmpty) {
      _showMessage(
        'Please select at least one family member.',
      );
      return;
    }

    if (_isRecording) {
      await _stopRecording();
    }

    setState(() {
      _isSaving = true;
    });

    try {
      String? finalImagePath =
          _existingImagePath;

      if (_newImagePath != null) {
        finalImagePath =
        await _memoryStore
            .saveMemoryImage(
          _newImagePath!,
        );

        if (_existingImagePath != null) {
          await _memoryStore
              .deleteMemoryImage(
            _existingImagePath!,
          );
        }
      }

      String? finalVoicePath =
          _newVoicePath ??
              _existingVoicePath;

      if (_newVoicePath != null &&
          _existingVoicePath != null &&
          _newVoicePath !=
              _existingVoicePath) {
        await _memoryStore
            .deleteMemoryAudio(
          _existingVoicePath!,
        );
      }

      final memory =
      Memory(
        id: widget.memory?.id ??
            'memory_${DateTime.now().millisecondsSinceEpoch}',
        title:
        _titleController.text.trim(),
        description:
        _descriptionController.text.trim(),
        date: _selectedDate
            .toIso8601String()
            .split('T')
            .first,
        location:
        _locationController.text.trim(),
        people:
        _selectedPeople.toList(),
        imageUrl:
        finalImagePath,
        voiceMessage:
        finalVoicePath,
        tags:
        widget.memory?.tags ??
            const [],
      );

      if (widget.isEditing) {
        await _memoryStore
            .updateMemory(
          memory,
        );
      } else {
        await _memoryStore
            .addMemory(
          memory,
        );
      }

      if (!mounted) {
        return;
      }

      Navigator.pop(
        context,
        true,
      );
    } catch (_) {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });

        _showMessage(
          'Unable to save the memory.',
        );
      }
    }
  }

  // ============================================================
  // HELPERS
  // ============================================================

  void _showMessage(
      String message,
      ) {
    if (!mounted) {
      return;
    }

    ScaffoldMessenger.of(context)
        .showSnackBar(
      SnackBar(
        content: Text(message),
      ),
    );
  }

  String _formatDuration(
      Duration duration,
      ) {
    final minutes =
    duration.inMinutes
        .remainder(60)
        .toString()
        .padLeft(2, '0');

    final seconds =
    duration.inSeconds
        .remainder(60)
        .toString()
        .padLeft(2, '0');

    return '$minutes:$seconds';
  }

  // ============================================================
  // BUILD
  // ============================================================

  @override
  Widget build(
      BuildContext context,
      ) {
    if (_isFamilyLoading) {
      return Scaffold(
        appBar: AppBar(
          title: Text(
            widget.isEditing
                ? 'Edit Memory'
                : 'Add Memory',
          ),
        ),
        body: const Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.isEditing
              ? 'Edit Memory'
              : 'Add Memory',
        ),
      ),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: ListView(
            padding:
            const EdgeInsets.all(20),
            children: [
              const Text(
                'Memory Details',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight:
                  FontWeight.bold,
                  color:
                  SmritiTheme.primaryDark,
                ),
              ),

              const SizedBox(height: 8),

              const Text(
                'Add a special moment that SMRITI can remember.',
                style: TextStyle(
                  fontSize: 16,
                  color:
                  SmritiTheme.textSecondary,
                ),
              ),

              const SizedBox(height: 24),

              // TITLE
              TextFormField(
                controller:
                _titleController,
                textCapitalization:
                TextCapitalization
                    .sentences,
                decoration:
                const InputDecoration(
                  labelText:
                  'Memory Title',
                  hintText:
                  'e.g. Diwali with Family',
                  prefixIcon:
                  Icon(Icons.title),
                  border:
                  OutlineInputBorder(),
                ),
                validator:
                    (value) {
                  if (value ==
                      null ||
                      value.trim()
                          .isEmpty) {
                    return 'Please enter a title.';
                  }

                  return null;
                },
              ),

              const SizedBox(height: 16),

              // DESCRIPTION
              TextFormField(
                controller:
                _descriptionController,
                textCapitalization:
                TextCapitalization
                    .sentences,
                maxLines: 4,
                decoration:
                const InputDecoration(
                  labelText:
                  'Description',
                  hintText:
                  'Describe this memory...',
                  prefixIcon:
                  Icon(Icons.notes),
                  border:
                  OutlineInputBorder(),
                  alignLabelWithHint:
                  true,
                ),
                validator:
                    (value) {
                  if (value ==
                      null ||
                      value.trim()
                          .isEmpty) {
                    return 'Please enter a description.';
                  }

                  return null;
                },
              ),

              const SizedBox(height: 16),

              // DATE
              InkWell(
                onTap: _pickDate,
                borderRadius:
                BorderRadius
                    .circular(12),
                child:
                InputDecorator(
                  decoration:
                  const InputDecoration(
                    labelText: 'Date',
                    prefixIcon:
                    Icon(
                      Icons
                          .calendar_month,
                    ),
                    border:
                    OutlineInputBorder(),
                  ),
                  child: Text(
                    '${_selectedDate.day.toString().padLeft(2, '0')}/'
                        '${_selectedDate.month.toString().padLeft(2, '0')}/'
                        '${_selectedDate.year}',
                  ),
                ),
              ),

              const SizedBox(height: 16),

              // LOCATION
              TextFormField(
                controller:
                _locationController,
                textCapitalization:
                TextCapitalization
                    .words,
                decoration:
                const InputDecoration(
                  labelText:
                  'Location',
                  hintText:
                  'e.g. Home',
                  prefixIcon:
                  Icon(
                    Icons
                        .location_on_outlined,
                  ),
                  border:
                  OutlineInputBorder(),
                ),
              ),

              const SizedBox(height: 28),

              // PEOPLE
              const Text(
                'People in this Memory',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight:
                  FontWeight.bold,
                  color:
                  SmritiTheme.primaryDark,
                ),
              ),

              const SizedBox(height: 8),

              const Text(
                'Select the family members connected to this moment.',
                style: TextStyle(
                  color:
                  SmritiTheme.textSecondary,
                ),
              ),

              const SizedBox(height: 12),

              if (_familyMembers.isEmpty)
                const Text(
                  'No family members have been added yet.',
                )
              else
                ..._familyMembers.map(
                      (member) {
                    final selected =
                    _selectedPeople
                        .contains(
                      member.name,
                    );

                    return Card(
                      margin:
                      const EdgeInsets
                          .only(
                        bottom: 8,
                      ),
                      child:
                      CheckboxListTile(
                        value: selected,
                        onChanged:
                            (_) {
                          _togglePerson(
                            member,
                          );
                        },
                        title:
                        Text(
                          member.name,
                        ),
                        subtitle:
                        Text(
                          member.relationship,
                        ),
                        secondary:
                        CircleAvatar(
                          backgroundImage:
                          member.photoUrl !=
                              null
                              ? FileImage(
                            File(
                              member
                                  .photoUrl!,
                            ),
                          )
                              : null,
                          child:
                          member.photoUrl ==
                              null
                              ? const Icon(
                            Icons
                                .person,
                          )
                              : null,
                        ),
                      ),
                    );
                  },
                ),

              const SizedBox(height: 28),

              // PHOTO
              const Text(
                'Memory Photo',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight:
                  FontWeight.bold,
                  color:
                  SmritiTheme.primaryDark,
                ),
              ),

              const SizedBox(height: 8),

              const Text(
                'Add a photo to help make this memory recognizable.',
                style: TextStyle(
                  color:
                  SmritiTheme.textSecondary,
                ),
              ),

              const SizedBox(height: 12),

              _buildPhotoSection(),

              const SizedBox(height: 28),

              // VOICE
              const Text(
                'Voice Memory',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight:
                  FontWeight.bold,
                  color:
                  SmritiTheme.primaryDark,
                ),
              ),

              const SizedBox(height: 8),

              const Text(
                'Record a familiar voice message connected to this memory.',
                style: TextStyle(
                  color:
                  SmritiTheme.textSecondary,
                ),
              ),

              const SizedBox(height: 12),

              _buildVoiceSection(),

              const SizedBox(height: 32),

              // SAVE
              SizedBox(
                width:
                double.infinity,
                height: 54,
                child:
                FilledButton.icon(
                  onPressed:
                  _isSaving
                      ? null
                      : _saveMemory,
                  icon: _isSaving
                      ? const SizedBox(
                    height: 22,
                    width: 22,
                    child:
                    CircularProgressIndicator(
                      strokeWidth: 2,
                    ),
                  )
                      : const Icon(
                    Icons
                        .save_outlined,
                  ),
                  label: Text(
                    _isSaving
                        ? 'Saving...'
                        : widget.isEditing
                        ? 'Save Changes'
                        : 'Save Memory',
                    style:
                    const TextStyle(
                      fontSize: 17,
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  // ============================================================
  // PHOTO SECTION
  // ============================================================

  Widget _buildPhotoSection() {
    final path =
        _newImagePath ??
            _existingImagePath;

    if (path == null) {
      return OutlinedButton.icon(
        onPressed: _pickImage,
        icon: const Icon(
          Icons
              .add_photo_alternate_outlined,
        ),
        label:
        const Text('Add Photo'),
        style:
        OutlinedButton.styleFrom(
          minimumSize:
          const Size.fromHeight(
            52,
          ),
        ),
      );
    }

    return Column(
      children: [
        ClipRRect(
          borderRadius:
          BorderRadius.circular(
            18,
          ),
          child: Image.file(
            File(path),
            width:
            double.infinity,
            height: 220,
            fit: BoxFit.cover,
            errorBuilder:
                (_, __, ___) {
              return Container(
                height: 220,
                alignment:
                Alignment.center,
                color:
                SmritiTheme.softGreen,
                child:
                const Icon(
                  Icons
                      .broken_image_outlined,
                  size: 50,
                ),
              );
            },
          ),
        ),

        const SizedBox(height: 12),

        Row(
          children: [
            Expanded(
              child:
              OutlinedButton
                  .icon(
                onPressed:
                _pickImage,
                icon:
                const Icon(
                  Icons
                      .change_circle_outlined,
                ),
                label:
                const Text(
                  'Change Photo',
                ),
              ),
            ),

            const SizedBox(width: 10),

            IconButton(
              tooltip:
              'Remove photo',
              onPressed:
              _removeImage,
              icon:
              const Icon(
                Icons
                    .delete_outline,
              ),
            ),
          ],
        ),
      ],
    );
  }

  // ============================================================
  // VOICE SECTION
  // ============================================================

  Widget _buildVoiceSection() {
    final voiceExists =
        _activeVoicePath != null;

    return Container(
      padding:
      const EdgeInsets.all(18),
      decoration:
      BoxDecoration(
        color:
        SmritiTheme.softGreen,
        borderRadius:
        BorderRadius.circular(
          20,
        ),
        border:
        Border.all(
          color:
          SmritiTheme.border,
        ),
      ),
      child: Column(
        children: [
          if (_isRecording) ...[
            const Icon(
              Icons.mic,
              size: 48,
              color:
              SmritiTheme.primary,
            ),

            const SizedBox(height: 8),

            Text(
              'Recording ${_formatDuration(_recordingDuration)}',
              style:
              const TextStyle(
                fontSize: 18,
                fontWeight:
                FontWeight.bold,
              ),
            ),

            const SizedBox(height: 6),

            const Text(
              'Speak naturally and clearly.',
              textAlign:
              TextAlign.center,
            ),

            const SizedBox(height: 16),
          ],

          if (voiceExists &&
              !_isRecording) ...[
            Row(
              children: [
                IconButton.filled(
                  onPressed:
                  _toggleVoicePlayback,
                  icon: Icon(
                    _isPlaying
                        ? Icons.stop
                        : Icons.play_arrow,
                  ),
                ),

                const SizedBox(
                  width: 12,
                ),

                const Expanded(
                  child: Text(
                    'Voice memory recorded',
                    style:
                    TextStyle(
                      fontWeight:
                      FontWeight.w600,
                    ),
                  ),
                ),

                IconButton(
                  tooltip:
                  'Remove voice',
                  onPressed:
                  _removeVoice,
                  icon:
                  const Icon(
                    Icons
                        .delete_outline,
                  ),
                ),
              ],
            ),

            const SizedBox(height: 12),
          ],

          SizedBox(
            width:
            double.infinity,
            child:
            FilledButton.icon(
              onPressed:
              _toggleRecording,
              icon: Icon(
                _isRecording
                    ? Icons.stop
                    : Icons.mic,
              ),
              label: Text(
                _isRecording
                    ? 'Stop Recording'
                    : voiceExists
                    ? 'Record Again'
                    : 'Record Voice Memory',
              ),
            ),
          ),

          if (voiceExists &&
              !_isRecording)
            const Padding(
              padding:
              EdgeInsets.only(
                top: 10,
              ),
              child: Text(
                'Record Again will replace the current voice memory.',
                textAlign:
                TextAlign.center,
              ),
            ),
        ],
      ),
    );
  }
}