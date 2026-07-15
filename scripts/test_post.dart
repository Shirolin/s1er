import 'dart:io';

void main() async {
  final client = HttpClient()..badCertificateCallback = (_, __, ___) => true;
  final body =
      'formhash=test&fastloginfield=username&username=test&password=test&questionid=0&answer=&cookietime=2592000';

  final req = await client.postUrl(Uri.parse(
      'https://stage1st.com/2b/member.php?mod=logging&action=login&loginsubmit=yes&mobile=2'));
  req.headers.set('Content-Type', 'application/x-www-form-urlencoded');
  req.headers.set('Content-Length', body.length.toString());
  req.headers.set('User-Agent',
      'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36');
  req.bufferOutput = true;
  req.write(body);
  final res = await req.close();
  final text = await res.transform(SystemEncoding().decoder).join();
  print('Status: ${res.statusCode}');
  print(text.substring(0, text.length > 300 ? 300 : text.length));
  client.close();
}
