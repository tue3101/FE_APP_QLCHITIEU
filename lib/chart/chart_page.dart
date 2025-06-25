import 'dart:async';
import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:intl/intl.dart';
import '../icon_color_utils.dart' as utils;
import '../utils/auth_utils.dart' as auth_utils;

class ChartPage extends StatefulWidget {
  final String token;
  final dynamic idnguoidung;
  final VoidCallback onBack;

  const ChartPage({
    //super.key đảm bảo key được truyền lên StatefulWidget
    // giúp Flutter biết widget này là “cũ” hay “mới” khi so sánh UI.
    super.key,
    //bắt buộc truyền các tham số này
    required this.token,
    required this.idnguoidung,
    required this.onBack,
  });

  //ghi đè override lên pthuc createState
  @override
  //khởi tạo trạng thái của chartP
  State<ChartPage> createState() => ChartPageState();
}

class ChartPageState extends State<ChartPage> {
  bool _isLoading = true; //cờ cho việc load
  double _totalExpense = 0.0; //khởi tạo tổng chi tiêu = 0.0
  ////tạo biến _cateED kiểu danh sách với mỗi phần tử là 1 map có key là String và value là dynamic
  List<Map<String, dynamic>> _categoryExpenseDetails = []; //danh mục chi tiết chi phí
  double _totalIncome = 0.0; //tổng thu nhập
  List<Map<String, dynamic>> _categoryIncomeDetails = []; //danh mục chi tiết thu nhập

  //lấy ngày hiện tại dùng subtract trừ đi 29 ngày (lùi lại 29 ngày)
  DateTime _startDate = DateTime.now().subtract(const Duration(days: 29));
  DateTime _endDate = DateTime.now(); //dùng ngày hôm nay là ngày kết thúc
  final _formatter = NumberFormat('#,###', 'vi_VN'); //dùng numberformat để hiển thị số theo kiểu Ziệt Nam

  //khai báo các danh sách kiểu dynamic
  List<dynamic> _allCategories = [];
  List<dynamic> _colors = [];
  List<dynamic> _icons = [];
  List<dynamic> _defaultCategories = [];
  List<dynamic> _userCategories = [];

  //khởi tạo trạng thái ban đầu của widget
  @override
  void initState() {
    super.initState();
    _fetchAllInitialData();
  }

  //hàm bất đồng bộ chọn thời giản hiển thị giao dịch lên biểu đồ
  //BuildContext đối tượng đại diện cho vị trí widget trong cây widget
  Future<void> _selectDateRange(BuildContext context) async {
    //gọi hàm show để hiển thị hộp thoại chọn khoảng ngày
    //gán kết quả người dùng chọn cho newDateRange
    final newDateRange = await showDateRangePicker(
      context: context, //để flutter biết hộp thoại đó nằm đâu trong widget tree
      //đặt trước mốc thời gian được chọn khi lịch hiển thị
      //datetimeRange đại diện cho khoảng tgian giữa 2 ngày cụ thể
      initialDateRange: DateTimeRange(start: _startDate, end: _endDate),
      firstDate: DateTime(2000), //ngày sớm nhất có thể chọn là 1/1/2000
      lastDate: DateTime.now().add(const Duration(days: 365)), //ngày muộn  nhất có thể chọn (ngày hiện tại cộng 365 ngày (tối đa trong 1 năm tới) )
    );

    //kiểm tra người dùng có chọn khoảng thời gian mới ko
    //nếu người dùng bấm cancel thì newDR = null và ko làm gì cả
    if (newDateRange != null) {
      setState(() {
        _startDate = newDateRange.start;
        _endDate = newDateRange.end;
      });
      _fetchChartData();
    }
  }

