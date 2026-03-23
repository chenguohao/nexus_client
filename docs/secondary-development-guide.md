# Twake Chat Secondary Development Guide

## 1. Document Purpose

This document is written for secondary development based on the current `twake-on-matrix` codebase.

It focuses on:

- What this project is
- How the technical architecture is organized
- Which functional modules already exist
- Which parts are suitable for direct reuse
- Which parts are risky or expensive to modify
- A practical reading order for onboarding

This is not a line-by-line code explanation. It is an engineering overview for building a similar app by modifying this codebase.

## 2. Project Positioning

`Twake Chat` is a Matrix-based chat client built with Flutter.

From the product perspective, it already contains the core capabilities needed by a modern communication app:

- Login and homeserver selection
- 1-to-1 chat and group chat
- Room list, archive, drafts
- File, image, video, link sharing
- Contacts and address book lookup
- Push notifications
- Share extension support
- Settings and account management
- Encryption-related account flows
- Story/media related features

From the architecture perspective, this is not a small demo project. It is already a medium-to-large production-style codebase with:

- clear folder layering
- service locator dependency injection
- multiple local storage mechanisms
- native mobile integration
- route-driven UI composition
- many product-specific business rules

## 3. Tech Stack Overview

### 3.1 Main Frameworks

- Flutter `3.38.9`
- Dart `3.10.x`
- Matrix SDK via `matrix`
- Routing via `go_router`
- DI via `get_it`
- Global state via `provider`
- Feature state via `ValueNotifier`, streams, local controllers, mixins
- Network requests via `dio`
- Functional result model via `dartz` `Either`

### 3.2 Storage and Local Data

- `Hive` for local structured cache and object persistence
- `sqflite` / `sqflite_common_ffi` for Matrix SDK database
- `shared_preferences` for lightweight local settings/cache
- custom store wrapper in `lib/utils/famedlysdk_store.dart`

### 3.3 Important Native / Platform Packages

- `receive_sharing_intent`
- `app_links`
- `flutter_local_notifications`
- `unifiedpush`
- `fcm_shared_isolate`
- `flutter_secure_storage`
- `photo_manager`
- `media_kit`
- `open_file`
- `share_plus`

### 3.4 Dependency Characteristics

This project depends on many Git-based packages, not only pub.dev releases.

Examples from `pubspec.yaml`:

- `receive_sharing_intent`
- `linagora_design_flutter`
- `flutter_matrix_html`
- `image_gallery_saver`
- `future_loading_dialog`
- `linkfy_text`
- `social_media_recorder`
- `native_imaging`

Implication for secondary development:

- the project is powerful, but dependency stability depends on external Git refs
- upgrading Flutter or plugins may trigger chain reactions
- keeping a lockstep toolchain is important

## 4. High-Level Directory Architecture

Top-level structure under `lib/`:

- `config`: app-wide config, theme, routes, localization, runtime config
- `data`: APIs, datasources, local storage adapters, repository implementations
- `domain`: repository contracts, models, failures, use cases/interactors
- `pages`: page-level product features
- `presentation`: controllers, decorators, mixins, lightweight UI state helpers
- `widgets`: reusable app shell widgets and layout scaffolds
- `utils`: cross-cutting services and helpers
- `modules`: more isolated business subdomains
- `di`: dependency registration

Recommended mental model:

- `domain` defines what the app wants to do
- `data` defines how data is fetched/stored
- `pages` and `widgets` define what users see
- `utils` and `di` hold system glue

## 5. Application Startup Flow

Core startup files:

- `lib/main.dart`
- `lib/widgets/twake_app.dart`
- `lib/widgets/matrix.dart`
- `lib/config/go_routes/go_router.dart`

Startup sequence:

1. `main()` performs platform bootstrap
2. Flutter bindings, storage, media stack, and DI are initialized
3. Matrix clients are restored through `ClientManager.getClients()`
4. `TwakeApp` builds `MaterialApp.router`
5. `Matrix` wraps the app and becomes the session/runtime root
6. Router decides whether the user enters login flow or room flow

