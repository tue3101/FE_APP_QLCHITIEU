import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../icon_color_utils.dart';
import '../category/category_selection_modal.dart';
import 'package:intl/intl.dart';
import 'package:math_expressions/math_expressions.dart';

class AddTransactionPage extends StatefulWidget {
  final String token;
  final dynamic idnguodung;
  const AddTransactionPage({super.key, required this.token, required this.idnguodung});

  @override
  State<AddTransactionPage> createState() => _AddTransactionPageState();
}

class _AddTransactionPageState extends State<AddTransactionPage> with TickerProviderStateMixin {
  late TabController _tabController;
  int selectedCategory = 0;
  final TextEditingController noteController = TextEditingController();
  List<dynamic> transactionTypes = [];
  List<dynamic> categories = []; // This might not be needed anymore in this file
  bool isLoading = true;
  String _displayValue = '0'; // Số hiển thị trên màn hình lớn
  String _fullExpression = ''; // Biểu thức đầy đủ đang được tính toán
  dynamic? _selectedCategory; // Stores the selected category data
  DateTime _selectedDate = DateTime.now();
  // TimeOfDay _selectedTime = TimeOfDay.now(); // Thời gian 
  bool _isNewNumber = false; // Flag to indicate if the next digit starts a new number
  bool _lastInputWasEquals = false; // Flag to check if the last input was '='

  @override
  void initState() {
    super.initState();
    fetchTransactionTypes();
  }

  @override
  void dispose() {
    _tabController.removeListener(_onTabChanged);
    _tabController.dispose();
    noteController.dispose();
    super.dispose();
  }

  Future<void> fetchTransactionTypes() async {
    setState(() { isLoading = true; });
    final url = Uri.parse('http://10.0.2.2:8081/QuanLyChiTieu/api/transaction-types');
    final response = await http.get(url, headers: {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer ${widget.token}',
    });
    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      setState(() {
        transactionTypes = data is List ? data : [];
        _tabController = TabController(length: transactionTypes.length, vsync: this);
        _tabController.addListener(_onTabChanged);
        isLoading = false;
      });
    } else {
      setState(() { isLoading = false; });
    }
  }

  void _onTabChanged() {
    if (_tabController.indexIsChanging) return;
  }

  //kiểm tra ký tự có phải toán tử
  bool _isOperator(String char) {
    return ['+', '-', '*', '/'].contains(char);
  }

  //hàm tính toán biểu thức số học
  void _evaluateCurrentExpression() {
    try {
      String expressionToEvaluate = _fullExpression; //lưu chuỗi biểu thức vd: 12+5 or 8-
      if (expressionToEvaluate.isEmpty
          || (expressionToEvaluate.isNotEmpty
              && _isOperator(expressionToEvaluate[expressionToEvaluate.length - 1]))){ //kiểm tra ký tự cuối có phải toán tử
        _displayValue = '0';
        return;
      }

      Parser p = Parser(); //phân tích cú pháp chuỗi biểu thức thành CTBT số học
      //gọi parse để chuyển chuỗi biểu thức thành đối tường E để máy tính có thể hiểu được
      //vd 4+5*5 => 4+(5*5)
      Expression exp = p.parse(expressionToEvaluate);
      ContextModel cm = ContextModel(); //vd a*b+4 => gán giá trị cho a , b thông qua CM
      double eval = exp.evaluate(EvaluationType.REAL, cm);
      _displayValue = eval.toInt().toString(); //vd: eval = 12.12 => 12 => "12"
    } catch (e) {
    }
  }
