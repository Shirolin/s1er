import 'notice_item.dart';
import 'private_message_item.dart';

class PmListResult {
  const PmListResult({
    required this.items,
    this.currentPage = 1,
    this.totalPages = 1,
  });

  static const empty = PmListResult(items: []);

  final List<PrivateMessageItem> items;
  final int currentPage;
  final int totalPages;
}

class NoticeListResult {
  const NoticeListResult({
    required this.items,
    this.currentPage = 1,
    this.totalPages = 1,
  });

  static const empty = NoticeListResult(items: []);

  final List<NoticeItem> items;
  final int currentPage;
  final int totalPages;
}
