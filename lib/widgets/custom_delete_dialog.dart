import 'dart:ui';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

void showCustomDeleteDialog({
  required BuildContext context,
  required String title,
  required String subtitle,
  required String deleteButtonText,
  required VoidCallback onDelete,
}) {
  showGeneralDialog(
    context: context,
    barrierDismissible: true,
    barrierLabel: '',
    barrierColor: CupertinoColors.black.withOpacity(0.55),
    transitionDuration: const Duration(milliseconds: 280),
    pageBuilder: (context, anim1, anim2) => const SizedBox.shrink(),
    transitionBuilder: (context, anim1, anim2, child) {
      final curveValue = Curves.easeOutBack.transform(anim1.value);
      final isDark = CupertinoTheme.of(context).brightness == Brightness.dark;
      
      return Transform.scale(
        scale: curveValue,
        child: Opacity(
          opacity: anim1.value.clamp(0.0, 1.0),
          child: Center(
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 24),
              padding: const EdgeInsets.only(top: 18, bottom: 14, left: 16, right: 16),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1C1C1E) : CupertinoColors.white,
                borderRadius: BorderRadius.circular(28),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(isDark ? 0.45 : 0.12),
                    blurRadius: 36,
                    offset: const Offset(0, 16),
                  ),
                ],
              ),
              child: Material(
                color: Colors.transparent,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: 21,
                        fontWeight: FontWeight.w400,
                        color: isDark ? CupertinoColors.white : const Color(0xFF1F1F1F),
                        letterSpacing: -0.5,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 6),
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.center,
                      child: Text(
                        subtitle,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w400,
                          color: isDark ? CupertinoColors.systemGrey2 : const Color(0xFF4E4E4E),
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),
                    // Grouped Action Buttons (Matching the stacked grouped rounded rectangle style)
                    Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Delete Button (Top Rounded)
                        GestureDetector(
                          onTap: () {
                            Navigator.pop(context);
                            onDelete();
                          },
                          child: Container(
                            width: double.infinity,
                            height: 48,
                            decoration: BoxDecoration(
                              color: isDark ? const Color(0xFF2C2C2E) : const Color(0xFFF2F2F2),
                              borderRadius: const BorderRadius.only(
                                topLeft: Radius.circular(20),
                                topRight: Radius.circular(20),
                              ),
                            ),
                            child: Center(
                              child: Text(
                                deleteButtonText,
                                style: const TextStyle(
                                  color: Color(0xFFD32F2F),
                                  fontSize: 16,
                                  fontWeight: FontWeight.w400,
                                ),
                              ),
                            ),
                          ),
                        ),
                        // Separator Divider
                        Container(
                          height: 2.0,
                          color: isDark ? const Color(0xFF1C1C1E) : CupertinoColors.white,
                        ),
                        // Cancel Button (Bottom Rounded)
                        GestureDetector(
                          onTap: () => Navigator.pop(context),
                          child: Container(
                            width: double.infinity,
                            height: 48,
                            decoration: BoxDecoration(
                              color: isDark ? const Color(0xFF2C2C2E) : const Color(0xFFF2F2F2),
                              borderRadius: const BorderRadius.only(
                                bottomLeft: Radius.circular(20),
                                bottomRight: Radius.circular(20),
                              ),
                            ),
                            child: Center(
                              child: Text(
                                'Cancel',
                                style: TextStyle(
                                  color: isDark ? CupertinoColors.white : const Color(0xFF1E1E1E),
                                  fontSize: 16,
                                  fontWeight: FontWeight.w400,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
    },
  );
}
