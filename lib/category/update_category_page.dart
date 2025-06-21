import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../icon_color_utils.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import '../utils/auth_utils.dart' as auth_utils;

class UpdateCategoryPage extends StatefulWidget {
  final String token;
  final dynamic idnguodung;
  final dynamic categoryData; // Existing category data to be updated

  const UpdateCategoryPage({
    super.key,
    required this.token,
    required this.idnguodung,
    required this.categoryData,
  });

  @override
  State<UpdateCategoryPage> createState() => _UpdateCategoryPageState();
}

class _UpdateCategoryPageState extends State<UpdateCategoryPage> {
  final _categoryNameController = TextEditingController();
  dynamic _selectedIcon;
  dynamic _selectedColor;
  dynamic _selectedTransactionType;
  List<dynamic> _transactionTypes = [];
  List<dynamic> _colors = [];
  List<dynamic> _icons = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
    _populateFields();
  }
//gán dulieu ban đầu vào
  void _populateFields() {
    _categoryNameController.text = widget.categoryData['ten_danh_muc'] ?? '';
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
    });
    try {
      await Future.wait([
        _fetchTransactionTypes(),
        _fetchColors(),
        _fetchIcons(),
      ]);
      _initializeSelections();
      setState(() {
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
    }
  }

  //khởi tạo lựa chọn ban đầu
  void _initializeSelections() {
    //icon
    final int? initialIconId = int.tryParse(widget.categoryData['id_icon']?.toString() ?? '');
    _selectedIcon = _icons.firstWhere(
      (icon) => icon['id_icon'] == initialIconId,
      orElse: () => null,
    );

    //color
    final int? initialColorId = int.tryParse(widget.categoryData['id_mau']?.toString() ?? '');
    _selectedColor = _colors.firstWhere(
      (color) => color['id_mau'] == initialColorId,
      orElse: () => null,
    );

    // loại giao dịch
    final int? initialTypeId = int.tryParse(widget.categoryData['id_loai']?.toString() ?? '');
    _selectedTransactionType = _transactionTypes.firstWhere(
      (type) => type['id_loai'] == initialTypeId,
      orElse: () => null,
    );
  }

  Future<void> _fetchTransactionTypes() async {
    final url = Uri.parse('http://10.0.2.2:8081/QuanLyChiTieu/api/transaction-types');
    final response = await http.get(
      url,
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer ${widget.token}',
      },
    );
    if (await auth_utils.handleApiResponse(context, response, widget.token, widget.idnguodung)) return;
    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      setState(() {
        _transactionTypes = data is List ? data : [];
      });
    } else {
      throw Exception('Failed to load transaction types');
    }
  }

  Future<void> _fetchColors() async {
    final url = Uri.parse('http://10.0.2.2:8081/QuanLyChiTieu/api/colors');
    final response = await http.get(url, headers: {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer ${widget.token}',
    });
    if (await auth_utils.handleApiResponse(context, response, widget.token, widget.idnguodung)) return;
    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      setState(() {
        _colors = data is List ? data : [];
      });
    } else {
      throw Exception('Failed to load colors');
    }
  }

  Future<void> _fetchIcons() async {
    final url = Uri.parse('http://10.0.2.2:8081/QuanLyChiTieu/api/icons');
    final response = await http.get(url, headers: {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer ${widget.token}',
    });
    if (await auth_utils.handleApiResponse(context, response, widget.token, widget.idnguodung)) return;
    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      setState(() {
        _icons = data is List ? data : [];
      });
    } else {
      throw Exception('Failed to load icons');
    }
  }

  Future<void> _updateCategory() async {
    print('Category Data: ${widget.categoryData}');
    if (_categoryNameController.text.isEmpty ||
        _selectedIcon == null ||
        _selectedColor == null ||
        _selectedTransactionType == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Vui lòng điền đầy đủ thông tin.')),
      );
      return;
    }

    final categoryId = widget.categoryData['id_danhmuc'];
    final url = Uri.parse('http://10.0.2.2:8081/QuanLyChiTieu/api/categories/$categoryId');
    final body = jsonEncode({
      'ten_danh_muc': _categoryNameController.text,
      'id_icon': _selectedIcon['id_icon'],
      'id_mau': _selectedColor['id_mau'],
      'id_loai': _selectedTransactionType['id_loai'],
      'id_nguoidung': widget.idnguodung,
    });

    try {
      final response = await http.put(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer ${widget.token}',
        },
        body: body,
      );

      if (await auth_utils.handleApiResponse(context, response, widget.token, widget.idnguodung)) return;

      if (response.statusCode == 200) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Cập nhật danh mục thành công!')),
        );
        Navigator.pop(context, true); // Pop with true to indicate success and refresh data
      } else {
        final errorData = jsonDecode(response.body);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Cập nhật danh mục thất bại: ${errorData['message'] ?? response.statusCode}')),
        );

      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Lỗi khi cập nhật danh mục: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Cập nhật danh mục'),
        centerTitle: true,
        backgroundColor: const Color(0xFF2196F3),
        foregroundColor: Colors.white,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
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
                  const SizedBox(height: 20),
                  const Text('Biểu tượng', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: _icons.map((icon) {
                      final iconData = getFaIconDataFromUnicode(icon['ma_icon']);
                      final isSelected = _selectedIcon != null && _selectedIcon['id_icon'] == icon['id_icon'];
                      return GestureDetector(
                        onTap: () {
                          setState(() {
                            _selectedIcon = icon;
                          });
                        },
                        child: Container(
                          width: 48,
                          height: 48,
                          decoration: BoxDecoration(
                            color: isSelected ? Colors.blue.withOpacity(0.3) : Colors.grey.withOpacity(0.1),
                            shape: BoxShape.circle,
                            border: isSelected ? Border.all(color: Colors.blue, width: 2) : null,
                          ),
                          child: Icon(iconData, color: isSelected ? Colors.blue : Colors.black54),
                        ),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 20),
                  const Text('Màu sắc', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: _colors.map((color) {
                      final parsedColor = hexToColor(color['ma_mau']);
                      final isSelected = _selectedColor != null && _selectedColor['id_mau'] == color['id_mau'];
                      return GestureDetector(
                        onTap: () {
                          setState(() {
                            _selectedColor = color;
                          });
                        },
                        child: Container(
                          width: 48,
                          height: 48,
                          decoration: BoxDecoration(
                            color: parsedColor.withOpacity(0.8),
                            shape: BoxShape.circle,
                            border: isSelected ? Border.all(color: Colors.blue, width: 2) : null,
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 20),
                  const Text('Loại giao dịch', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  DropdownButtonFormField<dynamic>(
                    value: _selectedTransactionType,
                    decoration: const InputDecoration(
                      border: OutlineInputBorder(),
                      contentPadding: EdgeInsets.symmetric(horizontal: 12.0, vertical: 8.0),
                    ),
                    items: _transactionTypes.map((type) {
                      return DropdownMenuItem<dynamic>(
                        value: type,
                        child: Text(type['ten_loai']),
                      );
                    }).toList(),
                    onChanged: (newValue) {
                      setState(() {
                        _selectedTransactionType = newValue;
                      });
                    },
                  ),
                  const SizedBox(height: 30),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _updateCategory,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF2196F3),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 15),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text(
                        'CẬP NHẬT DANH MỤC',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                ],
              ),
            ),
    );
  }
} 