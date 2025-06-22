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
  List<dynamic> _defaultCategories = [];
  List<dynamic> _userCategories = [];
  List<dynamic> _colors = [];
  List<dynamic> _icons = [];
  List<dynamic> _allCategories = []; // Combined default and user categories
  int _selectedIndex = 0; // New state variable for bottom navigation bar
  late PageController _pageController; // New page controller
  final formatter = NumberFormat('#,###', 'vi_VN');

  // State for monthly expense
  double _monthlyExpense = 0.0; //chi phí hàng tháng
  bool _isBalanceLoading = true; //cờ số dư

  //tạo globalkey truy cập tới chartpage và trạng thái state
  final GlobalKey<ChartPageState> _chartPageKey = GlobalKey<ChartPageState>();

  @override
  void initState() {
    super.initState();
    _pageController = PageController(); // Initialize page controller
    _loadData(); // Load all necessary data
  }

  @override
  void dispose() {
    _pageController.dispose(); // Dispose page controller
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() { isLoading = true; });
    print('Loading data...');
    try {
      await Future.wait([
        fetchTransactions(),
        _fetchDefaultCategories(),
        _fetchUserCategories(),
        _fetchColors(),
        _fetchIcons(),
        fetchMonthlyExpense(), // Fetch monthly expense along with other data
      ]);
      print('All data fetched successfully. Combining categories...');
      _combineCategories(); //kết hợp danh mục
      // Calculate balance after all data is fetched and processed
      // tính số dư
      setState(() {
        balance = totalIncome - totalExpense; // số dư = tổng thu nhập - tổng chi tiêu
        isLoading = false;
      });
      print('Data loading complete.');
    } catch (e) {
      print('Error loading data: $e');
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

  Future<void> fetchTransactions() async {
    setState(() {
      isLoading = true;
    });
    print('Fetching transactions...');
    try {
      final url = Uri.parse('http://10.0.2.2:8081/QuanLyChiTieu/api/transactions/user/${widget.idnguodung}/all');
      final response = await http.get(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer ${widget.token}',
          // Headers để chống cache
          'Cache-Control': 'no-cache, no-store, must-revalidate',
          'Pragma': 'no-cache',
          'Expires': '0',
        },
      );
      if (await auth_utils.handleApiResponse(context, response, widget.token, widget.idnguodung)) return; // Corrected call
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
            print('Processing transaction: $t');
            double sotien = (t['so_tien'] as num?)?.toDouble() ?? 0.0;
            String loaiGiaoDichId = t['id_loai']?.toString() ?? '0';
            // Parse date string from 'DD/MM/YYYY' to DateTime object
            final String ngayString = t['ngay'] is String ? t['ngay'] : '01/01/1970'; // Default date if null or not string
            final transactionDate = _parseDateString(ngayString);
            final formattedDate = _formatDate(transactionDate);

            // kiểm tra có khóa formatt... ko
            if (!_groupedTransactions.containsKey(formattedDate)) {
              _groupedTransactions[formattedDate] = [];
              _dailyTotals[formattedDate] = {'income': 0, 'expense': 0};
            }
            _groupedTransactions[formattedDate]!.add(t);

            // Calculate daily totals and overall totals
            if (loaiGiaoDichId == '1') { // Assuming '1' is Income
              totalIncome += sotien.toInt();
              //lấy thu nhập của ngày đảm bảo ngày ko null + totien kieu int
              _dailyTotals[formattedDate]!['income'] = _dailyTotals[formattedDate]!['income']! + sotien.toInt();
            } else if (loaiGiaoDichId == '2') { // Assuming '2' is Expense
              totalExpense += sotien.toInt(); // Sum expense amount as positive
              _dailyTotals[formattedDate]!['expense'] = _dailyTotals[formattedDate]!['expense']! + sotien.toInt();
            }

            // Find the category for this transaction using id_danhmuc
            final category = _allCategories.firstWhere((cat)
            {
                final int? categoryId = int.tryParse(cat['id_danhmuc']?.toString() ?? '');
                final int? transactionCategoryId = int.tryParse(t['id_danhmuc']?.toString() ?? '');
                return categoryId == transactionCategoryId;
              },
              orElse: () => {}, // Return an empty map if category not found to prevent TypeError
            );
            print('Category found: $category');
          }
          // print('Grouped transactions after loop: $_groupedTransactions'); // Commented out to avoid clutter
          // print('Daily totals after loop: $_dailyTotals'); // Commented out to avoid clutter

          // Sort dates in descending order
          final sortedDates = _groupedTransactions.keys.toList()..sort((a, b) {
              final dateA = _parseFormattedDateString(a);
              final dateB = _parseFormattedDateString(b);
              return dateB.compareTo(dateA);
            });


          //sắp xếp lại thứ tự các giao dịch và tổng thu/chi theo ngày
          // tạo map mới
          final sortedGroupedTransactions = <String, List<dynamic>>{};
          final sortedDailyTotals = <String, Map<String, int>>{}; //map có value là kiểu map với key:value
          for (var date in sortedDates) {
            sortedGroupedTransactions[date] = _groupedTransactions[date]!;
            sortedDailyTotals[date] = _dailyTotals[date]!;
          }
          //lưu vào 2 biến
          _groupedTransactions = sortedGroupedTransactions;
          _dailyTotals = sortedDailyTotals;

          // balance = totalIncome - totalExpense; // Removed: Balance calculation moved to _loadData
          isLoading = false;
          print('Transactions fetched and processed successfully.');
        });
      } else {
        print('Failed to load transactions: ${response.statusCode}');
        setState(() {
          isLoading = false;
        });
      }
    } catch (e) {
      print('Error fetching transactions: $e');
      setState(() {
        isLoading = false;
      });
    }
  }

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

  //fetch dữ liệu
  Future<void> fetchMonthlyExpense() async {
    if (!mounted) return; //!mounted có nghĩa là widget đã bị hủy
    setState(() {
      _isBalanceLoading = true;
    });
    try {
      final userId = int.tryParse(widget.idnguodung.toString());
      if (userId == null) throw Exception("User ID không hợp lệ");

      final now = DateTime.now();
      final expense = await fetchTongChiTieuHangThang(userId, now.month, now.year);

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

  void _onItemTapped(int index) {
    _pageController.jumpToPage(index);
  }

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now(); //thời gian hiện tại của ht
    const double blueHeaderHeight = 220.0;
    const double overlapAmount = 20.0;
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
                      const Icon(Icons.calendar_today, color: Colors.white, size: 18),
                      const SizedBox(width: 8),
                      //YYYY-MM số dư
                      Text('${now.year}-${now.month.toString().padLeft(2, '0')} Số dư', style: const TextStyle(color: Colors.white, fontSize: 16)),
                      //tạo khoảng trống
                      const Spacer(),
                      PopupMenuButton<String>(
                        onSelected: (value) {
                          if (value == 'logout') {
                            auth_utils.logoutUser(context, widget.token, widget.idnguodung); // Corrected call
                          }
                        },
                        //menu
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
                      //$ dùng chèn giá trị biến/bthuc
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

          // Cài đặt ngân sách
          Positioned(
            top: blueHeaderHeight - overlapAmount,
            left: 0,
            right: 0,
            child: GestureDetector(
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => AddBudgetPage(
                      token: widget.token,
                      idnguodung: widget.idnguodung,
                    ),
                  ),
                );
              },
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 0), // Changed from 20 to 0
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
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    const Text(
                      'Cài đặt ngân sách',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
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
                ),
              ),
            ),
          ),
          
          //danh sách thông tin giao dịch
          Positioned(
            top: blueHeaderHeight + 22,
            left: 0,
            right: 0,
            bottom: 0,
            child: Container(
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

                          return GestureDetector(
                            onTap: () async {
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
                              if (result == true) {
                                _loadData();
                              }
                            },
                            child: _TransactionItem(
                              icon: getFaIconDataFromUnicode(iconCode),
                              iconColor: hexToColor(colorCode),
                              title: categoryName,
                              subtitle: t['ghi_chu'] ?? '',
                              amount: amountText,
                              amountColor: amountColor,
                              transactionData: t,
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
          ),
        ],
      ),
      // Page 2: ManageCategoriesPage
      ManageCategoriesPage(
        token: widget.token,
        idnguodung: widget.idnguodung,
        onBackButtonPressed: () {
          setState(() {
            _selectedIndex = 0; // Set index back to home page
          });
          _pageController.jumpToPage(0); // Navigate to home page
          fetchMonthlyExpense(); // Tải lại chi tiêu hàng tháng khi quay về
        },
      ),
      // back từ biểu đồ về home
      ChartPage(
        key: _chartPageKey,//truyền một key định danh widget
        token: widget.token, //truyền token
        idnguoidung: widget.idnguodung, //truyền id người dùng
        onBack: () => _pageController.jumpToPage(0), //callback về home
      ),

    ];

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
                final result = await Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => AddTransactionPage(
                      token: widget.token,
                      idnguodung: widget.idnguodung,
                    ),
                  ),
                );
                //load biểu đồ khi thêm mới giao dịch
                if (result == true) { //nếu kết quả là true
                  _loadData();//load dữ liệu
                  //nếu chartpage được hiển thị thì current sẽ chứa chartPState và load lại dữ liệu còn ko thì trả về null
                  _chartPageKey.currentState?.reloadData();
                  //biến globalkey
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
  String _formatDate(DateTime date) {
    final day = date.day;
    final month = date.month;
    final year = date.year;
    return '$day thg $month, $year';
  }


  //Hàm chuyển đổi một chuỗi định dạng ngày kiểu "DD/MM/YYYY" thành đối tượng DateTime
  DateTime _parseDateString(String dateString) {
    final parts = dateString.split('/'); // dateString is like "DD/MM/YYYY"
    final day = int.parse(parts[0]);
    final month = int.parse(parts[1]);
    final year = int.parse(parts[2]);
    return DateTime(year, month, day);
  }

  //hàm chuyển chuỗi ngày dạng DD thg MM, YYYY thành DateTime
  DateTime _parseFormattedDateString(String formattedDateString) {
    final parts = formattedDateString.split(' '); //tách thành "DD", "thg", "MM," , "YYYY"
    final day = int.parse(parts[0]);
    final month = int.parse(parts[2]); // "thg" là index 1
    final year = int.parse(parts[3]);
    return DateTime(year, month, day);
  }

  double tinhTongThuNhap(List<dynamic> transactions) {
    // This function is no longer needed for the main balance but might be used elsewhere.
    // Let's keep it for now but acknowledge it's not for the main balance display.
    return transactions
        .where((tran) => tran['id_loai'].toString() == '1')
        .fold(0.0, (sum, tran) {
          final soTien = double.tryParse(tran['so_tien'].toString()) ?? 0.0;
          return sum + soTien;
        });
  }

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
    final formatter = NumberFormat('#,###', 'vi_VN');
    // Balance = Total Income (ad-hoc) - Monthly Expense - Ad-hoc Expense
    final soDuHienTai = totalIncome - totalExpense - _monthlyExpense;

    return Text(
      formatter.format(soDuHienTai.toInt()),
      style: TextStyle(
        color: soDuHienTai < 0 ? Colors.red : Colors.white,
        fontSize: 32,
        fontWeight: FontWeight.bold,
      ),
    );
  }

  void _navigateToUpdateTransaction(dynamic transactionData) async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => UpdateTransactionPage(
          token: widget.token,
          idnguodung: widget.idnguodung,
          transactionData: transactionData,
        ),
      ),
    );

    if (result == true) {
      _loadData();
    }
  }

  String _getCategoryName(int? categoryId) {
    if (categoryId == null) {
      return 'Không rõ';
    }
    try {
      final category = _allCategories.firstWhere(
        (cat) => (cat['id_danhmuc'] as int?) == categoryId,
      );
      return category['ten_danh_muc'] as String? ?? 'Không rõ';
    } catch (e) {
      return 'Không rõ';
    }
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