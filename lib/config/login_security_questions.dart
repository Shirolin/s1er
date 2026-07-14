/// Discuz! 登录安全提问选项（与论坛语言包 / S1-Next 一致）。
///
/// `id` 即登录 POST 的 `questionid`；`0` 表示未设置安全提问。
class LoginSecurityQuestion {
  const LoginSecurityQuestion({required this.id, required this.label});

  final int id;
  final String label;
}

abstract final class LoginSecurityQuestions {
  static const List<LoginSecurityQuestion> all = [
    LoginSecurityQuestion(id: 0, label: '安全提问（未设置请忽略）'),
    LoginSecurityQuestion(id: 1, label: '母亲的名字'),
    LoginSecurityQuestion(id: 2, label: '爷爷的名字'),
    LoginSecurityQuestion(id: 3, label: '父亲出生的城市'),
    LoginSecurityQuestion(id: 4, label: '您其中一位老师的名字'),
    LoginSecurityQuestion(id: 5, label: '您个人计算机的型号'),
    LoginSecurityQuestion(id: 6, label: '您最喜欢的餐馆名称'),
    LoginSecurityQuestion(id: 7, label: '驾驶执照最后四位数字'),
  ];

  static LoginSecurityQuestion byId(int id) =>
      all.firstWhere((q) => q.id == id, orElse: () => all.first);
}
