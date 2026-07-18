// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'app_database.dart';

// ignore_for_file: type=lint
class $SettingsEntriesTable extends SettingsEntries
    with TableInfo<$SettingsEntriesTable, SettingsEntry> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $SettingsEntriesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _keyMeta = const VerificationMeta('key');
  @override
  late final GeneratedColumn<String> key = GeneratedColumn<String>(
      'key', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _valueMeta = const VerificationMeta('value');
  @override
  late final GeneratedColumn<String> value = GeneratedColumn<String>(
      'value', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  @override
  List<GeneratedColumn> get $columns => [key, value];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'settings_entries';
  @override
  VerificationContext validateIntegrity(Insertable<SettingsEntry> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('key')) {
      context.handle(
          _keyMeta, key.isAcceptableOrUnknown(data['key']!, _keyMeta));
    } else if (isInserting) {
      context.missing(_keyMeta);
    }
    if (data.containsKey('value')) {
      context.handle(
          _valueMeta, value.isAcceptableOrUnknown(data['value']!, _valueMeta));
    } else if (isInserting) {
      context.missing(_valueMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {key};
  @override
  SettingsEntry map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return SettingsEntry(
      key: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}key'])!,
      value: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}value'])!,
    );
  }

  @override
  $SettingsEntriesTable createAlias(String alias) {
    return $SettingsEntriesTable(attachedDatabase, alias);
  }
}

class SettingsEntry extends DataClass implements Insertable<SettingsEntry> {
  final String key;
  final String value;
  const SettingsEntry({required this.key, required this.value});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['key'] = Variable<String>(key);
    map['value'] = Variable<String>(value);
    return map;
  }

  SettingsEntriesCompanion toCompanion(bool nullToAbsent) {
    return SettingsEntriesCompanion(
      key: Value(key),
      value: Value(value),
    );
  }

  factory SettingsEntry.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return SettingsEntry(
      key: serializer.fromJson<String>(json['key']),
      value: serializer.fromJson<String>(json['value']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'key': serializer.toJson<String>(key),
      'value': serializer.toJson<String>(value),
    };
  }

  SettingsEntry copyWith({String? key, String? value}) => SettingsEntry(
        key: key ?? this.key,
        value: value ?? this.value,
      );
  SettingsEntry copyWithCompanion(SettingsEntriesCompanion data) {
    return SettingsEntry(
      key: data.key.present ? data.key.value : this.key,
      value: data.value.present ? data.value.value : this.value,
    );
  }

  @override
  String toString() {
    return (StringBuffer('SettingsEntry(')
          ..write('key: $key, ')
          ..write('value: $value')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(key, value);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is SettingsEntry &&
          other.key == this.key &&
          other.value == this.value);
}

class SettingsEntriesCompanion extends UpdateCompanion<SettingsEntry> {
  final Value<String> key;
  final Value<String> value;
  final Value<int> rowid;
  const SettingsEntriesCompanion({
    this.key = const Value.absent(),
    this.value = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  SettingsEntriesCompanion.insert({
    required String key,
    required String value,
    this.rowid = const Value.absent(),
  })  : key = Value(key),
        value = Value(value);
  static Insertable<SettingsEntry> custom({
    Expression<String>? key,
    Expression<String>? value,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (key != null) 'key': key,
      if (value != null) 'value': value,
      if (rowid != null) 'rowid': rowid,
    });
  }

  SettingsEntriesCompanion copyWith(
      {Value<String>? key, Value<String>? value, Value<int>? rowid}) {
    return SettingsEntriesCompanion(
      key: key ?? this.key,
      value: value ?? this.value,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (key.present) {
      map['key'] = Variable<String>(key.value);
    }
    if (value.present) {
      map['value'] = Variable<String>(value.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('SettingsEntriesCompanion(')
          ..write('key: $key, ')
          ..write('value: $value, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $ReadingHistoriesTable extends ReadingHistories
    with TableInfo<$ReadingHistoriesTable, ReadingHistory> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $ReadingHistoriesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _uidMeta = const VerificationMeta('uid');
  @override
  late final GeneratedColumn<String> uid = GeneratedColumn<String>(
      'uid', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _tidMeta = const VerificationMeta('tid');
  @override
  late final GeneratedColumn<String> tid = GeneratedColumn<String>(
      'tid', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _subjectMeta =
      const VerificationMeta('subject');
  @override
  late final GeneratedColumn<String> subject = GeneratedColumn<String>(
      'subject', aliasedName, false,
      type: DriftSqlType.string,
      requiredDuringInsert: false,
      defaultValue: const Constant(''));
  static const VerificationMeta _authorMeta = const VerificationMeta('author');
  @override
  late final GeneratedColumn<String> author = GeneratedColumn<String>(
      'author', aliasedName, false,
      type: DriftSqlType.string,
      requiredDuringInsert: false,
      defaultValue: const Constant(''));
  static const VerificationMeta _fidMeta = const VerificationMeta('fid');
  @override
  late final GeneratedColumn<String> fid = GeneratedColumn<String>(
      'fid', aliasedName, false,
      type: DriftSqlType.string,
      requiredDuringInsert: false,
      defaultValue: const Constant(''));
  static const VerificationMeta _lastReadPageMeta =
      const VerificationMeta('lastReadPage');
  @override
  late final GeneratedColumn<int> lastReadPage = GeneratedColumn<int>(
      'last_read_page', aliasedName, false,
      type: DriftSqlType.int,
      requiredDuringInsert: false,
      defaultValue: const Constant(1));
  static const VerificationMeta _lastReadFloorMeta =
      const VerificationMeta('lastReadFloor');
  @override
  late final GeneratedColumn<int> lastReadFloor = GeneratedColumn<int>(
      'last_read_floor', aliasedName, false,
      type: DriftSqlType.int,
      requiredDuringInsert: false,
      defaultValue: const Constant(1));
  static const VerificationMeta _totalPagesMeta =
      const VerificationMeta('totalPages');
  @override
  late final GeneratedColumn<int> totalPages = GeneratedColumn<int>(
      'total_pages', aliasedName, false,
      type: DriftSqlType.int,
      requiredDuringInsert: false,
      defaultValue: const Constant(1));
  static const VerificationMeta _totalRepliesMeta =
      const VerificationMeta('totalReplies');
  @override
  late final GeneratedColumn<int> totalReplies = GeneratedColumn<int>(
      'total_replies', aliasedName, false,
      type: DriftSqlType.int,
      requiredDuringInsert: false,
      defaultValue: const Constant(0));
  static const VerificationMeta _perPageMeta =
      const VerificationMeta('perPage');
  @override
  late final GeneratedColumn<int> perPage = GeneratedColumn<int>(
      'per_page', aliasedName, false,
      type: DriftSqlType.int,
      requiredDuringInsert: false,
      defaultValue: const Constant(0));
  static const VerificationMeta _lastReadAtMeta =
      const VerificationMeta('lastReadAt');
  @override
  late final GeneratedColumn<int> lastReadAt = GeneratedColumn<int>(
      'last_read_at', aliasedName, false,
      type: DriftSqlType.int, requiredDuringInsert: true);
  static const VerificationMeta _firstReadAtMeta =
      const VerificationMeta('firstReadAt');
  @override
  late final GeneratedColumn<int> firstReadAt = GeneratedColumn<int>(
      'first_read_at', aliasedName, false,
      type: DriftSqlType.int, requiredDuringInsert: true);
  static const VerificationMeta _readCountMeta =
      const VerificationMeta('readCount');
  @override
  late final GeneratedColumn<int> readCount = GeneratedColumn<int>(
      'read_count', aliasedName, false,
      type: DriftSqlType.int,
      requiredDuringInsert: false,
      defaultValue: const Constant(1));
  @override
  List<GeneratedColumn> get $columns => [
        uid,
        tid,
        subject,
        author,
        fid,
        lastReadPage,
        lastReadFloor,
        totalPages,
        totalReplies,
        perPage,
        lastReadAt,
        firstReadAt,
        readCount
      ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'reading_histories';
  @override
  VerificationContext validateIntegrity(Insertable<ReadingHistory> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('uid')) {
      context.handle(
          _uidMeta, uid.isAcceptableOrUnknown(data['uid']!, _uidMeta));
    } else if (isInserting) {
      context.missing(_uidMeta);
    }
    if (data.containsKey('tid')) {
      context.handle(
          _tidMeta, tid.isAcceptableOrUnknown(data['tid']!, _tidMeta));
    } else if (isInserting) {
      context.missing(_tidMeta);
    }
    if (data.containsKey('subject')) {
      context.handle(_subjectMeta,
          subject.isAcceptableOrUnknown(data['subject']!, _subjectMeta));
    }
    if (data.containsKey('author')) {
      context.handle(_authorMeta,
          author.isAcceptableOrUnknown(data['author']!, _authorMeta));
    }
    if (data.containsKey('fid')) {
      context.handle(
          _fidMeta, fid.isAcceptableOrUnknown(data['fid']!, _fidMeta));
    }
    if (data.containsKey('last_read_page')) {
      context.handle(
          _lastReadPageMeta,
          lastReadPage.isAcceptableOrUnknown(
              data['last_read_page']!, _lastReadPageMeta));
    }
    if (data.containsKey('last_read_floor')) {
      context.handle(
          _lastReadFloorMeta,
          lastReadFloor.isAcceptableOrUnknown(
              data['last_read_floor']!, _lastReadFloorMeta));
    }
    if (data.containsKey('total_pages')) {
      context.handle(
          _totalPagesMeta,
          totalPages.isAcceptableOrUnknown(
              data['total_pages']!, _totalPagesMeta));
    }
    if (data.containsKey('total_replies')) {
      context.handle(
          _totalRepliesMeta,
          totalReplies.isAcceptableOrUnknown(
              data['total_replies']!, _totalRepliesMeta));
    }
    if (data.containsKey('per_page')) {
      context.handle(_perPageMeta,
          perPage.isAcceptableOrUnknown(data['per_page']!, _perPageMeta));
    }
    if (data.containsKey('last_read_at')) {
      context.handle(
          _lastReadAtMeta,
          lastReadAt.isAcceptableOrUnknown(
              data['last_read_at']!, _lastReadAtMeta));
    } else if (isInserting) {
      context.missing(_lastReadAtMeta);
    }
    if (data.containsKey('first_read_at')) {
      context.handle(
          _firstReadAtMeta,
          firstReadAt.isAcceptableOrUnknown(
              data['first_read_at']!, _firstReadAtMeta));
    } else if (isInserting) {
      context.missing(_firstReadAtMeta);
    }
    if (data.containsKey('read_count')) {
      context.handle(_readCountMeta,
          readCount.isAcceptableOrUnknown(data['read_count']!, _readCountMeta));
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {uid, tid};
  @override
  ReadingHistory map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return ReadingHistory(
      uid: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}uid'])!,
      tid: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}tid'])!,
      subject: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}subject'])!,
      author: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}author'])!,
      fid: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}fid'])!,
      lastReadPage: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}last_read_page'])!,
      lastReadFloor: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}last_read_floor'])!,
      totalPages: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}total_pages'])!,
      totalReplies: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}total_replies'])!,
      perPage: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}per_page'])!,
      lastReadAt: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}last_read_at'])!,
      firstReadAt: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}first_read_at'])!,
      readCount: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}read_count'])!,
    );
  }

  @override
  $ReadingHistoriesTable createAlias(String alias) {
    return $ReadingHistoriesTable(attachedDatabase, alias);
  }
}

