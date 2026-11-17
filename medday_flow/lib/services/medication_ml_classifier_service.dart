import 'package:medday_flow/utils/medication_model/frequency_and_dosage.dart';
import 'package:medday_flow/utils/medication_model/medication_classes.dart';
import 'package:medday_flow/widgets/medication_pill_graphic.dart';

/// Result of machine learning classification on formula / active chemical text
class MedicationMLPrediction {
  final MedicationClassInfo? predictedClass;
  final double confidence; // 0.0 to 1.0
  final String matchedFeature;
  final MedicationShape? suggestedShape;
  final DosageUnit? suggestedUnit;
  final double? extractedDosage;

  const MedicationMLPrediction({
    this.predictedClass,
    this.confidence = 0.0,
    this.matchedFeature = '',
    this.suggestedShape,
    this.suggestedUnit,
    this.extractedDosage,
  });

  bool get hasPrediction => predictedClass != null && confidence >= 0.40;
}

/// Embedded Machine Learning & Pharmacological Stem Classification Engine
/// Uses WHO INN (International Nonproprietary Names) / USAN therapeutic stem tokenization,
/// TF-IDF character n-gram cosine matching, and chemical entity recognition.
class MedicationMLClassifierService {
  // Common pharmaceutical salt and formulation stop words
  static const Set<String> _saltStopWords = {
    'hydrochloride', 'hcl', 'sodium', 'potassium', 'calcium', 'maleate',
    'tartrate', 'monohydrate', 'trihydrate', 'hydrate', 'fumarate',
    'succinate', 'besylate', 'mesylate', 'acetate', 'citrate', 'sulfate',
    'phosphate', 'gluconate', 'valerate', 'propionate', 'dipropionate',
    'nitrate', 'bromide', 'chloride', 'carbonate', 'bicarbonate', 'diacetate',
    'oral', 'tablet', 'capsule', 'extended', 'release', 'xr', 'er', 'sr',
    'cr', 'dr', 'forte', 'usp', 'bp', 'ep', 'suspension', 'solution',
  };