Important architectural note:

The true app runtime state is not in `main.dart`. It lives in `MatrixState` inside `lib/widgets/matrix.dart`.

That class is responsible for things such as:

- active Matrix client state
- login/session lifecycle
- first sync handling
- push initialization
- sharing intent setup
- app-level subscriptions

## 6. Core Architectural Pattern

This project mostly follows this pattern:

`API -> DataSource -> Repository -> Interactor -> UI/controller`

### 6.1 Example Layering

- API classes live in `lib/data/network/...`
- datasource interfaces and implementations live in `lib/data/datasource/...` and `lib/data/datasource_impl/...`
- repository interfaces live in `lib/domain/repository/...`
- repository implementations live in `lib/data/repository/...`
- business use cases live in `lib/domain/usecase/...`
- pages/controllers call interactors and convert results to UI state

### 6.2 Result Model

Many business flows use `Either<Failure, Success>` from `dartz`.

This is useful for secondary development because it gives a consistent error/success pattern, but it also means:

- logic is more explicit than throwing exceptions everywhere
- UI code must know how to unwrap stream-based results

### 6.3 State Management Style

This codebase is mixed, not single-framework state management.

Main patterns:

- `Provider` for global app/session state
- `GetIt` for dependency resolution
- `ValueNotifier` and custom notifier helpers for page state
- streams and subscriptions for event-driven updates
- many controller mixins in `presentation/mixins`

This is practical, but secondary development should keep discipline. If you add another full state framework on top, the architecture may become fragmented.

## 7. Dependency Injection Design

Composition root:

- `lib/di/global/get_it_initializer.dart`

`GetItInitializer.setUp()` binds:

- global services
- worker queues
- APIs
- managers
- datasources
- repositories
- interactors
- some controllers

Important global registrations include:

- `ResponsiveUtils`
- `TwakeEventDispatcher`
- `Store`
- download/upload queues and managers
- network stacks
- cache managers

This means the app is heavily service-locator driven.

Pros:

- easy access to shared services
- straightforward app-wide wiring

Cons:

- hidden dependencies are easier to create
- testing large features can become harder if constructors do not expose enough dependencies

## 8. Routing and UI Shell

Main router:

- `lib/config/go_routes/go_router.dart`

App shell:

- `lib/widgets/twake_app.dart`
- `lib/widgets/layouts/adaptive_layout/app_adaptive_scaffold.dart`

Routing characteristics:

- based on `go_router`
- supports logged-in and logged-out flows
- uses a `ShellRoute` style layout for `/rooms`
- combines navigation with responsive behavior

Important route groups:

- `/home`
- `/login`
- `/signup`
- `/connect`
- `/onAuthRedirect`
- `/rooms`
- `/rooms/:roomid`
- `/rooms/archive`
- `/rooms/share`
- `/rooms/draftChat`

UI composition characteristic:

The project is strongly responsive-aware. It is not built only for phone layout. Desktop/tablet adaptive behavior is already a first-class concern.

If you want a similar app for multiple device types, this is a strong area to reuse.

## 9. Functional Module Map

This section describes the main user-facing modules you can reuse or modify.

### 9.1 App Shell and Session Runtime

Responsibility:

- app startup
- current client/session
- global subscriptions
- theme and localization hookup
- bootstrapping sharing intent and push

Key files:

- `lib/main.dart`
- `lib/widgets/twake_app.dart`
- `lib/widgets/matrix.dart`

Secondary development advice:

- reuse this layer if you still want a Matrix-style multi-account app
- rewrite it if your future app is single-account and significantly simpler

### 9.2 Login and Homeserver Flow

Responsibility:

- welcome page
- homeserver selection
- SSO provider flow
- login and signup
- auth redirect handling

Key files:

- `lib/pages/twake_welcome/twake_welcome.dart`
- `lib/pages/auto_homeserver_picker/auto_homeserver_picker.dart`
- `lib/pages/homeserver_picker/homeserver_picker.dart`
- `lib/pages/connect/connect_page.dart`
- `lib/pages/login/login.dart`
- `lib/pages/sign_up/signup.dart`
- `lib/pages/login/on_auth_redirect.dart`

Secondary development advice:

- keep this if your app still depends on Matrix homeservers or SSO
- simplify heavily if your new app uses one fixed backend

### 9.3 Room List and Main Navigation

Responsibility:

- room list
- pinned rooms
- drafts
- archive
- main app navigation

Key files:

- `lib/pages/chat_list/chat_list.dart`
- `lib/pages/archive/archive.dart`
- `lib/widgets/layouts/adaptive_layout/app_adaptive_scaffold.dart`

Secondary development advice:

- high reuse value if your product is still chat-centric
- route composition and adaptive split layout are especially reusable

### 9.4 Chat Timeline and Messaging

Responsibility:

- chat page
- event rendering
- message cells
- replies, reactions, attachments, message operations
- room-specific interactions

Key files:

- `lib/pages/chat/chat.dart`
- `lib/pages/chat/events/message/message.dart`
- `lib/pages/chat/events/...`
- `lib/pages/chat/chat_pinned_events/...`

Secondary development advice:

- this is one of the heaviest and most business-dense parts of the codebase
- reuse if you want a Matrix message timeline
- expect expensive modifications if you want a very different message model

### 9.5 Chat Details and Room Management

Responsibility:

- room details
- members
- media/files/links tabs
- permissions, moderation, pinned messages

Key files:

- `lib/pages/chat_details/chat_details.dart`
- `lib/pages/chat_details/chat_details_page_view/...`

Secondary development advice:

- good reuse value for group/community products
- moderation and room metadata parts can be selectively retained

### 9.6 Contacts and Identity Lookup

Responsibility:

- contact list
- address book sync
- contact search
- phonebook lookup
- federation identity mapping

Key files:

- `lib/pages/contacts_tab/contacts_tab.dart`
- `lib/pages/new_private_chat/new_private_chat.dart`
- `lib/modules/federation_identity_lookup/...`
- `lib/modules/federation_identity_request_token/...`

Secondary development advice:

- if your app depends on real-world contacts and Matrix identity resolution, reuse is high
- if not, this area can be simplified a lot

### 9.7 Search

Responsibility:

- local recent chat search
- room/member lookup
- server search

Key files:

- `lib/pages/search/search.dart`
- `lib/pages/chat_search/chat_search.dart`
- `lib/domain/usecase/search/...`

### 9.8 Sharing Intent and External Content Intake

Responsibility:

- receive files/text/links from system share sheet
- cache initial share intent at cold start
- route shared content into room selection or deep-link flow

Key files:

- `lib/pages/chat_list/receive_sharing_intent_mixin.dart`
- `lib/pages/share/share.dart`
- `ios/TwakeShareExtension/ShareViewController.swift`

Secondary development advice:

- very valuable if your new app supports “share to app”
- also one of the most sensitive areas for iOS build/config issues

### 9.9 Media, Story, and File Preview

Responsibility:

- image viewer
- media viewer
- story page
- add story
- file preview and download/open flow

Key files:

- `lib/pages/image_viewer/image_viewer.dart`
- `lib/pages/media_viewer/media_viewer_view.dart`
- `lib/pages/story/story_page.dart`
- `lib/pages/add_story/add_story.dart`
- `lib/widgets/mixins/handle_download_and_preview_file_mixin.dart`

### 9.10 Settings and Account Management

Responsibility:

- profile
- appearance
- language
- notifications
- privacy/security
- blocked users
- device and account operations

Key files:

- `lib/pages/settings_dashboard/settings/...`
- `lib/pages/settings_dashboard/settings_profile/...`
- `lib/pages/settings_dashboard/settings_security/...`
- `lib/pages/bootstrap/...`
- `lib/pages/key_verification/...`

Secondary development advice:

