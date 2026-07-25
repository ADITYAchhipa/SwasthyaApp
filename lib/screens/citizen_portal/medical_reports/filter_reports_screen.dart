import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../theme/app_theme.dart';

class FilterReportsScreen extends StatefulWidget {
  final Map<String, dynamic> initialFilters;
  const FilterReportsScreen({Key? key, required this.initialFilters}) : super(key: key);

  @override
  State<FilterReportsScreen> createState() => _FilterReportsScreenState();
}

class _FilterReportsScreenState extends State<FilterReportsScreen> {
  String _selectedCategory = 'All';
  String _selectedDateRangeType = 'All Time';
  DateTime? _fromDate;
  DateTime? _toDate;
  String _selectedHospital = 'All';
  String _doctorName = '';
  String _departmentName = '';
  String _sortBy = 'Newest';
  bool _showAbnormalOnly = false;

  final List<String> _categories = ['All', 'Blood Tests', 'Radiology', 'MRI', 'CT Scan', 'Prescription', 'Discharge Summary', 'ECG', 'Others'];
  final List<String> _hospitals = ['All', 'CityCare Hospital', 'Apollo Hospitals', 'Manipal Hospital', 'Dr. Lal PathLabs', 'Fortis Hospital'];
  final List<String> _sortOptions = ['Newest', 'Oldest', 'Hospital', 'Report Name'];

  final _doctorController = TextEditingController();
  final _departmentController = TextEditingController();

  @override
  void initState() {
    super.initState();
    // Load initial filters if any
    final f = widget.initialFilters;
    if (f.isNotEmpty) {
      _selectedCategory = f['category'] ?? 'All';
      _selectedDateRangeType = f['dateRangeType'] ?? 'All Time';
      _fromDate = f['fromDate'];
      _toDate = f['toDate'];
      _selectedHospital = f['hospital'] ?? 'All';
      _doctorName = f['doctor'] ?? '';
      _departmentName = f['department'] ?? '';
      _sortBy = f['sortBy'] ?? 'Newest';
      _showAbnormalOnly = f['showAbnormalOnly'] ?? false;

      _doctorController.text = _doctorName;
      _departmentController.text = _departmentName;
    }
  }

  @override
  void dispose() {
    _doctorController.dispose();
    _departmentController.dispose();
    super.dispose();
  }

  void _resetFilters() {
    setState(() {
      _selectedCategory = 'All';
      _selectedDateRangeType = 'All Time';
      _fromDate = null;
      _toDate = null;
      _selectedHospital = 'All';
      _doctorName = '';
      _departmentName = '';
      _sortBy = 'Newest';
      _showAbnormalOnly = false;
      _doctorController.clear();
      _departmentController.clear();
    });
  }

  void _applyFilters() {
    final filters = {
      'category': _selectedCategory,
      'dateRangeType': _selectedDateRangeType,
      'fromDate': _fromDate,
      'toDate': _toDate,
      'hospital': _selectedHospital,
      'doctor': _doctorController.text.trim().isNotEmpty ? _doctorController.text.trim() : 'All',
      'department': _departmentController.text.trim().isNotEmpty ? _departmentController.text.trim() : 'All',
      'sortBy': _sortBy,
      'showAbnormalOnly': _showAbnormalOnly,
    };
    Navigator.pop(context, filters);
  }

