import 'package:flutter/material.dart';

/// Represents a therapeutic or pharmacological class of medication.
class MedicationClassInfo {
  final String id;
  final String name;
  final String category;
  final String examples;
  final String colorHex;
  final String icon;

  const MedicationClassInfo({
    required this.id,
    required this.name,
    required this.category,
    required this.examples,
    required this.colorHex,
    required this.icon,
  });

  bool matches(String query) {
    final q = query.trim().toLowerCase();
    if (q.isEmpty) return true;
    return name.toLowerCase().contains(q) ||
        category.toLowerCase().contains(q) ||
        examples.toLowerCase().contains(q) ||
        id.toLowerCase().contains(q);
  }
}

/// Comprehensive Catalog of standardized medical classes for MedDay Flow.
class MedicationClassCatalog {
  static const List<MedicationClassInfo> classes = [
    // -------------------------------------------------------------
    // PAIN & FEVER
    // -------------------------------------------------------------
    MedicationClassInfo(
      id: 'analgesic',
      name: 'Analgesic / Pain Relief (NSAID)',
      category: 'Pain & Fever',
      examples: 'Ibuprofen, Naproxen, Diclofenac, Celecoxib, Meloxicam',
      colorHex: '#EF4444',
      icon: '⚡',
    ),
    MedicationClassInfo(
      id: 'analgesic_non_opioid',
      name: 'Non-Opioid Analgesic / Antipyretic',
      category: 'Pain & Fever',
      examples: 'Paracetamol / Acetaminophen',
      colorHex: '#F87171',
      icon: '🌡️',
    ),
    MedicationClassInfo(
      id: 'opioid',
      name: 'Opioid Analgesic',
      category: 'Pain & Fever',
      examples: 'Tramadol, Codeine, Morphine, Oxycodone, Fentanyl',
      colorHex: '#DC2626',
      icon: '🛡️',
    ),
    MedicationClassInfo(
      id: 'muscle_relaxant',
      name: 'Skeletal Muscle Relaxant',
      category: 'Pain & Fever',
      examples: 'Cyclobenzaprine, Tizanidine, Baclofen, Methocarbamol',
      colorHex: '#FB923C',
      icon: '🧘',
    ),
    MedicationClassInfo(
      id: 'anti_gout',
      name: 'Anti-Gout / Uric Acid Lowering',
      category: 'Pain & Fever',
      examples: 'Allopurinol, Febuxostat, Colchicine',
      colorHex: '#EA580C',
      icon: '🦶',
    ),
    MedicationClassInfo(
      id: 'bone_health',
      name: 'Bisphosphonate / Bone Health',
      category: 'Pain & Fever',
      examples: 'Alendronate, Risedronate, Ibandronate, Zoledronic Acid',
      colorHex: '#D97706',
      icon: '🦴',
    ),

    // -------------------------------------------------------------
    // CARDIOVASCULAR
    // -------------------------------------------------------------
    MedicationClassInfo(
      id: 'antihypertensive',
      name: 'Antihypertensive (General BP)',
      category: 'Cardiovascular',
      examples: 'Amlodipine, Lisinopril, Losartan, Bisoprolol',
      colorHex: '#3B82F6',
      icon: '🫀',
    ),
    MedicationClassInfo(
      id: 'ace_inhibitor',
      name: 'ACE Inhibitor',
      category: 'Cardiovascular',
      examples: 'Lisinopril, Enalapril, Ramipril, Captopril, Perindopril',
      colorHex: '#2563EB',
      icon: '🩸',
    ),
    MedicationClassInfo(
      id: 'arb',
      name: 'Angiotensin Receptor Blocker (ARB)',
      category: 'Cardiovascular',
      examples: 'Losartan, Valsartan, Telmisartan, Candesartan, Olmesartan',
      colorHex: '#1D4ED8',
      icon: '💓',
    ),
    MedicationClassInfo(
      id: 'beta_blocker',
      name: 'Beta-Blocker',
      category: 'Cardiovascular',
      examples: 'Metoprolol, Bisoprolol, Atenolol, Carvedilol, Propranolol',
      colorHex: '#0284C7',
      icon: '📉',
    ),
    MedicationClassInfo(
      id: 'calcium_channel_blocker',
      name: 'Calcium Channel Blocker (CCB)',
      category: 'Cardiovascular',
      examples: 'Amlodipine, Nifedipine, Diltiazem, Verapamil, Felodipine',
      colorHex: '#0369A1',
      icon: '⏱️',
    ),
    MedicationClassInfo(
      id: 'diuretic',
      name: 'Diuretic (Water Pill)',
      category: 'Cardiovascular',
      examples: 'Hydrochlorothiazide, Furosemide, Spironolactone, Indapamide',
      colorHex: '#06B6D4',
      icon: '💧',
    ),
    MedicationClassInfo(
      id: 'statin',
      name: 'Statin / Lipid Lowering (Cholesterol)',
      category: 'Cardiovascular',
      examples: 'Atorvastatin, Rosuvastatin, Simvastatin, Pravastatin',
      colorHex: '#0D9488',
      icon: '🧪',
    ),
    MedicationClassInfo(
      id: 'anticoagulant',
      name: 'Anticoagulant (Blood Thinner)',
      category: 'Cardiovascular',
      examples: 'Apixaban, Rivaroxaban, Dabigatran, Warfarin, Enoxaparin',
      colorHex: '#B91C1C',
      icon: '🩸',
    ),
    MedicationClassInfo(
      id: 'antiplatelet',
      name: 'Antiplatelet',
      category: 'Cardiovascular',
      examples: 'Aspirin (low-dose 75/81mg), Clopidogrel, Ticagrelor',
      colorHex: '#991B1B',
      icon: '🛑',
    ),
    MedicationClassInfo(
      id: 'antiarrhythmic',
      name: 'Antiarrhythmic',
      category: 'Cardiovascular',
      examples: 'Amiodarone, Flecainide, Digoxin, Sotalol',
      colorHex: '#4F46E5',
      icon: '📈',
    ),
    MedicationClassInfo(
      id: 'nitrate',
      name: 'Nitrate / Anti-Anginal (Vasodilator)',
      category: 'Cardiovascular',
      examples: 'Nitroglycerin, Isosorbide Mononitrate, Isosorbide Dinitrate',
      colorHex: '#7C3AED',
      icon: '❤️',
    ),

    // -------------------------------------------------------------
    // ENDOCRINE & METABOLISM
    // -------------------------------------------------------------
    MedicationClassInfo(
      id: 'antidiabetic',
      name: 'Antidiabetic / Biguanide (Metformin)',
      category: 'Endocrine & Metabolism',
      examples: 'Metformin, Metformin XR',
      colorHex: '#F59E0B',
      icon: '🩸',
    ),
    MedicationClassInfo(
      id: 'sglt2_inhibitor',
      name: 'SGLT2 Inhibitor (Gliflozin)',
      category: 'Endocrine & Metabolism',
      examples: 'Empagliflozin, Dapagliflozin, Canagliflozin',
      colorHex: '#D97706',
      icon: '🔬',
    ),
    MedicationClassInfo(
      id: 'glp1_agonist',
      name: 'GLP-1 Receptor Agonist',
      category: 'Endocrine & Metabolism',
      examples: 'Semaglutide, Liraglutide, Dulaglutide, Tirzepatide',
      colorHex: '#B45309',
      icon: '💉',
    ),
    MedicationClassInfo(
      id: 'dpp4_sulfonylurea',
      name: 'DPP-4 Inhibitor / Sulfonylurea',
      category: 'Endocrine & Metabolism',
      examples: 'Sitagliptin, Linagliptin, Glimepiride, Gliclazide',
      colorHex: '#EAB308',
      icon: '🍯',
    ),
    MedicationClassInfo(
      id: 'insulin',
      name: 'Insulin Therapy',
      category: 'Endocrine & Metabolism',
      examples: 'Insulin Glargine, Detemir, Aspart, Lispro, NPH',
      colorHex: '#CA8A04',
      icon: '💉',
    ),
    MedicationClassInfo(
      id: 'thyroid',
      name: 'Thyroid Hormone (Levothyroxine)',
      category: 'Endocrine & Metabolism',
      examples: 'Levothyroxine Sodium, Liothyronine',
      colorHex: '#14B8A6',
      icon: '🦋',
    ),
    MedicationClassInfo(
      id: 'antithyroid',
      name: 'Antithyroid Agent',
      category: 'Endocrine & Metabolism',
      examples: 'Methimazole, Propylthiouracil, Carbimazole',
      colorHex: '#0D9488',
      icon: '🛡️',
    ),
    MedicationClassInfo(
      id: 'corticosteroid',
      name: 'Oral / Systemic Corticosteroid',
      category: 'Endocrine & Metabolism',
      examples: 'Prednisolone, Prednisone, Dexamethasone, Methylprednisolone',
      colorHex: '#D946EF',
      icon: '🌿',
    ),
    MedicationClassInfo(
      id: 'hormone_therapy',
      name: 'Hormonal Therapy / Contraceptive',
      category: 'Endocrine & Metabolism',
      examples: 'Estradiol, Progesterone, Levonorgestrel, Testosterone',
      colorHex: '#EC4899',
      icon: '🌸',
    ),

    // -------------------------------------------------------------
    // MENTAL HEALTH & NEUROLOGY
    // -------------------------------------------------------------
    MedicationClassInfo(
      id: 'antidepressant',
      name: 'Antidepressant (SSRI / SNRI)',
      category: 'Mental Health & Neurology',
      examples: 'Sertraline, Fluoxetine, Escitalopram, Duloxetine, Venlafaxine',
      colorHex: '#8B5CF6',
      icon: '🧠',
    ),
    MedicationClassInfo(
      id: 'antipsychotic',
      name: 'Antipsychotic / Mood Stabilizer',
      category: 'Mental Health & Neurology',
      examples: 'Quetiapine, Olanzapine, Aripiprazole, Risperidone, Lithium',
      colorHex: '#6366F1',
      icon: '🌙',
    ),
    MedicationClassInfo(
      id: 'anxiolytic',
      name: 'Anxiolytic / Sedative (Anti-Anxiety)',
      category: 'Mental Health & Neurology',
      examples: 'Alprazolam, Clonazepam, Lorazepam, Diazepam, Buspirone',
      colorHex: '#A855F7',
      icon: '🕊️',
    ),
    MedicationClassInfo(
      id: 'anticonvulsant',
      name: 'Anticonvulsant / Antiepileptic',
      category: 'Mental Health & Neurology',
      examples: 'Levetiracetam, Lamotrigine, Carbamazepine, Valproate, Gabapentin, Pregabalin',
      colorHex: '#7C3AED',
      icon: '⚡',
    ),
    MedicationClassInfo(
      id: 'sleep_aid',
      name: 'Sedative / Hypnotic (Sleep Aid)',
      category: 'Mental Health & Neurology',
      examples: 'Zolpidem, Zopiclone, Melatonin, Eszopiclone',
      colorHex: '#4338CA',
      icon: '💤',
    ),
    MedicationClassInfo(
      id: 'migraine',
      name: 'Anti-Migraine / Triptan / CGRP',
      category: 'Mental Health & Neurology',
      examples: 'Sumatriptan, Zolmitriptan, Rimegepant, Ubrogepant',
      colorHex: '#C026D3',
      icon: '💆',
    ),
    MedicationClassInfo(
      id: 'adhd_stimulant',
      name: 'ADHD / CNS Stimulant & Non-Stimulant',
      category: 'Mental Health & Neurology',
      examples: 'Methylphenidate, Lisdexamfetamine, Atomoxetine',
      colorHex: '#DB2777',
      icon: '🎯',
    ),
    MedicationClassInfo(
      id: 'parkinsons',
      name: 'Antiparkinsonian / Dopaminergic',
      category: 'Mental Health & Neurology',
      examples: 'Levodopa/Carbidopa, Pramipexole, Ropinirole, Selegiline',
      colorHex: '#9333EA',
      icon: '🤝',
    ),
    MedicationClassInfo(
      id: 'dementia',
      name: 'Anti-Dementia / Cholinesterase Inhibitor',
      category: 'Mental Health & Neurology',
      examples: 'Donepezil, Rivastigmine, Memantine, Galantamine',
      colorHex: '#6D28D9',
      icon: '🧩',
    ),

    // -------------------------------------------------------------
    // INFECTION & IMMUNOLOGY
    // -------------------------------------------------------------
    MedicationClassInfo(
      id: 'antibiotic',
      name: 'Antibiotic (Broad Spectrum / Penicillin)',
      category: 'Infection & Immunology',
      examples: 'Amoxicillin, Amoxicillin-Clavulanate, Ampicillin',
      colorHex: '#10B981',
      icon: '🛡️',
    ),
    MedicationClassInfo(
      id: 'cephalosporin',
      name: 'Antibiotic (Cephalosporin)',
      category: 'Infection & Immunology',
      examples: 'Cephalexin, Cefuroxime, Cefixime, Ceftriaxone',
      colorHex: '#059669',
      icon: '💊',
    ),
    MedicationClassInfo(
      id: 'fluoroquinolone_macrolide',
      name: 'Antibiotic (Fluoroquinolone / Macrolide)',
      category: 'Infection & Immunology',
      examples: 'Ciprofloxacin, Levofloxacin, Azithromycin, Clarithromycin',
      colorHex: '#047857',
      icon: '🔬',
    ),
    MedicationClassInfo(
      id: 'antiviral',
      name: 'Antiviral',
      category: 'Infection & Immunology',
      examples: 'Acyclovir, Valacyclovir, Oseltamivir, Paxlovid, Tenofovir',
      colorHex: '#0E7490',
      icon: '🧬',
    ),
    MedicationClassInfo(
      id: 'antifungal',
      name: 'Antifungal',
      category: 'Infection & Immunology',
      examples: 'Fluconazole, Itraconazole, Terbinafine, Nystatin',
      colorHex: '#0F766E',
      icon: '🍄',
    ),
    MedicationClassInfo(
      id: 'antiparasitic',
      name: 'Antiparasitic / Anthelmintic',
      category: 'Infection & Immunology',
      examples: 'Metronidazole, Albendazole, Ivermectin, Mebendazole',
      colorHex: '#15803D',
      icon: '🦠',
    ),
    MedicationClassInfo(
      id: 'immunosuppressant',
      name: 'Immunosuppressant / DMARD',
      category: 'Infection & Immunology',
      examples: 'Methotrexate, Tacrolimus, Cyclosporine, Hydroxychloroquine, Azathioprine',
      colorHex: '#047857',
      icon: '🌱',
    ),

    // -------------------------------------------------------------
    // GASTROINTESTINAL
    // -------------------------------------------------------------
    MedicationClassInfo(
      id: 'gastrointestinal',
      name: 'Proton Pump Inhibitor (PPI)',
      category: 'Gastrointestinal',
      examples: 'Omeprazole, Pantoprazole, Esomeprazole, Lansoprazole, Rabeprazole',
      colorHex: '#F97316',
      icon: '🧪',
    ),
    MedicationClassInfo(
      id: 'h2_blocker',
      name: 'H2 Receptor Blocker / Antacid',
      category: 'Gastrointestinal',
      examples: 'Famotidine, Cimetidine, Calcium Carbonate, Magnesium Hydroxide',
      colorHex: '#FB923C',
      icon: '🥛',
    ),
    MedicationClassInfo(
      id: 'antiemetic',
      name: 'Antiemetic (Anti-Nausea)',
      category: 'Gastrointestinal',
      examples: 'Ondansetron, Metoclopramide, Domperidone, Prochlorperazine',
      colorHex: '#F59E0B',
      icon: '🤢',
    ),
    MedicationClassInfo(
      id: 'laxative',
      name: 'Laxative / Stool Softener',
      category: 'Gastrointestinal',
      examples: 'Lactulose, Polyethylene Glycol (PEG), Senna, Bisacodyl, Docusate',
      colorHex: '#D97706',
      icon: '🚾',
    ),
    MedicationClassInfo(
      id: 'antidiarrheal',
      name: 'Antidiarrheal / GI Motility',
      category: 'Gastrointestinal',
      examples: 'Loperamide, Bismuth Subsalicylate, Racecadotril',
      colorHex: '#B45309',
      icon: '⏹️',
    ),
    MedicationClassInfo(
      id: 'antispasmodic',
      name: 'Antispasmodic (IBS / Cramping)',
      category: 'Gastrointestinal',
      examples: 'Mebeverine, Hyoscine Butylbromide, Dicyclomine',
      colorHex: '#92400E',
      icon: '🌀',
    ),

    // -------------------------------------------------------------
    // RESPIRATORY & ALLERGY
    // -------------------------------------------------------------
    MedicationClassInfo(
      id: 'respiratory',
      name: 'Bronchodilator (SABA Rescue Inhaler)',
      category: 'Respiratory & Allergy',
      examples: 'Salbutamol / Albuterol, Levalbuterol, Terbutaline',
      colorHex: '#0EA5E9',
      icon: '🫁',
    ),
    MedicationClassInfo(
      id: 'controller_inhaler',
      name: 'Controller Inhaler (ICS / LABA / LAMA)',
      category: 'Respiratory & Allergy',
      examples: 'Budesonide/Formoterol, Fluticasone/Salmeterol, Tiotropium',
      colorHex: '#0284C7',
      icon: '💨',
    ),
    MedicationClassInfo(
      id: 'antihistamine',
      name: 'Antihistamine / Allergy',
      category: 'Respiratory & Allergy',
      examples: 'Cetirizine, Loratadine, Fexofenadine, Levocetirizine, Bilastine',
      colorHex: '#EC4899',
      icon: '🌸',
    ),
    MedicationClassInfo(
      id: 'leukotriene_modifier',
      name: 'Leukotriene Receptor Antagonist',
      category: 'Respiratory & Allergy',
      examples: 'Montelukast, Zafirlukast',
      colorHex: '#38BDF8',
      icon: '🛡️',
    ),
    MedicationClassInfo(
      id: 'cough_cold',
      name: 'Cough, Cold & Decongestant',
      category: 'Respiratory & Allergy',
      examples: 'Dextromethorphan, Guaifenesin, Pseudoephedrine, Phenylephrine',
      colorHex: '#7DD3FC',
      icon: '🤧',
    ),

    // -------------------------------------------------------------
    // SPECIALTY & TOPICAL
    // -------------------------------------------------------------
    MedicationClassInfo(
      id: 'ophthalmic',
      name: 'Ophthalmic (Eye Drops / Ointment)',
      category: 'Specialty & Topical',
      examples: 'Latanoprost, Timolol, Tobramycin Drops, Artificial Tears, Olopatadine',
      colorHex: '#06B6D4',
      icon: '👁️',
    ),
    MedicationClassInfo(
      id: 'otic',
      name: 'Otic (Ear Drops)',
      category: 'Specialty & Topical',
      examples: 'Ofloxacin Otic, Ciprofloxacin/Dexamethasone, Acetic Acid Drops',
      colorHex: '#0891B2',
      icon: '👂',
    ),
    MedicationClassInfo(
      id: 'dermatological',
      name: 'Dermatological / Topical Cream',
      category: 'Specialty & Topical',
      examples: 'Hydrocortisone, Betamethasone, Clotrimazole Cream, Mupirocin, Tretinoin',
      colorHex: '#F472B6',
      icon: '🧴',
    ),
    MedicationClassInfo(
      id: 'urological',
      name: 'Urological / BPH / Overactive Bladder',
      category: 'Specialty & Topical',
      examples: 'Tamsulosin, Finasteride, Solifenacin, Mirabegron, Oxybutynin',
      colorHex: '#818CF8',
      icon: '🚻',
    ),
    MedicationClassInfo(
      id: 'chemotherapy',
      name: 'Antineoplastic / Oncology',
      category: 'Specialty & Topical',
      examples: 'Capecitabine, Imatinib, Tamoxifen, Anastrozole',
      colorHex: '#475569',
      icon: '🎗️',
    ),
    MedicationClassInfo(
      id: 'supplement',
      name: 'Vitamin & Mineral Supplement',
      category: 'Nutrition & Supplements',
      examples: 'Vitamin D3, B-Complex, Vitamin C, Iron, Calcium, Zinc, Magnesium',
      colorHex: '#EAB308',
      icon: '✨',
    ),
    MedicationClassInfo(
      id: 'other',
      name: 'Other / Specialty Medication',
      category: 'General',
      examples: 'Miscellaneous compounds, clinical trial items, unique preparations',
      colorHex: '#64748B',
      icon: '💊',
    ),
  ];

  static List<String> get categories {
    final Set<String> cats = {};
    for (final c in classes) {
      cats.add(c.category);
    }
    return cats.toList();
  }

  static MedicationClassInfo? findByName(String? name) {
    if (name == null || name.trim().isEmpty) return null;
    final trimmed = name.trim().toLowerCase();
    try {
      return classes.firstWhere(
        (c) =>
            c.name.toLowerCase() == trimmed ||
            c.id.toLowerCase() == trimmed ||
            c.name.toLowerCase().startsWith(trimmed),
      );
    } catch (_) {
      return null;
    }
  }

  static Color parseColor(String hex) {
    try {
      final clean = hex.replaceAll('#', '');
      return Color(int.parse('FF$clean', radix: 16));
    } catch (_) {
      return const Color(0xFF3B82F6);
    }
  }
}
