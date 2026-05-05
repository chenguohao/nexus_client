import 'package:dartz/dartz.dart';
import 'package:debounce_throttle/debounce_throttle.dart';
import 'package:fluffychat/app_state/failure.dart';
import 'package:fluffychat/app_state/success.dart';
import 'package:fluffychat/di/global/get_it_initializer.dart';
import 'package:fluffychat/domain/app_state/contact/get_contacts_state.dart';
import 'package:fluffychat/domain/app_state/search/search_state.dart';
import 'package:fluffychat/domain/contact_manager/contacts_manager.dart';
import 'package:fluffychat/domain/model/contact/contact_type.dart';
import 'package:fluffychat/domain/model/extensions/contact/contact_extension.dart';
import 'package:fluffychat/domain/usecase/search/search_recent_chat_interactor.dart';
import 'package:fluffychat/presentation/extensions/contact/presentation_contact_extension.dart';
import 'package:fluffychat/presentation/extensions/value_notifier_custom.dart';
import 'package:fluffychat/presentation/model/contact/get_presentation_contacts_empty.dart';
import 'package:fluffychat/presentation/model/contact/get_presentation_contacts_failure.dart';
import 'package:fluffychat/presentation/model/contact/get_presentation_contacts_success.dart';
import 'package:fluffychat/presentation/model/contact/presentation_contact.dart';
import 'package:fluffychat/presentation/model/contact/presentation_contact_success.dart';
import 'package:fluffychat/presentation/model/search/presentation_search.dart';
import 'package:fluffychat/presentation/model/search/presentation_search_state_extension.dart';
import 'package:fluffychat/utils/extension/presentation_search_extension.dart';
import 'package:flutter/material.dart';
import 'package:matrix/matrix.dart';