  Future<void> _fetchAllInitialData() async {
    setState(() {
      _isLoading = true;
    });
    try {
      //lấy dữ liệu về cùng lúc
      await Future.wait([
        _fetchColors(),
        _fetchIcons(),
        _fetchDefaultCategories(),
        _fetchUserCategories(),
      ]);
      //chạy sau khi 4 hàm kia hoàn tất
      _combineCategories();//kết hợp danh mục
      //phụ thuộc vào kết quả sau khi combine xong
      await _fetchChartData();//dữ liệu biểu đồ theo danh mục
    } catch (e) {
      print('Lỗi khi tải dữ liệu ban đầu: $e');
    } finally {
      //mounted là thuộc tính có sẵn trong state
      //trả về true nếu widget còn sống và false nếu bị dispose
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _fetchChartData() async {
    //mounted là thuộc tính có sẵn trong state
    //trả về true nếu widget còn sống và false nếu bị dispose
    if (mounted) {
      setState(() {
        _isLoading = true;
      });
    }

    try {
      final userId = int.tryParse(widget.idnguoidung.toString());
      if (userId == null) throw Exception("ID người dùng không hợp lệ");
      //lấy danh sách các tháng trong khoảng thời gian mà người dùng chọn gán vào months
      final months = _getMonthsInRange(_startDate, _endDate);

      // Fetch all data in parallel
      final results = await Future.wait([
        //gọi khoảng chi tiêu cố định theo tháng
        // _fetchMonthlyExpenses(userId, months),
        //lấy khoảng chi tiêu phát sinh
        _fetchVariableTransactions(userId, months),
      ]);

      //tổng chi tiêu hàng tháng
      // final totalMonthlyExpense = results[0] as double; // ĐÃ ĐÓNG COMMAND
      //chi tiêu phát sinh
      final variableTransactions = results[0] as List<dynamic>; // ĐÃ ĐÓNG COMMAND: đổi index từ 1 -> 0

      //gọi hàm xử lý giá trị đầu vào và chuẩn bị hiển thị biểu đồ
      _processChartData(/*totalMonthlyExpense,*/ 0.0, variableTransactions, months); // ĐÃ ĐÓNG COMMAND: truyền 0.0 thay vì totalMonthlyExpense

    } catch (e) {
      print('Lỗi khi tải dữ liệu biểu đồ: $e');
      //mounted là thuộc tính có sẵn trong state
      //trả về true nếu widget còn sống và false nếu bị dispose
      if (mounted) {
        setState(() {
          _totalExpense = 0; // tổng chi tiêu ban đầu gán = 0
          _categoryExpenseDetails = []; //gán ds rỗng
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }


  //hàm tạo danh sách các tháng (ngày đầu mỗi tháng) nằm trong khoảng thời gian bắt đầu đến kết thúc
  //để hiển thị báo cáo theo tháng
  List<DateTime> _getMonthsInRange(DateTime start, DateTime end) {
    final months = <DateTime>[];//khởi tạo danh sách rỗng kiểu DT gán cho months
    var currentMonth = DateTime(start.year, start.month, 1);//bắt đầu từ ngày đầu tiên của tháng
    //lặp qua từng tháng đến tháng cuối
    while (currentMonth.isBefore(DateTime(end.year, end.month + 1, 1))) {
      months.add(currentMonth); //thêm từng tháng vào danh sách
      currentMonth = DateTime(currentMonth.year, currentMonth.month + 1, 1); //nhảy sang tháng kế tiếp
    }
    return months;
  }

  //hàm lấy về dữ liệu chi tiêu hàng tháng
  // Future<double> _fetchMonthlyExpenses(int userId, List<DateTime> months) async {
  //   double total = 0.0; //khởi tạo = 0.0
  //   final futures = months.map((month) => //dùng biến months chứa giá trị tháng mà người dùng chọn
  //     _fetchTongChiTieuHangThang(userId, month.month, month.year)
  //   ).toList();
  //
  //   final results = await Future.wait(futures);
  //   for (var expense in results) {
  //     total += expense;
  //   }
  //   return total;
  // }


  //hàm lấy dữ liệu chi tiêu phát sinh
  Future<List<dynamic>> _fetchVariableTransactions(int userId, List<DateTime> months) async {
    final transactions = <dynamic>[];
    final futures = months.map((month) => 
      _fetchTransactionsByMonth(userId, month.month, month.year) //lấy giao dịch trong tháng
    ).toList();
    
    final results = await Future.wait(futures);
    for (var monthTransactions in results) {
      transactions.addAll(monthTransactions);//add danh sách monthT vào danh sách trans
    }
    return transactions;
  }

  //tạo hàm xử lý dữ liệu biểu đồ
  void _processChartData(double monthlyExpense, List<dynamic> transactions, List<DateTime> months) {
    // --- BIẾN TẠM THỜI ĐỂ XỬ LÝ ---
    Map<String, dynamic> expenseCategoryDetails = {};
    double variableExpenseTotal = 0; //tổng chi tiêu theo tháng
    Map<String, dynamic> incomeCategoryDetails = {};
    double incomeTotal = 0; //tổng thu nhập

    // --- LỌC GIAO DỊCH THEO KHOẢNG NGÀY ---
    final dateFormat = DateFormat('dd/MM/yyyy');
    final transactionsInDateRange = transactions.where((t) { //dùng where để lọc phần tử thỏa điêu kiện
      try {
        final transDate = dateFormat.parse(t['ngay']); //chuyển  chuỗi ngày kiểu String -> DT
        //kiểm tra transdate có nằm trong khoảng từ start -> end ko
        //isAfter là kiểm tra lớn hơn
        return transDate.isAfter(_startDate.subtract(const Duration(days: 1))) && // trừ đi 1 ngày nêếu transDate > hơn thì true
              //isBefore là kiểm tra nhỏ hơn
               transDate.isBefore(_endDate.add(const Duration(days: 1))); //cộng thêm 1 ngày nếu  transDate < hơn thì true
      } catch (e) {
        return false;
      }
    }).toList();


    // --- XỬ LÝ TỪNG GIAO DỊCH TRONG KHOẢNG NGÀY ĐÃ LỌC ---
    for (var t in transactionsInDateRange) {
      final amount = (t['so_tien'] as num).toDouble();
      final categoryId = t['id_danhmuc']?.toString();
      final isExpense = t['id_loai'].toString() == '2'; //kiem tra xem có phải chi tiêu hong

      final categoryInfo = _allCategories.firstWhere( //dùng firstwhere tìm ptu đầu tiên trong ds
        (cat) => categoryId != null && cat['id_danhmuc']?.toString() == categoryId,
        orElse: () => const <String, dynamic>{}
      );

      String categoryName;
      String color;
      String icon;

      //kiểm tra rỗng
      if (categoryInfo.isNotEmpty && (categoryInfo['ten_danh_muc'] as String?)?.isNotEmpty == true) {
        categoryName = categoryInfo['ten_danh_muc'] as String;
        color = categoryInfo['ma_mau'] as String? ?? '9E9E9E';
        icon = categoryInfo['ma_icon'] as String? ?? 'e887';
      } else {
        categoryName = 'Chưa phân loại';
        color = '9E9E9E';
        icon = 'e887';
      }

      // --- PHÂN LOẠI VÀO CHI TIÊU HOẶC THU NHẬP ---
      if (isExpense) { //isExpense -> true -> chi tiêu
        variableExpenseTotal += amount;
        expenseCategoryDetails.update(// cập nhật giá trị tương ứng với categoryName (key)
          categoryName,
          //nếu có  categoryName
          (existing)
          => <String, dynamic>{//trả về một Map
            'name': existing['name'],
            'amount': (existing['amount'] as num) + amount,
            'color': existing['color'],
            'icon': existing['icon'],
            'count': (existing['count'] as int) + 1, //đếm số lần xuất hiện
          },
          //ko có categoryName
          ifAbsent: () => <String, dynamic>{
            'name': categoryName,
            'amount': amount,
            'color': color,
            'icon': icon,
            'count': 1 //gán = 1 vì lần đầu tiên thấy
          },
        );
      } else { //ngược lại thì vào thu nhập
        incomeTotal += amount;
        incomeCategoryDetails.update(
          categoryName,
          //nếu có CateN
          (existing) => <String, dynamic>{
            'name': existing['name'],
            'amount': (existing['amount'] as num) + amount,
            'color': existing['color'],
            'icon': existing['icon'],
            'count': (existing['count'] as int) + 1,
          },
          //nếu ko có thì tạo mới
          ifAbsent: () => <String, dynamic>{
            'name': categoryName,
            'amount': amount,
            'color': color,
            'icon': icon,
            'count': 1 },
        );
      }
    }
    
    // --- XỬ LÝ DỮ LIỆU CHI TIÊU ---
    //tổng tất cả chi tiêu
    // final grandTotalExpense = monthlyExpense + variableExpenseTotal; // ĐÃ ĐÓNG COMMAND
    final grandTotalExpense = variableExpenseTotal; // Chỉ lấy chi tiêu phát sinh
    //danh sách chi tiết chi tiêu
    final expenseDetailsList = expenseCategoryDetails.values.toList(); //.value -> lấy tất cả giá trị

    //mục đích là chỉ khi có chi tiêu cố định mơi thêm mục chi tiêu cố định hàng tháng vào ds thong ke
    //kiểm tra người dùng có phát sinh chi tiêu cố định ko
    // if (monthlyExpense > 0) { //chi tiêu hàng tháng lớn hơn 0
    //   //chèn moot mục vào đầu danh sách
    //   expenseDetailsList.insert(0, {//chèn vào vị trí đầu tiên
    //     'name': 'Chi tiêu cố định hàng tháng',
    //     'amount': monthlyExpense,
    //     'color': '808080',
    //     'icon': 'e584',
    //     'count': months.length, //Gán giá trị cho key 'count' bằng số lượng tháng trong danh sách months.
    //   });
    // }

    // --- XỬ LÝ DỮ LIỆU THU NHẬP ---
    final incomeDetailsList = incomeCategoryDetails.values.toList(); //lấy tất cả giá trị trong map thu nhập
    
    // --- CẬP NHẬT STATE ---
    //mounted là thuộc tính có sẵn trong state
    //trả về true nếu widget còn sống và false nếu bị dispose
    if (mounted) {
      setState(() {
        _totalExpense = grandTotalExpense; //gán kết quả sau khi cộng
        //ds chứa ptu kieru map -> .map() biến đổi từng ptu trong ds
        _categoryExpenseDetails = expenseDetailsList.map<Map<String, dynamic>>(
          (e) //mặc định là dynamic
            => Map<String, dynamic>.from(e as Map)//tạo bảng sao //mỗi ptu 2 được ép kiểu map
        ).toList();
        _totalIncome = incomeTotal;
        //ds chứa ptu kieru map -> .map() biến đổi từng ptu trong ds
        _categoryIncomeDetails = incomeDetailsList.map<Map<String, dynamic>>(
          (e) => Map<String, dynamic>.from(e as Map)//tạo bảng sao //mỗi ptu 2 được ép kiểu map
        ).toList();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    //kiểm tra chi tiết danh mục chi tiêu ko rỗng hoặc tổng chi >0
    final bool hasExpenseData = _categoryExpenseDetails.isNotEmpty || _totalExpense > 0;
    //kiểm tra chi tiết danh mục thu nhập ko rỗng hoặc tổng thu >0
    final bool hasIncomeData = _categoryIncomeDetails.isNotEmpty || _totalIncome > 0;
  //Chỉ cần có dữ liệu chi tiêu hoặc thu nhập → coi như có dữ liệu để hiển thị
    final bool hasAnyData = hasExpenseData || hasIncomeData;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Báo cáo Thu chi'),
        backgroundColor: Colors.blue,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: widget.onBack,
        ),
        titleTextStyle: const TextStyle(color: Colors.white, fontSize: 20),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                _buildDateSelector(),
                Expanded(
                  child: hasAnyData
                      ? SingleChildScrollView(
                          child: Padding(
                            padding: const EdgeInsets.only(bottom: 24.0),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                if (hasExpenseData)//nếu có dữ liệu chi tiêu
                                  _buildExpenseChartAndDetails(),//gọi hàm vẽ bd và hiển thị ds chi tiết danh mục
                                //Nếu có cả thu nhập và chi tiêu, thì chèn thêm một đường kẻ phân cách
                                if (hasExpenseData && hasIncomeData)
                                  const Divider(height: 48, thickness: 1, indent: 16, endIndent: 16),
                                if (hasIncomeData)
                                  _buildIncomeChartAndDetails(),
                              ],
                            ),
                          ),
                        )
                      : _buildNoDataWidget(),
                ),
              ],
            ),
    );
  }

  Widget _buildDateSelector() {
    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: TextButton.icon(
        onPressed: () => _selectDateRange(context),
        icon: const Icon(Icons.calendar_today),
        label: Text(
          // chuyển hai biến _startDate và _endDate từ kiểu DateTime thành chuỗi định dạng ngày/tháng/năm
          //sau đó ghép lại thành một chuỗi biểu thị khoảng thời gian.
          '${DateFormat('dd/MM/yyyy').format(_startDate)} - ${DateFormat('dd/MM/yyyy').format(_endDate)}',
        ),
        style: TextButton.styleFrom(
          foregroundColor: Colors.white,
          backgroundColor: Colors.blue,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
        ),
      ),
    );
  }

  //ko có dữ liệu nào từ thu và chi
  Widget _buildNoDataWidget() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.receipt_long, size: 80, color: Colors.grey),
          const SizedBox(height: 16),
          const Text(
            'Không có dữ liệu thu chi',
            style: TextStyle(fontSize: 18, color: Colors.grey),
          ),
          Text(
            'Vui lòng chọn khoảng thời gian khác.',
            style: TextStyle(fontSize: 16, color: Colors.grey[600]),
          ),
        ],
      ),
    );
  }

  // --- PHẦN CHI TIÊU ---
  Widget _buildExpenseChartAndDetails() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
          child: Text('TỔNG CHI TIÊU', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.redAccent)),
        ),
        _buildExpensePieChart(),
        const SizedBox(height: 24),
        _buildExpenseCategoryList(),
      ],
    );
  }

  //biểu đồ chi tiêu
  Widget _buildExpensePieChart() {
    // //tạo ds mới từ _categoryExpenseDetails
    final sortedForChart = List<Map<String, dynamic>>.from(_categoryExpenseDetails)
      ..sort((a, b) => b['amount'].compareTo(a['amount'])); //dùng ..sort so sánh số tiền b với a rồi dùng compareTo sắp xếp giảm dần

    return Container(
      height: 250,
      child: Stack(
        alignment: Alignment.center,
        children: [
          PieChart(
            PieChartData(
              //.map() ánh xạ từng ptu thành một PieChartSectionDate hiển thị lên biểu đồ tròn
              sections: sortedForChart.map((detail) {//danh sách các danh mục chi tiêu đã được sắp xếp giảm dần theo số tiền
                //tính % của từng danh mục trên tổng chi tiêu
                //ví dụ: chi tiêu hàng tháng = 2.000.000 , tổng chi = 2.200.000 => 2.000.000/2.200.200*100 = 90.9%
                final double percentage = (_totalExpense > 0) ? (detail['amount'] / _totalExpense) * 100 : 0;
                return PieChartSectionData(
                  color: utils.hexToColor(detail['color'] as String),
                  value: detail['amount'], //Giá trị phần trăm thực tế trên biểu đồ tròn
                  //toStringAsFixed(1): làm tròn phần trăm tới 1 chữ số sau dấu phẩy
                  title: '${percentage.toStringAsFixed(1)}%', //Hiển thị chuỗi phần trăm làm nhãn của từng phần biểu đồ
                  radius: 80,
                  titleStyle: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                );
              }).toList(),
              centerSpaceRadius: 60,
              sectionsSpace: 2,
            ),
          ),
          Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text('Tổng chi', style: TextStyle(color: Colors.grey, fontSize: 16)),
              Text(
                // định dạng số tiền _totalExpense sang chuỗi có dấu phân cách hàng nghìn, rồi thêm ký hiệu tiền tệ "₫"
                '${_formatter.format(_totalExpense)} ₫',
                style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.redAccent),
              ),
            ],
          ),
        ],
      ),
    );
  }

  //tạo danh sách các danh mục chi tiêu được sắp xếp theo số tiền giảm dần
  Widget _buildExpenseCategoryList() {
    // tạo ds mới kiểu map từ _categoryExpenseDetails
     final sortedForList = List<Map<String, dynamic>>.from(_categoryExpenseDetails)
     //dùng ..sort so sánh a với b và compareTo sắp xếp giảm dần
      ..sort((a, b) => b['amount'].compareTo(a['amount']));

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: sortedForList.map((detail) {//danh sách các danh mục chi tiêu đã được sắp xếp giảm dần theo số tiền
          //tính % của từng danh mục trên tổng chi tiêu
          //ví dụ: chi = 2.000.000 , tổng chi = 2.200.000 => 2.000.000/2.200.200*100 = 90.9%
          final double percentage = (_totalExpense > 0) ? (detail['amount'] / _totalExpense) * 100 : 0;
          return Card(
            elevation: 2,
            margin: const EdgeInsets.symmetric(vertical: 4),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            child: Padding(
              padding: const EdgeInsets.all(12.0),
              child: Column(
                children: [
                  Row(
                    children: [
                      CircleAvatar(
                        backgroundColor: utils.hexToColor(detail['color'] as String),
                        child: Icon(
                          utils.getFaIconDataFromUnicode(detail['icon'] as String),
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                             Text(
                              detail['name'],
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                            ),
                            Text(
                              '${detail['count']} giao dịch', //số lượng giao dịch của danh mục đó
                              style: const TextStyle(color: Colors.grey, fontSize: 12),
                            ),
                          ],
                        ),
                      ),
                      Text(
                        // Dùng để hiển thị số tiền chi tiêu của từng danh mục dưới dạng có định dạng dấu phẩy phân cách hàng nghìn
                        // kèm đơn vị tiền tệ ₫
                        '${_formatter.format(detail['amount'])} ₫',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.redAccent),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(//thanh tiến trình của danh mục thể hiện % chi tiêu của từng danh mục
                    children: [
                       Expanded(
                        child: LinearProgressIndicator(
                          value: percentage / 100,
                          backgroundColor: Colors.grey[200],
                          valueColor: AlwaysStoppedAnimation<Color>(
                            utils.hexToColor(detail['color'] as String),                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      //Chuyển số percentage thành chuỗi, làm tròn 1 chữ số thập phân.
                      Text('${percentage.toStringAsFixed(1)}%'),
                    ],
                  )
                ],
              ),
            ),
          );
        }).toList(),
      ),
    );
  }


  // --- PHẦN THU NHẬP ---
  Widget _buildIncomeChartAndDetails() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
          child: Text('TỔNG THU NHẬP', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.green)),
        ),
        _buildIncomePieChart(),
        const SizedBox(height: 24),
        _buildIncomeCategoryList(),
      ],
    );
  }

  Widget _buildIncomePieChart() {
    final sortedForChart = List<Map<String, dynamic>>.from(_categoryIncomeDetails)
      ..sort((a, b) => b['amount'].compareTo(a['amount']));

    return Container(
      height: 250,
      child: Stack(
        alignment: Alignment.center,
        children: [
          PieChart(
            PieChartData(
              //duyệt từng phần tử trong danh sách sortedForChart
              // mỗi phần tử là một Map<String, dynamic> đại diện cho một danh mục thu nhập,
              //chuyển nó thành một phần tử của biểu đồ tròn (PieChartSectionData).
              sections: sortedForChart.map((detail) {
                final double percentage = (_totalIncome > 0) ? (detail['amount'] / _totalIncome) * 100 : 0;
                return PieChartSectionData(
                  color: utils.hexToColor(detail['color'] as String),
                  value: detail['amount'],
                  //Chuyển số percentage thành chuỗi, làm tròn 1 chữ số thập phân.
                  title: '${percentage.toStringAsFixed(1)}%', //dùng ${}% để chèn % vào tỷ lệ tính được
                  radius: 80,
                  titleStyle: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                );
              }).toList(),
              centerSpaceRadius: 60,
              sectionsSpace: 2,
            ),
          ),
          Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text('Tổng thu', style: TextStyle(color: Colors.grey, fontSize: 16)),
              Text(
                //Dùng để hiển thị tổng thu nhập (_totalIncome) dưới dạng chuỗi có dấu phân cách hàng nghìn
                // kèm theo đơn vị tiền tệ ₫
                '${_formatter.format(_totalIncome)} ₫',
                style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.green),
              ),
            ],
          ),
        ],
      ),
    );
  }


  //-----Hiển thị phần danh mục thu nhập -----//
  Widget _buildIncomeCategoryList() {
    //tạo mới một danh sách kiểu map từ _categoryIncomeDetails
     final sortedForList = List<Map<String, dynamic>>.from(_categoryIncomeDetails)
      ..sort((a, b) => b['amount'].compareTo(a['amount'])); //dùng sort để so sánh a, b rồi dùng compareTo để sắp xếp giảm dần

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: sortedForList.map((detail) {//danh sách các danh mục thu nhập đã được sắp xếp giảm dần theo số tiền
          final double percentage = (_totalIncome > 0) ? (detail['amount'] / _totalIncome) * 100 : 0;
          return Card(
            elevation: 2,
            margin: const EdgeInsets.symmetric(vertical: 4),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            child: Padding(
              padding: const EdgeInsets.all(12.0),
              child: Column(
                children: [
                  Row(
                    children: [
                      CircleAvatar(
                        backgroundColor: utils.hexToColor(detail['color'] as String),
                        child: Icon(
                          utils.getFaIconDataFromUnicode(detail['icon'] as String),
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                             Text(
                              detail['name'],
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                            ),
                            Text(
                              '${detail['count']} giao dịch',//đếm số lượng giao dịch theo tên danh mục
                              style: const TextStyle(color: Colors.grey, fontSize: 12),
                            ),
                          ],
                        ),
                      ),
                      Text(
                        //Dùng để hiển thị tổng thu nhập (_totalIncome) dưới dạng chuỗi có dấu phân cách hàng nghìn
                        // kèm theo đơn vị tiền tệ ₫
                        '${_formatter.format(detail['amount'])} ₫',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.green),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                       Expanded(
                        child: LinearProgressIndicator(
                          value: percentage / 100,
                          backgroundColor: Colors.grey[200],
                          valueColor: AlwaysStoppedAnimation<Color>(
                            utils.hexToColor(detail['color'] as String),                           ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      //Chuyển số percentage thành chuỗi, làm tròn 1 chữ số thập phân.
                      Text('${percentage.toStringAsFixed(1)}%'),
                    ],
                  )
                ],
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  // --- Helper methods copied from HomePage ---
//danh mục kết hợp
  void _combineCategories() {
    List<dynamic> combined = [];
    combined.addAll(_defaultCategories);
    combined.addAll(_userCategories);

    _allCategories = combined.map((category) {
      final iconData = _icons.firstWhere(
        (icon) => icon['id_icon'].toString() == category['id_icon'].toString(),
        orElse: () => {'ma_icon': 'e887'}, // Default 'help' icon
      );
      final colorData = _colors.firstWhere(
        (color) => color['id_mau'].toString() == category['id_mau'].toString(),
        orElse: () => {'ma_mau': '9E9E9E'}, // Default Grey color
      );
      return {
        //Dùng toán tử spread (...category) để giữ lại toàn bộ dữ liệu gốc
        ...category,
        //thêm 2 trường mới
        'ma_icon': iconData['ma_icon'], // Chỉ sử dụng ma_icon
        'ma_mau': colorData['ma_mau'],
      };
    }).toList();
  }

  Future<void> _fetchDefaultCategories() async {
    final url = Uri.parse('http://10.0.2.2:8081/QuanLyChiTieu/api/default-categories');
    final response = await http.get(url, headers: _authHeaders());
    if (await _handleApiResponse(response)) { //kiểm tra phản hồi api
      final data = jsonDecode(response.body);
      //nếu data là list -> true
      _defaultCategories = data is List ? data : [];
    } else {
      print('Lỗi tải danh mục mặc định: ${response.statusCode}');
      _defaultCategories = [];
    }
  }

  Future<void> _fetchUserCategories() async {
    final url = Uri.parse('http://10.0.2.2:8081/QuanLyChiTieu/api/categories/user/${widget.idnguoidung}');
    final response = await http.get(url, headers: _authHeaders());
    if (await _handleApiResponse(response)) {
      final data = jsonDecode(response.body);
      //nếu data là list -> true
      _userCategories = data is List ? data : [];
    } else {
      print('Lỗi tải danh mục người dùng: ${response.statusCode}');
      _userCategories = [];
    }
  }

  Future<void> _fetchColors() async {
    final url = Uri.parse('http://10.0.2.2:8081/QuanLyChiTieu/api/colors');
    final response = await http.get(url, headers: _authHeaders());
    if (await _handleApiResponse(response)) {
      final data = jsonDecode(response.body);
      //nếu data là list -> true
      _colors = data is List ? data : [];
    } else {
       print('Lỗi tải màu: ${response.statusCode}');
      _colors = [];
    }
  }

  Future<void> _fetchIcons() async {
    final url = Uri.parse('http://10.0.2.2:8081/QuanLyChiTieu/api/icons');
    final response = await http.get(url, headers: _authHeaders());
    if (await _handleApiResponse(response)) {
       final data = jsonDecode(response.body);
       //nếu data là list -> true
       _icons = data is List ? data : [];
    } else {
      print('Lỗi tải icon: ${response.statusCode}');
      _icons = [];
    }
  }

  Future<List<dynamic>> _fetchTransactionsByMonth(int userId, int month, int year) async {
    final url = Uri.parse('http://10.0.2.2:8081/QuanLyChiTieu/api/transactions/user/$userId/month/$month/year/$year');
    final response = await http.get(url, headers: _authHeaders());
    if (await _handleApiResponse(response)) {
      final data = jsonDecode(response.body);
      //nếu data là list -> true
      if (data is List) return data;
      if (data is Map && data['data'] is List) return data['data'];
    }
    return [];
  }

  Future<double> _fetchTongChiTieuHangThang(int userId, int month, int year) async {
    // final url = Uri.parse('http://10.0.2.2:8081/QuanLyChiTieu/api/chi-tieu-hang-thang/user/$userId/month/$month/year/$year');
    // final response = await http.get(url, headers: _authHeaders());
    // if (await _handleApiResponse(response)) {
    //   final data = jsonDecode(response.body);
    //   if (data is Map && data.containsKey('amount') && data['amount'] != null) {
    //     return double.tryParse(data['amount'].toString()) ?? 0.0;
    //   }
    // }
    return 0.0; // ĐÃ ĐÓNG COMMAND: luôn trả về 0
  }
  
  Map<String, String> _authHeaders() {
    return {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer ${widget.token}',
    };
  }

  Future<bool> _handleApiResponse(http.Response response) async {
    //chưa login hoặc ko có quyền truy cập
    if (response.statusCode == 401 || response.statusCode == 403) {
      if (mounted) {
        //chuyển về logout
        auth_utils.logoutUser(context, widget.token, widget.idnguoidung);
      }
      return false;
    }//thành công
    return response.statusCode == 200;
  }

  Future<void> reloadData() async {
    await _fetchAllInitialData();
  }
} 