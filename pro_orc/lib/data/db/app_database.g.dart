// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'app_database.dart';

// ignore_for_file: type=lint
class $AppConfigTableTable extends AppConfigTable
    with TableInfo<$AppConfigTableTable, AppConfigTableData> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $AppConfigTableTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _scanDirMeta = const VerificationMeta(
    'scanDir',
  );
  @override
  late final GeneratedColumn<String> scanDir = GeneratedColumn<String>(
    'scan_dir',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant(''),
  );
  static const VerificationMeta _ignoreListJsonMeta = const VerificationMeta(
    'ignoreListJson',
  );
  @override
  late final GeneratedColumn<String> ignoreListJson = GeneratedColumn<String>(
    'ignore_list_json',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('[".*","node_modules","build",".dart_tool"]'),
  );
  static const VerificationMeta _gitBinaryPathMeta = const VerificationMeta(
    'gitBinaryPath',
  );
  @override
  late final GeneratedColumn<String> gitBinaryPath = GeneratedColumn<String>(
    'git_binary_path',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('git'),
  );
  static const VerificationMeta _themeModeMeta = const VerificationMeta(
    'themeMode',
  );
  @override
  late final GeneratedColumn<String> themeMode = GeneratedColumn<String>(
    'theme_mode',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('dark'),
  );
  static const VerificationMeta _vaultDirMeta = const VerificationMeta(
    'vaultDir',
  );
  @override
  late final GeneratedColumn<String> vaultDir = GeneratedColumn<String>(
    'vault_dir',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant(''),
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    scanDir,
    ignoreListJson,
    gitBinaryPath,
    themeMode,
    vaultDir,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'app_config_table';
  @override
  VerificationContext validateIntegrity(
    Insertable<AppConfigTableData> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('scan_dir')) {
      context.handle(
        _scanDirMeta,
        scanDir.isAcceptableOrUnknown(data['scan_dir']!, _scanDirMeta),
      );
    }
    if (data.containsKey('ignore_list_json')) {
      context.handle(
        _ignoreListJsonMeta,
        ignoreListJson.isAcceptableOrUnknown(
          data['ignore_list_json']!,
          _ignoreListJsonMeta,
        ),
      );
    }
    if (data.containsKey('git_binary_path')) {
      context.handle(
        _gitBinaryPathMeta,
        gitBinaryPath.isAcceptableOrUnknown(
          data['git_binary_path']!,
          _gitBinaryPathMeta,
        ),
      );
    }
    if (data.containsKey('theme_mode')) {
      context.handle(
        _themeModeMeta,
        themeMode.isAcceptableOrUnknown(data['theme_mode']!, _themeModeMeta),
      );
    }
    if (data.containsKey('vault_dir')) {
      context.handle(
        _vaultDirMeta,
        vaultDir.isAcceptableOrUnknown(data['vault_dir']!, _vaultDirMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  AppConfigTableData map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return AppConfigTableData(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      scanDir: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}scan_dir'],
      )!,
      ignoreListJson: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}ignore_list_json'],
      )!,
      gitBinaryPath: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}git_binary_path'],
      )!,
      themeMode: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}theme_mode'],
      )!,
      vaultDir: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}vault_dir'],
      )!,
    );
  }

  @override
  $AppConfigTableTable createAlias(String alias) {
    return $AppConfigTableTable(attachedDatabase, alias);
  }
}

