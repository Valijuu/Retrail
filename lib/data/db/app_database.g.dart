// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'app_database.dart';

// ignore_for_file: type=lint
class $RidesTable extends Rides with TableInfo<$RidesTable, Ride> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $RidesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _rideIdMeta = const VerificationMeta('rideId');
  @override
  late final GeneratedColumn<int> rideId = GeneratedColumn<int>(
    'ride_id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _descriptionMeta = const VerificationMeta(
    'description',
  );
  @override
  late final GeneratedColumn<String> description = GeneratedColumn<String>(
    'description',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _typMeta = const VerificationMeta('typ');
  @override
  late final GeneratedColumn<String> typ = GeneratedColumn<String>(
    'typ',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _startTimeMeta = const VerificationMeta(
    'startTime',
  );
  @override
  late final GeneratedColumn<int> startTime = GeneratedColumn<int>(
    'start_time',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _endTimeMeta = const VerificationMeta(
    'endTime',
  );
  @override
  late final GeneratedColumn<int> endTime = GeneratedColumn<int>(
    'end_time',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _dateMeta = const VerificationMeta('date');
  @override
  late final GeneratedColumn<int> date = GeneratedColumn<int>(
    'date',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _commentMeta = const VerificationMeta(
    'comment',
  );
  @override
  late final GeneratedColumn<String> comment = GeneratedColumn<String>(
    'comment',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _isFavoriteMeta = const VerificationMeta(
    'isFavorite',
  );
  @override
  late final GeneratedColumn<bool> isFavorite = GeneratedColumn<bool>(
    'is_favorite',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("is_favorite" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _favoritedAtMeta = const VerificationMeta(
    'favoritedAt',
  );
  @override
  late final GeneratedColumn<int> favoritedAt = GeneratedColumn<int>(
    'favorited_at',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    rideId,
    description,
    typ,
    startTime,
    endTime,
    date,
    comment,
    isFavorite,
    favoritedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'rides';
  @override
  VerificationContext validateIntegrity(
    Insertable<Ride> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('ride_id')) {
      context.handle(
        _rideIdMeta,
        rideId.isAcceptableOrUnknown(data['ride_id']!, _rideIdMeta),
      );
    }
    if (data.containsKey('description')) {
      context.handle(
        _descriptionMeta,
        description.isAcceptableOrUnknown(
          data['description']!,
          _descriptionMeta,
        ),
      );
    }
    if (data.containsKey('typ')) {
      context.handle(
        _typMeta,
        typ.isAcceptableOrUnknown(data['typ']!, _typMeta),
      );
    }
    if (data.containsKey('start_time')) {
      context.handle(
        _startTimeMeta,
        startTime.isAcceptableOrUnknown(data['start_time']!, _startTimeMeta),
      );
    }
    if (data.containsKey('end_time')) {
      context.handle(
        _endTimeMeta,
        endTime.isAcceptableOrUnknown(data['end_time']!, _endTimeMeta),
      );
    }
    if (data.containsKey('date')) {
      context.handle(
        _dateMeta,
        date.isAcceptableOrUnknown(data['date']!, _dateMeta),
      );
    }
    if (data.containsKey('comment')) {
      context.handle(
        _commentMeta,
        comment.isAcceptableOrUnknown(data['comment']!, _commentMeta),
      );
    }
    if (data.containsKey('is_favorite')) {
      context.handle(
        _isFavoriteMeta,
        isFavorite.isAcceptableOrUnknown(data['is_favorite']!, _isFavoriteMeta),
      );
    }
    if (data.containsKey('favorited_at')) {
      context.handle(
        _favoritedAtMeta,
        favoritedAt.isAcceptableOrUnknown(
          data['favorited_at']!,
          _favoritedAtMeta,
        ),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {rideId};
  @override
  Ride map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Ride(
      rideId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}ride_id'],
      )!,
      description: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}description'],
      ),
      typ: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}typ'],
      ),
      startTime: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}start_time'],
      ),
      endTime: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}end_time'],
      ),
      date: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}date'],
      ),
      comment: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}comment'],
      ),
      isFavorite: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}is_favorite'],
      )!,
      favoritedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}favorited_at'],
      ),
    );
  }

  @override
  $RidesTable createAlias(String alias) {
    return $RidesTable(attachedDatabase, alias);
  }
}

