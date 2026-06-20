import 'package:flutter/material.dart';
import '../services/device_setup_service.dart';

class DeviceSetupScreen extends StatefulWidget {
  final VoidCallback onDone;
  const DeviceSetupScreen({super.key, required this.onDone});

  @override
  State<DeviceSetupScreen> createState() => _DeviceSetupScreenState();
}

class _DeviceSetupScreenState extends State<DeviceSetupScreen>
    with SingleTickerProviderStateMixin {
  Map<String, dynamic>? _guide;
  String _manufacturer = 'unknown';
  bool _isLoading = true;
  bool _permissionGranted = false;
  bool _isRequesting = false;
  bool _isOpeningSettings = false;
  late AnimationController _controller;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 600));
    _fadeAnimation =
        CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic);
    _loadGuide();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _loadGuide() async {
    final manufacturer = await DeviceSetupService.getManufacturer();
    final permissionGranted = await DeviceSetupService.isBatteryOptimizationIgnored();
    setState(() {
      _manufacturer = manufacturer;
      _guide = DeviceSetupService.getGuideForDevice(manufacturer);
      _permissionGranted = permissionGranted;
      _isLoading = false;
    });
    _controller.forward();
  }

  Future<void> _handleGrantPermission() async {
    setState(() => _isRequesting = true);
    await DeviceSetupService.requestBatteryOptimization();
    final permissionGranted = await DeviceSetupService.isBatteryOptimizationIgnored();
    setState(() {
      _isRequesting = false;
      _permissionGranted = permissionGranted;
    });
  }

  Future<void> _handleOpenSettings() async {
    setState(() => _isOpeningSettings = true);
    await DeviceSetupService.openManufacturerSettings(_manufacturer);
    await Future.delayed(const Duration(milliseconds: 800));
    if (mounted) setState(() => _isOpeningSettings = false);
  }

  Future<void> _handleDone() async {
    await DeviceSetupService.markSetupDone();
    widget.onDone();
  }

  Future<void> _handleSkip() async {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Skip Setup?'),
        content: const Text(
          'Without this permission, Krabby may not detect screenshots reliably in the background.\n\nYou can always enable it later from the app settings.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Go Back'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(ctx);
              await DeviceSetupService.markSetupSkipped();
              widget.onDone();
            },
            child: const Text('Skip Anyway', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    if (_isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    final Color accent = theme.colorScheme.primary;
    final String brand = _guide!['brand'] as String;
    final String description = _guide!['description'] as String;
    final String tip = _guide!['tip'] as String;
    final bool hasSettingsButton = _guide!['hasSettingsButton'] as bool;
    final String settingsLabel = _guide!['settingsLabel'] as String;
    final IconData settingsIcon = _guide!['settingsIcon'] as IconData;

    final Color bgColor = theme.scaffoldBackgroundColor;
    final Color cardColor = isDark ? const Color(0xFF1E293B) : Colors.grey.shade100;
    final Color labelColor = theme.colorScheme.onSurface;

    return Scaffold(
      backgroundColor: bgColor,
      body: SafeArea(
        child: FadeTransition(
          opacity: _fadeAnimation,
          child: Column(
            children: [
              Expanded(
                child: SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 20),

                      // Header
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Container(
                            width: 60,
                            height: 60,
                            decoration: BoxDecoration(
                              color: accent.withOpacity(0.12),
                              shape: BoxShape.circle,
                              border: Border.all(color: accent.withOpacity(0.2), width: 1.5),
                            ),
                            child: Icon(Icons.security, color: accent, size: 28),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'One Last Step',
                                  style: TextStyle(
                                    fontSize: 26,
                                    fontWeight: FontWeight.w900,
                                    letterSpacing: -0.5,
                                    color: labelColor,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                      decoration: BoxDecoration(
                                        color: accent.withOpacity(0.1),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Text(
                                        brand,
                                        style: TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w800,
                                          color: accent,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 20),

                      // Step 1 Card
                      _StepCard(
                        step: 1,
                        accent: accent,
                        isDark: isDark,
                        cardColor: cardColor,
                        labelColor: labelColor,
                        title: 'Grant Background Permission',
                        subtitle: 'Required for auto-detection.',
                        isDone: _permissionGranted,
                        child: _permissionGranted
                            ? _DoneRow()
                            : _ActionButton(
                                label: 'Grant Permission',
                                icon: Icons.security,
                                accent: accent,
                                isLoading: _isRequesting,
                                filled: true,
                                onTap: _isRequesting
                                    ? null
                                    : _handleGrantPermission,
                              ),
                      ),

                      // Step 2 Card (OEM only)
                      if (hasSettingsButton) ...[
                        const SizedBox(height: 16),
                        _StepCard(
                          step: 2,
                          accent: accent,
                          isDark: isDark,
                          cardColor: cardColor,
                          labelColor: labelColor,
                          title: 'Open Device Settings',
                          subtitle: description + (tip.isNotEmpty ? '\n\n' + tip : ''),
                          isDone: false,
                          child: _ActionButton(
                            label: settingsLabel,
                            icon: settingsIcon,
                            accent: accent,
                            isLoading: _isOpeningSettings,
                            filled: false,
                            onTap: _isOpeningSettings
                                ? null
                                : _handleOpenSettings,
                          ),
                        ),
                      ],

                      const SizedBox(height: 16),

                      // Mascot Info Card
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF4F9FF),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: accent.withOpacity(0.25),
                            width: 1.5,
                          ),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            Container(
                              width: 48,
                              height: 48,
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                shape: BoxShape.circle,
                                boxShadow: [
                                  BoxShadow(
                                    color: accent.withOpacity(0.15),
                                    blurRadius: 10,
                                    offset: const Offset(0, 4),
                                  )
                                ],
                              ),
                              child: Image.asset('assets/krabby.png'),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Why do I need this?',
                                    style: TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.bold,
                                      color: labelColor,
                                      letterSpacing: -0.3,
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    "I need this permission to automatically detect and organize your screenshots even when you're not using the app.",
                                    style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w500,
                                      color: theme.colorScheme.onSurface.withOpacity(0.7),
                                      height: 1.4,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 32),
                    ],
                  ),
                ),
              ),

              // Bottom CTA
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 0, 24, 16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    FilledButton(
                      style: FilledButton.styleFrom(
                        backgroundColor: _permissionGranted ? accent : theme.colorScheme.onSurface.withOpacity(0.12),
                        minimumSize: const Size(double.infinity, 58),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20),
                        ),
                      ),
                      onPressed: _permissionGranted ? _handleDone : null,
                      child: Text(
                        "All Done — Let's Go!",
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.bold,
                          color: _permissionGranted ? Colors.white : theme.colorScheme.onSurface.withOpacity(0.38),
                          letterSpacing: -0.3,
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    TextButton(
                      onPressed: _permissionGranted ? null : _handleSkip,
                      child: Text(
                        'Skip for Now',
                        style: TextStyle(
                          fontSize: 15,
                          color: _permissionGranted
                              ? Colors.grey
                              : theme.colorScheme.primary,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StepCard extends StatelessWidget {
  final int step;
  final Color accent;
  final bool isDark;
  final Color cardColor;
  final Color labelColor;
  final String title;
  final String subtitle;
  final bool isDone;
  final Widget child;

  const _StepCard({
    required this.step,
    required this.accent,
    required this.isDark,
    required this.cardColor,
    required this.labelColor,
    required this.title,
    required this.subtitle,
    required this.isDone,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AnimatedContainer(
      duration: const Duration(milliseconds: 400),
      curve: Curves.easeOutCubic,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: isDone ? Colors.green.withOpacity(0.05) : cardColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isDone
              ? Colors.green.withOpacity(0.5)
              : accent.withOpacity(0.2),
          width: 1.5,
        ),
        boxShadow: isDone
            ? [
                BoxShadow(
                  color: Colors.green.withOpacity(0.15),
                  blurRadius: 24,
                  offset: const Offset(0, 8),
                )
              ]
            : [
                BoxShadow(
                  color: Colors.black.withOpacity(isDark ? 0.2 : 0.04),
                  blurRadius: 16,
                  offset: const Offset(0, 4),
                )
              ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 400),
                curve: Curves.easeOutBack,
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  color: isDone ? Colors.green : accent.withOpacity(0.15),
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: isDone
                      ? const Icon(Icons.check, color: Colors.white, size: 14)
                      : Text(
                          '$step',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: accent,
                          ),
                        ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: labelColor,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 5),
          Padding(
            padding: const EdgeInsets.only(left: 38),
            child: subtitle.contains('\n')
                ? Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: subtitle.split('\n').where((line) => line.trim().isNotEmpty).map((line) {
                      final cleanLine = line.replaceFirst(RegExp(r'^\d+\.\s*'), '');
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              margin: const EdgeInsets.only(top: 5, right: 10),
                              width: 6,
                              height: 6,
                              decoration: BoxDecoration(
                                color: accent.withOpacity(0.5),
                                shape: BoxShape.circle,
                              ),
                            ),
                            Expanded(
                              child: Text(
                                cleanLine,
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: theme.colorScheme.onSurface.withOpacity(0.6),
                                  height: 1.4,
                                ),
                              ),
                            ),
                          ],
                        ),
                      );
                    }).toList(),
                  )
                : Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: theme.colorScheme.onSurface.withOpacity(0.6),
                      height: 1.45,
                    ),
                  ),
          ),
          const SizedBox(height: 14),
          child,
        ],
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color accent;
  final bool filled;
  final bool isLoading;
  final VoidCallback? onTap;

  const _ActionButton({
    required this.label,
    required this.icon,
    required this.accent,
    required this.filled,
    required this.isLoading,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SizedBox(
      width: double.infinity,
      child: FilledButton(
        style: FilledButton.styleFrom(
          backgroundColor: filled ? accent : accent.withOpacity(0.1),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          padding: const EdgeInsets.symmetric(vertical: 13),
        ),
        onPressed: onTap,
        child: isLoading
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
              )
            : Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(icon, color: filled ? Colors.white : accent, size: 16),
                  const SizedBox(width: 8),
                  Flexible(
                    child: Text(
                      label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: filled ? Colors.white : accent,
                      ),
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}

class _DoneRow extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Row(
      children: const [
        Icon(Icons.check_circle, color: Colors.green, size: 20),
        SizedBox(width: 8),
        Text(
          'Permission Granted',
          style: TextStyle(
            color: Colors.green,
            fontWeight: FontWeight.bold,
            fontSize: 14,
          ),
        ),
      ],
    );
  }
}
