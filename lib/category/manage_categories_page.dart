import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../icon_color_utils.dart'; // Ensure this path is correct
import '../main.dart';
import 'add_category_page.dart'; // Import the new page
import 'update_category_page.dart'; // Import the update page


class ManageCategoriesPage extends StatefulWidget {
  final String token;
  final dynamic idnguodung;
  final VoidCallback? onBackButtonPressed;

  const ManageCategoriesPage({
    super.key,
    required this.token,
    required this.idnguodung,
    this.onBackButtonPressed,
  });

  @override
  State<ManageCategoriesPage> createState() => _ManageCategoriesPageState();
}

class _ManageCategoriesPageState extends State<ManageCategoriesPage>
    with TickerProviderStateMixin {
  late TabController _tabController;
  late TabController _tabControllerChiTieu;
  bool _isLoading = true;
  String? _error;
  List<dynamic> _transactionTypes = [];
  List<dynamic> _defaultCategories = [];
  List<dynamic> _userCategories = [];
  List<dynamic> _colors = [];
  List<dynamic> _icons = [];
  List<dynamic> _allCategories = []; // Combined default and user categories
  Map<int, List<dynamic>> _groupedCategoriesByTransactionType = {};

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 0, vsync: this);
    _tabControllerChiTieu = TabController(length: 2, vsync: this);
    _loadData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _tabControllerChiTieu.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      await Future.wait([
        _fetchTransactionTypes(),
        _fetchDefaultCategories(),
        _fetchUserCategories(),
        _fetchColors(),
        _fetchIcons(),
      ]);

      _combineAndGroupCategories();

      if (_tabController.length != _transactionTypes.length) {
        _tabController.dispose();
        _tabController = TabController(length: _transactionTypes.length, vsync: this);
      }

      if (_tabControllerChiTieu == null || _tabControllerChiTieu.length != 2) {
        _tabControllerChiTieu?.dispose();
        _tabControllerChiTieu = TabController(length: 2, vsync: this);
      }

      setState(() {
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = 'Lỗi khi tải dữ liệu: $e';
        _isLoading = false;
      });
      print('Error loading data: $e');
    }
  }

  void _combineAndGroupCategories() {
    List<dynamic> combined = [];
    combined.addAll(_defaultCategories);
    combined.addAll(_userCategories);

    _allCategories = combined.map((category) {
      final int? categoryIconId =
          int.tryParse(category['id_icon']?.toString() ?? '');
      final int? categoryColorId =
          int.tryParse(category['id_mau']?.toString() ?? '');

      final iconData = _icons.firstWhere(
        (icon) => icon['id_icon'] == categoryIconId,
        orElse: () => {},
      );
      final colorData = _colors.firstWhere(
        (color) => color['id_mau'] == categoryColorId,
        orElse: () => {},
      );

      print('icon: ${iconData['ma_icon']}, color: ${colorData['ma_mau']}');

      return {
        ...category,
        'ma_icon': iconData['ma_icon'],
        'ma_mau': colorData['ma_mau'],
      };
    }).toList();

    _groupedCategoriesByTransactionType = {};
    for (var type in _transactionTypes) {
      final int typeId = int.tryParse(type['id_loai']?.toString() ?? '') ?? 0;
      _groupedCategoriesByTransactionType[typeId] = _allCategories
          .where((cat) =>
              int.tryParse(cat['id_loai']?.toString() ?? '') == typeId)
          .toList();
    }

    print('User categories: $_userCategories');
    print('Default categories: $_defaultCategories');

    // Sau khi map
    _defaultCategories = _allCategories.where((cat) => cat['id_nguoidung'] == null).toList();
    _userCategories = _allCategories.where((cat) => cat['id_nguoidung'] != null).toList();

    final chiTieuUser = _userCategories.where((cat) => cat['id_loai'] == 2).toList();
    final chiTieuDefault = _defaultCategories.where((cat) => cat['id_loai'] == 2).toList();
    print('User chi tiêu: $chiTieuUser');
    print('Default chi tiêu: $chiTieuDefault');

    print('userPhatSinh: $chiTieuUser');
    print('defaultPhatSinh: $chiTieuDefault');

    print('_userCategories: $_userCategories');
    print('_defaultCategories: $_defaultCategories');
    final userPhatSinh = _userCategories.where((cat) => cat['id_loai'].toString() == '2' && cat['id_tennhom'].toString() == '2').toList();
    final defaultPhatSinh = _defaultCategories.where((cat) => cat['id_loai'].toString() == '2' && cat['id_tennhom'].toString() == '2').toList();
    print('userPhatSinh: $userPhatSinh');
    print('defaultPhatSinh: $defaultPhatSinh');

    setState(() {
      _defaultCategories = _allCategories.where((cat) => cat['id_nguoidung'] == null).toList();
      _userCategories = _allCategories.where((cat) => cat['id_nguoidung'] != null).toList();
      _isLoading = false;
    });
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
    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      setState(() {
        _transactionTypes = data is List ? data : [];
      });
    } else {
      throw Exception('Failed to load transaction types');
    }
  }

  Future<void> _fetchDefaultCategories() async {
    final url = Uri.parse('http://10.0.2.2:8081/QuanLyChiTieu/api/default-categories');
    try {
      final response = await http.get(url, headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer ${widget.token}',
      });

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        setState(() {
          _defaultCategories = (data as List).map((category) => {
            ...category,
            'id_danhmuc': int.tryParse(category['id_danhmuc']?.toString() ?? ''),
          }).toList();
          List<dynamic> processedDefaultCategories = _defaultCategories.map((category) {
            final icon = _icons.firstWhere(
              (icon) => icon['id_icon'].toString() == category['id_icon'].toString(),
              orElse: () => null,
            );
            final color = _colors.firstWhere(
              (color) => color['id_mau'].toString() == category['id_mau'].toString(),
              orElse: () => null,
            );
            return {
              ...category,
              'ma_icon': icon != null ? icon['ma_icon'] : 'f555',
              'ma_mau': color != null ? color['ma_mau'] : '#2196F3',
            };
          }).toList();
        });
      } else {
        throw Exception('Failed to load default categories');
      }
    } catch (e) {
      throw e;
    }
  }

  Future<void> _fetchUserCategories() async {
    final url = Uri.parse('http://10.0.2.2:8081/QuanLyChiTieu/api/categories/user/${widget.idnguodung}');
    try {
      final response = await http.get(url, headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer ${widget.token}',
      });

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        setState(() {
          _userCategories = (data as List).map((category) => {
            ...category,
            'id_danhmuc': int.tryParse(category['id_danhmuc']?.toString() ?? ''),
          }).toList();
          List<dynamic> processedUserCategories = _userCategories.map((category) {
            final icon = _icons.firstWhere(
              (icon) => icon['id_icon'].toString() == category['id_icon'].toString(),
              orElse: () => null,
            );
            final color = _colors.firstWhere(
              (color) => color['id_mau'].toString() == category['id_mau'].toString(),
              orElse: () => null,
            );
            return {
              ...category,
              'ma_icon': icon != null ? icon['ma_icon'] : 'f555',
              'ma_mau': color != null ? color['ma_mau'] : '#2196F3',
            };
          }).toList();
        });
      } else {
        throw Exception('Failed to load user categories');
      }
    } catch (e) {
      throw e;
    }
  }

  Future<void> _fetchColors() async {
    final url = Uri.parse('http://10.0.2.2:8081/QuanLyChiTieu/api/colors');
    try {
      final response = await http.get(url, headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer ${widget.token}',
      });

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        setState(() {
          _colors = data is List ? data : [];
        });
      } else {
        throw Exception('Failed to load colors');
      }
    } catch (e) {
      throw e;
    }
  }

  Future<void> _fetchIcons() async {
    final url = Uri.parse('http://10.0.2.2:8081/QuanLyChiTieu/api/icons');
    try {
      final response = await http.get(url, headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer ${widget.token}',
      });

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        setState(() {
          _icons = data is List ? data : [];
        });
      } else {
        throw Exception('Failed to load icons');
      }
    } catch (e) {
      throw e;
    }
  }

  Future<bool> _checkIfCategoryHasTransactions(int categoryId) async {
    try {
      final url = Uri.parse('http://10.0.2.2:8081/QuanLyChiTieu/api/transactions/user/${widget.idnguodung}/all');
      final response = await http.get(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer ${widget.token}',
        },
      );
      
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        List<dynamic> transactions = [];
        if (data is List) {
          transactions = data;
        } else if (data is Map && data['data'] is List) {
          transactions = data['data'];
        }
        
        // Kiểm tra xem có giao dịch nào sử dụng danh mục này không
        return transactions.any((transaction) => 
          int.tryParse(transaction['id_danhmuc']?.toString() ?? '') == categoryId
        );
      } else {
        return false;
      }
    } catch (e) {
      return false;
    }
  }

  Future<void> _confirmDeleteCategory(int categoryId) async {
    final bool hasTransactions = await _checkIfCategoryHasTransactions(categoryId);

    if (hasTransactions) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Không thể xóa danh mục này vì có giao dịch tồn tại.')),
      );
      return;
    }

    final bool? confirm = await showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Xác nhận xóa'),
          content: const Text('Bạn có chắc chắn muốn xóa danh mục này?'),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Hủy'),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Xóa'),
            ),
          ],
        );
      },
    );

    if (confirm == true) {
      final url = Uri.parse('http://10.0.2.2:8081/QuanLyChiTieu/api/categories/$categoryId');
      try {
        final response = await http.delete(
          url,
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer ${widget.token}',
          },
        );
        if (response.statusCode == 200) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Xóa danh mục thành công!')),
          );
          _loadData(); // Refresh data after delete
        } else {
          final errorData = jsonDecode(response.body);
          String errorMessage = 'Xóa danh mục thất bại.';
          if (errorData != null && errorData['message'] != null) {
            errorMessage = errorData['message'];
          } else if (response.statusCode == 400) {
            errorMessage = 'Yêu cầu không hợp lệ.';
          } else if (response.statusCode == 404) {
            errorMessage = 'Không tìm thấy danh mục.';
          }
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(errorMessage)),
          );
        }
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Lỗi khi xóa danh mục: $e')),
        );
      }
    }
  }

  Widget _buildCategoryListByNhom(int idNhom) {
    final List<dynamic> allCategoriesForType = _allCategories
        .where((cat) => cat['id_loai'] == 2 && cat['id_tennhom'] == idNhom)
        .toList();

    final List<dynamic> userCategoriesForType = allCategoriesForType
        .where((cat) => cat['id_nguoidung'] != null)
        .toList();

    final List<dynamic> defaultCategoriesForType = allCategoriesForType
        .where((cat) => cat['id_nguoidung'] == null)
        .toList();

    List<Widget> categoryWidgets = [];

    // Thêm danh mục người dùng
    if (userCategoriesForType.isNotEmpty) {
      categoryWidgets.addAll(userCategoriesForType.map((category) {
        final iconCode = category?['ma_icon'] ?? 'f555';
        final colorCode = category?['ma_mau'] ?? '#2196F3';
        return _CategoryItem(
          categoryData: category,
          icon: getFaIconDataFromUnicode(iconCode),
          iconColor: hexToColor(colorCode),
          title: category['ten_danh_muc'] ?? 'Không rõ',
          onEdit: () async {
            final result = await Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => UpdateCategoryPage(
                  token: widget.token,
                  idnguodung: widget.idnguodung,
                  categoryData: category,
                ),
              ),
            );
            if (result == true) {
              _loadData();
            }
          },
          onDelete: (categoryId) => _confirmDeleteCategory(categoryId),
        );
      }));
    }

    // Thêm tiêu đề danh mục mặc định nếu có
    if (defaultCategoriesForType.isNotEmpty) {
      categoryWidgets.add(
        const Padding(
          padding: EdgeInsets.symmetric(vertical: 16.0),
          child: Text(
            'Danh mục mặc định',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 18,
              color: Colors.grey,
            ),
          ),
        ),
      );
      // Thêm danh mục mặc định
      categoryWidgets.addAll(defaultCategoriesForType.map((category) {
        final iconCode = category?['ma_icon'] ?? 'f555';
        final colorCode = category?['ma_mau'] ?? '#2196F3';
        return _CategoryItem(
          categoryData: category,
          icon: getFaIconDataFromUnicode(iconCode),
          iconColor: hexToColor(colorCode),
          title: category['ten_danh_muc'] ?? 'Không rõ',
          onEdit: () {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Không thể chỉnh sửa danh mục mặc định.')),
            );
          },
          onDelete: (categoryId) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Không thể xóa danh mục mặc định.')),
            );
          },
        );
      }));
    }

    if (categoryWidgets.isEmpty) {
      return const Center(child: Text('Chưa có danh mục nào'));
    }

    return ListView(
      padding: const EdgeInsets.all(16.0),
      children: categoryWidgets,
    );
  }

  @override
  Widget build(BuildContext context) {
    print('BUILD MANAGE CATEGORIES PAGE');
    return Scaffold(
      appBar: AppBar(
        title: const Text('Phân loại quản lý'),
        centerTitle: true,
        backgroundColor: const Color(0xFF2196F3),
        foregroundColor: Colors.white,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            if (widget.onBackButtonPressed != null) {
              widget.onBackButtonPressed!();
            } else {
              Navigator.pop(context);
            }
          },
        ),

      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(child: Text(_error!))
              : Column(
                  children: [
                    TabBar(
                      controller: _tabController,
                      tabs: [
                        Tab(text: 'Thu nhập'),
                        Tab(text: 'Chi tiêu'),
                      ],
                    ),
                    Expanded(
                      child: TabBarView(
                        controller: _tabController,
                        children: [
                          buildThuNhapWidget(),
                          buildChiTieuTabWithSubTabs(),
                        ],
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: () async {
                            final result = await Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => AddCategoryPage(
                                  token: widget.token,
                                  idnguodung: widget.idnguodung,
                                ),
                              ),
                            );
                            if (result == true) {
                              _loadData();
                            }
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF2196F3),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: const Text('THÊM DANH MỤC', style: TextStyle(fontSize: 18)),
                        ),
                      ),
                    ),
                  ],
                ),
    );
  }

  Widget buildThuNhapWidget() {
    // Lọc danh mục thu nhập
    final userThuNhap = _userCategories.where((cat)
    => cat['id_loai'] == 1).toList();
    final defaultThuNhap = _defaultCategories.where((cat)
    => cat['id_loai'] == 1).toList();

    List<Widget> widgets = [];

    // Danh mục người dùng
    if (userThuNhap.isNotEmpty) {
      widgets.addAll(userThuNhap.map((category) {
        final iconCode = category['ma_icon'] ?? 'f555';
        final colorCode = category['ma_mau'] ?? '#2196F3';
        return _CategoryItem(
          categoryData: category,
          icon: getFaIconDataFromUnicode(iconCode),
          iconColor: hexToColor(colorCode),
          title: category['ten_danh_muc'] ?? 'Không rõ',
          onEdit: () async {
            final result = await Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => UpdateCategoryPage(
                  token: widget.token,
                  idnguodung: widget.idnguodung,
                  categoryData: category,
                ),
              ),
            );
            if (result == true) {
              _loadData();
            }
          },
          onDelete: (categoryId) => _confirmDeleteCategory(categoryId),
        );
      }));
    }

    // Tiêu đề danh mục mặc định
    if (defaultThuNhap.isNotEmpty) {
      widgets.add(
        const Padding(
          padding: EdgeInsets.symmetric(vertical: 16.0),
          child: Text(
            'Danh mục mặc định',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 18,
              color: Colors.grey,
            ),
          ),
        ),
      );
      widgets.addAll(defaultThuNhap.map((category) {
        final iconCode = category['ma_icon'] ?? 'f555';
        final colorCode = category['ma_mau'] ?? '#2196F3';
        return _CategoryItem(
          categoryData: category,
          icon: getFaIconDataFromUnicode(iconCode),
          iconColor: hexToColor(colorCode),
          title: category['ten_danh_muc'] ?? 'Không rõ',
          onEdit: () {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Không thể chỉnh sửa danh mục mặc định.')),
            );
          },
          onDelete: (categoryId) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Không thể xóa danh mục mặc định.')),
            );
          },
        );
      }));
    }

    if (widgets.isEmpty) {
      return const Center(child: Text('Chưa có danh mục nào'));
    }

    return ListView(
      padding: const EdgeInsets.all(16.0),
      children: widgets,
    );
  }

  Widget buildChiTieuTabWithSubTabs() {
    return Column(
      children: [
        TabBar(
          controller: _tabControllerChiTieu,
          tabs: [
            Tab(text: 'Phát sinh'),
            Tab(text: 'Hàng tháng'),
          ],
        ),
        Expanded(
          child: TabBarView(
            controller: _tabControllerChiTieu,
            children: [
              danhMucPhatSinhWidget(),
              danhMucHangThangWidget(),
            ],
          ),
        ),
      ],
    );
  }

  Widget danhMucPhatSinhWidget() {
    print('BUILD danhMucPhatSinhWidget');
    // Lọc danh mục phát sinh của người dùng (chi tiêu)
    final userPhatSinh = _userCategories.where(
      (cat) => cat['id_loai'] == 2 && cat['id_tennhom'] == 2
    ).toList();

    // Lọc danh mục phát sinh mặc định (chi tiêu)
    final defaultPhatSinh = _defaultCategories.where(
      (cat) => cat['id_loai'] == 2 && cat['id_tennhom'] == 2
    ).toList();

    print('userPhatSinh: $userPhatSinh');
    print('defaultPhatSinh: $defaultPhatSinh');

    List<Widget> widgets = [];

    // Danh mục của người dùng
    if (userPhatSinh.isNotEmpty) {
      widgets.addAll(userPhatSinh.map((category) {
        final iconCode = category['ma_icon'] ?? 'f555';
        final colorCode = category['ma_mau'] ?? '#2196F3';
        return _CategoryItem(
          categoryData: category,
          icon: getFaIconDataFromUnicode(iconCode),
          iconColor: hexToColor(colorCode),
          title: category['ten_danh_muc'] ?? 'Không rõ',
          onEdit: () async {
            final result = await Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => UpdateCategoryPage(
                  token: widget.token,
                  idnguodung: widget.idnguodung,
                  categoryData: category,
                ),
              ),
            );
            if (result == true) {
              _loadData();
            }
          },
          onDelete: (categoryId) => _confirmDeleteCategory(categoryId),
        );
      }));
    }

    // Tiêu đề danh mục mặc định
    if (defaultPhatSinh.isNotEmpty) {
      widgets.add(
        const Padding(
          padding: EdgeInsets.symmetric(vertical: 16.0),
          child: Text(
            'Danh mục mặc định',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 18,
              color: Colors.grey,
            ),
          ),
        ),
      );
      widgets.addAll(defaultPhatSinh.map((category) {
        final iconCode = category['ma_icon'] ?? 'f555';
        final colorCode = category['ma_mau'] ?? '#2196F3';
        return _CategoryItem(
          categoryData: category,
          icon: getFaIconDataFromUnicode(iconCode),
          iconColor: hexToColor(colorCode),
          title: category['ten_danh_muc'] ?? 'Không rõ',
          onEdit: () {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Không thể chỉnh sửa danh mục mặc định.')),
            );
          },
          onDelete: (categoryId) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Không thể xóa danh mục mặc định.')),
            );
          },
        );
      }));
    }

    if (widgets.isEmpty) {
      return const Center(child: Text('Chưa có danh mục nào'));
    }

    return ListView(
      padding: const EdgeInsets.all(16.0),
      children: widgets,
    );
  }

  Widget danhMucHangThangWidget() {
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
          return const Center(child: Text('Không lấy được dữ liệu chi tiêu hàng tháng'));
        }
        
        final dynamic decodedBody = jsonDecode(snapshot.data!.body);
        final List<dynamic> chiTieuData;

        if (decodedBody is List) {
          chiTieuData = decodedBody;
        } else if (decodedBody is Map<String, dynamic>) {
          chiTieuData = [decodedBody]; // Wrap the map in a list
        } else {
          chiTieuData = []; // Handle other cases gracefully
        }

        // tổng chi
        int tongSoTien = 0;
        for (var item in chiTieuData) {
          final soTien = item['amount'];
          if (soTien != null) {
            final parsedValue = double.tryParse(soTien.toString()) ?? 0.0; //ko chuyển đc -> 0.0
            tongSoTien += parsedValue.toInt();
          }
        }

        return Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text(
                'Tổng chi phí hàng tháng phải trả:',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              Text(
                '${tongSoTien} đ',
                style: const TextStyle(fontSize: 32, color: Colors.blue, fontWeight: FontWeight.bold),
              ),
              ElevatedButton( //nút cập nhật số tiền hàng tháng
                onPressed: () async {
                  final newAmount = await showDialog<int>(
                    context: context,
                    builder: (context) => UpdateAmountDialog(),
                  );
                  if (newAmount != null) {
                    await updateMonthlyAmount(context, newAmount);
                    setState(() {}); // reload lại dữ liệu
                  }
                },
                child: const Text('Cập nhật số tiền'),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> updateMonthlyAmount(BuildContext context, int amount) async {
    final now = DateTime.now();
    final url = Uri.parse(
      'http://10.0.2.2:8081/QuanLyChiTieu/api/chi-tieu-hang-thang/user/${widget.idnguodung}/month/${now.month}/year/${now.year}/amount'
    );
    final response = await http.put(
      url,
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer ${widget.token}',
      },
      body: jsonEncode({'amount': amount}),
    );
    print('Status: ${response.statusCode}');
    print('Body: ${response.body}');
    if (response.statusCode == 200) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Cập nhật thành công!')),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Cập nhật thất bại: ${response.body}')),
      );
    }
  }
}

