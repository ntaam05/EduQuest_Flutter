// lib/data/mock_questions.dart
// Mock câu hỏi cho 3 bộ đề: Flutter, CSDL, OOP.
// Mỗi bộ có 10 câu hỏi tiếng Việt với giải thích rõ ràng.

import '../models/question.dart';

// ──────────────────────────────────────────
// BỘ 1: Flutter Cơ Bản
// ──────────────────────────────────────────
final List<Question> flutterQuestions = [
  const Question(
    id: 1,
    question: 'Flutter được phát triển bởi công ty nào?',
    options: ['Microsoft', 'Google', 'Apple', 'Meta'],
    correctAnswer: 1, // Google
    explanation: 'Flutter là framework UI mã nguồn mở được phát triển bởi Google, ra mắt lần đầu năm 2018.',
  ),
  const Question(
    id: 2,
    question: 'Ngôn ngữ lập trình chính được sử dụng trong Flutter là gì?',
    options: ['JavaScript', 'Kotlin', 'Dart', 'Swift'],
    correctAnswer: 2, // Dart
    explanation: 'Flutter sử dụng ngôn ngữ Dart — một ngôn ngữ do Google phát triển, được tối ưu cho UI.',
  ),
  const Question(
    id: 3,
    question: 'Widget nào là gốc rễ của mọi ứng dụng Flutter?',
    options: ['Scaffold', 'Container', 'MaterialApp', 'Widget'],
    correctAnswer: 2, // MaterialApp
    explanation: 'MaterialApp là widget cấp cao nhất, cung cấp Theme, Navigation và nhiều tính năng khác.',
  ),
  const Question(
    id: 4,
    question: 'StatelessWidget khác StatefulWidget ở điểm nào?',
    options: [
      'StatelessWidget nhanh hơn',
      'StatelessWidget không thể rebuild UI khi data thay đổi',
      'StatefulWidget không có build method',
      'Không có sự khác biệt'
    ],
    correctAnswer: 1,
    explanation: 'StatelessWidget không có state nội tại — UI không tự rebuild khi data thay đổi. StatefulWidget có State object để quản lý state và trigger rebuild.',
  ),
  const Question(
    id: 5,
    question: 'Hot Reload trong Flutter có tác dụng gì?',
    options: [
      'Khởi động lại hoàn toàn ứng dụng',
      'Cập nhật code mà không mất state hiện tại',
      'Build file APK mới',
      'Xóa cache ứng dụng'
    ],
    correctAnswer: 1,
    explanation: 'Hot Reload inject code mới vào Dart VM mà không reset state — giúp phát triển UI nhanh hơn nhiều.',
  ),
  const Question(
    id: 6,
    question: 'Widget nào dùng để sắp xếp các widget theo chiều dọc?',
    options: ['Row', 'Stack', 'Column', 'Flex'],
    correctAnswer: 2, // Column
    explanation: 'Column sắp xếp children theo chiều dọc (trục Y). Row sắp xếp theo chiều ngang (trục X).',
  ),
  const Question(
    id: 7,
    question: 'pubspec.yaml được dùng để làm gì?',
    options: [
      'Cấu hình database',
      'Quản lý dependencies và assets của project',
      'Viết logic ứng dụng',
      'Khai báo routes'
    ],
    correctAnswer: 1,
    explanation: 'pubspec.yaml là file cấu hình Flutter project: khai báo tên, version, dependencies, assets, fonts...',
  ),
  const Question(
    id: 8,
    question: 'setState() trong StatefulWidget được dùng để làm gì?',
    options: [
      'Khởi tạo state lần đầu',
      'Thông báo cho Flutter rebuild UI khi state thay đổi',
      'Xóa state cũ',
      'Truyền state sang widget con'
    ],
    correctAnswer: 1,
    explanation: 'setState() đánh dấu widget là "dirty" và yêu cầu Flutter gọi lại build() để cập nhật UI.',
  ),
  const Question(
    id: 9,
    question: 'Navigator.push() dùng để làm gì?',
    options: [
      'Xóa màn hình hiện tại',
      'Thêm màn hình mới vào stack navigation',
      'Quay lại màn hình trước',
      'Chuyển tab'
    ],
    correctAnswer: 1,
    explanation: 'Navigator.push() thêm một Route mới vào stack. Navigator.pop() để quay lại.',
  ),
  const Question(
    id: 10,
    question: 'Để hiển thị danh sách dài hiệu quả trong Flutter, nên dùng widget nào?',
    options: ['Column', 'SingleChildScrollView', 'ListView.builder', 'Wrap'],
    correctAnswer: 2,
    explanation: 'ListView.builder() chỉ tạo widget khi cần hiển thị (lazy loading), rất hiệu quả với danh sách dài.',
  ),
];