class Ride extends DataClass implements Insertable<Ride> {
  final int rideId;
  final String? description;
  final String? typ;
  final int? startTime;
  final int? endTime;
  final int? date;
  final String? comment;
  final bool isFavorite;
  final int? favoritedAt;
  const Ride({
    required this.rideId,
    this.description,
    this.typ,
    this.startTime,
    this.endTime,
    this.date,
    this.comment,
    required this.isFavorite,
    this.favoritedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['ride_id'] = Variable<int>(rideId);
    if (!nullToAbsent || description != null) {
      map['description'] = Variable<String>(description);
    }
    if (!nullToAbsent || typ != null) {
      map['typ'] = Variable<String>(typ);
    }
    if (!nullToAbsent || startTime != null) {
      map['start_time'] = Variable<int>(startTime);
    }
    if (!nullToAbsent || endTime != null) {
      map['end_time'] = Variable<int>(endTime);
    }
    if (!nullToAbsent || date != null) {
      map['date'] = Variable<int>(date);
    }
    if (!nullToAbsent || comment != null) {
      map['comment'] = Variable<String>(comment);
    }
    map['is_favorite'] = Variable<bool>(isFavorite);
    if (!nullToAbsent || favoritedAt != null) {
      map['favorited_at'] = Variable<int>(favoritedAt);
    }
    return map;
  }

  RidesCompanion toCompanion(bool nullToAbsent) {
    return RidesCompanion(
      rideId: Value(rideId),
      description: description == null && nullToAbsent
          ? const Value.absent()
          : Value(description),
      typ: typ == null && nullToAbsent ? const Value.absent() : Value(typ),
      startTime: startTime == null && nullToAbsent
          ? const Value.absent()
          : Value(startTime),
      endTime: endTime == null && nullToAbsent
          ? const Value.absent()
          : Value(endTime),
      date: date == null && nullToAbsent ? const Value.absent() : Value(date),
      comment: comment == null && nullToAbsent
          ? const Value.absent()
          : Value(comment),
      isFavorite: Value(isFavorite),
      favoritedAt: favoritedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(favoritedAt),
    );
  }

  factory Ride.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Ride(
      rideId: serializer.fromJson<int>(json['rideId']),
      description: serializer.fromJson<String?>(json['description']),
      typ: serializer.fromJson<String?>(json['typ']),
      startTime: serializer.fromJson<int?>(json['startTime']),
      endTime: serializer.fromJson<int?>(json['endTime']),
      date: serializer.fromJson<int?>(json['date']),
      comment: serializer.fromJson<String?>(json['comment']),
      isFavorite: serializer.fromJson<bool>(json['isFavorite']),
      favoritedAt: serializer.fromJson<int?>(json['favoritedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'rideId': serializer.toJson<int>(rideId),
      'description': serializer.toJson<String?>(description),
      'typ': serializer.toJson<String?>(typ),
      'startTime': serializer.toJson<int?>(startTime),
      'endTime': serializer.toJson<int?>(endTime),
      'date': serializer.toJson<int?>(date),
      'comment': serializer.toJson<String?>(comment),
      'isFavorite': serializer.toJson<bool>(isFavorite),
      'favoritedAt': serializer.toJson<int?>(favoritedAt),
    };
  }

  Ride copyWith({
    int? rideId,
    Value<String?> description = const Value.absent(),
    Value<String?> typ = const Value.absent(),
    Value<int?> startTime = const Value.absent(),
    Value<int?> endTime = const Value.absent(),
    Value<int?> date = const Value.absent(),
    Value<String?> comment = const Value.absent(),
    bool? isFavorite,
    Value<int?> favoritedAt = const Value.absent(),
  }) => Ride(
    rideId: rideId ?? this.rideId,
    description: description.present ? description.value : this.description,
    typ: typ.present ? typ.value : this.typ,
    startTime: startTime.present ? startTime.value : this.startTime,
    endTime: endTime.present ? endTime.value : this.endTime,
    date: date.present ? date.value : this.date,
    comment: comment.present ? comment.value : this.comment,
    isFavorite: isFavorite ?? this.isFavorite,
    favoritedAt: favoritedAt.present ? favoritedAt.value : this.favoritedAt,
  );
  Ride copyWithCompanion(RidesCompanion data) {
    return Ride(
      rideId: data.rideId.present ? data.rideId.value : this.rideId,
      description: data.description.present
          ? data.description.value
          : this.description,
      typ: data.typ.present ? data.typ.value : this.typ,
      startTime: data.startTime.present ? data.startTime.value : this.startTime,
      endTime: data.endTime.present ? data.endTime.value : this.endTime,
      date: data.date.present ? data.date.value : this.date,
      comment: data.comment.present ? data.comment.value : this.comment,
      isFavorite: data.isFavorite.present
          ? data.isFavorite.value
          : this.isFavorite,
      favoritedAt: data.favoritedAt.present
          ? data.favoritedAt.value
          : this.favoritedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Ride(')
          ..write('rideId: $rideId, ')
          ..write('description: $description, ')
          ..write('typ: $typ, ')
          ..write('startTime: $startTime, ')
          ..write('endTime: $endTime, ')
          ..write('date: $date, ')
          ..write('comment: $comment, ')
          ..write('isFavorite: $isFavorite, ')
          ..write('favoritedAt: $favoritedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    rideId,
    description,
    typ,
    startTime,
    endTime,
    date,
    comment,
    isFavorite,
    favoritedAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Ride &&
          other.rideId == this.rideId &&
          other.description == this.description &&
          other.typ == this.typ &&
          other.startTime == this.startTime &&
          other.endTime == this.endTime &&
          other.date == this.date &&
          other.comment == this.comment &&
          other.isFavorite == this.isFavorite &&
          other.favoritedAt == this.favoritedAt);
}

class RidesCompanion extends UpdateCompanion<Ride> {
  final Value<int> rideId;
  final Value<String?> description;
  final Value<String?> typ;
  final Value<int?> startTime;
  final Value<int?> endTime;
  final Value<int?> date;
  final Value<String?> comment;
  final Value<bool> isFavorite;
  final Value<int?> favoritedAt;
  const RidesCompanion({
    this.rideId = const Value.absent(),
    this.description = const Value.absent(),
    this.typ = const Value.absent(),
    this.startTime = const Value.absent(),
    this.endTime = const Value.absent(),
    this.date = const Value.absent(),
    this.comment = const Value.absent(),
    this.isFavorite = const Value.absent(),
    this.favoritedAt = const Value.absent(),
  });
  RidesCompanion.insert({
    this.rideId = const Value.absent(),
    this.description = const Value.absent(),
    this.typ = const Value.absent(),
    this.startTime = const Value.absent(),
    this.endTime = const Value.absent(),
    this.date = const Value.absent(),
    this.comment = const Value.absent(),
    this.isFavorite = const Value.absent(),
    this.favoritedAt = const Value.absent(),
  });
  static Insertable<Ride> custom({
    Expression<int>? rideId,
    Expression<String>? description,
    Expression<String>? typ,
    Expression<int>? startTime,
    Expression<int>? endTime,
    Expression<int>? date,
    Expression<String>? comment,
    Expression<bool>? isFavorite,
    Expression<int>? favoritedAt,
  }) {
    return RawValuesInsertable({
      if (rideId != null) 'ride_id': rideId,
      if (description != null) 'description': description,
      if (typ != null) 'typ': typ,
      if (startTime != null) 'start_time': startTime,
      if (endTime != null) 'end_time': endTime,
      if (date != null) 'date': date,
      if (comment != null) 'comment': comment,
      if (isFavorite != null) 'is_favorite': isFavorite,
      if (favoritedAt != null) 'favorited_at': favoritedAt,
    });
  }

  RidesCompanion copyWith({
    Value<int>? rideId,
    Value<String?>? description,
    Value<String?>? typ,
    Value<int?>? startTime,
    Value<int?>? endTime,
    Value<int?>? date,
    Value<String?>? comment,
    Value<bool>? isFavorite,
    Value<int?>? favoritedAt,
  }) {
    return RidesCompanion(
      rideId: rideId ?? this.rideId,
      description: description ?? this.description,
      typ: typ ?? this.typ,
      startTime: startTime ?? this.startTime,
      endTime: endTime ?? this.endTime,
      date: date ?? this.date,
      comment: comment ?? this.comment,
      isFavorite: isFavorite ?? this.isFavorite,
      favoritedAt: favoritedAt ?? this.favoritedAt,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (rideId.present) {
      map['ride_id'] = Variable<int>(rideId.value);
    }
    if (description.present) {
      map['description'] = Variable<String>(description.value);
    }
    if (typ.present) {
      map['typ'] = Variable<String>(typ.value);
    }
    if (startTime.present) {
      map['start_time'] = Variable<int>(startTime.value);
    }
    if (endTime.present) {
      map['end_time'] = Variable<int>(endTime.value);
    }
    if (date.present) {
      map['date'] = Variable<int>(date.value);
    }
    if (comment.present) {
      map['comment'] = Variable<String>(comment.value);
    }
    if (isFavorite.present) {
      map['is_favorite'] = Variable<bool>(isFavorite.value);
    }
    if (favoritedAt.present) {
      map['favorited_at'] = Variable<int>(favoritedAt.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('RidesCompanion(')
          ..write('rideId: $rideId, ')
          ..write('description: $description, ')
          ..write('typ: $typ, ')
          ..write('startTime: $startTime, ')
          ..write('endTime: $endTime, ')
          ..write('date: $date, ')
          ..write('comment: $comment, ')
          ..write('isFavorite: $isFavorite, ')
          ..write('favoritedAt: $favoritedAt')
          ..write(')'))
        .toString();
  }
}

class $TrackpointsTable extends Trackpoints
    with TableInfo<$TrackpointsTable, Trackpoint> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $TrackpointsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _trackpointIdMeta = const VerificationMeta(
    'trackpointId',
  );
  @override
  late final GeneratedColumn<int> trackpointId = GeneratedColumn<int>(
    'trackpoint_id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _rideIdMeta = const VerificationMeta('rideId');
  @override
  late final GeneratedColumn<int> rideId = GeneratedColumn<int>(
    'ride_id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES rides (ride_id) ON DELETE CASCADE',
    ),
  );
  static const VerificationMeta _latitudeMeta = const VerificationMeta(
    'latitude',
  );
  @override
  late final GeneratedColumn<double> latitude = GeneratedColumn<double>(
    'latitude',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _longitudeMeta = const VerificationMeta(
    'longitude',
  );
  @override
  late final GeneratedColumn<double> longitude = GeneratedColumn<double>(
    'longitude',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _timestampMeta = const VerificationMeta(
    'timestamp',
  );
  @override
  late final GeneratedColumn<int> timestamp = GeneratedColumn<int>(
    'timestamp',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _speedMeta = const VerificationMeta('speed');
  @override
  late final GeneratedColumn<double> speed = GeneratedColumn<double>(
    'speed',
    aliasedName,
    true,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    trackpointId,
    rideId,
    latitude,
    longitude,
    timestamp,
    speed,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'trackpoints';
  @override
  VerificationContext validateIntegrity(
    Insertable<Trackpoint> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('trackpoint_id')) {
      context.handle(
        _trackpointIdMeta,
        trackpointId.isAcceptableOrUnknown(
          data['trackpoint_id']!,
          _trackpointIdMeta,
        ),
      );
    }
    if (data.containsKey('ride_id')) {
      context.handle(
        _rideIdMeta,
        rideId.isAcceptableOrUnknown(data['ride_id']!, _rideIdMeta),
      );
    } else if (isInserting) {
      context.missing(_rideIdMeta);
    }
    if (data.containsKey('latitude')) {
      context.handle(
        _latitudeMeta,
        latitude.isAcceptableOrUnknown(data['latitude']!, _latitudeMeta),
      );
    } else if (isInserting) {
      context.missing(_latitudeMeta);
    }
    if (data.containsKey('longitude')) {
      context.handle(
        _longitudeMeta,
        longitude.isAcceptableOrUnknown(data['longitude']!, _longitudeMeta),
      );
    } else if (isInserting) {
      context.missing(_longitudeMeta);
    }
    if (data.containsKey('timestamp')) {
      context.handle(
        _timestampMeta,
        timestamp.isAcceptableOrUnknown(data['timestamp']!, _timestampMeta),
      );
    } else if (isInserting) {
      context.missing(_timestampMeta);
    }
    if (data.containsKey('speed')) {
      context.handle(
        _speedMeta,
        speed.isAcceptableOrUnknown(data['speed']!, _speedMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {trackpointId};
  @override
  Trackpoint map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Trackpoint(
      trackpointId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}trackpoint_id'],
      )!,
      rideId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}ride_id'],
      )!,
      latitude: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}latitude'],
      )!,
      longitude: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}longitude'],
      )!,
      timestamp: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}timestamp'],
      )!,
      speed: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}speed'],
      ),
    );
  }

