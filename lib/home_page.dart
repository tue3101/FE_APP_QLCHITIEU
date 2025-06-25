import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'transaction/add_transaction_page.dart';
import 'icon_color_utils.dart';
import 'transaction/update_transaction_page.dart';
import 'budget/add_budget_page.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../main.dart';
import 'utils/auth_utils.dart' as auth_utils;
import 'category/manage_categories_page.dart';
import 'package:intl/intl.dart';
import 'chart/chart_page.dart';
import 'services/notification_service.dart';
import '../sample_expense_list/list_page.dart';
import 'package:user_app_qlchitieu/services/export_service.dart';

class HomePage extends StatefulWidget {
  final String token;
  final dynamic idnguodung;
  const HomePage({super.key, required this.token, required this.idnguodung});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  bool isLoading = true;
  List<dynamic> transactions = [];
  Map<String, List<dynamic>> _groupedTransactions = {};
  Map<String, Map<String, int>> _dailyTotals = {};
  int totalIncome = 0;
  int totalExpense = 0;
  int balance = 0; //số dư
  Map<String, dynamic>? _budgetData; //tạo biên map có thể null
  List<dynamic> _defaultCategories = [];
  List<dynamic> _userCategories = [];
  List<dynamic> _colors = [];
  List<dynamic> _icons = [];
  List<dynamic> _allCategories = []; // Combined default and user categories
  int _selectedIndex = 0; // New state variable for bottom navigation bar
  late PageController _pageController; // New page controller
  final formatter = NumberFormat('#,###', 'vi_VN');
  DateTime _selectedDate = DateTime.now();

  // State for monthly expense
  double _monthlyExpense = 0.0; //chi phí hàng tháng
  bool _isBalanceLoading = true; //cờ số dư

  //tạo globalkey truy cập tới chartpage và trạng thái state
  final GlobalKey<ChartPageState> _chartPageKey = GlobalKey<ChartPageState>();

  // Thêm GlobalKey cho SampleExpenseListPage để gọi hàm reload
  final GlobalKey<SampleExpenseListPageState> _sampleExpenseListPageKey = GlobalKey<SampleExpenseListPageState>();

  @override
  void initState() {
    super.initState();
    _pageController = PageController(); // Initialize page controller
    _autoDeductMonthlyExpense(); // Thêm dòng này để tự động trừ khi sang tháng mới
    _loadData(); // Load all necessary data
  }

  @override
  void dispose() {
    _pageController.dispose(); // Dispose page controller
    super.dispose();
  }

  Future<void> _loadData() async {
    try {
      setState(() { isLoading = true; });
      print('Loading data for month: ${_selectedDate.month}/${_selectedDate.year}');
      await Future.wait([
        fetchTransactionsForMonth(),
        _fetchDefaultCategories(),
        _fetchUserCategories(),
        _fetchColors(),
        _fetchIcons(),
        fetchMonthlyExpense(), // vẫn gọi để hiển thị riêng nếu cần
        _fetchBudget(),
      ]);
      print('All data fetched successfully. Combining categories...');
      _combineCategories(); //kết hợp danh mục
      // Chỉ lấy tổng chi tiêu từ các giao dịch thực tế
      setState(() {
        balance = totalIncome - totalExpense; // Số dư = thu nhập - chi tiêu thực tế
        isLoading = false;
      });
      print('Data loading complete.');
    } catch (e, stack) {
      print('[ERROR] Lỗi khi load data: $e');
      print(stack);
      setState(() { isLoading = false; }); // Ensure loading indicator is dismissed even on error
    }
  }

  void _combineCategories() {
    List<dynamic> combined = [];
    // thêm tất cả phần tử của cả 2 vào combined
    combined.addAll(_defaultCategories);
    combined.addAll(_userCategories);


    _allCategories = combined.map((category) {
      final int? categoryIconId = int.tryParse(category['id_icon']?.toString() ?? '');
      final int? categoryColorId = int.tryParse(category['id_mau']?.toString() ?? '');

      // Find icon data
      final iconData = _icons.firstWhere((icon)
      => icon['id_icon'] == categoryIconId,
        orElse: () => {}, //nếu ko tìm thấy trả về rỗng
      );
      // Find color data
      final colorData = _colors.firstWhere((color)
      => color['id_mau'] == categoryColorId,
        orElse: () => {},
      );

      // Create a new category object with icon and color codes
      return {
        ...category, // Copy existing category data
        'ma_icon': iconData['ma_icon'], // Add ma_icon
        'ma_mau': colorData['ma_mau'], // Add ma_mau
      };
    }).toList();
  }

