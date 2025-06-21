import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../icon_color_utils.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

class AddCategoryPage extends StatefulWidget {
  final String token;
  final dynamic idnguodung;

  const AddCategoryPage({
    super.key,
    required this.token,
    required this.idnguodung,
  });

  @override
  State<AddCategoryPage> createState() => _AddCategoryPageState();
}

class _AddCategoryPageState extends State<AddCategoryPage> {
  final TextEditingController _categoryNameController = TextEditingController();
  dynamic? _selectedIcon; // Stores selected icon data
  dynamic? _selectedColor; // Stores selected color data
  dynamic? _selectedTransactionType; // Stores selected transaction type (income/expense)

  List<dynamic> _icons = [];
  List<dynamic> _colors = [];
  List<dynamic> _transactionTypes = [];
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void dispose() {
    _categoryNameController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    try {
      await Future.wait([
        _fetchIcons(),
        _fetchColors(),
        _fetchTransactionTypes(),
      ]);
      setState(() {
        _isLoading = false;
        //gán ptu đầu tiên vào lựa chọn
        if (_icons.isNotEmpty) _selectedIcon = _icons.first;
        if (_colors.isNotEmpty) _selectedColor = _colors.first;
        if (_transactionTypes.isNotEmpty) _selectedTransactionType = _transactionTypes.first;
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'Lỗi tải dữ liệu: $e';
        _isLoading = false;
      });
    }
  }

  Future<void> _fetchIcons() async {
    final url = Uri.parse('http://10.0.2.2:8081/QuanLyChiTieu/api/icons');
    final response = await http.get(url, headers: {
      'Authorization': 'Bearer ${widget.token}',
    });
    if (response.statusCode == 200) {
      _icons = json.decode(response.body);
    } else {
      throw Exception('Failed to load icons');
    }
  }

  Future<void> _fetchColors() async {
    final url = Uri.parse('http://10.0.2.2:8081/QuanLyChiTieu/api/colors');
    final response = await http.get(url, headers: {
      'Authorization': 'Bearer ${widget.token}',
    });
    if (response.statusCode == 200) {
      _colors = json.decode(response.body);
    } else {
      throw Exception('Failed to load colors');
    }
  }

  Future<void> _fetchTransactionTypes() async {
    final url = Uri.parse('http://10.0.2.2:8081/QuanLyChiTieu/api/transaction-types');
    final response = await http.get(url, headers: {
      'Authorization': 'Bearer ${widget.token}',
    });
    if (response.statusCode == 200) {
      _transactionTypes = json.decode(response.body);
    } else {
      throw Exception('Failed to load transaction types');
    }
  }

  Future<void> _addCategory() async {
    if (_categoryNameController.text.isEmpty ||
        _selectedIcon == null ||
        _selectedColor == null ||
        _selectedTransactionType == null) {
      setState(() {
        _errorMessage = 'Vui lòng điền đầy đủ thông tin.';
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final Map<String, dynamic> requestBody = {
      'ten_danh_muc': _categoryNameController.text,
      'id_icon': _selectedIcon!['id_icon'],
      'id_mau': _selectedColor!['id_mau'],
      'id_loai': _selectedTransactionType!['id_loai'],
    };

    // Nếu là 'Chi tiêu', thêm id_tennhom là 2. Nếu là thu nhập, id_tennhom sẽ là null.
    if (_selectedTransactionType!['id_loai'].toString() == '2') {
      requestBody['id_tennhom'] = 2; // Gán cứng là 2 (Phát sinh)
    } else {
      requestBody['id_tennhom'] = null; // Gán là null cho Thu nhập
    }

    final url = Uri.parse('http://10.0.2.2:8081/QuanLyChiTieu/api/categories');
    try {
      print('--- DEBUG: Add Category ---');
      print('Request URL: $url');
      print('Request Body: ${jsonEncode(requestBody)}');
      print('--- END DEBUG ---');

      final response = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer ${widget.token}',
        },
        body: jsonEncode(requestBody),
      );

      print('Response Status: ${response.statusCode}');
      print('Response Body: ${response.body}');

      if (response.statusCode == 200 || response.statusCode == 201) {
        Navigator.pop(context, true); // Return true to indicate success
      } else {
        setState(() {
          _errorMessage = 'Lỗi khi thêm danh mục: ${response.body}';
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Đã xảy ra lỗi: $e';
      });
    } finally {//luôn chạy
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Thêm phân loại mới'),
        centerTitle: true,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _errorMessage != null
              ? Center(child: Text(_errorMessage!))
              : SingleChildScrollView(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.grey),
                          borderRadius: BorderRadius.circular(8.0),
                        ),
                        child: TextField(
                          controller: _categoryNameController,
                          decoration: const InputDecoration(
                            labelText: 'Tên danh mục',
                            border: InputBorder.none,
                            contentPadding: EdgeInsets.symmetric(horizontal: 12.0, vertical: 12.0),
                          ),
                        ),
                      ),
                      const SizedBox(height: 40),
                      _buildDropdownSection(
                        'Chọn biểu tượng',
                        _icons,
                        _selectedIcon,
                        //hàm callback khi chọn biểu tượng khác
                        (value) => setState(() => _selectedIcon = value),
                        (item) => Icon(
                          getFaIconDataFromUnicode(item['ma_icon']),
                          color: hexToColor(item['ma_mau'] ?? '#2196F3'),
                          size: 30,
                        ),
                        (item) => item['ten_icon'].toString(),
                      ),
                      const SizedBox(height: 20),
                      _buildDropdownSection(
                        'Chọn màu sắc',
                        _colors,
                        _selectedColor,
                        (value) => setState(() => _selectedColor = value),
                        (item) => Container(
                          width: 30,
                          height: 30,
                          decoration: BoxDecoration(
                            color: hexToColor(item['ma_mau']),
                            shape: BoxShape.circle,
                          ),
                        ),
                        (item) => item['ten_mau'].toString(),
                      ),
                      const SizedBox(height: 20),
                      _buildDropdownSection(
                        'Chọn loại giao dịch',
                        _transactionTypes,
                        _selectedTransactionType,
                        (value) => setState(() => _selectedTransactionType = value),
                        (item) => const SizedBox.shrink(),
                        (item) => item['ten_loai'].toString(),
                      ),

                      const SizedBox(height: 30),
                      Center(
                        child: ElevatedButton(
                          onPressed: _isLoading ? null : _addCategory,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.blue,
                            padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 15),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          child: _isLoading
                              ? const CircularProgressIndicator(color: Colors.white)
                              : const Text(
                                  'Thêm danh mục',
                                  style: TextStyle(fontSize: 18, color: Colors.white),
                                ),
                        ),
                      ),
                    ],
                  ),
                ),
    );
  }

  Widget _buildDropdownSection(
    String title,
    List<dynamic> items,
    dynamic selectedItem,
    ValueChanged<dynamic?> onChanged, //callback khi chọn item mới
    Widget Function(dynamic) displayItem,//hiển thị bên cạnh item
    String Function(dynamic) itemToString,//chuỗi tên tương ứng item
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          decoration: BoxDecoration(
            border: Border.all(color: Colors.grey),
            borderRadius: BorderRadius.circular(8),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<dynamic>(
              isExpanded: true,
              value: selectedItem,
              hint: Text(title),
              onChanged: onChanged,
              items: items.map((item) {
                return DropdownMenuItem<dynamic>(
                  value: item,
                  child: Row(
                    children: [
                      displayItem(item),
                      const SizedBox(width: 10),
                      Text(itemToString(item)),
                    ],
                  ),
                );
              }).toList(),
            ),
          ),
        ),
      ],
    );
  }
} 