  @override
  $TrackpointsTable createAlias(String alias) {
    return $TrackpointsTable(attachedDatabase, alias);
  }
}

class Trackpoint extends DataClass implements Insertable<Trackpoint> {
  final int trackpointId;
  final int rideId;
  final double latitude;
  final double longitude;
  final int timestamp;
  final double? speed;
  const Trackpoint({
    required this.trackpointId,
    required this.rideId,
    required this.latitude,
    required this.longitude,
    required this.timestamp,
    this.speed,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['trackpoint_id'] = Variable<int>(trackpointId);
    map['ride_id'] = Variable<int>(rideId);
    map['latitude'] = Variable<double>(latitude);
    map['longitude'] = Variable<double>(longitude);
    map['timestamp'] = Variable<int>(timestamp);
    if (!nullToAbsent || speed != null) {
      map['speed'] = Variable<double>(speed);
    }
    return map;
  }

  TrackpointsCompanion toCompanion(bool nullToAbsent) {
    return TrackpointsCompanion(
      trackpointId: Value(trackpointId),
      rideId: Value(rideId),
      latitude: Value(latitude),
      longitude: Value(longitude),
      timestamp: Value(timestamp),
      speed: speed == null && nullToAbsent
          ? const Value.absent()
          : Value(speed),
    );
  }

  factory Trackpoint.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Trackpoint(
      trackpointId: serializer.fromJson<int>(json['trackpointId']),
      rideId: serializer.fromJson<int>(json['rideId']),
      latitude: serializer.fromJson<double>(json['latitude']),
      longitude: serializer.fromJson<double>(json['longitude']),
      timestamp: serializer.fromJson<int>(json['timestamp']),
      speed: serializer.fromJson<double?>(json['speed']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'trackpointId': serializer.toJson<int>(trackpointId),
      'rideId': serializer.toJson<int>(rideId),
      'latitude': serializer.toJson<double>(latitude),
      'longitude': serializer.toJson<double>(longitude),
      'timestamp': serializer.toJson<int>(timestamp),
      'speed': serializer.toJson<double?>(speed),
    };
  }

  Trackpoint copyWith({
    int? trackpointId,
    int? rideId,
    double? latitude,
    double? longitude,
    int? timestamp,
    Value<double?> speed = const Value.absent(),
  }) => Trackpoint(
    trackpointId: trackpointId ?? this.trackpointId,
    rideId: rideId ?? this.rideId,
    latitude: latitude ?? this.latitude,
    longitude: longitude ?? this.longitude,
    timestamp: timestamp ?? this.timestamp,
    speed: speed.present ? speed.value : this.speed,
  );
  Trackpoint copyWithCompanion(TrackpointsCompanion data) {
    return Trackpoint(
      trackpointId: data.trackpointId.present
          ? data.trackpointId.value
          : this.trackpointId,
      rideId: data.rideId.present ? data.rideId.value : this.rideId,
      latitude: data.latitude.present ? data.latitude.value : this.latitude,
      longitude: data.longitude.present ? data.longitude.value : this.longitude,
      timestamp: data.timestamp.present ? data.timestamp.value : this.timestamp,
      speed: data.speed.present ? data.speed.value : this.speed,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Trackpoint(')
          ..write('trackpointId: $trackpointId, ')
          ..write('rideId: $rideId, ')
          ..write('latitude: $latitude, ')
          ..write('longitude: $longitude, ')
          ..write('timestamp: $timestamp, ')
          ..write('speed: $speed')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode =>
      Object.hash(trackpointId, rideId, latitude, longitude, timestamp, speed);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Trackpoint &&
          other.trackpointId == this.trackpointId &&
          other.rideId == this.rideId &&
          other.latitude == this.latitude &&
          other.longitude == this.longitude &&
          other.timestamp == this.timestamp &&
          other.speed == this.speed);
}

class TrackpointsCompanion extends UpdateCompanion<Trackpoint> {
  final Value<int> trackpointId;
  final Value<int> rideId;
  final Value<double> latitude;
  final Value<double> longitude;
  final Value<int> timestamp;
  final Value<double?> speed;
  const TrackpointsCompanion({
    this.trackpointId = const Value.absent(),
    this.rideId = const Value.absent(),
    this.latitude = const Value.absent(),
    this.longitude = const Value.absent(),
    this.timestamp = const Value.absent(),
    this.speed = const Value.absent(),
  });
  TrackpointsCompanion.insert({
    this.trackpointId = const Value.absent(),
    required int rideId,
    required double latitude,
    required double longitude,
    required int timestamp,
    this.speed = const Value.absent(),
  }) : rideId = Value(rideId),
       latitude = Value(latitude),
       longitude = Value(longitude),
       timestamp = Value(timestamp);
  static Insertable<Trackpoint> custom({
    Expression<int>? trackpointId,
    Expression<int>? rideId,
    Expression<double>? latitude,
    Expression<double>? longitude,
    Expression<int>? timestamp,
    Expression<double>? speed,
  }) {
    return RawValuesInsertable({
      if (trackpointId != null) 'trackpoint_id': trackpointId,
      if (rideId != null) 'ride_id': rideId,
      if (latitude != null) 'latitude': latitude,
      if (longitude != null) 'longitude': longitude,
      if (timestamp != null) 'timestamp': timestamp,
      if (speed != null) 'speed': speed,
    });
  }

  TrackpointsCompanion copyWith({
    Value<int>? trackpointId,
    Value<int>? rideId,
    Value<double>? latitude,
    Value<double>? longitude,
    Value<int>? timestamp,
    Value<double?>? speed,
  }) {
    return TrackpointsCompanion(
      trackpointId: trackpointId ?? this.trackpointId,
      rideId: rideId ?? this.rideId,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      timestamp: timestamp ?? this.timestamp,
      speed: speed ?? this.speed,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (trackpointId.present) {
      map['trackpoint_id'] = Variable<int>(trackpointId.value);
    }
    if (rideId.present) {
      map['ride_id'] = Variable<int>(rideId.value);
    }
    if (latitude.present) {
      map['latitude'] = Variable<double>(latitude.value);
    }
    if (longitude.present) {
      map['longitude'] = Variable<double>(longitude.value);
    }
    if (timestamp.present) {
      map['timestamp'] = Variable<int>(timestamp.value);
    }
    if (speed.present) {
      map['speed'] = Variable<double>(speed.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('TrackpointsCompanion(')
          ..write('trackpointId: $trackpointId, ')
          ..write('rideId: $rideId, ')
          ..write('latitude: $latitude, ')
          ..write('longitude: $longitude, ')
          ..write('timestamp: $timestamp, ')
          ..write('speed: $speed')
          ..write(')'))
        .toString();
  }
}

abstract class _$AppDatabase extends GeneratedDatabase {
  _$AppDatabase(QueryExecutor e) : super(e);
  $AppDatabaseManager get managers => $AppDatabaseManager(this);
  late final $RidesTable rides = $RidesTable(this);
  late final $TrackpointsTable trackpoints = $TrackpointsTable(this);
  late final Index ridesDate = Index(
    'rides_date',
    'CREATE INDEX rides_date ON rides (date)',
  );
  late final Index trackpointsRideId = Index(
    'trackpoints_ride_id',
    'CREATE INDEX trackpoints_ride_id ON trackpoints (ride_id)',
  );
  late final RideDao rideDao = RideDao(this as AppDatabase);
  late final TrackpointDao trackpointDao = TrackpointDao(this as AppDatabase);
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [
    rides,
    trackpoints,
    ridesDate,
    trackpointsRideId,
  ];
  @override
  StreamQueryUpdateRules get streamUpdateRules => const StreamQueryUpdateRules([
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'rides',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('trackpoints', kind: UpdateKind.delete)],
    ),
  ]);
}

typedef $$RidesTableCreateCompanionBuilder =
    RidesCompanion Function({
      Value<int> rideId,
      Value<String?> description,
      Value<String?> typ,
      Value<int?> startTime,
      Value<int?> endTime,
      Value<int?> date,
      Value<String?> comment,
      Value<bool> isFavorite,
      Value<int?> favoritedAt,
    });
typedef $$RidesTableUpdateCompanionBuilder =
    RidesCompanion Function({
      Value<int> rideId,
      Value<String?> description,
      Value<String?> typ,
      Value<int?> startTime,
      Value<int?> endTime,
      Value<int?> date,
      Value<String?> comment,
      Value<bool> isFavorite,
      Value<int?> favoritedAt,
    });

final class $$RidesTableReferences
    extends BaseReferences<_$AppDatabase, $RidesTable, Ride> {
  $$RidesTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static MultiTypedResultKey<$TrackpointsTable, List<Trackpoint>>
  _trackpointsRefsTable(_$AppDatabase db) => MultiTypedResultKey.fromTable(
    db.trackpoints,
    aliasName: 'rides__ride_id__trackpoints__ride_id',
  );

  $$TrackpointsTableProcessedTableManager get trackpointsRefs {
    final manager = $$TrackpointsTableTableManager(
      $_db,
      $_db.trackpoints,
    ).filter((f) => f.rideId.rideId.sqlEquals($_itemColumn<int>('ride_id')!));

    final cache = $_typedResult.readTableOrNull(_trackpointsRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }
}

class $$RidesTableFilterComposer extends Composer<_$AppDatabase, $RidesTable> {
  $$RidesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get rideId => $composableBuilder(
    column: $table.rideId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get description => $composableBuilder(
    column: $table.description,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get typ => $composableBuilder(
    column: $table.typ,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get startTime => $composableBuilder(
    column: $table.startTime,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get endTime => $composableBuilder(
    column: $table.endTime,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get date => $composableBuilder(
    column: $table.date,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get comment => $composableBuilder(
    column: $table.comment,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get isFavorite => $composableBuilder(
    column: $table.isFavorite,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get favoritedAt => $composableBuilder(
    column: $table.favoritedAt,
    builder: (column) => ColumnFilters(column),
  );

  Expression<bool> trackpointsRefs(
    Expression<bool> Function($$TrackpointsTableFilterComposer f) f,
  ) {
    final $$TrackpointsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.rideId,
      referencedTable: $db.trackpoints,
      getReferencedColumn: (t) => t.rideId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$TrackpointsTableFilterComposer(
            $db: $db,
            $table: $db.trackpoints,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$RidesTableOrderingComposer
    extends Composer<_$AppDatabase, $RidesTable> {
  $$RidesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get rideId => $composableBuilder(
    column: $table.rideId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get description => $composableBuilder(
    column: $table.description,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get typ => $composableBuilder(
    column: $table.typ,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get startTime => $composableBuilder(
    column: $table.startTime,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get endTime => $composableBuilder(
    column: $table.endTime,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get date => $composableBuilder(
    column: $table.date,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get comment => $composableBuilder(
    column: $table.comment,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get isFavorite => $composableBuilder(
    column: $table.isFavorite,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get favoritedAt => $composableBuilder(
    column: $table.favoritedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$RidesTableAnnotationComposer
    extends Composer<_$AppDatabase, $RidesTable> {
  $$RidesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get rideId =>
      $composableBuilder(column: $table.rideId, builder: (column) => column);

  GeneratedColumn<String> get description => $composableBuilder(
    column: $table.description,
    builder: (column) => column,
  );

  GeneratedColumn<String> get typ =>
      $composableBuilder(column: $table.typ, builder: (column) => column);

  GeneratedColumn<int> get startTime =>
      $composableBuilder(column: $table.startTime, builder: (column) => column);

  GeneratedColumn<int> get endTime =>
      $composableBuilder(column: $table.endTime, builder: (column) => column);

  GeneratedColumn<int> get date =>
      $composableBuilder(column: $table.date, builder: (column) => column);

  GeneratedColumn<String> get comment =>
      $composableBuilder(column: $table.comment, builder: (column) => column);

  GeneratedColumn<bool> get isFavorite => $composableBuilder(
    column: $table.isFavorite,
    builder: (column) => column,
  );

  GeneratedColumn<int> get favoritedAt => $composableBuilder(
    column: $table.favoritedAt,
    builder: (column) => column,
  );

  Expression<T> trackpointsRefs<T extends Object>(
    Expression<T> Function($$TrackpointsTableAnnotationComposer a) f,
  ) {
    final $$TrackpointsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.rideId,
      referencedTable: $db.trackpoints,
      getReferencedColumn: (t) => t.rideId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$TrackpointsTableAnnotationComposer(
            $db: $db,
            $table: $db.trackpoints,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$RidesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $RidesTable,
          Ride,
          $$RidesTableFilterComposer,
          $$RidesTableOrderingComposer,
          $$RidesTableAnnotationComposer,
          $$RidesTableCreateCompanionBuilder,
          $$RidesTableUpdateCompanionBuilder,
          (Ride, $$RidesTableReferences),
          Ride,
          PrefetchHooks Function({bool trackpointsRefs})
        > {
  $$RidesTableTableManager(_$AppDatabase db, $RidesTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$RidesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$RidesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$RidesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> rideId = const Value.absent(),
                Value<String?> description = const Value.absent(),
                Value<String?> typ = const Value.absent(),
                Value<int?> startTime = const Value.absent(),
                Value<int?> endTime = const Value.absent(),
                Value<int?> date = const Value.absent(),
                Value<String?> comment = const Value.absent(),
                Value<bool> isFavorite = const Value.absent(),
                Value<int?> favoritedAt = const Value.absent(),
              }) => RidesCompanion(
                rideId: rideId,
                description: description,
                typ: typ,
                startTime: startTime,
                endTime: endTime,
                date: date,
                comment: comment,
                isFavorite: isFavorite,
                favoritedAt: favoritedAt,
              ),
          createCompanionCallback:
              ({
                Value<int> rideId = const Value.absent(),
                Value<String?> description = const Value.absent(),
                Value<String?> typ = const Value.absent(),
                Value<int?> startTime = const Value.absent(),
                Value<int?> endTime = const Value.absent(),
                Value<int?> date = const Value.absent(),
                Value<String?> comment = const Value.absent(),
                Value<bool> isFavorite = const Value.absent(),
                Value<int?> favoritedAt = const Value.absent(),
              }) => RidesCompanion.insert(
                rideId: rideId,
                description: description,
                typ: typ,
                startTime: startTime,
                endTime: endTime,
                date: date,
                comment: comment,
                isFavorite: isFavorite,
                favoritedAt: favoritedAt,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) =>
                    (e.readTable(table), $$RidesTableReferences(db, table, e)),
              )
              .toList(),
          prefetchHooksCallback: ({trackpointsRefs = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [if (trackpointsRefs) db.trackpoints],
              addJoins: null,
              getPrefetchedDataCallback: (items) async {
                return [
                  if (trackpointsRefs)
                    await $_getPrefetchedData<Ride, $RidesTable, Trackpoint>(
                      currentTable: table,
                      referencedTable: $$RidesTableReferences
                          ._trackpointsRefsTable(db),
                      managerFromTypedResult: (p0) =>
                          $$RidesTableReferences(db, table, p0).trackpointsRefs,
                      referencedItemsForCurrentItem: (item, referencedItems) =>
                          referencedItems.where((e) => e.rideId == item.rideId),
                      typedResults: items,
                    ),
                ];
              },
            );
          },
        ),
      );
}

typedef $$RidesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $RidesTable,
      Ride,
      $$RidesTableFilterComposer,
      $$RidesTableOrderingComposer,
      $$RidesTableAnnotationComposer,
      $$RidesTableCreateCompanionBuilder,
      $$RidesTableUpdateCompanionBuilder,
      (Ride, $$RidesTableReferences),
      Ride,
      PrefetchHooks Function({bool trackpointsRefs})
    >;
typedef $$TrackpointsTableCreateCompanionBuilder =
    TrackpointsCompanion Function({
      Value<int> trackpointId,
      required int rideId,
      required double latitude,
      required double longitude,
      required int timestamp,
      Value<double?> speed,
    });
typedef $$TrackpointsTableUpdateCompanionBuilder =
    TrackpointsCompanion Function({
      Value<int> trackpointId,
      Value<int> rideId,
      Value<double> latitude,
      Value<double> longitude,
      Value<int> timestamp,
      Value<double?> speed,
    });

final class $$TrackpointsTableReferences
    extends BaseReferences<_$AppDatabase, $TrackpointsTable, Trackpoint> {
  $$TrackpointsTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static $RidesTable _rideIdTable(_$AppDatabase db) =>
      db.rides.createAlias('trackpoints__ride_id__rides__ride_id');

  $$RidesTableProcessedTableManager get rideId {
    final $_column = $_itemColumn<int>('ride_id')!;

    final manager = $$RidesTableTableManager(
      $_db,
      $_db.rides,
    ).filter((f) => f.rideId.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_rideIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$TrackpointsTableFilterComposer
    extends Composer<_$AppDatabase, $TrackpointsTable> {
  $$TrackpointsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get trackpointId => $composableBuilder(
    column: $table.trackpointId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get latitude => $composableBuilder(
    column: $table.latitude,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get longitude => $composableBuilder(
    column: $table.longitude,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get timestamp => $composableBuilder(
    column: $table.timestamp,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get speed => $composableBuilder(
    column: $table.speed,
    builder: (column) => ColumnFilters(column),
  );

  $$RidesTableFilterComposer get rideId {
    final $$RidesTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.rideId,
      referencedTable: $db.rides,
      getReferencedColumn: (t) => t.rideId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$RidesTableFilterComposer(
            $db: $db,
            $table: $db.rides,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$TrackpointsTableOrderingComposer
    extends Composer<_$AppDatabase, $TrackpointsTable> {
  $$TrackpointsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get trackpointId => $composableBuilder(
    column: $table.trackpointId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get latitude => $composableBuilder(
    column: $table.latitude,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get longitude => $composableBuilder(
    column: $table.longitude,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get timestamp => $composableBuilder(
    column: $table.timestamp,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get speed => $composableBuilder(
    column: $table.speed,
    builder: (column) => ColumnOrderings(column),
  );

  $$RidesTableOrderingComposer get rideId {
    final $$RidesTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.rideId,
      referencedTable: $db.rides,
      getReferencedColumn: (t) => t.rideId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$RidesTableOrderingComposer(
            $db: $db,
            $table: $db.rides,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$TrackpointsTableAnnotationComposer
    extends Composer<_$AppDatabase, $TrackpointsTable> {
  $$TrackpointsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get trackpointId => $composableBuilder(
    column: $table.trackpointId,
    builder: (column) => column,
  );

  GeneratedColumn<double> get latitude =>
      $composableBuilder(column: $table.latitude, builder: (column) => column);

  GeneratedColumn<double> get longitude =>
      $composableBuilder(column: $table.longitude, builder: (column) => column);

  GeneratedColumn<int> get timestamp =>
      $composableBuilder(column: $table.timestamp, builder: (column) => column);

  GeneratedColumn<double> get speed =>
      $composableBuilder(column: $table.speed, builder: (column) => column);

  $$RidesTableAnnotationComposer get rideId {
    final $$RidesTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.rideId,
      referencedTable: $db.rides,
      getReferencedColumn: (t) => t.rideId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$RidesTableAnnotationComposer(
            $db: $db,
            $table: $db.rides,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$TrackpointsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $TrackpointsTable,
          Trackpoint,
          $$TrackpointsTableFilterComposer,
          $$TrackpointsTableOrderingComposer,
          $$TrackpointsTableAnnotationComposer,
          $$TrackpointsTableCreateCompanionBuilder,
          $$TrackpointsTableUpdateCompanionBuilder,
          (Trackpoint, $$TrackpointsTableReferences),
          Trackpoint,
          PrefetchHooks Function({bool rideId})
        > {
  $$TrackpointsTableTableManager(_$AppDatabase db, $TrackpointsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$TrackpointsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$TrackpointsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$TrackpointsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> trackpointId = const Value.absent(),
                Value<int> rideId = const Value.absent(),
                Value<double> latitude = const Value.absent(),
                Value<double> longitude = const Value.absent(),
                Value<int> timestamp = const Value.absent(),
                Value<double?> speed = const Value.absent(),
              }) => TrackpointsCompanion(
                trackpointId: trackpointId,
                rideId: rideId,
                latitude: latitude,
                longitude: longitude,
                timestamp: timestamp,
                speed: speed,
              ),
          createCompanionCallback:
              ({
                Value<int> trackpointId = const Value.absent(),
                required int rideId,
                required double latitude,
                required double longitude,
                required int timestamp,
                Value<double?> speed = const Value.absent(),
              }) => TrackpointsCompanion.insert(
                trackpointId: trackpointId,
                rideId: rideId,
                latitude: latitude,
                longitude: longitude,
                timestamp: timestamp,
                speed: speed,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$TrackpointsTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({rideId = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [],
              addJoins:
                  <
                    T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic
                    >
                  >(state) {
                    if (rideId) {
                      state =
                          state.withJoin(
                                currentTable: table,
                                currentColumn: table.rideId,
                                referencedTable: $$TrackpointsTableReferences
                                    ._rideIdTable(db),
                                referencedColumn: $$TrackpointsTableReferences
                                    ._rideIdTable(db)
                                    .rideId,
                              )
                              as T;
                    }

                    return state;
                  },
              getPrefetchedDataCallback: (items) async {
                return [];
              },
            );
          },
        ),
      );
}

typedef $$TrackpointsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $TrackpointsTable,
      Trackpoint,
      $$TrackpointsTableFilterComposer,
      $$TrackpointsTableOrderingComposer,
      $$TrackpointsTableAnnotationComposer,
      $$TrackpointsTableCreateCompanionBuilder,
      $$TrackpointsTableUpdateCompanionBuilder,
      (Trackpoint, $$TrackpointsTableReferences),
      Trackpoint,
      PrefetchHooks Function({bool rideId})
    >;

class $AppDatabaseManager {
  final _$AppDatabase _db;
  $AppDatabaseManager(this._db);
  $$RidesTableTableManager get rides =>
      $$RidesTableTableManager(_db, _db.rides);
  $$TrackpointsTableTableManager get trackpoints =>
      $$TrackpointsTableTableManager(_db, _db.trackpoints);
}
