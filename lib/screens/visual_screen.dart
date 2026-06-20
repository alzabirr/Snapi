import 'dart:io';
import 'dart:math';
import 'dart:ui';
import 'dart:convert';
import 'package:flutter/material.dart';
import '../models/screenshot_item.dart';
import '../services/database_service.dart';
import 'dart:async';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:flutter/services.dart';
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
  int _viewMode = 1; // 0: Overview, 1: Clusters, 2: Timeline, 3: Network
  bool _isMenuOpen = false;
  String? _draggedId;

  Timer? _debounceTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _transformationController = TransformationController();
    _loadData();
    
    DatabaseService.box.listenable().addListener(_onDatabaseChange);
    DatabaseService.categoryNotifier.addListener(_onDatabaseChange);

    _waveController = AnimationController(
      duration: const Duration(seconds: 4),
      vsync: this,
    )..repeat();
  }

  void _onDatabaseChange() {
    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 1000), () {
      if (mounted) _loadData(isAutoRefresh: true);
    });
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
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
    const double scale = 0.25;
    final tx = (viewportSize.width / 2) - (4000.0 * scale);
    final ty = (viewportSize.height / 2) - (4000.0 * scale);
    _transformationController.value = Matrix4.identity()..translate(tx, ty)..scale(scale);
  }

  Future<void> _saveOffsets() async {
    final prefs = await SharedPreferences.getInstance();
    final Map<String, String> encoded = {};
    _customOffsets.forEach((key, value) {
      encoded[key] = '${value.dx},${value.dy}';
    });
    await prefs.setString('visual_offsets', jsonEncode(encoded));
  }

  Future<void> _loadData({bool isAutoRefresh = false}) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      var cats = prefs.getStringList('user_categories');
      if (cats == null || cats.isEmpty) cats = ['Uncategorized', 'Personal'];
      cats = cats.toSet().toList();

      final savedStr = prefs.getString('visual_offsets');
      if (savedStr != null) {
        final Map<String, dynamic> decoded = jsonDecode(savedStr);
        decoded.forEach((key, value) {
          final parts = value.toString().split(',');
          if (parts.length == 2) {
            _customOffsets[key] = Offset(double.parse(parts[0]), double.parse(parts[1]));
          }
        });
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
        if (!isAutoRefresh) _initialCentered = false;
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Offset _getNodePos(String id, double defX, double defY) {
    final key = 'mode_${_viewMode}_$id';
    return _customOffsets[key] ?? Offset(defX, defY);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    if (_isLoading) return Center(child: CircularProgressIndicator(color: theme.colorScheme.primary));
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text(
          'VISUAL',
          style: TextStyle(
            color: theme.colorScheme.onSurface,
            fontWeight: FontWeight.w800,
          ),
        ),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          if (!_initialCentered) {
            _initialCentered = true;
            WidgetsBinding.instance.addPostFrameCallback((_) => _centerView(Size(constraints.maxWidth, constraints.maxHeight)));
          }
          return Stack(
            children: [
              if (_isMenuOpen)
                Positioned.fill(
                  child: GestureDetector(
                    onTap: () => setState(() => _isMenuOpen = false),
                    child: Container(color: Colors.black.withOpacity(0.3)),
                  ),
                ),
              InteractiveViewer(
                transformationController: _transformationController,
                boundaryMargin: const EdgeInsets.all(4000),
                minScale: 0.05,
                maxScale: 2.5,
                constrained: false, 
                child: SizedBox(
                  width: 8000,
                  height: 8000,
                  child: RepaintBoundary(
                    child: Stack(
                      clipBehavior: Clip.none,
                      children: [
                        ...(() {
                          final List<Widget> backgroundAndLines = [
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
                                  canvasSize: 8000,
                                  primaryColor: theme.colorScheme.primary,
                                ),
                              ),
                            ),
                          ];

                          final List<Widget> nodes = [
                            _buildDraggableNode(4000, 4000, '', theme.colorScheme.primary, 'root', isCenter: true),
                            ..._buildCategoryBranches(),
                          ];

                          if (_draggedId != null) {
                            Widget? draggedWidget;
                            final List<Widget> otherNodes = [];
                            
                            for (var node in nodes) {
                              if (node.key == ValueKey(_draggedId)) {
                                draggedWidget = node;
                              } else {
                                otherNodes.add(node);
                              }
                            }
                            
                            return [...backgroundAndLines, ...otherNodes, if (draggedWidget != null) draggedWidget];
                          }
                          
                          return [...backgroundAndLines, ...nodes];
                        })(),
                      ],
                    ),
                  ),
                ),
              ),
              
              // Instruction
              Positioned(
                top: 20, left: 20, right: 20,
                child: AnimatedOpacity(
                  duration: const Duration(milliseconds: 200),
                  opacity: _draggedId != null ? 0.0 : 1.0,
                  child: _buildInstructionCard(isDark),
                ),
              ),

              // Reset Button on the Right Side
              Positioned(
                bottom: 385, right: 20,
                child: AnimatedOpacity(
                  duration: const Duration(milliseconds: 200),
                  opacity: _draggedId != null ? 0.0 : 1.0,
                  child: _VisualResetButton(onTap: _resetLayout),
                ),
              ),

              // Floating Menu on the Bottom Right
              Positioned(
                bottom: 110, right: 20,
                child: AnimatedOpacity(
                  duration: const Duration(milliseconds: 200),
                  opacity: _draggedId != null ? 0.0 : 1.0,
                  child: _buildFloatingMenu(),
                ),
              ),
            ],
          );
        }
      ),
    );
  }

  void _resetLayout() async {
    setState(() {
      _customOffsets.removeWhere((key, value) => key.startsWith('mode_${_viewMode}_'));
    });
    await _saveOffsets();
    
    final double scale = 0.25;
    final Size viewportSize = MediaQuery.of(context).size;
    final tx = (viewportSize.width / 2) - (4000.0 * scale);
    final ty = (viewportSize.height / 2) - (4000.0 * scale);
    
    final targetMatrix = Matrix4.identity()..translate(tx, ty)..scale(scale);
    
    final AnimationController animController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );
    final Matrix4Tween tween = Matrix4Tween(
      begin: _transformationController.value,
      end: targetMatrix,
    );
    final Animation<Matrix4> animation = tween.animate(
      CurvedAnimation(parent: animController, curve: Curves.easeInOutCubic),
    );
    animation.addListener(() {
      _transformationController.value = animation.value;
    });
    animController.forward().then((_) => animController.dispose());
    
    HapticFeedback.mediumImpact();
  }

  Widget _buildInstructionCard(bool isDark) {
    final theme = Theme.of(context);
    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            color: (isDark ? Colors.black : Colors.white).withOpacity(0.4),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: theme.colorScheme.primary.withOpacity(0.2)),
          ),
          child: Row(
            children: [
              Icon(Icons.auto_awesome, color: theme.colorScheme.primary, size: 20),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  _viewMode == 3 ? 'Social Network Graph enabled. Drag nodes freely.' : 'Explore your visual catalog. Drag nodes to move.',
                  style: TextStyle(color: theme.colorScheme.onSurface, fontSize: 13, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFloatingMenu() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          height: 250,
          width: 160,
          child: Stack(
            alignment: Alignment.bottomRight,
            children: [
              _buildAnimatedMenuButton(index: 2, isOpen: _isMenuOpen, icon: Icons.grid_view, label: 'Overview', bottom: 185, onPressed: () => setState(() { _viewMode = 0; _isMenuOpen = false; })),
              _buildAnimatedMenuButton(index: 1, isOpen: _isMenuOpen, icon: Icons.access_time_filled, label: 'Timeline', bottom: 125, onPressed: () => setState(() { _viewMode = 2; _isMenuOpen = false; })),
              _buildAnimatedMenuButton(index: 0, isOpen: _isMenuOpen, icon: Icons.folder, label: 'Clusters', bottom: 65, onPressed: () => setState(() { _viewMode = 1; _isMenuOpen = false; })),
              _buildFloatingButton(icon: _isMenuOpen ? Icons.close : Icons.tune, label: 'Layout', onPressed: () => setState(() => _isMenuOpen = !_isMenuOpen)),
            ],
          ),
        ),
      ],
    );
  }

  List<Widget> _buildCategoryBranches() {
    List<Widget> widgets = [];
    double centerX = 4000;
    double centerY = 4000;
    final theme = Theme.of(context);

    if (_viewMode == 0) {
      final allItems = _groupedItems.values.expand((x) => x).toList();
      for (int i = 0; i < allItems.length; i++) {
        double theta = i * (pi * (3 - sqrt(5))); 
        double r = 160 + (90 * sqrt(i));
        widgets.add(_buildDraggableItemNode(centerX + r * cos(theta), centerY + r * sin(theta), allItems[i]));
      }
    } else if (_viewMode == 2) {
      final dateCategories = _getDateCategories();
      final double total = dateCategories.isEmpty ? 1.0 : dateCategories.length.toDouble();
      for (int i = 0; i < dateCategories.length; i++) {
        double angle = (2 * pi * i) / total;
        double defCatX = centerX + 600 * cos(angle);
        double defCatY = centerY + 600 * sin(angle);
        final String nodeId = 'date_${dateCategories[i]}';
        widgets.add(_buildDraggableNode(defCatX, defCatY, dateCategories[i], Colors.indigo, nodeId));
        final items = _groupedItems.values.expand((x) => x).where((it) => '${it.createdAt.day} ${_getMonthName(it.createdAt.month)} ${it.createdAt.year}' == dateCategories[i]).toList();
        final catPos = _getNodePos(nodeId, defCatX, defCatY);
        for (int j = 0; j < items.length; j++) {
          double r = 220.0 + (j / 6).floor() * 140.0;
          double subAngle = angle - (pi/1.5) / 2 + (pi/1.5) * (j%6) / 5;
          widgets.add(_buildDraggableItemNode(catPos.dx + r * cos(subAngle), catPos.dy + r * sin(subAngle), items[j]));
        }
      }
    } else {
      final double total = _categories.isEmpty ? 1.0 : _categories.length.toDouble();
      for (int i = 0; i < _categories.length; i++) {
        double angle = (2 * pi * i) / total;
        double r = 750.0 + (i % 2 * 350.0);
        double defCatX = centerX + r * cos(angle);
        double defCatY = centerY + r * sin(angle);
        final String nodeId = 'cat_${_categories[i]}';
        widgets.add(_buildDraggableNode(defCatX, defCatY, _categories[i], _getCategoryColor(i), nodeId));
        final catPos = _getNodePos(nodeId, defCatX, defCatY);
        final items = _groupedItems[_categories[i]] ?? [];
        for (int j = 0; j < items.length; j++) {
          int ring = 1 + (j ~/ 6);
          double theta = angle + (2 * pi * (j % 6)) / 6 + (ring * 0.3);
          widgets.add(_buildDraggableItemNode(catPos.dx + (140.0 + ring * 110.0) * cos(theta), catPos.dy + (140.0 + ring * 110.0) * sin(theta), items[j]));
        }
      }
    }
    return widgets;
  }

  Widget _buildDraggableNode(double defX, double defY, String label, Color color, String id, {bool isCenter = false}) {
    final pos = _getNodePos(id, defX, defY);
    final isDragging = _draggedId == id;
    final theme = Theme.of(context);
    
    return Positioned(
      key: ValueKey('node_$id'),
      left: pos.dx - (isCenter ? 75 : 60),
      top: pos.dy - (isCenter ? 75 : 60),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onPanStart: (_) {
          HapticFeedback.mediumImpact();
          setState(() => _draggedId = 'node_$id');
        },
        onPanUpdate: (details) {
          setState(() {
            final double scale = _transformationController.value.getMaxScaleOnAxis();
            _customOffsets['mode_${_viewMode}_$id'] = (_customOffsets['mode_${_viewMode}_$id'] ?? Offset(defX, defY)) + (details.delta / (scale > 0 ? scale : 1.0)) * 0.48;
          });
        },
        onPanEnd: (_) {
          setState(() => _draggedId = null);
          _saveOffsets();
        },
        onTap: () { if (!isCenter) Navigator.push(context, MaterialPageRoute(builder: (c) => CategoryDetailScreen(category: label, items: _groupedItems[label] ?? []))); },
        child: AnimatedBuilder(
          animation: _waveController,
          builder: (c, child) {
            double wave = sin((_waveController.value * 2 * pi) + (id.hashCode % 10));
            double scale = isDragging ? 1.1 : (isCenter ? 1.0 + wave * 0.05 : 1.0);
            return Transform.scale(scale: scale, child: Transform.translate(offset: Offset(0, wave * (isCenter ? 4 : 8)), child: child));
          },
        child: RepaintBoundary(
          child: Column(
            children: [
              Container(
                width: isCenter ? 150 : 120, height: isCenter ? 150 : 120,
                decoration: BoxDecoration(
                  color: color.withOpacity(isDragging ? 0.6 : 0.4), shape: BoxShape.circle,
                  border: Border.all(color: color.withOpacity(0.7), width: 3),
                  boxShadow: [
                    BoxShadow(
                      color: color.withOpacity(isDragging ? 0.5 : 0.3), 
                      blurRadius: isDragging ? 40 : 20,
                      spreadRadius: isDragging ? 5 : 0,
                    ),
                    if (isDragging) BoxShadow(color: Colors.black.withOpacity(0.2), blurRadius: 20, offset: const Offset(0, 10)),
                  ],
                ),
                child: Center(
                  child: Container(
                    margin: const EdgeInsets.all(12),
                    decoration: BoxDecoration(color: color.withOpacity(0.4), shape: BoxShape.circle),
                    child: isCenter 
                      ? ClipRRect(borderRadius: BorderRadius.circular(75), child: Image.asset('assets/krabby.png', fit: BoxFit.cover)) 
                      : const Icon(Icons.folder, color: Colors.white, size: 40),
                  ),
                ),
              ),
              if (label.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(
                  label, 
                  style: TextStyle(
                    color: theme.colorScheme.onSurface, 
                    fontSize: 14, 
                    fontWeight: FontWeight.w900,
                    shadows: [
                      Shadow(color: (theme.brightness == Brightness.dark ? Colors.black : Colors.white).withOpacity(0.5), blurRadius: 4)
                    ]
                  )
                ),
              ]
            ],
          ),
        ),
        ),
      ),
    );
  }

  Widget _buildDraggableItemNode(double defX, double defY, ScreenshotItem item) {
    final pos = _getNodePos(item.id, defX, defY);
    final isDragging = _draggedId == 'item_${item.id}';
    final theme = Theme.of(context);
    
    return Positioned(
      key: ValueKey('item_${item.id}'),
      left: pos.dx - 60, top: pos.dy - 75,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onPanStart: (_) {
          HapticFeedback.mediumImpact();
          setState(() => _draggedId = 'item_${item.id}');
        },
        onPanUpdate: (details) {
          setState(() {
            final double scale = _transformationController.value.getMaxScaleOnAxis();
            _customOffsets['mode_${_viewMode}_${item.id}'] = (_customOffsets['mode_${_viewMode}_${item.id}'] ?? Offset(defX, defY)) + (details.delta / (scale > 0 ? scale : 1.0)) * 0.48;
          });
        },
        onPanEnd: (_) {
          final draggedIdCopy = _draggedId;
          setState(() => _draggedId = null);
          _saveOffsets();
          
          if (draggedIdCopy != null && draggedIdCopy.startsWith('item_')) {
            final itemId = draggedIdCopy.substring(5);
            final itemPos = _customOffsets['mode_${_viewMode}_$itemId'];
            if (itemPos != null) {
              for (int i = 0; i < _categories.length; i++) {
                final String cat = _categories[i];
                final String catNodeId = 'cat_${cat}_$i';
                final catPos = _getNodePos(catNodeId, 0, 0);
                if ((itemPos - catPos).distance < 120) {
                  final item = _findItemById(itemId);
                  if (item != null && item.category != cat) {
                    DatabaseService.updateItemCategory(item, cat);
                    _showDropToast(cat);
                  }
                  break;
                }
              }
            }
          }
        },
        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (c) => CaptureDetailsScreen(item: item))),
        child: AnimatedBuilder(
          animation: _waveController,
          builder: (c, child) {
            double wave = sin((_waveController.value * 2 * pi) + (item.id.hashCode % 10));
            return Transform.scale(
              scale: isDragging ? 1.15 : 1.0, 
              child: Transform.translate(offset: Offset(0, wave * 6), child: child)
            );
          },
          child: RepaintBoundary(
            child: Container(
              width: 110, height: 140,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(isDragging ? 0.4 : 0.25), 
                    blurRadius: isDragging ? 35 : 18, 
                    offset: isDragging ? const Offset(0, 15) : const Offset(0, 6),
                  ),
                  if (isDragging) BoxShadow(color: theme.colorScheme.primary.withOpacity(0.4), blurRadius: 20, spreadRadius: 2),
                ],
              ),
              child: Stack(
                children: [
                  Positioned.fill(
                     child: ClipRRect(
                      borderRadius: BorderRadius.circular(20),
                      child: Image.file(
                        File(item.path), 
                        fit: BoxFit.cover, 
                        cacheWidth: 180,
                        errorBuilder: (context, error, stackTrace) => Container(
                          color: theme.colorScheme.surfaceVariant,
                          child: Center(child: Icon(Icons.photo_library, color: theme.colorScheme.onSurfaceVariant, size: 30)),
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    bottom: 0, left: 0, right: 0,
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 10),
                      decoration: BoxDecoration(
                        color: (theme.brightness == Brightness.dark ? Colors.black : Colors.white).withOpacity(0.6),
                        borderRadius: const BorderRadius.vertical(bottom: Radius.circular(20)),
                      ),
                      child: Text(
                        item.note.isEmpty ? 'Capture' : item.note, 
                        maxLines: 1, overflow: TextOverflow.ellipsis, textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 10, 
                          fontWeight: FontWeight.bold, 
                          color: theme.colorScheme.onSurface,
                          letterSpacing: 0.3
                        )
                      ),
                    ),
                  ),
                  if (!File(item.path).existsSync())
                    Positioned.fill(
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.6),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.delete, color: Colors.red, size: 35),
                            const SizedBox(height: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: Colors.red.withOpacity(0.8),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: const Text(
                                'Removed from Gallery',
                                style: TextStyle(color: Colors.white, fontSize: 8, fontWeight: FontWeight.bold),
                                textAlign: TextAlign.center,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  List<String> _getDateCategories() {
    final allItems = _groupedItems.values.expand((x) => x).toList();
    allItems.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    List<String> res = [];
    for (var it in allItems) {
      final s = '${it.createdAt.day} ${_getMonthName(it.createdAt.month)} ${it.createdAt.year}';
      if (!res.contains(s)) res.add(s);
    }
    return res;
  }

  ScreenshotItem? _findItemById(String id) {
    for (var list in _groupedItems.values) {
      for (var item in list) {
        if (item.id == id) return item;
      }
    }
    return null;
  }

  void _showDropToast(String category) {
    final theme = Theme.of(context);
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (context) {
        Future.delayed(const Duration(seconds: 1), () {
          if (Navigator.canPop(context)) Navigator.pop(context);
        });
        return Center(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            decoration: BoxDecoration(
              color: theme.colorScheme.primary.withOpacity(0.9),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              'Moved to $category',
              style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold, decoration: TextDecoration.none),
            ),
          ),
        );
      },
    );
  }

  String _getMonthName(int m) => ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'][m - 1];
  Color _getCategoryColor(int i) => [Colors.purple, Colors.orange, Colors.pink, Colors.teal, Colors.green, Colors.indigo][i % 6];

  Widget _buildAnimatedMenuButton({required int index, required bool isOpen, required IconData icon, required String label, required double bottom, required VoidCallback onPressed}) {
    return AnimatedPositioned(
      duration: Duration(milliseconds: 300 + (index * 60)), curve: Curves.easeOutQuart,
      bottom: isOpen ? bottom : 0, right: 0,
      child: AnimatedOpacity(
        duration: const Duration(milliseconds: 200), opacity: isOpen ? 1.0 : 0.0,
        child: AnimatedScale(duration: const Duration(milliseconds: 400), scale: isOpen ? 1.0 : 0.4, curve: Curves.easeOutBack, child: _buildFloatingButton(icon: icon, label: label, onPressed: onPressed)),
      ),
    );
  }

  Widget _buildFloatingButton({required IconData icon, required String label, required VoidCallback onPressed, Color? color}) {
    final theme = Theme.of(context);
    final buttonColor = color ?? theme.colorScheme.primary;
    return GestureDetector(
      onTap: onPressed,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
        decoration: BoxDecoration(color: buttonColor, borderRadius: BorderRadius.circular(18)),
        child: Row(mainAxisSize: MainAxisSize.min, children: [Icon(icon, color: Colors.white, size: 20), const SizedBox(width: 10), Text(label, style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold))]),
      ),
    );
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
  final double canvasSize;
  final Color primaryColor;

  MindMapPainter({required this.categories, required this.groupedItems, required this.isDark, required this.customOffsets, required this.viewMode, required this.dateCategories, required this.getMonthName, required this.canvasSize, required this.primaryColor});

  Offset _getPos(String id, double defX, double defY) => customOffsets['mode_${viewMode}_$id'] ?? Offset(defX, defY);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = primaryColor.withOpacity(isDark ? 0.2 : 0.3)..strokeWidth = 2.0..style = PaintingStyle.stroke..strokeCap = StrokeCap.round;
    final double center = canvasSize / 2;
    final centerPos = _getPos('root', center, center);

    if (viewMode == 0) {
      final allItems = groupedItems.values.expand((x) => x).toList();
      for (int i = 0; i < allItems.length; i++) {
        double theta = i * (pi * (3 - sqrt(5))); 
        double r = 160 + (90 * sqrt(i));
        _drawCurve(canvas, centerPos, _getPos(allItems[i].id, center + r * cos(theta), center + r * sin(theta)), paint);
      }
    } else if (viewMode == 2) {
      final double total = dateCategories.isEmpty ? 1.0 : dateCategories.length.toDouble();
      for (int i = 0; i < dateCategories.length; i++) {
        double angle = (2 * pi * i) / total;
        final String nodeId = 'date_${dateCategories[i]}';
        final catPos = _getPos(nodeId, center + 600 * cos(angle), center + 600 * sin(angle));
        _drawCurve(canvas, centerPos, catPos, paint);
        final items = groupedItems.values.expand((x) => x).where((it) => '${it.createdAt.day} ${getMonthName(it.createdAt.month)} ${it.createdAt.year}' == dateCategories[i]).toList();
        for (int j = 0; j < items.length; j++) {
          double r = 220.0 + (j / 6).floor() * 140.0;
          double subAngle = angle - (pi/1.5) / 2 + (pi/1.5) * (j%6) / 5;
          _drawCurve(canvas, catPos, _getPos(items[j].id, catPos.dx + r * cos(subAngle), catPos.dy + r * sin(subAngle)), paint);
        }
      }
    } else {
      final double total = categories.isEmpty ? 1.0 : categories.length.toDouble();
      for (int i = 0; i < categories.length; i++) {
        double angle = (2 * pi * i) / total;
        double r = 750.0 + (i % 2 * 350.0);
        final String nodeId = 'cat_${categories[i]}';
        final catPos = _getPos(nodeId, center + r * cos(angle), center + r * sin(angle));
        _drawCurve(canvas, centerPos, catPos, paint);
        final items = groupedItems[categories[i]] ?? [];
        for (int j = 0; j < items.length; j++) {
          int ring = 1 + (j ~/ 6);
          double theta = angle + (2 * pi * (j % 6)) / 6 + (ring * 0.3);
          _drawCurve(canvas, catPos, _getPos(items[j].id, catPos.dx + (140.0 + ring * 110.0) * cos(theta), catPos.dy + (140.0 + ring * 110.0) * sin(theta)), paint);
        }
      }
    }
  }

  void _drawCurve(Canvas canvas, Offset start, Offset end, Paint paint) {
    final path = Path()..moveTo(start.dx, start.dy);
    final cp1 = start + (end - start) * 0.45 + Offset(-(end - start).dy, (end - start).dx) * 0.1;
    final cp2 = end - (end - start) * 0.45 - Offset(-(end - start).dy, (end - start).dx) * 0.1;
    path.cubicTo(cp1.dx, cp1.dy, cp2.dx, cp2.dy, end.dx, end.dy);
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter old) => true;
}