// truyền value vào (nhập trên phím may tính truyền giá trị vào)
  void _onNumberPressed(String value) {
    setState(() {
      if (_lastInputWasEquals) { //true (đã bấm =)
        //gán biểu thức và hiển thị hằng số mới
        _fullExpression = value; // biểu thức hiển thị
        _displayValue = value; // giá trị của biểu thức
        _lastInputWasEquals = false; //biến kiểm tra có bấm dấu = trước đó ko
        _isNewNumber = false; //ko nhập số mới
        return;
      }

      //nhập số mới sau phép toán
      if (_isNewNumber) {
        _displayValue = value; //cập nhật màn hình hiển thị hằng số vừa bấm
        _fullExpression += value; // nối số đó vào biểu thức đầy đủ
        _isNewNumber = false; //ko nhập số nữa
      } else {
        if (_displayValue == '0' && value == '0') return;
        if (_displayValue == '0' && value != '0') {
          _displayValue = value;
          //ko rỗng và kết = 0
          if (_fullExpression.isNotEmpty && _fullExpression.endsWith('0')) {
            //thay thế ký tự cuối trong _fullE = value vd: 5 + => * => bỏ + => 5 *
             _fullExpression = _fullExpression.substring(0, _fullExpression.length - 1) + value;
          } else {
             _fullExpression += value;
          }
        } else {
          _displayValue += value;
          _fullExpression += value; // Append digit to full expression
        }
      }
      _evaluateCurrentExpression();//gọi hàm để tính
    });
  }

  void _onOperatorPressed(String operator) {
    setState(() {
      _lastInputWasEquals = false; // lần nhập trc ko phải =

      if (_fullExpression.isNotEmpty && _isOperator(_fullExpression[_fullExpression.length - 1])) //lấy ký tự cuối của bthuc
        {
          //vd 3+5+ => bấm - => thay operator (-) vào cuối => 3+5-
        _fullExpression = _fullExpression.substring(0, _fullExpression.length - 1) + operator;
      } else {
        //kết quả khác 0 và biểu thức rỗng
        if (_displayValue != '0' || _fullExpression.isEmpty) {
           _fullExpression += operator; //thêm dấu cho bthuc
        } else if (_displayValue == '0' && _fullExpression.isEmpty) {
           _fullExpression = '0' + operator;
        }
      }
      _isNewNumber = true; //nhập số mới
      _evaluateCurrentExpression(); // gọi hàm tính
    });
  }
