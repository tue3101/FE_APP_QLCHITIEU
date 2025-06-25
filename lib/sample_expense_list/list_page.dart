import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:intl/intl.dart';
import '../utils/auth_utils.dart' as auth_utils;

class SampleExpenseListPage extends StatefulWidget {
  final String token;
  final dynamic idnguoidung;
  final VoidCallback onBack;


  const SampleExpenseListPage({
    super.key,
    required this.token,
    required this.idnguoidung,
    required this.onBack,

  });

  @override
  State<SampleExpenseListPage> createState() => SampleExpenseListPageState();
}

class SampleExpenseListPageState extends State<SampleExpenseListPage> with TickerProviderStateMixin {
  bool _isLoading = true;
  String? _error;

  List<dynamic> _salaryLevels = []; //mức lương
  List<dynamic> _sessions = []; //buổi
  List<dynamic> _expenseTypes = []; //loại chi tiêu
  List<dynamic> _suggestions = []; //gợi ý
  List<dynamic> _sampleExpenses = []; //chi tiêu mẫu

  dynamic _selectedSalaryLevelId; //chọn mức lương
  //sử dụng thư viện intl để định dạng số thành tiền tệ Việt Nam
  final _formatter = NumberFormat.currency(locale: 'vi_VN', symbol: '₫');

  // Thêm TabController
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _fetchInitialData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void reloadData() {
    if (mounted) {
      _fetchInitialData();
    }
  }

  Future<void> _fetchInitialData() async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      // Tải dữ liệu từ các endpoint khác nhau cùng lúc
      final results = await Future.wait([
        _fetchData('mucluong'), //truyền tên loại dữ liệu cần lấy (tham số)
        _fetchData('buoi'),
        _fetchData('loaichitieu'),
        _fetchData('goiy'),
        // API mới cho chi tiêu mặc định
        _fetchData('chitieumau/default'),
        // API mới cho chi tiêu cá nhân
        _fetchData('chitieumau/user/${widget.idnguoidung}'),
      ]);

      if (mounted) {
        setState(() {
          _salaryLevels = results[0];
          _sessions = results[1];
          _expenseTypes = results[2];
          _suggestions = results[3];

          // Gộp danh sách chi tiêu mặc định và cá nhân
          final List<dynamic> defaultExpenses = results[4];
          final List<dynamic> userExpenses = results[5];
          _sampleExpenses = [...defaultExpenses, ...userExpenses];

          if (_salaryLevels.isNotEmpty) {
            _selectedSalaryLevelId = _salaryLevels.first['id'];
          }
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) { //kiểm tra tôồn tại widget
        setState(() {
          _isLoading = false;
          _error = 'Lỗi tải dữ liệu: $e';
        });
      }
    }
  }