- high reuse if your app keeps Matrix accounts and encryption features
- if you want a lighter app, this module is a good place to reduce scope

### 9.11 Push Notifications and Background Work

Responsibility:

- push registration
- push payload handling
- local notifications
- badge updates
- Android UnifiedPush / shared isolate
- iOS APN channel handling

Key files:

- `lib/utils/background_push.dart`
- `ios/NSE/...`

Secondary development advice:

- critical for a production chat app
- expensive to rework because it spans Flutter, native iOS, native Android, and backend push behavior

### 9.12 VoIP / Call Capability

Current state:

- traces of call-related functionality exist
- full WebRTC/call flow appears not to be the main active path in the current codebase

Relevant files:

- `lib/pages/chat/events/call_invite_content.dart`
- `lib/utils/voip/callkeep_manager.dart`

Recommendation:

- treat this as partial or reserved capability
- do not assume it is production-complete without deeper validation

## 10. Matrix Integration Design

This is one of the most important parts if you want to build a similar product.

Key file:

- `lib/utils/client_manager.dart`

Main behavior:

- restores one or more Matrix clients from local store
- initializes Matrix SDK databases
- supports multiple accounts
- configures supported login methods
- uses `sqflite` database for Matrix SDK
- still maintains a legacy Hive database builder path

Important detail:

The app is not purely “Flutter UI over REST APIs”.

It relies deeply on Matrix client runtime behavior:

- room state
- sync lifecycle
- encryption
- event timelines
- push handling
- identity/session state

Implication:

If your future app still uses Matrix as the protocol, this project has high reuse value.

If your future app only wants “a chat UI similar to this” but uses a different backend, large parts of chat/session/business flow will need replacement.

## 11. Data Layer and Storage Design

### 11.1 Network Layer

Main files:

- `lib/di/global/network_di.dart`
- `lib/data/network/...`

Characteristics:

- based on `dio`
- multiple named clients/stacks
- dynamic URL interception
- custom authorization interception

### 11.2 Repository Pattern

Main locations:

- `lib/domain/repository/...`
- `lib/data/repository/...`

Examples of repository domains:

- contacts
- invitation
- media
- user info
- reactions
- server config
- server search
- recovery words
- localizations

### 11.3 Local Persistence

Used for:

- Matrix SDK data
- account/session metadata
- Hive object caches
- language and preference cache
- invitation status
- contacts and third-party contacts

Important files:

- `lib/utils/client_manager.dart`
- `lib/di/global/hive_di.dart`
- `lib/data/hive/...`
- `lib/data/local/...`
- `lib/utils/famedlysdk_store.dart`

Implication:

This app already has a mature offline-first tendency.

For secondary development, this is useful, but changes to models usually require:

- updating entity classes
- running code generation
- checking Hive adapters / serialization compatibility

## 12. Native Platform Integration

### 12.1 iOS

Important native pieces:

- share extension in `ios/TwakeShareExtension`
- notification service extension in `ios/NSE`
- CocoaPods-managed plugin integration
- Xcode target-specific bundle identifiers and signing

### 12.2 Android

Not fully analyzed line by line here, but Flutter plugin usage indicates:

- push/background handling
- notification flow
- media/file access
- contacts and permissions

### 12.3 Practical Takeaway

This is not a pure Flutter-only project anymore.

If you perform secondary development for production:

- iOS targets and extensions must be treated as first-class engineering scope
- plugin upgrades must be tested on both Android and iOS

## 13. Build and Tooling Characteristics

### 13.1 Required Toolchain

From current project requirements and observed build behavior:

- Flutter `3.38.9`
- Dart `>=3.10.0 <4.0.0`
- code generation must be available

### 13.2 Code Generation

This project requires generated files such as `*.g.dart`.

Typical command:

```bash
flutter pub get
flutter pub run build_runner build --delete-conflicting-outputs
```

If these files are missing, app compilation will fail even before native packaging finishes.

### 13.3 Secondary Development Advice

Before any big change:

1. lock Flutter version first
2. run `pub get`
3. run `build_runner`
4. then run platform build