class ReadingHistory extends DataClass implements Insertable<ReadingHistory> {
  final String uid;
  final String tid;
  final String subject;
  final String author;
  final String fid;
  final int lastReadPage;
  final int lastReadFloor;
  final int totalPages;
  final int totalReplies;
  final int perPage;
  final int lastReadAt;
  final int firstReadAt;
  final int readCount;
  const ReadingHistory(
      {required this.uid,
      required this.tid,
      required this.subject,
      required this.author,
      required this.fid,
      required this.lastReadPage,
      required this.lastReadFloor,
      required this.totalPages,
      required this.totalReplies,
      required this.perPage,
      required this.lastReadAt,
      required this.firstReadAt,
      required this.readCount});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['uid'] = Variable<String>(uid);
    map['tid'] = Variable<String>(tid);
    map['subject'] = Variable<String>(subject);
    map['author'] = Variable<String>(author);
    map['fid'] = Variable<String>(fid);
    map['last_read_page'] = Variable<int>(lastReadPage);
    map['last_read_floor'] = Variable<int>(lastReadFloor);
    map['total_pages'] = Variable<int>(totalPages);
    map['total_replies'] = Variable<int>(totalReplies);
    map['per_page'] = Variable<int>(perPage);
    map['last_read_at'] = Variable<int>(lastReadAt);
    map['first_read_at'] = Variable<int>(firstReadAt);
    map['read_count'] = Variable<int>(readCount);
    return map;
  }

  ReadingHistoriesCompanion toCompanion(bool nullToAbsent) {
    return ReadingHistoriesCompanion(
      uid: Value(uid),
      tid: Value(tid),
      subject: Value(subject),
      author: Value(author),
      fid: Value(fid),
      lastReadPage: Value(lastReadPage),
      lastReadFloor: Value(lastReadFloor),
      totalPages: Value(totalPages),
      totalReplies: Value(totalReplies),
      perPage: Value(perPage),
      lastReadAt: Value(lastReadAt),
      firstReadAt: Value(firstReadAt),
      readCount: Value(readCount),
    );
  }

  factory ReadingHistory.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return ReadingHistory(
      uid: serializer.fromJson<String>(json['uid']),
      tid: serializer.fromJson<String>(json['tid']),
      subject: serializer.fromJson<String>(json['subject']),
      author: serializer.fromJson<String>(json['author']),
      fid: serializer.fromJson<String>(json['fid']),
      lastReadPage: serializer.fromJson<int>(json['lastReadPage']),
      lastReadFloor: serializer.fromJson<int>(json['lastReadFloor']),
      totalPages: serializer.fromJson<int>(json['totalPages']),
      totalReplies: serializer.fromJson<int>(json['totalReplies']),
      perPage: serializer.fromJson<int>(json['perPage']),
      lastReadAt: serializer.fromJson<int>(json['lastReadAt']),
      firstReadAt: serializer.fromJson<int>(json['firstReadAt']),
      readCount: serializer.fromJson<int>(json['readCount']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'uid': serializer.toJson<String>(uid),
      'tid': serializer.toJson<String>(tid),
      'subject': serializer.toJson<String>(subject),
      'author': serializer.toJson<String>(author),
      'fid': serializer.toJson<String>(fid),
      'lastReadPage': serializer.toJson<int>(lastReadPage),
      'lastReadFloor': serializer.toJson<int>(lastReadFloor),
      'totalPages': serializer.toJson<int>(totalPages),
      'totalReplies': serializer.toJson<int>(totalReplies),
      'perPage': serializer.toJson<int>(perPage),
      'lastReadAt': serializer.toJson<int>(lastReadAt),
      'firstReadAt': serializer.toJson<int>(firstReadAt),
      'readCount': serializer.toJson<int>(readCount),
    };
  }

  ReadingHistory copyWith(
          {String? uid,
          String? tid,
          String? subject,
          String? author,
          String? fid,
          int? lastReadPage,
          int? lastReadFloor,
          int? totalPages,
          int? totalReplies,
          int? perPage,
          int? lastReadAt,
          int? firstReadAt,
          int? readCount}) =>
      ReadingHistory(
        uid: uid ?? this.uid,
        tid: tid ?? this.tid,
        subject: subject ?? this.subject,
        author: author ?? this.author,
        fid: fid ?? this.fid,
        lastReadPage: lastReadPage ?? this.lastReadPage,
        lastReadFloor: lastReadFloor ?? this.lastReadFloor,
        totalPages: totalPages ?? this.totalPages,
        totalReplies: totalReplies ?? this.totalReplies,
        perPage: perPage ?? this.perPage,
        lastReadAt: lastReadAt ?? this.lastReadAt,
        firstReadAt: firstReadAt ?? this.firstReadAt,
        readCount: readCount ?? this.readCount,
      );
  ReadingHistory copyWithCompanion(ReadingHistoriesCompanion data) {
    return ReadingHistory(
      uid: data.uid.present ? data.uid.value : this.uid,
      tid: data.tid.present ? data.tid.value : this.tid,
      subject: data.subject.present ? data.subject.value : this.subject,
      author: data.author.present ? data.author.value : this.author,
      fid: data.fid.present ? data.fid.value : this.fid,
      lastReadPage: data.lastReadPage.present
          ? data.lastReadPage.value
          : this.lastReadPage,
      lastReadFloor: data.lastReadFloor.present
          ? data.lastReadFloor.value
          : this.lastReadFloor,
      totalPages:
          data.totalPages.present ? data.totalPages.value : this.totalPages,
      totalReplies: data.totalReplies.present
          ? data.totalReplies.value
          : this.totalReplies,
      perPage: data.perPage.present ? data.perPage.value : this.perPage,
      lastReadAt:
          data.lastReadAt.present ? data.lastReadAt.value : this.lastReadAt,
      firstReadAt:
          data.firstReadAt.present ? data.firstReadAt.value : this.firstReadAt,
      readCount: data.readCount.present ? data.readCount.value : this.readCount,
    );
  }

  @override
  String toString() {
    return (StringBuffer('ReadingHistory(')
          ..write('uid: $uid, ')
          ..write('tid: $tid, ')
          ..write('subject: $subject, ')
          ..write('author: $author, ')
          ..write('fid: $fid, ')
          ..write('lastReadPage: $lastReadPage, ')
          ..write('lastReadFloor: $lastReadFloor, ')
          ..write('totalPages: $totalPages, ')
          ..write('totalReplies: $totalReplies, ')
          ..write('perPage: $perPage, ')
          ..write('lastReadAt: $lastReadAt, ')
          ..write('firstReadAt: $firstReadAt, ')
          ..write('readCount: $readCount')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
      uid,
      tid,
      subject,
      author,
      fid,
      lastReadPage,
      lastReadFloor,
      totalPages,
      totalReplies,
      perPage,
      lastReadAt,
      firstReadAt,
      readCount);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ReadingHistory &&
          other.uid == this.uid &&
          other.tid == this.tid &&
          other.subject == this.subject &&
          other.author == this.author &&
          other.fid == this.fid &&
          other.lastReadPage == this.lastReadPage &&
          other.lastReadFloor == this.lastReadFloor &&
          other.totalPages == this.totalPages &&
          other.totalReplies == this.totalReplies &&
          other.perPage == this.perPage &&
          other.lastReadAt == this.lastReadAt &&
          other.firstReadAt == this.firstReadAt &&
          other.readCount == this.readCount);
}

