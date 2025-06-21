import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../icon_color_utils.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:intl/intl.dart';

class CategorySelectionModal extends StatefulWidget {
  //khai báo hàm function được truyền từ bên ngoài trả về void
  final Function(dynamic) onCategorySelected;
  final String token;
  final dynamic idnguodung;
  final List<dynamic> transactionTypes;

  const CategorySelectionModal({
    Key? key,
    required this.onCategorySelected,
    required this.token,
    required this.idnguodung,
    required this.transactionTypes,
  }) : super(key: key);

  @override
  State<CategorySelectionModal> createState() => _CategorySelectionModalState();
}

class _CategorySelectionModalState extends State<CategorySelectionModal> with TickerProviderStateMixin {
  late TabController _mainTabController;
  late TabController _chiTieuTabController;

  bool _isLoading = true;
  String? _error;
  
  dynamic _selectedCategory;

  List<dynamic> _allCategories = [];
  List<dynamic> _thuNhapCategories = [];
  List<dynamic> _phatSinhCategories = [];
  List<dynamic> _hangThangCategories = [];


  @override
  void initState() {
    super.initState();
    _mainTabController = TabController(length: 2, vsync: this);
    _chiTieuTabController = TabController(length: 2, vsync: this);
    _fetchCategories();
  }

  @override
  void dispose() {
    _mainTabController.dispose();
    _chiTieuTabController.dispose();
    super.dispose();
  }

  Future<void> _fetchCategories() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final urlDefaultCategories = Uri.parse('http://10.0.2.2:8081/QuanLyChiTieu/api/default-categories');
      final urlUserCategories = Uri.parse('http://10.0.2.2:8081/QuanLyChiTieu/api/categories/user/${widget.idnguodung}');
      final urlColors = Uri.parse('http://10.0.2.2:8081/QuanLyChiTieu/api/colors');
      final urlIcons = Uri.parse('http://10.0.2.2:8081/QuanLyChiTieu/api/icons');

      // Fetch icons
      final iconResponse = await http.get(urlIcons, headers: {
        'Authorization': 'Bearer ${widget.token}', //token được truyền từ widget cha
      });
      if (iconResponse.statusCode != 200) {
        print('Icons API Response Body: ${iconResponse.body}');
        throw Exception('Failed to load icons: Status ${iconResponse.statusCode}');
      }
      final List<dynamic> iconData = json.decode(iconResponse.body);
      // Fetch colors
      final colorResponse = await http.get(urlColors, headers: {
        'Authorization': 'Bearer ${widget.token}',
      });
      if (colorResponse.statusCode != 200) {
         print('Colors API Response Body: ${colorResponse.body}');
        throw Exception('Failed to load colors: Status ${colorResponse.statusCode}');
      }
      final List<dynamic> colorData = json.decode(colorResponse.body);

      // Fetch default categories
      final defaultCategoryResponse = await http.get(urlDefaultCategories, headers: {
        'Authorization': 'Bearer ${widget.token}',
      });
      if (defaultCategoryResponse.statusCode != 200) {
         print('Default Categories API Response Body: ${defaultCategoryResponse.body}');
        throw Exception('Failed to load default categories: Status ${defaultCategoryResponse.statusCode}');
      }
      final List<dynamic> defaultCategoryData = json.decode(defaultCategoryResponse.body);

      // Fetch user categories
      final userCategoryResponse = await http.get(urlUserCategories, headers: {
        'Authorization': 'Bearer ${widget.token}',
      });
      if (userCategoryResponse.statusCode != 200) {
         print('User Categories API Response Body: ${userCategoryResponse.body}');
        throw Exception('Failed to load user categories: Status ${userCategoryResponse.statusCode}');
      }
      final List<dynamic> userCategoryData = json.decode(userCategoryResponse.body);

      // gộp 2 danh sách
      List<dynamic> combinedCategories = [...defaultCategoryData, ...userCategoryData];

      final processedCategories = combinedCategories.map((category) {
        // Find icon hex
        final icon = iconData.firstWhere(
          (icon) => icon['id_icon'] == category['id_icon'], // Match by id_icon
          orElse: () => {},
        );
        // Tìm ptu đầu tiên trong danh sách có id trùng để lấy ra màu phù hợp
         final color = colorData.firstWhere(
          (color) => color['id_mau'] == category['id_mau'],
          orElse: () => {},
        );

        return {
          ...category,
          'ma_icon': icon['ma_icon'] ?? 'f555',
          'ma_mau': color['ma_mau'] ?? '#2196F3',
        };
      }).toList();

      // Store all processed categories
      _allCategories = processedCategories;