## 14. Key Engineering Risks for Secondary Development

### 14.1 Mixed State Management

The codebase is understandable, but not centralized around one state architecture.

Risk:

- harder onboarding
- duplicated patterns if new developers add another state solution

Recommendation:

- keep existing style for short-term modification
- only refactor state management if you have time and clear architecture goals

### 14.2 Heavy Plugin and Native Dependency Surface

Risk:

- iOS and Android builds are sensitive
- plugin API changes can break runtime and build

Recommendation:

- avoid upgrading many plugins at once
- keep a tested baseline branch

### 14.3 Git Dependencies

Risk:

- upstream refs may change or disappear
- reproducibility depends on external repos

Recommendation:

- fork critical Git dependencies if your project will be long-lived

### 14.4 Matrix-Centric Business Coupling

Risk:

- chat, session, sync, event timeline, and settings are tightly connected to Matrix assumptions

Recommendation:

- if your new app still uses Matrix, keep most of the architecture
- if your new app uses a different protocol, expect partial rewrite rather than simple skinning

### 14.5 iOS Multi-Target Complexity

Risk:

- main app + share extension + notification extension create extra bundle id and build config complexity

Recommendation:

- plan bundle identifiers early
- keep Debug and Release identifiers/signing clearly separated

## 15. What Is Most Reusable

High reuse value:

- app shell and route structure
- responsive scaffold and room shell
- login/homeserver flow if still Matrix-based
- room list and room detail shell
- sharing intent flow
- push/background integration structure
- settings center structure
- upload/download manager design

Medium reuse value:

- contact and identity lookup modules
- story/media viewer flows
- search flows

Low reuse value unless your backend is still Matrix:

- Matrix session runtime internals
- encryption/account lifecycle details
- event model-specific chat rendering

## 16. Recommended Secondary Development Strategy

### Option A: Keep Matrix, Build a Branded Variant

Suitable when:

- your future app is still a Matrix client
- you mainly want product customization

Recommended approach:

- keep current architecture
- replace branding, themes, assets, onboarding, settings, platform config
- selectively simplify modules you do not need

### Option B: Keep UI Shell, Replace Backend Gradually

Suitable when:

- you want similar UX but not a fully Matrix-centered product

Recommended approach:

- reuse layout, page shells, settings structure, media/sharing interaction patterns
- progressively abstract and replace repository/interactor implementations

This is feasible, but much more expensive.

### Option C: Use This Repo as Product Prototype Reference Only

Suitable when:

- you only want to learn from the module breakdown and interaction design
- your backend and business model differ significantly

Recommended approach:

- copy architectural ideas, not implementation details

## 17. Suggested Reading Order

If you want to understand the project quickly, read files in this order:

1. `README.md`
2. `lib/main.dart`
3. `lib/widgets/twake_app.dart`
4. `lib/widgets/matrix.dart`
5. `lib/config/go_routes/go_router.dart`
6. `lib/di/global/get_it_initializer.dart`
7. `lib/utils/client_manager.dart`
8. `lib/pages/chat_list/chat_list.dart`
9. `lib/pages/chat/chat.dart`
10. `lib/pages/chat/events/message/message.dart`
11. `lib/pages/chat_details/chat_details.dart`
12. `lib/pages/login/login.dart`
13. `lib/pages/contacts_tab/contacts_tab.dart`
14. `lib/pages/share/share.dart`
15. `lib/utils/background_push.dart`

## 18. Final Recommendation

If your target is "build a similar app fast", the most pragmatic path is:

- keep the Matrix-based architecture
- keep the route shell and main page organization
- keep upload/download/push/sharing infrastructure
- simplify feature scope before trying to refactor architecture

If your target is "build a product that only looks similar", then this repository is still useful, but mainly as an architecture and product-reference repository, not as a directly modifiable base.

In short:

- for a Matrix derivative product: this repo is a strong foundation
- for a non-Matrix app: this repo is a strong reference, but only partially reusable