//khi nhấn C để clearAll
  void _onClearPressed() {
    setState(() {
      _displayValue = '0'; //đặt lại = 0
      _fullExpression = ''; // thay thế bthuc đang nhập thành chuỗi rỗng
      _isNewNumber = false; //đánh dấu chua nhập số mới
      // _lastInputWasEquals = false; //đánh dấu ko = ở lần nhập trc
    });
  }

  //Xóa từng ký tự
  void _onBackspacePressed() {
    setState(() {
      _lastInputWasEquals = false; //ko = ở lần trc

      if (_displayValue.isNotEmpty && _displayValue != '0') {
        _displayValue = _displayValue.substring(0, _displayValue.length - 1); //xóa ký tự cuối
        if (_displayValue.isEmpty) {
          _displayValue = '0'; //đặt về 0 nếu ko còn ký tự nào sau khi xóa
        }
      }

      if (_fullExpression.isNotEmpty) {
        _fullExpression = _fullExpression.substring(0, _fullExpression.length - 1); //xóa ký tự cuối nếu bthuc ko rỗng
      }

      if (_fullExpression.isEmpty) {
        _displayValue = '0';
        _isNewNumber = false;
      } else {
        _evaluateCurrentExpression();
      }
    });
  }

  void _onEqualsPressed() {
    setState(() {
      _lastInputWasEquals = true;

      try {
        String finalExpression = _fullExpression;
        // If the expression ends with an operator, remove it before final evaluation
        if (finalExpression.isNotEmpty && _isOperator(finalExpression[finalExpression.length - 1])) {
          finalExpression = finalExpression.substring(0, finalExpression.length - 1);
        }

        if (finalExpression.isEmpty) {
          _displayValue = '0';
          _fullExpression = '';
          _isNewNumber = false;
          return;
        }

        Parser p = Parser();
        Expression exp = p.parse(finalExpression);
        ContextModel cm = ContextModel();
        double eval = exp.evaluate(EvaluationType.REAL, cm);

        _displayValue = eval.toInt().toString();
        _fullExpression = _displayValue; // After '=', the result becomes the new base for calculation
        _isNewNumber = true; // Prepare for new number after result
      } catch (e) {
        _displayValue = 'Lỗi';
        _fullExpression = '';
        _isNewNumber = true;
        print('Calculation Error: $e');
      }
    });
  }

  // Function to build the blue header area
  Widget _buildHeader() {
    return Container(
      color: const Color(0xFF1565C0), // Blue color
      padding: const EdgeInsets.only(top: 40, bottom: 20, left: 16, right: 16), // Adjust padding as needed
      child: Column(
        children: [
          Row(
            children: [
              // Back button
              IconButton(
                icon: const Icon(Icons.arrow_back, color: Colors.white),
                onPressed: () => Navigator.pop(context),
              ),
              const Spacer(), // Pushes remaining items to the right
            ],
          ),
          const SizedBox(height: 16), // Space between back button row and category/amount row
          Row(
            crossAxisAlignment: CrossAxisAlignment.start, // Align items to the top of this row
            children: [
              // Category Icon (clickable)
              GestureDetector(
                onTap: _showCategorySelectionModal,
                child: CircleAvatar(
                  backgroundColor: hexToColor(_selectedCategory?['ma_mau'] ?? '#2196F3').withOpacity(0.2),
                  radius: 28,
                  child: Icon(
                    getFaIconDataFromUnicode(_selectedCategory?['ma_icon'] ?? 'f555'),
                    color: hexToColor(_selectedCategory?['ma_mau'] ?? '#2196F3'),
                    size: 32,
                  ),
                ),
              ),
              const SizedBox(width: 16),
              // Thêm tên danh mục ở đây
              if (_selectedCategory != null)
                 Expanded(
                  child: Text(
                    _selectedCategory?['ten_danh_muc'] ?? '', // Display category name
                    style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold), // Adjust style as needed
                    overflow: TextOverflow.ellipsis, // Prevent overflow
                  ),
                ),
              const SizedBox(width: 16), // Space between category name and amount display
              // Amount Input/Display and dropdown indicator
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end, // Align content to the right
                  children: [
                    // kết quả
                    TextField(
                      controller: TextEditingController(text: _displayValue),
                      textAlign: TextAlign.right,
                      keyboardType: TextInputType.none, // Hide default keyboard
                      style: const TextStyle(color: Colors.white, fontSize: 48, fontWeight: FontWeight.bold),
                      decoration: const InputDecoration(
                        border: InputBorder.none,
                        hintText: '0',
                        hintStyle: TextStyle(color: Colors.white70, fontSize: 48, fontWeight: FontWeight.bold),
                        contentPadding: EdgeInsets.zero,
                        isDense: true,
                      ),
                      readOnly: true,
                    ),
                    // Calculation string (e.g., 66+444=) - Số nhỏ
                    if (_fullExpression.isNotEmpty)
                      Text(
                        _fullExpression,
                        style: const TextStyle(color: Colors.white70, fontSize: 20),
                        textAlign: TextAlign.right,
                      ),
                  ],
                ),
              ),
              // Dropdown Indicator (optional, based on exact design needs)
              // Align to the top to match the number
              const Align(
                 alignment: Alignment.topRight,
                 child: Icon(Icons.arrow_drop_down, color: Colors.white70, size: 30),
              ),
            ],
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
       backgroundColor: const Color(0xFFF5F6FA),
       body: isLoading
             ? const Center(child: CircularProgressIndicator())
             : Column(
                 children: [
                   _buildHeader(),
                   Expanded(
                     child: SingleChildScrollView(
                       child: Column(
                         children: [
                           Container(
                             margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 8), // Adjust margin to match image
                             padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16), // Adjust padding
                             decoration: BoxDecoration(
                               color: Colors.white,
                               borderRadius: BorderRadius.circular(16), // Add border radius
                             ),
                             child: Column(
                               children: [
                                 // Row cho Ngày tháng
                                 Row(
                                   children: [
                                     const Icon(Icons.calendar_today, color: Colors.grey), // Use calendar_today icon
                                     const SizedBox(width: 8),
                                     const Text('Ngày tháng', style: TextStyle(fontSize: 16)), // Label
                                     const Spacer(), // Push date and arrow to the right
                                     TextButton(
                                       onPressed: () async {
                                         final date = await showDatePicker(
                                           context: context,
                                           initialDate: _selectedDate,
                                           //chỉ có thể chọn từ 2000 - 2100
                                           firstDate: DateTime(2000), //ngày sớm nhất trong năm 2000
                                           lastDate: DateTime(2100), //ngày cuối trong năm 2100
                                         );
                                         if (date != null) {
                                           setState(() => _selectedDate = date);
                                         }
                                       },
                                       child: Text(
                                         DateFormat('dd/MM/yyyy').format(_selectedDate), //chuyển DateTime thành dd/mm/yyyy
                                         style: TextStyle(fontSize: 16, color: Colors.black54), // Match text style
                                       ),
                                     ),
                                     const Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey), // Right arrow icon
                                   ],
                                 ),
                                 const SizedBox(height: 8), // Space between rows
                                 // Row cho Ghi chú
                                 Row(
                                   children: [
                                     const Icon(Icons.edit, color: Colors.grey), // Use edit icon
                                     const SizedBox(width: 8),
                                     const Text('Ghi chú', style: TextStyle(fontSize: 16)), // Label
                                     const Spacer(), // Push TextField to the right
                                     Expanded(
                                       child: TextField(
                                         controller: noteController,
                                         decoration: const InputDecoration(
                                           hintText: 'Nhập ghi chú', // Hint text
                                           border: InputBorder.none, // No border
                                           isDense: true, // Compact input
                                         ),
                                         textAlign: TextAlign.right, // Align text to the right
                                         style: const TextStyle(fontSize: 16, color: Colors.black54), // Match text style
                                       ),
                                     ),
                                   ],
                                 ),
                               ],
                             ),
                           ),
                           // Bàn phím số
                           Column(
                             children: [
                               Row(
                                 children: [
                                   _buildNumberButton('1'),
                                   _buildNumberButton('2'),
                                   _buildNumberButton('3'),
                                   _buildOperatorButton('+'),
                                 ],
                               ),
                               Row(
                                 children: [
                                   _buildNumberButton('4'),
                                   _buildNumberButton('5'),
                                   _buildNumberButton('6'),
                                   _buildOperatorButton('-'),
                                 ],
                               ),
                               Row(
                                 children: [
                                   _buildNumberButton('7'),
                                   _buildNumberButton('8'),
                                   _buildNumberButton('9'),
                                   _buildOperatorButton('*'),
                                 ],
                               ),
                               Row(
                                 children: [
                                   _buildFunctionButton('C'),
                                   _buildNumberButton('0'),
                                   _buildFunctionButton('='),
                                   _buildOperatorButton('/'),
                                 ],
                               ),
                               Row(
                                 children: [
                                   _buildFunctionButton('DEL'),
                                   _buildNumberButton('.'),
                                   // The empty space for the = button can be filled by adjusting the last row or by making the = button take more space
                                 ],
                               ),
                             ],
                           ),
                           // Nút "Thêm giao dịch"
                           Padding(
                             padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 8.0),
                             child: SizedBox(
                               width: double.infinity,
                               child: ElevatedButton(
                                 onPressed: _addTransaction, // gọi hàm thêm
                                 style: ElevatedButton.styleFrom(
                                   backgroundColor: const Color(0xFF2196F3),
                                   foregroundColor: Colors.white,
                                   padding: const EdgeInsets.symmetric(vertical: 16),
                                   shape: RoundedRectangleBorder(
                                     borderRadius: BorderRadius.circular(12),
                                   ),
                                 ),
                                 child: const Text('THÊM GIAO DỊCH', style: TextStyle(fontSize: 18)),
                               ),
                             ),
                           ),
                         ],
                       ),
                     ),
                   ),
                 ],
               ),
    );
  }

  void _showCategorySelectionModal() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => CategorySelectionModal(
        onCategorySelected: (dynamic category) {
          setState(() {
            _selectedCategory = category;
          });
        },
        token: widget.token,
        idnguodung: widget.idnguodung,
        transactionTypes: transactionTypes,
      ),
    );
  }

  Widget _buildNumberButton(String value) {
    return Expanded(
      child: TextButton(
        onPressed: () => _onNumberPressed(value),
        style: TextButton.styleFrom(
          padding: EdgeInsets.zero,
          shape: const RoundedRectangleBorder(),
          backgroundColor: Colors.white,
          side: const BorderSide(color: Colors.grey, width: 0.5), // Thêm viền
        ),
        child: Text(
          value,
          style: const TextStyle(
            fontSize: 24,
            color: Colors.black87, // Màu chữ
          ),
        ),
      ),
    );
  }

  Widget _buildOperatorButton(String operator) {
    return Expanded(
      child: TextButton(
        onPressed: () => _onOperatorPressed(operator),
        style: TextButton.styleFrom(
          padding: EdgeInsets.zero,
          shape: const RoundedRectangleBorder(),
          backgroundColor: Colors.blue.shade100, // Màu nền toán tử
          side: const BorderSide(color: Colors.grey, width: 0.5), // Thêm viền
        ),
        child: Text(
          operator,
          style: const TextStyle(
            fontSize: 24,
            color: Colors.blue, // Màu chữ
          ),
        ),
      ),
    );
  }

  Widget _buildFunctionButton(String value) {
    return Expanded(
      child: TextButton(
        onPressed: () {
          if (value == 'C') {
            _onBackspacePressed();
          } else if (value == '=') {
            _onEqualsPressed();
          } else if (value == 'DEL') {
            _onClearPressed();
          }
        },
        style: TextButton.styleFrom(
          padding: EdgeInsets.zero,
          shape: const RoundedRectangleBorder(),
          backgroundColor: Colors.white, // Màu nền của nút chức năng
          side: const BorderSide(color: Colors.grey, width: 0.5), // Thêm viền
        ),
        child: Text(
          value == 'DEL' ? 'AC' : value,
          style: const TextStyle(
            fontSize: 24,
            color: Colors.black87, // Màu chữ
          ),
        ),
      ),
    );
  }

  // Chức năng để thêm giao dịch
  Future<void> _addTransaction() async {
    if (_selectedCategory == null || _displayValue == '0' || _displayValue.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Vui lòng chọn danh mục và nhập số tiền.')),
      );
      return;
    }

    final url = Uri.parse('http://10.0.2.2:8081/QuanLyChiTieu/api/transactions');
    final body = jsonEncode({
      'so_tien': double.parse(_displayValue),
      'ghi_chu': noteController.text,
      'ngay': DateFormat('dd/MM/yyyy').format(_selectedDate),
      'id_danhmuc': _selectedCategory!['id_danhmuc'],
      'id_loai': _selectedCategory!['id_loai'],
      'id_nguoidung': widget.idnguodung,
    });

    try {
      final response = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer ${widget.token}',
        },
        body: body,
      );

      if (response.statusCode == 201) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Thêm giao dịch thành công!')),
        );
        Navigator.pop(context, true); // Quay lại trang trước và làm mới dữ liệu
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Thêm giao dịch thất bại: ${response.statusCode}')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Lỗi khi thêm giao dịch: $e')),
      );
    }
  }
}