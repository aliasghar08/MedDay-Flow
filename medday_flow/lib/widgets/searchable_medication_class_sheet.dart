import 'package:flutter/material.dart';
import 'package:medday_flow/utils/medication_model/medication_classes.dart';

/// Interactive modal sheet to search, filter, and pick a standardized medication class.
class SearchableMedicationClassSheet extends StatefulWidget {
  final String? selectedClass;

  const SearchableMedicationClassSheet({
    super.key,
    this.selectedClass,
  });

  static Future<String?> show(BuildContext context, {String? currentSelection}) {
    return showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => SearchableMedicationClassSheet(selectedClass: currentSelection),
    );
  }

  @override
  State<SearchableMedicationClassSheet> createState() => _SearchableMedicationClassSheetState();
}

class _SearchableMedicationClassSheetState extends State<SearchableMedicationClassSheet> {
  final TextEditingController _searchController = TextEditingController();
  final TextEditingController _customClassController = TextEditingController();
  String _selectedCategory = 'All';
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _searchController.addListener(() {
      setState(() {
        _searchQuery = _searchController.text.trim();
      });
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    _customClassController.dispose();
    super.dispose();
  }

  List<MedicationClassInfo> get _filteredClasses {
    return MedicationClassCatalog.classes.where((c) {
      final matchesCategory = _selectedCategory == 'All' || c.category == _selectedCategory;
      final matchesQuery = _searchQuery.isEmpty || c.matches(_searchQuery);
      return matchesCategory && matchesQuery;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final categories = ['All', ...MedicationClassCatalog.categories];
    final filtered = _filteredClasses;

    return Container(
      height: MediaQuery.of(context).size.height * 0.85,
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        boxShadow: const [
          BoxShadow(
            color: Colors.black26,
            blurRadius: 16,
            offset: Offset(0, -4),
          ),
        ],
      ),
      child: Column(
        children: [
          // Drag handle & title
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
            child: Column(
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: isDark ? Colors.grey.shade700 : Colors.grey.shade300,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Select Medication Class',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close_rounded, size: 20),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Search text field
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            child: TextField(
              controller: _searchController,
              autofocus: false,
              decoration: InputDecoration(
                hintText: 'Search by class, condition, or drug (e.g. Statin, Metformin)...',
                hintStyle: TextStyle(fontSize: 13, color: Colors.grey.shade500),
                prefixIcon: const Icon(Icons.search_rounded, size: 20),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear_rounded, size: 18),
                        onPressed: () => _searchController.clear(),
                      )
                    : null,
                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide(
                    color: isDark ? Colors.grey.shade800 : Colors.grey.shade300,
                  ),
                ),
                filled: true,
                fillColor: isDark ? const Color(0xFF282828) : const Color(0xFFF1F5F9),
              ),
            ),
          ),

          // Horizontal category chips
          SizedBox(
            height: 42,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: categories.length,
              separatorBuilder: (ctx, i) => const SizedBox(width: 8),
              itemBuilder: (context, index) {
                final cat = categories[index];
                final isSelected = _selectedCategory == cat;
                return ChoiceChip(
                  label: Text(cat),
                  selected: isSelected,
                  onSelected: (selected) {
                    if (selected) {
                      setState(() {
                        _selectedCategory = cat;
                      });
                    }
                  },
                  labelStyle: TextStyle(
                    fontSize: 12,
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                    color: isSelected
                        ? Colors.white
                        : (isDark ? Colors.grey.shade300 : Colors.grey.shade700),
                  ),
                  selectedColor: Colors.blueAccent,
                  backgroundColor: isDark ? const Color(0xFF2C2C2C) : const Color(0xFFE2E8F0),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                    side: BorderSide(
                      color: isSelected
                          ? Colors.blueAccent
                          : (isDark ? Colors.grey.shade800 : Colors.transparent),
                    ),
                  ),
                );
              },
            ),
          ),

          const SizedBox(height: 8),
          const Divider(height: 1),

          // Class Results List
          Expanded(
            child: filtered.isEmpty
                ? _buildEmptyState(context, isDark)
                : ListView.separated(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    itemCount: filtered.length,
                    separatorBuilder: (ctx, i) => const SizedBox(height: 8),
                    itemBuilder: (context, index) {
                      final item = filtered[index];
                      final isSelected = widget.selectedClass == item.name ||
                          widget.selectedClass == item.id;
                      final classColor = MedicationClassCatalog.parseColor(item.colorHex);

                      return InkWell(
                        onTap: () {
                          Navigator.pop(context, item.name);
                        },
                        borderRadius: BorderRadius.circular(14),
                        child: Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: isSelected
                                ? (isDark ? Colors.blueAccent.withValues(alpha: 0.15) : Colors.blue.shade50)
                                : (isDark ? const Color(0xFF252525) : Colors.grey.shade50),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                              color: isSelected
                                  ? Colors.blueAccent
                                  : (isDark ? Colors.grey.shade800 : Colors.grey.shade200),
                              width: isSelected ? 1.5 : 1.0,
                            ),
                          ),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Container(
                                width: 40,
                                height: 40,
                                decoration: BoxDecoration(
                                  color: classColor.withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Center(
                                  child: Text(
                                    item.icon,
                                    style: const TextStyle(fontSize: 20),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Expanded(
                                          child: Text(
                                            item.name,
                                            style: TextStyle(
                                              fontWeight: FontWeight.bold,
                                              fontSize: 14,
                                              color: isSelected
                                                  ? Colors.blueAccent
                                                  : (isDark ? Colors.white : Colors.black87),
                                            ),
                                          ),
                                        ),
                                        if (isSelected)
                                          const Icon(
                                            Icons.check_circle_rounded,
                                            color: Colors.blueAccent,
                                            size: 18,
                                          ),
                                      ],
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      item.category,
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w600,
                                        color: classColor,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      'e.g. ${item.examples}',
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
          ),

          // Custom Class Input Button at Bottom
          Container(
            padding: EdgeInsets.fromLTRB(16, 10, 16, MediaQuery.of(context).viewInsets.bottom + 12),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
              border: Border(
                top: BorderSide(
                  color: isDark ? Colors.grey.shade800 : Colors.grey.shade200,
                ),
              ),
            ),
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    icon: const Icon(Icons.edit_note_rounded, size: 18),
                    label: const Text('Enter Custom Class Name'),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    onPressed: () => _showCustomClassDialog(context),
                  ),
                ),
                if (widget.selectedClass != null && widget.selectedClass!.isNotEmpty) ...[
                  const SizedBox(width: 8),
                  TextButton(
                    onPressed: () => Navigator.pop(context, ''),
                    child: const Text('Clear', style: TextStyle(color: Colors.redAccent)),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context, bool isDark) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.search_off_rounded, size: 54, color: Colors.grey.shade400),
            const SizedBox(height: 12),
            Text(
              'No classes match "$_searchQuery"',
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              'You can use the custom class option below to enter any medication category manually.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, color: Colors.grey.shade500),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context, _searchQuery);
              },
              child: Text('Use "$_searchQuery" as Class'),
            ),
          ],
        ),
      ),
    );
  }

  void _showCustomClassDialog(BuildContext context) {
    _customClassController.text = _searchQuery;
    showDialog(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        title: const Text('Custom Medication Class'),
        content: TextField(
          controller: _customClassController,
          autofocus: true,
          decoration: const InputDecoration(
            hintText: 'e.g. Immunotherapy, Nootropic...',
            labelText: 'Class / Category Name',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogCtx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              final text = _customClassController.text.trim();
              Navigator.pop(dialogCtx);
              if (text.isNotEmpty) {
                Navigator.pop(context, text);
              }
            },
            child: const Text('Select'),
          ),
        ],
      ),
    );
  }
}
