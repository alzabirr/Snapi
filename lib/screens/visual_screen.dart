import 'dart:io';
import 'dart:math';
import 'dart:ui';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart' show Colors;
import '../models/screenshot_item.dart';
import '../services/database_service.dart';
import 'dart:async';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'capture_details_screen.dart';
import 'category_screen.dart';

class VisualScreen extends StatefulWidget {
  const VisualScreen({super.key});

  @override
  State<VisualScreen> createState() => _VisualScreenState();
}

class _VisualScreenState extends State<VisualScreen> with WidgetsBindingObserver, TickerProviderStateMixin {
  late AnimationController _waveController;
  late TransformationController _transformationController;
  List<String> _categories = [];
  Map<String, List<ScreenshotItem>> _groupedItems = {};
  bool _isLoading = true;
  bool _initialCentered = false;
  final Map<String, Offset> _customOffsets = {};
  int _viewMode = 1; // 0 for All, 1 for Folder, 2 for Date
  bool _isMenuOpen = false;
  Timer? _refreshTimer;

  Offset _getNodePos(String id, double defX, double defY) {
    final key = 'mode_${_viewMode}_$id';
    return _customOffsets[key] ?? Offset(defX, defY);
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _transformationController = TransformationController();
    _loadData();
    
    // Real-time updates when database changes
    DatabaseService.box.listenable().addListener(_onDatabaseChange);
    DatabaseService.categoryNotifier.addListener(_onDatabaseChange);

    _waveController = AnimationController(
      duration: const Duration(seconds: 4),
      vsync: this,
    )..repeat();
  }