      // Filter categories into specific lists
      setState(() {
        _thuNhapCategories = _allCategories
            .where((cat) => cat['id_loai'].toString() == '1')
            .toList();
        _phatSinhCategories = _allCategories
            .where((cat) => cat['id_loai'].toString() == '2' && cat['id_tennhom'].toString() == '2')
            .toList();
        _hangThangCategories = _allCategories
            .where((cat) => cat['id_loai'].toString() == '2' && cat['id_tennhom'].toString() == '1')
            .toList();
        _isLoading = false;
      });

    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  // Widget to build sectioned category list (User's and Default)
  Widget _buildSectionedCategoryList(List<dynamic> categories) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
      return Center(child: Text('Lỗi: $_error'));
    }

    final userCategories = categories.where((c) => c['id_nguoidung'] != null).toList();
    final defaultCategories = categories.where((c) => c['id_nguoidung'] == null).toList();

    if (userCategories.isEmpty && defaultCategories.isEmpty) {
      return const Center(child: Text('Không có danh mục nào'));
    }

    List<Widget> listItems = [];

    // Add user categories
    listItems.addAll(userCategories.map((category) => ListTile(
      leading: Icon(
        getFaIconDataFromUnicode(category['ma_icon'] ?? 'f555'),
        color: hexToColor(category['ma_mau'] ?? '#2196F3'),
      ),
      title: Text(category['ten_danh_muc'] ?? ''),
      trailing: _selectedCategory?['id_danhmuc'] == category['id_danhmuc']
          ? const Icon(Icons.check, color: Colors.blue)
          : null,
      onTap: () {
        setState(() => _selectedCategory = category);
        widget.onCategorySelected(category);
        Navigator.pop(context);
      },
    )));

    // Add default categories header and items
    if (defaultCategories.isNotEmpty) {
      listItems.add(
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 16.0, vertical: 16.0),
          child: Text(
            'Danh mục mặc định',
            style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey),
          ),
        ),
      );
      listItems.addAll(defaultCategories.map((category) => ListTile(
        leading: Icon(
          getFaIconDataFromUnicode(category['ma_icon'] ?? 'f555'),
          color: hexToColor(category['ma_mau'] ?? '#2196F3'),
        ),
        title: Text(category['ten_danh_muc'] ?? ''),
        trailing: _selectedCategory?['id_danhmuc'] == category['id_danhmuc']
            ? const Icon(Icons.check, color: Colors.blue)
            : null,
        onTap: () {
          setState(() => _selectedCategory = category);
          widget.onCategorySelected(category);
          Navigator.pop(context);
        },
      )));
    }

    return ListView(children: listItems);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.7,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        children: [
          TabBar(
            controller: _mainTabController,
            tabs: const [
              Tab(text: 'THU NHẬP'),
              Tab(text: 'CHI TIÊU'),
            ],
            labelColor: Colors.blue,
            unselectedLabelColor: Colors.grey,
          ),
          Expanded(
            child: TabBarView(
              controller: _mainTabController,
              children: [
                // Income Tab
                _buildSectionedCategoryList(_thuNhapCategories),

                // Expense Tab with sub-tabs
                Column(
                  children: [
                    TabBar(
                      controller: _chiTieuTabController,
                      tabs: const [
                        Tab(text: 'PHÁT SINH'),
                        Tab(text: 'HÀNG THÁNG'),
                      ],
                      labelColor: Colors.blue,
                      unselectedLabelColor: Colors.grey,
                    ),
                    Expanded(
                      child: TabBarView(
                        controller: _chiTieuTabController,
                        children: [
                           _buildSectionedCategoryList(_phatSinhCategories),
                           _buildMonthlyExpenseWidget(),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMonthlyExpenseWidget() {
    final now = DateTime.now();
    return FutureBuilder<http.Response>(
      future: http.get(
        Uri.parse('http://10.0.2.2:8081/QuanLyChiTieu/api/chi-tieu-hang-thang/user/${widget.idnguodung}/month/${now.month}/year/${now.year}'),
        headers: {'Authorization': 'Bearer ${widget.token}'},
      ),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError || !snapshot.hasData || snapshot.data!.statusCode != 200) {
          return const Center(child: Text('Không lấy được dữ liệu'));
        }
        
        final dynamic decodedBody = jsonDecode(snapshot.data!.body);
        int tongSoTien = 0;

        if (decodedBody is Map && decodedBody.containsKey('amount')) {
          tongSoTien = (double.tryParse(decodedBody['amount'].toString()) ?? 0.0).toInt();
        } else if (decodedBody is List) {
           for (var item in decodedBody) {
             final soTien = item['amount'];
             if (soTien != null) {
               tongSoTien += (double.tryParse(soTien.toString()) ?? 0.0).toInt();
             }
           }
        }
        
        final formatter = NumberFormat('#,###', 'vi_VN');

        return Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text(
                'Tổng chi phí hàng tháng:',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              Text(
                '${formatter.format(tongSoTien)} đ',
                style: const TextStyle(fontSize: 32, color: Colors.blue, fontWeight: FontWeight.bold),
              ),
            ],
          ),
        );
      },
    );
  }
} 