// ──────────────────────────────────────────
// BỘ 2: Cơ Sở Dữ Liệu
// ──────────────────────────────────────────
final List<Question> databaseQuestions = [
  const Question(
    id: 101,
    question: 'SQL là viết tắt của gì?',
    options: [
      'Structured Query Language',
      'Simple Query Logic',
      'Standard Query List',
      'System Query Language'
    ],
    correctAnswer: 0,
    explanation: 'SQL (Structured Query Language) là ngôn ngữ truy vấn chuẩn để làm việc với cơ sở dữ liệu quan hệ.',
  ),
  const Question(
    id: 102,
    question: 'Lệnh SQL nào được dùng để lấy dữ liệu từ bảng?',
    options: ['INSERT', 'UPDATE', 'SELECT', 'DELETE'],
    correctAnswer: 2, // SELECT
    explanation: 'SELECT dùng để truy vấn và lấy dữ liệu. Cú pháp: SELECT cột FROM bảng WHERE điều_kiện.',
  ),
  const Question(
    id: 103,
    question: 'Primary Key có đặc điểm gì?',
    options: [
      'Có thể trùng lặp',
      'Có thể NULL',
      'Là duy nhất và không NULL',
      'Chỉ có 1 bảng được dùng'
    ],
    correctAnswer: 2,
    explanation: 'Primary Key xác định duy nhất mỗi hàng trong bảng — không được trùng và không được NULL.',
  ),
  const Question(
    id: 104,
    question: 'Foreign Key dùng để làm gì?',
    options: [
      'Tăng tốc truy vấn',
      'Thiết lập mối quan hệ giữa hai bảng',
      'Mã hóa dữ liệu',
      'Đặt tên cột'
    ],
    correctAnswer: 1,
    explanation: 'Foreign Key là cột tham chiếu đến Primary Key của bảng khác, tạo ra mối quan hệ (relationship) giữa các bảng.',
  ),
  const Question(
    id: 105,
    question: 'JOIN nào trả về tất cả hàng từ cả hai bảng, kể cả không khớp?',
    options: ['INNER JOIN', 'LEFT JOIN', 'RIGHT JOIN', 'FULL OUTER JOIN'],
    correctAnswer: 3,
    explanation: 'FULL OUTER JOIN trả về tất cả hàng từ cả hai bảng. Nơi không khớp sẽ được điền NULL.',
  ),
  const Question(
    id: 106,
    question: 'Chỉ mục (Index) trong database có tác dụng gì?',
    options: [
      'Tăng dung lượng lưu trữ',
      'Tăng tốc độ truy vấn tìm kiếm',
      'Mã hóa dữ liệu',
      'Tự động backup'
    ],
    correctAnswer: 1,
    explanation: 'Index tạo cấu trúc dữ liệu phụ giúp database tìm kiếm nhanh hơn, tương tự mục lục sách.',
  ),
  const Question(
    id: 107,
    question: 'Hàm COUNT() trong SQL dùng để làm gì?',
    options: [
      'Tính tổng',
      'Đếm số hàng',
      'Tính trung bình',
      'Tìm giá trị lớn nhất'
    ],
    correctAnswer: 1,
    explanation: 'COUNT() đếm số hàng thỏa mãn điều kiện. VD: SELECT COUNT(*) FROM users;',
  ),
  const Question(
    id: 108,
    question: 'GROUP BY trong SQL được dùng để làm gì?',
    options: [
      'Sắp xếp kết quả',
      'Nhóm các hàng có cùng giá trị cột để dùng aggregate functions',
      'Lọc dữ liệu',
      'Kết hợp bảng'
    ],
    correctAnswer: 1,
    explanation: 'GROUP BY nhóm các hàng có cùng giá trị để áp dụng các hàm tổng hợp (SUM, COUNT, AVG...) cho mỗi nhóm.',
  ),
  const Question(
    id: 109,
    question: 'ACID trong database là gì?',
    options: [
      'Một loại database',
      'Thuộc tính: Atomicity, Consistency, Isolation, Durability',
      'Ngôn ngữ truy vấn',
      'Phương pháp backup'
    ],
    correctAnswer: 1,
    explanation: 'ACID là 4 thuộc tính đảm bảo transaction xử lý đáng tin cậy: Nguyên tử, Nhất quán, Cô lập, Bền vững.',
  ),
  const Question(
    id: 110,
    question: 'NoSQL khác SQL ở điểm nào?',
    options: [
      'NoSQL không có dữ liệu',
      'NoSQL không dùng bảng có cấu trúc cố định',
      'NoSQL nhanh hơn trong mọi trường hợp',
      'NoSQL không hỗ trợ query'
    ],
    correctAnswer: 1,
    explanation: 'NoSQL lưu trữ dữ liệu phi quan hệ (document, key-value, graph...) linh hoạt hơn nhưng hy sinh một số đảm bảo ACID.',
  ),
];

