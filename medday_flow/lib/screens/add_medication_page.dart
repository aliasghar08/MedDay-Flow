import 'dart:async';
import 'package:medday_flow/providers/auth_provider.dart' as app_auth;
import 'package:medday_flow/providers/medication_provider.dart';
import 'package:medday_flow/services/medication_ml_classifier_service.dart';
import 'package:medday_flow/utils/medication_model/frequency_and_dosage.dart';
import 'package:medday_flow/utils/medication_model/medication_model.dart';
import 'package:medday_flow/utils/medication_model/medication_schedule_model.dart';
import 'package:medday_flow/utils/medication_model/medication_classes.dart';
import 'package:medday_flow/widgets/medication_pill_graphic.dart';
import 'package:medday_flow/widgets/ad_banner_widget.dart';
import 'package:medday_flow/widgets/searchable_medication_class_sheet.dart';
import 'package:flutter/material.dart';
import 'package:medday_flow/services/custom_state_management.dart';

class AddMedicationPage extends StatefulWidget {
  final Medication? existingMedication;
  final MedicationSchedule? existingSchedule;

  const AddMedicationPage({
    super.key,
    this.existingMedication,
    this.existingSchedule,
  });

  @override
  State<AddMedicationPage> createState() => _AddMedicationPageState();
}

