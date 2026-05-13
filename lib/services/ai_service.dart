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
  // 0. High-Level Basic Categories for Quick Sorting
  static const Map<String, Map<String, double>> basicCategories = {
    'Chat': {
      'message': 2.0, 'chat': 2.0, 'reply': 1.5, 'typing': 1.5, 'conversation': 2.0,
      'inbox': 2.0, 'messenger': 2.5, 'whatsapp': 2.5,
    },
    'Social Media': {
      'facebook': 2.5, 'instagram': 2.5, 'tiktok': 2.5, 'post': 1.5,
      'story': 1.5, 'reel': 2.0, 'followers': 2.0, 'likes': 1.5,
    },

    'Finance': {
      'payment': 2.0, 'transaction': 2.0, 'balance': 2.0, 'bank': 2.0, 'bkash': 3.0,
      'nagad': 3.0, 'rocket': 2.5, 'cash': 1.5, 'money': 1.5,
    },
    'Shopping': {
      'order': 2.0, 'cart': 2.0, 'checkout': 2.0, 'delivery': 2.0, 'product': 1.5,
      'discount': 1.5, 'price': 1.5, 'shopping': 2.0,
    },
    'Education': {
      'exam': 2.5, 'result': 2.0, 'assignment': 3.0, 'university': 2.0, 'class': 2.0,
      'lecture': 2.0, 'student': 1.5, 'study': 3.0, 'quiz': 2.5, 'homework': 3.0,
      'syllabus': 2.5, 'academic': 2.0, 'tutorial': 2.5, 'course': 2.0,
      'pdf': 2.0, 'notes': 2.5, 'book': 2.0, 'school': 2.0, 'college': 2.0,
    },


    'Work': {
      'meeting': 2.0, 'office': 1.5, 'project': 1.5, 'salary': 2.0, 'invoice': 2.0, 'task': 1.5,
    },
    'Entertainment': {
      'movie': 2.0, 'music': 2.0, 'anime': 2.5, 'netflix': 2.5, 'spotify': 2.5,
      'youtube': 2.5, 'acoustics': 2.5, 'synthesizer': 3.0, 'midi': 2.5, 'rhythm': 2.0,
    },
    'Gaming': {
      'game': 2.0, 'pubg': 3.0, 'free fire': 3.0, 'esports': 2.5, 'victory': 2.0, 'ranked': 2.0, 'console': 2.0,
      'minecraft': 3.0, 'roblox': 3.0, 'valorant': 3.0, 'cod': 2.5, 'league of legends': 3.0, 'dota': 3.0,
      'genshin': 3.0, 'clash of clans': 3.0, 'mobile legends': 3.0, 'fifa': 2.5, 'gta': 2.5, 'steam': 2.5,
      'playstation': 2.5, 'xbox': 2.5, 'nintendo': 2.5, 'twitch': 2.5, 'moba': 2.5, 'fps': 2.5, 'rpg': 2.5,
    },
    'Tech': {
      'software': 1.5, 'hardware': 1.5, 'coding': 1.5, 'cloud computing': 3.0, 'cybersecurity': 3.0, 'hacking': 2.5,
      'machine learning': 3.0, 'artificial intelligence': 2.5, 'data science': 2.5, 'analytics': 1.5, 'blockchain': 2.5, 'web api': 2.0,
      'web development': 2.5, 'database': 1.5, 'networking': 1.5, 'encryption': 2.5, 'penetration testing': 3.0,
      'zero-day': 3.0, 'ransomware': 3.0, 'phishing': 2.5, 'firewall': 2.0, 'malware': 2.5, 'intrusion detection': 3.0,
      'cryptography': 2.5, 'neural networks': 3.0, 'transformers': 3.0, 'reinforcement learning': 3.0, 'backpropagation': 3.0,
      'deep learning': 3.0, 'natural language processing': 3.0, 'computer vision': 3.0, 'kubernetes': 3.0, 'docker': 2.5,
      'serverless': 3.0, 'microservices': 3.0, 'aws': 2.5, 'azure': 2.5, 'gcp': 2.5, 'virtualization': 2.5, 'saas': 2.5,
      'smart contracts': 3.0, 'ethereum': 3.0, 'decentralization': 3.0, 'consensus algorithm': 3.0, 'proof of stake': 3.0,
      'nft': 2.5, 'mining': 2.5, 'git': 1.5, 'pull request': 3.0, 'statistics': 1.5, 'data mining': 3.0, 'tableau': 2.5,
      'nanotechnology': 3.0, 'carbon nanotubes': 3.0, 'graphene': 3.0, 'wireframe': 2.0, 'prototype': 2.0, 'ui design': 2.5,
      'figma': 2.5, 'unity engine': 3.0, 'unreal engine': 3.0, 'game design': 2.5,
    },


    'Pets & Animals': {
      'animal': 3.0, 'pets': 2.5, 'cat': 2.5, 'dog': 2.5, 'bird': 2.0, 'wildlife': 2.5, 'veterinary': 2.5,
      'cow': 2.0, 'tiger': 2.0, 'lion': 2.0, 'zoo': 2.0, 'ethology': 3.0,
    },
    'Sports': {
      'football': 3.0, 'cricket': 3.0, 'badminton': 3.0, 'basketball': 2.5, 'tennis': 2.5, 'soccer': 2.5,
      'match': 2.0, 'score': 2.0, 'tournament': 2.5, 'world cup': 3.0, 'athlete': 2.0, 'sports': 2.5,
    },







    'Travel': {
      'ticket': 2.0, 'flight': 2.5, 'hotel': 2.0, 'booking': 2.0, 'visa': 2.5, 'airport': 2.0,
    },
    'Health': {
      'doctor': 2.0, 'medicine': 2.0, 'hospital': 2.0, 'fitness': 1.5, 'workout': 1.5,
    },
    'OTP & Security': {
      'otp': 3.0, 'verification': 2.5, 'password': 2.5, 'login': 2.0, 'security': 2.0, '2fa': 3.0,
    },
    'Food': {
      'food': 2.0, 'recipe': 2.0, 'restaurant': 2.0, 'burger': 1.5, 'pizza': 1.5,
    },
    'News': {
      'breaking': 2.5, 'headline': 2.0, 'journalism': 2.0, 'news': 2.5,
    },
  };

  // 1. Consolidated Keyword List (Cleaned from Overlaps)

  static const Map<String, Map<String, double>> _keywords = {
    'Quantum Physics': {
      'qubit': 3.0, 'entanglement': 3.0, 'superposition': 3.0, 'schrodinger': 2.5, 'wave function': 3.0, 'quantum decoherence': 3.0,
      'particle physics': 2.5, 'cern': 2.5, 'higgs boson': 3.0, 'uncertainty principle': 3.0, 'quantum': 2.0, 'physics': 2.0, 'relativity': 2.5
    },
    'Molecular Biology': {
      'crispr': 3.0, 'dna sequencing': 3.0, 'rna transcription': 3.0, 'protein folding': 3.0, 'ribosome': 2.5, 'mitochondria': 2.5,
      'genomics': 3.0, 'proteomics': 3.0, 'epigenetics': 3.0, 'molecular biology': 3.0, 'biochemistry': 2.0, 'biology': 2.0, 'genetics': 2.5, 'stem cells': 3.0
    },
    'Astrophysics': {
      'supernova': 3.0, 'exoplanet': 3.0, 'dark matter': 3.0, 'event horizon': 3.0, 'singularity': 2.5, 'pulsar': 3.0,
      'quasar': 3.0, 'nebula': 2.5, 'astronomy': 2.0, 'black hole': 2.5, 'cosmic': 2.0, 'orbital mechanics': 3.0
    },




    'Fintech': {
      'neobank': 3.0, 'payment gateway': 2.5, 'swift': 2.5, 'remittance': 3.0, 'open banking': 3.0, 'aml': 3.0, 'kyc': 3.0,
      'bkash': 3.0, 'nagad': 3.0, 'fintech': 3.0, 'transaction': 2.0, 'payment': 2.0
    },
    'Investments': {
      'hedging': 3.0, 'derivatives': 3.0, 'options trading': 3.0, 'futures': 2.5, 'arbitrage': 3.0, 'volatility': 2.5,
      'stock market': 3.0, 'etf': 2.5, 'dividend': 2.5, 'trading': 2.0, 'investment': 2.0, 'forex': 3.0
    },
    'Macroeconomics': {
      'gdp': 3.0, 'inflation': 2.5, 'fiscal policy': 3.0, 'monetary policy': 3.0, 'central bank': 2.5, 'recession': 2.5,
      'economics': 2.0, 'interest rate': 2.0
    },
    'Criminal Law': {
      'felony': 3.0, 'misdemeanor': 3.0, 'indictment': 3.0, 'prosecutor': 2.5, 'criminal law': 3.0, 'parole': 2.5,
      'police': 2.0, 'miranda rights': 3.0
    },
    'Civil Law': {
      'tort': 3.0, 'liability': 2.5, 'negligence': 2.5, 'contract law': 3.0, 'litigation': 2.5, 'arbitration': 2.5,
      'plaintiff': 3.0, 'defendant': 3.0, 'civil law': 3.0
    },
    'Constitutional Law': {
      'sovereignty': 2.5, 'treaty': 2.5, 'constitution': 3.0, 'un charter': 3.0, 'human rights': 2.5, 'supreme court': 2.5
    },
    'Political Science': {
      'geopolitics': 3.0, 'ideology': 2.5, 'authoritarianism': 3.0, 'populism': 3.0, 'legislature': 2.5, 'election': 2.5,
      'politics': 2.5, 'governance': 2.5, 'democracy': 2.0
    },

    'Environmental Science': {
      'biodiversity': 3.0, 'ecosystem': 2.5, 'conservation': 2.5, 'pollution': 2.0, 'ecology': 3.0, 'botany': 2.5,
      'environment': 2.5, 'nature': 2.0
    },
    'Climate Change': {
      'global warming': 3.0, 'carbon footprint': 3.0, 'greenhouse effect': 3.0, 'sustainability': 2.5, 'climate': 3.0
    },
    'Renewable Energy': {
      'photovoltaic': 3.0, 'wind turbine': 3.0, 'hydroelectric': 2.5, 'geothermal': 3.0, 'energy storage': 3.0,
      'solar power': 2.5, 'renewable': 2.5
    },
    'Mechanical Engineering': {
      'thermodynamics': 3.0, 'fluid mechanics': 3.0, 'kinematics': 3.0, 'cad': 2.5, 'hydraulics': 2.5, 'engineering': 2.0
    },
    'Electrical Engineering': {
      'circuit design': 3.0, 'semiconductor': 3.0, 'signal processing': 3.0, 'microcontroller': 3.0, 'pcb': 2.5
    },
    'Civil Engineering': {
      'structural analysis': 3.0, 'geotechnical': 3.0, 'hydrology': 2.5, 'surveying': 2.5, 'urban planning': 2.5
    },
    'Medical Research': {
      'clinical trials': 3.0, 'epidemiology': 3.0, 'oncology': 3.0, 'immunology': 3.0, 'pathology': 3.0, 'medicine': 2.0
    },
    'Pharmacology': {
      'pharmacokinetics': 3.0, 'dosage': 2.0, 'antibiotic': 2.5, 'vaccine': 2.5, 'pharmacology': 3.0
    },
    'Psychology': {
      'cognitive behavioral': 3.0, 'psychoanalysis': 3.0, 'neuroplasticity': 3.0, 'mental health': 2.5, 'psychology': 2.5
    },
    'Ancient History': {
      'mesopotamia': 3.0, 'egyptology': 3.0, 'roman empire': 2.5, 'archaeology': 2.5, 'ancient': 2.0
    },
    'Modern History': {
      'industrial revolution': 3.0, 'world war': 2.5, 'cold war': 2.5, 'history': 2.0
    },
    'Linguistics': {
      'syntax': 3.0, 'semantics': 2.5, 'etymology': 3.0, 'phonetics': 3.0, 'linguistics': 3.0
    },
    'Philosophy': {
      'existentialism': 3.0, 'stoicism': 3.0, 'metaphysics': 3.0, 'ethics': 2.5, 'philosophy': 2.5
    },
    'Architecture': {
      'bauhaus': 3.0, 'blueprint': 2.5, 'facade': 2.5, 'minimalism': 2.0, 'architecture': 3.0
    },
    'Digital Art': {
      'vector': 2.0, 'raster': 2.0, 'compositing': 3.0, 'typography': 2.5, 'digital art': 3.0, 'illustration': 2.5
    },
    'Marketing': {
      'branding': 2.5, 'seo': 3.0, 'conversion rate': 3.0, 'crm': 2.5, 'marketing': 2.5, 'advertising': 2.0
    },

    'E-commerce': {
      'dropshipping': 3.0, 'sku': 2.5, 'shopping cart': 2.5, 'checkout': 2.0, 'e-commerce': 3.0, 'shopping': 2.0
    },
    'Real Estate': {
      'mortgage': 3.0, 'appraisal': 2.5, 'realtor': 2.5, 'real estate': 3.0, 'property': 2.0
    },
    'Agriculture': {
      'hydroponics': 3.0, 'pesticide': 2.5, 'irrigation': 2.5, 'agriculture': 3.0, 'farming': 2.5
    },
    'Marine Science': {
      'oceanography': 3.0, 'coral reef': 3.0, 'marine biology': 3.0, 'abyss': 2.5
    },
    'Sports Science': {
      'biomechanics': 3.0, 'kinesiology': 3.0, 'sports nutrition': 3.0, 'fitness': 2.0, 'athlete': 2.5
    },
    'Food': {
      'recipe': 3.0, 'food': 3.0, 'cooking': 2.5, 'chef': 2.5, 'kitchen': 2.0,
      'dinner': 2.0, 'lunch': 2.0, 'breakfast': 2.0, 'ingredients': 2.5,
      'restaurant': 2.0, 'delicious': 2.0, 'gastronomy': 3.0, 'sous-vide': 3.0,
    },

    'Fashion': {
      'couture': 3.0, 'textile': 2.5, 'runway': 2.5, 'fashion': 2.5
    },
    'Journalism': {
      'investigative': 2.5, 'editorial': 2.0, 'news': 2.5, 'journalism': 3.0, 'media': 2.0
    },
    'Sociology': {
      'demography': 3.0, 'socialization': 2.5, 'inequality': 2.5, 'sociology': 3.0
    },
    'Aviation': {
      'aerodynamics': 3.0, 'cockpit': 2.5, 'fuselage': 3.0, 'flight': 2.0, 'aviation': 3.0
    },
    'Space': {
      'rover': 3.0, 'satellite': 2.5, 'orbit': 2.0, 'nasa': 2.5, 'spacex': 2.5, 'space': 2.0, 'space mission': 3.0
    },
    'Religion': {
      'theology': 3.0, 'scripture': 2.5, 'spirituality': 2.5, 'religion': 3.0
    },


    'Family': {
      'parenting': 2.5, 'relationship': 2.0, 'marriage': 2.5, 'kids': 2.0, 'family': 2.0
    },


    'Military & Defense': {
      'ballistics': 3.0, 'reconnaissance': 3.0, 'logistics': 2.0, 'stealth': 2.5, 'artillery': 3.0, 'defense': 2.0
    },
    'Human Resources': {
      'recruitment': 3.0, 'onboarding': 2.5, 'payroll': 2.5, 'hr management': 3.0, 'talent acquisition': 3.0
    },


    'Supply Chain': {
      'inventory': 2.5, 'procurement': 3.0, 'logistics': 3.0, 'warehousing': 2.5, 'supply chain': 3.0
    }
  };




  // 2. Optimized Priority List
  static const List<String> _priority = [
    'OTP & Security', 'Chat', 'Social Media', 'Fintech', 'Finance', 'Investments', 
    'Pets & Animals', 'Criminal Law', 'Civil Law', 'Medical Research', 'Quantum Physics', 
    'Macroeconomics', 'Molecular Biology', 'Astrophysics', 
    'Constitutional Law', 'Renewable Energy', 'Mechanical Engineering', 
    'Electrical Engineering', 'Civil Engineering', 'Psychology', 'Pharmacology', 
    'Environmental Science', 'Climate Change', 
    'Digital Art', 'Marketing', 'E-commerce', 'Shopping', 'Fashion',
    'Real Estate', 'Ancient History', 'Modern History', 'Linguistics', 'Philosophy', 
    'Architecture', 'Agriculture', 'Marine Science', 'Sports Science', 'Culinary Arts', 
    'Food', 'Education', 'Health', 'Journalism', 'News', 'Sociology', 'Aviation', 
    'Space', 'Entertainment', 'Gaming', 'Sports', 'Pets & Animals', 'Tech', 'Religion', 'Political Science', 
    'Family', 'Human Resources', 
    'Military & Defense', 'Supply Chain', 'Work', 'Travel'
  ];












  // 3. Negative Context Rules
  static const Map<String, List<String>> _negativeRules = {
    'Fintech': ['blood bank', 'food bank', 'time bank'],
    'Tech': [
      'mechanical machine', 'hand tool', 'medical report', 'patient record', 
      'news headline', 'breaking news', 'bank statement', 'money transfer',
      'animal', 'pets', 'cat', 'dog', 'bird', 'wildlife', 'veterinary', 'zoo'
    ],



    'Medical Research': ['tech medicine', 'computer doctor'],
    'Investments': ['time investment', 'emotional investment'],
    'Ancient History': ['modern history', 'recent history'],
    'Space': ['office space', 'parking space'],
  };


  static ClassificationResult categorizeText(String text) {
    if (text.isEmpty) return ClassificationResult('Other', 0.0);
    final normalized = _normalize(text);
    final words = normalized.split(' ');

    Map<String, double> scores = {};
    for (var cat in _priority) scores[cat] = 0.0;

    // Helper to process a keyword map
    void processKeywords(Map<String, Map<String, double>> keywordsMap) {
      keywordsMap.forEach((cat, keywords) {
        if (!scores.containsKey(cat)) scores[cat] = 0.0;
        
        keywords.forEach((keyword, weight) {
          // Phrase Check
          if (keyword.contains(' ')) {
            if (normalized.contains(keyword)) {
              scores[cat] = scores[cat]! + (weight * 1.5);
            }
          } else {
            // Keyword Match
            for (var word in words) {
              if (word == keyword) {
                scores[cat] = scores[cat]! + weight;
                break;
              } else if (_isFuzzyMatch(word, keyword)) {
                scores[cat] = scores[cat]! + (weight * 0.7);
                break;
              }
            }
          }
        });
      });
    }

    // Run both maps
    processKeywords(basicCategories);
    processKeywords(_keywords);

    // Negative Rules
    _negativeRules.forEach((cat, negatives) {
      if (scores.containsKey(cat)) {
        for (var bad in negatives) {
          if (normalized.contains(bad)) scores[cat] = scores[cat]! * 0.1;
        }
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
    final categories = prefs.getStringList('user_categories') ?? ['Uncategorized', 'Work', 'Personal'];

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