  //hàm lấy dữ lịiệu từ API
  Future<List<dynamic>> _fetchData(String endpoint) async {
    final url = Uri.parse('http://10.0.2.2:8081/QuanLyChiTieu/api/$endpoint');
    final response = await http.get(url, headers: _authHeaders());

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return data is List ? data : [];
    } else if (response.statusCode == 401 || response.statusCode == 403) {
      if (mounted) {//kiểm tra widget tồn tại
        auth_utils.logoutUser(context, widget.token, widget.idnguoidung);
      }
      throw Exception('Phiên đăng nhập hết hạn');
    } else {
      throw Exception('Không thể tải dữ liệu từ ${response.statusCode}');
    }
  }

  Map<String, String> _authHeaders() {
    return {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer ${widget.token}',
    };
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Chi Tiêu Mẫu Tham Khảo'),
        backgroundColor: Colors.blue,
        leading: IconButton( //nút mũi tên back về
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: widget.onBack,
        ),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.white,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          tabs: const [
            Tab(text: 'Chi tiêu mẫu'),
            Tab(text: 'Chi tiêu cá nhân'),
          ],
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(child: Text(_error!, style: const TextStyle(color: Colors.red)))
              : Column(//sắp xếp các widget theo chiều dọc
                  children: [
                    // Luôn hiển thị dropdown chọn mức lương ở cả hai tab
                    _buildSalarySelector(),
                    //expanded dùng để chiếm toàn bộ không gian còn lại trong column
                    Expanded(
                      child: TabBarView(
                        controller: _tabController,
                        children: [
                          // Tab 1: Chi tiêu mặc định
                          _buildExpenseList(expenses: _defaultExpenses),
                          // Tab 2: Chi tiêu cá nhân
                          _buildExpenseList(expenses: _personalExpenses, isPersonalTab: true),
                        ],
                      ),
                    ),
                  ],
                ),
    );
  }

  //widget chọn mức lương
  Widget _buildSalarySelector() {
    return Container(
      //tạo khoảng cách bên trong
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 10.0),//lề trái phải , lề trên/dưới
      color: Colors.teal.withOpacity(0.1),
      child: DropdownButtonFormField<dynamic>(//dropdown kèm tích hợp với form
        value: _selectedSalaryLevelId, //gán giá trị được chọn hiện tại cho dropdown
        isExpanded: true, //chiếm toàn bộ chiều ngang dropdown
        decoration: const InputDecoration(
          labelText: 'Chọn mức lương của bạn',
          border: OutlineInputBorder(), //Tạo viền bao quanh input
          contentPadding: EdgeInsets.symmetric(horizontal: 10), //khoảng trống bên trái/phải giữa nội dung và viền
        ),
        //biến mỗi phần tử trong danh sách thành một dropmenu
        items: _salaryLevels.map<DropdownMenuItem<dynamic>>((level) {
          final amount = num.tryParse(level['muc_luong'].toString()) ?? 0;
          return DropdownMenuItem<dynamic>(
            value: level['id'],
            child: Text(_formatter.format(amount)), //format lại tiền kiểu VN
          );
        }).toList(),
        //xử lý sự kiện khi người dùng chọn một mục trong Dropdown.
        onChanged: (newValue) {
          setState(() {
            _selectedSalaryLevelId = newValue;
          });
        },
      ),
    );
  }

  // Thêm getter để lọc chi tiêu mẫu theo tab
  List<dynamic> get _defaultExpenses {
    return _sampleExpenses.where((exp) => exp['id_nguoidung'] == null).toList();
  }

  List<dynamic> get _personalExpenses {
    // Chuyển đổi id người dùng của widget (có thể là String) sang int để so sánh
    final currentUserId = int.tryParse(widget.idnguoidung.toString());
    if (currentUserId == null) {
      return []; // Trả về danh sách rỗng nếu id người dùng không hợp lệ
    }
    // Lọc chi tiêu mẫu có id_nguoidung khớp với id của người dùng đang đăng nhập
    return _sampleExpenses.where((exp) => exp['id_nguoidung'] == currentUserId).toList();
  }

  // Cập nhật hàm _buildExpenseList để nhận tham số expenses và isPersonalTab
  Widget _buildExpenseList({List<dynamic>? expenses, bool isPersonalTab = false}) {
    final expenseList = expenses ?? _sampleExpenses;
    
    // Xử lý cho tab cá nhân
    if (isPersonalTab) {
      if (expenseList.isEmpty) {
        return const Center(
            child: Text('Chưa có chi tiêu mẫu cá nhân nào. Hãy export từ trang chính!'));
      }
      // Nhóm các chi tiêu mẫu cá nhân theo tên
      final Map<String, List<dynamic>> expensesByName = {};
      for (var exp in expenseList) {
        final key = exp['ten_chi_tieu_mau']?.toString() ?? 'Chi tiêu mẫu chưa đặt tên';
        expensesByName.putIfAbsent(key, () => []).add(exp);
      }

      // Tính tổng lương (lấy mức lương đang chọn)
      double salaryAmount = 0;
      if (_salaryLevels.isNotEmpty && _selectedSalaryLevelId != null) {
        final selectedSalary = _salaryLevels.firstWhere(
          (level) => level['id'] == _selectedSalaryLevelId,
          orElse: () => null,
        );
        if (selectedSalary != null) {
          salaryAmount = (num.tryParse(selectedSalary['muc_luong'].toString()) ?? 0).toDouble();
        }
      }
      // Tính tổng chi tiêu cá nhân (không lọc theo mức lương)
      double totalPersonalExpense = 0;
      for (var exp in expenseList) {
        final suggestion = _suggestions.firstWhere((s) => s['id'] == exp['id_goi_y'], orElse: () => null);
        if (suggestion != null) {
          final amount = num.tryParse(suggestion['gia'].toString()) ?? 0;
          totalPersonalExpense += amount;
        }
      }
      double savings = salaryAmount - totalPersonalExpense;

      return ListView(
        padding: const EdgeInsets.all(8.0),
        children: [
          // Bảng tiết kiệm ở đầu tab cá nhân
          Padding(
            padding: const EdgeInsets.fromLTRB(12.0, 16.0, 12.0, 8.0),
            child: Card(
              elevation: 2,
              color: Colors.teal.shade50,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              child: Padding(
                padding: const EdgeInsets.all(12.0),
                child: RichText(
                  textAlign: TextAlign.center,
                  text: TextSpan(
                    style: const TextStyle(fontSize: 16, color: Colors.black87),
                    children: [
                      const TextSpan(text: 'Với các gợi ý này, bạn có thể tiết kiệm được: '),
                      TextSpan(
                        text: _formatter.format(savings),
                        style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 17,
                            color: Colors.green[700]),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          // Danh sách nhóm chi tiêu mẫu cá nhân
          ...expensesByName.keys.map((name) {
            final personalExpenses = expensesByName[name]!;
            // Nhóm theo ngày cho từng bộ chi tiêu cá nhân
            final Map<int, List<dynamic>> expensesByDay = {};
            for (var exp in personalExpenses) {
              expensesByDay.putIfAbsent(exp['ngay'], () => []).add(exp);
            }
            final sortedDays = expensesByDay.keys.toList()..sort();

            return Card(
              margin: const EdgeInsets.symmetric(vertical: 8.0),
              elevation: 2,
              child: Padding(
                padding: const EdgeInsets.all(8.0),
                child: Column(
                  children: [
                    // Tên của bộ chi tiêu mẫu + icon bút cập nhật
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 12.0),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            name,
                            textAlign: TextAlign.center,
                            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.teal),
                          ),
                          const SizedBox(width: 8),
                          GestureDetector(
                            onTap: () async {
                              final controller = TextEditingController(text: name);
                              final newName = await showDialog<String>(
                                context: context,
                                builder: (context) => AlertDialog(
                                  title: const Text('Đổi tên chi tiêu mẫu'),
                                  content: TextField(
                                    controller: controller,
                                    decoration: const InputDecoration(hintText: 'Nhập tên mới'),
                                  ),
                                  actions: [
                                    TextButton(
                                      onPressed: () => Navigator.pop(context),
                                      child: const Text('Hủy'),
                                    ),
                                    ElevatedButton(
                                      onPressed: () => Navigator.pop(context, controller.text.trim()),
                                      child: const Text('Lưu'),
                                    ),
                                  ],
                                ),
                              );
                              if (newName != null && newName.isNotEmpty && newName != name) {
                                await _updatePersonalSampleName(newName);
                                reloadData();
                                if (mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(content: Text('Đã cập nhật tên chi tiêu mẫu!')),
                                  );
                                }
                              }
                            },
                            child: const Icon(Icons.edit, color: Colors.blueGrey, size: 20),
                          ),
                          const SizedBox(width: 8),
                          GestureDetector(
                            onTap: () async {
                              final confirm = await showDialog<bool>(
                                context: context,
                                builder: (context) => AlertDialog(
                                  title: const Text('Xác nhận xóa'),
                                  content: const Text('Bạn có chắc chắn muốn xóa toàn bộ chi tiêu mẫu cá nhân đã export không?'),
                                  actions: [
                                    TextButton(
                                      onPressed: () => Navigator.pop(context, false),
                                      child: const Text('Hủy'),
                                    ),
                                    ElevatedButton(
                                      onPressed: () => Navigator.pop(context, true),
                                      child: const Text('Xóa'),
                                    ),
                                  ],
                                ),
                              );
                              if (confirm == true) {
                                await _deletePersonalSampleExpenses();
                                reloadData();
                                if (mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(content: Text('Đã xóa toàn bộ chi tiêu mẫu cá nhân!')),
                                  );
                                }
                              }
                            },
                            child: const Icon(Icons.delete, color: Colors.redAccent, size: 20),
                          ),
                        ],
                      ),
                    ),
                    const Divider(),
                    // ListView cho các ngày
                    ListView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: sortedDays.length,
                      itemBuilder: (context, dayIndex) {
                        final day = sortedDays[dayIndex];
                        final expensesForDay = expensesByDay[day]!;
                        // Tính tổng chi tiêu của ngày này
                        double totalForDay = 0;
                        for (var exp in expensesForDay) {
                          final suggestion = _suggestions.firstWhere((s) => s['id'] == exp['id_goi_y'], orElse: () => null);
                          if (suggestion != null) {
                            final amount = num.tryParse(suggestion['gia'].toString()) ?? 0;
                            totalForDay += amount;
                          }
                        }
                        return ExpansionTile(
                          title: Text('Ngày $day', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                          children: [
                            Padding(
                              padding: const EdgeInsets.fromLTRB(16.0, 8.0, 16.0, 8.0),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  const Text('Tổng chi tiêu dự kiến:', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500)),
                                  Text(
                                    _formatter.format(totalForDay),
                                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.redAccent),
                                  ),
                                ],
                              ),
                            ),
                            const Divider(height: 1, indent: 16, endIndent: 16, thickness: 1),
                            ..._buildPersonalSuggestionList(expensesForDay),
                          ],
                        );
                      },
                    ),
                  ],
                ),
              ),
            );
          }),
        ],
      );
    }
    
    // Phần code còn lại cho tab mặc định (giữ nguyên)
    if (_selectedSalaryLevelId == null) {
      return const Center(child: Text('Vui lòng chọn mức lương để xem gợi ý.'));
    }
    
    dynamic selectedSalaryLevel = _salaryLevels.firstWhere(
        (level) => level['id'] == _selectedSalaryLevelId,
        orElse: () => null);

    if (selectedSalaryLevel == null) return const SizedBox.shrink();
    double salaryAmount = (num.tryParse(selectedSalaryLevel['muc_luong'].toString()) ?? 0).toDouble();
    
    List<dynamic> filteredExpenses = expenseList.where((exp) => exp['id_muc_luong'] == _selectedSalaryLevelId).toList();

    if (filteredExpenses.isEmpty) {
      return const Center(
          child: Text('Không có dữ liệu chi tiêu mẫu cho mức lương này.'));
    }

    double totalMonthlyExpense = filteredExpenses.fold(0.0, (sum, exp) {
      final suggestion = _suggestions.firstWhere((s) => s['id'] == exp['id_goi_y'], orElse: () => null);
      if (suggestion != null) {
        final amount = num.tryParse(suggestion['gia'].toString()) ?? 0;
        return sum + amount;
      }
      return sum;
    });
    double savings = salaryAmount - totalMonthlyExpense;

    final Map<int, List<dynamic>> expensesByDay = {};
    for (var exp in filteredExpenses) {
      expensesByDay.putIfAbsent(exp['ngay'], () => []).add(exp);
    }
    final sortedDays = expensesByDay.keys.toList()..sort();

    return Column(
      children: [    
        Padding(
          padding: const EdgeInsets.fromLTRB(12.0, 16.0, 12.0, 8.0),
          child: Card(
            elevation: 2,
            color: Colors.teal.shade50,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            child: Padding(
              padding: const EdgeInsets.all(12.0),
              child: RichText(
                textAlign: TextAlign.center,
                text: TextSpan(
                  style: const TextStyle(fontSize: 16, color: Colors.black87),
                  children: [
                    const TextSpan(text: 'Với các gợi ý này, bạn có thể tiết kiệm được: '),
                    TextSpan(
                      text: _formatter.format(savings),
                      style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 17,
                          color: Colors.green[700]),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),

        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.all(8.0),
            itemCount: sortedDays.length,
            itemBuilder: (context, index) {
              final day = sortedDays[index];
              final expensesForDay = expensesByDay[day]!;
              return Card(
                margin: const EdgeInsets.only(bottom: 12.0),
                elevation: 2,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
                child: ExpansionTile(
                  title: Text('Ngày $day',
                      style: const TextStyle(
                          fontWeight: FontWeight.bold, fontSize: 18)),
                  children: _buildSessionsForDay(expensesForDay),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  // Hàm mới để hiển thị danh sách gợi ý cho tab cá nhân
  List<Widget> _buildPersonalSuggestionList(List<dynamic> dayExpenses) {
    if (dayExpenses.isEmpty) return [const ListTile(title: Text('Không có chi tiêu nào cho ngày này.'))];
    
    return dayExpenses.map((exp) {
      final suggestion = _suggestions.firstWhere(
        (s) => s['id'] == exp['id_goi_y'],
        orElse: () => {'goi_y': 'N/A', 'gia': '0'},
      );
      final amount = num.tryParse(suggestion['gia'].toString()) ?? 0;

      return ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 0),
        leading: const Icon(Icons.label_important_outline, color: Colors.blueGrey, size: 20),
        title: Text(suggestion['goi_y']),
        trailing: Text(
          _formatter.format(amount),
          style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 15),
        ),
      );
    }).toList();
  }

  // Xây dựng danh sách các buổi trong một ngày
  List<Widget> _buildSessionsForDay(List<dynamic> dayExpenses) {
    //fold được dùng để tính toán tổng, tích, hoặc thực hiện một phép gộp nào đó trên một danh sách.
    //0.0: giá trị khởi đầu (số thực double, tổng ban đầu).
    // (sum, exp): sum là tổng tạm thời, exp là phần tử đang lặp.
     // Tính tổng tiền chi tiêu dự kiến cho ngày
    final double totalForDay = dayExpenses.fold(0.0, (sum, exp) {
      final suggestion = _suggestions.firstWhere(//tìm tử đầu tiên thõa đk
        (s) => s['id'] == exp['id_goi_y'],
        orElse: () => null
      );
      if (suggestion != null) {//ko null
        final amount = num.tryParse(suggestion['gia'].toString()) ?? 0; //gán giá của món gợi ý
        return sum + amount;
      }
      return sum;
    });


    //..sort(...)	Sắp xếp tại chỗ (in-place) theo điều kiện
    // (a, b) => a['id'].compareTo(b['id'])	So sánh id của hai phần tử để sắp tăng dần
    //tạo bản sao danh sách buổi và sắp xếp buoi tăng dần
    final sortedSessions = List<dynamic>.from(_sessions)..sort((a,b) => a['id'].compareTo(b['id']));
    //widget tổng chi dự kiến
    List<Widget> children = [
      Padding(
        padding: const EdgeInsets.fromLTRB(16.0, 8.0, 16.0, 8.0),
        child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
                const Text('Tổng chi tiêu dự kiến:', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500)),
                Text(
                    _formatter.format(totalForDay), //tổng tiền chi trong ngày
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.redAccent),
                ),
            ],
        ),
      ),
      const Divider(height: 1, indent: 16, endIndent: 16, thickness: 1),
    ];

    //thêm các widget con vào ds children
    //duyệt qua ds sortedS thành widget và dùng all để thêm tất cả vào children
    children.addAll(sortedSessions.map((session) {
      //lọc khoản chi tiêu trong 1 ngày thuộc đúng buổi hiện tại
      final expensesForSession = dayExpenses.where((exp) => exp['id_buoi'] == session['id']).toList();

      if (expensesForSession.isEmpty) {//rỗng thì ko hiển thị và thay bằng widget rỗng
        return const SizedBox.shrink();
      }

      //tên buổi
      return Padding(
        padding: const EdgeInsets.fromLTRB(16.0, 8.0, 16.0, 16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              session['ten_buoi'].toUpperCase(), //biến giá trị ten_buoi thành chữ in hoa
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16,
                color: Colors.teal[700],
              ),
            ),
            const Divider(),
            //chèn danh sách các widget hiển thị chi tiêu vào children
            ..._buildExpenseTypesForSession(expensesForSession),
          ],
        ),
      );
    }));
    
    return children;
  }

  // Xây dựng các loại chi tiêu trong một buổi
  List<Widget> _buildExpenseTypesForSession(List<dynamic> sessionExpenses) {
    final Map<int, List<dynamic>> expensesByTypeId = {};
    //nhóm các khoản chi trong một buổi theo id_loai_chi
    for (var exp in sessionExpenses) {
      //putIfAbsent(...)	Nếu chưa có key id_loai_chi, tạo [] mới
      expensesByTypeId.putIfAbsent(exp['id_loai_chi'], () => []).add(exp);//	Thêm khoản chi đó vào nhóm loại tương ứng
    }


    //entries dùng để lấy tất cả các cặp key–value dưới dạng một iterable gồm các MapEntry
    // lặp qua từng nhóm chi tiêu theo loại (entries của Map) và tạo widget cho mỗi loại chi tiêu.
    return expensesByTypeId.entries.map((entry) {
      final typeId = entry.key; //lấy khóa
      final typeExpenses = entry.value; //lấy giá trị
      //Tìm trong danh sách _expenseTypes loại chi tiêu có id bằng typeId.
      final expenseType = _expenseTypes.firstWhere(
        (type) => type['id'] == typeId,
        orElse: () => {'ten_loai': 'Không xác định'},
      );


      //hiển thị tên loại
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 8.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
             Row(
                children: [
                    Icon(Icons.category_outlined, color: Colors.teal[300], size: 20),
                    const SizedBox(width: 8),
                    Text(
                        expenseType['ten_loai'],
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                    ),
                ],
             ),
             const SizedBox(height: 8),
             Padding(
                padding: const EdgeInsets.only(left: 28.0),
                child: Column(
                    children: _buildSuggestionDetails(typeExpenses), //xây dựng danh dách chi tiết gợi ý dựa vào loại chi tiêu
                ),
             )
          ],
        ),
      );
    }).toList();
  }

  // Xây dựng chi tiết gợi ý và giá tiền
  List<Widget> _buildSuggestionDetails(List<dynamic> typeExpenses) {
    return typeExpenses.map((exp) {
      //tìm gợi ý tương ứng với khoản chi tiêu dựa vào id_goi_y
        final suggestion = _suggestions.firstWhere(
          (s) => s['id'] == exp['id_goi_y'],
          orElse: () => {'goi_y': 'N/A', 'gia': '0'},
        );
        final amount = num.tryParse(suggestion['gia'].toString()) ?? 0;

        //hiển thị chi tiết gợi ý và giá tiền
        return Padding(
          padding: const EdgeInsets.only(bottom: 4.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text("• ${suggestion['goi_y']}"),
              Text(
                _formatter.format(amount),
                style: const TextStyle(fontWeight: FontWeight.w500, color: Colors.black54),
              )
            ],
          ),
        );
    }).toList();
  }

  // Hàm cập nhật tên chi tiêu mẫu cá nhân qua API mới
  Future<void> _updatePersonalSampleName(String newName) async {
    final userId = widget.idnguoidung;
    final url = Uri.parse('http://10.0.2.2:8081/QuanLyChiTieu/api/chitieumau/user/$userId/update-name');
    final response = await http.put(
      url,
      headers: _authHeaders(),
      body: jsonEncode({
        'ten_moi': newName,
      }),
    );
    if (response.statusCode != 200) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Lỗi cập nhật tên: ${response.body}')),
        );
      }
    }
  }

  // Hàm xóa toàn bộ chi tiêu mẫu cá nhân qua API DELETE
  Future<void> _deletePersonalSampleExpenses() async {
    final userId = widget.idnguoidung;
    final url = Uri.parse('http://10.0.2.2:8081/QuanLyChiTieu/api/chitieumau/user/$userId');
    final response = await http.delete(
      url,
      headers: _authHeaders(),
    );
    if (response.statusCode != 200) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Lỗi xóa chi tiêu mẫu cá nhân: ${response.body}')),
        );
      }
    }
  }
}