class _VisualResetButton extends StatefulWidget {
  final VoidCallback onTap;
  const _VisualResetButton({required this.onTap});

  @override
  State<_VisualResetButton> createState() => _VisualResetButtonState();
}

class _VisualResetButtonState extends State<_VisualResetButton> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  late Animation<double> _rotationAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 700),
      vsync: this,
    );
    
    _scaleAnimation = TweenSequence<double>([
      TweenSequenceItem(tween: Tween<double>(begin: 1.0, end: 0.85).chain(CurveTween(curve: Curves.easeOut)), weight: 25),
      TweenSequenceItem(tween: Tween<double>(begin: 0.85, end: 1.08).chain(CurveTween(curve: Curves.elasticOut)), weight: 75),
    ]).animate(_controller);

    _rotationAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOutBack),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _handleTap() {
    _controller.forward(from: 0.0);
    widget.onTap();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return GestureDetector(
      onTap: _handleTap,
      child: ScaleTransition(
        scale: _scaleAnimation,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
            child: Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    theme.colorScheme.primary,
                    theme.colorScheme.primary.withRed(50),
                  ],
                ),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: Colors.white.withOpacity(0.15),
                  width: 1.0,
                ),
                boxShadow: [
                  BoxShadow(
                    color: theme.colorScheme.primary.withOpacity(0.35),
                    blurRadius: 12,
                    spreadRadius: 1,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Center(
                child: RotationTransition(
                  turns: _rotationAnimation,
                  child: const Icon(
                    Icons.refresh,
                    color: Colors.white,
                    size: 18,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}