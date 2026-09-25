import 'package:flutter/material.dart';

import '../models/cognitive_game.dart';
import '../theme/smriti_theme.dart';
import 'cognitive_activity_screen.dart';
import 'memory_chain_game.dart';
import 'picture_puzzle_game.dart';
import 'remember_the_moment_game.dart';
import 'smriti_analytics_screen.dart';
import 'what_comes_next_game.dart';
import 'who_is_this_game.dart';

class GamesScreen extends StatelessWidget {
  const GamesScreen({super.key});

  static const List<CognitiveGame> games = [
    CognitiveGame(
      id: 'game_001',
      title: 'Who Is This?',
      description: 'Recognize someone from your family.',
      category: 'Recognition',
      difficulty: 'Adaptive',
      icon: 'family',
    ),
    CognitiveGame(
      id: 'game_002',
      title: 'Remember the Moment',
      description:
      'Explore your own memories through photos, questions, voice and personalized activities.',
      category: 'Memory',
      difficulty: 'Adaptive',
      icon: 'memory',
    ),
    CognitiveGame(
      id: 'game_003',
      title: 'What Comes Next?',
      description:
      'Choose the next moment in a familiar memory sequence.',
      category: 'Sequence',
      difficulty: 'Adaptive',
      icon: 'sequence',
    ),
    CognitiveGame(
      id: 'game_004',
      title: 'Picture Puzzle',
      description:
      'Rebuild a real memory photo by arranging its pieces.',
      category: 'Visual',
      difficulty: 'Adaptive',
      icon: 'puzzle',
    ),
    CognitiveGame(
      id: 'game_005',
      title: 'Memory Chain',
      description:
      'Put connected memories into the order they happened.',
      category: 'Timeline',
      difficulty: 'Adaptive',
      icon: 'chain',
    ),
  ];

  void _openGame(
      BuildContext context,
      CognitiveGame game,
      ) {
    switch (game.id) {
      case 'game_001':
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => const WhoIsThisGame(),
          ),
        );
        break;

      case 'game_002':
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => RememberTheMomentGame(
              game: game,
            ),
          ),
        );
        break;

      case 'game_003':
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => const WhatComesNextGame(),
          ),
        );
        break;

      case 'game_004':
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => const PicturePuzzleGame(),
          ),
        );
        break;

      case 'game_005':
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => const MemoryChainGame(),
          ),
        );
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Let's Play"),
        actions: [
          IconButton(
            tooltip: 'Cognitive Activity',
            icon: const Icon(
              Icons.insights_rounded,
            ),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) =>
                  const CognitiveActivityScreen(),
                ),
              );
            },
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
              'Let’s have some fun ❤️',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: SmritiTheme.primaryDark,
              ),
            ),

            const SizedBox(height: 8),

            const Text(
              'Choose something you would like to play.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 16,
                color: SmritiTheme.textSecondary,
              ),
            ),

            const SizedBox(height: 25),

            ...games.map(
                  (game) => Padding(
                padding: const EdgeInsets.only(
                  bottom: 15,
                ),
                child: GameCard(
                  game: game,
                  onOpen: () => _openGame(
                    context,
                    game,
                  ),
                ),
              ),
            ),

            const SizedBox(height: 4),

            SizedBox(
              width: double.infinity,
              height: 54,
              child: OutlinedButton.icon(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) =>
                      const SmritiAnalyticsScreen(),
                    ),
                  );
                },
                icon: const Icon(
                  Icons.insights_rounded,
                ),
                label: const Text(
                  'Analytics & Insights',
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w600,
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

class GameCard extends StatelessWidget {
  final CognitiveGame game;
  final VoidCallback onOpen;

  const GameCard({
    super.key,
    required this.game,
    required this.onOpen,
  });

  IconData _icon() {
    switch (game.icon) {
      case 'family':
        return Icons.family_restroom_rounded;

      case 'memory':
        return Icons.photo_library_rounded;

      case 'sequence':
        return Icons.format_list_numbered_rounded;

      case 'puzzle':
        return Icons.extension_rounded;

      case 'chain':
        return Icons.timeline_rounded;

      default:
        return Icons.extension_rounded;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: SmritiTheme.surface,
      borderRadius: BorderRadius.circular(24),
      child: InkWell(
        borderRadius: BorderRadius.circular(24),
        onTap: onOpen,
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: SmritiTheme.border,
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  color: SmritiTheme.softGreen,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Icon(
                  _icon(),
                  size: 34,
                  color: SmritiTheme.primary,
                ),
              ),

              const SizedBox(width: 16),

              Expanded(
                child: Column(
                  crossAxisAlignment:
                  CrossAxisAlignment.start,
                  children: [
                    Text(
                      game.title,
                      style: const TextStyle(
                        fontSize: 21,
                        fontWeight: FontWeight.bold,
                        color: SmritiTheme.textPrimary,
                      ),
                    ),

                    const SizedBox(height: 5),

                    Text(
                      game.description,
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 15,
                        height: 1.3,
                        color: SmritiTheme.textSecondary,
                      ),
                    ),

                    const SizedBox(height: 10),

                    Wrap(
                      spacing: 8,
                      runSpacing: 6,
                      children: [
                        _Tag(
                          text: game.category,
                        ),
                        _Tag(
                          text: game.difficulty,
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              const SizedBox(width: 8),

              const Icon(
                Icons.arrow_forward_ios_rounded,
                size: 18,
                color: SmritiTheme.primary,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Tag extends StatelessWidget {
  final String text;

  const _Tag({
    required this.text,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 10,
        vertical: 5,
      ),
      decoration: BoxDecoration(
        color: SmritiTheme.softGreen,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: SmritiTheme.primaryDark,
        ),
      ),
    );
  }
}