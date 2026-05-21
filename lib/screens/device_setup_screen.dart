import 'package:flutter/cupertino.dart';
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
    await showCupertinoDialog(
      context: context,
      builder: (ctx) => CupertinoAlertDialog(
        title: const Text('Skip Setup?'),
        content: const Text(
          'Without this permission, Snapi may not detect screenshots reliably in the background.\n\nYou can always enable it later from the app settings.',
        ),
        actions: [
          CupertinoDialogAction(
            isDestructiveAction: true,
            onPressed: () async {
              Navigator.pop(ctx);
              await DeviceSetupService.markSetupSkipped();
              widget.onDone();
            },
            child: const Text('Skip Anyway'),
          ),
          CupertinoDialogAction(
            isDefaultAction: true,
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Go Back'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark =
        CupertinoTheme.of(context).brightness == Brightness.dark;

    if (_isLoading) {
      return const CupertinoPageScaffold(
        child: Center(child: CupertinoActivityIndicator()),
      );
    }

    final Color accent = CupertinoTheme.of(context).primaryColor;
    final String brand = _guide!['brand'] as String;
    final String description = _guide!['description'] as String;
    final String tip = _guide!['tip'] as String;
    final bool hasSettingsButton = _guide!['hasSettingsButton'] as bool;
    final String settingsLabel = _guide!['settingsLabel'] as String;
    final IconData settingsIcon = _guide!['settingsIcon'] as IconData;

    final Color bgColor =
        isDark ? CupertinoColors.black : CupertinoColors.white;
    final Color cardColor = isDark
        ? const Color(0xFF1C1C1E)
        : CupertinoColors.systemGrey6.color;
    final Color labelColor = isDark
        ? CupertinoColors.white
        : CupertinoColors.black;

    return CupertinoPageScaffold(
      backgroundColor: bgColor,
      child: SafeArea(
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

                      // ── Header icon + titles ──────────────────────────────
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
                            child: Icon(CupertinoIcons.shield_fill, color: accent, size: 28),
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

                      // ── Step 1: Grant Battery Permission ──────────────────
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
                                icon: CupertinoIcons.lock_shield_fill,
                                accent: accent,
                                isLoading: _isRequesting,
                                filled: true,
                                onTap: _isRequesting
                                    ? null
                                    : _handleGrantPermission,
                              ),
                      ),

                      // ── Step 2: Open Device Settings (OEM only) ───────────
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

                      // ── Mascot Explanation Card ─────────────────────────────────
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: isDark ? const Color(0xFF233040) : const Color(0xFFF4F9FF),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: CupertinoColors.activeBlue.withOpacity(0.25),
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
                                color: CupertinoColors.white,
                                shape: BoxShape.circle,
                                boxShadow: [
                                  BoxShadow(
                                    color: CupertinoColors.activeBlue.withOpacity(0.15),
                                    blurRadius: 10,
                                    offset: const Offset(0, 4),
                                  )
                                ],
                              ),
                              child: Image.asset('assets/snapi.png'),
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
                                      fontWeight: FontWeight.w800,
                                      color: isDark ? CupertinoColors.white : CupertinoColors.black,
                                      letterSpacing: -0.3,
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    "I need this permission to automatically detect and organize your screenshots even when you're not using the app.",
                                    style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                      color: isDark ? CupertinoColors.systemGrey : const Color(0xFF555555),
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

              // ── Bottom CTA ─────────────────────────────────────────────────
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 0, 24, 16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    GestureDetector(
                      onTap: _permissionGranted ? _handleDone : null,
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 300),
                        width: double.infinity,
                        height: 58,
                        decoration: BoxDecoration(
                          gradient: _permissionGranted
                              ? LinearGradient(colors: [accent, accent.withOpacity(0.8)])
                              : LinearGradient(colors: [CupertinoColors.systemGrey4.resolveFrom(context), CupertinoColors.systemGrey4.resolveFrom(context)]),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: const Center(
                          child: Padding(
                            padding: EdgeInsets.symmetric(horizontal: 16.0),
                            child: FittedBox(
                              fit: BoxFit.scaleDown,
                              child: Text(
                                "All Done — Let's Go!",
                                style: TextStyle(
                                  fontSize: 17,
                                  fontWeight: FontWeight.w800,
                                  color: CupertinoColors.white,
                                  letterSpacing: -0.3,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    CupertinoButton(
                      padding: EdgeInsets.zero,
                      onPressed: _permissionGranted ? null : _handleSkip,
                      child: Text(
                        'Skip for Now',
                        style: TextStyle(
                          fontSize: 15,
                          color: _permissionGranted
                              ? CupertinoColors.systemGrey
                              : CupertinoColors.secondaryLabel
                                  .resolveFrom(context),
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

// ── Step Card ──────────────────────────────────────────────────────────────────
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
    return AnimatedContainer(
      duration: const Duration(milliseconds: 400),
      curve: Curves.easeOutCubic,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: isDone ? CupertinoColors.systemGreen.withOpacity(0.05) : cardColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isDone
              ? CupertinoColors.systemGreen.withOpacity(0.5)
              : accent.withOpacity(0.2),
          width: 1.5,
        ),
        boxShadow: isDone
            ? [
                BoxShadow(
                  color: CupertinoColors.systemGreen.withOpacity(0.15),
                  blurRadius: 24,
                  offset: const Offset(0, 8),
                )
              ]
            : [
                BoxShadow(
                  color: CupertinoColors.black.withOpacity(isDark ? 0.2 : 0.04),
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
              // Step number / check badge
              AnimatedContainer(
                duration: const Duration(milliseconds: 400),
                curve: Curves.easeOutBack,
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  color: isDone
                      ? CupertinoColors.systemGreen
                      : accent.withOpacity(0.15),
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: isDone
                      ? const Icon(CupertinoIcons.checkmark,
                          color: CupertinoColors.white, size: 14)
                      : Text(
                          '$step',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
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
                    fontWeight: FontWeight.w700,
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
                                  color: CupertinoColors.secondaryLabel.resolveFrom(context),
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
                      color: CupertinoColors.secondaryLabel.resolveFrom(context),
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

// ── Action Button ──────────────────────────────────────────────────────────────
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
    return SizedBox(
      width: double.infinity,
      child: CupertinoButton(
        padding: const EdgeInsets.symmetric(vertical: 13),
        color: filled ? accent : accent.withOpacity(0.1),
        borderRadius: BorderRadius.circular(14),
        onPressed: onTap,
        child: isLoading
            ? CupertinoActivityIndicator(
                color: filled ? CupertinoColors.white : accent)
            : Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(icon,
                      color: filled ? CupertinoColors.white : accent,
                      size: 16),
                  const SizedBox(width: 8),
                  Flexible(
                    child: Text(
                      label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: filled ? CupertinoColors.white : accent,
                      ),
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}

// ── Done Row ───────────────────────────────────────────────────────────────────
class _DoneRow extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const Icon(CupertinoIcons.checkmark_circle_fill,
            color: CupertinoColors.systemGreen, size: 20),
        const SizedBox(width: 8),
        const Text(
          'Permission Granted',
          style: TextStyle(
            color: CupertinoColors.systemGreen,
            fontWeight: FontWeight.w700,
            fontSize: 14,
          ),
        ),
      ],
    );
  }
}