  Future<void> _selectFromDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _fromDate ?? DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime.now(),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: AppTheme.accentTeal,
              onPrimary: Colors.white,
              onSurface: AppTheme.textPrimary,
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null && picked != _fromDate) {
      setState(() {
        _fromDate = picked;
        _selectedDateRangeType = 'Custom Range';
      });
    }
  }

  Future<void> _selectToDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _toDate ?? DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime.now(),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: AppTheme.accentTeal,
              onPrimary: Colors.white,
              onSurface: AppTheme.textPrimary,
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null && picked != _toDate) {
      setState(() {
        _toDate = picked;
        _selectedDateRangeType = 'Custom Range';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Text(
          'Filter Reports',
          style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 18, color: AppTheme.textPrimary),
        ),
        leading: IconButton(
          icon: const Icon(Icons.close, color: AppTheme.textPrimary),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          TextButton(
            onPressed: _resetFilters,
            child: Text(
              'Reset',
              style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 14, color: AppTheme.accentRed),
            ),
          ),
          const SizedBox(width: 8),
        ],
        elevation: 0,
        backgroundColor: Colors.white,
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 1. Report Type
                    Text('Report Type', style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 14, color: AppTheme.textPrimary)),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: _categories.map((cat) {
                        final isSelected = _selectedCategory == cat;
                        return ChoiceChip(
                          label: Text(
                            cat,
                            style: GoogleFonts.poppins(
                              fontSize: 12,
                              fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                              color: isSelected ? Colors.white : AppTheme.textPrimary,
                            ),
                          ),
                          selected: isSelected,
                          onSelected: (selected) {
                            setState(() {
                              _selectedCategory = cat;
                            });
                          },
                          selectedColor: AppTheme.accentTeal,
                          backgroundColor: AppTheme.lightBg,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                            side: BorderSide(color: isSelected ? AppTheme.accentTeal : AppTheme.borderColor),
                          ),
                        );
                      }).toList(),
                    ),
                    const Divider(height: 32, color: AppTheme.borderColor),

                    // 2. Date Range
                    Text('Date Range', style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 14, color: AppTheme.textPrimary)),
                    const SizedBox(height: 8),
                    _buildRadioDateRange('All Time'),
                    _buildRadioDateRange('Last 7 Days'),
                    _buildRadioDateRange('Last 30 Days'),
                    _buildRadioDateRange('Last 3 Months'),
                    _buildRadioDateRange('Last 6 Months'),
                    _buildRadioDateRange('Custom Range'),
                    
                    if (_selectedDateRangeType == 'Custom Range') ...[
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: GestureDetector(
                              onTap: () => _selectFromDate(context),
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                                decoration: BoxDecoration(
                                  border: Border.all(color: AppTheme.borderColor),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      _fromDate != null ? '${_fromDate!.day}/${_fromDate!.month}/${_fromDate!.year}' : 'From Date',
                                      style: GoogleFonts.poppins(fontSize: 12, color: AppTheme.textPrimary),
                                    ),
                                    const Icon(Icons.calendar_today_rounded, size: 14, color: AppTheme.textSecondary),
                                  ],
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: GestureDetector(
                              onTap: () => _selectToDate(context),
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                                decoration: BoxDecoration(
                                  border: Border.all(color: AppTheme.borderColor),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      _toDate != null ? '${_toDate!.day}/${_toDate!.month}/${_toDate!.year}' : 'To Date',
                                      style: GoogleFonts.poppins(fontSize: 12, color: AppTheme.textPrimary),
                                    ),
                                    const Icon(Icons.calendar_today_rounded, size: 14, color: AppTheme.textSecondary),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                    const Divider(height: 32, color: AppTheme.borderColor),

                    // 3. Hospital / Lab
                    Text('Hospital / Lab', style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 14, color: AppTheme.textPrimary)),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14),
                      decoration: BoxDecoration(
                        color: AppTheme.lightBg,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppTheme.borderColor),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          value: _selectedHospital,
                          isExpanded: true,
                          style: GoogleFonts.poppins(color: AppTheme.textPrimary, fontSize: 13, fontWeight: FontWeight.w500),
                          icon: const Icon(Icons.keyboard_arrow_down_rounded, color: AppTheme.textSecondary),
                          onChanged: (newValue) {
                            setState(() {
                              _selectedHospital = newValue!;
                            });
                          },
                          items: _hospitals.map((hosp) {
                            return DropdownMenuItem<String>(
                              value: hosp,
                              child: Text(hosp),
                            );
                          }).toList(),
                        ),
                      ),
                    ),
                    const Divider(height: 32, color: AppTheme.borderColor),

                    // 4. Doctor Name
                    Text('Doctor Name', style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 14, color: AppTheme.textPrimary)),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _doctorController,
                      style: GoogleFonts.poppins(fontSize: 13, color: AppTheme.textPrimary),
                      decoration: InputDecoration(
                        hintText: 'Enter doctor name',
                        hintStyle: GoogleFonts.poppins(fontSize: 13, color: AppTheme.textSecondary.withOpacity(0.7)),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                        fillColor: AppTheme.lightBg,
                        filled: true,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: AppTheme.borderColor),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: AppTheme.borderColor),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: AppTheme.accentTeal),
                        ),
                      ),
                    ),
                    const Divider(height: 32, color: AppTheme.borderColor),

                    // 5. Department
                    Text('Department', style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 14, color: AppTheme.textPrimary)),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _departmentController,
                      style: GoogleFonts.poppins(fontSize: 13, color: AppTheme.textPrimary),
                      decoration: InputDecoration(
                        hintText: 'Enter department name',
                        hintStyle: GoogleFonts.poppins(fontSize: 13, color: AppTheme.textSecondary.withOpacity(0.7)),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                        fillColor: AppTheme.lightBg,
                        filled: true,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: AppTheme.borderColor),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: AppTheme.borderColor),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: AppTheme.accentTeal),
                        ),
                      ),
                    ),
                    const Divider(height: 32, color: AppTheme.borderColor),

                    // 6. Sort By
                    Text('Sort By', style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 14, color: AppTheme.textPrimary)),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: _sortOptions.map((opt) {
                        final isSelected = _sortBy == opt;
                        return ChoiceChip(
                          label: Text(
                            opt,
                            style: GoogleFonts.poppins(
                              fontSize: 12,
                              fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                              color: isSelected ? Colors.white : AppTheme.textPrimary,
                            ),
                          ),
                          selected: isSelected,
                          onSelected: (selected) {
                            setState(() {
                              _sortBy = opt;
                            });
                          },
                          selectedColor: AppTheme.accentTeal,
                          backgroundColor: AppTheme.lightBg,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                            side: BorderSide(color: isSelected ? AppTheme.accentTeal : AppTheme.borderColor),
                          ),
                        );
                      }).toList(),
                    ),
                    const Divider(height: 32, color: AppTheme.borderColor),

                    // 7. Abnormal reports switch
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Show only abnormal reports',
                              style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 14, color: AppTheme.textPrimary),
                            ),
                            Text(
                              'Display tests indicating values out of range',
                              style: GoogleFonts.poppins(fontSize: 11, color: AppTheme.textSecondary),
                            ),
                          ],
                        ),
                        Switch.adaptive(
                          value: _showAbnormalOnly,
                          activeColor: AppTheme.accentTeal,
                          onChanged: (value) {
                            setState(() {
                              _showAbnormalOnly = value;
                            });
                          },
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                  ],
                ),
              ),
            ),

            // Apply Button
            Padding(
              padding: const EdgeInsets.all(16),
              child: SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  onPressed: _applyFilters,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.accentTeal,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    elevation: 0,
                  ),
                  child: Text(
                    'Apply Filters',
                    style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 15, color: Colors.white),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRadioDateRange(String type) {
    final isSelected = _selectedDateRangeType == type;
    return InkWell(
      onTap: () {
        setState(() {
          _selectedDateRangeType = type;
        });
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(
          children: [
            Icon(
              isSelected ? Icons.radio_button_checked_rounded : Icons.radio_button_off_rounded,
              color: isSelected ? AppTheme.accentTeal : AppTheme.textSecondary,
              size: 20,
            ),
            const SizedBox(width: 10),
            Text(
              type,
              style: GoogleFonts.poppins(
                fontSize: 13,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                color: isSelected ? AppTheme.accentTeal : AppTheme.textPrimary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