class ReadingHistoriesCompanion extends UpdateCompanion<ReadingHistory> {
  final Value<String> uid;
  final Value<String> tid;
  final Value<String> subject;
  final Value<String> author;
  final Value<String> fid;
  final Value<int> lastReadPage;
  final Value<int> lastReadFloor;
  final Value<int> totalPages;
  final Value<int> totalReplies;
  final Value<int> perPage;
  final Value<int> lastReadAt;
  final Value<int> firstReadAt;
  final Value<int> readCount;
  final Value<int> rowid;
  const ReadingHistoriesCompanion({
    this.uid = const Value.absent(),
    this.tid = const Value.absent(),
    this.subject = const Value.absent(),
    this.author = const Value.absent(),
    this.fid = const Value.absent(),
    this.lastReadPage = const Value.absent(),
    this.lastReadFloor = const Value.absent(),
    this.totalPages = const Value.absent(),
    this.totalReplies = const Value.absent(),
    this.perPage = const Value.absent(),
    this.lastReadAt = const Value.absent(),
    this.firstReadAt = const Value.absent(),
    this.readCount = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  ReadingHistoriesCompanion.insert({
    required String uid,
    required String tid,
    this.subject = const Value.absent(),
    this.author = const Value.absent(),
    this.fid = const Value.absent(),
    this.lastReadPage = const Value.absent(),
    this.lastReadFloor = const Value.absent(),
    this.totalPages = const Value.absent(),
    this.totalReplies = const Value.absent(),
    this.perPage = const Value.absent(),
    required int lastReadAt,
    required int firstReadAt,
    this.readCount = const Value.absent(),
    this.rowid = const Value.absent(),
  })  : uid = Value(uid),
        tid = Value(tid),
        lastReadAt = Value(lastReadAt),
        firstReadAt = Value(firstReadAt);
  static Insertable<ReadingHistory> custom({
    Expression<String>? uid,
    Expression<String>? tid,
    Expression<String>? subject,
    Expression<String>? author,
    Expression<String>? fid,
    Expression<int>? lastReadPage,
    Expression<int>? lastReadFloor,
    Expression<int>? totalPages,
    Expression<int>? totalReplies,
    Expression<int>? perPage,
    Expression<int>? lastReadAt,
    Expression<int>? firstReadAt,
    Expression<int>? readCount,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (uid != null) 'uid': uid,
      if (tid != null) 'tid': tid,
      if (subject != null) 'subject': subject,
      if (author != null) 'author': author,
      if (fid != null) 'fid': fid,
      if (lastReadPage != null) 'last_read_page': lastReadPage,
      if (lastReadFloor != null) 'last_read_floor': lastReadFloor,
      if (totalPages != null) 'total_pages': totalPages,
      if (totalReplies != null) 'total_replies': totalReplies,
      if (perPage != null) 'per_page': perPage,
      if (lastReadAt != null) 'last_read_at': lastReadAt,
      if (firstReadAt != null) 'first_read_at': firstReadAt,
      if (readCount != null) 'read_count': readCount,
      if (rowid != null) 'rowid': rowid,
    });
  }

  ReadingHistoriesCompanion copyWith(
      {Value<String>? uid,
      Value<String>? tid,
      Value<String>? subject,
      Value<String>? author,
      Value<String>? fid,
      Value<int>? lastReadPage,
      Value<int>? lastReadFloor,
      Value<int>? totalPages,
      Value<int>? totalReplies,
      Value<int>? perPage,
      Value<int>? lastReadAt,
      Value<int>? firstReadAt,
      Value<int>? readCount,
      Value<int>? rowid}) {
    return ReadingHistoriesCompanion(
      uid: uid ?? this.uid,
      tid: tid ?? this.tid,
      subject: subject ?? this.subject,
      author: author ?? this.author,
      fid: fid ?? this.fid,
      lastReadPage: lastReadPage ?? this.lastReadPage,
      lastReadFloor: lastReadFloor ?? this.lastReadFloor,
      totalPages: totalPages ?? this.totalPages,
      totalReplies: totalReplies ?? this.totalReplies,
      perPage: perPage ?? this.perPage,
      lastReadAt: lastReadAt ?? this.lastReadAt,
      firstReadAt: firstReadAt ?? this.firstReadAt,
      readCount: readCount ?? this.readCount,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (uid.present) {
      map['uid'] = Variable<String>(uid.value);
    }
    if (tid.present) {
      map['tid'] = Variable<String>(tid.value);
    }
    if (subject.present) {
      map['subject'] = Variable<String>(subject.value);
    }
    if (author.present) {
      map['author'] = Variable<String>(author.value);
    }
    if (fid.present) {
      map['fid'] = Variable<String>(fid.value);
    }
    if (lastReadPage.present) {
      map['last_read_page'] = Variable<int>(lastReadPage.value);
    }
    if (lastReadFloor.present) {
      map['last_read_floor'] = Variable<int>(lastReadFloor.value);
    }
    if (totalPages.present) {
      map['total_pages'] = Variable<int>(totalPages.value);
    }
    if (totalReplies.present) {
      map['total_replies'] = Variable<int>(totalReplies.value);
    }
    if (perPage.present) {
      map['per_page'] = Variable<int>(perPage.value);
    }
    if (lastReadAt.present) {
      map['last_read_at'] = Variable<int>(lastReadAt.value);
    }
    if (firstReadAt.present) {
      map['first_read_at'] = Variable<int>(firstReadAt.value);
    }
    if (readCount.present) {
      map['read_count'] = Variable<int>(readCount.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('ReadingHistoriesCompanion(')
          ..write('uid: $uid, ')
          ..write('tid: $tid, ')
          ..write('subject: $subject, ')
          ..write('author: $author, ')
          ..write('fid: $fid, ')
          ..write('lastReadPage: $lastReadPage, ')
          ..write('lastReadFloor: $lastReadFloor, ')
          ..write('totalPages: $totalPages, ')
          ..write('totalReplies: $totalReplies, ')
          ..write('perPage: $perPage, ')
          ..write('lastReadAt: $lastReadAt, ')
          ..write('firstReadAt: $firstReadAt, ')
          ..write('readCount: $readCount, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $PollVotesTable extends PollVotes
    with TableInfo<$PollVotesTable, PollVote> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $PollVotesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _uidMeta = const VerificationMeta('uid');
  @override
  late final GeneratedColumn<String> uid = GeneratedColumn<String>(
      'uid', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _tidMeta = const VerificationMeta('tid');
  @override
  late final GeneratedColumn<String> tid = GeneratedColumn<String>(
      'tid', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _optionIdsJsonMeta =
      const VerificationMeta('optionIdsJson');
  @override
  late final GeneratedColumn<String> optionIdsJson = GeneratedColumn<String>(
      'option_ids_json', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  @override
  List<GeneratedColumn> get $columns => [uid, tid, optionIdsJson];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'poll_votes';
  @override
  VerificationContext validateIntegrity(Insertable<PollVote> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('uid')) {
      context.handle(
          _uidMeta, uid.isAcceptableOrUnknown(data['uid']!, _uidMeta));
    } else if (isInserting) {
      context.missing(_uidMeta);
    }
    if (data.containsKey('tid')) {
      context.handle(
          _tidMeta, tid.isAcceptableOrUnknown(data['tid']!, _tidMeta));
    } else if (isInserting) {
      context.missing(_tidMeta);
    }
    if (data.containsKey('option_ids_json')) {
      context.handle(
          _optionIdsJsonMeta,
          optionIdsJson.isAcceptableOrUnknown(
              data['option_ids_json']!, _optionIdsJsonMeta));
    } else if (isInserting) {
      context.missing(_optionIdsJsonMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {uid, tid};
  @override
  PollVote map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return PollVote(
      uid: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}uid'])!,
      tid: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}tid'])!,
      optionIdsJson: attachedDatabase.typeMapping.read(
          DriftSqlType.string, data['${effectivePrefix}option_ids_json'])!,
    );
  }

  @override
  $PollVotesTable createAlias(String alias) {
    return $PollVotesTable(attachedDatabase, alias);
  }
}

class PollVote extends DataClass implements Insertable<PollVote> {
  final String uid;
  final String tid;
  final String optionIdsJson;
  const PollVote(
      {required this.uid, required this.tid, required this.optionIdsJson});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['uid'] = Variable<String>(uid);
    map['tid'] = Variable<String>(tid);
    map['option_ids_json'] = Variable<String>(optionIdsJson);
    return map;
  }

  PollVotesCompanion toCompanion(bool nullToAbsent) {
    return PollVotesCompanion(
      uid: Value(uid),
      tid: Value(tid),
      optionIdsJson: Value(optionIdsJson),
    );
  }

  factory PollVote.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return PollVote(
      uid: serializer.fromJson<String>(json['uid']),
      tid: serializer.fromJson<String>(json['tid']),
      optionIdsJson: serializer.fromJson<String>(json['optionIdsJson']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'uid': serializer.toJson<String>(uid),
      'tid': serializer.toJson<String>(tid),
      'optionIdsJson': serializer.toJson<String>(optionIdsJson),
    };
  }

  PollVote copyWith({String? uid, String? tid, String? optionIdsJson}) =>
      PollVote(
        uid: uid ?? this.uid,
        tid: tid ?? this.tid,
        optionIdsJson: optionIdsJson ?? this.optionIdsJson,
      );
  PollVote copyWithCompanion(PollVotesCompanion data) {
    return PollVote(
      uid: data.uid.present ? data.uid.value : this.uid,
      tid: data.tid.present ? data.tid.value : this.tid,
      optionIdsJson: data.optionIdsJson.present
          ? data.optionIdsJson.value
          : this.optionIdsJson,
    );
  }

  @override
  String toString() {
    return (StringBuffer('PollVote(')
          ..write('uid: $uid, ')
          ..write('tid: $tid, ')
          ..write('optionIdsJson: $optionIdsJson')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(uid, tid, optionIdsJson);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is PollVote &&
          other.uid == this.uid &&
          other.tid == this.tid &&
          other.optionIdsJson == this.optionIdsJson);
}

class PollVotesCompanion extends UpdateCompanion<PollVote> {
  final Value<String> uid;
  final Value<String> tid;
  final Value<String> optionIdsJson;
  final Value<int> rowid;
  const PollVotesCompanion({
    this.uid = const Value.absent(),
    this.tid = const Value.absent(),
    this.optionIdsJson = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  PollVotesCompanion.insert({
    required String uid,
    required String tid,
    required String optionIdsJson,
    this.rowid = const Value.absent(),
  })  : uid = Value(uid),
        tid = Value(tid),
        optionIdsJson = Value(optionIdsJson);
  static Insertable<PollVote> custom({
    Expression<String>? uid,
    Expression<String>? tid,
    Expression<String>? optionIdsJson,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (uid != null) 'uid': uid,
      if (tid != null) 'tid': tid,
      if (optionIdsJson != null) 'option_ids_json': optionIdsJson,
      if (rowid != null) 'rowid': rowid,
    });
  }

  PollVotesCompanion copyWith(
      {Value<String>? uid,
      Value<String>? tid,
      Value<String>? optionIdsJson,
      Value<int>? rowid}) {
    return PollVotesCompanion(
      uid: uid ?? this.uid,
      tid: tid ?? this.tid,
      optionIdsJson: optionIdsJson ?? this.optionIdsJson,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (uid.present) {
      map['uid'] = Variable<String>(uid.value);
    }
    if (tid.present) {
      map['tid'] = Variable<String>(tid.value);
    }
    if (optionIdsJson.present) {
      map['option_ids_json'] = Variable<String>(optionIdsJson.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('PollVotesCompanion(')
          ..write('uid: $uid, ')
          ..write('tid: $tid, ')
          ..write('optionIdsJson: $optionIdsJson, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $BlacklistEntriesTable extends BlacklistEntries
    with TableInfo<$BlacklistEntriesTable, BlacklistEntry> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $BlacklistEntriesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _uidMeta = const VerificationMeta('uid');
  @override
  late final GeneratedColumn<String> uid = GeneratedColumn<String>(
      'uid', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _usernameMeta =
      const VerificationMeta('username');
  @override
  late final GeneratedColumn<String> username = GeneratedColumn<String>(
      'username', aliasedName, false,
      type: DriftSqlType.string,
      requiredDuringInsert: false,
      defaultValue: const Constant(''));
  static const VerificationMeta _createdAtMeta =
      const VerificationMeta('createdAt');
  @override
  late final GeneratedColumn<int> createdAt = GeneratedColumn<int>(
      'created_at', aliasedName, false,
      type: DriftSqlType.int, requiredDuringInsert: true);
  static const VerificationMeta _reasonMeta = const VerificationMeta('reason');
  @override
  late final GeneratedColumn<String> reason = GeneratedColumn<String>(
      'reason', aliasedName, false,
      type: DriftSqlType.string,
      requiredDuringInsert: false,
      defaultValue: const Constant(''));
  static const VerificationMeta _scopeJsonMeta =
      const VerificationMeta('scopeJson');
  @override
  late final GeneratedColumn<String> scopeJson = GeneratedColumn<String>(
      'scope_json', aliasedName, false,
      type: DriftSqlType.string,
      requiredDuringInsert: false,
      defaultValue: const Constant('[]'));
  @override
  List<GeneratedColumn> get $columns =>
      [uid, username, createdAt, reason, scopeJson];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'blacklist_entries';
  @override
  VerificationContext validateIntegrity(Insertable<BlacklistEntry> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('uid')) {
      context.handle(
          _uidMeta, uid.isAcceptableOrUnknown(data['uid']!, _uidMeta));
    } else if (isInserting) {
      context.missing(_uidMeta);
    }
    if (data.containsKey('username')) {
      context.handle(_usernameMeta,
          username.isAcceptableOrUnknown(data['username']!, _usernameMeta));
    }
    if (data.containsKey('created_at')) {
      context.handle(_createdAtMeta,
          createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta));
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    if (data.containsKey('reason')) {
      context.handle(_reasonMeta,
          reason.isAcceptableOrUnknown(data['reason']!, _reasonMeta));
    }
    if (data.containsKey('scope_json')) {
      context.handle(_scopeJsonMeta,
          scopeJson.isAcceptableOrUnknown(data['scope_json']!, _scopeJsonMeta));
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {uid};
  @override
  BlacklistEntry map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return BlacklistEntry(
      uid: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}uid'])!,
      username: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}username'])!,
      createdAt: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}created_at'])!,
      reason: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}reason'])!,
      scopeJson: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}scope_json'])!,
    );
  }

  @override
  $BlacklistEntriesTable createAlias(String alias) {
    return $BlacklistEntriesTable(attachedDatabase, alias);
  }
}

class BlacklistEntry extends DataClass implements Insertable<BlacklistEntry> {
  final String uid;
  final String username;
  final int createdAt;
  final String reason;
  final String scopeJson;
  const BlacklistEntry(
      {required this.uid,
      required this.username,
      required this.createdAt,
      required this.reason,
      required this.scopeJson});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['uid'] = Variable<String>(uid);
    map['username'] = Variable<String>(username);
    map['created_at'] = Variable<int>(createdAt);
    map['reason'] = Variable<String>(reason);
    map['scope_json'] = Variable<String>(scopeJson);
    return map;
  }

  BlacklistEntriesCompanion toCompanion(bool nullToAbsent) {
    return BlacklistEntriesCompanion(
      uid: Value(uid),
      username: Value(username),
      createdAt: Value(createdAt),
      reason: Value(reason),
      scopeJson: Value(scopeJson),
    );
  }

  factory BlacklistEntry.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return BlacklistEntry(
      uid: serializer.fromJson<String>(json['uid']),
      username: serializer.fromJson<String>(json['username']),
      createdAt: serializer.fromJson<int>(json['createdAt']),
      reason: serializer.fromJson<String>(json['reason']),
      scopeJson: serializer.fromJson<String>(json['scopeJson']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'uid': serializer.toJson<String>(uid),
      'username': serializer.toJson<String>(username),
      'createdAt': serializer.toJson<int>(createdAt),
      'reason': serializer.toJson<String>(reason),
      'scopeJson': serializer.toJson<String>(scopeJson),
    };
  }

  BlacklistEntry copyWith(
          {String? uid,
          String? username,
          int? createdAt,
          String? reason,
          String? scopeJson}) =>
      BlacklistEntry(
        uid: uid ?? this.uid,
        username: username ?? this.username,
        createdAt: createdAt ?? this.createdAt,
        reason: reason ?? this.reason,
        scopeJson: scopeJson ?? this.scopeJson,
      );
  BlacklistEntry copyWithCompanion(BlacklistEntriesCompanion data) {
    return BlacklistEntry(
      uid: data.uid.present ? data.uid.value : this.uid,
      username: data.username.present ? data.username.value : this.username,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      reason: data.reason.present ? data.reason.value : this.reason,
      scopeJson: data.scopeJson.present ? data.scopeJson.value : this.scopeJson,
    );
  }

  @override
  String toString() {
    return (StringBuffer('BlacklistEntry(')
          ..write('uid: $uid, ')
          ..write('username: $username, ')
          ..write('createdAt: $createdAt, ')
          ..write('reason: $reason, ')
          ..write('scopeJson: $scopeJson')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(uid, username, createdAt, reason, scopeJson);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is BlacklistEntry &&
          other.uid == this.uid &&
          other.username == this.username &&
          other.createdAt == this.createdAt &&
          other.reason == this.reason &&
          other.scopeJson == this.scopeJson);
}

class BlacklistEntriesCompanion extends UpdateCompanion<BlacklistEntry> {
  final Value<String> uid;
  final Value<String> username;
  final Value<int> createdAt;
  final Value<String> reason;
  final Value<String> scopeJson;
  final Value<int> rowid;
  const BlacklistEntriesCompanion({
    this.uid = const Value.absent(),
    this.username = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.reason = const Value.absent(),
    this.scopeJson = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  BlacklistEntriesCompanion.insert({
    required String uid,
    this.username = const Value.absent(),
    required int createdAt,
    this.reason = const Value.absent(),
    this.scopeJson = const Value.absent(),
    this.rowid = const Value.absent(),
  })  : uid = Value(uid),
        createdAt = Value(createdAt);
  static Insertable<BlacklistEntry> custom({
    Expression<String>? uid,
    Expression<String>? username,
    Expression<int>? createdAt,
    Expression<String>? reason,
    Expression<String>? scopeJson,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (uid != null) 'uid': uid,
      if (username != null) 'username': username,
      if (createdAt != null) 'created_at': createdAt,
      if (reason != null) 'reason': reason,
      if (scopeJson != null) 'scope_json': scopeJson,
      if (rowid != null) 'rowid': rowid,
    });
  }

  BlacklistEntriesCompanion copyWith(
      {Value<String>? uid,
      Value<String>? username,
      Value<int>? createdAt,
      Value<String>? reason,
      Value<String>? scopeJson,
      Value<int>? rowid}) {
    return BlacklistEntriesCompanion(
      uid: uid ?? this.uid,
      username: username ?? this.username,
      createdAt: createdAt ?? this.createdAt,
      reason: reason ?? this.reason,
      scopeJson: scopeJson ?? this.scopeJson,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (uid.present) {
      map['uid'] = Variable<String>(uid.value);
    }
    if (username.present) {
      map['username'] = Variable<String>(username.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<int>(createdAt.value);
    }
    if (reason.present) {
      map['reason'] = Variable<String>(reason.value);
    }
    if (scopeJson.present) {
      map['scope_json'] = Variable<String>(scopeJson.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('BlacklistEntriesCompanion(')
          ..write('uid: $uid, ')
          ..write('username: $username, ')
          ..write('createdAt: $createdAt, ')
          ..write('reason: $reason, ')
          ..write('scopeJson: $scopeJson, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

abstract class _$AppDatabase extends GeneratedDatabase {
  _$AppDatabase(QueryExecutor e) : super(e);
  $AppDatabaseManager get managers => $AppDatabaseManager(this);
  late final $SettingsEntriesTable settingsEntries =
      $SettingsEntriesTable(this);
  late final $ReadingHistoriesTable readingHistories =
      $ReadingHistoriesTable(this);
  late final $PollVotesTable pollVotes = $PollVotesTable(this);
  late final $BlacklistEntriesTable blacklistEntries =
      $BlacklistEntriesTable(this);
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities =>
      [settingsEntries, readingHistories, pollVotes, blacklistEntries];
}

typedef $$SettingsEntriesTableCreateCompanionBuilder = SettingsEntriesCompanion
    Function({
  required String key,
  required String value,
  Value<int> rowid,
});
typedef $$SettingsEntriesTableUpdateCompanionBuilder = SettingsEntriesCompanion
    Function({
  Value<String> key,
  Value<String> value,
  Value<int> rowid,
});

class $$SettingsEntriesTableFilterComposer
    extends Composer<_$AppDatabase, $SettingsEntriesTable> {
  $$SettingsEntriesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get key => $composableBuilder(
      column: $table.key, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get value => $composableBuilder(
      column: $table.value, builder: (column) => ColumnFilters(column));
}

class $$SettingsEntriesTableOrderingComposer
    extends Composer<_$AppDatabase, $SettingsEntriesTable> {
  $$SettingsEntriesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get key => $composableBuilder(
      column: $table.key, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get value => $composableBuilder(
      column: $table.value, builder: (column) => ColumnOrderings(column));
}

class $$SettingsEntriesTableAnnotationComposer
    extends Composer<_$AppDatabase, $SettingsEntriesTable> {
  $$SettingsEntriesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get key =>
      $composableBuilder(column: $table.key, builder: (column) => column);

  GeneratedColumn<String> get value =>
      $composableBuilder(column: $table.value, builder: (column) => column);
}

class $$SettingsEntriesTableTableManager extends RootTableManager<
    _$AppDatabase,
    $SettingsEntriesTable,
    SettingsEntry,
    $$SettingsEntriesTableFilterComposer,
    $$SettingsEntriesTableOrderingComposer,
    $$SettingsEntriesTableAnnotationComposer,
    $$SettingsEntriesTableCreateCompanionBuilder,
    $$SettingsEntriesTableUpdateCompanionBuilder,
    (
      SettingsEntry,
      BaseReferences<_$AppDatabase, $SettingsEntriesTable, SettingsEntry>
    ),
    SettingsEntry,
    PrefetchHooks Function()> {
  $$SettingsEntriesTableTableManager(
      _$AppDatabase db, $SettingsEntriesTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$SettingsEntriesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$SettingsEntriesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$SettingsEntriesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<String> key = const Value.absent(),
            Value<String> value = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              SettingsEntriesCompanion(
            key: key,
            value: value,
            rowid: rowid,
          ),
          createCompanionCallback: ({
            required String key,
            required String value,
            Value<int> rowid = const Value.absent(),
          }) =>
              SettingsEntriesCompanion.insert(
            key: key,
            value: value,
            rowid: rowid,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ));
}

typedef $$SettingsEntriesTableProcessedTableManager = ProcessedTableManager<
    _$AppDatabase,
    $SettingsEntriesTable,
    SettingsEntry,
    $$SettingsEntriesTableFilterComposer,
    $$SettingsEntriesTableOrderingComposer,
    $$SettingsEntriesTableAnnotationComposer,
    $$SettingsEntriesTableCreateCompanionBuilder,
    $$SettingsEntriesTableUpdateCompanionBuilder,
    (
      SettingsEntry,
      BaseReferences<_$AppDatabase, $SettingsEntriesTable, SettingsEntry>
    ),
    SettingsEntry,
    PrefetchHooks Function()>;
typedef $$ReadingHistoriesTableCreateCompanionBuilder
    = ReadingHistoriesCompanion Function({
  required String uid,
  required String tid,
  Value<String> subject,
  Value<String> author,
  Value<String> fid,
  Value<int> lastReadPage,
  Value<int> lastReadFloor,
  Value<int> totalPages,
  Value<int> totalReplies,
  Value<int> perPage,
  required int lastReadAt,
  required int firstReadAt,
  Value<int> readCount,
  Value<int> rowid,
});
typedef $$ReadingHistoriesTableUpdateCompanionBuilder
    = ReadingHistoriesCompanion Function({
  Value<String> uid,
  Value<String> tid,
  Value<String> subject,
  Value<String> author,
  Value<String> fid,
  Value<int> lastReadPage,
  Value<int> lastReadFloor,
  Value<int> totalPages,
  Value<int> totalReplies,
  Value<int> perPage,
  Value<int> lastReadAt,
  Value<int> firstReadAt,
  Value<int> readCount,
  Value<int> rowid,
});

class $$ReadingHistoriesTableFilterComposer
    extends Composer<_$AppDatabase, $ReadingHistoriesTable> {
  $$ReadingHistoriesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get uid => $composableBuilder(
      column: $table.uid, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get tid => $composableBuilder(
      column: $table.tid, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get subject => $composableBuilder(
      column: $table.subject, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get author => $composableBuilder(
      column: $table.author, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get fid => $composableBuilder(
      column: $table.fid, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get lastReadPage => $composableBuilder(
      column: $table.lastReadPage, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get lastReadFloor => $composableBuilder(
      column: $table.lastReadFloor, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get totalPages => $composableBuilder(
      column: $table.totalPages, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get totalReplies => $composableBuilder(
      column: $table.totalReplies, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get perPage => $composableBuilder(
      column: $table.perPage, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get lastReadAt => $composableBuilder(
      column: $table.lastReadAt, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get firstReadAt => $composableBuilder(
      column: $table.firstReadAt, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get readCount => $composableBuilder(
      column: $table.readCount, builder: (column) => ColumnFilters(column));
}

class $$ReadingHistoriesTableOrderingComposer
    extends Composer<_$AppDatabase, $ReadingHistoriesTable> {
  $$ReadingHistoriesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get uid => $composableBuilder(
      column: $table.uid, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get tid => $composableBuilder(
      column: $table.tid, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get subject => $composableBuilder(
      column: $table.subject, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get author => $composableBuilder(
      column: $table.author, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get fid => $composableBuilder(
      column: $table.fid, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get lastReadPage => $composableBuilder(
      column: $table.lastReadPage,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get lastReadFloor => $composableBuilder(
      column: $table.lastReadFloor,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get totalPages => $composableBuilder(
      column: $table.totalPages, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get totalReplies => $composableBuilder(
      column: $table.totalReplies,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get perPage => $composableBuilder(
      column: $table.perPage, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get lastReadAt => $composableBuilder(
      column: $table.lastReadAt, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get firstReadAt => $composableBuilder(
      column: $table.firstReadAt, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get readCount => $composableBuilder(
      column: $table.readCount, builder: (column) => ColumnOrderings(column));
}

class $$ReadingHistoriesTableAnnotationComposer
    extends Composer<_$AppDatabase, $ReadingHistoriesTable> {
  $$ReadingHistoriesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get uid =>
      $composableBuilder(column: $table.uid, builder: (column) => column);

  GeneratedColumn<String> get tid =>
      $composableBuilder(column: $table.tid, builder: (column) => column);

  GeneratedColumn<String> get subject =>
      $composableBuilder(column: $table.subject, builder: (column) => column);

  GeneratedColumn<String> get author =>
      $composableBuilder(column: $table.author, builder: (column) => column);

  GeneratedColumn<String> get fid =>
      $composableBuilder(column: $table.fid, builder: (column) => column);

  GeneratedColumn<int> get lastReadPage => $composableBuilder(
      column: $table.lastReadPage, builder: (column) => column);

  GeneratedColumn<int> get lastReadFloor => $composableBuilder(
      column: $table.lastReadFloor, builder: (column) => column);

  GeneratedColumn<int> get totalPages => $composableBuilder(
      column: $table.totalPages, builder: (column) => column);

  GeneratedColumn<int> get totalReplies => $composableBuilder(
      column: $table.totalReplies, builder: (column) => column);

  GeneratedColumn<int> get perPage =>
      $composableBuilder(column: $table.perPage, builder: (column) => column);

  GeneratedColumn<int> get lastReadAt => $composableBuilder(
      column: $table.lastReadAt, builder: (column) => column);

  GeneratedColumn<int> get firstReadAt => $composableBuilder(
      column: $table.firstReadAt, builder: (column) => column);

  GeneratedColumn<int> get readCount =>
      $composableBuilder(column: $table.readCount, builder: (column) => column);
}

class $$ReadingHistoriesTableTableManager extends RootTableManager<
    _$AppDatabase,
    $ReadingHistoriesTable,
    ReadingHistory,
    $$ReadingHistoriesTableFilterComposer,
    $$ReadingHistoriesTableOrderingComposer,
    $$ReadingHistoriesTableAnnotationComposer,
    $$ReadingHistoriesTableCreateCompanionBuilder,
    $$ReadingHistoriesTableUpdateCompanionBuilder,
    (
      ReadingHistory,
      BaseReferences<_$AppDatabase, $ReadingHistoriesTable, ReadingHistory>
    ),
    ReadingHistory,
    PrefetchHooks Function()> {
  $$ReadingHistoriesTableTableManager(
      _$AppDatabase db, $ReadingHistoriesTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$ReadingHistoriesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$ReadingHistoriesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$ReadingHistoriesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<String> uid = const Value.absent(),
            Value<String> tid = const Value.absent(),
            Value<String> subject = const Value.absent(),
            Value<String> author = const Value.absent(),
            Value<String> fid = const Value.absent(),
            Value<int> lastReadPage = const Value.absent(),
            Value<int> lastReadFloor = const Value.absent(),
            Value<int> totalPages = const Value.absent(),
            Value<int> totalReplies = const Value.absent(),
            Value<int> perPage = const Value.absent(),
            Value<int> lastReadAt = const Value.absent(),
            Value<int> firstReadAt = const Value.absent(),
            Value<int> readCount = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              ReadingHistoriesCompanion(
            uid: uid,
            tid: tid,
            subject: subject,
            author: author,
            fid: fid,
            lastReadPage: lastReadPage,
            lastReadFloor: lastReadFloor,
            totalPages: totalPages,
            totalReplies: totalReplies,
            perPage: perPage,
            lastReadAt: lastReadAt,
            firstReadAt: firstReadAt,
            readCount: readCount,
            rowid: rowid,
          ),
          createCompanionCallback: ({
            required String uid,
            required String tid,
            Value<String> subject = const Value.absent(),
            Value<String> author = const Value.absent(),
            Value<String> fid = const Value.absent(),
            Value<int> lastReadPage = const Value.absent(),
            Value<int> lastReadFloor = const Value.absent(),
            Value<int> totalPages = const Value.absent(),
            Value<int> totalReplies = const Value.absent(),
            Value<int> perPage = const Value.absent(),
            required int lastReadAt,
            required int firstReadAt,
            Value<int> readCount = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              ReadingHistoriesCompanion.insert(
            uid: uid,
            tid: tid,
            subject: subject,
            author: author,
            fid: fid,
            lastReadPage: lastReadPage,
            lastReadFloor: lastReadFloor,
            totalPages: totalPages,
            totalReplies: totalReplies,
            perPage: perPage,
            lastReadAt: lastReadAt,
            firstReadAt: firstReadAt,
            readCount: readCount,
            rowid: rowid,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ));
}

typedef $$ReadingHistoriesTableProcessedTableManager = ProcessedTableManager<
    _$AppDatabase,
    $ReadingHistoriesTable,
    ReadingHistory,
    $$ReadingHistoriesTableFilterComposer,
    $$ReadingHistoriesTableOrderingComposer,
    $$ReadingHistoriesTableAnnotationComposer,
    $$ReadingHistoriesTableCreateCompanionBuilder,
    $$ReadingHistoriesTableUpdateCompanionBuilder,
    (
      ReadingHistory,
      BaseReferences<_$AppDatabase, $ReadingHistoriesTable, ReadingHistory>
    ),
    ReadingHistory,
    PrefetchHooks Function()>;
typedef $$PollVotesTableCreateCompanionBuilder = PollVotesCompanion Function({
  required String uid,
  required String tid,
  required String optionIdsJson,
  Value<int> rowid,
});
typedef $$PollVotesTableUpdateCompanionBuilder = PollVotesCompanion Function({
  Value<String> uid,
  Value<String> tid,
  Value<String> optionIdsJson,
  Value<int> rowid,
});

class $$PollVotesTableFilterComposer
    extends Composer<_$AppDatabase, $PollVotesTable> {
  $$PollVotesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get uid => $composableBuilder(
      column: $table.uid, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get tid => $composableBuilder(
      column: $table.tid, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get optionIdsJson => $composableBuilder(
      column: $table.optionIdsJson, builder: (column) => ColumnFilters(column));
}

class $$PollVotesTableOrderingComposer
    extends Composer<_$AppDatabase, $PollVotesTable> {
  $$PollVotesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get uid => $composableBuilder(
      column: $table.uid, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get tid => $composableBuilder(
      column: $table.tid, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get optionIdsJson => $composableBuilder(
      column: $table.optionIdsJson,
      builder: (column) => ColumnOrderings(column));
}

class $$PollVotesTableAnnotationComposer
    extends Composer<_$AppDatabase, $PollVotesTable> {
  $$PollVotesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get uid =>
      $composableBuilder(column: $table.uid, builder: (column) => column);

  GeneratedColumn<String> get tid =>
      $composableBuilder(column: $table.tid, builder: (column) => column);

  GeneratedColumn<String> get optionIdsJson => $composableBuilder(
      column: $table.optionIdsJson, builder: (column) => column);
}

class $$PollVotesTableTableManager extends RootTableManager<
    _$AppDatabase,
    $PollVotesTable,
    PollVote,
    $$PollVotesTableFilterComposer,
    $$PollVotesTableOrderingComposer,
    $$PollVotesTableAnnotationComposer,
    $$PollVotesTableCreateCompanionBuilder,
    $$PollVotesTableUpdateCompanionBuilder,
    (PollVote, BaseReferences<_$AppDatabase, $PollVotesTable, PollVote>),
    PollVote,
    PrefetchHooks Function()> {
  $$PollVotesTableTableManager(_$AppDatabase db, $PollVotesTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$PollVotesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$PollVotesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$PollVotesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<String> uid = const Value.absent(),
            Value<String> tid = const Value.absent(),
            Value<String> optionIdsJson = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              PollVotesCompanion(
            uid: uid,
            tid: tid,
            optionIdsJson: optionIdsJson,
            rowid: rowid,
          ),
          createCompanionCallback: ({
            required String uid,
            required String tid,
            required String optionIdsJson,
            Value<int> rowid = const Value.absent(),
          }) =>
              PollVotesCompanion.insert(
            uid: uid,
            tid: tid,
            optionIdsJson: optionIdsJson,
            rowid: rowid,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ));
}

typedef $$PollVotesTableProcessedTableManager = ProcessedTableManager<
    _$AppDatabase,
    $PollVotesTable,
    PollVote,
    $$PollVotesTableFilterComposer,
    $$PollVotesTableOrderingComposer,
    $$PollVotesTableAnnotationComposer,
    $$PollVotesTableCreateCompanionBuilder,
    $$PollVotesTableUpdateCompanionBuilder,
    (PollVote, BaseReferences<_$AppDatabase, $PollVotesTable, PollVote>),
    PollVote,
    PrefetchHooks Function()>;
typedef $$BlacklistEntriesTableCreateCompanionBuilder
    = BlacklistEntriesCompanion Function({
  required String uid,
  Value<String> username,
  required int createdAt,
  Value<String> reason,
  Value<String> scopeJson,
  Value<int> rowid,
});
typedef $$BlacklistEntriesTableUpdateCompanionBuilder
    = BlacklistEntriesCompanion Function({
  Value<String> uid,
  Value<String> username,
  Value<int> createdAt,
  Value<String> reason,
  Value<String> scopeJson,
  Value<int> rowid,
});

class $$BlacklistEntriesTableFilterComposer
    extends Composer<_$AppDatabase, $BlacklistEntriesTable> {
  $$BlacklistEntriesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get uid => $composableBuilder(
      column: $table.uid, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get username => $composableBuilder(
      column: $table.username, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get createdAt => $composableBuilder(
      column: $table.createdAt, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get reason => $composableBuilder(
      column: $table.reason, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get scopeJson => $composableBuilder(
      column: $table.scopeJson, builder: (column) => ColumnFilters(column));
}

class $$BlacklistEntriesTableOrderingComposer
    extends Composer<_$AppDatabase, $BlacklistEntriesTable> {
  $$BlacklistEntriesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get uid => $composableBuilder(
      column: $table.uid, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get username => $composableBuilder(
      column: $table.username, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get createdAt => $composableBuilder(
      column: $table.createdAt, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get reason => $composableBuilder(
      column: $table.reason, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get scopeJson => $composableBuilder(
      column: $table.scopeJson, builder: (column) => ColumnOrderings(column));
}

class $$BlacklistEntriesTableAnnotationComposer
    extends Composer<_$AppDatabase, $BlacklistEntriesTable> {
  $$BlacklistEntriesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get uid =>
      $composableBuilder(column: $table.uid, builder: (column) => column);

  GeneratedColumn<String> get username =>
      $composableBuilder(column: $table.username, builder: (column) => column);

  GeneratedColumn<int> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<String> get reason =>
      $composableBuilder(column: $table.reason, builder: (column) => column);

  GeneratedColumn<String> get scopeJson =>
      $composableBuilder(column: $table.scopeJson, builder: (column) => column);
}

class $$BlacklistEntriesTableTableManager extends RootTableManager<
    _$AppDatabase,
    $BlacklistEntriesTable,
    BlacklistEntry,
    $$BlacklistEntriesTableFilterComposer,
    $$BlacklistEntriesTableOrderingComposer,
    $$BlacklistEntriesTableAnnotationComposer,
    $$BlacklistEntriesTableCreateCompanionBuilder,
    $$BlacklistEntriesTableUpdateCompanionBuilder,
    (
      BlacklistEntry,
      BaseReferences<_$AppDatabase, $BlacklistEntriesTable, BlacklistEntry>
    ),
    BlacklistEntry,
    PrefetchHooks Function()> {
  $$BlacklistEntriesTableTableManager(
      _$AppDatabase db, $BlacklistEntriesTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$BlacklistEntriesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$BlacklistEntriesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$BlacklistEntriesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<String> uid = const Value.absent(),
            Value<String> username = const Value.absent(),
            Value<int> createdAt = const Value.absent(),
            Value<String> reason = const Value.absent(),
            Value<String> scopeJson = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              BlacklistEntriesCompanion(
            uid: uid,
            username: username,
            createdAt: createdAt,
            reason: reason,
            scopeJson: scopeJson,
            rowid: rowid,
          ),
          createCompanionCallback: ({
            required String uid,
            Value<String> username = const Value.absent(),
            required int createdAt,
            Value<String> reason = const Value.absent(),
            Value<String> scopeJson = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              BlacklistEntriesCompanion.insert(
            uid: uid,
            username: username,
            createdAt: createdAt,
            reason: reason,
            scopeJson: scopeJson,
            rowid: rowid,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ));
}

typedef $$BlacklistEntriesTableProcessedTableManager = ProcessedTableManager<
    _$AppDatabase,
    $BlacklistEntriesTable,
    BlacklistEntry,
    $$BlacklistEntriesTableFilterComposer,
    $$BlacklistEntriesTableOrderingComposer,
    $$BlacklistEntriesTableAnnotationComposer,
    $$BlacklistEntriesTableCreateCompanionBuilder,
    $$BlacklistEntriesTableUpdateCompanionBuilder,
    (
      BlacklistEntry,
      BaseReferences<_$AppDatabase, $BlacklistEntriesTable, BlacklistEntry>
    ),
    BlacklistEntry,
    PrefetchHooks Function()>;

class $AppDatabaseManager {
  final _$AppDatabase _db;
  $AppDatabaseManager(this._db);
  $$SettingsEntriesTableTableManager get settingsEntries =>
      $$SettingsEntriesTableTableManager(_db, _db.settingsEntries);
  $$ReadingHistoriesTableTableManager get readingHistories =>
      $$ReadingHistoriesTableTableManager(_db, _db.readingHistories);
  $$PollVotesTableTableManager get pollVotes =>
      $$PollVotesTableTableManager(_db, _db.pollVotes);
  $$BlacklistEntriesTableTableManager get blacklistEntries =>
      $$BlacklistEntriesTableTableManager(_db, _db.blacklistEntries);
}
