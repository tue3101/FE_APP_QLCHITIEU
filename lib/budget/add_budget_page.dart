import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:intl/intl.dart';

class AddBudgetPage extends StatefulWidget {
  final String token;
  final dynamic idnguodung;

  const AddBudgetPage({super.key, required this.token, required this.idnguodung});

  @override
  State<AddBudgetPage> createState() => _AddBudgetPageState();
}

class _AddBudgetPageState extends State<AddBudgetPage> {
  bool _isLoading = true;
  Map<String, dynamic>? _budgetData; // ? -> biến này có thể null
  final NumberFormat _formatter = NumberFormat('#,###', 'vi_VN'); //định dạng hiển thị phaân cách hàng nghìn

  @override
  void initState() {
    super.initState();
    _fetchBudget();
  }

  Future<void> _fetchBudget() async {
    setState(() {
      _isLoading = true;
    });

    final now = DateTime.now(); //gán thời gian hện tại
    final url = Uri.parse(
        'http://10.0.2.2:8081/QuanLyChiTieu/api/budget/user/${widget.idnguodung}/month/${now.month}/year/${now.year}');

    try {
      final response = await http.get(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer ${widget.token}',
        },
      );

      if (response.statusCode == 200) {
        //utf8.decode(...) chuyển nó thành chuỗi gốc.
        //response.bodyBytes	Dữ liệu thô gốc dưới dạng byte (an toàn hơn để tự decode)
        final responseBody = utf8.decode(response.bodyBytes);
        final data = jsonDecode(responseBody);
        setState(() {
          _budgetData = data;
        });
      } else if (response.statusCode == 404) {
        setState(() {
          _budgetData = null;
        });
      } else {
        print('Failed to load budget: ${response.statusCode}');
        setState(() {
          _budgetData = null;
        });
      }
    } catch (e) {
      print('Error fetching budget: $e');
      setState(() {
        _budgetData = null;
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  //dialog cập nhật ngân sách
  Future<void> _showUpdateBudgetDialog() async {
    final amountController = TextEditingController();
    // Không gán giá trị cũ vào controller nữa
    // if (_budgetData != null && _budgetData!['ngansach'] != null) {
    //   amountController.text = _budgetData!['ngansach'].toString();
    // }

    final newAmount = await showDialog<String>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Cập nhật ngân sách'),
          content: TextField(
            controller: amountController,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(labelText: 'Nhập số tiền'),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Hủy'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.of(context).pop(amountController.text);
              },
              child: const Text('Cập nhật'),
            ),
          ],
        );
      },
    );

    //so tiền mới khác null và ko rỗng
    if (newAmount != null && newAmount.isNotEmpty) {
      final amountValue = int.tryParse(newAmount);
      if (amountValue != null) {
        _createOrUpdateBudget(amountValue);
      }
    }
  }

  //hàm tạo hoặc cập nhật số tiền
  Future<void> _createOrUpdateBudget(int newAmount) async {
    //nếu có thì cập nhật
    if (_budgetData != null && _budgetData!['id_ngansach'] != null) {
      await _updateBudget(newAmount);
    } else { //chưa thì tạo
      await _createBudget(newAmount);
    }
  }

  //hàm tạo ngân sách
  Future<void> _createBudget(int newAmount) async {
    final url = Uri.parse('http://10.0.2.2:8081/QuanLyChiTieu/api/budget');
    final now = DateTime.now();//gán thời gian hiện tại
    try {
      final response = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer ${widget.token}',
        },
        body: jsonEncode({
          'id_nguoidung': widget.idnguodung,
          'ngansach': newAmount,
          'thang': now.month,
          'nam': now.year,
        }),
      );

      if (response.statusCode == 201 || response.statusCode == 200) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Tạo ngân sách thành công!')),
        );
        Navigator.pop(context, true); // Đóng và báo thành công
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Tạo ngân sách thất bại: ${response.body}')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Lỗi khi tạo ngân sách: $e')),
      );
    }
  }

  //hàm cập nhật ngân sách
  Future<void> _updateBudget(int newAmount) async {
    final budgetId = _budgetData!['id_ngansach'];
    final url = Uri.parse(
        'http://10.0.2.2:8081/QuanLyChiTieu/api/budget/$budgetId');
    try {
      final response = await http.put(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer ${widget.token}',
        },
        body: jsonEncode({
          'id_nguoidung': _budgetData!['id_nguoidung'],
          'ngansach': newAmount,
          'thang': _budgetData!['thang'],
          'nam': _budgetData!['nam'],
        }),
      );

      if (response.statusCode == 200) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Cập nhật ngân sách thành công!')),
        );
        Navigator.pop(context, true); // Đóng và báo thành công
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Cập nhật thất bại: ${response.body}')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Lỗi khi cập nhật ngân sách: $e')),
      );
    }
  }


  //giao diện hiển thị
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
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
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
                        value: _budgetData != null && _budgetData!['ngansach'] != null
                            ? '${_formatter.format(_budgetData!['ngansach'])} đ'
                            : 'Chưa có ngân sách',
                        onTap: _showUpdateBudgetDialog,
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