  Future<void> _fetchDefaultCategories() async {
    final url = Uri.parse('http://10.0.2.2:8081/QuanLyChiTieu/api/default-categories');
    try {
      final response = await http.get(url, headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer ${widget.token}',
      });

      if (await auth_utils.handleApiResponse(context, response, widget.token, widget.idnguodung)) return; // Corrected call

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        setState(() {
          _defaultCategories = (data as List).map((category)
          => {
            ...category,
            'id_danhmuc': int.tryParse(category['id_danhmuc']?.toString() ?? ''),
          }).toList();
        });
        print('Default categories fetched: ${_defaultCategories.length}');
      } else {
        print('Failed to load default categories: ${response.statusCode}');
      }
    } catch (e) {
      print('Error fetching default categories: $e');
    }
  }

  Future<void> _fetchUserCategories() async {
    final url = Uri.parse('http://10.0.2.2:8081/QuanLyChiTieu/api/categories/user/${widget.idnguodung}');
    try {
      final response = await http.get(url, headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer ${widget.token}',
      });

      if (await auth_utils.handleApiResponse(context, response, widget.token, widget.idnguodung)) return; // Corrected call

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        setState(() {
          _userCategories = (data as List).map((category) => {
            ...category,
            'id_danhmuc': int.tryParse(category['id_danhmuc']?.toString() ?? ''),
          }).toList();
        });
        print('User categories fetched: ${_userCategories.length}');
      } else {
        print('Failed to load user categories: ${response.statusCode}');
      }
    } catch (e) {
      print('Error fetching user categories: $e');
    }
  }

  Future<void> _fetchColors() async {
    final url = Uri.parse('http://10.0.2.2:8081/QuanLyChiTieu/api/colors');
    try {
      final response = await http.get(url, headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer ${widget.token}',
      });

      if (await auth_utils.handleApiResponse(context, response, widget.token, widget.idnguodung)) return; // Corrected call

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        setState(() {
          _colors = data is List ? data : [];
        });
      } else {
        print('Failed to load colors: ${response.statusCode}');
      }
    } catch (e) {
      print('Error fetching colors: $e');
    }
  }

  Future<void> _fetchIcons() async {
    final url = Uri.parse('http://10.0.2.2:8081/QuanLyChiTieu/api/icons');
    try {
      final response = await http.get(url, headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer ${widget.token}',
      });

      if (await auth_utils.handleApiResponse(context, response, widget.token, widget.idnguodung)) return; // Corrected call

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        setState(() {
          _icons = data is List ? data : [];
        });
        print('Icons fetched: ${_icons.length}');
      } else {
        print('Failed to load icons: ${response.statusCode}');
      }
    } catch (e) {
      print('Error fetching icons: $e');
    }
  }

  Future<void> fetchTransactionsForMonth() async {
    print('Fetching transactions for: ${_selectedDate.month}/${_selectedDate.year}');
    try {
      final url = Uri.parse('http://10.0.2.2:8081/QuanLyChiTieu/api/transactions/user/${widget.idnguodung}/month/${_selectedDate.month}/year/${_selectedDate.year}');
      final response = await http.get(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer ${widget.token}',
          //Yêu cầu trình duyệt hoặc proxy không lưu cache kết quả này.
          //no-cache : xác minh lại server trc khi dùng
          //no-store: ko được lưu cache ở bất cứ đâu
          //must-revalidate: nếu cache hết hạn phải hỏi lại server
          'Cache-Control': 'no-cache, no-store, must-revalidate',
          'Pragma': 'no-cache', //đảm bảo tương thích ngược với hệ thống cũ
          'Expires': '0', //Không được lưu cache, hết hạn ngay lập tức


        },
      );
      if (await auth_utils.handleApiResponse(context, response, widget.token, widget.idnguodung)) return;

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        List<dynamic> fetchedTransactions = [];
        if (data is List) {
          fetchedTransactions = data;
        } else if (data is Map && data['data'] is List) {
          fetchedTransactions = data['data'];
        }

        setState(() {
          transactions = fetchedTransactions;
          totalIncome = 0;
          totalExpense = 0;
          _groupedTransactions = {};
          _dailyTotals = {};

          for (var t in transactions) {
            double sotien = (t['so_tien'] as num?)?.toDouble() ?? 0.0;
            String loaiGiaoDichId = t['id_loai']?.toString() ?? '0';
            final String ngayString = t['ngay'] is String ? t['ngay'] : '01/01/1970';
            final transactionDate = _parseDateString(ngayString);
            final formattedDate = _formatDate(transactionDate);

            if (!_groupedTransactions.containsKey(formattedDate)) {
              _groupedTransactions[formattedDate] = [];
              _dailyTotals[formattedDate] = {'income': 0, 'expense': 0};
            }
            _groupedTransactions[formattedDate]!.add(t);

            if (loaiGiaoDichId == '1') {
              totalIncome += sotien.toInt();
              //!->khẳng định giá trị ko null
              _dailyTotals[formattedDate]!['income'] = _dailyTotals[formattedDate]!['income']! + sotien.toInt();
            } else if (loaiGiaoDichId == '2') {
              totalExpense += sotien.toInt();
              _dailyTotals[formattedDate]!['expense'] = _dailyTotals[formattedDate]!['expense']! + sotien.toInt();
            }
          }
          //chuyển các key trong map thành list
          final sortedDates = _groupedTransactions.keys.toList()
            ..sort((a, b) {
              final dateA = _parseFormattedDateString(a);
              final dateB = _parseFormattedDateString(b);
              return dateB.compareTo(dateA); // ngày mới nhất trước
            });
          //tạo biến lưu các giao dịch theo từng ngày
          final sortedGroupedTransactions = <String, List<dynamic>>{};
          //lưu tổng tiền chi tiêu, thu nhập... theo ngày
          final sortedDailyTotals = <String, Map<String, int>>{};
          for (var date in sortedDates) {
            sortedGroupedTransactions[date] = _groupedTransactions[date]!;
            sortedDailyTotals[date] = _dailyTotals[date]!;
          }
          _groupedTransactions = sortedGroupedTransactions;
          _dailyTotals = sortedDailyTotals;


        });

        print('Transactions fetched and processed successfully for the month.');
      } else {
        print('Failed to load transactions for month: ${response.statusCode}');
      }
    } catch (e) {
      print('Error fetching transactions for month: $e');
    }
  }
  //
  // Future<void> fetchTransactions() async {
  //   setState(() {
  //     isLoading = true;
  //   });
  //   print('Fetching transactions...');
  //   try {
  //     final url = Uri.parse('http://10.0.2.2:8081/QuanLyChiTieu/api/transactions/user/${widget.idnguodung}/all');
  //     final response = await http.get(
  //       url,
  //       headers: {
  //         'Content-Type': 'application/json',
  //         'Authorization': 'Bearer ${widget.token}',
  //         // Headers để chống cache
  //         'Cache-Control': 'no-cache, no-store, must-revalidate',
  //         'Pragma': 'no-cache',
  //         'Expires': '0',
  //       },
  //     );
  //     if (await auth_utils.handleApiResponse(context, response, widget.token, widget.idnguodung)) return; // Corrected call
  //     if (response.statusCode == 200) {
  //       final data = jsonDecode(response.body);
  //       List<dynamic> fetchedTransactions = [];
  //       if (data is List) {
  //         fetchedTransactions = data;
  //       } else if (data is Map && data['data'] is List) {
  //         fetchedTransactions = data['data'];
  //       }
  //       setState(() {
  //         transactions = fetchedTransactions;
  //         totalIncome = 0;
  //         totalExpense = 0;
  //         _groupedTransactions = {};
  //         _dailyTotals = {};
  //
  //         for (var t in transactions) {
  //           print('Processing transaction: $t');
  //           double sotien = (t['so_tien'] as num?)?.toDouble() ?? 0.0;
  //           String loaiGiaoDichId = t['id_loai']?.toString() ?? '0';
  //           // Parse date string from 'DD/MM/YYYY' to DateTime object
  //           final String ngayString = t['ngay'] is String ? t['ngay'] : '01/01/1970'; // Default date if null or not string
  //           final transactionDate = _parseDateString(ngayString);
  //           final formattedDate = _formatDate(transactionDate);
  //
  //           // kiểm tra có khóa formatt... ko
  //           if (!_groupedTransactions.containsKey(formattedDate)) {
  //             _groupedTransactions[formattedDate] = [];
  //             _dailyTotals[formattedDate] = {'income': 0, 'expense': 0};
  //           }
  //           _groupedTransactions[formattedDate]!.add(t);
  //
  //           // Calculate daily totals and overall totals
  //           if (loaiGiaoDichId == '1') { // Assuming '1' is Income
  //             totalIncome += sotien.toInt();
  //             //lấy thu nhập của ngày đảm bảo ngày ko null + totien kieu int
  //             _dailyTotals[formattedDate]!['income'] = _dailyTotals[formattedDate]!['income']! + sotien.toInt();
  //           } else if (loaiGiaoDichId == '2') { // Assuming '2' is Expense
  //             totalExpense += sotien.toInt(); // Sum expense amount as positive
  //             _dailyTotals[formattedDate]!['expense'] = _dailyTotals[formattedDate]!['expense']! + sotien.toInt();
  //           }
  //
  //           // Find the category for this transaction using id_danhmuc
  //           final category = _allCategories.firstWhere((cat)
  //           {
  //               final int? categoryId = int.tryParse(cat['id_danhmuc']?.toString() ?? '');
  //               final int? transactionCategoryId = int.tryParse(t['id_danhmuc']?.toString() ?? '');
  //               return categoryId == transactionCategoryId;
  //             },
  //             orElse: () => {}, // Return an empty map if category not found to prevent TypeError
  //           );
  //           print('Category found: $category');
  //         }
  //         // print('Grouped transactions after loop: $_groupedTransactions'); // Commented out to avoid clutter
  //         // print('Daily totals after loop: $_dailyTotals'); // Commented out to avoid clutter
  //
  //         // Sort dates in descending order
  //         final sortedDates = _groupedTransactions.keys.toList()..sort((a, b) {
  //             final dateA = _parseFormattedDateString(a);
  //             final dateB = _parseFormattedDateString(b);
  //             return dateB.compareTo(dateA);
  //           });
  //
  //
  //         //sắp xếp lại thứ tự các giao dịch và tổng thu/chi theo ngày
  //         // tạo map mới
  //         final sortedGroupedTransactions = <String, List<dynamic>>{};
  //         final sortedDailyTotals = <String, Map<String, int>>{}; //map có value là kiểu map với key:value
  //         for (var date in sortedDates) {
  //           sortedGroupedTransactions[date] = _groupedTransactions[date]!;
  //           sortedDailyTotals[date] = _dailyTotals[date]!;
  //         }
  //         //lưu vào 2 biến
  //         _groupedTransactions = sortedGroupedTransactions;
  //         _dailyTotals = sortedDailyTotals;
  //
  //         // balance = totalIncome - totalExpense; // Removed: Balance calculation moved to _loadData
  //         isLoading = false;
  //         print('Transactions fetched and processed successfully.');
  //       });
  //     } else {
  //       print('Failed to load transactions: ${response.statusCode}');
  //       setState(() {
  //         isLoading = false;
  //       });
  //     }
  //   } catch (e) {
  //     print('Error fetching transactions: $e');
  //     setState(() {
  //       isLoading = false;
  //     });
  //   }
  // }

  Future<List<dynamic>> fetchTransactionsByMonth(int userId, int month, int year) async {
    final url = Uri.parse('http://10.0.2.2:8081/QuanLyChiTieu/api/transactions/user/$userId/month/$month/year/$year');
    final response = await http.get(
      url,
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer ${widget.token}',
      },
    );
    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      if (data is List) return data;
      if (data is Map && data['data'] is List) return data['data'];
      return [];
    } else {
      throw Exception('Lỗi lấy giao dịch');
    }
  }


  //lấy về chi tiêu hàng tháng
  Future<double> fetchTongChiTieuHangThang(int userId, int month, int year) async {
    final url = Uri.parse('http://10.0.2.2:8081/QuanLyChiTieu/api/chi-tieu-hang-thang/user/$userId/month/$month/year/$year');
    final response = await http.get(url, headers: {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer ${widget.token}',
    });
    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);

      if (data is Map && data.containsKey('amount') && data['amount'] != null) {
        return double.tryParse(data['amount'].toString()) ?? 0.0;
      }
      // Handle other cases if necessary, otherwise return 0
      return 0.0;
    } else {
      throw Exception('Lỗi lấy chi tiêu hàng tháng');
    }
  }

  //gọi hàm trên và cập nhật UI
  Future<void> fetchMonthlyExpense() async {
    if (!mounted) return; //!mounted có nghĩa là widget đã bị hủy
    setState(() {
      _isBalanceLoading = true;
    });
    try {
      final userId = int.tryParse(widget.idnguodung.toString());
      if (userId == null) throw Exception("User ID không hợp lệ");

      final expense = await fetchTongChiTieuHangThang(userId, _selectedDate.month, _selectedDate.year);

      if (mounted) {
        setState(() {
          _monthlyExpense = expense;
          _isBalanceLoading = false;
        });
      }
    } catch (e) {
      print("Lỗi khi lấy chi tiêu hàng tháng: $e");
      if (mounted) {
        setState(() {
          _isBalanceLoading = false;
        });
      }
    }
  }

  Future<void> _selectMonth(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2000), //bắt đàu từ 1/1/2000
      lastDate: DateTime.now().add(const Duration(days: 365 * 5)), // ngày cuối cùng được chọn là 5 năm sau tính từ hôm nay
      locale: const Locale('vi', 'VN'),//Thiết lập ngôn ngữ và quốc gia
      helpText: 'CHỌN THÁNG',
      //initialDatePickerMode xác định chế độ hiển thị ban đầu khi mở hộp thoại chọn ngày.
      //DatePickerMode.year có nghĩa là hiển thị màn hình chọn năm ngay từ đầu (thay vì chọn ngày luôn).
      initialDatePickerMode: DatePickerMode.year,
    );

    if (picked != null && (picked.month != _selectedDate.month || picked.year != _selectedDate.year)) {
      setState(() {
        //Tạo một DateTime mới từ năm và tháng của picked, nhưng gán ngày là 1
        _selectedDate = DateTime(picked.year, picked.month, 1);
      });
      _loadData(); // Reload data for the new month
    }
  }

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now(); //thời gian hiện tại của hthong
    const double blueHeaderHeight = 220.0; //chiều cao cố định
    const double overlapAmount = 20.0;
    final sortedDates = _groupedTransactions.keys.toList()
    ..sort((a, b) {
      final dateA = _parseFormattedDateString(a);
      final dateB = _parseFormattedDateString(b);
      return dateB.compareTo(dateA); // ngày mới nhất trước
    });

    final List<Widget> _pages = [
      Stack(
        children: [
          // Blue Header Container
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            height: blueHeaderHeight,
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.only(top: 48, left: 20, right: 20, bottom: 20),
              decoration: const BoxDecoration(
                color: Color(0xFF2196F3),
                borderRadius: BorderRadius.only(
                  bottomLeft: Radius.circular(24),
                  bottomRight: Radius.circular(24),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: TextButton(
                          onPressed: () => _selectMonth(context),
                          style: TextButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
                            alignment: Alignment.centerLeft,
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.calendar_today, color: Colors.white, size: 18),
                              const SizedBox(width: 8),
                              Text(
                                  '${_selectedDate.year}-${_selectedDate.month.toString().padLeft(2, '0')} Số dư',
                                  style: const TextStyle(color: Colors.white, fontSize: 16)
                              ),
                              const Icon(Icons.arrow_drop_down, color: Colors.white),
                            ],
                          ),
                        ),
                      ),
                      PopupMenuButton<String>(
                        onSelected: (value) async {
                          if (value == 'logout') {
                            auth_utils.logoutUser(context, widget.token, widget.idnguodung);
                          }
                        },
                        itemBuilder: (BuildContext context) => <PopupMenuEntry<String>>[
                          const PopupMenuItem<String>(
                            value: 'logout',
                            child: Text('Đăng xuất'),
                          ),
                        ],
                        icon: Icon(Icons.more_horiz, color: Colors.white.withOpacity(0.8)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  // số dư
                  buildThuNhapWidget(),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      const Text('Chi tiêu: ', style: TextStyle(color: Colors.white70, fontSize: 16)),
                      Text('${formatter.format(totalExpense)}', style: const TextStyle(color: Colors.white, fontSize: 16)),
                      const SizedBox(width: 16),
                      const Text('Thu nhập: ', style: TextStyle(color: Colors.white70, fontSize: 16)),
                      Text('+${formatter.format(totalIncome)}', style: const TextStyle(color: Colors.white, fontSize: 16)),
                    ],
                  ),
                ],
              ),
            ),
          ),

          // Phần còn lại: ngân sách, export, danh sách giao dịch
          Positioned(
            top: blueHeaderHeight - overlapAmount,
            left: 0,
            right: 0,
            bottom: 0,
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Ngân sách
                  Container(
                    margin: const EdgeInsets.symmetric(horizontal: 0),
                    padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.03),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        //giá trị map ko null, giá trị key ko null, ép kiểu kiểm tra >0
                        if (_budgetData != null && _budgetData!['ngansach'] != null && (_budgetData!['ngansach'] as num) > 0)
                          ...[ //trải toàn bộ ptu vào list hiện tại
                            Builder(builder: (context) {
                              final totalBudget = (_budgetData!['ngansach'] as num).toDouble();
                              double spentAmount = 0;
                              _groupedTransactions.forEach((date, transList) {
                                for (var t in transList) {
                                  if (t['id_loai'].toString() == '2' && t['id_danhmuc'].toString() != '55') {
                                    spentAmount += (t['so_tien'] as num?)?.toDouble() ?? 0.0;
                                  }
                                }
                              });
                              final remainingAmount = totalBudget - spentAmount;
                              final progress = (totalBudget > 0) ? (spentAmount / totalBudget).clamp(0.0, 1.0) : 0.0;
                              return Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      const Text('Ngân sách tháng', style: TextStyle(fontSize: 16, color: Colors.black54)),
                                      Text(
                                        'Còn lại: ${formatter.format(remainingAmount)} đ',
                                        style: TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.bold,
                                          color: remainingAmount < 0 ? Colors.redAccent : Colors.black,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 8),
                                  ClipRRect(
                                    borderRadius: const BorderRadius.all(Radius.circular(10)),
                                    child: LinearProgressIndicator(
                                      value: progress,
                                      minHeight: 12,
                                      backgroundColor: Colors.grey.shade300,
                                      valueColor: AlwaysStoppedAnimation<Color>(
                                        progress >= 0.8
                                            ? Colors.redAccent
                                            : (progress >= 0.5
                                                ? Colors.orangeAccent
                                                : (progress >= 0.2
                                                    ? Colors.green
                                                    : Colors.blue)),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text(
                                        'Đã chi: ${formatter.format(spentAmount)} đ',
                                        style: const TextStyle(fontSize: 16, color: Colors.black, fontWeight: FontWeight.bold),
                                      ),
                                      Text(
                                        '/ ${formatter.format(totalBudget)} đ',
                                        style: const TextStyle(fontSize: 16, color: Colors.black, fontWeight: FontWeight.bold),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 8),
                                ],
                              );
                            })
                          ]
                        else
                          ...[
                            const Center(
                              child: Text(
                                'Cài đặt ngân sách',
                                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                              ),
                            ),
                            const SizedBox(height: 8),
                            Container(
                              width: double.infinity,
                              margin: const EdgeInsets.symmetric(horizontal: 0.5),
                              height: 6,
                              decoration: BoxDecoration(
                                color: const Color(0xFF64B5F6),
                                borderRadius: BorderRadius.circular(5),
                              ),
                            ),
                          ],
                      ],
                    ),
                  ),
                  // Nút export
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                    child: ElevatedButton.icon(
                      icon: Icon(Icons.file_upload),
                      label: Text('Export chi tiêu mẫu'),
                      style: ElevatedButton.styleFrom(
                        minimumSize: Size(double.infinity, 44),
                        backgroundColor: Colors.teal,
                        foregroundColor: Colors.white,
                        textStyle: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      onPressed: () => showExportDialog(
                        context,
                        idNguoiDung: int.tryParse(widget.idnguodung.toString()),
                        token: widget.token,
                        thang: _selectedDate.month,
                      ),
                    ),
                  ),
                  // Danh sách giao dịch
                  Container(
                    margin: const EdgeInsets.symmetric(horizontal: 0, vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.03),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: ListView(
                      shrinkWrap: true,
                      physics: NeverScrollableScrollPhysics(),
                      padding: EdgeInsets.zero,
                      children: [
                        ..._groupedTransactions.keys.map((date) {
                          final dailyIncome = _dailyTotals[date]!['income']!;
                          final dailyExpense = _dailyTotals[date]!['expense']!;
                          return Column(
                            children: [
                              Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                child: Row(
                                  children: [
                                    Expanded(
                                      child: Text(date, style: const TextStyle(fontSize: 14, color: Colors.black54)),
                                    ),
                                    const Spacer(),
                                    Expanded(
                                      child: Text('Chi tiêu:${formatter.format(dailyExpense)}', style: const TextStyle(fontSize: 14, color: Colors.black54)),
                                    ),
                                    const SizedBox(width: 8),
                                    Text('Thu nhập:+${formatter.format(dailyIncome)}', style: const TextStyle(fontSize: 14, color: Colors.blue)),
                                  ],
                                ),
                              ),
                              ..._groupedTransactions[date]!.map((t) {
                                final category = _allCategories.firstWhere(
                                  (cat) {
                                    final int? categoryId = int.tryParse(cat['id_danhmuc']?.toString() ?? '');
                                    final int? transactionCategoryId = int.tryParse(t['id_danhmuc']?.toString() ?? '');
                                    return categoryId == transactionCategoryId;
                                  },
                                  orElse: () => {},
                                );
                                final iconCode = category?['ma_icon'] ?? 'f555';
                                final colorCode = category?['ma_mau'] ?? '#2196F3';
                                final categoryName = category?['ten_danh_muc'] ?? 'Không rõ';
                                double amountValue = (t['so_tien'] as num?)?.toDouble() ?? 0.0;
                                final amountText = ((t['id_loai'].toString() == '1') ? '+' : '-') + formatter.format(amountValue);
                                final amountColor = (t['id_loai'].toString() == '1') ? Colors.blue : Colors.black;
                                final isMonthlyAuto = t['id_danhmuc'].toString() == '55' && t['ghi_chu'] == 'Tự động trừ chi tiêu hàng tháng';
                                return GestureDetector(
                                  onTap: isMonthlyAuto ? null : () async {
                                    final result = await Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (context) => UpdateTransactionPage(
                                          token: widget.token,
                                          idnguodung: widget.idnguodung,
                                          transactionData: t,
                                        ),
                                      ),
                                    );
                                    print('[DEBUG] Kết quả cập nhật giao dịch: $result');
                                    if (result == true) {
                                      print('[DEBUG] Gọi _loadData() sau khi cập nhật');
                                      _loadData();
                                    }
                                  },
                                  child: Opacity(
                                    opacity: isMonthlyAuto ? 0.6 : 1.0,
                                    child: _TransactionItem(
                                      icon: getFaIconDataFromUnicode(iconCode),
                                      iconColor: hexToColor(colorCode),
                                      title: categoryName,
                                      subtitle: t['ghi_chu'] ?? '',
                                      amount: amountText,
                                      amountColor: amountColor,
                                      transactionData: t,
                                    ),
                                  ),
                                );
                              }).toList(),
                              const Divider(height: 1),
                            ],
                          );
                        }).toList(),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
      ManageCategoriesPage(
        token: widget.token,
        idnguodung: widget.idnguodung,
        onBackButtonPressed: (result) {
          setState(() {
            _selectedIndex = 0;
          });
          _pageController.jumpToPage(0);
          if (result == true) {
            _loadData();
          }
        },
      ),
      ChartPage(
        key: _chartPageKey,
        token: widget.token,
        idnguoidung: widget.idnguodung,
        onBack: () => _pageController.jumpToPage(0),
      ),
      SampleExpenseListPage(
        key: _sampleExpenseListPageKey,
        token: widget.token,
        idnguoidung: widget.idnguodung,
        onBack: ()=> _pageController.jumpToPage(0),
      ), 
    ];


    //menu dưới cùng
    return Scaffold(
      backgroundColor: const Color(0xFFF5F6FA),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : PageView( // Use PageView for page switching
        controller: _pageController,
        onPageChanged: (index) {
          setState(() {
            _selectedIndex = index;
          });
          // Khi chuyển đến trang Chi tiêu mẫu, tải lại dữ liệu
          if (index == 3) {
            print("[DEBUG_HOME] Chuyển đến trang chi tiêu mẫu, gọi reloadData()...");
            _sampleExpenseListPageKey.currentState?.reloadData();
          }
        },
        children: _pages,
      ),
      bottomNavigationBar: _selectedIndex == 0
          ? ClipRRect(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20.0)), // Bo tròn góc trên
        child: BottomAppBar(
          shape: const CircularNotchedRectangle(), // Giữ hình dạng khuyết
          clipBehavior: Clip.antiAlias,
          color: Colors.white,
          notchMargin: 6.0, // Điều chỉnh khoảng cách của nút nổi
          elevation: 2.0, // Độ đổ bóng cho thanh điều hướng
          child: Row(
            mainAxisAlignment: MainAxisAlignment.start, // Nhóm các biểu tượng về bên trái
            children: <Widget>[
              IconButton(
                icon: const Icon(Icons.receipt_long),
                color: _selectedIndex == 0 ? Colors.blue : Colors.grey,
                onPressed: () {
                  setState(() {
                    _selectedIndex = 0;
                  });
                  _pageController.jumpToPage(0);
                  _loadData();
                },
              ),
              IconButton(
                icon: const Icon(Icons.grid_view),
                color: _selectedIndex == 1 ? Colors.blue : Colors.grey,
                onPressed: () {
                  setState(() {
                    _selectedIndex = 1;
                  });
                  _pageController.jumpToPage(1);
                },
              ),
              IconButton( //click vào icon biểu đồ để chuyển trang
                icon: const Icon(Icons.pie_chart),
                //nếu index==2 thì trả màu xanh dương ko thì màu xanh lá
                color: _selectedIndex == 2 ? Colors.blue : Colors.grey,
                onPressed: () {//xử lý nhấn vào icon
                  setState(() { //cập nhật trang thái của index = 2
                    _selectedIndex = 2;
                  });
                  _pageController.jumpToPage(2);//điểu khiển trang nhảy sang số 2
                },
              ),
              IconButton(
                icon: const Icon(Icons.list),
                color: _selectedIndex == 3 ? Colors.blue : Colors.grey,
                onPressed: () {
                  setState(() {
                    _selectedIndex = 3;
                  });
                  _pageController.jumpToPage(3);
                },
              ),
              const Spacer(), // Đẩy khoảng trống và nút về bên phải
              const SizedBox(width: 40), // Khoảng trống cho FloatingActionButton
            ],
          ),
        ),
      )
          : null,
      floatingActionButton: _selectedIndex == 0
          ? FloatingActionButton(
        onPressed: () async {
          // Lấy ngân sách và tổng chi tiêu hiện tại
          double totalBudget = (_budgetData != null && _budgetData!['ngansach'] != null)
              ? (_budgetData!['ngansach'] as num).toDouble()
              : 0.0;
          double totalExpenseValue = totalExpense.toDouble();
          final result = await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => AddTransactionPage(
                token: widget.token,
                idnguodung: widget.idnguodung,
              ),
              settings: RouteSettings(
                arguments: {
                  'totalBudget': totalBudget,
                  'totalExpense': totalExpenseValue,
                },
              ),
            ),
          );
          if (result is Map && result['shouldNotify'] == true) {
            double oldPercent = result['oldPercent'] ?? 0;
            double newPercent = result['newPercent'] ?? 0;
            double soTienGiaoDichMoi = 0;
            if (result['newPercent'] != null && result['oldPercent'] != null && totalBudget > 0) {
              soTienGiaoDichMoi = ((newPercent - oldPercent) * totalBudget) / 100;
            }
            // Tính lại số tiền còn lại sau khi thêm giao dịch (cộng thêm số tiền vừa thêm)
            double spentAmount = 0;
            _groupedTransactions.forEach((date, transList) {
              for (var t in transList) {
                if (t['id_loai'].toString() == '2' && t['id_danhmuc'].toString() != '55') {
                  spentAmount += (t['so_tien'] as num?)?.toDouble() ?? 0.0;
                }
              }
            });
            spentAmount += soTienGiaoDichMoi;
            double remainingAmount = totalBudget - spentAmount;
            checkAndNotifyBudget(oldPercent, newPercent, remainingAmount: remainingAmount);
            _loadData();
          } else if (result == true) {
            _loadData();
          }
        },
        backgroundColor: const Color(0xFF2196F3),
        elevation: 8.0,
        shape: const CircleBorder(), // nút thêm hình tròn
        child: const Icon(Icons.add, size: 32, color: Colors.white),
      )
          : null,
      floatingActionButtonLocation: FloatingActionButtonLocation.endDocked, // Đặt nút ở ngoài cùng bên phải
    );
  }


  //Hàm định dạng một đối tượng DateTime thành chuỗi kiểu "ngày thg tháng, năm"
  //Sau khi có đối tượng DateTime, nhóm các giao dịch trong cùng một ngày lại với nhau
  // hiển thị một tiêu đề  cho mỗi nhóm (ví dụ: "25 thg 5, 2025").
  String _formatDate(DateTime date) {
    final day = date.day;
    final month = date.month;
    final year = date.year;
    return '$day thg $month, $year';
  }


  //Hàm chuyển đổi một chuỗi định dạng ngày kiểu "DD/MM/YYYY" thành đối tượng DateTime
  //Dữ liệu ngày tháng từ API của bạn có dạng chuỗi String kiểu "DD/MM/YYYY" (ví dụ: "25/05/2025").
  // Để máy tính có thể hiểu và so sánh được,cần chuyển nó thành đối tượng DateTime.
  DateTime _parseDateString(String dateString) {
    final parts = dateString.split('/'); // dateString is like "DD/MM/YYYY"
    final day = int.parse(parts[0]);
    final month = int.parse(parts[1]);
    final year = int.parse(parts[2]);
    return DateTime(year, month, day);
  }

  //hàm chuyển chuỗi ngày dạng DD thg MM, YYYY thành DateTime
  //Để sắp xếp đúng theo thứ tự thời gian , phải chuyển các chuỗi này ngược lại thành đối tượng DateTime để so sánh.
  DateTime _parseFormattedDateString(String formattedDateString) {
    final parts = formattedDateString.split(' '); //tách thành "DD", "thg", "MM,", "YYYY"
    final day = int.parse(parts[0]);
    final month = int.parse(parts[2].replaceAll(',', '')); // Loại bỏ dấu phẩy nếu có
    final year = int.parse(parts[3]);
    return DateTime(year, month, day);
  }

  // double tinhTongThuNhap(List<dynamic> transactions) {
  //
  //   return transactions
  //       .where((tran) => tran['id_loai'].toString() == '1')
  //       .fold(0.0, (sum, tran) {
  //         final soTien = double.tryParse(tran['so_tien'].toString()) ?? 0.0;
  //         return sum + soTien;
  //       });
  // }

  Widget buildThuNhapWidget() {
    if (_isBalanceLoading) {
      // Use a smaller, white indicator that fits the header
      return const SizedBox(
        width: 24,
        height: 24,
        child: CircularProgressIndicator(
          strokeWidth: 2.5,
          valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
        ),
      );
    }
    //tạo một định dạng số có dấu phân cách hàng nghìn theo chuẩn Việt Nam
    final formatter = NumberFormat('#,###', 'vi_VN');
    // Balance = Total Income (ad-hoc) - Monthly Expense - Ad-hoc Expense
    final soDuHienTai = totalIncome - totalExpense;

    return Text(
      formatter.format(soDuHienTai.toInt()),
      style: TextStyle(
        color: soDuHienTai < 0 ? Colors.red : Colors.white,
        fontSize: 32,
        fontWeight: FontWeight.bold,
      ),
    );
  }