// ──────────────────────────────────────────
// BỘ 3: Lập Trình Hướng Đối Tượng (OOP)
// ──────────────────────────────────────────
final List<Question> oopQuestions = [
  const Question(
    id: 201,
    question: 'OOP là viết tắt của gì?',
    options: [
      'Open Object Programming',
      'Object Oriented Programming',
      'Object Operation Processing',
      'Ordered Object Protocol'
    ],
    correctAnswer: 1,
    explanation: 'OOP (Object-Oriented Programming) là mô hình lập trình tổ chức code xung quanh các đối tượng (objects).',
  ),
  const Question(
    id: 202,
    question: 'Tính đóng gói (Encapsulation) trong OOP có nghĩa là gì?',
    options: [
      'Ẩn chi tiết triển khai, chỉ lộ ra interface cần thiết',
      'Một lớp kế thừa từ nhiều lớp khác',
      'Một method có nhiều cách triển khai',
      'Tạo nhiều object từ một class'
    ],
    correctAnswer: 0,
    explanation: 'Encapsulation bảo vệ dữ liệu bằng cách ẩn implementation chi tiết và chỉ expose ra public interface.',
  ),
  const Question(
    id: 203,
    question: 'Tính kế thừa (Inheritance) cho phép điều gì?',
    options: [
      'Một class dùng thuộc tính và phương thức của class khác',
      'Gọi nhiều constructor cùng lúc',
      'Ẩn dữ liệu khỏi các class khác',
      'Chạy code song song'
    ],
    correctAnswer: 0,
    explanation: 'Inheritance cho phép class con (subclass) kế thừa thuộc tính và phương thức từ class cha (superclass), tái sử dụng code.',
  ),
  const Question(
    id: 204,
    question: 'Polymorphism (Đa hình) có nghĩa là gì?',
    options: [
      'Một class có nhiều tên',
      'Cùng một interface nhưng có nhiều cách triển khai khác nhau',
      'Một object thuộc nhiều class',
      'Method không có tham số'
    ],
    correctAnswer: 1,
    explanation: 'Polymorphism cho phép cùng một method name hoạt động khác nhau tùy class — ví dụ override phương thức draw() cho Circle và Square.',
  ),
  const Question(
    id: 205,
    question: 'Abstract class khác interface ở điểm nào (trong Java/Dart)?',
    options: [
      'Abstract class có thể có implementation, interface thì không (Java)',
      'Abstract class không thể kế thừa',
      'Interface chậm hơn',
      'Không có sự khác biệt'
    ],
    correctAnswer: 0,
    explanation: 'Abstract class có thể chứa method có implementation + abstract method. Interface (trong Java) chỉ khai báo signature.',
  ),
  const Question(
    id: 206,
    question: 'Constructor được dùng để làm gì?',
    options: [
      'Xóa object',
      'Khởi tạo object và các thuộc tính của nó',
      'Kế thừa class cha',
      'Override method'
    ],
    correctAnswer: 1,
    explanation: 'Constructor là phương thức đặc biệt được gọi khi tạo object mới, dùng để khởi tạo giá trị ban đầu cho các thuộc tính.',
  ),
  const Question(
    id: 207,
    question: 'Từ khóa "static" trong class có nghĩa là gì?',
    options: [
      'Thuộc tính không thể thay đổi',
      'Thuộc về class, không thuộc về instance cụ thể',
      'Chạy nhanh hơn',
      'Private method'
    ],
    correctAnswer: 1,
    explanation: 'Static member thuộc về class (dùng chung cho tất cả instance), không cần tạo object để truy cập.',
  ),
  const Question(
    id: 208,
    question: 'Design pattern Singleton đảm bảo điều gì?',
    options: [
      'Class có nhiều instance',
      'Class chỉ có duy nhất một instance trong toàn bộ chương trình',
      'Instance không thể bị xóa',
      'Class không có constructor'
    ],
    correctAnswer: 1,
    explanation: 'Singleton pattern đảm bảo chỉ có một instance của class tồn tại, hữu ích cho database connection, logger, config...',
  ),
  const Question(
    id: 209,
    question: 'Overriding (ghi đè) method khác Overloading (nạp chồng) như thế nào?',
    options: [
      'Override: cùng tên+param, khác class. Overload: cùng class, khác param',
      'Override nhanh hơn Overload',
      'Chúng giống nhau',
      'Overload chỉ dùng cho constructor'
    ],
    correctAnswer: 0,
    explanation: 'Override: class con tái định nghĩa method của class cha (runtime). Overload: cùng tên method nhưng khác số/kiểu tham số (compile time).',
  ),
  const Question(
    id: 210,
    question: 'Interface trong Dart được khai báo bằng từ khóa nào?',
    options: ['interface', 'abstract', 'Dart dùng class thường như interface', 'protocol'],
    correctAnswer: 2,
    explanation: 'Dart không có từ khóa "interface". Mọi class đều có thể được implements như interface. Dùng "abstract class" cho abstract methods.',
  ),
];