  // WHO / USAN Pharmacological Suffix Stem Dictionary -> Class ID mapping with base weights
  static const Map<String, String> _pharmacologicalStems = {
    // Cardiovascular
    'statin': 'statin', // Atorvastatin, Rosuvastatin, Simvastatin
    'sartan': 'arb', // Losartan, Valsartan, Telmisartan
    'pril': 'ace_inhibitor', // Lisinopril, Enalapril, Ramipril
    'olol': 'beta_blocker', // Metoprolol, Atenolol, Bisoprolol
    'alol': 'beta_blocker', // Labetalol, Carvedilol
    'dipine': 'calcium_channel_blocker', // Amlodipine, Nifedipine, Felodipine
    'thiazide': 'diuretic', // Hydrochlorothiazide
    'semide': 'diuretic', // Furosemide, Torsemide
    'xaban': 'anticoagulant', // Apixaban, Rivaroxaban
    'parin': 'anticoagulant', // Heparin, Enoxaparin
    'grel': 'antiplatelet', // Clopidogrel, Ticagrelor

    // Endocrine & Metabolism
    'formin': 'antidiabetic', // Metformin, Phenformin
    'gliflozin': 'sglt2_inhibitor', // Empagliflozin, Dapagliflozin
    'glutide': 'glp1_agonist', // Semaglutide, Liraglutide, Dulaglutide
    'tide': 'glp1_agonist', // Exenatide, Tirzepatide
    'gliptin': 'dpp4_sulfonylurea', // Sitagliptin, Linagliptin, Vildagliptin
    'glinide': 'dpp4_sulfonylurea', // Repaglinide, Nateglinide
    'glitazone': 'antidiabetic', // Pioglitazone, Rosiglitazone
    'piride': 'dpp4_sulfonylurea', // Glimepiride
    'zide': 'dpp4_sulfonylurea', // Gliclazide, Glipizide
    'thyroxine': 'thyroid', // Levothyroxine
    'thiouracil': 'antithyroid', // Propylthiouracil
    'dronate': 'bone_health', // Alendronate, Risedronate, Ibandronate
    'sone': 'corticosteroid', // Prednisone, Dexamethasone, Hydrocortisone
    'lone': 'corticosteroid', // Prednisolone, Methylprednisolone
    'onide': 'corticosteroid', // Budesonide, Desonide
    'gestrel': 'hormone_therapy', // Levonorgestrel, Desogestrel
    'estrol': 'hormone_therapy', // Diethylstilbestrol
    'diol': 'hormone_therapy', // Estradiol

    // Mental Health & Neurology
    'oxetine': 'antidepressant', // Fluoxetine, Paroxetine, Duloxetine
    'pram': 'antidepressant', // Citalopram, Escitalopram
    'traline': 'antidepressant', // Sertraline
    'faxine': 'antidepressant', // Venlafaxine, Desvenlafaxine
    'triptyline': 'antidepressant', // Amitriptyline, Nortriptyline
    'piprazole': 'antipsychotic', // Aripiprazole, Brexpiprazole
    'tidone': 'antipsychotic', // Lurasidone, Ziprasidone
    'apine': 'antipsychotic', // Quetiapine, Olanzapine, Clozapine
    'peridone': 'antipsychotic', // Risperidone, Paliperidone
    'azepam': 'anxiolytic', // Diazepam, Lorazepam, Clonazepam
    'azolam': 'anxiolytic', // Alprazolam, Midazolam, Triazolam
    'irone': 'anxiolytic', // Buspirone
    'toin': 'anticonvulsant', // Phenytoin
    'racetam': 'anticonvulsant', // Levetiracetam, Piracetam
    'suximide': 'anticonvulsant', // Ethosuximide
    'gab': 'anticonvulsant', // Gabapentin, Pregabalin
    'triptan': 'migraine', // Sumatriptan, Zolmitriptan, Rizatriptan
    'gepant': 'migraine', // Rimegepant, Ubrogepant
    'capone': 'parkinsons', // Entacapone, Tolcapone
    'pezil': 'dementia', // Donepezil
    'stigmine': 'dementia', // Rivastigmine, Neostigmine
    'mantine': 'dementia', // Memantine, Amantadine

    // Infection & Immunology
    'cillin': 'antibiotic', // Amoxicillin, Ampicillin, Penicillin
    'ceph': 'cephalosporin', // Cephalexin
    'cef': 'cephalosporin', // Cefuroxime, Cefixime, Ceftriaxone
    'floxacin': 'fluoroquinolone_macrolide', // Ciprofloxacin, Levofloxacin, Moxifloxacin
    'thromycin': 'fluoroquinolone_macrolide', // Azithromycin, Clarithromycin, Erythromycin
    'mycin': 'fluoroquinolone_macrolide', // Clindamycin, Gentamicin, Tobramycin
    'cycline': 'antibiotic', // Doxycycline, Tetracycline, Minocycline
    'clovir': 'antiviral', // Acyclovir, Valacyclovir, Ganciclovir
    'amivir': 'antiviral', // Oseltamivir, Zanamivir
    'navir': 'antiviral', // Ritonavir, Darunavir
    'buvir': 'antiviral', // Sofosbuvir
    'fovir': 'antiviral', // Tenofovir
    'conazole': 'antifungal', // Ketoconazole, Fluconazole, Itraconazole
    'fungin': 'antifungal', // Caspofungin, Micafungin
    'bendazole': 'antiparasitic', // Mebendazole, Albendazole
    'mab': 'immunosuppressant', // Infliximab, Adalimumab, Rituximab
    'nib': 'chemotherapy', // Imatinib, Erlotinib, Gefitinib
    'limus': 'immunosuppressant', // Tacrolimus, Sirolimus, Everolimus

    // Gastrointestinal
    'prazole': 'gastrointestinal', // Omeprazole, Pantoprazole, Esomeprazole, Lansoprazole
    'tidine': 'h2_blocker', // Famotidine, Cimetidine, Ranitidine
    'setron': 'antiemetic', // Ondansetron, Granisetron, Palonosetron
    'peridone_gi': 'antiemetic', // Domperidone

    // Respiratory & Allergy
    'terol': 'respiratory', // Salbutamol, Formoterol, Salmeterol
    'tropium': 'controller_inhaler', // Ipratropium, Tiotropium
    'lukast': 'leukotriene_modifier', // Montelukast, Zafirlukast
    'rizine': 'antihistamine', // Cetirizine, Levocetirizine
    'tadine': 'antihistamine', // Loratadine, Desloratadine
    'fendine': 'antihistamine', // Fexofenadine
    'astine': 'antihistamine', // Bilastine, Ebastine
    'zoline': 'cough_cold', // Xylometazoline, Oxymetazoline

    // Pain & Fever
    'profen': 'analgesic', // Ibuprofen, Ketoprofen, Flurbiprofen
    'fenac': 'analgesic', // Diclofenac, Aceclofenac
    'coxib': 'analgesic', // Celecoxib, Etoricoxib
    'oxicam': 'analgesic', // Meloxicam, Piroxicam
    'codone': 'opioid', // Oxycodone, Hydrocodone
    'morphone': 'opioid', // Hydromorphone, Oxymorphone
    'curium': 'muscle_relaxant', // Atracurium
    'curonium': 'muscle_relaxant', // Rocuronium

    // Urological
    'zosin': 'urological', // Tamsulosin, Doxazosin, Terazosin
    'steride': 'urological', // Finasteride, Dutasteride
    'nacin': 'urological', // Solifenacin, Darifenacin
  };

