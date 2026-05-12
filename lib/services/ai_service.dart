import 'package:shared_preferences/shared_preferences.dart';
import 'ocr_service.dart';

class ClassificationResult {
  final String category;
  final double confidence;
  ClassificationResult(this.category, this.confidence);
  @override
  String toString() => '$category (${confidence.toStringAsFixed(1)}%)';
}

class AIService {
  // 1. Consolidated Keyword List (Cleaned from Overlaps)
  static const Map<String, Map<String, double>> _keywords = {
    'Science': {
      'physics': 2.0, 'chemistry': 2.0, 'biology': 2.0, 'astronomy': 2.0, 'quantum': 2.5, 'relativity': 2.5, 
      'biochemistry': 3.0, 'molecular biology': 3.0, 'stem cells': 3.0, 'orbital mechanics': 3.0, 'space mission': 3.0,
      'nasa': 2.0, 'spacex': 2.0, 'genetics': 2.5, 'nanotechnology': 3.0, 'black hole': 3.0
    },
    'Tech': {
      'software': 2.5, 'hardware': 2.0, 'coding': 2.0, 'cloud computing': 3.0, 'cybersecurity': 3.0, 'hacking': 2.5,
      'machine learning': 3.0, 'ai': 2.5, 'data science': 3.0, 'analytics': 3.0, 'blockchain': 2.5, 'api': 2.0,
      'web development': 2.5, 'database': 2.0, 'networking': 2.0, 'encryption': 2.5
    },
    'Finance': {
      'bkash': 3.0, 'nagad': 3.0, 'bank': 2.5, 'crypto': 3.0, 'investment': 2.5, 'stock market': 3.0, 'forex': 3.0,
      'trading': 2.5, 'fintech': 2.5, 'transaction': 2.0, 'payment': 2.0, 'balance': 2.0, 'insurance': 2.0
    },
    'Govt': {
      'politics': 2.5, 'democracy': 2.0, 'governance': 3.0, 'bureaucracy': 3.0, 'election': 2.5, 'policy': 2.0,
      'international relations': 3.0, 'diplomacy': 2.5, 'constitution': 2.5, 'human rights': 2.0, 'govt': 2.0
    },
    'Law': {
      'criminal law': 2.5, 'civil law': 2.5, 'judiciary': 2.5, 'court': 2.0, 'legal': 2.0, 'police': 2.0, 'contract': 2.0
    },
    'Education': {
      'exam': 2.5, 'result': 2.5, 'university': 2.0, 'pedagogy': 3.0, 'curriculum': 3.0, 'edtech': 2.5, 'assignment': 2.0,
      'syllabus': 2.0, 'lecture': 1.5, 'online learning': 2.0, 'academic': 2.0
    },
    'Nature': {
      'climate': 3.0, 'environment': 2.5, 'pollution': 2.0, 'botany': 2.5, 'agriculture': 2.5, 'disaster': 3.0,
      'earthquake': 3.0, 'tsunami': 3.0, 'weather': 2.0, 'forecast': 2.5, 'sustainability': 2.5, 'forest': 2.0
    },
    'Business': {
      'entrepreneurship': 2.5, 'marketing': 2.0, 'hr': 2.0, 'startups': 2.5, 'management': 1.5, 'ceo': 2.0, 'trade': 2.0, 'gdp': 2.5
    },
    'Media': {
      'news': 3.0, 'journalism': 3.0, 'broadcasting': 2.5, 'advertising': 2.0, 'social media': 2.0, 'viral': 2.0, 'internet culture': 2.5
    },
    'Design': {
      'ux research': 3.0, 'ui design': 3.0, '3d pipeline': 3.0, 'game design': 3.0, 'graphics': 2.0, 'illustration': 2.5, 'creative': 1.5
    },
    'Health': {
      'medicine': 2.5, 'doctor': 2.5, 'hospital': 2.0, 'anatomy': 2.5, 'psychiatry': 3.0, 'mental health': 2.5, 'fitness': 2.0, 'yoga': 2.0
    },
    'History': {
      'ancient civilizations': 3.0, 'archaeology': 2.5, 'medieval': 2.0, 'colonial': 2.0, 'fossils': 2.5
    },
    'Arts': {
      'painting': 2.0, 'music': 2.0, 'literature': 2.0, 'theatre': 2.0, 'cinema': 2.0, 'poetry': 2.0, 'photography': 2.0
    },
    'Lifestyle': {
      'food': 3.0, 'shopping': 2.5, 'fashion': 2.0, 'home': 2.0, 'pets': 2.0, 'parenting': 2.0, 'kids': 2.0, 'relationships': 2.0, 'motivation': 2.0
    },
    'Travel': {
      'ticket': 2.5, 'booking': 2.0, 'flight': 2.5, 'hotel': 2.0, 'visa': 2.5, 'map': 2.0, 'airport': 2.0
    },
    'Work': {
      'meeting': 2.0, 'deadline': 2.0, 'project': 1.5, 'office': 1.5, 'invoice': 2.0, 'salary': 2.0, 'task': 1.5
    },
    'Social': {
      'facebook': 2.5, 'instagram': 2.5, 'whatsapp': 2.0, 'tiktok': 2.5, 'chat': 1.5, 'post': 1.0, 'status': 1.0
    },
    'Gaming': {
      'pubg': 3.0, 'free fire': 3.0, 'esports': 2.5, 'victory': 2.0, 'ranked': 2.0, 'console': 2.0
    }
  };

