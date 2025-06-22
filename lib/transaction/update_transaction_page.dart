import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../icon_color_utils.dart';
import '../category/category_selection_modal.dart';
import 'package:intl/intl.dart';
import 'package:math_expressions/math_expressions.dart';

class UpdateTransactionPage extends StatefulWidget {
  final String token;
  final dynamic idnguodung;
  final dynamic transactionData;

  const UpdateTransactionPage({
    super.key,
    required this.token,
    required this.idnguodung,
    required this.transactionData,
  });

  @override
  State<UpdateTransactionPage> createState() => _UpdateTransactionPageState();
}

class _UpdateTransactionPageState extends State<UpdateTransactionPage> with TickerProviderStateMixin {
  late TabController _tabController;
  final TextEditingController noteController = TextEditingController();
  List<dynamic> transactionTypes = [];
  List<dynamic> categories = [];
  bool isLoading = true;
  String _displayValue = '0';
  String _fullExpression = '';
  dynamic? _selectedCategory;
  DateTime _selectedDate = DateTime.now();
  TimeOfDay _selectedTime = TimeOfDay.now();
  bool _isNewNumber = false;
  bool _lastInputWasEquals = false;
  List<dynamic> _colors = [];
  List<dynamic> _icons = [];

  @override
  void initState() {
    super.initState();
    _initializeData();
  }

  Future<void> _initializeData() async {


    setState(() { isLoading = true; });
    await Future.wait([
      _fetchTransactionTypes(),
      _fetchCategories(),
      _fetchColors(),
      _fetchIcons(),
    ]);

    _enrichCategoriesWithIconAndColor();

    _displayValue = (widget.transactionData['so_tien'] as num?)?.toString() ?? '0';
    _fullExpression = _displayValue;
    noteController.text = widget.transactionData['ghi_chu']?.toString() ?? '';

    if (widget.transactionData['ngay'] != null) {
      final dateParts = widget.transactionData['ngay'].split('/');
      //2->yyyy, 1->mm, 0->dd
      _selectedDate = DateTime(int.parse(dateParts[2]),
          int.parse(dateParts[1]),
          int.parse(dateParts[0]));
    }
    // if (widget.transactionData['ngay_gio'] != null) {
    //   try {
    //     final fullDateTime = DateTime.parse(widget.transactionData['ngay_gio']);
    //     _selectedTime = TimeOfDay.fromDateTime(fullDateTime);
    //   } catch (e) {
    //     print('Error parsing ngay_gio: $e. Using current time.');
    //     _selectedTime = TimeOfDay.now();
    //   }
    // } else {
    //   _selectedTime = TimeOfDay.now();
    // }

    if (widget.transactionData['id_danhmuc'] != null && categories.isNotEmpty) {
      final int? transactionCategoryId = int.tryParse(widget.transactionData['id_danhmuc']?.toString() ?? '');
      _selectedCategory = categories.firstWhere( //tìm ptu đầu tiên trong ds thỏa đk
        (cat) => cat['id_danhmuc'] == transactionCategoryId,
        orElse: () { //ko tìm thấy thì thay thế
          return {
            'id_danhmuc': transactionCategoryId,
            'ma_icon': widget.transactionData['ma_icon'] ?? 'f555',
            'ma_mau': widget.transactionData['ma_mau'] ?? '#2196F3',
            'ten_danh_muc': widget.transactionData['ten_danh_muc'] ?? 'Không rõ',
            'id_loai': int.tryParse(widget.transactionData['id_loai']?.toString() ?? ''),
          };
        },
      );
    } else {
      _selectedCategory = {
        'id_danhmuc': null,
        'ma_icon': widget.transactionData['ma_icon'] ?? 'f555',
        'ma_mau': widget.transactionData['ma_mau'] ?? '#2196F3',
        'ten_danh_muc': widget.transactionData['ten_danh_muc'] ?? 'Chọn danh mục',
        'id_loai': int.tryParse(widget.transactionData['id_loai']?.toString() ?? ''),
      };
    }

    setState(() { isLoading = false; });
  }

  @override
  void dispose() {
    if (transactionTypes.isNotEmpty) {
      _tabController.dispose();
    }
    noteController.dispose();
    super.dispose();
  }