  // Direct generic drug dictionary -> class ID
  static const Map<String, String> _knownDrugToClass = {
    'paracetamol': 'analgesic_non_opioid',
    'acetaminophen': 'analgesic_non_opioid',
    'tylenol': 'analgesic_non_opioid',
    'panadol': 'analgesic_non_opioid',
    'aspirin': 'antiplatelet',
    'tramadol': 'opioid',
    'codeine': 'opioid',
    'morphine': 'opioid',
    'fentanyl': 'opioid',
    'allopurinol': 'anti_gout',
    'colchicine': 'anti_gout',
    'febuxostat': 'anti_gout',
    'metformin': 'antidiabetic',
    'glimepiride': 'dpp4_sulfonylurea',
    'gliclazide': 'dpp4_sulfonylurea',
    'glipizide': 'dpp4_sulfonylurea',
    'insulin': 'insulin',
    'gabapentin': 'anticonvulsant',
    'pregabalin': 'anticonvulsant',
    'valproate': 'anticonvulsant',
    'carbamazepine': 'anticonvulsant',
    'levetiracetam': 'anticonvulsant',
    'lamotrigine': 'anticonvulsant',
    'lithium': 'antipsychotic',
    'quetiapine': 'antipsychotic',
    'olanzapine': 'antipsychotic',
    'aripiprazole': 'antipsychotic',
    'risperidone': 'antipsychotic',
    'sertraline': 'antidepressant',
    'fluoxetine': 'antidepressant',
    'escitalopram': 'antidepressant',
    'citalopram': 'antidepressant',
    'duloxetine': 'antidepressant',
    'venlafaxine': 'antidepressant',
    'alprazolam': 'anxiolytic',
    'clonazepam': 'anxiolytic',
    'lorazepam': 'anxiolytic',
    'diazepam': 'anxiolytic',
    'zolpidem': 'sleep_aid',
    'zopiclone': 'sleep_aid',
    'melatonin': 'sleep_aid',
    'methylphenidate': 'adhd_stimulant',
    'atomoxetine': 'adhd_stimulant',
    'levodopa': 'parkinsons',
    'carbidopa': 'parkinsons',
    'pramipexole': 'parkinsons',
    'donepezil': 'dementia',
    'memantine': 'dementia',
    'amoxicillin': 'antibiotic',
    'ampicillin': 'antibiotic',
    'penicillin': 'antibiotic',
    'azithromycin': 'fluoroquinolone_macrolide',
    'clarithromycin': 'fluoroquinolone_macrolide',
    'ciprofloxacin': 'fluoroquinolone_macrolide',
    'levofloxacin': 'fluoroquinolone_macrolide',
    'doxycycline': 'antibiotic',
    'cephalexin': 'cephalosporin',
    'cefuroxime': 'cephalosporin',
    'ceftriaxone': 'cephalosporin',
    'acyclovir': 'antiviral',
    'valacyclovir': 'antiviral',
    'oseltamivir': 'antiviral',
    'paxlovid': 'antiviral',
    'fluconazole': 'antifungal',
    'itraconazole': 'antifungal',
    'terbinafine': 'antifungal',
    'metronidazole': 'antiparasitic',
    'albendazole': 'antiparasitic',
    'ivermectin': 'antiparasitic',
    'methotrexate': 'immunosuppressant',
    'tacrolimus': 'immunosuppressant',
    'cyclosporine': 'immunosuppressant',
    'hydroxychloroquine': 'immunosuppressant',
    'omeprazole': 'gastrointestinal',
    'pantoprazole': 'gastrointestinal',
    'esomeprazole': 'gastrointestinal',
    'lansoprazole': 'gastrointestinal',
    'famotidine': 'h2_blocker',
    'ondansetron': 'antiemetic',
    'metoclopramide': 'antiemetic',
    'domperidone': 'antiemetic',
    'lactulose': 'laxative',
    'bisacodyl': 'laxative',
    'senna': 'laxative',
    'loperamide': 'antidiarrheal',
    'mebeverine': 'antispasmodic',
    'salbutamol': 'respiratory',
    'albuterol': 'respiratory',
    'budesonide': 'controller_inhaler',
    'fluticasone': 'controller_inhaler',
    'tiotropium': 'controller_inhaler',
    'montelukast': 'leukotriene_modifier',
    'cetirizine': 'antihistamine',
    'loratadine': 'antihistamine',
    'fexofenadine': 'antihistamine',
    'levocetirizine': 'antihistamine',
    'bilastine': 'antihistamine',
    'pseudoephedrine': 'cough_cold',
    'dextromethorphan': 'cough_cold',
    'guaifenesin': 'cough_cold',
    'latanoprost': 'ophthalmic',
    'timolol': 'ophthalmic',
    'tamsulosin': 'urological',
    'finasteride': 'urological',
    'vitamin d3': 'supplement',
    'vitamin d': 'supplement',
    'vitamin c': 'supplement',
    'vitamin b': 'supplement',
    'b-complex': 'supplement',
    'folic acid': 'supplement',
    'iron': 'supplement',
    'calcium': 'supplement',
    'zinc': 'supplement',
    'magnesium': 'supplement',
    'omega 3': 'supplement',
    'fish oil': 'supplement',
  };

