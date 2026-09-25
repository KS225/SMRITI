import 'dart:io';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';

import '../data/memory_store.dart';
import '../models/memory.dart';
import '../theme/smriti_theme.dart';
import 'add_memory_screen.dart';

class MemoriesScreen extends StatefulWidget {
  const MemoriesScreen({
    super.key,
  });

  @override
  State<MemoriesScreen> createState() =>
      _MemoriesScreenState();
}

class _MemoriesScreenState
    extends State<MemoriesScreen> {
  final MemoryStore _memoryStore =
      MemoryStore.instance;

  @override
  void initState() {
    super.initState();

    _memoryStore.addListener(
      _onMemoriesChanged,
    );

    _memoryStore.initialize();
  }

  @override
  void dispose() {
    _memoryStore.removeListener(
      _onMemoriesChanged,
    );

    super.dispose();
  }

  void _onMemoriesChanged() {
    if (mounted) {
      setState(() {});
    }
  }

  // ============================================================
  // ADD MEMORY
  // ============================================================

  Future<void> _addMemory() async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) =>
        const AddMemoryScreen(),
      ),
    );
  }

  // ============================================================
  // EDIT MEMORY
  // ============================================================

  Future<void> _editMemory(
      Memory memory,
      ) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) =>
            AddMemoryScreen(
              memory: memory,
            ),
      ),
    );
  }

  // ============================================================
  // DELETE MEMORY
  // ============================================================

  Future<void> _deleteMemory(
      Memory memory,
      ) async {
    final shouldDelete =
    await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text(
            'Delete this memory?',
          ),
          content: const Text(
            'This memory, its photo and voice recording will be removed from SMRITI.',
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(
                  context,
                  false,
                );
              },
              child:
              const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () {
                Navigator.pop(
                  context,
                  true,
                );
              },
              child:
              const Text('Delete'),
            ),
          ],
        );
      },
    );

    if (shouldDelete != true) {
      return;
    }

    await _memoryStore.removeMemory(
      memory.id,
    );

    if (!mounted) {
      return;
    }

    ScaffoldMessenger.of(context)
        .showSnackBar(
      const SnackBar(
        content: Text(
          'Memory deleted.',
        ),
      ),
    );
  }

  // ============================================================
  // BUILD
  // ============================================================

  @override
  Widget build(
      BuildContext context,
      ) {
    final memories =
        _memoryStore.memories;

    return Scaffold(
      appBar: AppBar(
        title:
        const Text('My Memories'),
        actions: [
          IconButton(
            tooltip: 'Add memory',
            onPressed: _addMemory,
            icon: const Icon(
              Icons
                  .add_photo_alternate_rounded,
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: ListView(
          padding:
          const EdgeInsets.fromLTRB(
            20,
            10,
            20,
            30,
          ),
          children: [
            const Text(
              'Special moments from your life ❤️',
              textAlign:
              TextAlign.center,
              style: TextStyle(
                fontSize: 18,
                color:
                SmritiTheme
                    .textSecondary,
              ),
            ),

            const SizedBox(height: 20),

            // ==================================================
            // ADD MEMORY BUTTON
            // ==================================================

            SizedBox(
              width:
              double.infinity,
              height: 52,
              child:
              FilledButton.icon(
                onPressed:
                _addMemory,
                icon:
                const Icon(
                  Icons
                      .add_photo_alternate_rounded,
                ),
                label:
                const Text(
                  'Add Memory',
                  style:
                  TextStyle(
                    fontSize: 17,
                  ),
                ),
              ),
            ),

            const SizedBox(height: 26),

            if (memories.isEmpty)
              _buildEmptyState(),

            ...memories.map(
                  (memory) =>
                  Padding(
                    padding:
                    const EdgeInsets.only(
                      bottom: 18,
                    ),
                    child:
                    MemoryCard(
                      memory: memory,
                      onEdit: () =>
                          _editMemory(
                            memory,
                          ),
                      onDelete: () =>
                          _deleteMemory(
                            memory,
                          ),
                    ),
                  ),
            ),
          ],
        ),
      ),
    );
  }

  // ============================================================
  // EMPTY STATE
  // ============================================================

  Widget _buildEmptyState() {
    return Container(
      padding:
      const EdgeInsets.all(24),
      decoration:
      BoxDecoration(
        color:
        SmritiTheme.softGreen,
        borderRadius:
        BorderRadius.circular(
          24,
        ),
        border:
        Border.all(
          color:
          SmritiTheme.border,
        ),
      ),
      child: const Column(
        children: [
          Icon(
            Icons
                .photo_album_rounded,
            size: 70,
            color:
            SmritiTheme.primary,
          ),

          SizedBox(height: 16),

          Text(
            'No memories yet',
            textAlign:
            TextAlign.center,
            style: TextStyle(
              fontSize: 23,
              fontWeight:
              FontWeight.bold,
              color:
              SmritiTheme
                  .primaryDark,
            ),
          ),

          SizedBox(height: 8),

          Text(
            'Add a special moment that you would like SMRITI to remember.',
            textAlign:
            TextAlign.center,
            style: TextStyle(
              fontSize: 16,
              height: 1.4,
              color:
              SmritiTheme
                  .textSecondary,
            ),
          ),

          SizedBox(height: 18),

          Text(
            '❤️',
            style: TextStyle(
              fontSize: 30,
            ),
          ),
        ],
      ),
    );
  }
}

// ============================================================
// MEMORY CARD
// ============================================================

class MemoryCard
    extends StatelessWidget {
  final Memory memory;

  final VoidCallback? onEdit;

  final VoidCallback? onDelete;

  const MemoryCard({
    super.key,
    required this.memory,
    this.onEdit,
    this.onDelete,
  });

  // ============================================================
  // IMAGE
  // ============================================================

  ImageProvider?
  _getMemoryImage() {
    final path =
        memory.imageUrl;

    if (path == null ||
        path.isEmpty) {
      return null;
    }

    final file = File(path);

    if (!file.existsSync()) {
      return null;
    }

    return FileImage(file);
  }

  // ============================================================
  // BUILD
  // ============================================================

  @override
  Widget build(
      BuildContext context,
      ) {
    final image =
    _getMemoryImage();

    return Material(
      color:
      SmritiTheme.surface,
      borderRadius:
      BorderRadius.circular(
        24,
      ),
      child: InkWell(
        borderRadius:
        BorderRadius.circular(
          24,
        ),
        onTap: () {
          _showMemoryDetails(
            context,
          );
        },
        child: Container(
          decoration:
          BoxDecoration(
            borderRadius:
            BorderRadius.circular(
              24,
            ),
            border:
            Border.all(
              color:
              SmritiTheme.border,
            ),
          ),
          clipBehavior:
          Clip.antiAlias,
          child: Column(
            crossAxisAlignment:
            CrossAxisAlignment
                .start,
            children: [
              // ==================================================
              // IMAGE
              // ==================================================

              if (image != null)
                SizedBox(
                  width:
                  double.infinity,
                  height: 210,
                  child: Image(
                    image: image,
                    fit: BoxFit.cover,
                  ),
                )
              else
                Container(
                  width:
                  double.infinity,
                  height: 150,
                  color:
                  SmritiTheme
                      .softGreen,
                  child:
                  const Icon(
                    Icons
                        .photo_library_rounded,
                    size: 60,
                    color:
                    SmritiTheme
                        .primary,
                  ),
                ),

              // ==================================================
              // CONTENT
              // ==================================================

              Padding(
                padding:
                const EdgeInsets
                    .all(18),
                child: Column(
                  crossAxisAlignment:
                  CrossAxisAlignment
                      .start,
                  children: [
                    Row(
                      crossAxisAlignment:
                      CrossAxisAlignment
                          .start,
                      children: [
                        Expanded(
                          child:
                          Text(
                            memory.title,
                            style:
                            const TextStyle(
                              fontSize:
                              22,
                              fontWeight:
                              FontWeight
                                  .bold,
                              color:
                              SmritiTheme
                                  .textPrimary,
                            ),
                          ),
                        ),

                        // EDIT
                        if (onEdit !=
                            null)
                          IconButton(
                            tooltip:
                            'Edit memory',
                            onPressed:
                            onEdit,
                            icon:
                            const Icon(
                              Icons
                                  .edit_outlined,
                            ),
                          ),

                        // DELETE
                        if (onDelete !=
                            null)
                          IconButton(
                            tooltip:
                            'Delete memory',
                            onPressed:
                            onDelete,
                            icon:
                            const Icon(
                              Icons
                                  .delete_outline_rounded,
                            ),
                          ),
                      ],
                    ),

                    const SizedBox(
                      height: 8,
                    ),

                    Text(
                      memory.description,
                      maxLines: 3,
                      overflow:
                      TextOverflow
                          .ellipsis,
                      style:
                      const TextStyle(
                        fontSize: 16,
                        height: 1.4,
                        color:
                        SmritiTheme
                            .textSecondary,
                      ),
                    ),

                    const SizedBox(
                      height: 14,
                    ),

                    Wrap(
                      spacing: 12,
                      runSpacing: 8,
                      children: [
                        if (memory
                            .date
                            .isNotEmpty)
                          _InfoChip(
                            icon: Icons
                                .calendar_month_rounded,
                            text:
                            memory.date,
                          ),

                        if (memory
                            .location
                            .isNotEmpty)
                          _InfoChip(
                            icon: Icons
                                .location_on_rounded,
                            text:
                            memory.location,
                          ),

                        if (memory
                            .voiceMessage !=
                            null)
                          const _InfoChip(
                            icon:
                            Icons
                                .mic_none_rounded,
                            text:
                            'Voice',
                          ),
                      ],
                    ),

                    if (memory
                        .people
                        .isNotEmpty) ...[
                      const SizedBox(
                        height: 12,
                      ),
                      _InfoChip(
                        icon: Icons
                            .people_alt_rounded,
                        text:
                        memory.people
                            .join(
                          ', ',
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ============================================================
  // DETAILS
  // ============================================================

  void _showMemoryDetails(
      BuildContext context,
      ) {
    final image =
    _getMemoryImage();

    showModalBottomSheet(
      context: context,
      isScrollControlled:
      true,
      backgroundColor:
      SmritiTheme.surface,
      shape:
      const RoundedRectangleBorder(
        borderRadius:
        BorderRadius.vertical(
          top: Radius.circular(
            28,
          ),
        ),
      ),
      builder: (context) {
        return MemoryDetailsSheet(
          memory: memory,
          image: image,
        );
      },
    );
  }
}

// ============================================================
// MEMORY DETAILS
// ============================================================

class MemoryDetailsSheet
    extends StatefulWidget {
  final Memory memory;

  final ImageProvider? image;

  const MemoryDetailsSheet({
    super.key,
    required this.memory,
    this.image,
  });

  @override
  State<MemoryDetailsSheet>
  createState() =>
      _MemoryDetailsSheetState();
}

class _MemoryDetailsSheetState
    extends State<
        MemoryDetailsSheet> {
  final AudioPlayer _audioPlayer =
  AudioPlayer();

  bool _isPlaying = false;

  @override
  void dispose() {
    _audioPlayer.dispose();

    super.dispose();
  }

  Future<void>
  _toggleVoice() async {
    final path =
        widget.memory.voiceMessage;

    if (path == null) {
      return;
    }

    final file =
    File(path);

    if (!await file.exists()) {
      if (mounted) {
        ScaffoldMessenger.of(
            context)
            .showSnackBar(
          const SnackBar(
            content: Text(
              'Voice recording could not be found.',
            ),
          ),
        );
      }

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
      if (mounted) {
        ScaffoldMessenger.of(
            context)
            .showSnackBar(
          const SnackBar(
            content: Text(
              'Unable to play voice memory.',
            ),
          ),
        );
      }
    }
  }

  @override
  Widget build(
      BuildContext context,
      ) {
    final memory =
        widget.memory;

    return SafeArea(
      child:
      SingleChildScrollView(
        padding:
        const EdgeInsets.fromLTRB(
          20,
          12,
          20,
          30,
        ),
        child: Column(
          crossAxisAlignment:
          CrossAxisAlignment
              .start,
          children: [
            Center(
              child: Container(
                width: 45,
                height: 5,
                decoration:
                BoxDecoration(
                  color:
                  SmritiTheme
                      .border,
                  borderRadius:
                  BorderRadius
                      .circular(
                    10,
                  ),
                ),
              ),
            ),

            const SizedBox(
              height: 20,
            ),

            if (widget.image !=
                null)
              ClipRRect(
                borderRadius:
                BorderRadius
                    .circular(
                  22,
                ),
                child: Image(
                  image:
                  widget.image!,
                  width:
                  double.infinity,
                  height: 230,
                  fit: BoxFit.cover,
                ),
              ),

            if (widget.image !=
                null)
              const SizedBox(
                height: 20,
              ),

            Text(
              memory.title,
              style:
              const TextStyle(
                fontSize: 28,
                fontWeight:
                FontWeight.bold,
                color:
                SmritiTheme
                    .primaryDark,
              ),
            ),

            const SizedBox(
              height: 12,
            ),

            Text(
              memory.description,
              style:
              const TextStyle(
                fontSize: 17,
                height: 1.5,
                color:
                SmritiTheme
                    .textSecondary,
              ),
            ),

            const SizedBox(
              height: 20,
            ),

            if (memory.date
                .isNotEmpty)
              _DetailRow(
                icon: Icons
                    .calendar_month_rounded,
                title: 'Date',
                value:
                memory.date,
              ),

            if (memory.location
                .isNotEmpty)
              _DetailRow(
                icon: Icons
                    .location_on_rounded,
                title:
                'Location',
                value:
                memory.location,
              ),

            if (memory.people
                .isNotEmpty)
              _DetailRow(
                icon: Icons
                    .people_alt_rounded,
                title:
                'People',
                value:
                memory.people
                    .join(', '),
              ),

            if (memory.voiceMessage !=
                null) ...[
              const SizedBox(
                height: 10,
              ),

              SizedBox(
                width:
                double.infinity,
                height: 52,
                child:
                FilledButton.icon(
                  onPressed:
                  _toggleVoice,
                  icon: Icon(
                    _isPlaying
                        ? Icons.stop
                        : Icons
                        .play_arrow,
                  ),
                  label: Text(
                    _isPlaying
                        ? 'Stop Voice Memory'
                        : 'Play Voice Memory',
                  ),
                ),
              ),
            ],

            const SizedBox(
              height: 18,
            ),

            SizedBox(
              width:
              double.infinity,
              height: 52,
              child:
              FilledButton(
                onPressed: () {
                  Navigator.pop(
                    context,
                  );
                },
                child:
                const Text(
                  'Close',
                  style:
                  TextStyle(
                    fontSize: 17,
                  ),
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
// INFO CHIP
// ============================================================

class _InfoChip
    extends StatelessWidget {
  final IconData icon;

  final String text;

  const _InfoChip({
    required this.icon,
    required this.text,
  });

  @override
  Widget build(
      BuildContext context,
      ) {
    return Container(
      padding:
      const EdgeInsets.symmetric(
        horizontal: 10,
        vertical: 7,
      ),
      decoration:
      BoxDecoration(
        color:
        SmritiTheme.softGreen,
        borderRadius:
        BorderRadius.circular(
          20,
        ),
      ),
      child: Row(
        mainAxisSize:
        MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 17,
            color:
            SmritiTheme.primary,
          ),

          const SizedBox(
            width: 6,
          ),

          Text(
            text,
            style:
            const TextStyle(
              fontSize: 14,
              color:
              SmritiTheme
                  .primaryDark,
              fontWeight:
              FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

// ============================================================
// DETAIL ROW
// ============================================================

class _DetailRow
    extends StatelessWidget {
  final IconData icon;

  final String title;

  final String value;

  const _DetailRow({
    required this.icon,
    required this.title,
    required this.value,
  });

  @override
  Widget build(
      BuildContext context,
      ) {
    return Padding(
      padding:
      const EdgeInsets.only(
        bottom: 14,
      ),
      child: Row(
        crossAxisAlignment:
        CrossAxisAlignment
            .start,
        children: [
          Container(
            width: 42,
            height: 42,
            decoration:
            BoxDecoration(
              color:
              SmritiTheme
                  .softGreen,
              borderRadius:
              BorderRadius.circular(
                12,
              ),
            ),
            child: Icon(
              icon,
              color:
              SmritiTheme.primary,
            ),
          ),

          const SizedBox(
            width: 12,
          ),

          Expanded(
            child: Column(
              crossAxisAlignment:
              CrossAxisAlignment
                  .start,
              children: [
                Text(
                  title,
                  style:
                  const TextStyle(
                    fontSize: 13,
                    color:
                    SmritiTheme
                        .textSecondary,
                  ),
                ),

                const SizedBox(
                  height: 2,
                ),

                Text(
                  value,
                  style:
                  const TextStyle(
                    fontSize: 17,
                    fontWeight:
                    FontWeight.w600,
                    color:
                    SmritiTheme
                        .textPrimary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}