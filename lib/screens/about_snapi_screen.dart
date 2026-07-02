import 'dart:ui';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart' show Colors;

class AboutSnapiScreen extends StatelessWidget {
  const AboutSnapiScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = CupertinoTheme.of(context).brightness == Brightness.dark;

    return CupertinoPageScaffold(
      backgroundColor: isDark
          ? const Color(0xFF000000)
          : const Color(0xFFF2F2F7),
      navigationBar: CupertinoNavigationBar(
        transitionBetweenRoutes: false,
        middle: const Text('About Snapi'),
        backgroundColor:
            (isDark ? const Color(0xFF000000) : const Color(0xFFF2F2F7))
                .withOpacity(0.8),
        border: null,
      ),
      child: SafeArea(
        child: ListView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 20),
          children: [
            // Header Title
            Text(
              "Snapi",
              style: TextStyle(
                fontSize: 32,
                fontWeight: FontWeight.w900,
                letterSpacing: -1,
                color: isDark ? CupertinoColors.white : CupertinoColors.black,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              "Privacy-First Smart Screenshot Organizer.",
              style: TextStyle(
                fontSize: 15,
                color: CupertinoColors.secondaryLabel.resolveFrom(context),
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 30),

            // WHAT IT DOES Section
            _buildDetailCard(
              context,
              icon: CupertinoIcons.square_stack_3d_up,
              title: "What Snapi Does",
              subtitle: "Automatic cataloging & instant textual search",
              details: [
                "Auto-imports newly captured screenshots seamlessly from your gallery.",
                "Extracts all visible text, numbers, and paragraphs inside screenshots using advanced OCR.",
                "Organizes screenshots into smart, context-aware folders based on their content.",
                "Enables lightning-fast search—simply type any word, phrase, or app name from a screenshot to find it in milliseconds.",
              ],
              isDark: isDark,
            ),
            const SizedBox(height: 24),

            // HOW IT WORKS Section
            _buildDetailCard(
              context,
              icon: CupertinoIcons.gear_alt_fill,
              title: "How It Works",
              subtitle: "Fully automated, battery-optimized, local processing",
              details: [
                "Background Listener: A highly optimized background service monitors your device gallery for new screenshots without draining battery.",
                "On-Device Text Recognition: Using highly accurate on-device machine learning, Snapi parses and extracts text directly on your hardware.",
                "Contextual Auto-Categorization: AI groups your captures into categories like 'Personal', 'Uncategorized', or custom smart folders.",
                "Local Storage: Everything is saved inside a lightweight, lightning-fast local Hive database.",
              ],
              isDark: isDark,
            ),
            const SizedBox(height: 24),

            // OUR MOTIVE Section
            _buildDetailCard(
              context,
              icon: CupertinoIcons.heart_fill,
              title: "Our Motive & Philosophy",
              subtitle: "Why we built Snapi",
              details: [
                "Zero Cloud Policy: We believe your screenshots represent your most private thoughts, messages, and information. We never upload any data, image, or text to any server.",
                "No Internet Needed: Snapi functions completely offline. No tracking, no ads, and no external APIs.",
                "Enhancing Productivity: Saving you hours of scrolling through thousands of photos just to find that one confirmation code, address, or receipt.",
              ],
              isDark: isDark,
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailCard(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String subtitle,
    required List<String> details,
    required bool isDark,
  }) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1C1C1E) : CupertinoColors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: isDark
            ? []
            : [
                BoxShadow(
                  color: CupertinoColors.black.withOpacity(0.04),
                  blurRadius: 16,
                  offset: const Offset(0, 8),
                ),
              ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: CupertinoColors.activeBlue.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: CupertinoColors.activeBlue, size: 24),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: isDark
                            ? CupertinoColors.white
                            : CupertinoColors.black,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 12,
                        color: CupertinoColors.secondaryLabel.resolveFrom(
                          context,
                        ),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          const Divider(
            height: 1,
            thickness: 0.5,
            color: CupertinoColors.separator,
          ),
          const SizedBox(height: 16),
          Column(
            children: details.map((detail) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(top: 5, right: 10),
                      child: Container(
                        width: 6,
                        height: 6,
                        decoration: const BoxDecoration(
                          color: CupertinoColors.activeBlue,
                          shape: BoxShape.circle,
                        ),
                      ),
                    ),
                    Expanded(
                      child: Text(
                        detail,
                        style: TextStyle(
                          fontSize: 14,
                          color: isDark
                              ? const Color(0xFFE5E5EA)
                              : const Color(0xFF3A3A3C),
                          height: 1.4,
                        ),
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }
}

// Simple Divider Helper
class Divider extends StatelessWidget {
  final double height;
  final double thickness;
  final Color color;

  const Divider({
    super.key,
    required this.height,
    required this.thickness,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: height,
      child: Center(
        child: Container(height: thickness, color: color),
      ),
    );
  }
}