// void _navigateToUpdateTransaction(dynamic transactionData) async {
//   final result = await Navigator.push(
//     context,
//     MaterialPageRoute(
//       builder: (context) => UpdateTransactionPage(
//         token: widget.token,
//         idnguodung: widget.idnguodung,
//         transactionData: transactionData,
//       ),
//     ),
//   );
//
//   if (result == true) {
//     _loadData();
//   }
// }

// String _getCategoryName(int? categoryId) {
//   if (categoryId == null) {
//     return 'Không rõ';
//   }
//   try {
//     final category = _allCategories.firstWhere(
//       (cat) => (cat['id_danhmuc'] as int?) == categoryId,
//     );
//     return category['ten_danh_muc'] as String? ?? 'Không rõ';
//   } catch (e) {
//     return 'Không rõ';
//   }
// }
//==========NGÂN SÁCH====//
Future<void> _fetchBudget() async {
    final now = DateTime.now();
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
        final responseBody = utf8.decode(response.bodyBytes);
        final data = jsonDecode(responseBody);
        if (mounted) {
          setState(() {
            _budgetData = data;
          });
        }
      } else {
        if (mounted) {
          setState(() {
            _budgetData = null;
          });
        }
      }
    } catch (e) {
      print('Error fetching budget in home_page: $e');
      if (mounted) {
        setState(() {
          _budgetData = null;
        });
      }
    }
  }

  //hàm kiem tra và thông báo
  void checkAndNotifyBudget(double oldPercent, double newPercent, {double? remainingAmount}) {
    // Gửi thông báo mỗi khi có sự biến đổi ngân sách
    if (remainingAmount != null) {
      NotificationService().showNotification(
        1,
        "Ngân sách đã thay đổi!",
        "Số tiền còn lại: ${NumberFormat('#,###', 'vi_VN').format(remainingAmount)} đ",
      );

    }
    // Nếu vẫn muốn giữ logic cũ thì có thể giữ lại các mốc dưới đây:
    //old <20<=new
    if (oldPercent < 20 && newPercent >= 20) {
      NotificationService().showNotification(2, "Bạn đã chi tiêu 20% ngân sách!", "Bạn đã chi tiêu 20% ngân sách!");
    }//old<50<=50
    if (oldPercent < 50 && newPercent >= 50) {
      NotificationService().showNotification(3, "Bạn đã chi tiêu 50% ngân sách!", "Bạn đã chi tiêu 50% ngân sách!");
    }//old<80<=80
    if (oldPercent < 80 && newPercent >= 80) {
      NotificationService().showNotification(4, "Ngân sách sắp cạn! Bạn đã chi tiêu 80% ngân sách!", "Ngân sách sắp cạn! Bạn đã chi tiêu 80% ngân sách!");
    }//old<100<=100
    if (oldPercent < 100 && newPercent >= 100) {
      NotificationService().showNotification(5, "Bạn đã dùng hết ngân sách!", "Bạn đã dùng hết ngân sách tháng này!");
    }
  }


  //----------XỬ LÝ TỰ ĐỘNG THÊM GIAO DỊCH CHI PHÍ HÀNG THÁNG VÀO ĐÀU THÁNG-----------//
  //hàm tự động trừ chi phí hàng tháng vào đầu mỗi tháng
  Future<void> _autoDeductMonthlyExpense() async {
    final now = DateTime.now();//thơi gian hiện tại
    final userId = int.tryParse(widget.idnguodung.toString());
    if (userId == null) return;

    // Ngày 1 của tháng hiện tại
    final firstDayOfMonth = DateTime(now.year, now.month, 1);

    // Lấy danh sách giao dịch tháng này
    final transactions = await fetchTransactionsByMonth(userId, now.month, now.year);
    // Tìm trong danh sách giao dịch xem đã có giao dịch chi tiêu hang tháng chưa
    final autoTransaction = transactions.firstWhere(
      (t) => t['id_danhmuc']?.toString() == '55' && t['ghi_chu'] == 'Tự động trừ chi tiêu hàng tháng',
      orElse: () => null,
    );

    final amount = await fetchTongChiTieuHangThang(userId, now.month, now.year); //tổng chi hàng tháng
    if (amount > 0) {
      //nếu đã có giao dịch tự động thêm
      if (autoTransaction != null) {
        // Đã có giao dịch tự động, cập nhật số tiền nếu khác
        if ((autoTransaction['so_tien'] as num?)?.toDouble() != amount) {
          await _updateMonthlyExpenseTransaction(autoTransaction['id_giaodich'], amount);
        }
      } else {
        // Chưa có, tạo mới
        await _createMonthlyExpenseTransaction(userId, amount, firstDayOfMonth);
      }
    }
  }

  //cập nhật chi tiêu hàng tháng
  Future<void> _updateMonthlyExpenseTransaction(dynamic transactionId, double amount) async {
    final url = Uri.parse('http://10.0.2.2:8081/QuanLyChiTieu/api/transactions/$transactionId');
    final body = jsonEncode({
      'so_tien': amount,
    });
    final response = await http.put(url, headers: {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer ${widget.token}',
    }, body: body);
    print('Update response: ${response.statusCode} - ${response.body}');
  }
