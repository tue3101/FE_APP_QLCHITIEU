import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

Future<void> exportFromGiaoDich({
  required BuildContext context,
  required int? idNguoiDung,
  required int thang,
  required String token,
}) async {
  print('[DEBUG] Gọi exportFromGiaoDich với thang=$thang, idNguoiDung=$idNguoiDung');
  final url = Uri.parse('http://10.0.2.2:8081/QuanLyChiTieu/api/export/process-transactions');
  final response = await http.post(
    url,
    headers: {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $token',
    },
    body: jsonEncode({
      'thang': thang,
      'id_nguoidung': idNguoiDung,
    }),
  );
  print('[DEBUG] Response status: \'${response.statusCode}\', body: ${response.body}');
  print('[DEBUG] context.mounted: ${context.mounted}');
  if (response.statusCode == 200) {
    if (context.mounted) {
      print('[DEBUG] Hiển thị SnackBar thành công');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Export thành công!')),
      );
    }
  } else {
    if (context.mounted) {
      print('[DEBUG] Hiển thị SnackBar lỗi');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Lỗi export: ${response.body}')),
      );
    }
  }
}

void showExportDialog(BuildContext context, {required int? idNguoiDung, required String token, required int thang}) {
  final rootContext = context; // context của trang Home
  showDialog(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: const Text('Export chi tiêu mẫu'),
      content: const Text('Bạn muốn export chi tiêu mẫu cho cá nhân hay dùng chung?'),
      actions: [
        TextButton(
          onPressed: () async {
            Navigator.pop(dialogContext);
            Future.delayed(const Duration(milliseconds: 200), () async {
              // Kiểm tra đã có export cá nhân chưa
              final checkUrl = Uri.parse('http://10.0.2.2:8081/QuanLyChiTieu/api/chitieumau/user/$idNguoiDung');
              final checkRes = await http.get(
                checkUrl,
                headers: {
                  'Content-Type': 'application/json',
                  'Authorization': 'Bearer $token',
                },
              );
              if (checkRes.statusCode == 200) {
                final data = jsonDecode(checkRes.body);
                if (data is List && data.isNotEmpty) {
                  if (rootContext.mounted) {
                    ScaffoldMessenger.of(rootContext).showSnackBar(
                      const SnackBar(content: Text('Bạn đã có chi tiêu mẫu cá nhân, không thể export nữa!')),
                    );
                  }
                  return;
                }
              }
              // Nếu chưa có thì cho export
              exportFromGiaoDich(
                context: rootContext, // dùng context gốc
                idNguoiDung: idNguoiDung,
                thang: thang,
                token: token,
              );
            });
          },
          child: const Text('đồng ý'),
        ),
        TextButton(
          onPressed: () => Navigator.pop(dialogContext),
          child: const Text('Hủy'),
        ),
      ],
    ),
  );
} 