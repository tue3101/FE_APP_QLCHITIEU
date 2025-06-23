import 'package:flutter_local_notifications/flutter_local_notifications.dart';

class NotificationService {
  //tạo một thể hiện duy nhất (singleton instance) của NotificationService.
  //gọi hàm khởi tạo đến constructor riêng tên là _internal của lớp NotificationService.
  static final NotificationService _notificationService = NotificationService._internal();

  //dùng để trả về instance duy nhất (singleton) của lớp NotificationService.
  //factory dùng để trả về đối tượng cũ
  factory NotificationService() {
    return _notificationService;
  }
//Constructor nội bộ để tạo instance
  //hỉ được gọi một lần → để tạo duy nhất một đối tượng của lớp.
  //dùng lại nó qua NotificationService()
  NotificationService._internal();
//cài thư viện   flutter_local_notifications: ^17.1.2 để su dụng
  //FlutterLocalNotificationsPlugin cung cấp các dữ liệu , class, method để xử lý thông báo cục bộ
  final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
      FlutterLocalNotificationsPlugin(); // gửi thông báo cục bộ (local notification)

  Future<void> init() async {
    //AndroidInitializationSettings	Lớp cấu hình để khởi tạo thông báo cho Android
    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('@mipmap/ic_launcher'); //'@mipmap/ic_launcher'	Đường dẫn đến icon của thông báo

    //InitializationSettings	Class cấu hình khởi tạo của flutter_local_notifications (plugin)
    const InitializationSettings initializationSettings = InitializationSettings(
     //	Truyền cấu hình Android vào
      android: initializationSettingsAndroid,
    );

    //flutterLocalNotificationsPlugin	Biến đại diện cho plugin thông báo cục bộ
    //truyền đối tuong cấu hình vào hàm khởi tạo initialize
    await flutterLocalNotificationsPlugin.initialize(initializationSettings);
  }


  //Hàm dùng để hiển thị một thông báo cục bộ
  //truyền 3 tham số : id thông báo, tiêu đề và nội dung thông báo
  Future<void> showNotification(int id, String title, String body) async {
    // AndroidNotificationDetails định nghĩa chi tiết cách mà thông báo hiển thị trên đt
    const AndroidNotificationDetails androidPlatformChannelSpecifics =
        AndroidNotificationDetails(
      'budget_channel_id', //Mã định danh của kênh thông báo (phải là duy nhất)
      'Ngân sách', //Tên hiển thị cho kênh thông báo
      channelDescription: 'Thông báo về tình hình ngân sách',//Mô tả kênh thông báo
      importance: Importance.max, //Mức quan trọng cao nhất (hiển thị thông báo toàn màn hình nếu cần)
      priority: Priority.high, //ưu tiên cao, sẽ báo rung hoặc kèm âm thanh.
      showWhen: true, //Bật/tắt việc hiển thị thời gian thông báo
    );
    //androidPlatformChannelSpecifics	Chi tiết hiển thị thông báo cho Android (AndroidNotificationDetails)
    const NotificationDetails platformChannelSpecifics =
        NotificationDetails(android: androidPlatformChannelSpecifics);
    //platformChannelSpecifics	Truyền vào show() để hiển thị thông báo
    await flutterLocalNotificationsPlugin.show(
      id,
      title,
      body,
      platformChannelSpecifics,
    );
  }
} 