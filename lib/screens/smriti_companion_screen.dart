import 'package:flutter/material.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:google_mlkit_language_id/google_mlkit_language_id.dart';
import 'package:speech_to_text/speech_to_text.dart';

import '../data/family_store.dart';
import '../data/memory_store.dart';
import '../models/family_member.dart';
import '../models/memory.dart';
import '../theme/smriti_theme.dart';
import 'find_my_phone_screen.dart';
import 'help_screen.dart';

class SmritiCompanionScreen extends StatefulWidget {
  const SmritiCompanionScreen({super.key});

  @override
  State<SmritiCompanionScreen> createState() =>
      _SmritiCompanionScreenState();
}

class _SmritiCompanionScreenState
    extends State<SmritiCompanionScreen> {
  final FamilyStore _familyStore = FamilyStore.instance;
  final MemoryStore _memoryStore = MemoryStore.instance;

  final SpeechToText _speech = SpeechToText();
  final FlutterTts _tts = FlutterTts();
  final LanguageIdentifier _languageIdentifier =
  LanguageIdentifier(confidenceThreshold: 0.5);

  final TextEditingController _controller =
  TextEditingController();

  final List<_ChatMessage> _messages = [];

  bool _loading = true;
  bool _isListening = false;
  bool _isSpeaking = false;

  String _languageCode = 'en';
  String _speechLocale = 'en-IN';

  @override
  void initState() {
    super.initState();
    _initialize();
  }

  Future<void> _initialize() async {
    await Future.wait([
      _familyStore.initialize(),
      _memoryStore.initialize(),
    ]);

    await _tts.setLanguage('en-IN');
    await _tts.setSpeechRate(0.45);
    await _tts.setPitch(1.0);

    if (!mounted) return;

    setState(() {
      _loading = false;
      _messages.add(
        const _ChatMessage(
          text:
          'Hello ❤️ I am SMRITI. You can ask me about your family, memories, the time, or ask me for help.',
          isUser: false,
        ),
      );
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    _tts.stop();
    _speech.stop();
    _languageIdentifier.close();
    super.dispose();
  }

  Future<void> _sendTypedMessage() async {
    final text = _controller.text.trim();

    if (text.isEmpty || _loading) {
      return;
    }

    _controller.clear();

    await _processUserMessage(text);
  }

  Future<void> _startListening() async {
    if (_isListening) {
      await _speech.stop();

      if (mounted) {
        setState(() {
          _isListening = false;
        });
      }

      return;
    }

    final available = await _speech.initialize(
      onStatus: (status) {
        if (!mounted) return;

        if (status == 'done' ||
            status == 'notListening') {
          setState(() {
            _isListening = false;
          });
        }
      },
      onError: (_) {
        if (!mounted) return;

        setState(() {
          _isListening = false;
        });
      },
    );

    if (!available || !mounted) {
      return;
    }

    setState(() {
      _isListening = true;
    });

    await _speech.listen(
      onResult: (result) {
        if (!mounted) return;

        final text = result.recognizedWords;

        if (text.isNotEmpty) {
          _controller.text = text;
          _controller.selection =
              TextSelection.fromPosition(
                TextPosition(
                  offset: _controller.text.length,
                ),
              );
        }

        if (result.finalResult) {
          setState(() {
            _isListening = false;
          });
        }
      },
      listenOptions: SpeechListenOptions(
        localeId: _speechLocale,
        partialResults: true,
        listenMode: ListenMode.confirmation,
      ),
    );
  }

  Future<void> _processUserMessage(String text) async {
    setState(() {
      _messages.add(
        _ChatMessage(
          text: text,
          isUser: true,
        ),
      );
    });

    final detected = await _detectLanguage(text);

    final response = _generateResponse(text);

    if (!mounted) return;

    setState(() {
      _messages.add(
        _ChatMessage(
          text: response,
          isUser: false,
        ),
      );
    });

    await _speakResponse(
      response,
      language: detected,
    );
  }

  Future<String> _detectLanguage(String text) async {
    try {
      final detected =
      await _languageIdentifier.identifyLanguage(text);

      if (detected == 'hi') {
        _languageCode = 'hi';
        _speechLocale = 'hi-IN';

        await _tts.setLanguage('hi-IN');
      } else if (detected == 'mr') {
        _languageCode = 'mr';
        _speechLocale = 'mr-IN';

        await _tts.setLanguage('mr-IN');
      } else {
        _languageCode = 'en';
        _speechLocale = 'en-IN';

        await _tts.setLanguage('en-IN');
      }

      return _languageCode;
    } catch (_) {
      _languageCode = 'en';
      _speechLocale = 'en-IN';

      await _tts.setLanguage('en-IN');

      return 'en';
    }
  }

  Future<void> _speakResponse(
      String text, {
        required String language,
      }) async {
    if (_isSpeaking) {
      await _tts.stop();
    }

    if (!mounted) return;

    setState(() {
      _isSpeaking = true;
    });

    try {
      if (language == 'hi') {
        await _tts.setLanguage('hi-IN');
      } else if (language == 'mr') {
        await _tts.setLanguage('mr-IN');
      } else {
        await _tts.setLanguage('en-IN');
      }

      await _tts.speak(text);
    } catch (_) {
      // Text response remains available even if TTS fails.
    }

    if (!mounted) return;

    setState(() {
      _isSpeaking = false;
    });
  }

  String _generateResponse(String input) {
    final text = input.trim().toLowerCase();

    if (_containsAny(text, [
      'hello',
      'hi',
      'hey',
      'namaste',
      'good morning',
      'good afternoon',
      'good evening',
    ])) {
      return _greetingResponse();
    }

    if (_containsAny(text, [
      'what time',
      'current time',
      'time is it',
      'time now',
    ])) {
      return _timeResponse();
    }

    if (_containsAny(text, [
      'what day',
      'which day',
      'today',
      'date today',
    ])) {
      return _dateResponse();
    }

    if (_containsAny(text, [
      'where am i',
      'where are we',
      'where is this',
      'what is this place',
    ])) {
      return _orientationResponse();
    }

    if (_containsAny(text, [
      'my family',
      'family members',
      'who is in my family',
      'who are my family',
      'people in my family',
    ])) {
      return _familyListResponse();
    }

    if (_containsAny(text, [
      'my memories',
      'show my memories',
      'tell me about my memories',
      'what memories do i have',
    ])) {
      return _memoryListResponse();
    }

    if (_containsAny(text, [
      'caregiver',
      'need help',
      'i need help',
      'help me',
      'call my caregiver',
    ])) {
      return _caregiverResponse();
    }

    if (_containsAny(text, [
      'find my phone',
      'where is my phone',
      'phone missing',
      'lost my phone',
      'ring my phone',
    ])) {
      return _phoneResponse();
    }

    if (_containsAny(text, [
      'medicine',
      'medication',
      'tablet',
      'dose',
      'diagnose',
      'disease',
      'medical',
    ])) {
      return _medicalSafetyResponse();
    }

    final familyResponse =
    _findFamilyResponse(text);

    if (familyResponse != null) {
      return familyResponse;
    }

    final memoryResponse =
    _findMemoryResponse(text);

    if (memoryResponse != null) {
      return memoryResponse;
    }

    if (_containsAny(text, [
      'thank you',
      'thanks',
      'thank',
    ])) {
      return _languageCode == 'hi'
          ? 'आपका स्वागत है ❤️ मैं हमेशा आपकी मदद करने की कोशिश करूंगी.'
          : _languageCode == 'mr'
          ? 'तुमचे स्वागत आहे ❤️ मी तुमची मदत करण्याचा प्रयत्न करेन.'
          : 'You are very welcome ❤️ I am happy to help.';
    }

    return _fallbackResponse();
  }

  String _greetingResponse() {
    if (_languageCode == 'hi') {
      return 'नमस्ते ❤️ मैं SMRITI हूँ। आज मैं आपकी मदद करने के लिए यहाँ हूँ.';
    }

    if (_languageCode == 'mr') {
      return 'नमस्कार ❤️ मी SMRITI आहे. आज मी तुमची मदत करण्यासाठी इथे आहे.';
    }

    return 'Hello ❤️ I am SMRITI. I am here to help you.';
  }

  String _timeResponse() {
    final now = DateTime.now();

    final hour = now.hour == 0
        ? 12
        : now.hour > 12
        ? now.hour - 12
        : now.hour;

    final minute =
    now.minute.toString().padLeft(2, '0');

    final period = now.hour >= 12 ? 'PM' : 'AM';

    final value = '$hour:$minute $period';

    if (_languageCode == 'hi') {
      return 'अभी समय $value है.';
    }

    if (_languageCode == 'mr') {
      return 'आत्ता वेळ $value आहे.';
    }

    return 'The current time is $value.';
  }

  String _dateResponse() {
    final now = DateTime.now();

    const days = [
      'Monday',
      'Tuesday',
      'Wednesday',
      'Thursday',
      'Friday',
      'Saturday',
      'Sunday',
    ];

    const months = [
      'January',
      'February',
      'March',
      'April',
      'May',
      'June',
      'July',
      'August',
      'September',
      'October',
      'November',
      'December',
    ];

    final value =
        '${days[now.weekday - 1]}, '
        '${now.day} ${months[now.month - 1]} '
        '${now.year}';

    if (_languageCode == 'hi') {
      return 'आज $value है.';
    }

    if (_languageCode == 'mr') {
      return 'आज $value आहे.';
    }

    return 'Today is $value.';
  }

  String _orientationResponse() {
    if (_languageCode == 'hi') {
      return 'आप SMRITI के साथ अपने परिचित स्थान, यानी घर पर हैं. ❤️';
    }

    if (_languageCode == 'mr') {
      return 'तुम्ही SMRITI सोबत तुमच्या परिचित ठिकाणी, म्हणजे घरी आहात. ❤️';
    }

    return 'You are with SMRITI in your familiar place, at home. ❤️';
  }

  String _familyListResponse() {
    final members = _familyStore.members;

    if (members.isEmpty) {
      return 'No family members have been added yet. A caregiver can add them from Family Management.';
    }

    final names = members
        .map(_familyMemberDisplayName)
        .join(', ');

    return 'The people in your family are: $names.';
  }

  String _memoryListResponse() {
    final memories = _memoryStore.memories;

    if (memories.isEmpty) {
      return 'You do not have any saved memories yet. A caregiver can add memories for you.';
    }

    final visibleMemories =
    memories.take(5).toList();

    final names = visibleMemories
        .map((memory) => memory.title)
        .join(', ');

    if (memories.length > 5) {
      return 'You have ${memories.length} saved memories. Some of them are: $names.';
    }

    return 'Your saved memories include: $names.';
  }

  String _caregiverResponse() {
    if (_languageCode == 'hi') {
      return 'मैं आपको आपके caregiver से संपर्क करने में मदद कर सकती हूँ.';
    }

    if (_languageCode == 'mr') {
      return 'मी तुम्हाला तुमच्या caregiver शी संपर्क करण्यास मदत करू शकते.';
    }

    return 'I can help you contact your caregiver.';
  }

  String _phoneResponse() {
    if (_languageCode == 'hi') {
      return 'मैं आपके फोन को ढूंढने में मदद कर सकती हूँ. नीचे Find My Phone खोलें.';
    }

    if (_languageCode == 'mr') {
      return 'मी तुमचा फोन शोधण्यास मदत करू शकते. खाली Find My Phone उघडा.';
    }

    return 'I can help you find your phone. Use the Find My Phone button below.';
  }

  String _medicalSafetyResponse() {
    if (_languageCode == 'hi') {
      return 'मैं सामान्य जानकारी दे सकती हूँ, लेकिन दवा बदलने या चिकित्सकीय निर्णय लेने के लिए आपके caregiver या healthcare professional से बात करना बेहतर है.';
    }

    if (_languageCode == 'mr') {
      return 'मी सामान्य माहिती देऊ शकते, पण औषध बदलणे किंवा वैद्यकीय निर्णय घेण्यासाठी caregiver किंवा healthcare professional शी बोलणे योग्य आहे.';
    }

    return 'I can provide general information, but medication changes and medical decisions should be discussed with your caregiver or healthcare professional.';
  }

  String? _findFamilyResponse(String text) {
    final members = _familyStore.members;

    for (final member in members) {
      final name = member.name.trim().toLowerCase();

      if (name.isEmpty) {
        continue;
      }

      if (text.contains(name)) {
        final relationship =
        member.relationship.trim();

        final memoryNote =
        member.memoryNote?.trim();

        if (memoryNote != null &&
            memoryNote.isNotEmpty) {
          return '${member.name} is your $relationship. '
              '${memoryNote.trim()}';
        }

        return '${member.name} is your $relationship.';
      }
    }

    return null;
  }

  String? _findMemoryResponse(String text) {
    final memories = _memoryStore.memories;

    for (final memory in memories) {
      final searchable = [
        memory.title,
        memory.description,
        memory.location,
        ...memory.people,
        ...memory.tags,
      ].join(' ').toLowerCase();

      final words = text
          .split(RegExp(r'[^a-zA-Z0-9]+'))
          .where((word) => word.trim().length >= 3)
          .toList();

      final matched = words.any(
        searchable.contains,
      );

      if (!matched) {
        continue;
      }

      final location = memory.location.trim();

      if (location.isNotEmpty) {
        return 'I remember "${memory.title}". '
            '${memory.description} '
            'It is connected with $location.';
      }

      return 'I remember "${memory.title}". '
          '${memory.description}';
    }

    return null;
  }

  String _fallbackResponse() {
    if (_languageCode == 'hi') {
      return 'मैं आपकी मदद कर सकती हूँ. आप मुझसे परिवार, यादों, समय, जगह, caregiver या फोन के बारे में पूछ सकते हैं.';
    }

    if (_languageCode == 'mr') {
      return 'मी तुमची मदत करू शकते. तुम्ही मला कुटुंब, आठवणी, वेळ, ठिकाण, caregiver किंवा फोनबद्दल विचारू शकता.';
    }

    return 'I can help with your family, memories, time, orientation, caregiver support, or finding your phone.';
  }

  bool _containsAny(
      String text,
      List<String> phrases,
      ) {
    for (final phrase in phrases) {
      if (text.contains(phrase)) {
        return true;
      }
    }

    return false;
  }

  String _familyMemberDisplayName(
      FamilyMember member,
      ) {
    final relationship =
    member.relationship.trim();

    if (relationship.isEmpty) {
      return member.name;
    }

    return '${member.name} (${member.relationship})';
  }

  Future<void> _stopSpeaking() async {
    await _tts.stop();

    if (!mounted) return;

    setState(() {
      _isSpeaking = false;
    });
  }

  Future<void> _openHelp() async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const HelpScreen(),
      ),
    );
  }

  Future<void> _openFindPhone() async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) =>
        const FindMyPhoneScreen(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Talk to SMRITI'),
        ),
        body: const Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Talk to SMRITI'),
        actions: [
          if (_isSpeaking)
            IconButton(
              tooltip: 'Stop speaking',
              onPressed: _stopSpeaking,
              icon: const Icon(
                Icons.stop_circle_outlined,
              ),
            ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: ListView.builder(
                padding:
                const EdgeInsets.fromLTRB(
                  16,
                  18,
                  16,
                  18,
                ),
                itemCount: _messages.length,
                itemBuilder: (context, index) {
                  return _buildMessage(
                    _messages[index],
                  );
                },
              ),
            ),

            _buildQuickActions(),

            _buildComposer(),
          ],
        ),
      ),
    );
  }

  Widget _buildMessage(
      _ChatMessage message,
      ) {
    final alignment = message.isUser
        ? Alignment.centerRight
        : Alignment.centerLeft;

    final color = message.isUser
        ? SmritiTheme.primary
        : SmritiTheme.softGreen;

    final textColor = message.isUser
        ? Colors.white
        : SmritiTheme.textPrimary;

    return Align(
      alignment: alignment,
      child: Container(
        constraints:
        const BoxConstraints(maxWidth: 330),
        margin: const EdgeInsets.only(
          bottom: 12,
        ),
        padding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 13,
        ),
        decoration: BoxDecoration(
          color: color,
          borderRadius:
          BorderRadius.circular(20),
          border: message.isUser
              ? null
              : Border.all(
            color: SmritiTheme.border,
          ),
        ),
        child: Text(
          message.text,
          style: TextStyle(
            fontSize: 15,
            height: 1.4,
            color: textColor,
          ),
        ),
      ),
    );
  }

  Widget _buildQuickActions() {
    return SizedBox(
      height: 54,
      child: ListView(
        padding:
        const EdgeInsets.symmetric(
          horizontal: 14,
        ),
        scrollDirection: Axis.horizontal,
        children: [
          _quickAction(
            icon: Icons.people_alt_rounded,
            text: 'My Family',
            prompt: 'Who is in my family?',
          ),
          _quickAction(
            icon: Icons.favorite_rounded,
            text: 'My Memories',
            prompt: 'Tell me about my memories',
          ),
          _quickAction(
            icon: Icons.access_time_rounded,
            text: 'Time',
            prompt: 'What time is it?',
          ),
          _quickAction(
            icon: Icons.help_rounded,
            text: 'Help',
            prompt: 'I need help',
          ),
          _quickAction(
            icon:
            Icons.phone_android_rounded,
            text: 'Find Phone',
            prompt: 'Find my phone',
          ),
        ],
      ),
    );
  }

  Widget _quickAction({
    required IconData icon,
    required String text,
    required String prompt,
  }) {
    return Padding(
      padding:
      const EdgeInsets.only(right: 8),
      child: ActionChip(
        avatar: Icon(
          icon,
          size: 18,
          color: SmritiTheme.primary,
        ),
        label: Text(text),
        onPressed: () async {
          if (prompt == 'I need help') {
            await _openHelp();
            return;
          }

          if (prompt == 'Find my phone') {
            await _openFindPhone();
            return;
          }

          await _processUserMessage(prompt);
        },
      ),
    );
  }

  Widget _buildComposer() {
    return Container(
      padding: const EdgeInsets.fromLTRB(
        12,
        10,
        12,
        12,
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(
          top: BorderSide(
            color: SmritiTheme.border,
          ),
        ),
      ),
      child: Row(
        crossAxisAlignment:
        CrossAxisAlignment.end,
        children: [
          IconButton(
            tooltip: _isListening
                ? 'Stop listening'
                : 'Speak',
            onPressed: _startListening,
            icon: Icon(
              _isListening
                  ? Icons.stop_rounded
                  : Icons.mic_rounded,
              color: _isListening
                  ? SmritiTheme.primaryDark
                  : SmritiTheme.primary,
            ),
          ),

          Expanded(
            child: TextField(
              controller: _controller,
              minLines: 1,
              maxLines: 4,
              textInputAction:
              TextInputAction.send,
              onSubmitted: (_) =>
                  _sendTypedMessage(),
              decoration: InputDecoration(
                hintText:
                'Talk or type to SMRITI...',
                filled: true,
                fillColor:
                SmritiTheme.softGreen,
                border: OutlineInputBorder(
                  borderRadius:
                  BorderRadius.circular(20),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),

          const SizedBox(width: 8),

          IconButton(
            tooltip: 'Send',
            onPressed: _sendTypedMessage,
            icon: const Icon(
              Icons.send_rounded,
              color: SmritiTheme.primary,
            ),
          ),
        ],
      ),
    );
  }
}

class _ChatMessage {
  final String text;
  final bool isUser;

  const _ChatMessage({
    required this.text,
    required this.isUser,
  });
}