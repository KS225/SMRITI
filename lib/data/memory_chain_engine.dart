import 'dart:math';

import '../models/memory.dart';
import '../models/memory_chain.dart';
import 'memory_enhancement_store.dart';
import 'memory_store.dart';
import 'memory_chain_store.dart';

class MemoryChainQuestion {
  final MemoryChain chain;
  final List<String> orderedMemoryIds;

  const MemoryChainQuestion({
    required this.chain,
    required this.orderedMemoryIds,
  });

  String get answerMemoryId => orderedMemoryIds.last;
}

class MemoryChainEngine {
  final MemoryStore memoryStore;
  final MemoryEnhancementStore enhancementStore;
  final MemoryChainStore chainStore;

  const MemoryChainEngine({
    required this.memoryStore,
    required this.enhancementStore,
    required this.chainStore,
  });

  List<MemoryChain> buildAvailableChains() {
    final memoriesById = {
      for (final memory in memoryStore.memories) memory.id: memory,
    };

    final result = <MemoryChain>[];
    final signatures = <String>{};

    void addChain({
      required String id,
      required String title,
      required String description,
      required List<String> memoryIds,
      String category = 'Life Story',
    }) {
      final cleaned = memoryIds
          .where(memoriesById.containsKey)
          .toList(growable: false);
      if (cleaned.length < 3) return;

      final signature = cleaned.join('|');
      if (!signatures.add(signature)) return;

      result.add(
        MemoryChain(
          id: id,
          title: title,
          description: description,
          memoryIds: cleaned,
          category: category,
        ),
      );
    }

    // 1. Caregiver-created chains are always preferred.
    for (final chain in chainStore.chains) {
      addChain(
        id: chain.id,
        title: chain.title,
        description: chain.description,
        memoryIds: chain.memoryIds,
        category: chain.category,
      );
    }

    // 2. Album-based automatic chains.
    final albums = <String, List<Memory>>{};
    for (final memory in memoryStore.memories) {
      final album = enhancementStore.enhancementFor(memory.id).album.trim();
      if (album.isEmpty) continue;
      albums.putIfAbsent(album, () => []).add(memory);
    }

    for (final entry in albums.entries) {
      final ordered = _sortMemories(entry.value);
      addChain(
        id: 'auto_album_${entry.key.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), '_')}',
        title: entry.key,
        description: 'A sequence built from this memory album.',
        memoryIds: ordered.map((memory) => memory.id).toList(),
        category: 'Album',
      );
    }

    // 3. Related-memory chains.
    final visitedPairs = <String>{};
    for (final memory in memoryStore.memories) {
      final ids = <String>{memory.id};
      ids.addAll(
        enhancementStore
            .enhancementFor(memory.id)
            .relatedMemoryIds
            .where(memoriesById.containsKey),
      );
      if (ids.length < 3) continue;

      final ordered = _sortMemories(
        ids.map((id) => memoriesById[id]!).toList(),
      );
      final signature = ordered.map((item) => item.id).join('|');
      if (!visitedPairs.add(signature)) continue;

      addChain(
        id: 'auto_related_${memory.id}',
        title: 'Connected Memories',
        description: 'Memories you connected together in Memory Studio.',
        memoryIds: ordered.map((item) => item.id).toList(),
        category: 'Related',
      );
    }

    // 4. Category chains provide a useful fallback when a caregiver has
    // not yet created albums or explicit relationships.
    final categories = <String, List<Memory>>{};
    for (final memory in memoryStore.memories) {
      final category = enhancementStore.enhancementFor(memory.id).category;
      categories.putIfAbsent(category, () => []).add(memory);
    }

    for (final entry in categories.entries) {
      final ordered = _sortMemories(entry.value);
      addChain(
        id: 'auto_category_${entry.key.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), '_')}',
        title: '${entry.key} Memories',
        description: 'A simple sequence from your ${entry.key.toLowerCase()} memories.',
        memoryIds: ordered.map((memory) => memory.id).toList(),
        category: entry.key,
      );
    }

    // 5. Final fallback: chronological life story.
    final chronological = _sortMemories(memoryStore.memories);
    addChain(
      id: 'auto_life_story',
      title: 'Life Story',
      description: 'A chronological sequence of your saved memories.',
      memoryIds: chronological.map((memory) => memory.id).toList(),
      category: 'Timeline',
    );

    return result;
  }

  List<MemoryChainQuestion> buildQuestions({
    int limit = 8,
    Random? random,
  }) {
    final rng = random ?? Random();
    final questions = <MemoryChainQuestion>[];

    for (final chain in buildAvailableChains()) {
      if (chain.memoryIds.length < 3) continue;

      for (var start = 0; start <= chain.memoryIds.length - 3; start++) {
        final sequence = chain.memoryIds.sublist(start, start + 3);
        questions.add(
          MemoryChainQuestion(
            chain: chain,
            orderedMemoryIds: List<String>.from(sequence),
          ),
        );
      }
    }

    questions.shuffle(rng);

    final seenAnswers = <String>{};
    final result = <MemoryChainQuestion>[];
    for (final question in questions) {
      if (!seenAnswers.add('${question.chain.id}:${question.answerMemoryId}')) {
        continue;
      }
      result.add(question);
      if (result.length >= limit) break;
    }

    return result;
  }

  List<Memory> _sortMemories(Iterable<Memory> input) {
    final list = List<Memory>.from(input);
    list.sort((a, b) {
      final aDate = DateTime.tryParse(a.date);
      final bDate = DateTime.tryParse(b.date);
      if (aDate != null && bDate != null) return aDate.compareTo(bDate);
      if (aDate != null) return -1;
      if (bDate != null) return 1;
      return a.title.toLowerCase().compareTo(b.title.toLowerCase());
    });
    return list;
  }
}
