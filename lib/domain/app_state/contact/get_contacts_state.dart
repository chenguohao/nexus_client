import 'package:fluffychat/app_state/failure.dart';
import 'package:fluffychat/app_state/initial.dart';
import 'package:fluffychat/app_state/success.dart';
import 'package:fluffychat/domain/model/contact/contact.dart';
import 'package:fluffychat/domain/model/contact/friend_status.dart';

class ContactsInitial extends Initial {
  const ContactsInitial() : super();

  @override
  List<Object?> get props => [];
}

class ContactsLoading extends Success {
  const ContactsLoading() : super();

  @override
  List<Object?> get props => [];
}

class GetContactsSuccess extends Success {
  final List<Contact> contacts;

  /// 按 mxid 索引的好友状态。供个人页按钮、拉群入口、邀请页等做状态判断。
  /// 老链路构造时可省略，缺省 = 不知道任何 mxid 的状态。
  final Map<String, FriendStatus> friendStatusByMxid;

  const GetContactsSuccess({
    required this.contacts,
    this.friendStatusByMxid = const <String, FriendStatus>{},
  });

  @override
  List<Object?> get props => [contacts, friendStatusByMxid];
}

class GetContactsIsEmpty extends Failure {
  const GetContactsIsEmpty();

  @override
  List<Object?> get props => [];
}

class GetContactsFailure extends Failure {
  final String keyword;
  final dynamic exception;

  const GetContactsFailure({required this.keyword, required this.exception});

  @override
  List<Object?> get props => [keyword, exception];
}