class AppConfigTableData extends DataClass
    implements Insertable<AppConfigTableData> {
  final int id;
  final String scanDir;
  final String ignoreListJson;
  final String gitBinaryPath;

  /// One of 'light', 'dark', 'system'. Default 'dark' preserves the existing
  /// look for current users (v2.2 Design-Refresh).
  final String themeMode;

  /// Absolute path to the Obsidian vault root used for the a1 learning-loop
  /// view (M6). Empty string means "use the default" (`$HOME/N3URAL-Vault`),
  /// resolved by the reader — kept empty by default so per-machine HOME is not
  /// baked into the DB.
  final String vaultDir;
  const AppConfigTableData({
    required this.id,
    required this.scanDir,
    required this.ignoreListJson,
    required this.gitBinaryPath,
    required this.themeMode,
    required this.vaultDir,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['scan_dir'] = Variable<String>(scanDir);
    map['ignore_list_json'] = Variable<String>(ignoreListJson);
    map['git_binary_path'] = Variable<String>(gitBinaryPath);
    map['theme_mode'] = Variable<String>(themeMode);
    map['vault_dir'] = Variable<String>(vaultDir);
    return map;
  }

  AppConfigTableCompanion toCompanion(bool nullToAbsent) {
    return AppConfigTableCompanion(
      id: Value(id),
      scanDir: Value(scanDir),
      ignoreListJson: Value(ignoreListJson),
      gitBinaryPath: Value(gitBinaryPath),
      themeMode: Value(themeMode),
      vaultDir: Value(vaultDir),
    );
  }

  factory AppConfigTableData.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return AppConfigTableData(
      id: serializer.fromJson<int>(json['id']),
      scanDir: serializer.fromJson<String>(json['scanDir']),
      ignoreListJson: serializer.fromJson<String>(json['ignoreListJson']),
      gitBinaryPath: serializer.fromJson<String>(json['gitBinaryPath']),
      themeMode: serializer.fromJson<String>(json['themeMode']),
      vaultDir: serializer.fromJson<String>(json['vaultDir']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'scanDir': serializer.toJson<String>(scanDir),
      'ignoreListJson': serializer.toJson<String>(ignoreListJson),
      'gitBinaryPath': serializer.toJson<String>(gitBinaryPath),
      'themeMode': serializer.toJson<String>(themeMode),
      'vaultDir': serializer.toJson<String>(vaultDir),
    };
  }

  AppConfigTableData copyWith({
    int? id,
    String? scanDir,
    String? ignoreListJson,
    String? gitBinaryPath,
    String? themeMode,
    String? vaultDir,
  }) => AppConfigTableData(
    id: id ?? this.id,
    scanDir: scanDir ?? this.scanDir,
    ignoreListJson: ignoreListJson ?? this.ignoreListJson,
    gitBinaryPath: gitBinaryPath ?? this.gitBinaryPath,
    themeMode: themeMode ?? this.themeMode,
    vaultDir: vaultDir ?? this.vaultDir,
  );
  AppConfigTableData copyWithCompanion(AppConfigTableCompanion data) {
    return AppConfigTableData(
      id: data.id.present ? data.id.value : this.id,
      scanDir: data.scanDir.present ? data.scanDir.value : this.scanDir,
      ignoreListJson: data.ignoreListJson.present
          ? data.ignoreListJson.value
          : this.ignoreListJson,
      gitBinaryPath: data.gitBinaryPath.present
          ? data.gitBinaryPath.value
          : this.gitBinaryPath,
      themeMode: data.themeMode.present ? data.themeMode.value : this.themeMode,
      vaultDir: data.vaultDir.present ? data.vaultDir.value : this.vaultDir,
    );
  }

  @override
  String toString() {
    return (StringBuffer('AppConfigTableData(')
          ..write('id: $id, ')
          ..write('scanDir: $scanDir, ')
          ..write('ignoreListJson: $ignoreListJson, ')
          ..write('gitBinaryPath: $gitBinaryPath, ')
          ..write('themeMode: $themeMode, ')
          ..write('vaultDir: $vaultDir')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    scanDir,
    ignoreListJson,
    gitBinaryPath,
    themeMode,
    vaultDir,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is AppConfigTableData &&
          other.id == this.id &&
          other.scanDir == this.scanDir &&
          other.ignoreListJson == this.ignoreListJson &&
          other.gitBinaryPath == this.gitBinaryPath &&
          other.themeMode == this.themeMode &&
          other.vaultDir == this.vaultDir);
}

class AppConfigTableCompanion extends UpdateCompanion<AppConfigTableData> {
  final Value<int> id;
  final Value<String> scanDir;
  final Value<String> ignoreListJson;
  final Value<String> gitBinaryPath;
  final Value<String> themeMode;
  final Value<String> vaultDir;
  const AppConfigTableCompanion({
    this.id = const Value.absent(),
    this.scanDir = const Value.absent(),
    this.ignoreListJson = const Value.absent(),
    this.gitBinaryPath = const Value.absent(),
    this.themeMode = const Value.absent(),
    this.vaultDir = const Value.absent(),
  });
  AppConfigTableCompanion.insert({
    this.id = const Value.absent(),
    this.scanDir = const Value.absent(),
    this.ignoreListJson = const Value.absent(),
    this.gitBinaryPath = const Value.absent(),
    this.themeMode = const Value.absent(),
    this.vaultDir = const Value.absent(),
  });
  static Insertable<AppConfigTableData> custom({
    Expression<int>? id,
    Expression<String>? scanDir,
    Expression<String>? ignoreListJson,
    Expression<String>? gitBinaryPath,
    Expression<String>? themeMode,
    Expression<String>? vaultDir,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (scanDir != null) 'scan_dir': scanDir,
      if (ignoreListJson != null) 'ignore_list_json': ignoreListJson,
      if (gitBinaryPath != null) 'git_binary_path': gitBinaryPath,
      if (themeMode != null) 'theme_mode': themeMode,
      if (vaultDir != null) 'vault_dir': vaultDir,
    });
  }

  AppConfigTableCompanion copyWith({
    Value<int>? id,
    Value<String>? scanDir,
    Value<String>? ignoreListJson,
    Value<String>? gitBinaryPath,
    Value<String>? themeMode,
    Value<String>? vaultDir,
  }) {
    return AppConfigTableCompanion(
      id: id ?? this.id,
      scanDir: scanDir ?? this.scanDir,
      ignoreListJson: ignoreListJson ?? this.ignoreListJson,
      gitBinaryPath: gitBinaryPath ?? this.gitBinaryPath,
      themeMode: themeMode ?? this.themeMode,
      vaultDir: vaultDir ?? this.vaultDir,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (scanDir.present) {
      map['scan_dir'] = Variable<String>(scanDir.value);
    }
    if (ignoreListJson.present) {
      map['ignore_list_json'] = Variable<String>(ignoreListJson.value);
    }
    if (gitBinaryPath.present) {
      map['git_binary_path'] = Variable<String>(gitBinaryPath.value);
    }
    if (themeMode.present) {
      map['theme_mode'] = Variable<String>(themeMode.value);
    }
    if (vaultDir.present) {
      map['vault_dir'] = Variable<String>(vaultDir.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('AppConfigTableCompanion(')
          ..write('id: $id, ')
          ..write('scanDir: $scanDir, ')
          ..write('ignoreListJson: $ignoreListJson, ')
          ..write('gitBinaryPath: $gitBinaryPath, ')
          ..write('themeMode: $themeMode, ')
          ..write('vaultDir: $vaultDir')
          ..write(')'))
        .toString();
  }
}

class $ProjectSettingsTableTable extends ProjectSettingsTable
    with TableInfo<$ProjectSettingsTableTable, ProjectSettingsTableData> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $ProjectSettingsTableTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _folderIdMeta = const VerificationMeta(
    'folderId',
  );
  @override
  late final GeneratedColumn<String> folderId = GeneratedColumn<String>(
    'folder_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _projectTypeMeta = const VerificationMeta(
    'projectType',
  );
  @override
  late final GeneratedColumn<String> projectType = GeneratedColumn<String>(
    'project_type',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _displayNameMeta = const VerificationMeta(
    'displayName',
  );
  @override
  late final GeneratedColumn<String> displayName = GeneratedColumn<String>(
    'display_name',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _typeSetAtMeta = const VerificationMeta(
    'typeSetAt',
  );
  @override
  late final GeneratedColumn<DateTime> typeSetAt = GeneratedColumn<DateTime>(
    'type_set_at',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _isHiddenMeta = const VerificationMeta(
    'isHidden',
  );
  @override
  late final GeneratedColumn<bool> isHidden = GeneratedColumn<bool>(
    'is_hidden',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("is_hidden" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  @override
  List<GeneratedColumn> get $columns => [
    folderId,
    projectType,
    displayName,
    typeSetAt,
    isHidden,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'project_settings_table';
  @override
  VerificationContext validateIntegrity(
    Insertable<ProjectSettingsTableData> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('folder_id')) {
      context.handle(
        _folderIdMeta,
        folderId.isAcceptableOrUnknown(data['folder_id']!, _folderIdMeta),
      );
    } else if (isInserting) {
      context.missing(_folderIdMeta);
    }
    if (data.containsKey('project_type')) {
      context.handle(
        _projectTypeMeta,
        projectType.isAcceptableOrUnknown(
          data['project_type']!,
          _projectTypeMeta,
        ),
      );
    }
    if (data.containsKey('display_name')) {
      context.handle(
        _displayNameMeta,
        displayName.isAcceptableOrUnknown(
          data['display_name']!,
          _displayNameMeta,
        ),
      );
    }
    if (data.containsKey('type_set_at')) {
      context.handle(
        _typeSetAtMeta,
        typeSetAt.isAcceptableOrUnknown(data['type_set_at']!, _typeSetAtMeta),
      );
    }
    if (data.containsKey('is_hidden')) {
      context.handle(
        _isHiddenMeta,
        isHidden.isAcceptableOrUnknown(data['is_hidden']!, _isHiddenMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {folderId};
  @override
  ProjectSettingsTableData map(
    Map<String, dynamic> data, {
    String? tablePrefix,
  }) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return ProjectSettingsTableData(
      folderId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}folder_id'],
      )!,
      projectType: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}project_type'],
      ),
      displayName: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}display_name'],
      ),
      typeSetAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}type_set_at'],
      ),
      isHidden: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}is_hidden'],
      )!,
    );
  }

  @override
  $ProjectSettingsTableTable createAlias(String alias) {
    return $ProjectSettingsTableTable(attachedDatabase, alias);
  }
}

