import 'dart:convert';
import 'dart:io';

void main() async {
  final client = HttpClient();
  client.userAgent = 'Mozilla/5.0 (Linux; Android 10) AppleWebKit/537.36';
  
  print('=== Testing forumindex ===');
  final req1 = await client.getUrl(Uri.parse('https://stage1st.com/2b/api/mobile/index.php?version=4&module=forumindex'));
  final res1 = await req1.close();
  final body1 = await res1.transform(utf8.decoder).join();
  final json1 = jsonDecode(body1);
  
  final vars = json1['Variables'] as Map<String, dynamic>?;
  if (vars != null) {
    print('Variables keys: ${vars.keys.toList()}');
    final forumlist = vars['forumlist'];
    if (forumlist is List) {
      print('forumlist count: ${forumlist.length}');
      if (forumlist.isNotEmpty) {
        final first = forumlist[0] as Map<String, dynamic>;
        print('First forum keys: ${first.keys.toList()}');
        print('First forum name: ${first['name']}');
        print('First forum fid: ${first['fid']}');
        final forums = first['forums'];
        if (forums is List) {
          print('Subforums count: ${forums.length}');
          if (forums.isNotEmpty) {
            print('First subforum keys: ${(forums[0] as Map).keys.toList()}');
            print('First subforum name: ${(forums[0] as Map)['name']}');
          }
        } else {
          print('forums field type: ${forums?.runtimeType}, value: $forums');
        }
      }
    } else {
      print('forumlist type: ${forumlist?.runtimeType}');
    }
    
    final memberinfo = vars['memberinfo'];
    if (memberinfo is Map) {
      print('\n=== memberinfo ===');
      print('memberinfo keys: ${memberinfo.keys.toList()}');
      print('uid: ${memberinfo['uid']}');
      print('username: ${memberinfo['username']}');
    } else {
      print('\nmemberinfo: $memberinfo');
    }
  } else {
    print('No Variables. Top keys: ${json1.keys.toList()}');
    print('Body (first 3000): ${body1.substring(0, body1.length > 3000 ? 3000 : body1.length)}');
  }
  
  print('\n=== Testing forumdisplay fid=4 ===');
  final req2 = await client.getUrl(Uri.parse('https://stage1st.com/2b/api/mobile/index.php?version=4&module=forumdisplay&fid=4&page=1'));
  final res2 = await req2.close();
  final body2 = await res2.transform(utf8.decoder).join();
  final json2 = jsonDecode(body2);
  
  final vars2 = json2['Variables'] as Map<String, dynamic>?;
  if (vars2 != null) {
    print('Variables keys: ${vars2.keys.toList()}');
    final threads = vars2['forum_threadlist'];
    if (threads is List) {
      print('forum_threadlist count: ${threads.length}');
    }
    print('threads (total count field): ${vars2['threads']}');
    print('perpage: ${vars2['perpage']}');
  } else {
    print('No Variables. Body (first 3000): ${body2.substring(0, body2.length > 3000 ? 3000 : body2.length)}');
  }
  
  client.close();
}