mixin class ContactsViewControllerMixin {
  static const _debouncerIntervalInMilliseconds = 300;
  static const _defaultLimitRecentContacts = 6;

  final TextEditingController textEditingController = TextEditingController();

  final SearchRecentChatInteractor _searchRecentChatInteractor =
      getIt.get<SearchRecentChatInteractor>();

  // FIXME: Consider can use FocusNode instead ?
  final ValueNotifier<bool> isSearchModeNotifier = ValueNotifier(false);

  final presentationRecentContactNotifier =
      ValueNotifierCustom<List<PresentationSearch>>([]);

  final presentationContactNotifier =
      ValueNotifierCustom<Either<Failure, Success>>(
        const Right(ContactsInitial()),
      );

  final FocusNode searchFocusNode = FocusNode();

  final Debouncer<String> _debouncer = Debouncer(
    const Duration(milliseconds: _debouncerIntervalInMilliseconds),
    initialValue: '',
  );

  final contactsManager = getIt.get<ContactsManager>();

  void initialFetchContacts({
    required BuildContext context,
    required Client client,
    required MatrixLocalizations matrixLocalizations,
    bool forceRun = false,
  }) async {
    _refreshAllContacts(
      context: context,
      client: client,
      matrixLocalizations: matrixLocalizations,
    );
    _listenContactsDataChange(
      context: context,
      client: client,
      matrixLocalizations: matrixLocalizations,
    );
    textEditingController.addListener(() {
      _debouncer.value = textEditingController.text;
    });

    _debouncer.values.listen((keyword) {
      _refreshAllContacts(
        context: context,
        client: client,
        matrixLocalizations: matrixLocalizations,
      );
    });

    if (client.userID == null) return;
    await contactsManager.initialSynchronizeContacts(
      withMxId: client.userID!,
      isAvailableSupportPhonebookContacts: false,
      forceRun: forceRun,
    );
  }

  void synchronizeContactsOnContactTab({
    required BuildContext context,
    required Client client,
    required MatrixLocalizations matrixLocalizations,
  }) async {
    _refreshAllContacts(
      context: context,
      client: client,
      matrixLocalizations: matrixLocalizations,
    );
    _listenContactsDataChange(
      context: context,
      client: client,
      matrixLocalizations: matrixLocalizations,
    );
    textEditingController.addListener(() {
      _debouncer.value = textEditingController.text;
    });

    _debouncer.values.listen((keyword) {
      _refreshAllContacts(
        context: context,
        client: client,
        matrixLocalizations: matrixLocalizations,
      );
    });

    if (client.userID == null) return;
    await contactsManager.synchronizeContactsOnContactTab(
      withMxId: client.userID!,
      isAvailableSupportPhonebookContacts: false,
    );
  }

  void _listenContactsDataChange({
    required BuildContext context,
    required Client client,
    required MatrixLocalizations matrixLocalizations,
  }) {
    contactsManager.getContactsNotifier().addListener(
      () => _refreshAllContacts(
        context: context,
        client: client,
        matrixLocalizations: matrixLocalizations,
      ),
    );
  }

  void _refreshAllContacts({
    required BuildContext context,
    required Client client,
    required MatrixLocalizations matrixLocalizations,
  }) {
    final keyword = _debouncer.value.trim();
    _refreshContacts(keyword);
    _refreshRecentContacts(
      context: context,
      client: client,
      keyword: keyword.isEmpty ? null : keyword,
      matrixLocalizations: matrixLocalizations,
    );
  }

  Future<void> _refreshContacts(String keyword) async {
    if (presentationContactNotifier.isDisposed) return;

    final externalContactState = _checkExternalContact(keyword);

    presentationContactNotifier
        .value = contactsManager.getContactsNotifier().value.fold(
      (failure) {
        if (externalContactState != null) {
          return externalContactState;
        }
        if (failure is GetContactsFailure) {
          return _handleSearchExternalContact(
            keyword,
            otherResult: Left(GetPresentationContactsFailure(keyword: keyword)),
          );
        }
        if (failure is GetContactsIsEmpty) {
          return _handleSearchExternalContact(
            keyword,
            otherResult: Left(GetPresentationContactsEmpty(keyword: keyword)),
          );
        }
        return Left(failure);
      },
      (success) {
        if (success is GetContactsSuccess) {
          final filteredContacts = success.contacts
              .searchContacts(keyword)
              .expand((contact) => contact.toPresentationContacts())
              .toList();

          if (filteredContacts.isEmpty) {
            return externalContactState ??
                Left(GetPresentationContactsEmpty(keyword: keyword));
          } else {
            return Right(
              GetPresentationContactsSuccess(
                contacts: filteredContacts,
                keyword: keyword,
              ),
            );
          }
        }
        return externalContactState ?? Right(success);
      },
    );
  }

  Either<Failure, Success>? _checkExternalContact(String keyword) {
    if (keyword.isValidMatrixId && keyword.startsWith("@")) {
      return Right(
        PresentationExternalContactSuccess(
          contact: PresentationContact(
            matrixId: keyword,
            displayName: keyword.substring(1),
            type: ContactType.external,
          ),
        ),
      );
    }
    return null;
  }

  Either<Failure, Success> _handleSearchExternalContact(
    String keyword, {
    required Either<Failure, Success> otherResult,
  }) {
    if (keyword.isValidMatrixId && keyword.startsWith("@")) {
      return Right(
        PresentationExternalContactSuccess(
          contact: PresentationContact(
            matrixId: keyword,
            displayName: keyword.substring(1),
            type: ContactType.external,
          ),
        ),
      );
    } else {
      return otherResult;
    }
  }

  Future<void> _refreshRecentContacts({
    required BuildContext context,
    required Client client,
    required MatrixLocalizations matrixLocalizations,
    String? keyword,
  }) async {
    _searchRecentChatInteractor
        .execute(
          keyword: keyword ?? '',
          matrixLocalizations: matrixLocalizations,
          rooms: client.rooms,
        )
        .listen((event) {
          event.map((success) {
            if (success is SearchRecentChatSuccess) {
              final recent = success
                  .toPresentation()
                  .contacts
                  .where((contact) => contact.directChatMatrixID != null)
                  .toList();

              final tomContacts =
                  contactsManager
                      .getContactsNotifier()
                      .value
                      .getSuccessOrNull<GetContactsSuccess>()
                      ?.contacts ??
                  [];
              final tomPresentationSearchContacts = tomContacts
                  .expand((contact) => contact.toPresentationContacts())
                  .toList();
              final tomContactPresentationSearchMatched =
                  tomPresentationSearchContacts
                      .expand((contact) => contact.toPresentationSearch())
                      .where(
                        (contact) => contact.doesMatchKeyword(success.keyword),
                      )
                      .toList();
              if (presentationRecentContactNotifier.isDisposed) return;

              presentationRecentContactNotifier.value =
                  handleSearchRecentContacts(
                    contacts: tomContactPresentationSearchMatched,
                    recentChat: recent,
                    keyword: success.keyword,
                  );
            }
          });
        });
  }

  List<PresentationSearch> handleSearchRecentContacts({
    required List<PresentationSearch> contacts,
    required List<PresentationSearch> recentChat,
    required String keyword,
  }) {
    if (keyword.isEmpty) {
      return _getRecentContactsExcludingContacts(
        recentChat: recentChat,
        contacts: contacts,
      ).take(_defaultLimitRecentContacts).toList();
    } else {
      return _getRecentContactsExcludingContacts(
        recentChat: recentChat,
        contacts: contacts,
      );
    }
  }

  List<PresentationSearch> _getRecentContactsExcludingContacts({
    required List<PresentationSearch> contacts,
    required List<PresentationSearch> recentChat,
  }) {
    final contactIds = contacts.map((contact) => contact.id).toSet();
    final List<PresentationSearch> filteredRecentChat = recentChat.where((
      chat,
    ) {
      return !contactIds.contains(chat.directChatMatrixID);
    }).toList();

    return filteredRecentChat;
  }

  void openSearchBar() {
    isSearchModeNotifier.value = true;
    searchFocusNode.requestFocus();
  }

  void onSelectedContact() {
    searchFocusNode.requestFocus();
    textEditingController.selection = TextSelection(
      baseOffset: 0,
      extentOffset: textEditingController.text.length,
    );
  }

  void closeSearchBar() {
    textEditingController.clear();
    searchFocusNode.unfocus();
    isSearchModeNotifier.value = false;
  }

  void disposeContactsMixin() {
    textEditingController.clear();
    searchFocusNode.dispose();
    textEditingController.dispose();
    isSearchModeNotifier.dispose();
    presentationRecentContactNotifier.dispose();
    presentationContactNotifier.dispose();
  }

  @visibleForTesting
  void refreshAllContactsTest({
    required BuildContext context,
    required Client client,
    required MatrixLocalizations matrixLocalizations,
  }) {
    _refreshAllContacts(
      context: context,
      client: client,
      matrixLocalizations: matrixLocalizations,
    );
  }
}