  void _onDatabaseChange() {
    if (mounted) _loadData(isAutoRefresh: true);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _transformationController.dispose();
    _waveController.dispose();
    DatabaseService.box.listenable().removeListener(_onDatabaseChange);
    DatabaseService.categoryNotifier.removeListener(_onDatabaseChange);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _loadData();
    }
  }

  void _centerView(Size viewportSize) {
    if (viewportSize.width == 0 || viewportSize.height == 0) return;
    
    // Reduced zoom level for better overview
    const double scale = 0.45;
    
    // The canvas is now 5000x5000, center node is at (2500, 2500).
    final tx = (viewportSize.width / 2) - (2500.0 * scale);
    final ty = (viewportSize.height / 2) - (2500.0 * scale);

    _transformationController.value = Matrix4.identity()
      ..translate(tx, ty)
      ..scale(scale);
  }

  Future<void> _loadData({bool isAutoRefresh = false}) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      var cats = prefs.getStringList('user_categories');
      
      if (cats == null || cats.isEmpty) {
        cats = ['Uncategorized', 'Work', 'Personal', 'Social'];
      }
      
      final allItems = DatabaseService.getAllItems();
      final Map<String, List<ScreenshotItem>> grouped = {};
      for (var cat in cats) {
        grouped[cat] = allItems.where((item) => item.category == cat || (cat == 'Uncategorized' && item.category.isEmpty)).toList();
      }

      if (mounted) {
        setState(() {
          _categories = cats!;
          _groupedItems = grouped;
          _isLoading = false;
        });
        if (!isAutoRefresh) {
          _initialCentered = false;
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) return const Center(child: CupertinoActivityIndicator());

    final isDark = CupertinoTheme.of(context).brightness == Brightness.dark;
    final hasItems = _groupedItems.values.any((list) => list.isNotEmpty);

    return CupertinoPageScaffold(
      backgroundColor: isDark ? CupertinoColors.black : CupertinoColors.white,
      navigationBar: CupertinoNavigationBar(
        middle: Text(
          'VISUAL',
          style: TextStyle(
            color: isDark ? CupertinoColors.white : CupertinoColors.black,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.5,
          ),
        ),
        backgroundColor: (isDark ? CupertinoColors.black : CupertinoColors.white).withOpacity(0.8),
        border: null,
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final size = Size(constraints.maxWidth, constraints.maxHeight);
          
          // Auto-center on first layout or after data reload
          if (!_initialCentered) {
            _initialCentered = true;
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted) _centerView(size);
            });
          }
          
          return Stack(
            children: [
              // Background Gradient
              Positioned.fill(
                child: Container(
                  color: isDark ? CupertinoColors.black : CupertinoColors.white,
                ),
              ),
              // Background Dim when menu is open
              if (_isMenuOpen)
                Positioned.fill(
                  child: GestureDetector(
                    onTap: () => setState(() => _isMenuOpen = false),
                    child: Container(
                      color: Colors.black.withOpacity(0.3),
                    ),
                  ),
                ),
              InteractiveViewer(
                transformationController: _transformationController,
                boundaryMargin: const EdgeInsets.all(2500),
                minScale: 0.05,
                maxScale: 2.5,
                constrained: false, 
                child: SizedBox(
                  width: 5000,
                  height: 5000,
                  child: RepaintBoundary(
                    child: Stack(
                      children: [
                        // Clean minimalist background
                        Positioned.fill(
                          child: CustomPaint(
                            painter: MindMapPainter(
                              categories: _categories,
                              groupedItems: _groupedItems,
                              isDark: isDark,
                              customOffsets: _customOffsets,
                              viewMode: _viewMode,
                              dateCategories: _getDateCategories(),
                              getMonthName: _getMonthName,
                            ),
                          ),
                        ),
                        _buildDraggableNode(2500, 2500, '', CupertinoColors.activeBlue, 'root', isCenter: true),
                        ..._buildCategoryBranches(),
                      ],
                    ),
                  ),
                ),
              ),
              // Glassmorphic Instruction Card
              Positioned(
                top: 20,
                left: 20,
                right: 20,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(20),
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                      decoration: BoxDecoration(
                        color: (isDark ? Colors.black : Colors.white).withOpacity(0.4),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: CupertinoColors.activeBlue.withOpacity(0.2)),
                      ),
                      child: Row(
                        children: [
                          const Icon(CupertinoIcons.sparkles, color: CupertinoColors.activeBlue, size: 20),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              'Explore your visual catalog. Drag nodes to move.',
                              style: TextStyle(
                                color: isDark ? Colors.white : Colors.black,
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                letterSpacing: -0.2,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              // Floating Action Buttons (Redesigned)
              Positioned(
                bottom: 110,
                right: 20,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const SizedBox(height: 12),
                    SizedBox(
                      height: 250,
                      width: 160,
                      child: Stack(
                        alignment: Alignment.bottomRight,
                        clipBehavior: Clip.none,
                        children: [
                          _buildAnimatedMenuButton(
                            index: 2,
                            isOpen: _isMenuOpen,
                            icon: CupertinoIcons.square_grid_2x2_fill,
                            label: 'Overview',
                            bottom: 185,
                            onPressed: () {
                              setState(() {
                                _viewMode = 0;
                                _isMenuOpen = false;
                              });
                            },
                          ),
                          _buildAnimatedMenuButton(
                            index: 1,
                            isOpen: _isMenuOpen,
                            icon: CupertinoIcons.time_solid,
                            label: 'Timeline',
                            bottom: 125,
                            onPressed: () {
                              setState(() {
                                _viewMode = 2;
                                _isMenuOpen = false;
                              });
                            },
                          ),
                          _buildAnimatedMenuButton(
                            index: 0,
                            isOpen: _isMenuOpen,
                            icon: CupertinoIcons.folder_solid,
                            label: 'Clusters',
                            bottom: 65,
                            onPressed: () {
                              setState(() {
                                _viewMode = 1;
                                _isMenuOpen = false;
                              });
                            },
                          ),
                          _buildFloatingButton(
                            icon: _isMenuOpen ? CupertinoIcons.xmark : CupertinoIcons.slider_horizontal_3,
                            label: 'Layout',
                            onPressed: () => setState(() => _isMenuOpen = !_isMenuOpen),
                            color: CupertinoColors.activeBlue,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          );
        }
      ),
    );
  }

  Widget _buildAnimatedMenuButton({
    required int index,
    required bool isOpen,
    required IconData icon,
    required String label,
    required double bottom,
    required VoidCallback onPressed,
  }) {
    return AnimatedPositioned(
      duration: Duration(milliseconds: 300 + (index * 60)),
      curve: Curves.easeOutQuart,
      bottom: isOpen ? bottom : 0,
      right: 0,
      child: AnimatedOpacity(
        duration: const Duration(milliseconds: 200),
        opacity: isOpen ? 1.0 : 0.0,
        child: AnimatedScale(
          duration: const Duration(milliseconds: 400),
          scale: isOpen ? 1.0 : 0.4,
          curve: Curves.easeOutBack,
          child: _buildFloatingButton(
            icon: icon, 
            label: label, 
            onPressed: onPressed,
            color: CupertinoColors.activeBlue.withOpacity(0.9),
          ),
        ),
      ),
    );
  }

  Widget _buildFloatingButton({required IconData icon, required String label, required VoidCallback onPressed, Color color = CupertinoColors.activeBlue}) {
    return GestureDetector(
      onTap: onPressed,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(18),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: Colors.white, size: 20),
            const SizedBox(width: 10),
            Text(label, style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w700)),
          ],
        ),
      ),
    );
  }

  List<String> _getDateCategories() {
    final allItems = _groupedItems.values.expand((x) => x).toList();
    allItems.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    List<String> result = [];
    for (var item in allItems) {
      final dateStr = '${item.createdAt.day} ${_getMonthName(item.createdAt.month)} ${item.createdAt.year}';
      if (!result.contains(dateStr)) result.add(dateStr);
    }
    return result;
  }

  List<Widget> _buildCategoryBranches() {
    if (_viewMode == 0) {
      List<Widget> widgets = [];
      final allItems = _groupedItems.values.expand((x) => x).toList();
      double centerX = 2500;
      double centerY = 2500;
      for (int i = 0; i < allItems.length; i++) {
        double goldenAngle = pi * (3 - sqrt(5)); 
        double theta = i * goldenAngle;
        double r = 160 + (90 * sqrt(i));
        double itemX = centerX + r * cos(theta);
        double itemY = centerY + r * sin(theta);
        widgets.add(_buildDraggableItemNode(itemX, itemY, allItems[i]));
      }
      return widgets;
    }

    if (_viewMode == 2) {
      List<Widget> widgets = [];
      final allItems = _groupedItems.values.expand((x) => x).toList();
      allItems.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      Map<String, List<ScreenshotItem>> dateGroups = {};
      for (var item in allItems) {
        final dateStr = '${item.createdAt.day} ${_getMonthName(item.createdAt.month)} ${item.createdAt.year}';
        if (!dateGroups.containsKey(dateStr)) dateGroups[dateStr] = [];
        dateGroups[dateStr]!.add(item);
      }
      final activeDates = dateGroups.keys.toList();
      double centerX = 2500;
      double centerY = 2500;
      double radius = 600;
      for (int i = 0; i < activeDates.length; i++) {
        double angle = (2 * pi * i) / (activeDates.isEmpty ? 1 : activeDates.length);
        double defCatX = centerX + radius * cos(angle);
        double defCatY = centerY + radius * sin(angle);
        
        // Actual position of the Date node
        final catPos = _getNodePos('date_${activeDates[i]}', defCatX, defCatY);

        widgets.add(_buildDraggableNode(defCatX, defCatY, activeDates[i], CupertinoColors.systemIndigo, 'date_${activeDates[i]}'));
        final items = dateGroups[activeDates[i]]!;
        for (int j = 0; j < items.length; j++) {
          int layer = (j / 6).floor();
          int indexInLayer = j % 6;
          int itemsInThisLayer = (j >= (layer * 6) && j < (layer + 1) * 6) ? min(6, items.length - layer * 6) : 6;
          double layerRadius = 220.0 + (layer * 140.0);
          double arcSweep = pi / (1.2 + (layer * 0.2));
          double subAngle = angle - (arcSweep / 2) + (arcSweep * indexInLayer / (itemsInThisLayer > 1 ? itemsInThisLayer - 1 : 1));
          if (itemsInThisLayer == 1) subAngle = angle;
          
          // Position relative to actual Date node
          double itemX = catPos.dx + layerRadius * cos(subAngle);
          double itemY = catPos.dy + layerRadius * sin(subAngle);
          widgets.add(_buildDraggableItemNode(itemX, itemY, items[j]));
        }
      }
      return widgets;
    }

    List<Widget> widgets = [];
    double centerX = 2500;
    double centerY = 2500;
    for (int i = 0; i < _categories.length; i++) {
      double angle = (2 * pi * i) / (_categories.isEmpty ? 1 : _categories.length);
      double catRadius = 750.0 + (i % 2 == 0 ? 0 : 350.0);
      double defCatX = centerX + catRadius * cos(angle);
      double defCatY = centerY + catRadius * sin(angle);
      
      // Get the ACTUAL position of the folder node
      final catPos = _getNodePos('cat_${_categories[i]}', defCatX, defCatY);

      final color = _getCategoryColor(i);
      widgets.add(_buildDraggableNode(defCatX, defCatY, _categories[i], color, 'cat_${_categories[i]}'));

      final items = _groupedItems[_categories[i]] ?? [];
      for (int j = 0; j < items.length; j++) {
        int ring = 1;
        int capacity = 6;
        int currentItemCount = j;
        while (currentItemCount >= capacity) {
          currentItemCount -= capacity;
          ring++;
          capacity = ring * 6;
        }
        double ringRadius = 140.0 + (ring * 110.0);
        double theta = angle + (2 * pi * currentItemCount) / capacity + (ring * 0.3);
        
        // Calculate item position relative to the ACTUAL folder position
        double itemX = catPos.dx + ringRadius * cos(theta);
        double itemY = catPos.dy + ringRadius * sin(theta);
        widgets.add(_buildDraggableItemNode(itemX, itemY, items[j]));
      }
    }
    return widgets;
  }

  Widget _buildDraggableNode(double defX, double defY, String label, Color color, String id, {bool isCenter = false}) {
    final pos = _getNodePos(id, defX, defY);
    return Positioned(
      left: pos.dx - (isCenter ? 75 : 60),
      top: pos.dy - (isCenter ? 75 : 60),
      child: AnimatedBuilder(
        animation: _waveController,
        builder: (context, child) {
          final double wave = sin((_waveController.value * 2 * pi) + (id.hashCode % 10));
          final double scale = isCenter ? (1.0 + (wave * 0.05)) : 1.0;
          return Transform.scale(
            scale: scale,
            child: Transform.translate(
              offset: Offset(0, wave * (isCenter ? 4 : 8)),
              child: child,
            ),
          );
        },
        child: GestureDetector(
          onPanUpdate: (details) {
            final key = 'mode_${_viewMode}_$id';
            _customOffsets[key] = pos + details.delta;
            setState(() {}); 
          },
          onTap: () {
            if (!isCenter) {
              Navigator.push(
                context,
                CupertinoPageRoute(
                  builder: (context) => CategoryDetailScreen(
                    category: label,
                    items: _groupedItems[label] ?? [],
                  ),
                ),
              );
            }
          },
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: isCenter ? 150 : 120,
                height: isCenter ? 150 : 120,
                decoration: BoxDecoration(
                  color: color.withOpacity(0.15),
                  shape: BoxShape.circle,
                  border: Border.all(color: color.withOpacity(0.5), width: 3),
                  boxShadow: [
                    BoxShadow(color: color.withOpacity(0.2), blurRadius: 20, spreadRadius: 2),
                  ],
                ),
                child: Center(
                  child: Container(
                    margin: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: color.withOpacity(0.25),
                      shape: BoxShape.circle,
                    ),
                    child: isCenter 
                      ? Padding(
                          padding: const EdgeInsets.all(16),
                          child: Image.asset('assets/snapi.png', fit: BoxFit.contain),
                        )
                      : Icon(CupertinoIcons.folder_fill, color: color, size: 40),
                  ),
                ),
              ),
              if (label.isNotEmpty) ...[
                const SizedBox(height: 12),
                ClipRRect(
                  borderRadius: BorderRadius.circular(20),
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
                      decoration: BoxDecoration(
                        color: color.withOpacity(0.8),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        label,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.2,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDraggableItemNode(double defX, double defY, ScreenshotItem item) {
    final pos = _getNodePos(item.id, defX, defY);
    return Positioned(
      left: pos.dx - 55,
      top: pos.dy - 65,
      child: AnimatedBuilder(
        animation: _waveController,
        builder: (context, child) {
          final double wave = sin((_waveController.value * 2 * pi) + (item.id.hashCode % 10));
          return Transform.translate(
            offset: Offset(0, wave * 6),
            child: child,
          );
        },
        child: GestureDetector(
          onPanUpdate: (details) {
            final key = 'mode_${_viewMode}_${item.id}';
            _customOffsets[key] = pos + details.delta;
            setState(() {});
          },
          onTap: () => Navigator.push(
            context,
            CupertinoPageRoute(builder: (context) => CaptureDetailsScreen(item: item)),
          ),
          child: Container(
            width: 110,
            height: 140,
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: CupertinoColors.systemBackground.withOpacity(0.9),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: CupertinoColors.activeBlue.withOpacity(0.4)),
              boxShadow: [
                BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 10, offset: const Offset(0, 5)),
              ],
            ),
            child: Column(
              children: [
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Image.file(
                      File(item.path),
                      fit: BoxFit.cover,
                      cacheWidth: 200,
                      errorBuilder: (c, e, s) => Container(
                        color: CupertinoColors.systemGrey6,
                        child: const Icon(CupertinoIcons.photo, size: 30, color: CupertinoColors.systemGrey),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: Text(
                    item.note.isEmpty ? 'Capture' : item.note,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700),
                  ),
                ),
                const SizedBox(height: 4),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _getMonthName(int month) {
    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return months[month - 1];
  }

  Color _getCategoryColor(int index) {
    final colors = [
      CupertinoColors.systemPurple,
      CupertinoColors.systemOrange,
      CupertinoColors.systemPink,
      CupertinoColors.systemTeal,
      CupertinoColors.systemGreen,
      CupertinoColors.systemIndigo,
    ];
    return colors[index % colors.length];
  }
}

class MindMapPainter extends CustomPainter {
  final List<String> categories;
  final Map<String, List<ScreenshotItem>> groupedItems;
  final bool isDark;
  final Map<String, Offset> customOffsets;
  final int viewMode;
  final List<String> dateCategories;
  final String Function(int) getMonthName;

  MindMapPainter({
    required this.categories, 
    required this.groupedItems, 
    required this.isDark,
    required this.customOffsets,
    required this.viewMode,
    required this.dateCategories,
    required this.getMonthName,
  });

  Offset _getPos(String id, double defX, double defY) {
    final key = 'mode_${viewMode}_$id';
    return customOffsets[key] ?? Offset(defX, defY);
  }

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = CupertinoColors.activeBlue.withOpacity(isDark ? 0.2 : 0.3)
      ..strokeWidth = 2.0
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..isAntiAlias = true;

    final double defCenterX = 2500.0;
    final double defCenterY = 2500.0;
    final centerPos = _getPos('root', defCenterX, defCenterY);

    if (viewMode == 0) {
      final allItems = groupedItems.values.expand((x) => x).toList();
      for (int i = 0; i < allItems.length; i++) {
        double goldenAngle = pi * (3 - sqrt(5)); 
        double theta = i * goldenAngle;
        double r = 160 + (90 * sqrt(i));
        final targetPos = _getPos(allItems[i].id, defCenterX + r * cos(theta), defCenterY + r * sin(theta));
        _drawOrganicCurve(canvas, centerPos, targetPos, paint);
      }
    } else if (viewMode == 2) {
      for (int i = 0; i < dateCategories.length; i++) {
        double angle = (2 * pi * i) / (dateCategories.isEmpty ? 1 : dateCategories.length);
        final catPos = _getPos('date_${dateCategories[i]}', defCenterX + 600 * cos(angle), defCenterY + 600 * sin(angle));
        _drawOrganicCurve(canvas, centerPos, catPos, paint);

        final items = groupedItems.values.expand((x) => x).where((item) {
          final dateStr = '${item.createdAt.day} ${getMonthName(item.createdAt.month)} ${item.createdAt.year}';
          return dateStr == dateCategories[i];
        }).toList();

        for (int j = 0; j < items.length; j++) {
          int layer = (j / 6).floor();
          int indexInLayer = j % 6;
          int itemsInThisLayer = (j >= (layer * 6) && j < (layer + 1) * 6) ? min(6, items.length - layer * 6) : 6;
          double layerRadius = 220.0 + (layer * 140.0);
          double arcSweep = pi / (1.2 + (layer * 0.2));
          double subAngle = angle - (arcSweep / 2) + (arcSweep * indexInLayer / (itemsInThisLayer > 1 ? itemsInThisLayer - 1 : 1));
          if (itemsInThisLayer == 1) subAngle = angle;
          
          final itemPos = _getPos(items[j].id, catPos.dx + layerRadius * cos(subAngle), catPos.dy + layerRadius * sin(subAngle));
          _drawOrganicCurve(canvas, catPos, itemPos, paint);
        }
      }
    } else {
      for (int i = 0; i < categories.length; i++) {
        double angle = (2 * pi * i) / (categories.isEmpty ? 1 : categories.length);
        double catRadius = 750.0 + (i % 2 == 0 ? 0 : 350.0);
        final catPos = _getPos('cat_${categories[i]}', defCenterX + catRadius * cos(angle), defCenterY + catRadius * sin(angle));
        _drawOrganicCurve(canvas, centerPos, catPos, paint);

        final items = groupedItems[categories[i]] ?? [];
        for (int j = 0; j < items.length; j++) {
          int ring = 1;
          int capacity = 6;
          int currentItemCount = j;
          while (currentItemCount >= capacity) {
            currentItemCount -= capacity;
            ring++;
            capacity = ring * 6;
          }
          double ringRadius = 140.0 + (ring * 110.0);
          double theta = angle + (2 * pi * currentItemCount) / capacity + (ring * 0.3);
          final itemPos = _getPos(items[j].id, catPos.dx + ringRadius * cos(theta), catPos.dy + ringRadius * sin(theta));
          _drawOrganicCurve(canvas, catPos, itemPos, paint);
        }
      }
    }
  }

  void _drawOrganicCurve(Canvas canvas, Offset start, Offset end, Paint paint) {
    final path = Path();
    path.moveTo(start.dx, start.dy);
    
    final double dist = (end - start).distance;
    final double controlPointDist = dist * 0.45;
    final Offset direction = (end - start) / (dist == 0 ? 1 : dist);
    final Offset normal = Offset(-direction.dy, direction.dx);
    
    final cp1 = start + direction * controlPointDist + normal * (controlPointDist * 0.25);
    final cp2 = end - direction * controlPointDist - normal * (controlPointDist * 0.25);
    
    path.cubicTo(cp1.dx, cp1.dy, cp2.dx, cp2.dy, end.dx, end.dy);
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}