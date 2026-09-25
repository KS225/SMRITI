import 'dart:math';
import 'dart:io';

import 'package:flutter/material.dart';

import '../data/cognitive_session_store.dart';
import '../data/memory_enhancement_store.dart';
import '../data/memory_store.dart';
import '../data/memory_question_engine.dart';
import '../models/memory.dart';
import '../theme/smriti_theme.dart';
import 'remember_the_moment_game.dart';

class MemoryStudioScreen extends StatefulWidget {
  const MemoryStudioScreen({super.key});

  @override
  State<MemoryStudioScreen> createState() =>
      _MemoryStudioScreenState();
}

class _MemoryStudioScreenState extends State<MemoryStudioScreen> {
  final MemoryStore _memoryStore = MemoryStore.instance;
  final MemoryEnhancementStore _store =
      MemoryEnhancementStore.instance;
  final CognitiveSessionStore _sessionStore =
      CognitiveSessionStore.instance;

  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _initialize();
  }

  Future<void> _initialize() async {
    await Future.wait([
      _memoryStore.initialize(),
      _store.initialize(),
      _sessionStore.initialize(),
    ]);
    if (mounted) setState(() => _loading = false);
  }

  ImageProvider? _imageFor(Memory memory) {
    final path = memory.imageUrl;
    if (path == null || path.isEmpty) return null;
    final file = File(path);
    if (!file.existsSync()) return null;
    return FileImage(file);
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return Scaffold(
        appBar: AppBar(title: const Text('Memory Studio')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    final memories = List<Memory>.from(_memoryStore.memories)
      ..sort((a, b) {
        final aDate = DateTime.tryParse(a.date);
        final bDate = DateTime.tryParse(b.date);
        if (aDate == null && bDate == null) return a.title.compareTo(b.title);
        if (aDate == null) return 1;
        if (bDate == null) return -1;
        return aDate.compareTo(bDate);
      });

    final due = memories
        .where((memory) => _store.enhancementFor(memory.id).isDueForReview)
        .length;
    final questions = memories.fold<int>(
      0,
          (sum, memory) =>
      sum + _store.questionsForMemory(memory.id).length,
    );

    return Scaffold(
      appBar: AppBar(
        title: const Text('Memory Studio'),
        actions: [
          IconButton(
            onPressed: () => setState(() {}),
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 30),
        children: [
          const Text(
            'Personalize the memories used by Remember the Moment. ❤️',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 18,
              height: 1.35,
              color: SmritiTheme.textSecondary,
            ),
          ),
          const SizedBox(height: 16),
          _overview(memories.length, due, questions),
          const SizedBox(height: 16),
          ...memories.map(
                (memory) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: _memoryCard(memory),
            ),
          ),
          if (memories.isEmpty)
            const Padding(
              padding: EdgeInsets.all(30),
              child: Text(
                'Add memories first. They will appear here for personalization.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 16,
                  color: SmritiTheme.textSecondary,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _overview(int memoryCount, int due, int questions) {
    return Container(
      padding: const EdgeInsets.all(17),
      decoration: BoxDecoration(
        color: SmritiTheme.softGreen,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: SmritiTheme.border),
      ),
      child: Wrap(
        spacing: 20,
        runSpacing: 12,
        children: [
          _metric(Icons.photo_album_rounded, '$memoryCount', 'Memories'),
          _metric(Icons.refresh_rounded, '$due', 'Review due'),
          _metric(Icons.quiz_rounded, '$questions', 'Questions'),
        ],
      ),
    );
  }

  Widget _metric(IconData icon, String value, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: SmritiTheme.primary),
        const SizedBox(width: 7),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              value,
              style: const TextStyle(
                fontSize: 19,
                fontWeight: FontWeight.bold,
                color: SmritiTheme.primaryDark,
              ),
            ),
            Text(
              label,
              style: const TextStyle(
                fontSize: 12,
                color: SmritiTheme.textSecondary,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _memoryCard(Memory memory) {
    final e = _store.enhancementFor(memory.id);
    final image = _imageFor(memory);
    final qCount = _store.questionsForMemory(memory.id).length;

    return Material(
      color: SmritiTheme.surface,
      borderRadius: BorderRadius.circular(22),
      child: InkWell(
        onTap: () => _openEditor(memory),
        borderRadius: BorderRadius.circular(22),
        child: Container(
          padding: const EdgeInsets.all(15),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: SmritiTheme.border),
          ),
          child: Row(
            children: [
              Container(
                width: 78,
                height: 78,
                decoration: BoxDecoration(
                  color: SmritiTheme.softGreen,
                  borderRadius: BorderRadius.circular(18),
                ),
                clipBehavior: Clip.antiAlias,
                child: image != null
                    ? Image(image: image, fit: BoxFit.cover)
                    : const Icon(
                  Icons.photo_rounded,
                  size: 34,
                  color: SmritiTheme.primary,
                ),
              ),
              const SizedBox(width: 13),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      memory.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: SmritiTheme.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      e.category +
                          (e.album.isEmpty ? '' : ' · ${e.album}'),
                      style: const TextStyle(
                        fontSize: 13,
                        color: SmritiTheme.textSecondary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 7),
                    Wrap(
                      spacing: 7,
                      children: [
                        _mini(Icons.visibility_rounded, '${e.timesSeen}'),
                        _mini(Icons.favorite_rounded, '${e.rememberedCount}'),
                        _mini(Icons.quiz_rounded, '$qCount'),
                      ],
                    ),
                  ],
                ),
              ),
              const Icon(
                Icons.arrow_forward_ios_rounded,
                size: 16,
                color: SmritiTheme.primary,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _mini(IconData icon, String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 5),
      decoration: BoxDecoration(
        color: SmritiTheme.softGreen,
        borderRadius: BorderRadius.circular(15),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: SmritiTheme.primary),
          const SizedBox(width: 4),
          Text(
            text,
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: SmritiTheme.primaryDark,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _openEditor(Memory memory) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => MemoryEditorScreen(memory: memory),
      ),
    );
    if (mounted) setState(() {});
  }
}

class MemoryEditorScreen extends StatefulWidget {
  final Memory memory;

  const MemoryEditorScreen({
    super.key,
    required this.memory,
  });

  @override
  State<MemoryEditorScreen> createState() => _MemoryEditorScreenState();
}

class _MemoryEditorScreenState extends State<MemoryEditorScreen> {
  final MemoryStore _memoryStore = MemoryStore.instance;
  final MemoryEnhancementStore _store =
      MemoryEnhancementStore.instance;

  late TextEditingController _albumController;
  late String _category;
  final Set<String> _relatedIds = {};
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final e = _store.enhancementFor(widget.memory.id);
    _category = e.category;
    _relatedIds.addAll(e.relatedMemoryIds);
    _albumController = TextEditingController(text: e.album);
  }

  @override
  void dispose() {
    _albumController.dispose();
    super.dispose();
  }

  List<String> get _categories => _store.categoriesForMemoryData(
    [_category, ..._store.allCategories],
  );

  ImageProvider? _imageFor(Memory memory) {
    final path = memory.imageUrl;
    if (path == null || path.isEmpty) return null;
    final file = File(path);
    if (!file.existsSync()) return null;
    return FileImage(file);
  }

  Future<void> _saveMetadata() async {
    setState(() => _saving = true);
    await _store.updateMetadata(
      widget.memory.id,
      category: _category,
      album: _albumController.text,
      relatedMemoryIds: _relatedIds.toList(),
    );
    if (mounted) {
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Memory settings saved.')),
      );
    }
  }

  Future<void> _smartGenerate() async {
    final engine = MemoryQuestionEngine(
      memoryStore: _memoryStore,
      enhancementStore: _store,
    );
    final questions = engine.generateSuggestedQuestions(
      widget.memory,
      difficulty: 'Standard',
      count: 4,
    );

    if (questions.isEmpty) {
      _message('Add people, a location, a date or more memories first.');
      return;
    }

    for (var i = 0; i < questions.length; i++) {
      final q = questions[i];
      await _store.addQuestion(
        MemoryQuestion(
          id:
          'smart_${widget.memory.id}_${DateTime.now().millisecondsSinceEpoch}_$i',
          memoryId: widget.memory.id,
          type: q.type,
          prompt: q.prompt,
          options: q.options,
          correctAnswer: q.correctAnswer,
          hint: q.hint,
          difficulty: 'Standard',
          enabled: true,
          createdAt: DateTime.now(),
        ),
      );
    }

    if (mounted) {
      setState(() {});
      _message('${questions.length} smart questions added.');
    }
  }

  Future<void> _addQuestion() async {
    final draft = await showDialog<_QuestionDraft>(
      context: context,
      builder: (_) => const _QuestionDialog(),
    );
    if (draft == null) return;

    await _store.addQuestion(
      MemoryQuestion(
        id:
        'custom_${widget.memory.id}_${DateTime.now().millisecondsSinceEpoch}',
        memoryId: widget.memory.id,
        type: 'custom',
        prompt: draft.prompt,
        options: draft.options,
        correctAnswer: draft.options[draft.correctIndex],
        hint: draft.hint,
        difficulty: draft.difficulty,
        enabled: true,
        createdAt: DateTime.now(),
      ),
    );

    if (mounted) setState(() {});
  }

  Future<void> _editQuestion(MemoryQuestion question) async {
    final draft = await showDialog<_QuestionDraft>(
      context: context,
      builder: (_) => _QuestionDialog(initial: question),
    );
    if (draft == null) return;

    await _store.updateQuestion(
      question.copyWith(
        prompt: draft.prompt,
        options: draft.options,
        correctAnswer: draft.options[draft.correctIndex],
        hint: draft.hint,
        difficulty: draft.difficulty,
      ),
    );

    if (mounted) setState(() {});
  }

  Future<void> _deleteQuestion(MemoryQuestion question) async {
    await _store.removeQuestion(
      widget.memory.id,
      question.id,
    );
    if (mounted) setState(() {});
  }

  void _message(String text) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(text)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final e = _store.enhancementFor(widget.memory.id);
    final questions = _store.questionsForMemory(
      widget.memory.id,
      enabledOnly: false,
    );
    final related = _memoryStore.memories
        .where((memory) => memory.id != widget.memory.id)
        .toList();
    final image = _imageFor(widget.memory);

    return Scaffold(
      appBar: AppBar(title: const Text('Memory Personalization')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 30),
        children: [
          if (image != null)
            ClipRRect(
              borderRadius: BorderRadius.circular(22),
              child: Image(
                image: image,
                height: 245,
                width: double.infinity,
                fit: BoxFit.cover,
              ),
            ),
          const SizedBox(height: 15),
          Text(
            widget.memory.title,
            style: const TextStyle(
              fontSize: 27,
              fontWeight: FontWeight.bold,
              color: SmritiTheme.primaryDark,
            ),
          ),
          const SizedBox(height: 20),
          const Text(
            'Category and Album',
            style: TextStyle(
              fontSize: 21,
              fontWeight: FontWeight.bold,
              color: SmritiTheme.primaryDark,
            ),
          ),
          const SizedBox(height: 11),
          DropdownButtonFormField<String>(
            initialValue: _category,
            decoration: const InputDecoration(
              labelText: 'Category',
              prefixIcon: Icon(Icons.folder_special_rounded),
              border: OutlineInputBorder(),
            ),
            items: _categories
                .map(
                  (value) => DropdownMenuItem(
                value: value,
                child: Text(value),
              ),
            )
                .toList(),
            onChanged: (value) {
              if (value != null) setState(() => _category = value);
            },
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _albumController,
            decoration: const InputDecoration(
              labelText: 'Album / Story',
              hintText: 'e.g. Goa Family Trip',
              prefixIcon: Icon(Icons.photo_album_rounded),
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 11),
          FilledButton.icon(
            onPressed: _saving ? null : _saveMetadata,
            icon: _saving
                ? const SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
                : const Icon(Icons.save_rounded),
            label: Text(_saving ? 'Saving...' : 'Save Personalization'),
          ),
          const SizedBox(height: 22),
          const Text(
            'Related Memories',
            style: TextStyle(
              fontSize: 21,
              fontWeight: FontWeight.bold,
              color: SmritiTheme.primaryDark,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'Use these connections for memory chains and related-memory questions.',
            style: TextStyle(color: SmritiTheme.textSecondary),
          ),
          const SizedBox(height: 8),
          if (related.isEmpty)
            const Text('Add another memory to create a connection.')
          else
            ...related.map(
                  (memory) => CheckboxListTile(
                value: _relatedIds.contains(memory.id),
                onChanged: (value) {
                  setState(() {
                    if (value == true) {
                      _relatedIds.add(memory.id);
                    } else {
                      _relatedIds.remove(memory.id);
                    }
                  });
                },
                title: Text(memory.title),
                subtitle: Text(
                  memory.location.isEmpty ? 'Memory' : memory.location,
                ),
              ),
            ),
          OutlinedButton.icon(
            onPressed: _saveMetadata,
            icon: const Icon(Icons.link_rounded),
            label: Text('Save ${_relatedIds.length} Connections'),
          ),
          const SizedBox(height: 22),
          const Text(
            'Engagement Data',
            style: TextStyle(
              fontSize: 21,
              fontWeight: FontWeight.bold,
              color: SmritiTheme.primaryDark,
            ),
          ),
          const SizedBox(height: 9),
          _activityBox(e),
          const SizedBox(height: 22),
          Row(
            children: [
              const Expanded(
                child: Text(
                  'Personalized Questions',
                  style: TextStyle(
                    fontSize: 21,
                    fontWeight: FontWeight.bold,
                    color: SmritiTheme.primaryDark,
                  ),
                ),
              ),
              IconButton.filledTonal(
                onPressed: _smartGenerate,
                icon: const Icon(Icons.auto_fix_high_rounded),
              ),
            ],
          ),
          const SizedBox(height: 6),
          const Text(
            'Smart generation is offline and uses only saved memory facts. It does not invent personal details.',
            style: TextStyle(color: SmritiTheme.textSecondary),
          ),
          const SizedBox(height: 11),
          SizedBox(
            width: double.infinity,
            height: 50,
            child: OutlinedButton.icon(
              onPressed: _smartGenerate,
              icon: const Icon(Icons.auto_awesome_rounded),
              label: const Text('Generate Smart Questions'),
            ),
          ),
          const SizedBox(height: 12),
          ...questions.map(
                (question) => Padding(
              padding: const EdgeInsets.only(bottom: 9),
              child: _questionCard(question),
            ),
          ),
          if (questions.isEmpty)
            Container(
              padding: const EdgeInsets.all(15),
              decoration: BoxDecoration(
                color: SmritiTheme.softGreen,
                borderRadius: BorderRadius.circular(18),
              ),
              child: const Text(
                'No custom questions yet. Smart-generate them or add your own.',
              ),
            ),
          const SizedBox(height: 10),
          OutlinedButton.icon(
            onPressed: _addQuestion,
            icon: const Icon(Icons.add_rounded),
            label: const Text('Add Caregiver Question'),
          ),
          const SizedBox(height: 18),
          SizedBox(
            height: 52,
            child: FilledButton.icon(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) =>
                    const RememberTheMomentGame(),
                  ),
                );
              },
              icon: const Icon(Icons.play_arrow_rounded),
              label: const Text('Preview in Remember the Moment'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _activityBox(MemoryEnhancement e) {
    return Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: SmritiTheme.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: SmritiTheme.border),
      ),
      child: Wrap(
        spacing: 9,
        runSpacing: 8,
        children: [
          _data(Icons.visibility_rounded, 'Seen: ${e.timesSeen}'),
          _data(Icons.check_circle_rounded, 'Correct: ${e.correctCount}'),
          _data(Icons.cancel_rounded, 'Incorrect: ${e.incorrectCount}'),
          _data(Icons.help_outline_rounded, "Don't know: ${e.dontKnowCount}"),
          _data(Icons.favorite_rounded, 'Remembered: ${e.rememberedCount}'),
          _data(Icons.question_mark_rounded, 'Not sure: ${e.notSureCount}'),
          _data(Icons.mic_rounded, 'Voice: ${e.voiceRecallCount}'),
          _data(Icons.psychology_rounded, 'Familiarity: ${e.familiarityScore.round()}/100'),
          _data(
            Icons.refresh_rounded,
            e.isDueForReview ? 'Review due' : 'Review scheduled',
          ),
        ],
      ),
    );
  }

  Widget _data(IconData icon, String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
      decoration: BoxDecoration(
        color: SmritiTheme.softGreen,
        borderRadius: BorderRadius.circular(17),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: SmritiTheme.primary),
          const SizedBox(width: 4),
          Text(
            text,
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: SmritiTheme.primaryDark,
            ),
          ),
        ],
      ),
    );
  }

  Widget _questionCard(MemoryQuestion question) {
    return Container(
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: SmritiTheme.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: SmritiTheme.border),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.quiz_rounded, color: SmritiTheme.primary),
          const SizedBox(width: 9),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  question.prompt,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  'Answer: ${question.correctAnswer} · ${question.difficulty}',
                  style: const TextStyle(
                    fontSize: 12,
                    color: SmritiTheme.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: 'Edit',
            onPressed: () => _editQuestion(question),
            icon: const Icon(Icons.edit_outlined),
          ),
          IconButton(
            tooltip: 'Delete',
            onPressed: () => _deleteQuestion(question),
            icon: const Icon(Icons.delete_outline_rounded),
          ),
        ],
      ),
    );
  }
}