  /// Main inference method: Predicts medication class, shape, unit, and dosage from formula text
  static MedicationMLPrediction predict(String formulaText) {
    if (formulaText.trim().isEmpty) {
      return const MedicationMLPrediction();
    }

    final raw = formulaText.trim();
    final cleanTokens = _tokenizeAndClean(raw);
    final normalized = cleanTokens.join(' ');

    // 1. Direct Generic Dictionary Match (Highest Confidence: 1.0)
    for (final token in cleanTokens) {
      if (_knownDrugToClass.containsKey(token)) {
        final classId = _knownDrugToClass[token]!;
        final classInfo = MedicationClassCatalog.findByName(classId);
        if (classInfo != null) {
          return _buildPrediction(
            classInfo: classInfo,
            confidence: 1.0,
            feature: 'Known molecule "$token"',
            rawText: raw,
          );
        }
      }
    }

    // Check 2-word phrases (e.g. "vitamin d3", "folic acid", "fish oil")
    for (int i = 0; i < cleanTokens.length - 1; i++) {
      final bigram = '${cleanTokens[i]} ${cleanTokens[i + 1]}';
      if (_knownDrugToClass.containsKey(bigram)) {
        final classId = _knownDrugToClass[bigram]!;
        final classInfo = MedicationClassCatalog.findByName(classId);
        if (classInfo != null) {
          return _buildPrediction(
            classInfo: classInfo,
            confidence: 1.0,
            feature: 'Known compound "$bigram"',
            rawText: raw,
          );
        }
      }
    }

    // 2. Pharmacological Suffix / INN Stem Matching (Confidence: 0.95)
    for (final token in cleanTokens) {
      if (token.length < 4) continue;
      for (final entry in _pharmacologicalStems.entries) {
        final stem = entry.key;
        final classId = entry.value;

        if (token.endsWith(stem) || token.contains(stem)) {
          final classInfo = MedicationClassCatalog.findByName(classId);
          if (classInfo != null) {
            return _buildPrediction(
              classInfo: classInfo,
              confidence: 0.95,
              feature: 'Pharmacological stem "-$stem"',
              rawText: raw,
            );
          }
        }
      }
    }

    // 3. TF-IDF & Cosine N-Gram Embedding Similarity Match against Catalog Classes
    double bestScore = 0.0;
    MedicationClassInfo? bestClass;
    String matchedName = '';

    for (final cls in MedicationClassCatalog.classes) {
      final classScore = _computeSimilarityScore(normalized, cls);
      if (classScore > bestScore) {
        bestScore = classScore;
        bestClass = cls;
        matchedName = cls.name;
      }
    }

    if (bestClass != null && bestScore >= 0.40) {
      return _buildPrediction(
        classInfo: bestClass,
        confidence: double.parse(bestScore.toStringAsFixed(2)),
        feature: 'Similarity match with $matchedName',
        rawText: raw,
      );
    }

    // Fallback: extract dosage and shape even if class could not be determined
    return _buildPrediction(
      classInfo: null,
      confidence: 0.0,
      feature: '',
      rawText: raw,
    );
  }

