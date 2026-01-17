import 'package:flutter/material.dart';
import 'game_screen.dart';

class HelpScreen extends StatefulWidget {
  final bool isFirstLaunch;

  const HelpScreen({super.key, this.isFirstLaunch = false});

  @override
  State<HelpScreen> createState() => _HelpScreenState();
}

class _HelpScreenState extends State<HelpScreen> {
  bool isPolish = true;

  final Map<String, String> plContent = {
    'title': 'Witaj w Queens!',
    'title_help': 'Jak grać?',
    'goal_header': 'Cel gry:',
    'goal_desc':
        'Musisz umieścić dokładnie jedną Królową (Gwiazdkę) w każdym wierszu, kolumnie i kolorowej strefie.',
    'rule1_title': '1. Wiersze i Kolumny',
    'rule1_desc':
        'W każdym rzędzie i w każdej kolumnie może znajdować się tylko JEDNA Królowa.',
    'rule2_title': '2. Kolorowe Strefy',
    'rule2_desc':
        'Każdy kolorowy obszar na planszy musi zawierać dokładnie JEDNĄ Królową.',
    'rule3_title': '3. Brak Sąsiadów',
    'rule3_desc':
        'Królowe nie mogą się stykać, nawet rogami (na ukos). Każda Królowa musi mieć wokół siebie wolną przestrzeń.',
    'controls_title': 'Sterowanie',
    'controls_desc':
        '• Kliknij raz: X (puste)\n• Kliknij dwa razy: Królowa (Gwiazdka)\n• Kliknij trzy razy: Wyczyść pole',
    'tip': 'Gra automatycznie zaznaczy na czerwono błędy.',
    'switch_btn': 'English',
    'play_btn': 'GRAJ',
  };

  final Map<String, String> enContent = {
    'title': 'Welcome to Queens!',
    'title_help': 'How to play?',
    'goal_header': 'Goal:',
    'goal_desc':
        'You must place exactly one Queen (Star) in every row, column, and colored region.',
    'rule1_title': '1. Rows & Columns',
    'rule1_desc': 'Each row and each column must contain exactly ONE Queen.',
    'rule2_title': '2. Colored Zones',
    'rule2_desc':
        'Each colored area on the board must contain exactly ONE Queen.',
    'rule3_title': '3. No Touching',
    'rule3_desc': 'Queens cannot touch each other, not even diagonally.',
    'controls_title': 'Controls',
    'controls_desc':
        '• 1st Tap: X (mark as empty)\n• 2nd Tap: Queen (Star)\n• 3rd Tap: Clear cell',
    'tip': 'The game automatically highlights errors in red.',
    'switch_btn': 'Polski',
    'play_btn': 'PLAY',
  };

  @override
  Widget build(BuildContext context) {
    final content = isPolish ? plContent : enContent;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Text(
          widget.isFirstLaunch ? content['title']! : content['title_help']!,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
        backgroundColor: Colors.white,
        elevation: 0,
        leading: widget.isFirstLaunch
            ? null
            : IconButton(
                icon: const Icon(Icons.close, color: Colors.black),
                onPressed: () => Navigator.of(context).pop(),
              ),
        actions: [
          TextButton(
            onPressed: () => setState(() => isPolish = !isPolish),
            child: Text(
              content['switch_btn']!,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Colors.blueAccent,
              ),
            ),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    content['goal_header']!,
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    content['goal_desc']!,
                    style: const TextStyle(fontSize: 16, height: 1.5),
                  ),
                  const SizedBox(height: 30),
                  _buildRule(
                    icon: Icons.table_rows,
                    title: content['rule1_title']!,
                    description: content['rule1_desc']!,
                  ),
                  _buildRule(
                    icon: Icons.palette,
                    title: content['rule2_title']!,
                    description: content['rule2_desc']!,
                  ),
                  _buildRule(
                    icon: Icons.do_not_touch,
                    title: content['rule3_title']!,
                    description: content['rule3_desc']!,
                  ),
                  _buildRule(
                    icon: Icons.touch_app,
                    title: content['controls_title']!,
                    description: content['controls_desc']!,
                  ),

                  const SizedBox(height: 20),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.green[50],
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.green, width: 1),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.lightbulb, color: Colors.green),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            content['tip']!,
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 80),
                ],
              ),
            ),
          ),

          // --- PRZYCISK GRAJ (Tylko przy starcie) ---
          if (widget.isFirstLaunch)
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black12,
                    blurRadius: 10,
                    offset: const Offset(0, -5),
                  ),
                ],
              ),
              child: SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blueAccent,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  onPressed: () {
                    Navigator.pushReplacement(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const GameScreen(),
                      ),
                    );
                  },
                  child: Text(
                    content['play_btn']!,
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildRule({
    required IconData icon,
    required String title,
    required String description,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 24.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.grey[100],
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, size: 30, color: Colors.blueAccent),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  description,
                  style: TextStyle(
                    fontSize: 15,
                    color: Colors.grey[700],
                    height: 1.4,
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