class _CategoryItem extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String title;
  final VoidCallback onEdit;
  final Function(int) onDelete;
  final dynamic categoryData;

  const _CategoryItem({
    super.key,
    //bắt buộc truyền các giá trị này
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.onEdit,
    required this.onDelete,
    required this.categoryData,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: iconColor.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: iconColor, size: 24),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              title,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          IconButton(
            icon: const Icon(Icons.edit, color: Colors.grey),
            onPressed: onEdit,
          ),
          IconButton(
            icon: const Icon(Icons.delete, color: Colors.red),
            onPressed: () => onDelete(int.parse(categoryData['id_danhmuc'].toString())),
          ),
        ],
      ),
    );
  }
}

///hộp thoại update số tiền hàng tháng
class UpdateAmountDialog extends StatefulWidget {
  @override
  State<UpdateAmountDialog> createState() => _UpdateAmountDialogState();
}

class _UpdateAmountDialogState extends State<UpdateAmountDialog> {
  final TextEditingController _controller = TextEditingController();

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Cập nhật số tiền hàng tháng'),
      content: TextField(
        controller: _controller,
        keyboardType: TextInputType.number,
        decoration: const InputDecoration(labelText: 'Nhập số tiền mới'),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Hủy'),
        ),
        ElevatedButton(
          onPressed: () {
            final value = int.tryParse(_controller.text);
            if (value != null) {
              Navigator.pop(context, value);
            }
          },
          child: const Text('Cập nhật'),
        ),
      ],
    );
  }
} 