import 'package:html/parser.dart' show parseFragment;
import '../config/constants.dart';

class BbcodeParser {
  static String parse(String input) {
    if (input.isEmpty) return '';

    var output = input;

    // 1. 预处理：初步清洗干扰标签
    output = _preClean(output);

    // 2. 核心转换：BBCode -> HTML
    output = _convertBbcodeToHtml(output);

    // 3. 后处理：规范化 HTML 结构，确保属性正确
    output = _normalizeHtml(output);

    return output;
  }

  static String _preClean(String text) {
    var output = text;
    // 解转义：有些 API 返回的内容被转义过两次，先把 &lt; 这种还原，方便后续统一处理标签
    output = output.replaceAll('&lt;', '<')
                   .replaceAll('&gt;', '>')
                   .replaceAll('&amp;', '&')
                   .replaceAll('&nbsp;', ' ');
    
    // 解码 Unicode 数字实体：&#x5546; (十六进制) / &#21834; (十进制) -> 对应字符
    output = output.replaceAllMapped(
      RegExp(r'&#x([0-9a-fA-F]+);'),
      (m) => String.fromCharCode(int.parse(m.group(1)!, radix: 16)),
    );
    output = output.replaceAllMapped(
      RegExp(r'&#(\d+);'),
      (m) => String.fromCharCode(int.parse(m.group(1)!)),
    );
    
    // 规范化自闭合标签并处理连续换行
    output = output.replaceAll(RegExp(r'<br\s*/?>', caseSensitive: false), '<br/>');
    
    // 最佳实践：折叠连续换行。
    // Discuz! 数据中常出现 <br/>\n<br/>\n 这种情况，会导致视觉上出现过多空行。
    // 下面的正则匹配：( <br/> 或 \n 或 \r ) 连续出现 3 次及以上的情况
    output = output.replaceAll(RegExp(r'(<br/>\s*|[\n\r]\s*){3,}'), '<br/><br/>');
    
    return output;
  }

  static String _convertBbcodeToHtml(String text) {
    var output = text;

    // 基础行内标签
    output = output.replaceAllMapped(RegExp(r'\[b\](.*?)\[/b\]', dotAll: true), (m) => '<b>${m.group(1)}</b>');
    output = output.replaceAllMapped(RegExp(r'\[i\](.*?)\[/i\]', dotAll: true), (m) => '<i>${m.group(1)}</i>');
    output = output.replaceAllMapped(RegExp(r'\[u\](.*?)\[/u\]', dotAll: true), (m) => '<u>${m.group(1)}</u>');
    output = output.replaceAllMapped(RegExp(r'\[s\](.*?)\[/s\]', dotAll: true), (m) => '<s>${m.group(1)}</s>');

    // 链接
    output = output.replaceAllMapped(RegExp(r'\[url=(.*?)\](.*?)\[/url\]', dotAll: true), (m) => '<a href="${m.group(1)}">${m.group(2)}</a>');
    output = output.replaceAllMapped(RegExp(r'\[url\](.*?)\[/url\]', dotAll: true), (m) => '<a href="${m.group(1)}">${m.group(1)}</a>');

    // 图片
    output = output.replaceAllMapped(RegExp(r'\[img\](.*?)\[/img\]', dotAll: true), (m) => '<img src="${m.group(1)}" />');

    // 颜色与大小
    output = output.replaceAllMapped(RegExp(r'\[color=(.*?)\](.*?)\[/color\]', dotAll: true), (m) => '<span style="color:${m.group(1)}">${m.group(2)}</span>');
    output = output.replaceAllMapped(RegExp(r'\[size=(\d+)\](.*?)\[/size\]', dotAll: true), (m) {
      final size = int.tryParse(m.group(1)!) ?? 14;
      return '<span style="font-size:${size.clamp(10, 24)}px">${m.group(2)}</span>';
    });

    // 结构化标签
    output = output.replaceAllMapped(RegExp(r'\[quote\](.*?)\[/quote\]', dotAll: true), (m) => '<blockquote>${m.group(1)}</blockquote>');
    output = output.replaceAllMapped(RegExp(r'\[code\](.*?)\[/code\]', dotAll: true), (m) => '<pre>${m.group(1)}</pre>');
    output = output.replaceAllMapped(RegExp(r'\[hide\](.*?)\[/hide\]', dotAll: true), (m) => '<span class="hide-content">${m.group(1)}</span>');
    
    // 其他
    output = output.replaceAll(RegExp(r'\[hr\]', caseSensitive: false), '<hr/>');
    
    // 移除末尾多余换行
    output = output.trim();
    
    // 将 \n 转换为 <br/> (在折叠之后处理剩余的单个换行)
    output = output.replaceAll('\n', '<br/>');

    // 表情包 [f:xxx] -> 转换成 span 供 TagExtension 拦截
    output = output.replaceAllMapped(RegExp(r'\[f:(\d+)\]'), (m) => '<span class="emoticon" data-code="f:${m.group(1)}">[emoticon]</span>');

    return output;
  }

  /// 使用 html parser 规范化输出
  static String _normalizeHtml(String html) {
    var output = html;

    // 1. 移除 S1 API 自动生成的 <div class="img"> 等外层包裹
    final fragment = parseFragment(output);
    fragment.querySelectorAll('div.img').forEach((div) {
      final img = div.querySelector('img');
      if (img != null) {
        div.replaceWith(img);
      }
    });
    output = fragment.outerHtml;
    
    // 规范化：统一 html 处理后的换行标签，以便测试匹配 (html parser 可能会输出 <br> 而非 <br/>)
    output = output.replaceAll('<br>', '<br/>');

    // 2. 用正则把表情包 <img> 标签转为 <span>，确保 flutter_html 永远看不到这些 URL
    //    （flutter_html 会对 <img> 做 XHR 预加载，触发 CORS 错误）
    output = output.replaceAllMapped(
      RegExp(r'<img\s[^>]*src="([^"]*)"[^>]*/?>', caseSensitive: false),
      (m) {
        final src = m.group(1) ?? '';
        if (src.isNotEmpty && S1Constants.isEmoticon(src)) {
          return '<span class="emoticon" data-src="$src">[emoticon]</span>';
        }
        return m.group(0)!;
      },
    );

    // 3. 同样处理单引号 src="..." 的情况
    output = output.replaceAllMapped(
      RegExp(r"<img\s[^>]*src='([^']*)'[^>]*/?>", caseSensitive: false),
      (m) {
        final src = m.group(1) ?? '';
        if (src.isNotEmpty && S1Constants.isEmoticon(src)) {
          return '<span class="emoticon" data-src="$src">[emoticon]</span>';
        }
        return m.group(0)!;
      },
    );

    // 3. 同样处理单引号 src="..." 的情况
    output = output.replaceAllMapped(
      RegExp(r"<img\s[^>]*src='([^']*)'[^>]*/?>", caseSensitive: false),
      (m) {
        final src = m.group(1) ?? '';
        if (src.isNotEmpty && S1Constants.isEmoticon(src)) {
          return '<span class="emoticon" data-src="$src">[emoticon]</span>';
        }
        return m.group(0)!;
      },
    );

    return output;
  }

  static List<String> extractImages(String html) {
    final regex = RegExp(r'<img[^>]+src="([^"]+)"');
    return regex.allMatches(html).map((m) => m.group(1)!).toList();
  }

  static String stripTags(String html) {
    return html.replaceAll(RegExp(r'<[^>]*>'), '');
  }
}
