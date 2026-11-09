/// 本机保存的未提交撰写内容，永不写服务端。
///
/// 回复只用 [message]；新主题另用 [subject]、[typeId]；其余字段仅编辑使用。
class ComposeDraft {
  const ComposeDraft({
    required this.message,
    this.subject = '',
    this.typeId,
    this.readPerm,
    this.leadingQuote,
    this.includeQuote,
    this.mediaTags,
    this.mediaSlots,
  });

  /// 正文缺失或不是字符串时返回 null。
  static ComposeDraft? fromJson(Map<String, Object?> json) {
    final message = json['message'];
    if (message is! String) return null;
    final subject = json['subject'];
    final includeQuote = json['includeQuote'];
    final mediaTags = json['mediaTags'];
    final mediaSlots = json['mediaSlots'];
    return ComposeDraft(
      message: message,
      subject: subject is String ? subject : '',
      typeId: _string(json['typeId']),
      readPerm: _string(json['readPerm']),
      leadingQuote: _string(json['leadingQuote']),
      includeQuote: includeQuote is bool ? includeQuote : null,
      mediaTags: mediaTags is List
          ? [for (final tag in mediaTags) tag.toString()]
          : null,
      mediaSlots: mediaSlots is List
          ? [
              for (final slot in mediaSlots)
                slot is int ? slot : int.tryParse(slot.toString()) ?? 0,
            ]
          : null,
    );
  }

  final String message;
  final String subject;
  final String? typeId;
  final String? readPerm;

  /// 编辑页从服务器原文拆出的前置 `[quote]`。
  final String? leadingQuote;
  final bool? includeQuote;
  final List<String>? mediaTags;

  /// 与 [mediaTags] 一一对应的稳定 slot（`⟦图N⟧` 的 N）；缺省视为 1..n。
  final List<int>? mediaSlots;

  static String? _string(Object? value) => value is String ? value : null;
}
