import 'dart:convert';

import 'package:equatable/equatable.dart';
import 'package:crypto/crypto.dart';
import 'package:fluffychat/domain/model/contact/friend_status.dart';
import 'package:fluffychat/domain/model/contact/third_party_status.dart';
import 'package:fluffychat/utils/string_extension.dart';
import 'package:matrix/encryption/utils/base64_unpadded.dart';

enum ThirdPartyIdType {
  email,
  msisdn;

  @override
  String toString() {
    switch (this) {
      case email:
        return 'email';
      case msisdn:
        return 'msisdn';
    }
  }
}

class Contact extends Equatable {
  final String id;

  final Set<Email>? emails;

  final String? displayName;

  final Set<PhoneNumber>? phoneNumbers;

  /// 好友关系状态。默认 [FriendStatus.accepted]，对老接口/老数据兼容。
  final FriendStatus friendStatus;

  /// 通讯录条目在服务端最后更新时间（Unix 毫秒）。旧数据可能为 null。
  final int? updatedAtMillis;

  const Contact({
    required this.id,
    this.emails,
    this.displayName,
    this.phoneNumbers,
    this.friendStatus = FriendStatus.accepted,
    this.updatedAtMillis,
  });

  @override
  List<Object?> get props => [
    id,
    emails,
    displayName,
    phoneNumbers,
    friendStatus,
    updatedAtMillis,
  ];

  Contact copyWith({
    String? displayName,
    Set<Email>? emails,
    Set<PhoneNumber>? phoneNumbers,
    FriendStatus? friendStatus,
    int? updatedAtMillis,
  }) {
    return Contact(
      id: id,
      displayName: displayName ?? this.displayName,
      emails: emails ?? this.emails,
      phoneNumbers: phoneNumbers ?? this.phoneNumbers,
      friendStatus: friendStatus ?? this.friendStatus,
      updatedAtMillis: updatedAtMillis ?? this.updatedAtMillis,
    );
  }
}

abstract class ThirdPartyContact with EquatableMixin {
  final String? matrixId;

  final String thirdPartyId;

  final ThirdPartyIdType thirdPartyIdType;

  final ThirdPartyStatus? status;

  final Map<String, List<String>>? thirdPartyIdToHashMap;

  ThirdPartyContact({
    required this.thirdPartyId,
    required this.thirdPartyIdType,
    this.matrixId,
    this.status,
    this.thirdPartyIdToHashMap,
  });

  String calculateHashWithAlgorithmSha256({required String pepper}) {
    final input = [thirdPartyId, thirdPartyIdType, pepper].join(' ');
    final bytes = utf8.encode(input);
    final lookupHash = encodeBase64Unpadded(
      sha256.convert(bytes).bytes,
    ).urlSafeBase64;
    return lookupHash;
  }

  String calculateHashWithoutAlgorithm() {
    return [thirdPartyId, thirdPartyIdType].join(' ');
  }

  List<String> calculateHashUsingAllPeppers({
    String? lookupPepper,
    Set<String>? altLookupPeppers,
    Set<String>? algorithms,
  }) {
    final List<String> hashes = [];

    if (algorithms == null || algorithms.isEmpty) {
      final hash = calculateHashWithoutAlgorithm();
      hashes.add(hash);
      return hashes;
    }

    for (final algorithm in algorithms) {
      final peppers = {lookupPepper, ...?altLookupPeppers};

      for (final pepper in peppers) {
        if (algorithm == 'sha256') {
          final hash = calculateHashWithAlgorithmSha256(pepper: pepper ?? '');
          hashes.add(hash);
        } else {
          final hash = calculateHashWithoutAlgorithm();
          hashes.add(hash);
        }
      }
    }
    return hashes;
  }

  @override
  List<Object?> get props => [
    thirdPartyId,
    thirdPartyIdType,
    matrixId,
    status,
    thirdPartyIdToHashMap,
  ];
}

class PhoneNumber extends ThirdPartyContact {
  final String number;

  PhoneNumber({
    required this.number,
    super.matrixId,
    super.status,
    super.thirdPartyIdToHashMap,
  }) : super(
         thirdPartyId: number.msisdnSanitizer(),
         thirdPartyIdType: ThirdPartyIdType.msisdn,
       );

  @override
  List<Object?> get props => [
    number,
    matrixId,
    status,
    thirdPartyIdToHashMap,
    thirdPartyId,
    thirdPartyIdType,
  ];

  PhoneNumber copyWith({
    String? matrixId,
    ThirdPartyStatus? status,
    Map<String, List<String>>? thirdPartyIdToHashMap,
  }) {
    return PhoneNumber(
      number: number,
      matrixId: matrixId ?? this.matrixId,
      status: status ?? this.status,
      thirdPartyIdToHashMap:
          thirdPartyIdToHashMap ?? this.thirdPartyIdToHashMap,
    );
  }
}

class Email extends ThirdPartyContact {
  final String address;

  Email({
    required this.address,
    super.matrixId,
    super.status,
    super.thirdPartyIdToHashMap,
  }) : super(thirdPartyId: address, thirdPartyIdType: ThirdPartyIdType.email);

  Email copyWith({
    String? matrixId,
    ThirdPartyStatus? status,
    Map<String, List<String>>? thirdPartyIdToHashMap,
  }) {
    return Email(
      address: address,
      matrixId: matrixId ?? this.matrixId,
      status: status ?? this.status,
      thirdPartyIdToHashMap:
          thirdPartyIdToHashMap ?? this.thirdPartyIdToHashMap,
    );
  }

  @override
  List<Object?> get props => [
    address,
    matrixId,
    status,
    thirdPartyIdToHashMap,
    thirdPartyId,
    thirdPartyIdType,
  ];
}
