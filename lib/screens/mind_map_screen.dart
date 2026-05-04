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

class MindMapScreen extends StatefulWidget {
  const MindMapScreen({super.key});

  @override
  State<MindMapScreen> createState() => _MindMapScreenState();
}

class _MindMapScreenState extends State<MindMapScreen> with WidgetsBindingObserver {
  late TransformationController _transformationController;
  List<String> _categories = [];
  Map<String, List<ScreenshotItem>> _groupedItems = {};
  bool _isLoading = true;
  bool _initialCentered = false;
  final Map<String, Offset> _customOffsets = {};
  int _viewMode = 1; // 0 for All, 1 for Folder, 2 for Date
  bool _isMenuOpen = false;
  Timer? _refreshTimer;

  Offset _getNodePos(String id, double defaultX, double defaultY) {
    return _customOffsets[id] ?? Offset(defaultX, defaultY);
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
  }

  void _onDatabaseChange() {
    if (mounted) _loadData(isAutoRefresh: true);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _transformationController.dispose();
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
        cats = ['General', 'Work', 'Personal', 'Social', 'School'];
      }
      
      final allItems = DatabaseService.getAllItems();
      final Map<String, List<ScreenshotItem>> grouped = {};
      for (var cat in cats) {
        grouped[cat] = allItems.where((item) => item.category == cat || (cat == 'General' && item.category.isEmpty)).toList();
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
      backgroundColor: isDark ? const Color(0xFF000000) : CupertinoColors.white,
      navigationBar: CupertinoNavigationBar(
        middle: Text(
          'Mind Map',
          style: TextStyle(
            color: isDark ? CupertinoColors.white : CupertinoColors.black,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.5,
          ),
        ),
        backgroundColor: (isDark ? const Color(0xFF000000) : CupertinoColors.white).withOpacity(0.8),
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
                  color: isDark ? const Color(0xFF000000) : CupertinoColors.white,
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
                        // Background Grid (Inside InteractiveViewer for perfect sync)
                        Positioned.fill(
                          child: CustomPaint(
                            painter: GridPainter(
                              isDark: isDark,
                            ),
                          ),
                        ),
                        Positioned.fill(
                          child: CustomPaint(
                            painter: MindMapPainter(
                              categories: _categories,
                              groupedItems: _groupedItems,
                              isDark: isDark,
                              customOffsets: _customOffsets,
                              viewMode: _viewMode,
                              dateCategories: _getDateCategories(),
                            ),
                          ),
                        ),
                        _buildDraggableNode(2500, 2500, 'Captures Hub', CupertinoColors.activeBlue, 'root', isCenter: true),
                        ..._buildCategoryBranches(),
                      ],
                    ),
                  ),
                ),
              ),
              // Floating Instruction Card
              Positioned(
                top: 20,
                left: 20,
                right: 20,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(15),
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      decoration: BoxDecoration(
                        color: (isDark ? Colors.black : Colors.white).withOpacity(0.7),
                        borderRadius: BorderRadius.circular(15),
                        border: Border.all(color: CupertinoColors.activeBlue.withOpacity(0.3)),
                      ),
                      child: Row(
                        children: [
                          const Icon(CupertinoIcons.info_circle_fill, color: CupertinoColors.activeBlue, size: 20),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              'Pinch to zoom, drag nodes to move them. Tap for details.',
                              style: TextStyle(
                                color: isDark ? Colors.white : Colors.black,
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              // Floating Action Buttons
              Positioned(
                bottom: 110,
                right: 20,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const SizedBox(height: 12),
                    // Vertical Menu (Animated)
                    SizedBox(
                      height: 250,
                      width: 150,
                      child: Stack(
                        alignment: Alignment.bottomRight,
                        clipBehavior: Clip.none,
                        children: [
                          _buildAnimatedMenuButton(
                            index: 2,
                            isOpen: _isMenuOpen,
                            icon: CupertinoIcons.square_grid_2x2_fill,
                            label: 'Show All',
                            bottom: 180,
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
                            icon: CupertinoIcons.calendar,
                            label: 'By Date',
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
                            icon: CupertinoIcons.folder_fill,
                            label: 'Folders',
                            bottom: 70,
                            onPressed: () {
                              setState(() {
                                _viewMode = 1;
                                _isMenuOpen = false;
                              });
                            },
                          ),
                          _buildFloatingButton(
                            icon: _isMenuOpen ? CupertinoIcons.xmark : CupertinoIcons.layers_fill,
                            label: 'View',
                            onPressed: () => setState(() => _isMenuOpen = !_isMenuOpen),
                            color: CupertinoColors.activeBlue, // Always blue
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

  void _showViewModeMenu(BuildContext context) {
    showCupertinoModalPopup(
      context: context,
      builder: (BuildContext context) => CupertinoActionSheet(
        title: const Text('Select View Mode'),
        message: const Text('Choose how you want to visualize your captures'),
        actions: <CupertinoActionSheetAction>[
          CupertinoActionSheetAction(
            child: const Text('Folders'),
            onPressed: () {
              setState(() => _viewMode = 1);
              Navigator.pop(context);
            },
          ),
          CupertinoActionSheetAction(
            child: const Text('By Date'),
            onPressed: () {
              setState(() => _viewMode = 2);
              Navigator.pop(context);
            },
          ),
          CupertinoActionSheetAction(
            child: const Text('Show All'),
            onPressed: () {
              setState(() => _viewMode = 0);
              Navigator.pop(context);
            },
          ),
        ],
        cancelButton: CupertinoActionSheetAction(
          isDefaultAction: true,
          onPressed: () {
            Navigator.pop(context);
          },
          child: const Text('Cancel'),
        ),
      ),
    );
  }

  Widget _buildSegmentLabel(String text, bool isSelected) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.bold,
          color: isSelected ? Colors.white : (CupertinoTheme.of(context).brightness == Brightness.dark ? Colors.white70 : Colors.black87),
        ),
      ),
    );
  }

  List<String> _getDateCategories() {
    final allItems = _groupedItems.values.expand((x) => x).toList();
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    final thisWeek = today.subtract(Duration(days: now.weekday));

    Set<String> activeDates = {};
    for (var item in allItems) {
      final itemDate = DateTime(item.createdAt.year, item.createdAt.month, item.createdAt.day);
      if (itemDate == today) activeDates.add('Today');
      else if (itemDate == yesterday) activeDates.add('Yesterday');
      else if (itemDate.isAfter(thisWeek)) activeDates.add('This Week');
      else if (itemDate.month == now.month && itemDate.year == now.year) activeDates.add('This Month');
      else activeDates.add('Older');
    }
    
    // Sort them in a logical order
    List<String> order = ['Today', 'Yesterday', 'This Week', 'This Month', 'Older'];
    return order.where((o) => activeDates.contains(o)).toList();
  }

  List<Widget> _buildCategoryBranches() {
    if (_viewMode == 0) {
      // "All" mode: Show all screenshots in a large circle around the hub
      List<Widget> widgets = [];
      final allItems = _groupedItems.values.expand((x) => x).toList();
      double centerX = 2500;
      double centerY = 2500;
      double radius = 550;

      for (int i = 0; i < allItems.length; i++) {
        // Golden Spiral for beautiful organic layout
        double goldenAngle = pi * (3 - sqrt(5)); 
        double theta = i * goldenAngle;
        double r = 160 + (90 * sqrt(i)); // Expands outward

        double itemX = centerX + r * cos(theta);
        double itemY = centerY + r * sin(theta);
        widgets.add(_buildDraggableItemNode(itemX, itemY, allItems[i]));
      }
      return widgets;
    }

    if (_viewMode == 2) {
      // "Date" mode: Group items by Today, Yesterday, This Week, etc.
      List<Widget> widgets = [];
      final allItems = _groupedItems.values.expand((x) => x).toList();
      
      // Sorting all items by date
      allItems.sort((a, b) => b.createdAt.compareTo(a.createdAt));

      Map<String, List<ScreenshotItem>> dateGroups = {
        'Today': [],
        'Yesterday': [],
        'This Week': [],
        'This Month': [],
        'Older': [],
      };

      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      final yesterday = today.subtract(const Duration(days: 1));
      final thisWeek = today.subtract(Duration(days: now.weekday));

      for (var item in allItems) {
        final itemDate = DateTime(item.createdAt.year, item.createdAt.month, item.createdAt.day);
        if (itemDate == today) {
          dateGroups['Today']!.add(item);
        } else if (itemDate == yesterday) {
          dateGroups['Yesterday']!.add(item);
        } else if (itemDate.isAfter(thisWeek)) {
          dateGroups['This Week']!.add(item);
        } else if (itemDate.month == now.month && itemDate.year == now.year) {
          dateGroups['This Month']!.add(item);
        } else {
          dateGroups['Older']!.add(item);
        }
      }

      // Remove empty groups
      dateGroups.removeWhere((key, value) => value.isEmpty);
      final activeDates = dateGroups.keys.toList();

      double centerX = 2500;
      double centerY = 2500;
        double radius = 600; // Increased for more space

        for (int i = 0; i < activeDates.length; i++) {
          double angle = (2 * pi * i) / activeDates.length;
          double catX = centerX + radius * cos(angle);
          double catY = centerY + radius * sin(angle);

          widgets.add(_buildDraggableNode(catX, catY, activeDates[i], CupertinoColors.systemIndigo, 'date_${activeDates[i]}'));

          final items = dateGroups[activeDates[i]]!;
          
          for (int j = 0; j < items.length; j++) {
            // Concentric circle layout for many items
            int layer = (j / 6).floor();
            int indexInLayer = j % 6;
            int itemsInThisLayer = (j >= (layer * 6) && j < (layer + 1) * 6) 
                ? min(6, items.length - layer * 6) 
                : 6;

            double layerRadius = 220.0 + (layer * 140.0);
            double arcSweep = pi / (1.2 + (layer * 0.2));
            double subAngle = angle - (arcSweep / 2) + (arcSweep * indexInLayer / (itemsInThisLayer > 1 ? itemsInThisLayer - 1 : 1));
            if (itemsInThisLayer == 1) subAngle = angle;
            
            double itemX = catX + layerRadius * cos(subAngle);
            double itemY = catY + layerRadius * sin(subAngle);
            widgets.add(_buildDraggableItemNode(itemX, itemY, items[j]));
          }
        }
      return widgets;
    }

    // "Folder" mode (Current implementation)
    List<Widget> widgets = [];
    double centerX = 2500;
    double centerY = 2500;
      double radius = 600; // Increased for more space

    for (int i = 0; i < _categories.length; i++) {
      double angle = (2 * pi * i) / _categories.length;
      // Staggered radii for dynamic constellation layout
      double catRadius = 750.0 + (i % 2 == 0 ? 0 : 350.0);
      double catX = centerX + catRadius * cos(angle);
      double catY = centerY + catRadius * sin(angle);

      final color = _getCategoryColor(i);
      widgets.add(_buildDraggableNode(catX, catY, _categories[i], color, 'cat_${_categories[i]}'));

      final items = _groupedItems[_categories[i]] ?? [];
      
      for (int j = 0; j < items.length; j++) {
        // Planetary Rings layout
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
        
        double itemX = catX + ringRadius * cos(theta);
        double itemY = catY + ringRadius * sin(theta);
        widgets.add(_buildDraggableItemNode(itemX, itemY, items[j]));
      }
    }
    return widgets;
  }

  Widget _buildDraggableNode(double defX, double defY, String label, Color color, String id, {bool isCenter = false}) {
    final pos = _getNodePos(id, defX, defY);
    return Positioned(
      left: pos.dx - (isCenter ? 70 : 55),
      top: pos.dy - (isCenter ? 70 : 55),
      child: GestureDetector(
        onPanUpdate: (details) {
          // Direct update for better performance
          _customOffsets[id] = pos + details.delta;
          setState(() {}); 
        },
        onTap: () {
          if (!isCenter) {
            final categoryName = label;
            final items = _groupedItems[categoryName] ?? [];
            Navigator.push(
              context,
              CupertinoPageRoute(
                builder: (context) => CategoryDetailScreen(
                  category: categoryName,
                  items: items,
                ),
              ),
            );
          }
        },
        child: AnimatedScale(
          scale: 1.0, // Can be expanded for hover effects later
          duration: const Duration(milliseconds: 200),
          child: Column(
          children: [
            Container(
              width: isCenter ? 140 : 110,
              height: isCenter ? 140 : 110,
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  colors: [color.withOpacity(0.4), color.withOpacity(0.1)],
                ),
                shape: BoxShape.circle,
                border: Border.all(color: color.withOpacity(0.6), width: 2),
                boxShadow: [
                  BoxShadow(
                    color: color.withOpacity(0.3),
                    blurRadius: 15,
                    spreadRadius: 2,
                  ),
                ],
              ),
              child: Container(
                margin: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.2),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  isCenter ? CupertinoIcons.sparkles : CupertinoIcons.folder_fill,
                  color: color,
                  size: isCenter ? 50 : 35,
                ),
              ),
            ),
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              decoration: BoxDecoration(
                color: color.withOpacity(0.9),
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 5),
                ],
              ),
              child: Text(
                label,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.5,
                ),
              ),
            ),
          ],
        ),
      ),
    ),
    );
  }

  Widget _buildDraggableItemNode(double defX, double defY, ScreenshotItem item) {
    final pos = _getNodePos(item.id, defX, defY);
    return Positioned(
      left: pos.dx - 50,
      top: pos.dy - 60,
      child: GestureDetector(
        onPanUpdate: (details) {
          _customOffsets[item.id] = pos + details.delta;
          setState(() {});
        },
        onTap: () => Navigator.push(
          context,
          CupertinoPageRoute(builder: (context) => CaptureDetailsScreen(item: item)),
        ),
        child: Container(
          width: 100,
          height: 130,
          padding: const EdgeInsets.all(5),
          decoration: BoxDecoration(
            color: CupertinoColors.systemBackground.withOpacity(0.8),
            borderRadius: BorderRadius.circular(15),
            border: Border.all(color: CupertinoColors.activeBlue.withOpacity(0.3)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.2),
                blurRadius: 10,
                offset: const Offset(0, 5),
              ),
            ],
          ),
          child: Column(
            children: [
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      Image.file(
                        File(item.path),
                        fit: BoxFit.cover,
                        cacheWidth: 200,
                        errorBuilder: (c, e, s) => Container(
                          color: CupertinoColors.systemGrey6,
                          child: const Icon(CupertinoIcons.photo, size: 30, color: CupertinoColors.systemGrey),
                        ),
                      ),
                      // Overlay gradient for better text readability if needed
                      Positioned.fill(
                        child: Container(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [Colors.transparent, Colors.black.withOpacity(0.2)],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 6),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: Text(
                  item.note.isEmpty ? 'Screenshot' : item.note,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    letterSpacing: -0.2,
                  ),
                ),
              ),
              const SizedBox(height: 4),
            ],
          ),
        ),
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
      duration: Duration(milliseconds: 250 + (index * 50)),
      curve: Curves.easeOutBack,
      bottom: isOpen ? bottom : 0,
      right: 0,
      child: AnimatedOpacity(
        duration: const Duration(milliseconds: 200),
        opacity: isOpen ? 1.0 : 0.0,
        child: AnimatedScale(
          duration: const Duration(milliseconds: 300),
          scale: isOpen ? 1.0 : 0.5,
          curve: Curves.easeOutBack,
          child: _buildSmallMenuButton(icon: icon, label: label, onPressed: onPressed),
        ),
      ),
    );
  }

  Widget _buildSmallMenuButton({required IconData icon, required String label, required VoidCallback onPressed}) {
    return _buildFloatingButton(
      icon: icon, 
      label: label, 
      onPressed: onPressed,
      color: CupertinoColors.activeBlue.withOpacity(0.8),
    );
  }

  Widget _buildFloatingButton({required IconData icon, required String label, required VoidCallback onPressed, Color color = CupertinoColors.activeBlue}) {
    return GestureDetector(
      onTap: onPressed,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(15),
          // Removed glow shadows
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: Colors.white, size: 18),
            const SizedBox(width: 8),
            Text(label, style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold)),
          ],
        ),
      ),
    );
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

  MindMapPainter({
    required this.categories, 
    required this.groupedItems, 
    required this.isDark,
    required this.customOffsets,
    required this.viewMode,
    required this.dateCategories,
  });

  Offset _getPos(String id, double defX, double defY) {
    return customOffsets[id] ?? Offset(defX, defY);
  }

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = CupertinoColors.activeBlue.withOpacity(0.3)
      ..strokeWidth = 3.5 
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..isAntiAlias = true;

    final double defCenterX = 2500.0;
    final double defCenterY = 2500.0;
    final centerPos = _getPos('root', defCenterX, defCenterY);
    
    final radius = 600.0; // Synced with builder

    if (categories.isEmpty) return;

    if (groupedItems.values.expand((x) => x).isEmpty) return;
    
    if (viewMode == 0) {
      // All mode: Draw lines directly from hub to all items
      final allItems = groupedItems.values.expand((x) => x).toList();
      for (int i = 0; i < allItems.length; i++) {
        double goldenAngle = pi * (3 - sqrt(5)); 
        double theta = i * goldenAngle;
        double r = 160 + (90 * sqrt(i));

        double defItemX = defCenterX + r * cos(theta);
        double defItemY = defCenterY + r * sin(theta);
        final itemPos = _getPos(allItems[i].id, defItemX, defItemY);

        Path path = Path();
        path.moveTo(centerPos.dx, centerPos.dy);
        double ctrlX = (centerPos.dx + itemPos.dx) / 2 + 30 * cos(theta + pi/2);
        double ctrlY = (centerPos.dy + itemPos.dy) / 2 + 30 * sin(theta + pi/2);
        path.quadraticBezierTo(ctrlX, ctrlY, itemPos.dx, itemPos.dy);
        
        // Organic Glow
        paint.strokeWidth = 4.0;
        paint.color = CupertinoColors.activeBlue.withOpacity(0.04);
        paint.shader = null;
        canvas.drawPath(path, paint);

        paint.strokeWidth = 1.5;
        paint.color = CupertinoColors.activeBlue.withOpacity(0.15);
        canvas.drawPath(path, paint);
      }
    } else if (viewMode == 2) {
      // Date mode
      final allItems = groupedItems.values.expand((x) => x).toList();
      allItems.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      final yesterday = today.subtract(const Duration(days: 1));
      final thisWeek = today.subtract(Duration(days: now.weekday));

      Map<String, List<ScreenshotItem>> dateGroups = {};
      for (var item in allItems) {
        final itemDate = DateTime(item.createdAt.year, item.createdAt.month, item.createdAt.day);
        String label = 'Older';
        if (itemDate == today) label = 'Today';
        else if (itemDate == yesterday) label = 'Yesterday';
        else if (itemDate.isAfter(thisWeek)) label = 'This Week';
        else if (itemDate.month == now.month && itemDate.year == now.year) label = 'This Month';
        
        if (!dateGroups.containsKey(label)) dateGroups[label] = [];
        dateGroups[label]!.add(item);
      }

      for (int i = 0; i < dateCategories.length; i++) {
        String label = dateCategories[i];
        double angle = (2 * pi * i) / dateCategories.length;
        double defCatX = defCenterX + radius * cos(angle);
        double defCatY = defCenterY + radius * sin(angle);
        final catPos = _getPos('date_$label', defCatX, defCatY);

        Path path = Path();
        path.moveTo(centerPos.dx, centerPos.dy);
        double ctrlX = (centerPos.dx + catPos.dx) / 2 + 60 * cos(angle + pi/2);
        double ctrlY = (centerPos.dy + catPos.dy) / 2 + 60 * sin(angle + pi/2);
        path.quadraticBezierTo(ctrlX, ctrlY, catPos.dx, catPos.dy);
        
        // Glow effect for Date branches
        paint.strokeWidth = 6.0;
        paint.color = CupertinoColors.systemIndigo.withOpacity(0.08);
        paint.shader = null;
        canvas.drawPath(path, paint);

        paint.strokeWidth = 2.5;
        final indigoGradient = LinearGradient(
          colors: [CupertinoColors.systemIndigo.withOpacity(0.2), CupertinoColors.systemIndigo.withOpacity(0.7)],
        ).createShader(Rect.fromPoints(centerPos, catPos));
        paint.shader = indigoGradient;
        canvas.drawPath(path, paint);

        final items = dateGroups[label] ?? [];
        
        for (int j = 0; j < items.length; j++) {
          int layer = (j / 6).floor();
          int indexInLayer = j % 6;
          int itemsInThisLayer = (j >= (layer * 6) && j < (layer + 1) * 6) 
                ? min(6, items.length - layer * 6) 
                : 6;

          double layerRadius = 220.0 + (layer * 140.0);
          double arcSweep = pi / (1.2 + (layer * 0.2));
          double subAngle = angle - (arcSweep / 2) + (arcSweep * indexInLayer / (itemsInThisLayer > 1 ? itemsInThisLayer - 1 : 1));
          if (itemsInThisLayer == 1) subAngle = angle;
          
          double defItemX = defCatX + layerRadius * cos(subAngle);
          double defItemY = defCatY + layerRadius * sin(subAngle);
          final itemPos = _getPos(items[j].id, defItemX, defItemY);
          
          Path subPath = Path();
          subPath.moveTo(catPos.dx, catPos.dy);
          double sCtrlX = (catPos.dx + itemPos.dx) / 2 + 40 * cos(subAngle + pi/2);
          double sCtrlY = (catPos.dy + itemPos.dy) / 2 + 40 * sin(subAngle + pi/2);
          subPath.quadraticBezierTo(sCtrlX, sCtrlY, itemPos.dx, itemPos.dy);
          
          paint.shader = null;
          paint.strokeWidth = 1.5;
          paint.color = CupertinoColors.systemIndigo.withOpacity(0.4);
          canvas.drawPath(subPath, paint);
        }
      }
    } else {
      // Folder mode
      for (int i = 0; i < categories.length; i++) {
        double angle = (2 * pi * i) / categories.length;
        double catRadius = 750.0 + (i % 2 == 0 ? 0 : 350.0);
        double defCatX = defCenterX + catRadius * cos(angle);
        double defCatY = defCenterY + catRadius * sin(angle);
        final catPos = _getPos('cat_${categories[i]}', defCatX, defCatY);
        // Draw curved line from Center to Category with a "Glow" effect
        Path path = Path();
        path.moveTo(centerPos.dx, centerPos.dy);
        double ctrlX = (centerPos.dx + catPos.dx) / 2 + 60 * cos(angle + pi/2);
        double ctrlY = (centerPos.dy + catPos.dy) / 2 + 60 * sin(angle + pi/2);
        path.quadraticBezierTo(ctrlX, ctrlY, catPos.dx, catPos.dy);
        
        // Outer Glow
        paint.strokeWidth = 6.0;
        paint.color = CupertinoColors.activeBlue.withOpacity(isDark ? 0.05 : 0.03);
        paint.shader = null;
        canvas.drawPath(path, paint);

        // Inner Line
        paint.strokeWidth = 2.5;
        final lineGradient = LinearGradient(
          colors: [
            CupertinoColors.activeBlue.withOpacity(isDark ? 0.2 : 0.3), 
            CupertinoColors.activeBlue.withOpacity(isDark ? 0.8 : 0.9)
          ],
        ).createShader(Rect.fromPoints(centerPos, catPos));
        paint.shader = lineGradient;
        canvas.drawPath(path, paint);

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
          
          double defItemX = defCatX + ringRadius * cos(theta);
          double defItemY = defCatY + ringRadius * sin(theta);
          final itemPos = _getPos(items[j].id, defItemX, defItemY);
          
          Path subPath = Path();
          subPath.moveTo(catPos.dx, catPos.dy);
          double sCtrlX = (catPos.dx + itemPos.dx) / 2 + 40 * cos(theta + pi/2);
          double sCtrlY = (catPos.dy + itemPos.dy) / 2 + 40 * sin(theta + pi/2);
          subPath.quadraticBezierTo(sCtrlX, sCtrlY, itemPos.dx, itemPos.dy);
          
          paint.shader = null;
          paint.strokeWidth = 1.5;
          paint.color = CupertinoColors.activeBlue.withOpacity(isDark ? 0.25 : 0.35);
          canvas.drawPath(subPath, paint);
        }
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

class GridPainter extends CustomPainter {
  final bool isDark;
  GridPainter({required this.isDark});

  @override
  void paint(Canvas canvas, Size size) {
    // 1. Draw an ultra-subtle radial glow centered at the hub (2500, 2500)
    final Offset hubCenter = Offset(size.width / 2, size.height / 2);
    final Paint glowPaint = Paint()
      ..shader = RadialGradient(
        center: Alignment.center,
        colors: [
          (isDark ? CupertinoColors.activeBlue : CupertinoColors.activeBlue).withOpacity(isDark ? 0.08 : 0.06),
          Colors.transparent,
        ],
      ).createShader(Rect.fromCircle(center: hubCenter, radius: 1800));
    
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), glowPaint);

    // 2. Draw Ultra-faint Dot Grid
    final Paint dotPaint = Paint()
      ..color = (isDark ? CupertinoColors.white : CupertinoColors.activeBlue).withOpacity(isDark ? 0.08 : 0.04)
      ..strokeCap = StrokeCap.round
      ..strokeWidth = 1.5;

    const double spacing = 100.0; // Larger spacing for a cleaner look

    List<Offset> points = [];
    for (double x = 0; x <= size.width; x += spacing) {
      for (double y = 0; y <= size.height; y += spacing) {
        points.add(Offset(x, y));
      }
    }
    
    canvas.drawPoints(PointMode.points, points, dotPaint);
  }

  @override
  bool shouldRepaint(covariant GridPainter oldDelegate) {
    return oldDelegate.isDark != isDark;
  }
}