  Future<void> _fetchTransactionTypes() async {
    final url = Uri.parse('http://10.0.2.2:8081/QuanLyChiTieu/api/transaction-types');
    try {
      final response = await http.get(url, headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer ${widget.token}',
      });
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        setState(() {
          transactionTypes = data is List ? data : [];
          if (transactionTypes.isNotEmpty) {
             _tabController = TabController(length: transactionTypes.length, vsync: this);
             _tabController.addListener(_onTabChanged);
          }
        });
      } else {
        print('Failed to load transaction types: ${response.statusCode}');
      }
    } catch (e) {
      print('Error fetching transaction types: $e');
    }
  }

  Future<void> _fetchCategories() async {
    final urlDefault = Uri.parse('http://10.0.2.2:8081/QuanLyChiTieu/api/default-categories');
    final urlUser = Uri.parse('http://10.0.2.2:8081/QuanLyChiTieu/api/categories/user/${widget.idnguodung}');


    try {
      final responseDefault = await http.get(urlDefault, headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer ${widget.token}',
      });
      final responseUser = await http.get(urlUser, headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer ${widget.token}',
      });

      List<dynamic> defaultCats = [];
      if (responseDefault.statusCode == 200) {
        defaultCats = (jsonDecode(responseDefault.body) as List).map((cat) => {
          ...cat, //trải ptu
          //ghi đè = bản đã ép kiểu
          'id_danhmuc': int.tryParse(cat['id_danhmuc']?.toString() ?? ''),
          'id_icon': int.tryParse(cat['id_icon']?.toString() ?? ''),
          'id_mau': int.tryParse(cat['id_mau']?.toString() ?? ''),
        }).toList();
      } else {
        print('Failed to load default categories: ${responseDefault.statusCode}');
      }

      List<dynamic> userCats = [];
      if (responseUser.statusCode == 200) {
        userCats = (jsonDecode(responseUser.body) as List).map((cat) => {
          ...cat,
          'id_danhmuc': int.tryParse(cat['id_danhmuc']?.toString() ?? ''),
          'id_icon': int.tryParse(cat['id_icon']?.toString() ?? ''),
          'id_mau': int.tryParse(cat['id_mau']?.toString() ?? ''),
        }).toList();
      } else {
        print('Failed to load user categories: ${responseUser.statusCode}');
      }

      setState(() {
        categories = [...defaultCats, ...userCats];
      });
    } catch (e) {
      print('Error fetching categories: $e');
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

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        setState(() {
          _icons = data is List ? data : [];
        });
      } else {
        print('Failed to load icons: ${response.statusCode}');
      }
    } catch (e) {
      print('Error fetching icons: $e');
    }
  }

  //hàm bổ sung icon và color cho category để hiển thị đầy đủ
  void _enrichCategoriesWithIconAndColor() {
    if (categories.isEmpty || _icons.isEmpty || _colors.isEmpty) {
      print('Skipping category enrichment: categories, icons, or colors are empty.');
      return;
    }

    List<dynamic> enrichedCategories = [];
    for (var category in categories) {
      final int? categoryIconId = int.tryParse(category['id_icon']?.toString() ?? '');
      final int? categoryColorId = int.tryParse(category['id_mau']?.toString() ?? '');

      final iconData = _icons.firstWhere(
        (icon) => icon['id_icon'] == categoryIconId,
        orElse: () => {'ma_icon': 'f555'},
      );
      final colorData = _colors.firstWhere(
        (color) => color['id_mau'] == categoryColorId,
        orElse: () => {'ma_mau': '#2196F3'},
      );

      enrichedCategories.add({
        ...category,
        'ma_icon': iconData['ma_icon'] ?? 'f555',
        'ma_mau': colorData['ma_mau'] ?? '#2196F3',
      });
    }
    setState(() {
      categories = enrichedCategories;
    });
    print('Categories enriched with icon and color data.');
  }

  void _onTabChanged() {
    if (_tabController.indexIsChanging) return;
  }

  Widget _buildHeader() {
    return Container(
      color: const Color(0xFF1565C0),
      padding: const EdgeInsets.only(top: 40, bottom: 20, left: 16, right: 16),
      child: Column(
        children: [
          Row(
            children: [
              IconButton(
                icon: const Icon(Icons.arrow_back, color: Colors.white),
                onPressed: () => Navigator.pop(context),
              ),
              const Spacer(),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
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
              if (_selectedCategory != null)
                 Expanded(
                  child: Text(
                    _selectedCategory?['ten_danh_muc'] ?? '',
                    style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    TextField(
                      controller: TextEditingController(text: _displayValue),
                      textAlign: TextAlign.right,
                      keyboardType: TextInputType.none,
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
                    if (_fullExpression.isNotEmpty)
                      Text(
                        _fullExpression,
                        style: const TextStyle(color: Colors.white70, fontSize: 20),
                        textAlign: TextAlign.right,
                      ),
                  ],
                ),
              ),
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
                             margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                             padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
                             decoration: BoxDecoration(
                               color: Colors.white,
                               borderRadius: BorderRadius.circular(16),
                             ),
                             child: Column(
                               children: [
                                 Row(
                                   children: [
                                     const Icon(Icons.calendar_today, color: Colors.grey),
                                     const SizedBox(width: 8),
                                     const Text('Ngày tháng', style: TextStyle(fontSize: 16)),
                                     const Spacer(),
                                     TextButton(
                                       onPressed: () async {
                                         final date = await showDatePicker(
                                           context: context,
                                           initialDate: _selectedDate,
                                           firstDate: DateTime(2000),
                                           lastDate: DateTime(2100),
                                         );
                                         if (date != null) {
                                           setState(() => _selectedDate = date);
                                         }
                                       },
                                       child: Text(
                                         DateFormat('dd/MM/yyyy').format(_selectedDate),
                                         style: TextStyle(fontSize: 16, color: Colors.black54),
                                       ),
                                     ),
                                     const Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey),
                                   ],
                                 ),
                                 const SizedBox(height: 8),
                                 // Row(
                                 //   children: [
                                 //     const Icon(Icons.access_time, color: Colors.grey),
                                 //     const SizedBox(width: 8),
                                 //     const Text('Thời gian', style: TextStyle(fontSize: 16)),
                                 //     const Spacer(),
                                 //     TextButton(
                                 //       onPressed: () async {
                                 //         final time = await showTimePicker(
                                 //           context: context,
                                 //           initialTime: _selectedTime,
                                 //         );
                                 //         if (time != null) {
                                 //           setState(() => _selectedTime = time);
                                 //         }
                                 //       },
                                 //       child: Text(
                                 //         _selectedTime.format(context),
                                 //         style: TextStyle(fontSize: 16, color: Colors.black54),
                                 //       ),
                                 //     ),
                                 //     const Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey),
                                 //   ],
                                 // ),
                                 const SizedBox(height: 8),
                                 Row(
                                   children: [
                                     const Icon(Icons.edit, color: Colors.grey),
                                     const SizedBox(width: 8),
                                     const Text('Ghi chú', style: TextStyle(fontSize: 16)),
                                     const Spacer(),
                                     Expanded(
                                       child: TextField(
                                         controller: noteController,
                                         decoration: const InputDecoration(
                                           hintText: 'Nhập ghi chú',
                                           border: InputBorder.none,
                                           isDense: true,
                                         ),
                                         textAlign: TextAlign.right,
                                         style: const TextStyle(fontSize: 16, color: Colors.black54),
                                       ),
                                     ),
                                   ],
                                 ),
                               ],
                             ),
                           ),
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
                                 ],
                               ),
                             ],
                           ),
                           Padding(
                             padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 8.0),
                             child: SizedBox(
                               width: double.infinity,
                               child: ElevatedButton(
                                 onPressed: _updateTransaction,
                                 style: ElevatedButton.styleFrom(
                                   backgroundColor: const Color(0xFF2196F3),
                                   foregroundColor: Colors.white,
                                   padding: const EdgeInsets.symmetric(vertical: 16),
                                   shape: RoundedRectangleBorder(
                                     borderRadius: BorderRadius.circular(12),
                                   ),
                                 ),
                                 child: const Text('CẬP NHẬT GIAO DỊCH', style: TextStyle(fontSize: 18)),
                               ),
                             ),
                           ),
                           Padding(
                             padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 8.0),
                             child: SizedBox(
                               width: double.infinity,
                               child: OutlinedButton(
                                 onPressed: _confirmDeleteTransaction,
                                 style: OutlinedButton.styleFrom(
                                   foregroundColor: Colors.red,
                                   side: const BorderSide(color: Colors.red),
                                   padding: const EdgeInsets.symmetric(vertical: 16),
                                   shape: RoundedRectangleBorder(
                                     borderRadius: BorderRadius.circular(12),
                                   ),
                                 ),
                                 child: const Text('XÓA GIAO DỊCH', style: TextStyle(fontSize: 18)),
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

  void _showCategorySelectionModal() async {
    final selected = await showModalBottomSheet<dynamic>( //mở hộp thoại từ dưới màn hình lên
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (BuildContext context) {
        return CategorySelectionModal(
          token: widget.token,
          idnguodung: widget.idnguodung,
          onCategorySelected: (category) {
            setState(() {
              _selectedCategory = category;
            });
          },
          transactionTypes: transactionTypes,
        );
      },
    );

    if (selected != null) {
      setState(() {
        _selectedCategory = selected;
      });
    }
  }

  Widget _buildNumberButton(String value) {
    return Expanded(
      child: TextButton(
        onPressed: () => _onNumberPressed(value),
        style: TextButton.styleFrom(
          padding: EdgeInsets.zero,
          shape: const RoundedRectangleBorder(),
          backgroundColor: Colors.white,
          side: const BorderSide(color: Colors.grey, width: 0.5),
        ),
        child: Text(
          value,
          style: const TextStyle(
            fontSize: 24,
            color: Colors.black87,
          ),
        ),
      ),
    );
  }

  Widget _buildOperatorButton(String value) {
    return Expanded(
      child: TextButton(
        onPressed: () => _onOperatorPressed(value),
        style: TextButton.styleFrom(
          padding: EdgeInsets.zero,
          shape: const RoundedRectangleBorder(),
          backgroundColor: Colors.blue.shade100,
          side: const BorderSide(color: Colors.grey, width: 0.5),
        ),
        child: Text(
          value,
          style: const TextStyle(
            fontSize: 24,
            color: Colors.blue,
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
          backgroundColor: Colors.white,
          side: const BorderSide(color: Colors.grey, width: 0.5),
        ),
        child: Text(
          value == 'DEL' ? 'AC' : value,
          style: const TextStyle(
            fontSize: 24,
            color: Colors.black87,
          ),
        ),
      ),
    );
  }

  void _onNumberPressed(String value) {
    setState(() {
      if (_lastInputWasEquals) {
        _fullExpression = value;
        _displayValue = value;
        _lastInputWasEquals = false;
        _isNewNumber = false;
        return;
      }

      if (_isNewNumber) {
        _displayValue = value;
        _fullExpression += value;
        _isNewNumber = false;
      } else {
        if (_displayValue == '0' && value == '0') return;
        if (_displayValue == '0' && value != '0') {
          _displayValue = value;
          if (_fullExpression.isNotEmpty && _fullExpression.endsWith('0')) {
             _fullExpression = _fullExpression.substring(0, _fullExpression.length - 1) + value;
          } else {
             _fullExpression += value;
          }
        } else {
          _displayValue += value;
          _fullExpression += value;
        }
      }
      _evaluateCurrentExpression();
    });
  }

  void _onOperatorPressed(String operator) {
    setState(() {
      _lastInputWasEquals = false;

      if (_fullExpression.isNotEmpty && _isOperator(_fullExpression[_fullExpression.length - 1])) {
        _fullExpression = _fullExpression.substring(0, _fullExpression.length - 1) + operator;
      } else {
        if (_displayValue != '0' || _fullExpression.isEmpty) {
           _fullExpression += operator;
        } else if (_displayValue == '0' && _fullExpression.isEmpty) {
           _fullExpression = '0' + operator;
        }
      }
      _isNewNumber = true;
      _evaluateCurrentExpression();
    });
  }

  void _onClearPressed() {
    setState(() {
      _displayValue = '0';
      _fullExpression = '';
      _isNewNumber = false;
      _lastInputWasEquals = false;
    });
  }

  void _onBackspacePressed() {
    setState(() {
      _lastInputWasEquals = false;

      if (_displayValue.isNotEmpty && _displayValue != '0') {
        _displayValue = _displayValue.substring(0, _displayValue.length - 1);
        if (_displayValue.isEmpty) {
          _displayValue = '0';
        }
      }

      if (_fullExpression.isNotEmpty) {
        _fullExpression = _fullExpression.substring(0, _fullExpression.length - 1);
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
        String finalExpression = _fullExpression.replaceAll('×', '*').replaceAll('÷', '/');
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
        _fullExpression = _displayValue;
        _isNewNumber = true;
      } catch (e) {
        _displayValue = 'Lỗi';
        _fullExpression = '';
        _isNewNumber = true;
        print('Calculation Error: $e');
      }
    });
  }

  Future<void> _updateTransaction() async {
    if (_selectedCategory == null || _displayValue == '0' || _displayValue.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Vui lòng chọn danh mục và nhập số tiền.')),
      );
      return;
    }

    final url = Uri.parse('http://10.0.2.2:8081/QuanLyChiTieu/api/transactions/${widget.transactionData['id_GD']}');
    final body = jsonEncode({
      'so_tien': double.parse(_displayValue),
      'ghi_chu': noteController.text,
      'ngay': DateFormat('dd/MM/yyyy').format(_selectedDate),
      'id_danhmuc': _selectedCategory!['id_danhmuc'],
      'id_loai': _selectedCategory!['id_loai'],
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

      if (response.statusCode == 200) {
        if (mounted) {
           Navigator.pop(context, true);
        }
      } else {
        print('Cập nhật giao dịch thất bại: ${response.body}');
        if (mounted) {
          Navigator.pop(context, false);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Cập nhật thất bại: ${response.body}')),
          );
        }
      }
    } catch (e) {
      print('Lỗi khi cập nhật giao dịch: $e');
      if (mounted) {
        Navigator.pop(context, false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Lỗi: $e')),
        );
      }
    }
  }

  Future<void> _deleteTransaction() async {
    final transactionId = widget.transactionData['id_GD'];
    final url = Uri.parse('http://10.0.2.2:8081/QuanLyChiTieu/api/transactions/$transactionId');

    try {
      final response = await http.delete(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer ${widget.token}',
        },
      );

      if (response.statusCode == 200 || response.statusCode == 204) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Xóa giao dịch thành công!')),
        );
        Navigator.pop(context, true);
      } else if (response.statusCode == 403) {
         final errorData = jsonDecode(response.body);
         final errorMessage = errorData['message'] ?? 'Bạn không có quyền xóa giao dịch này.';
         ScaffoldMessenger.of(context).showSnackBar(
           SnackBar(content: Text('Xóa giao dịch thất bại: $errorMessage')),
         );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Xóa giao dịch thất bại: ${response.statusCode}')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Lỗi khi xóa giao dịch: $e')),
      );
    }
  }

  void _confirmDeleteTransaction() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Xác nhận xóa'),
          content: const Text('Bạn có chắc chắn muốn xóa giao dịch này không?'),
          actions: <Widget>[
            TextButton(
              child: const Text('Hủy'),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
            TextButton(
              child: const Text('Xóa', style: TextStyle(color: Colors.red)),
              onPressed: () {
                Navigator.of(context).pop();
                _deleteTransaction();
              },
            ),
          ],
        );
      },
    );
  }

  bool _isOperator(String char) {
    return ['+', '-', '*', '/'].contains(char);
  }

  void _evaluateCurrentExpression() {
    try {
      String expressionToEvaluate = _fullExpression.replaceAll('×', '*').replaceAll('÷', '/');
      if (expressionToEvaluate.isEmpty || (expressionToEvaluate.isNotEmpty && _isOperator(expressionToEvaluate[expressionToEvaluate.length - 1]))) {
        _displayValue = '0';
        return;
      }

      Parser p = Parser();
      Expression exp = p.parse(expressionToEvaluate);
      ContextModel cm = ContextModel();
      double eval = exp.evaluate(EvaluationType.REAL, cm);
      _displayValue = eval.toInt().toString();
    } catch (e) {
      // If there's a parsing error for intermediate expressions, keep the _displayValue
      // as the last valid number entered. Don't show 'Error' here.
      // Only _onEqualsPressed should show 'Error' for invalid final expressions.
      // For now, if an error happens during intermediate evaluation, _displayValue won't be updated.
    }
  }
} 