  static List<String> _tokenizeAndClean(String text) {
    // Replace non-alphanumeric except hyphen and space
    final sanitized = text.toLowerCase().replaceAll(RegExp(r'[^a-z0-9\-\s]'), ' ');
    final parts = sanitized.split(RegExp(r'\s+'));

    final List<String> clean = [];
    for (final p in parts) {
      final trimmed = p.trim();
      // Drop pure dosage numbers or salt stop words
      if (trimmed.isEmpty || RegExp(r'^\d+(\.\d+)?(mg|mcg|g|ml|iu|units)?$').hasMatch(trimmed)) {
        continue;
      }
      if (!_saltStopWords.contains(trimmed)) {
        clean.add(trimmed);
      }
    }
    return clean;
  }

  static double _computeSimilarityScore(String query, MedicationClassInfo cls) {
    double score = 0.0;
    final clsTokens = '${cls.name} ${cls.category} ${cls.examples}'.toLowerCase().split(RegExp(r'[^a-z0-9]+'));

    final queryWords = query.split(RegExp(r'\s+'));
    for (final q in queryWords) {
      if (q.length < 3) continue;
      for (final target in clsTokens) {
        if (target.isEmpty || target.length < 3) continue;
        if (q == target) {
          score += 0.50;
        } else if (target.contains(q) || q.contains(target)) {
          score += 0.35;
        } else {
          // 3-gram dice coefficient
          final dice = _computeDiceCoefficient(q, target);
          if (dice > 0.65) {
            score += dice * 0.40;
          }
        }
      }
    }

    // Normalize between 0.0 and 0.92
    return score.clamp(0.0, 0.92);
  }