class ProjectSettingsTableData extends DataClass
    implements Insertable<ProjectSettingsTableData> {
  final String folderId;
  final String? projectType;
  final String? displayName;
  final DateTime? typeSetAt;
  final bool isHidden;
  const ProjectSettingsTableData({
    required this.folderId,
    this.projectType,
    this.displayName,
    this.typeSetAt,
    required this.isHidden,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['folder_id'] = Variable<String>(folderId);
    if (!nullToAbsent || projectType != null) {
      map['project_type'] = Variable<String>(projectType);
    }
    if (!nullToAbsent || displayName != null) {
      map['display_name'] = Variable<String>(displayName);
    }
    if (!nullToAbsent || typeSetAt != null) {
      map['type_set_at'] = Variable<DateTime>(typeSetAt);
    }
    map['is_hidden'] = Variable<bool>(isHidden);
    return map;
  }

  ProjectSettingsTableCompanion toCompanion(bool nullToAbsent) {
    return ProjectSettingsTableCompanion(
      folderId: Value(folderId),
      projectType: projectType == null && nullToAbsent
          ? const Value.absent()
          : Value(projectType),
      displayName: displayName == null && nullToAbsent
          ? const Value.absent()
          : Value(displayName),
      typeSetAt: typeSetAt == null && nullToAbsent
          ? const Value.absent()
          : Value(typeSetAt),
      isHidden: Value(isHidden),
    );
  }

  factory ProjectSettingsTableData.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return ProjectSettingsTableData(
      folderId: serializer.fromJson<String>(json['folderId']),
      projectType: serializer.fromJson<String?>(json['projectType']),
      displayName: serializer.fromJson<String?>(json['displayName']),
      typeSetAt: serializer.fromJson<DateTime?>(json['typeSetAt']),
      isHidden: serializer.fromJson<bool>(json['isHidden']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'folderId': serializer.toJson<String>(folderId),
      'projectType': serializer.toJson<String?>(projectType),
      'displayName': serializer.toJson<String?>(displayName),
      'typeSetAt': serializer.toJson<DateTime?>(typeSetAt),
      'isHidden': serializer.toJson<bool>(isHidden),
    };
  }

  ProjectSettingsTableData copyWith({
    String? folderId,
    Value<String?> projectType = const Value.absent(),
    Value<String?> displayName = const Value.absent(),
    Value<DateTime?> typeSetAt = const Value.absent(),
    bool? isHidden,
  }) => ProjectSettingsTableData(
    folderId: folderId ?? this.folderId,
    projectType: projectType.present ? projectType.value : this.projectType,
    displayName: displayName.present ? displayName.value : this.displayName,
    typeSetAt: typeSetAt.present ? typeSetAt.value : this.typeSetAt,
    isHidden: isHidden ?? this.isHidden,
  );
  ProjectSettingsTableData copyWithCompanion(
    ProjectSettingsTableCompanion data,
  ) {
    return ProjectSettingsTableData(
      folderId: data.folderId.present ? data.folderId.value : this.folderId,
      projectType: data.projectType.present
          ? data.projectType.value
          : this.projectType,
      displayName: data.displayName.present
          ? data.displayName.value
          : this.displayName,
      typeSetAt: data.typeSetAt.present ? data.typeSetAt.value : this.typeSetAt,
      isHidden: data.isHidden.present ? data.isHidden.value : this.isHidden,
    );
  }

  @override
  String toString() {
    return (StringBuffer('ProjectSettingsTableData(')
          ..write('folderId: $folderId, ')
          ..write('projectType: $projectType, ')
          ..write('displayName: $displayName, ')
          ..write('typeSetAt: $typeSetAt, ')
          ..write('isHidden: $isHidden')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode =>
      Object.hash(folderId, projectType, displayName, typeSetAt, isHidden);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ProjectSettingsTableData &&
          other.folderId == this.folderId &&
          other.projectType == this.projectType &&
          other.displayName == this.displayName &&
          other.typeSetAt == this.typeSetAt &&
          other.isHidden == this.isHidden);
}

class ProjectSettingsTableCompanion
    extends UpdateCompanion<ProjectSettingsTableData> {
  final Value<String> folderId;
  final Value<String?> projectType;
  final Value<String?> displayName;
  final Value<DateTime?> typeSetAt;
  final Value<bool> isHidden;
  final Value<int> rowid;
  const ProjectSettingsTableCompanion({
    this.folderId = const Value.absent(),
    this.projectType = const Value.absent(),
    this.displayName = const Value.absent(),
    this.typeSetAt = const Value.absent(),
    this.isHidden = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  ProjectSettingsTableCompanion.insert({
    required String folderId,
    this.projectType = const Value.absent(),
    this.displayName = const Value.absent(),
    this.typeSetAt = const Value.absent(),
    this.isHidden = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : folderId = Value(folderId);
  static Insertable<ProjectSettingsTableData> custom({
    Expression<String>? folderId,
    Expression<String>? projectType,
    Expression<String>? displayName,
    Expression<DateTime>? typeSetAt,
    Expression<bool>? isHidden,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (folderId != null) 'folder_id': folderId,
      if (projectType != null) 'project_type': projectType,
      if (displayName != null) 'display_name': displayName,
      if (typeSetAt != null) 'type_set_at': typeSetAt,
      if (isHidden != null) 'is_hidden': isHidden,
      if (rowid != null) 'rowid': rowid,
    });
  }

  ProjectSettingsTableCompanion copyWith({
    Value<String>? folderId,
    Value<String?>? projectType,
    Value<String?>? displayName,
    Value<DateTime?>? typeSetAt,
    Value<bool>? isHidden,
    Value<int>? rowid,
  }) {
    return ProjectSettingsTableCompanion(
      folderId: folderId ?? this.folderId,
      projectType: projectType ?? this.projectType,
      displayName: displayName ?? this.displayName,
      typeSetAt: typeSetAt ?? this.typeSetAt,
      isHidden: isHidden ?? this.isHidden,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (folderId.present) {
      map['folder_id'] = Variable<String>(folderId.value);
    }
    if (projectType.present) {
      map['project_type'] = Variable<String>(projectType.value);
    }
    if (displayName.present) {
      map['display_name'] = Variable<String>(displayName.value);
    }
    if (typeSetAt.present) {
      map['type_set_at'] = Variable<DateTime>(typeSetAt.value);
    }
    if (isHidden.present) {
      map['is_hidden'] = Variable<bool>(isHidden.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('ProjectSettingsTableCompanion(')
          ..write('folderId: $folderId, ')
          ..write('projectType: $projectType, ')
          ..write('displayName: $displayName, ')
          ..write('typeSetAt: $typeSetAt, ')
          ..write('isHidden: $isHidden, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

abstract class _$AppDatabase extends GeneratedDatabase {
  _$AppDatabase(QueryExecutor e) : super(e);
  $AppDatabaseManager get managers => $AppDatabaseManager(this);
  late final $AppConfigTableTable appConfigTable = $AppConfigTableTable(this);
  late final $ProjectSettingsTableTable projectSettingsTable =
      $ProjectSettingsTableTable(this);
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [
    appConfigTable,
    projectSettingsTable,
  ];
}

typedef $$AppConfigTableTableCreateCompanionBuilder =
    AppConfigTableCompanion Function({
      Value<int> id,
      Value<String> scanDir,
      Value<String> ignoreListJson,
      Value<String> gitBinaryPath,
      Value<String> themeMode,
      Value<String> vaultDir,
    });
typedef $$AppConfigTableTableUpdateCompanionBuilder =
    AppConfigTableCompanion Function({
      Value<int> id,
      Value<String> scanDir,
      Value<String> ignoreListJson,
      Value<String> gitBinaryPath,
      Value<String> themeMode,
      Value<String> vaultDir,
    });

class $$AppConfigTableTableFilterComposer
    extends Composer<_$AppDatabase, $AppConfigTableTable> {
  $$AppConfigTableTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get scanDir => $composableBuilder(
    column: $table.scanDir,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get ignoreListJson => $composableBuilder(
    column: $table.ignoreListJson,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get gitBinaryPath => $composableBuilder(
    column: $table.gitBinaryPath,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get themeMode => $composableBuilder(
    column: $table.themeMode,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get vaultDir => $composableBuilder(
    column: $table.vaultDir,
    builder: (column) => ColumnFilters(column),
  );
}

class $$AppConfigTableTableOrderingComposer
    extends Composer<_$AppDatabase, $AppConfigTableTable> {
  $$AppConfigTableTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get scanDir => $composableBuilder(
    column: $table.scanDir,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get ignoreListJson => $composableBuilder(
    column: $table.ignoreListJson,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get gitBinaryPath => $composableBuilder(
    column: $table.gitBinaryPath,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get themeMode => $composableBuilder(
    column: $table.themeMode,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get vaultDir => $composableBuilder(
    column: $table.vaultDir,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$AppConfigTableTableAnnotationComposer
    extends Composer<_$AppDatabase, $AppConfigTableTable> {
  $$AppConfigTableTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get scanDir =>
      $composableBuilder(column: $table.scanDir, builder: (column) => column);

  GeneratedColumn<String> get ignoreListJson => $composableBuilder(
    column: $table.ignoreListJson,
    builder: (column) => column,
  );

  GeneratedColumn<String> get gitBinaryPath => $composableBuilder(
    column: $table.gitBinaryPath,
    builder: (column) => column,
  );

  GeneratedColumn<String> get themeMode =>
      $composableBuilder(column: $table.themeMode, builder: (column) => column);

  GeneratedColumn<String> get vaultDir =>
      $composableBuilder(column: $table.vaultDir, builder: (column) => column);
}

class $$AppConfigTableTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $AppConfigTableTable,
          AppConfigTableData,
          $$AppConfigTableTableFilterComposer,
          $$AppConfigTableTableOrderingComposer,
          $$AppConfigTableTableAnnotationComposer,
          $$AppConfigTableTableCreateCompanionBuilder,
          $$AppConfigTableTableUpdateCompanionBuilder,
          (
            AppConfigTableData,
            BaseReferences<
              _$AppDatabase,
              $AppConfigTableTable,
              AppConfigTableData
            >,
          ),
          AppConfigTableData,
          PrefetchHooks Function()
        > {
  $$AppConfigTableTableTableManager(
    _$AppDatabase db,
    $AppConfigTableTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$AppConfigTableTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$AppConfigTableTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$AppConfigTableTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String> scanDir = const Value.absent(),
                Value<String> ignoreListJson = const Value.absent(),
                Value<String> gitBinaryPath = const Value.absent(),
                Value<String> themeMode = const Value.absent(),
                Value<String> vaultDir = const Value.absent(),
              }) => AppConfigTableCompanion(
                id: id,
                scanDir: scanDir,
                ignoreListJson: ignoreListJson,
                gitBinaryPath: gitBinaryPath,
                themeMode: themeMode,
                vaultDir: vaultDir,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String> scanDir = const Value.absent(),
                Value<String> ignoreListJson = const Value.absent(),
                Value<String> gitBinaryPath = const Value.absent(),
                Value<String> themeMode = const Value.absent(),
                Value<String> vaultDir = const Value.absent(),
              }) => AppConfigTableCompanion.insert(
                id: id,
                scanDir: scanDir,
                ignoreListJson: ignoreListJson,
                gitBinaryPath: gitBinaryPath,
                themeMode: themeMode,
                vaultDir: vaultDir,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$AppConfigTableTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $AppConfigTableTable,
      AppConfigTableData,
      $$AppConfigTableTableFilterComposer,
      $$AppConfigTableTableOrderingComposer,
      $$AppConfigTableTableAnnotationComposer,
      $$AppConfigTableTableCreateCompanionBuilder,
      $$AppConfigTableTableUpdateCompanionBuilder,
      (
        AppConfigTableData,
        BaseReferences<_$AppDatabase, $AppConfigTableTable, AppConfigTableData>,
      ),
      AppConfigTableData,
      PrefetchHooks Function()
    >;
typedef $$ProjectSettingsTableTableCreateCompanionBuilder =
    ProjectSettingsTableCompanion Function({
      required String folderId,
      Value<String?> projectType,
      Value<String?> displayName,
      Value<DateTime?> typeSetAt,
      Value<bool> isHidden,
      Value<int> rowid,
    });
typedef $$ProjectSettingsTableTableUpdateCompanionBuilder =
    ProjectSettingsTableCompanion Function({
      Value<String> folderId,
      Value<String?> projectType,
      Value<String?> displayName,
      Value<DateTime?> typeSetAt,
      Value<bool> isHidden,
      Value<int> rowid,
    });

class $$ProjectSettingsTableTableFilterComposer
    extends Composer<_$AppDatabase, $ProjectSettingsTableTable> {
  $$ProjectSettingsTableTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get folderId => $composableBuilder(
    column: $table.folderId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get projectType => $composableBuilder(
    column: $table.projectType,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get displayName => $composableBuilder(
    column: $table.displayName,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get typeSetAt => $composableBuilder(
    column: $table.typeSetAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get isHidden => $composableBuilder(
    column: $table.isHidden,
    builder: (column) => ColumnFilters(column),
  );
}

class $$ProjectSettingsTableTableOrderingComposer
    extends Composer<_$AppDatabase, $ProjectSettingsTableTable> {
  $$ProjectSettingsTableTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get folderId => $composableBuilder(
    column: $table.folderId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get projectType => $composableBuilder(
    column: $table.projectType,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get displayName => $composableBuilder(
    column: $table.displayName,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get typeSetAt => $composableBuilder(
    column: $table.typeSetAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get isHidden => $composableBuilder(
    column: $table.isHidden,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$ProjectSettingsTableTableAnnotationComposer
    extends Composer<_$AppDatabase, $ProjectSettingsTableTable> {
  $$ProjectSettingsTableTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get folderId =>
      $composableBuilder(column: $table.folderId, builder: (column) => column);

  GeneratedColumn<String> get projectType => $composableBuilder(
    column: $table.projectType,
    builder: (column) => column,
  );

  GeneratedColumn<String> get displayName => $composableBuilder(
    column: $table.displayName,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get typeSetAt =>
      $composableBuilder(column: $table.typeSetAt, builder: (column) => column);

  GeneratedColumn<bool> get isHidden =>
      $composableBuilder(column: $table.isHidden, builder: (column) => column);
}

class $$ProjectSettingsTableTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $ProjectSettingsTableTable,
          ProjectSettingsTableData,
          $$ProjectSettingsTableTableFilterComposer,
          $$ProjectSettingsTableTableOrderingComposer,
          $$ProjectSettingsTableTableAnnotationComposer,
          $$ProjectSettingsTableTableCreateCompanionBuilder,
          $$ProjectSettingsTableTableUpdateCompanionBuilder,
          (
            ProjectSettingsTableData,
            BaseReferences<
              _$AppDatabase,
              $ProjectSettingsTableTable,
              ProjectSettingsTableData
            >,
          ),
          ProjectSettingsTableData,
          PrefetchHooks Function()
        > {
  $$ProjectSettingsTableTableTableManager(
    _$AppDatabase db,
    $ProjectSettingsTableTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$ProjectSettingsTableTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$ProjectSettingsTableTableOrderingComposer(
                $db: db,
                $table: table,
              ),
          createComputedFieldComposer: () =>
              $$ProjectSettingsTableTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<String> folderId = const Value.absent(),
                Value<String?> projectType = const Value.absent(),
                Value<String?> displayName = const Value.absent(),
                Value<DateTime?> typeSetAt = const Value.absent(),
                Value<bool> isHidden = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => ProjectSettingsTableCompanion(
                folderId: folderId,
                projectType: projectType,
                displayName: displayName,
                typeSetAt: typeSetAt,
                isHidden: isHidden,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String folderId,
                Value<String?> projectType = const Value.absent(),
                Value<String?> displayName = const Value.absent(),
                Value<DateTime?> typeSetAt = const Value.absent(),
                Value<bool> isHidden = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => ProjectSettingsTableCompanion.insert(
                folderId: folderId,
                projectType: projectType,
                displayName: displayName,
                typeSetAt: typeSetAt,
                isHidden: isHidden,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$ProjectSettingsTableTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $ProjectSettingsTableTable,
      ProjectSettingsTableData,
      $$ProjectSettingsTableTableFilterComposer,
      $$ProjectSettingsTableTableOrderingComposer,
      $$ProjectSettingsTableTableAnnotationComposer,
      $$ProjectSettingsTableTableCreateCompanionBuilder,
      $$ProjectSettingsTableTableUpdateCompanionBuilder,
      (
        ProjectSettingsTableData,
        BaseReferences<
          _$AppDatabase,
          $ProjectSettingsTableTable,
          ProjectSettingsTableData
        >,
      ),
      ProjectSettingsTableData,
      PrefetchHooks Function()
    >;

class $AppDatabaseManager {
  final _$AppDatabase _db;
  $AppDatabaseManager(this._db);
  $$AppConfigTableTableTableManager get appConfigTable =>
      $$AppConfigTableTableTableManager(_db, _db.appConfigTable);
  $$ProjectSettingsTableTableTableManager get projectSettingsTable =>
      $$ProjectSettingsTableTableTableManager(_db, _db.projectSettingsTable);
}
