import 'package:shared_preferences/shared_preferences.dart';
import 'ocr_service.dart';

class AIService {
  static final Map<String, List<String>> _categoryKeywords = {
    'Shopping': ['add to cart', 'total price', 'checkout', 'buy now', 'daraz', 'amazon', 'aliexpress', 'shopee', 'product details', 'delivery charge', 'promo code', 'cart', 'voucher', 'order total', 'billing', 'quantity', 'wishlist', 'payment successful', 'order id', 'sale', 'clearance', 'refund', 'tracking', 'discount code', 'coupon'],
    'Work': ['meeting', 'deadline', 'task', 'office', 'project', 'client', 'presentation', 'email', 'invoice', 'salary', 'zoom', 'google meet', 'spreadsheet', 'report', 'slack', 'linkedin', 'cv', 'resume', 'notion', 'google docs', 'jira', 'trello', 'attendance', 'interview', 'work from home', 'business card'],
    'Social': ['instagram', 'tiktok', 'facebook', 'twitter', 'replied', 'commented', 'shared', 'follow', 'message', 'chat', 'messenger', 'whatsapp', 'active now', 'seen', 'delivered', 'typing', 'story', 'reel', 'youtube', 'subscriber', 'profile', 'friend request', 'reddit', 'snapchat', 'discord', 'telegram', 'status', 'online', 'group chat', 'notification'],
    'Study': ['exam', 'result', 'assignment', 'research', 'university', 'college', 'syllabus', 'lecture', 'notes', 'study', 'quiz', 'coursework', 'scholarship', 'gpa', 'degree', 'department', 'certificate', 'admission', 'library', 'textbook'],
    'Travel': ['hotel', 'flight', 'ticket', 'booking', 'visa', 'itinerary', 'destination', 'vacation', 'tripadvisor', 'uber', 'pathao', 'map', 'navigation', 'gps', 'passport', 'check-in', 'bus ticket', 'train', 'shohoz', 'busbd', 'gozayaan', 'sharetrip', 'airport'],
    'Food': ['restaurant', 'foodpanda', 'swiggy', 'recipe', 'ingredients', 'nutrition', 'menu', 'order summary', 'zomato', 'delivery', 'yum', 'delicious', 'tasty', 'cooking', 'hungry', 'dinner', 'lunch', 'breakfast', 'pizza', 'burger', 'cafe'],
    'Finance': ['bkash', 'nagad', 'rocket', 'bank', 'transfer', 'statement', 'balance', 'transaction', 'bill pay', 'recharge', 'card', 'payment', 'cash out', 'money', 'credit', 'debit', 'wallet', 'upay', 'cellfin', 'remittance', 'exchange rate', 'stock market', 'crypto'],
    'Health': ['doctor', 'hospital', 'medicine', 'prescription', 'fitness', 'workout', 'gym', 'health', 'calorie', 'blood pressure', 'appointment', 'pharmacy', 'clinic', 'skin care', 'mask', 'vaccine'],
    'Gaming': ['pubg', 'free fire', 'steam', 'game', 'level up', 'victory', 'score', 'player', 'ranked', 'tournament', 'esports', 'twitch', 'gaming', 'discord chat', 'console', 'nintendo'],
    'Programming': ['flutter', 'dart', 'github', 'vscode', 'javascript', 'python', 'programming', 'code snippet', 'stack overflow', 'debugging', 'api', 'database', 'frontend', 'backend', 'repository'],
    'Beauty': ['makeup', 'skincare', 'lipstick', 'outfit', 'fashion', 'style', 'collection', 'cosmetics', 'salon', 'parlor', 'jewelry'],
    'News': ['breaking news', 'politics', 'world news', 'daily', 'election', 'government', 'headline', 'article', 'journalist'],
  };

  /// Analyzes text and returns the best matching category with a confidence-based scoring system.
  static String suggestCategory(String text) {
    if (text.isEmpty) return 'Uncategorized';
    
    // Normalize text: lowercase and replace newlines with spaces
    final normalizedText = text.toLowerCase().replaceAll('\n', ' ').replaceAll(RegExp(r'\s+'), ' ');
    
    String bestMatch = 'Uncategorized';
    double maxScore = 0;

    _categoryKeywords.forEach((category, keywords) {
      double score = 0;
      for (var keyword in keywords) {
        if (normalizedText.contains(keyword)) {
          // Multi-word keywords (phrases) get more weight
          if (keyword.contains(' ')) {
            score += 2.5;
          } else {
            score += 1.0;
          }
        }
      }
      
      // Category specific adjustments
      if (category == 'Shopping' && score < 2.0) score = 0; // Require higher confidence for shopping
      if (category == 'Social' && normalizedText.contains('active now')) score += 5; // Very strong indicator
      if (category == 'Finance' && (normalizedText.contains('bkash') || normalizedText.contains('nagad'))) score += 5;

      if (score > maxScore && score >= 1.5) {
        maxScore = score;
        bestMatch = category;
      }
    });

    return bestMatch;
  }

  /// Automatically ensures the category exists in user's preferences.
  static Future<void> ensureCategoryExists(String category) async {
    if (category == 'Uncategorized') return;

    final prefs = await SharedPreferences.getInstance();
    final categories = prefs.getStringList('user_categories') ?? ['Uncategorized', 'Work', 'Personal', 'Social', 'School'];
    
    if (!categories.contains(category)) {
      categories.add(category);
      await prefs.setStringList('user_categories', categories);
    }
  }

  /// Full AI pipeline: OCR -> Analyze -> Auto-create folder
  static Future<String> analyzeAndSuggest(String imagePath) async {
    try {
      final text = await OCRService.extractText(imagePath);
      final category = suggestCategory(text);
      
      if (category != 'Uncategorized') {
        // Automatically create the folder if it doesn't exist (Silent)
        await ensureCategoryExists(category);
      }
      
      return category;
    } catch (e) {
      return 'Uncategorized';
    }
  }
}