  // 2. Optimized Priority List
  static const List<String> _priority = [
    'Finance', 'Law', 'Health', 'Science', 'Tech', 'Govt', 'Education', 'Nature',
    'Business', 'Design', 'Media', 'History', 'Arts', 'Travel', 'Work', 'Gaming', 
    'Lifestyle', 'Social'
  ];

  // 3. Negative Context Rules
  static const Map<String, List<String>> _negativeRules = {
    'Finance': ['blood bank', 'food bank', 'time bank'],
    'Tech': ['mechanical machine', 'hand tool'],
    'Health': ['tech medicine', 'computer doctor'],
  };

  static ClassificationResult categorizeText(String text) {
    if (text.isEmpty) return ClassificationResult('Other', 0.0);
    final normalized = _normalize(text);
    final words = normalized.split(' ');

    Map<String, double> scores = {};
    for (var cat in _priority) scores[cat] = 0.0;

    // Phrase Check
    _keywords.forEach((cat, keywords) {
      keywords.forEach((keyword, weight) {
        if (keyword.contains(' ') && normalized.contains(keyword)) {
          scores[cat] = scores[cat]! + (weight * 1.5);
        }
      });
    });

    // Keyword Match
    _keywords.forEach((cat, keywords) {
      keywords.forEach((keyword, weight) {
        if (keyword.contains(' ')) return;
        for (var word in words) {
          if (word == keyword) {
            scores[cat] = scores[cat]! + weight;
            break;
          } else if (_isFuzzyMatch(word, keyword)) {
            scores[cat] = scores[cat]! + (weight * 0.7);
            break;
          }
        }
      });
    });

    // Negative Rules
    _negativeRules.forEach((cat, negatives) {
      for (var bad in negatives) {
        if (normalized.contains(bad)) scores[cat] = scores[cat]! * 0.1;
      }
    });

    String bestCategory = 'Other';
    double maxScore = 0.0;
    for (var cat in _priority) {
      if (scores[cat]! > maxScore) {
        maxScore = scores[cat]!;
        bestCategory = cat;
      }
    }

    double confidence = (maxScore / (maxScore + 3.0)) * 100;
    if (maxScore < 1.8) {
      bestCategory = 'Other';
      confidence = (100 - (maxScore * 8)).clamp(0, 100);
    }

    return ClassificationResult(bestCategory, confidence.clamp(0, 100));
  }

  static String _normalize(String text) => text.toLowerCase().replaceAll(RegExp(r'[^\w\s]'), ' ').replaceAll(RegExp(r'\s+'), ' ').trim();

  static bool _isFuzzyMatch(String a, String b) {
    if (a.length < 5 || (a.length - b.length).abs() > 1) return false;
    return _levenshtein(a, b) <= 1;
  }

  static int _levenshtein(String a, String b) {
    var matrix = List.generate(a.length + 1, (i) => List.generate(b.length + 1, (j) => i == 0 ? j : (j == 0 ? i : 0)));
    for (var i = 1; i <= a.length; i++) {
      for (var j = 1; j <= b.length; j++) {
        var cost = a[i - 1] == b[j - 1] ? 0 : 1;
        matrix[i][j] = [matrix[i - 1][j] + 1, matrix[i][j - 1] + 1, matrix[i - 1][j - 1] + cost].reduce((v, e) => v < e ? v : e);
      }
    }
    return matrix[a.length][b.length];
  }

  static Future<void> ensureCategoryExists(String category) async {
    if (category == 'Other' || category == 'Uncategorized') return;
    final prefs = await SharedPreferences.getInstance();
    final categories = prefs.getStringList('user_categories') ?? ['Uncategorized', 'Work', 'Personal', 'Social'];
    if (!categories.contains(category)) {
      categories.add(category);
      await prefs.setStringList('user_categories', categories);
    }
  }

  static Future<ClassificationResult> analyzeAndSuggest(String imagePath) async {
    try {
      final text = await OCRService.extractText(imagePath);
      final result = categorizeText(text);
      if (result.category != 'Other') await ensureCategoryExists(result.category);
      return result;
    } catch (e) {
      return ClassificationResult('Other', 0.0);
    }
  }
}
