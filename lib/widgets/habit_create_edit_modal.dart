import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

class HabitCreateEditModal extends StatefulWidget {
  final Map<String, dynamic> formData;
  final bool isEditing;
  final Function(Map<String, dynamic>) onSave;
  final VoidCallback onCancel;
  final List<Map<String, dynamic>> colorOptions;

  const HabitCreateEditModal({
    super.key,
    required this.formData,
    required this.isEditing,
    required this.onSave,
    required this.onCancel,
    required this.colorOptions,
  });

  @override
  State<HabitCreateEditModal> createState() => _HabitCreateEditModalState();
}

class _HabitCreateEditModalState extends State<HabitCreateEditModal>
    with SingleTickerProviderStateMixin {
  late Map<String, dynamic> _formData;
  late AnimationController _animationController;
  late Animation<double> _slideAnimation;

  final _nameController = TextEditingController();
  final _categoryController = TextEditingController();
  final _everyNController = TextEditingController();

  // mentor choices
  final List<Map<String, String>> _mentorChoices = const [
    {'id': 'standard', 'label': 'Standard (no voice)'},
    {'id': 'drill-sergeant', 'label': 'Drill Sergeant (default)'},
    {'id': 'marcus', 'label': 'Marcus Aurelius'},
    {'id': 'confucius', 'label': 'Confucius'},
    {'id': 'buddha', 'label': 'Buddha'},
    {'id': 'lincoln', 'label': 'Abraham Lincoln'},
  ];

  @override
  void initState() {
    super.initState();
    _formData = Map.from(widget.formData);

    _nameController.text = _formData['name'] ?? '';
    _categoryController.text = _formData['category'] ?? '';
    _everyNController.text = (_formData['everyN'] ?? 2).toString();

    // default mentor logic:
    // if form doesn’t carry mentorVoice, load global default (or Drill Sergeant fallback)
    if ((_formData['mentorVoice'] == null || (_formData['mentorVoice'] as String).isEmpty)) {
      _initDefaultMentor();
    }

    _animationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );

    _slideAnimation = Tween<double>(begin: 1.0, end: 0.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeOutCubic),
    );

    _animationController.forward();
  }

  Future<void> _initDefaultMentor() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString('defaultMentorVoice') ?? 'drill-sergeant';
    setState(() {
      _formData['mentorVoice'] = saved; // default DS
    });
  }

  @override
  void dispose() {
    _animationController.dispose();
    _nameController.dispose();
    _categoryController.dispose();
    _everyNController.dispose();
    super.dispose();
  }

  void _updateFormData(String key, dynamic value) {
    setState(() {
      _formData[key] = value;
    });
  }

  void _save() {
    if (_nameController.text.trim().isEmpty) {
      HapticFeedback.heavyImpact();
      return;
    }

    _formData['name'] = _nameController.text.trim();
    _formData['category'] = _categoryController.text.trim();
    if (_formData['frequency'] == 'everyN') {
      _formData['everyN'] = int.tryParse(_everyNController.text) ?? 2;
    }
    // ensure mentorVoice present
    _formData['mentorVoice'] = (_formData['mentorVoice'] as String?)?.trim().isNotEmpty == true
        ? _formData['mentorVoice']
        : 'drill-sergeant';

    HapticFeedback.selectionClick();
    widget.onSave(_formData);
  }

  void _cancel() {
    _animationController.reverse().then((_) => widget.onCancel());
  }

  String get _modalTitle {
    final action = widget.isEditing ? 'Edit' : 'New';
    final type = _formData['type'] == 'habit'
        ? 'Habit'
        : _formData['type'] == 'task'
            ? 'Task'
            : 'Bad Habit';
    return '$action $type';
  }

  Widget _buildColorPicker() {
    // Some callers passed only 'color'; support both 'color' and 'bgColor'
    Color _chipColorOf(Map<String, dynamic> opt) {
      final c = opt['bgColor'] ?? opt['color'];
      return (c is Color) ? c : const Color(0xFF10B981);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Color',
            style: TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.w500)),
        const SizedBox(height: 8),
        Row(
          children: widget.colorOptions.map((opt) {
            final isSelected = _formData['color'] == opt['name'];
            return GestureDetector(
              onTap: () {
                _updateFormData('color', opt['name']);
                HapticFeedback.selectionClick();
              },
              child: Container(
                width: 32,
                height: 32,
                margin: const EdgeInsets.only(right: 8),
                decoration: BoxDecoration(
                  color: _chipColorOf(opt),
                  borderRadius: BorderRadius.circular(8),
                  border: isSelected ? Border.all(color: Colors.white, width: 2) : null,
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildTextField({
    required String label,
    required TextEditingController controller,
    String? hint,
    TextInputType? keyboardType,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: const TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.w500)),
        const SizedBox(height: 8),
        TextField(
          controller: controller,
          keyboardType: keyboardType,
          style: const TextStyle(color: Colors.white),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: const TextStyle(color: Colors.white30),
            filled: true,
            fillColor: const Color(0xFF0B0F0E),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(color: Colors.white.withOpacity(0.1)),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(color: Colors.white.withOpacity(0.1)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: Color(0xFF10B981)),
            ),
            contentPadding: const EdgeInsets.all(12),
          ),
        ),
      ],
    );
  }

  Widget _buildDateField({
    required String label,
    required String value,
    required Function(String) onChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: const TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.w500)),
        const SizedBox(height: 8),
        GestureDetector(
          onTap: () async {
            final picked = await showDatePicker(
              context: context,
              initialDate: DateTime.tryParse(value) ?? DateTime.now(),
              firstDate: DateTime.now().subtract(const Duration(days: 365)),
              lastDate: DateTime.now().add(const Duration(days: 365)),
              builder: (context, child) {
                return Theme(
                  data: ThemeData.dark().copyWith(
                    colorScheme: const ColorScheme.dark(primary: Color(0xFF10B981)),
                  ),
                  child: child!,
                );
              },
            );
            if (picked != null) {
              onChanged(picked.toIso8601String().split('T')[0]);
            }
          },
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFF0B0F0E),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.white.withOpacity(0.1)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    value.isEmpty ? 'Select date' : value,
                    style: TextStyle(color: value.isEmpty ? Colors.white30 : Colors.white),
                  ),
                ),
                const Icon(Icons.calendar_today, color: Colors.white70, size: 20),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildDropdown({
    required String label,
    required String value,
    required List<String> options,
    required Function(String) onChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: const TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.w500)),
        const SizedBox(height: 8),
        DropdownButtonFormField<String>(
          value: value,
          onChanged: (newValue) {
            if (newValue != null) {
              onChanged(newValue);
              HapticFeedback.selectionClick();
            }
          },
          style: const TextStyle(color: Colors.white),
          dropdownColor: const Color(0xFF121816),
          decoration: InputDecoration(
            filled: true,
            fillColor: const Color(0xFF0B0F0E),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(color: Colors.white.withOpacity(0.1)),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(color: Colors.white.withOpacity(0.1)),
            ),
            contentPadding: const EdgeInsets.all(12),
          ),
          items: options.map((option) {
            return DropdownMenuItem<String>(value: option, child: Text(option));
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildIntensitySelector() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Intensity',
            style: TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.w500)),
        const SizedBox(height: 8),
        Row(
          children: [1, 2, 3].map((i) {
            final isSelected = _formData['intensity'] == i;
            return GestureDetector(
              onTap: () {
                _updateFormData('intensity', i);
                HapticFeedback.selectionClick();
              },
              child: Container(
                width: 48,
                height: 40,
                margin: const EdgeInsets.only(right: 8),
                decoration: BoxDecoration(
                  color: isSelected ? Colors.white : const Color(0xFF0B0F0E),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isSelected ? Colors.white : Colors.white.withOpacity(0.1),
                  ),
                ),
                child: Center(
                  child: Text(
                    'I$i',
                    style: TextStyle(
                      color: isSelected ? Colors.black : Colors.white70,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildMentorSelector() {
    final current = (_formData['mentorVoice'] as String?) ?? 'drill-sergeant';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Alarm Voice',
            style: TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.w500)),
        const SizedBox(height: 8),
        DropdownButtonFormField<String>(
          value: current,
          onChanged: (val) {
            if (val == null) return;
            _updateFormData('mentorVoice', val);
            HapticFeedback.selectionClick();
          },
          style: const TextStyle(color: Colors.white),
          dropdownColor: const Color(0xFF121816),
          decoration: InputDecoration(
            filled: true,
            fillColor: const Color(0xFF0B0F0E),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(color: Colors.white.withOpacity(0.1)),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(color: Colors.white.withOpacity(0.1)),
            ),
            contentPadding: const EdgeInsets.all(12),
          ),
          items: _mentorChoices
              .map(
                (m) => DropdownMenuItem<String>(
                  value: m['id'],
                  child: Text(m['label']!),
                ),
              )
              .toList(),
        ),
        const SizedBox(height: 8),
        TextButton.icon(
          onPressed: () async {
            final prefs = await SharedPreferences.getInstance();
            await prefs.setString('defaultMentorVoice', _formData['mentorVoice'] ?? 'drill-sergeant');
            if (!mounted) return;
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Default alarm voice saved')),
            );
          },
          icon: const Icon(Icons.push_pin_outlined, size: 16, color: Colors.white70),
          label: const Text('Set as default', style: TextStyle(color: Colors.white70)),
        ),
      ],
    );
  }

  Widget _buildReminderSection() {
    final enabled = _formData['reminderOn'] == true;
    final time = _formData['reminderTime'] ?? '08:00';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Text('Reminder',
                style: TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.w500)),
            const SizedBox(width: 12),
            Switch(
              value: enabled,
              onChanged: (v) {
                _updateFormData('reminderOn', v);
                HapticFeedback.selectionClick();
              },
              activeColor: const Color(0xFF10B981),
            ),
            const Text('Enable', style: TextStyle(color: Colors.white70, fontSize: 12)),
          ],
        ),
        if (enabled) ...[
          const SizedBox(height: 12),
          GestureDetector(
            onTap: () async {
              final picked = await showTimePicker(
                context: context,
                initialTime: TimeOfDay.fromDateTime(
                  DateTime.tryParse('2023-01-01 $time:00') ?? DateTime.now(),
                ),
                builder: (context, child) => Theme(
                  data: ThemeData.dark().copyWith(
                    colorScheme: const ColorScheme.dark(primary: Color(0xFF10B981)),
                  ),
                  child: child!,
                ),
              );
              if (picked != null) {
                final hh = picked.hour.toString().padLeft(2, '0');
                final mm = picked.minute.toString().padLeft(2, '0');
                _updateFormData('reminderTime', '$hh:$mm');
              }
            },
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFF0B0F0E),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.white.withOpacity(0.1)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.access_time, color: Colors.white70, size: 20),
                  const SizedBox(width: 8),
                  Text(time, style: const TextStyle(color: Colors.white)),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          _buildMentorSelector(), // <— NEW: choose mentor voice for this habit
        ],
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _slideAnimation,
      builder: (context, child) {
        return Container(
          color: Colors.black.withOpacity(0.6),
          child: Stack(
            children: [
              // Backdrop
              GestureDetector(onTap: _cancel, child: Container(color: Colors.transparent)),
              // Modal content
              Positioned(
                left: 0,
                right: 0,
                bottom: MediaQuery.of(context).size.height * _slideAnimation.value * -1,
                child: Container(
                  decoration: const BoxDecoration(
                    color: Color(0xFF101513),
                    borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Header
                      Container(
                        padding: const EdgeInsets.all(20),
                        child: Row(
                          children: [
                            Text(_modalTitle,
                                style: const TextStyle(
                                    color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                            const Spacer(),
                            IconButton(
                              onPressed: _cancel,
                              icon: Container(
                                padding: const EdgeInsets.all(6),
                                decoration: BoxDecoration(
                                  color: Colors.white.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: const Icon(Icons.close, color: Colors.white, size: 16),
                              ),
                            ),
                          ],
                        ),
                      ),

                      // Form
                      Container(
                        constraints:
                            BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.8),
                        child: SingleChildScrollView(
                          padding: const EdgeInsets.symmetric(horizontal: 20),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _buildColorPicker(),
                              const SizedBox(height: 20),

                              Row(
                                children: [
                                  Expanded(
                                    child: _buildTextField(
                                      label: 'Name',
                                      controller: _nameController,
                                      hint: 'e.g. 30 push-ups',
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: _buildTextField(
                                      label: 'Category',
                                      controller: _categoryController,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 16),

                              Row(
                                children: [
                                  Expanded(
                                    child: _buildDateField(
                                      label: 'Start date',
                                      value: _formData['startDate'] ?? '',
                                      onChanged: (v) => _updateFormData('startDate', v),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: _buildDateField(
                                      label: 'End date',
                                      value: _formData['endDate'] ?? '',
                                      onChanged: (v) => _updateFormData('endDate', v),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 16),

                              Row(
                                children: [
                                  Expanded(
                                    child: _buildDropdown(
                                      label: 'Repeat',
                                      value: _formData['frequency'] ?? 'daily',
                                      options: const ['daily', 'weekdays', 'weekends', 'everyN', 'custom'],
                                      onChanged: (v) => _updateFormData('frequency', v),
                                    ),
                                  ),
                                  if (_formData['frequency'] == 'everyN') ...[
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: _buildTextField(
                                        label: 'Every N days',
                                        controller: _everyNController,
                                        keyboardType: TextInputType.number,
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                              const SizedBox(height: 16),

                              _buildIntensitySelector(),
                              const SizedBox(height: 20),

                              _buildReminderSection(),
                              const SizedBox(height: 32),

                              Row(
                                children: [
                                  Expanded(
                                    child: GestureDetector(
                                      onTap: _cancel,
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(vertical: 16),
                                        decoration: BoxDecoration(
                                          color: Colors.white.withOpacity(0.1),
                                          borderRadius: BorderRadius.circular(12),
                                        ),
                                        child: const Text('Cancel',
                                            textAlign: TextAlign.center,
                                            style: TextStyle(
                                                color: Colors.white,
                                                fontSize: 16,
                                                fontWeight: FontWeight.w600)),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: GestureDetector(
                                      onTap: _save,
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(vertical: 16),
                                        decoration: BoxDecoration(
                                          color: const Color(0xFF10B981),
                                          borderRadius: BorderRadius.circular(12),
                                        ),
                                        child: const Text('Save',
                                            textAlign: TextAlign.center,
                                            style: TextStyle(
                                                color: Colors.black,
                                                fontSize: 16,
                                                fontWeight: FontWeight.w600)),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 20),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
