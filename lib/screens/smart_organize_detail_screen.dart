import 'package:flutter/cupertino.dart';
import 'dart:ui';
import 'dart:math';
import 'package:flutter/material.dart' show Colors;

class SmartOrganizeDetailScreen extends StatefulWidget {
  const SmartOrganizeDetailScreen({super.key});

  @override
  State<SmartOrganizeDetailScreen> createState() => _SmartOrganizeDetailScreenState();
}

class _SmartOrganizeDetailScreenState extends State<SmartOrganizeDetailScreen> with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 8),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = CupertinoTheme.of(context).brightness == Brightness.dark;
    final primaryColor = CupertinoColors.activeBlue;

    return CupertinoPageScaffold(
      backgroundColor: isDark ? const Color(0xFF000000) : const Color(0xFFF9F9FB),
      navigationBar: CupertinoNavigationBar(
        leading: CupertinoButton(
          padding: EdgeInsets.zero,
          onPressed: () => Navigator.pop(context),
          child: const Icon(CupertinoIcons.chevron_back, size: 28),
        ),
        backgroundColor: isDark ? const Color(0xFF000000) : const Color(0xFFF9F9FB),
        middle: const Text('AI Workflow'),
        border: null,
      ),
      child: Stack(
        children: [
          // Main Content
          SafeArea(
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              child: Column(
                children: [
                  const SizedBox(height: 30),
                  
                  // Title Section
                  TweenAnimationBuilder<double>(
                    tween: Tween(begin: 0, end: 1),
                    duration: const Duration(seconds: 1),
                    builder: (context, value, child) => Opacity(
                      opacity: value,
                      child: child,
                    ),
                    child: Column(
                      children: [
                        const Text(
                          'Intelligence Map',
                          style: TextStyle(
                            fontSize: 38,
                            fontWeight: FontWeight.w900,
                            letterSpacing: -1.8,
                          ),
                        ),
                        const SizedBox(height: 10),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 50),
                          child: Text(
                            'Snapi automatically analyzes your captures to suggest the perfect folder for you.',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 15,
                              color: CupertinoColors.secondaryLabel.resolveFrom(context),
                              fontWeight: FontWeight.w600,
                              height: 1.4,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  
                  const SizedBox(height: 60),
                  
                  // Interactive Map Container
                  Container(
                    height: 750,
                    width: double.infinity,
                    margin: const EdgeInsets.symmetric(horizontal: 16),
                    child: Stack(
                      clipBehavior: Clip.none,
                      children: [
                        // Dynamic Connecting Path
                        Positioned.fill(
                          child: AnimatedBuilder(
                            animation: _controller,
                            builder: (context, child) => CustomPaint(
                              painter: WorkflowPathPainter(
                                progress: _controller.value,
                                isDark: isDark,
                                primaryColor: primaryColor,
                              ),
                            ),
                          ),
                        ),
                        
                        // Map Nodes
                        _buildFloatingNode(
                          top: 0,
                          left: 20,
                          icon: CupertinoIcons.camera_fill,
                          color: CupertinoColors.systemPink,
                          label: 'Auto-Detection',
                          desc: 'Snapi instantly feels when you save a new screenshot.',
                          delay: 0.0,
                        ),
                        
                        _buildFloatingNode(
                          top: 180,
                          right: 10,
                          icon: CupertinoIcons.doc_text_viewfinder,
                          color: CupertinoColors.activeBlue,
                          label: 'Text Reading',
                          desc: 'AI reads keywords inside images to understand what it is.',
                          delay: 0.25,
                        ),
                        
                        _buildFloatingNode(
                          top: 360,
                          left: 10,
                          icon: CupertinoIcons.sparkles,
                          color: CupertinoColors.systemYellow,
                          label: 'Auto-Suggestion',
                          desc: 'AI automatically suggests the best folder based on content.',
                          delay: 0.5,
                        ),
                        
                        _buildFloatingNode(
                          top: 540,
                          right: 20,
                          icon: CupertinoIcons.folder_badge_plus,
                          color: CupertinoColors.systemGreen,
                          label: 'Auto-Organize',
                          desc: 'With one tap, your capture is sorted into its smart folder.',
                          delay: 0.75,
                        ),
                      ],
                    ),
                  ),
                  
                  const SizedBox(height: 100),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFloatingNode({
    required double top,
    double? left,
    double? right,
    required IconData icon,
    required Color color,
    required String label,
    required String desc,
    required double delay,
  }) {
    return Positioned(
      top: top,
      left: left,
      right: right,
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) {
          return Container(
            width: 200,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: left != null ? CrossAxisAlignment.start : CrossAxisAlignment.end,
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [color.withOpacity(0.2), color.withOpacity(0.1)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    shape: BoxShape.circle,
                    border: Border.all(color: color.withOpacity(0.4), width: 1.5),
                    boxShadow: [
                      BoxShadow(
                        color: color.withOpacity(0.15),
                        blurRadius: 20,
                      ),
                    ],
                  ),
                  child: Icon(icon, color: color, size: 28),
                ),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: (CupertinoTheme.of(context).brightness == Brightness.dark 
                      ? const Color(0xFF1C1C1E) 
                      : CupertinoColors.white).withOpacity(0.8),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: color.withOpacity(0.1)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        label,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w900,
                          color: color,
                          letterSpacing: -0.2,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        desc,
                        textAlign: left != null ? TextAlign.left : TextAlign.right,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                          color: CupertinoColors.secondaryLabel.resolveFrom(context),
                          height: 1.3,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class WorkflowPathPainter extends CustomPainter {
  final double progress;
  final bool isDark;
  final Color primaryColor;

  WorkflowPathPainter({
    required this.progress,
    required this.isDark,
    required this.primaryColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = (isDark ? Colors.white : Colors.black).withOpacity(0.06)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round;

    final dashPaint = Paint()
      ..color = primaryColor.withOpacity(0.5)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5
      ..strokeCap = StrokeCap.round;

    final path = Path();
    
    path.moveTo(60, 40);
    path.cubicTo(size.width - 20, 80, size.width - 20, 160, size.width - 60, 210);
    path.cubicTo(0, 260, 0, 360, 60, 410);
    path.cubicTo(size.width, 460, size.width, 560, size.width - 60, 610);

    canvas.drawPath(path, paint);

    final pms = path.computeMetrics();
    for (var pm in pms) {
      final length = pm.length;
      final dashPath = Path();
      
      double start = (progress * length * 1.2) % (length * 1.2);
      if (start < length) {
        double end = min(start + 80, length);
        dashPath.addPath(pm.extractPath(start, end), Offset.zero);
      }
      
      canvas.drawPath(dashPath, dashPaint);
      
      if (start < length) {
        final pos = pm.getTangentForOffset(min(start + 80, length))?.position;
        if (pos != null) {
          final glowPaint = Paint()
            ..color = primaryColor.withOpacity(0.6)
            ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 12);
          canvas.drawCircle(pos, 8, glowPaint);
          canvas.drawCircle(pos, 3, Paint()..color = Colors.white);
        }
      }
    }
  }

  @override
  bool shouldRepaint(covariant WorkflowPathPainter oldDelegate) => true;
}