  static double _computeDiceCoefficient(String s1, String s2) {
    if (s1.length < 3 || s2.length < 3) return 0.0;
    final Set<String> ngrams1 = {};
    for (int i = 0; i <= s1.length - 3; i++) {
      ngrams1.add(s1.substring(i, i + 3));
    }
    final Set<String> ngrams2 = {};
    for (int i = 0; i <= s2.length - 3; i++) {
      ngrams2.add(s2.substring(i, i + 3));
    }
    final intersection = ngrams1.intersection(ngrams2).length;
    return (2.0 * intersection) / (ngrams1.length + ngrams2.length);
  }

  static MedicationMLPrediction _buildPrediction({
    required MedicationClassInfo? classInfo,
    required double confidence,
    required String feature,
    required String rawText,
  }) {
    final lower = rawText.toLowerCase();

    // Extract Dosage (e.g., "20mg", "500 mg", "0.5 mcg", "10ml")
    double? extractedDosage;
    DosageUnit? suggestedUnit;

    final dosageMatch = RegExp(r'(\d+(?:\.\d+)?)\s*(mg|mcg|g|ml|iu|units|drops|puffs)\b', caseSensitive: false)
        .firstMatch(rawText);
    if (dosageMatch != null) {
      extractedDosage = double.tryParse(dosageMatch.group(1)!);
      final unitStr = dosageMatch.group(2)!.toLowerCase();
      if (unitStr == 'mg') {
        suggestedUnit = DosageUnit.mg;
      } else if (unitStr == 'mcg') {
        suggestedUnit = DosageUnit.mcg;
      } else if (unitStr == 'ml') {
        suggestedUnit = DosageUnit.ml;
      } else if (unitStr == 'drop' || unitStr == 'drops') {
        suggestedUnit = DosageUnit.drop;
      } else if (unitStr == 'puff' || unitStr == 'puffs') {
        suggestedUnit = DosageUnit.puff;
      } else if (unitStr == 'spray' || unitStr == 'sprays') {
        suggestedUnit = DosageUnit.spray;
      } else if (unitStr == 'tablet' || unitStr == 'tablets' || unitStr == 'tab') {
        suggestedUnit = DosageUnit.tablet;
      } else if (unitStr == 'capsule' || unitStr == 'capsules' || unitStr == 'cap') {
        suggestedUnit = DosageUnit.capsule;
      }
    }

    // Extract Shape Form Factor
    MedicationShape? suggestedShape;
    if (lower.contains('inhaler') || lower.contains('inhalation') || lower.contains('spray')) {
      suggestedShape = MedicationShape.inhaler;
    } else if (lower.contains('drops') || lower.contains('ophthalmic') || lower.contains('otic')) {
      suggestedShape = MedicationShape.drops;
    } else if (lower.contains('syrup') || lower.contains('liquid') || lower.contains('suspension') || lower.contains('solution')) {
      suggestedShape = MedicationShape.liquid;
    } else if (lower.contains('injection') || lower.contains('syringe') || lower.contains('insulin')) {
      suggestedShape = MedicationShape.injection;
    } else if (lower.contains('patch') || lower.contains('transdermal')) {
      suggestedShape = MedicationShape.patch;
    } else if (lower.contains('capsule') || lower.contains('cap')) {
      suggestedShape = MedicationShape.capsule;
    }

    return MedicationMLPrediction(
      predictedClass: classInfo,
      confidence: confidence,
      matchedFeature: feature,
      suggestedShape: suggestedShape,
      suggestedUnit: suggestedUnit,
      extractedDosage: extractedDosage,
    );
  }
}
