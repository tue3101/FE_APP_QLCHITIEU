import 'package:flutter/material.dart';

class AddBudgetPage extends StatefulWidget {
  final String token;
  final dynamic idnguodung;

  const AddBudgetPage({super.key, required this.token, required this.idnguodung});

  @override
  State<AddBudgetPage> createState() => _AddBudgetPageState();
}

class _AddBudgetPageState extends State<AddBudgetPage> {
  TextEditingController _amountController = TextEditingController();
  String _selectedPeriod = 'Tháng này'; // Default value
  int _selectedStartDate = 1; // Default day

  @override
  void initState() {
    super.initState();
    _amountController.text = '0'; // Initial value
  }

  @override
  void dispose() {
    _amountController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFF2196F3),
        title: const Text('Cài đặt', style: TextStyle(color: Colors.white)),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () {
            Navigator.pop(context);
          },
        ),
      ),
      body: ListView(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Cài đặt ngân sách',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.blue[700],
                  ),
                ),
                const SizedBox(height: 16),
                _buildSettingItem(
                  icon: Icons.edit_note,
                  title: 'Số tiền',
                  value: _amountController.text,
                  onTap: () {
                    // Logic to open a dialog or a new page for amount input
                  },
                ),
                const SizedBox(height: 16),
                Text(
                  'Chu kỳ',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.black54,
                  ),
                ),
                const SizedBox(height: 8),
                _buildSettingItem(
                  icon: Icons.calendar_today,
                  title: _selectedPeriod,
                  value: '', // No value displayed below title for period
                  onTap: () {
                    // Logic to select period
                  },
                ),
                const SizedBox(height: 16),
                _buildSettingItem(
                  icon: Icons.calendar_view_day,
                  title: 'Cài đặt ngày bắt đầu',
                  value: _selectedStartDate.toString(),
                  onTap: () {
                    // Logic to select start date
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSettingItem({
    required IconData icon,
    required String title,
    required String value,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(8),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            Icon(icon, color: Colors.blueGrey, size: 24),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  if (value.isNotEmpty)
                    Text(
                      value,
                      style: const TextStyle(fontSize: 14, color: Colors.black54),
                    ),
                ],
              ),
            ),
            const Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey),
          ],
        ),
      ),
    );
  }
} 