//tạo chi tiêu hàng tháng
  Future<void> _createMonthlyExpenseTransaction(int userId, double amount, DateTime date) async {
    // Gọi API tạo giao dịch mới
    final url = Uri.parse('http://10.0.2.2:8081/QuanLyChiTieu/api/transactions');
    final body = jsonEncode({
      'id_nguoidung': userId,
      'id_danhmuc': 55, // ID danh mục mặc định cho chi tiêu hàng tháng
      'id_loai': 2, // 2 = chi tiêu
      'id_tennhom': 1, // <-- BẮT BUỘC PHẢI LÀ 1 (hàng tháng)
      'so_tien': amount,
      'ngay': DateFormat('dd/MM/yyyy').format(date),
      'ghi_chu': 'Tự động trừ chi tiêu hàng tháng',
    });
    await http.post(url, headers: {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer ${widget.token}',
    }, body: body);
  }
}

class _TransactionItem extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String title;
  final String subtitle;
  final String amount;
  final Color amountColor;
  final dynamic transactionData;

  const _TransactionItem({
    //bắt buộc truyền các tham số này
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.subtitle,
    required this.amount,
    required this.amountColor,
    required this.transactionData,
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
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  subtitle,
                  style: const TextStyle(color: Colors.black54, fontSize: 13),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          Text(
            amount,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 16,
              color: amountColor,
            ),
          ),
        ],
      ),
    );
  }
} 