class _AddMedicationPageState extends State<AddMedicationPage> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _formulaController = TextEditingController();
  final _dosageController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _instructionsController = TextEditingController();

  String _selectedColor = '#2563EB';
  String? _selectedSecondaryColor;
  bool _isDualTone = false;
  MedicationShape _selectedShape = MedicationShape.capsule;
  String? _selectedClass;
  String _selectedIcon = '💊';
  DosageUnit _selectedUnit = DosageUnit.mg;
  double _dosage = 0.0;

  // Scheduling variables
  MedicationFrequency _selectedFrequency = MedicationFrequency.daily;
  DateTime _startDate = DateTime.now();
  DateTime? _endDate;
  final List<TimeOfDay> _selectedTimes = [];
  final List<int> _selectedDays = []; // 0-6 for Monday-Sunday
  final List<DateTime> _selectedCustomDates = [];
  int _reminderMinutesBefore = 15;
  bool _isSaving = false;

  // ML Classification & Prediction variables
  Timer? _formulaDebounceTimer;
  bool _userManuallyOverrodeClass = false;
  MedicationMLPrediction? _lastMlPrediction;

  // Form factor / tablet shape options
  final List<Map<String, dynamic>> _shapeOptions = [
    {
      'shape': MedicationShape.capsule,
      'name': 'Capsule',
      'icon': Icons.medication_rounded,
    },
    {
      'shape': MedicationShape.round,
      'name': 'Round',
      'icon': Icons.circle_outlined,
    },
    {
      'shape': MedicationShape.oval,
      'name': 'Oval',
      'icon': Icons.egg_outlined,
    },
    {
      'shape': MedicationShape.oblong,
      'name': 'Caplet',
      'icon': Icons.crop_portrait_rounded,
    },
    {
      'shape': MedicationShape.liquid,
      'name': 'Syrup',
      'icon': Icons.water_drop_outlined,
    },
    {
      'shape': MedicationShape.drops,
      'name': 'Drops',
      'icon': Icons.opacity_rounded,
    },
    {
      'shape': MedicationShape.inhaler,
      'name': 'Inhaler',
      'icon': Icons.air_rounded,
    },
    {
      'shape': MedicationShape.injection,
      'name': 'Injection',
      'icon': Icons.vaccines_outlined,
    },
    {
      'shape': MedicationShape.patch,
      'name': 'Patch',
      'icon': Icons.crop_square_rounded,
    },
    {
      'shape': MedicationShape.topical,
      'name': 'Topical',
      'icon': Icons.sanitizer_outlined,
    },
  ];

  // Color options for medication
  final List<Map<String, dynamic>> _colorOptions = [
    {'color': '#2563EB', 'name': 'Sky Blue'},
    {'color': '#1D4ED8', 'name': 'Royal Navy'},
    {'color': '#EF4444', 'name': 'Coral Red'},
    {'color': '#B91C1C', 'name': 'Ruby Red'},
    {'color': '#10B981', 'name': 'Emerald'},
    {'color': '#047857', 'name': 'Forest Green'},
    {'color': '#F59E0B', 'name': 'Amber'},
    {'color': '#EAB308', 'name': 'Sun Yellow'},
    {'color': '#8B5CF6', 'name': 'Lavender'},
    {'color': '#6D28D9', 'name': 'Purple'},
    {'color': '#06B6D4', 'name': 'Teal Cyan'},
    {'color': '#EC4899', 'name': 'Rose Pink'},
    {'color': '#F1F5F9', 'name': 'Pill White'},
    {'color': '#64748B', 'name': 'Slate Grey'},
  ];

  // Day options
  final List<Map<String, dynamic>> _dayOptions = [
    {'index': 0, 'name': 'Monday', 'short': 'Mon'},
    {'index': 1, 'name': 'Tuesday', 'short': 'Tue'},
    {'index': 2, 'name': 'Wednesday', 'short': 'Wed'},
    {'index': 3, 'name': 'Thursday', 'short': 'Thu'},
    {'index': 4, 'name': 'Friday', 'short': 'Fri'},
    {'index': 5, 'name': 'Saturday', 'short': 'Sat'},
    {'index': 6, 'name': 'Sunday', 'short': 'Sun'},
  ];

  @override
  void initState() {
    super.initState();
    // Pre-fill form if editing existing medication
    if (widget.existingMedication != null) {
      _nameController.text = widget.existingMedication!.name;
      _formulaController.text = widget.existingMedication!.formula ?? '';
      _dosageController.text = widget.existingMedication!.dosage.toString();
      _descriptionController.text = widget.existingMedication!.description ?? '';
      _selectedColor = widget.existingMedication!.color;
      _selectedSecondaryColor = widget.existingMedication!.secondaryColor;
      _isDualTone = widget.existingMedication!.secondaryColor != null;
      _selectedShape = MedicationShape.fromString(widget.existingMedication!.shape);
      _selectedClass = widget.existingMedication!.medicationClass;
      _selectedIcon = widget.existingMedication!.icon;
      _selectedUnit = widget.existingMedication!.unit;
      _dosage = widget.existingMedication!.dosage;
      _userManuallyOverrodeClass = widget.existingMedication!.medicationClass != null &&
          widget.existingMedication!.medicationClass!.trim().isNotEmpty;
    }

    // Pre-fill schedule if editing existing schedule
    if (widget.existingSchedule != null) {
      _selectedFrequency = widget.existingSchedule!.frequency;
      _startDate = widget.existingSchedule!.startDate;
      _endDate = widget.existingSchedule!.endDate;
      _selectedTimes.addAll(widget.existingSchedule!.timesPerDay);
      _selectedDays.addAll(widget.existingSchedule!.daysOfWeek);
      _selectedCustomDates.addAll(widget.existingSchedule!.specificDates);
      _instructionsController.text = widget.existingSchedule!.instructions ?? '';
      _reminderMinutesBefore = widget.existingSchedule!.reminderMinutesBefore;
    } else {
      // Default initial time
      _selectedTimes.add(const TimeOfDay(hour: 8, minute: 0));
    }
  }

  void _onFormulaChanged(String text) {
    setState(() {}); // refresh live preview
    _formulaDebounceTimer?.cancel();
    if (text.trim().isEmpty) {
      setState(() {
        _lastMlPrediction = null;
      });
      return;
    }

    _formulaDebounceTimer = Timer(const Duration(milliseconds: 250), () {
      if (!mounted) return;
      final prediction = MedicationMLClassifierService.predict(text);
      setState(() {
        _lastMlPrediction = prediction;
        if (prediction.hasPrediction && !_userManuallyOverrodeClass) {
          _selectedClass = prediction.predictedClass!.name;
          if (prediction.extractedDosage != null &&
              (_dosage == 0.0 || _dosageController.text.isEmpty || _dosageController.text == '0.0')) {
            _dosage = prediction.extractedDosage!;
            _dosageController.text = prediction.extractedDosage!.toString();
          }
          if (prediction.suggestedUnit != null) {
            _selectedUnit = prediction.suggestedUnit!;
          }
          if (prediction.suggestedShape != null) {
            _selectedShape = prediction.suggestedShape!;
          }
        }
      });
    });
  }

  @override
  void dispose() {
    _formulaDebounceTimer?.cancel();
    _nameController.dispose();
    _formulaController.dispose();
    _dosageController.dispose();
    _descriptionController.dispose();
    _instructionsController.dispose();
    super.dispose();
  }

  Future<void> _saveMedication() async {
    if (!_formKey.currentState!.validate()) return;
    _formKey.currentState!.save();

    // Validate scheduling
    if (_selectedTimes.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please add at least one intake time')),
      );
      return;
    }

    if (_selectedFrequency == MedicationFrequency.weekly && _selectedDays.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select at least one day for weekly schedule')),
      );
      return;
    }

    if (_selectedFrequency == MedicationFrequency.custom && _selectedCustomDates.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select at least one date for custom schedule')),
      );
      return;
    }

    final authProvider = context.read<app_auth.AuthProvider>();
    if (authProvider.user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('User not authenticated')),
      );
      return;
    }

    setState(() {
      _isSaving = true;
    });

    try {
      final medProvider = context.read<MedicationProvider>();

      final medicationId = widget.existingMedication?.medicationId ??
          'med_${DateTime.now().millisecondsSinceEpoch}';
      final scheduleId = widget.existingSchedule?.scheduleId ??
          'sched_${DateTime.now().millisecondsSinceEpoch}';

      final medication = Medication(
        medicationId: medicationId,
        name: _nameController.text.trim(),
        formula: _formulaController.text.trim().isEmpty
            ? null
            : _formulaController.text.trim(),
        medicationClass: _selectedClass,
        shape: _selectedShape.name,
        secondaryColor: _isDualTone && _selectedSecondaryColor != null
            ? _selectedSecondaryColor
            : null,
        dosage: _dosage,
        unit: _selectedUnit,
        description: _descriptionController.text.trim().isEmpty
            ? null
            : _descriptionController.text.trim(),
        color: _selectedColor,
        icon: _selectedIcon,
        createdAt: widget.existingMedication?.createdAt ?? DateTime.now(),
        isActive: widget.existingMedication?.isActive ?? true,
      );

      final schedule = MedicationSchedule(
        scheduleId: scheduleId,
        medication: medication,
        startDate: _startDate,
        endDate: _endDate,
        frequency: _selectedFrequency,
        timesPerDay: _selectedTimes,
        daysOfWeek: _selectedDays,
        specificDates: _selectedCustomDates,
        instructions: _instructionsController.text.trim().isEmpty
            ? null
            : _instructionsController.text.trim(),
        reminderMinutesBefore: _reminderMinutesBefore,
        createdAt: widget.existingSchedule?.createdAt ?? DateTime.now(),
      );

      await medProvider.saveMedication(
        medication: medication,
        schedule: schedule,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${medication.name} saved successfully!'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.pop(context, medication);
      }
    } catch (e) {
      debugPrint('Error saving medication: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to save medication: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  Future<void> _addTime() async {
    final TimeOfDay? pickedTime = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.now(),
    );

    if (pickedTime != null) {
      setState(() {
        _selectedTimes.add(pickedTime);
        _selectedTimes.sort((a, b) => a.hour.compareTo(b.hour));
      });
    }
  }

  void _removeTime(TimeOfDay time) {
    setState(() {
      _selectedTimes.remove(time);
    });
  }

  void _toggleDay(int dayIndex) {
    setState(() {
      if (_selectedDays.contains(dayIndex)) {
        _selectedDays.remove(dayIndex);
      } else {
        _selectedDays.add(dayIndex);
      }
      _selectedDays.sort();
    });
  }

  Future<void> _pickStartDate() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _startDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (picked != null) {
      setState(() {
        _startDate = picked;
      });
    }
  }

  Future<void> _pickEndDate() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _endDate ?? _startDate.add(const Duration(days: 30)),
      firstDate: _startDate,
      lastDate: DateTime(2100),
    );
    if (picked != null) {
      setState(() {
        _endDate = picked;
      });
    }
  }

  Future<void> _addCustomDate() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime.now(),
      lastDate: DateTime(2100),
    );
    if (picked != null) {
      setState(() {
        _selectedCustomDates.add(picked);
        _selectedCustomDates.sort((a, b) => a.compareTo(b));
      });
    }
  }

  void _removeCustomDate(DateTime date) {
    setState(() {
      _selectedCustomDates.remove(date);
    });
  }

  Color _parseColor(String colorHex) {
    try {
      final hex = colorHex.replaceAll('#', '');
      return Color(int.parse('FF$hex', radix: 16));
    } catch (_) {
      return Colors.blue;
    }
  }

  Color _getTextColor(Color backgroundColor) {
    return backgroundColor.computeLuminance() > 0.5 ? Colors.black : Colors.white;
  }

  Widget _buildFrequencySection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Schedule Frequency',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        DropdownButtonFormField<MedicationFrequency>(
          initialValue: _selectedFrequency,
          isExpanded: true, // ✅ FIX: prevents text overflow
          decoration: const InputDecoration(
            labelText: 'Frequency',
            border: OutlineInputBorder(),
          ),
          items: MedicationFrequency.values.map((frequency) {
            return DropdownMenuItem<MedicationFrequency>(
              value: frequency,
              child: Text(
                _getFrequencyDisplayName(frequency),
                overflow: TextOverflow.ellipsis,
              ),
            );
          }).toList(),
          onChanged: (value) {
            if (value != null) {
              setState(() {
                _selectedFrequency = value;
              });
            }
          },
        ),
      ],
    );
  }

  Widget _buildDaysSection() {
    if (_selectedFrequency != MedicationFrequency.weekly) return const SizedBox();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 16),
        const Text(
          'Select Days',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: _dayOptions.map((day) {
            final isSelected = _selectedDays.contains(day['index']);
            return FilterChip(
              label: Text(day['short']),
              selected: isSelected,
              onSelected: (selected) => _toggleDay(day['index']),
              selectedColor: Colors.blue.withValues(alpha: 0.2),
              checkmarkColor: Colors.blue,
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildTimesSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 16),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Intake Times',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            IconButton(
              onPressed: _addTime,
              icon: const Icon(Icons.add_alarm),
              tooltip: 'Add Time',
            ),
          ],
        ),
        const SizedBox(height: 8),
        if (_selectedTimes.isEmpty)
          const Text(
            'No times added. Tap the + button to add intake times.',
            style: TextStyle(color: Colors.grey),
          )
        else
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _selectedTimes.map((time) {
              return Chip(
                label: Text(_formatTime(time)),
                onDeleted: () => _removeTime(time),
                deleteIconColor: Colors.red,
              );
            }).toList(),
          ),
      ],
    );
  }

  Widget _buildCustomDatesSection() {
    if (_selectedFrequency != MedicationFrequency.custom) return const SizedBox();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 16),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Specific Dates',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            IconButton(
              onPressed: _addCustomDate,
              icon: const Icon(Icons.add_circle),
              tooltip: 'Add Date',
            ),
          ],
        ),
        const SizedBox(height: 8),
        if (_selectedCustomDates.isEmpty)
          const Text(
            'No dates added. Tap the + button to add specific dates.',
            style: TextStyle(color: Colors.grey),
          )
        else
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _selectedCustomDates.map((date) {
              return Chip(
                label: Text(_formatDate(date)),
                onDeleted: () => _removeCustomDate(date),
                deleteIconColor: Colors.red,
              );
            }).toList(),
          ),
      ],
    );
  }

  Widget _buildDateRangeSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 16),
        const Text(
          'Schedule Dates',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: ListTile(
                title: const Text('Start Date'),
                subtitle: Text(_formatDate(_startDate)),
                trailing: const Icon(Icons.calendar_today),
                onTap: _pickStartDate,
              ),
            ),
            Expanded(
              child: ListTile(
                title: const Text('End Date (Optional)'),
                subtitle: Text(
                  _endDate != null ? _formatDate(_endDate!) : 'No end date',
                ),
                trailing: IconButton(
                  icon: const Icon(Icons.calendar_today),
                  onPressed: _pickEndDate,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildReminderSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 16),
        const Text(
          'Reminder Settings',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        DropdownButtonFormField<int>(
          initialValue: _reminderMinutesBefore,
          isExpanded: true, // ✅ FIX: prevents text overflow
          decoration: const InputDecoration(
            labelText: 'Remind Before',
            border: OutlineInputBorder(),
          ),
          items: [0, 5, 10, 15, 30, 60].map((minutes) {
            return DropdownMenuItem<int>(
              value: minutes,
              child: Text(
                minutes == 0 ? 'At exact time' : '$minutes minutes before',
                overflow: TextOverflow.ellipsis,
              ),
            );
          }).toList(),
          onChanged: (value) {
            if (value != null) {
              setState(() {
                _reminderMinutesBefore = value;
              });
            }
          },
        ),
      ],
    );
  }

  String _formatTime(TimeOfDay time) {
    final hour = time.hourOfPeriod == 0 ? 12 : time.hourOfPeriod;
    final minute = time.minute.toString().padLeft(2, '0');
    final period = time.period == DayPeriod.am ? 'AM' : 'PM';
    return '$hour:$minute $period';
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }

  String _getFrequencyDisplayName(MedicationFrequency frequency) {
    switch (frequency) {
      case MedicationFrequency.daily:
        return 'Daily';
      case MedicationFrequency.weekly:
        return 'Weekly';
      case MedicationFrequency.monthly:
        return 'Monthly';
      case MedicationFrequency.asNeeded:
        return 'As Needed';
      case MedicationFrequency.custom:
        return 'Custom Dates';
    }
  }

  String _getUnitDisplayName(DosageUnit unit) {
    switch (unit) {
      case DosageUnit.mg:
        return 'mg';
      case DosageUnit.mcg:
        return 'mcg';
      case DosageUnit.ml:
        return 'ml';
      case DosageUnit.tablet:
        return 'Tablet';
      case DosageUnit.capsule:
        return 'Capsule';
      case DosageUnit.drop:
        return 'Drop';
      case DosageUnit.spray:
        return 'Spray';
      case DosageUnit.puff:
        return 'Puff';
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.existingMedication != null ? 'Edit Medication' : 'Add New Medication',
        ),
        actions: [
          IconButton(
            onPressed: _isSaving ? null : _saveMedication,
            icon: _isSaving
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.save),
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: ListView(
            children: [
              // --------------------------------------------------------
              // Visual Studio & Form Factor Card (Shape, Color, 3D Pill)
              // --------------------------------------------------------
              Card(
                elevation: 1.5,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                child: Padding(
                  padding: const EdgeInsets.all(18.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: Theme.of(context).primaryColor.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Icon(Icons.palette_rounded, color: Theme.of(context).primaryColor, size: 20),
                          ),
                          const SizedBox(width: 10),
                          const Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Medication Visual Studio',
                                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                                ),
                                Text(
                                  'Customize realistic 3D appearance & colors',
                                  style: TextStyle(fontSize: 12, color: Colors.grey),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 18),

                      // Interactive Live Preview Box
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: isDark
                                ? [const Color(0xFF262626), const Color(0xFF1A1A1A)]
                                : [Colors.blue.shade50.withValues(alpha: 0.5), Colors.indigo.shade50.withValues(alpha: 0.5)],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: isDark ? Colors.grey.shade800 : Colors.blue.shade100,
                          ),
                        ),
                        child: Row(
                          children: [
                            // Live 3D pill graphic
                            MedicationPillGraphic(
                              shape: _selectedShape,
                              primaryColor: _parseColor(_selectedColor),
                              secondaryColor: _isDualTone && _selectedSecondaryColor != null
                                  ? _parseColor(_selectedSecondaryColor!)
                                  : null,
                              size: 58,
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    _nameController.text.trim().isEmpty
                                        ? 'Medicine Name'
                                        : _nameController.text.trim(),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 16,
                                    ),
                                  ),
                                  if (_formulaController.text.trim().isNotEmpty) ...[
                                    const SizedBox(height: 2),
                                    Text(
                                      _formulaController.text.trim(),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontStyle: FontStyle.italic,
                                        color: isDark ? Colors.cyan.shade200 : const Color(0xFF0E7490),
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ],
                                  const SizedBox(height: 3),
                                  Text(
                                    '${_selectedShape.name.toUpperCase()} • ${_dosageController.text.isNotEmpty ? _dosageController.text : "0"} ${_selectedUnit.name}${_isDualTone ? " (Dual-Tone)" : ""}',
                                    style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                                  ),
                                  if (_selectedClass != null && _selectedClass!.isNotEmpty) ...[
                                    const SizedBox(height: 4),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: Colors.purple.withValues(alpha: 0.15),
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: Text(
                                        _selectedClass!,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.w600,
                                          color: Colors.purple,
                                        ),
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),

                      // Shape Selection Carousel / Horizontal Chips
                      const Text(
                        'Pill / Medicine Shape',
                        style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.grey),
                      ),
                      const SizedBox(height: 8),
                      SizedBox(
                        height: 72,
                        child: ListView.builder(
                          scrollDirection: Axis.horizontal,
                          itemCount: _shapeOptions.length,
                          itemBuilder: (context, idx) {
                            final item = _shapeOptions[idx];
                            final shape = item['shape'] as MedicationShape;
                            final isSel = _selectedShape == shape;
                            return GestureDetector(
                              onTap: () => setState(() => _selectedShape = shape),
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 180),
                                width: 78,
                                margin: const EdgeInsets.only(right: 8),
                                padding: const EdgeInsets.all(6),
                                decoration: BoxDecoration(
                                  color: isSel
                                      ? (isDark ? Colors.blue.shade900.withValues(alpha: 0.5) : Colors.blue.shade50)
                                      : (isDark ? const Color(0xFF2A2A2A) : Colors.grey.shade100),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: isSel ? Colors.blueAccent : Colors.transparent,
                                    width: 2,
                                  ),
                                ),
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      item['icon'] as IconData,
                                      size: 24,
                                      color: isSel ? Colors.blueAccent : Colors.grey,
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      item['name'] as String,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        fontSize: 10,
                                        fontWeight: isSel ? FontWeight.bold : FontWeight.normal,
                                        color: isSel ? Colors.blueAccent : (isDark ? Colors.grey.shade300 : Colors.black87),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                      const SizedBox(height: 18),

                      // Primary Color Palette
                      const Text(
                        'Primary Color',
                        style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.grey),
                      ),
                      const SizedBox(height: 8),
                      SizedBox(
                        height: 46,
                        child: ListView.builder(
                          scrollDirection: Axis.horizontal,
                          itemCount: _colorOptions.length,
                          itemBuilder: (context, idx) {
                            final opt = _colorOptions[idx];
                            final hex = opt['color'] as String;
                            final c = _parseColor(hex);
                            final isSel = _selectedColor == hex;
                            return GestureDetector(
                              onTap: () => setState(() => _selectedColor = hex),
                              child: Container(
                                width: 40,
                                height: 40,
                                margin: const EdgeInsets.only(right: 10),
                                decoration: BoxDecoration(
                                  color: c,
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: isSel ? Colors.black : Colors.grey.shade300,
                                    width: isSel ? 3 : 1,
                                  ),
                                  boxShadow: [
                                    if (isSel)
                                      BoxShadow(
                                        color: c.withValues(alpha: 0.5),
                                        blurRadius: 8,
                                        spreadRadius: 1,
                                      ),
                                  ],
                                ),
                                child: isSel
                                    ? Icon(
                                        Icons.check,
                                        size: 20,
                                        color: _getTextColor(c),
                                      )
                                    : null,
                              ),
                            );
                          },
                        ),
                      ),
                      const SizedBox(height: 14),

                      // Dual-Tone Toggle & Secondary Color
                      SwitchListTile.adaptive(
                        contentPadding: EdgeInsets.zero,
                        title: const Text(
                          'Two-Tone / Dual Color Pill',
                          style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                        ),
                        subtitle: const Text(
                          'Enable split-tone color (ideal for capsules & coated caplets)',
                          style: TextStyle(fontSize: 12, color: Colors.grey),
                        ),
                        value: _isDualTone,
                        onChanged: (val) {
                          setState(() {
                            _isDualTone = val;
                            if (val && _selectedSecondaryColor == null) {
                              _selectedSecondaryColor = '#F1F5F9'; // default white
                            }
                          });
                        },
                      ),
                      if (_isDualTone) ...[
                        const SizedBox(height: 8),
                        const Text(
                          'Secondary Color (Second Half)',
                          style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.grey),
                        ),
                        const SizedBox(height: 8),
                        SizedBox(
                          height: 46,
                          child: ListView.builder(
                            scrollDirection: Axis.horizontal,
                            itemCount: _colorOptions.length,
                            itemBuilder: (context, idx) {
                              final opt = _colorOptions[idx];
                              final hex = opt['color'] as String;
                              final c = _parseColor(hex);
                              final isSel = _selectedSecondaryColor == hex;
                              return GestureDetector(
                                onTap: () => setState(() => _selectedSecondaryColor = hex),
                                child: Container(
                                  width: 40,
                                  height: 40,
                                  margin: const EdgeInsets.only(right: 10),
                                  decoration: BoxDecoration(
                                    color: c,
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                      color: isSel ? Colors.black : Colors.grey.shade300,
                                      width: isSel ? 3 : 1,
                                    ),
                                    boxShadow: [
                                      if (isSel)
                                        BoxShadow(
                                          color: c.withValues(alpha: 0.5),
                                          blurRadius: 8,
                                          spreadRadius: 1,
                                        ),
                                    ],
                                  ),
                                  child: isSel
                                      ? Icon(
                                          Icons.check,
                                          size: 20,
                                          color: _getTextColor(c),
                                        )
                                      : null,
                                ),
                              );
                            },
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Medication Details Card
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Medication Details',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _nameController,
                        onChanged: (_) => setState(() {}),
                        decoration: const InputDecoration(
                          labelText: 'Medication Name*',
                          hintText: 'e.g., Lipitor, Amoxicillin',
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.medication),
                        ),
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'Please enter medication name';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),

                      // Formula / Active Ingredient Field
                      TextFormField(
                        controller: _formulaController,
                        onChanged: _onFormulaChanged,
                        decoration: const InputDecoration(
                          labelText: 'Formula / Active Ingredient (Optional)',
                          hintText: 'e.g., Atorvastatin Calcium 20mg, Amoxicillin Trihydrate',
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.biotech_outlined),
                        ),
                      ),

                      // ML Auto-Classification Feedback Badge
                      if (_lastMlPrediction != null && _lastMlPrediction!.hasPrediction) ...[
                        const SizedBox(height: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          decoration: BoxDecoration(
                            color: isDark ? const Color(0xFF1E293B) : const Color(0xFFEFF6FF),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: const Color(0xFF3B82F6).withValues(alpha: 0.35),
                            ),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.auto_awesome, color: Color(0xFF2563EB), size: 18),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        const Text(
                                          'ML Classification: ',
                                          style: TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 12,
                                            color: Color(0xFF1D4ED8),
                                          ),
                                        ),
                                        Flexible(
                                          child: Text(
                                            _lastMlPrediction!.predictedClass!.name,
                                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                      ],
                                    ),
                                    Text(
                                      '${(_lastMlPrediction!.confidence * 100).toInt()}% confidence • ${_lastMlPrediction!.matchedFeature}',
                                      style: TextStyle(fontSize: 11, color: isDark ? Colors.grey.shade400 : Colors.grey.shade600),
                                    ),
                                  ],
                                ),
                              ),
                              if (_userManuallyOverrodeClass && _selectedClass != _lastMlPrediction!.predictedClass!.name)
                                TextButton(
                                  style: TextButton.styleFrom(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                    minimumSize: Size.zero,
                                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                  ),
                                  onPressed: () {
                                    setState(() {
                                      _userManuallyOverrodeClass = false;
                                      _selectedClass = _lastMlPrediction!.predictedClass!.name;
                                    });
                                  },
                                  child: const Text('Apply ML', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                                ),
                            ],
                          ),
                        ),
                      ],
                      const SizedBox(height: 16),

                      // Searchable Medication Class Selector
                      Builder(
                        builder: (ctx) {
                          final classInfo = MedicationClassCatalog.findByName(_selectedClass);
                          final hasSelection = _selectedClass != null && _selectedClass!.isNotEmpty;
                          final theme = Theme.of(ctx);
                          final isDark = theme.brightness == Brightness.dark;

                          return InkWell(
                            onTap: () async {
                              final picked = await SearchableMedicationClassSheet.show(
                                context,
                                currentSelection: _selectedClass,
                              );
                              if (picked != null) {
                                setState(() {
                                  _selectedClass = picked.isEmpty ? null : picked;
                                  _userManuallyOverrodeClass = true; // User explicitly selected or changed class!
                                });
                              }
                            },
                            borderRadius: BorderRadius.circular(12),
                            child: InputDecorator(
                              decoration: InputDecoration(
                                labelText: 'Medication Class / Category',
                                border: const OutlineInputBorder(),
                                prefixIcon: const Icon(Icons.category_outlined),
                                suffixIcon: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    if (hasSelection)
                                      IconButton(
                                        icon: const Icon(Icons.clear, size: 18),
                                        tooltip: 'Clear class',
                                        onPressed: () {
                                          setState(() {
                                            _selectedClass = null;
                                            _userManuallyOverrodeClass = true; // User manually cleared class
                                          });
                                        },
                                      ),
                                    const Icon(Icons.search_rounded, size: 20),
                                    const SizedBox(width: 8),
                                  ],
                                ),
                              ),
                              child: hasSelection
                                  ? Row(
                                      children: [
                                        if (classInfo != null) ...[
                                          Text(classInfo.icon, style: const TextStyle(fontSize: 16)),
                                          const SizedBox(width: 8),
                                        ],
                                        Expanded(
                                          child: Text(
                                            _selectedClass!,
                                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                        if (classInfo != null)
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                            decoration: BoxDecoration(
                                              color: MedicationClassCatalog.parseColor(classInfo.colorHex).withValues(alpha: 0.15),
                                              borderRadius: BorderRadius.circular(6),
                                            ),
                                            child: Text(
                                              classInfo.category,
                                              style: TextStyle(
                                                fontSize: 10,
                                                fontWeight: FontWeight.w600,
                                                color: MedicationClassCatalog.parseColor(classInfo.colorHex),
                                              ),
                                            ),
                                          ),
                                      ],
                                    )
                                  : Text(
                                      'Tap to search & select class (50+ available)...',
                                      style: TextStyle(
                                        fontSize: 13,
                                        color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                                      ),
                                    ),
                            ),
                          );
                        },
                      ),
                      const SizedBox(height: 16),
                      // ✅ FIXED ROW: dosage + unit dropdown
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            flex: 3, // ✅ CHANGED: was 2
                            child: TextFormField(
                              controller: _dosageController,
                              decoration: const InputDecoration(
                                labelText: 'Dosage*',
                                border: OutlineInputBorder(),
                              ),
                              keyboardType: TextInputType.number,
                              validator: (value) {
                                if (value == null || value.isEmpty) {
                                  return 'Please enter dosage';
                                }
                                final dosage = double.tryParse(value);
                                if (dosage == null || dosage <= 0) {
                                  return 'Please enter a valid dosage';
                                }
                                return null;
                              },
                              onSaved: (value) {
                                _dosage = double.parse(value!);
                              },
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            flex: 2, // ✅ CHANGED: was 1
                            child: DropdownButtonFormField<DosageUnit>(
                              initialValue: _selectedUnit,
                              isExpanded: true, // ✅ ADDED: prevents overflow
                              decoration: const InputDecoration(
                                labelText: 'Unit',
                                border: OutlineInputBorder(),
                                isDense: true, // ✅ ADDED: compact layout
                              ),
                              items: DosageUnit.values.map((unit) {
                                return DropdownMenuItem<DosageUnit>(
                                  value: unit,
                                  child: Text(
                                    _getUnitDisplayName(unit),
                                    overflow: TextOverflow.ellipsis, // ✅ ADDED
                                  ),
                                );
                              }).toList(),
                              onChanged: (value) {
                                if (value != null) {
                                  setState(() {
                                    _selectedUnit = value;
                                  });
                                }
                              },
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _descriptionController,
                        decoration: const InputDecoration(
                          labelText: 'Description (Optional)',
                          border: OutlineInputBorder(),
                          alignLabelWithHint: true,
                        ),
                        maxLines: 2,
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _instructionsController,
                        decoration: const InputDecoration(
                          labelText: 'Instructions (e.g. Take with meals)',
                          border: OutlineInputBorder(),
                          alignLabelWithHint: true,
                        ),
                        maxLines: 2,
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Scheduling Section Card
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Scheduling',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 16),
                      _buildFrequencySection(),
                      _buildDaysSection(),
                      _buildTimesSection(),
                      _buildCustomDatesSection(),
                      _buildDateRangeSection(),
                      _buildReminderSection(),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),

              ElevatedButton(
                onPressed: _isSaving ? null : _saveMedication,
                style: ElevatedButton.styleFrom(
                  minimumSize: const Size(double.infinity, 50),
                ),
                child: _isSaving
                    ? const CircularProgressIndicator()
                    : Text(
                        widget.existingMedication != null
                            ? 'Update Medication'
                            : 'Save Medication',
                        style: const TextStyle(fontSize: 16),
                      ),
              ),
            ],
          ),
        ),
      ),
      bottomNavigationBar: const AdBannerWidget(),
    );
  }
}