class _QuestionDraft {
  final String prompt;
  final List<String> options;
  final int correctIndex;
  final String hint;
  final String difficulty;

  const _QuestionDraft({
    required this.prompt,
    required this.options,
    required this.correctIndex,
    required this.hint,
    required this.difficulty,
  });
}

class _QuestionDialog extends StatefulWidget {
  final MemoryQuestion? initial;

  const _QuestionDialog({this.initial});

  @override
  State<_QuestionDialog> createState() => _QuestionDialogState();
}

class _QuestionDialogState extends State<_QuestionDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _prompt;
  late final TextEditingController _hint;
  late List<TextEditingController> _options;
  late int _correctIndex;
  late String _difficulty;

  @override
  void initState() {
    super.initState();
    final initial = widget.initial;
    _prompt = TextEditingController(text: initial?.prompt ?? '');
    _hint = TextEditingController(text: initial?.hint ?? '');
    _options = (initial?.options ?? ['Option 1', 'Option 2'])
        .map((text) => TextEditingController(text: text))
        .toList();
    _correctIndex = initial == null
        ? 0
        : max(0, initial.options.indexOf(initial.correctAnswer));
    _difficulty = initial?.difficulty ?? 'Easy';
  }

  @override
  void dispose() {
    _prompt.dispose();
    _hint.dispose();
    for (final controller in _options) {
      controller.dispose();
    }
    super.dispose();
  }

  void _addOption() {
    if (_options.length >= 4) return;
    setState(() {
      _options.add(
        TextEditingController(
          text: 'Option ${_options.length + 1}',
        ),
      );
    });
  }

  void _removeOption(int index) {
    if (_options.length <= 2) return;
    _options[index].dispose();
    setState(() {
      _options.removeAt(index);
      if (_correctIndex >= _options.length) {
        _correctIndex = _options.length - 1;
      }
    });
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    final options = _options.map((c) => c.text.trim()).toList();
    if (options.toSet().length != options.length) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Each answer option must be different.'),
        ),
      );
      return;
    }

    Navigator.pop(
      context,
      _QuestionDraft(
        prompt: _prompt.text.trim(),
        options: options,
        correctIndex: _correctIndex,
        hint: _hint.text.trim(),
        difficulty: _difficulty,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.initial == null ? 'Add Question' : 'Edit Question'),
      content: SizedBox(
        width: 460,
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: _prompt,
                  maxLines: 2,
                  decoration: const InputDecoration(
                    labelText: 'Question',
                    border: OutlineInputBorder(),
                  ),
                  validator: (value) =>
                  value == null || value.trim().isEmpty
                      ? 'Enter a question.'
                      : null,
                ),
                const SizedBox(height: 11),
                DropdownButtonFormField<String>(
                  initialValue: _difficulty,
                  decoration: const InputDecoration(
                    labelText: 'Difficulty',
                    border: OutlineInputBorder(),
                  ),
                  items: const [
                    DropdownMenuItem(value: 'Easy', child: Text('Easy')),
                    DropdownMenuItem(
                      value: 'Standard',
                      child: Text('Standard'),
                    ),
                    DropdownMenuItem(
                      value: 'Challenging',
                      child: Text('Challenging'),
                    ),
                  ],
                  onChanged: (value) {
                    if (value != null) setState(() => _difficulty = value);
                  },
                ),
                const SizedBox(height: 11),
                ..._options.asMap().entries.map(
                      (entry) => Padding(
                    padding: const EdgeInsets.only(bottom: 9),
                    child: Row(
                      children: [
                        GestureDetector(
                          onTap: () {
                            setState(() => _correctIndex = entry.key);
                          },
                          child: Icon(
                            _correctIndex == entry.key
                                ? Icons.radio_button_checked_rounded
                                : Icons.radio_button_unchecked_rounded,
                            color: SmritiTheme.primary,
                            size: 24,
                          ),
                        ),
                        Expanded(
                          child: TextFormField(
                            controller: entry.value,
                            decoration: InputDecoration(
                              labelText: 'Option ${entry.key + 1}',
                              border: const OutlineInputBorder(),
                            ),
                            validator: (value) =>
                            value == null || value.trim().isEmpty
                                ? 'Enter an option.'
                                : null,
                          ),
                        ),
                        if (_options.length > 2)
                          IconButton(
                            onPressed: () => _removeOption(entry.key),
                            icon: const Icon(
                              Icons.remove_circle_outline,
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
                TextButton.icon(
                  onPressed: _options.length >= 4 ? null : _addOption,
                  icon: const Icon(Icons.add_rounded),
                  label: const Text('Add Option'),
                ),
                const SizedBox(height: 6),
                TextFormField(
                  controller: _hint,
                  maxLines: 2,
                  decoration: const InputDecoration(
                    labelText: 'Optional hint',
                    border: OutlineInputBorder(),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _submit,
          child: const Text('Save Question'),
        ),
      ],
    );
  }
}
