import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_ja.dart';
import 'app_localizations_zh.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
      : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
    delegate,
    GlobalMaterialLocalizations.delegate,
    GlobalCupertinoLocalizations.delegate,
    GlobalWidgetsLocalizations.delegate,
  ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('en'),
    Locale('ja'),
    Locale('zh')
  ];

  /// No description provided for @appTitle.
  ///
  /// In ja, this message translates to:
  /// **'WMS'**
  String get appTitle;

  /// No description provided for @search.
  ///
  /// In ja, this message translates to:
  /// **'検索'**
  String get search;

  /// No description provided for @retry.
  ///
  /// In ja, this message translates to:
  /// **'再試行'**
  String get retry;

  /// No description provided for @signOut.
  ///
  /// In ja, this message translates to:
  /// **'サインアウト'**
  String get signOut;

  /// No description provided for @backToMenu.
  ///
  /// In ja, this message translates to:
  /// **'メニューに戻る'**
  String get backToMenu;

  /// No description provided for @somethingWentWrong.
  ///
  /// In ja, this message translates to:
  /// **'問題が発生しました'**
  String get somethingWentWrong;

  /// No description provided for @language.
  ///
  /// In ja, this message translates to:
  /// **'言語'**
  String get language;

  /// No description provided for @languageTooltip.
  ///
  /// In ja, this message translates to:
  /// **'言語を選択'**
  String get languageTooltip;

  /// No description provided for @languageJapanese.
  ///
  /// In ja, this message translates to:
  /// **'日本語'**
  String get languageJapanese;

  /// No description provided for @languageEnglish.
  ///
  /// In ja, this message translates to:
  /// **'English'**
  String get languageEnglish;

  /// No description provided for @languageChinese.
  ///
  /// In ja, this message translates to:
  /// **'中文'**
  String get languageChinese;

  /// No description provided for @navDashboard.
  ///
  /// In ja, this message translates to:
  /// **'ダッシュボード'**
  String get navDashboard;

  /// No description provided for @brandSubtitle.
  ///
  /// In ja, this message translates to:
  /// **'倉庫管理'**
  String get brandSubtitle;

  /// No description provided for @welcomeBack.
  ///
  /// In ja, this message translates to:
  /// **'おかえりなさい'**
  String get welcomeBack;

  /// No description provided for @operatorName.
  ///
  /// In ja, this message translates to:
  /// **'作業者'**
  String get operatorName;

  /// No description provided for @scannerReady.
  ///
  /// In ja, this message translates to:
  /// **'スキャン準備完了'**
  String get scannerReady;

  /// No description provided for @readyToScanTitle.
  ///
  /// In ja, this message translates to:
  /// **'スキャン準備完了'**
  String get readyToScanTitle;

  /// No description provided for @readyToScanBody.
  ///
  /// In ja, this message translates to:
  /// **'どこでもハンディでスキャン、またはタップしてバーコード・SKU・名称で検索。'**
  String get readyToScanBody;

  /// No description provided for @topbarScanHint.
  ///
  /// In ja, this message translates to:
  /// **'バーコード / SKU をスキャンまたは検索'**
  String get topbarScanHint;

  /// No description provided for @menu.
  ///
  /// In ja, this message translates to:
  /// **'メニュー'**
  String get menu;

  /// No description provided for @cameraScan.
  ///
  /// In ja, this message translates to:
  /// **'カメラでスキャン'**
  String get cameraScan;

  /// No description provided for @groupFieldOperations.
  ///
  /// In ja, this message translates to:
  /// **'現場作業'**
  String get groupFieldOperations;

  /// No description provided for @groupLookup.
  ///
  /// In ja, this message translates to:
  /// **'照会'**
  String get groupLookup;

  /// No description provided for @groupManagement.
  ///
  /// In ja, this message translates to:
  /// **'管理'**
  String get groupManagement;

  /// No description provided for @featInspection.
  ///
  /// In ja, this message translates to:
  /// **'検品'**
  String get featInspection;

  /// No description provided for @featInspectionDesc.
  ///
  /// In ja, this message translates to:
  /// **'バーコード・数量照合、NG記録'**
  String get featInspectionDesc;

  /// No description provided for @featReceiving.
  ///
  /// In ja, this message translates to:
  /// **'入荷'**
  String get featReceiving;

  /// No description provided for @featReceivingDesc.
  ///
  /// In ja, this message translates to:
  /// **'発注の入荷、検品を自動開始'**
  String get featReceivingDesc;

  /// No description provided for @featStockAdjustment.
  ///
  /// In ja, this message translates to:
  /// **'在庫調整'**
  String get featStockAdjustment;

  /// No description provided for @featStockAdjustmentDesc.
  ///
  /// In ja, this message translates to:
  /// **'理由付きでスキャンして増減'**
  String get featStockAdjustmentDesc;

  /// No description provided for @featStockCount.
  ///
  /// In ja, this message translates to:
  /// **'棚卸'**
  String get featStockCount;

  /// No description provided for @featStockCountDesc.
  ///
  /// In ja, this message translates to:
  /// **'ロケーション別の循環棚卸'**
  String get featStockCountDesc;

  /// No description provided for @featPicking.
  ///
  /// In ja, this message translates to:
  /// **'ピッキング'**
  String get featPicking;

  /// No description provided for @featPickingDesc.
  ///
  /// In ja, this message translates to:
  /// **'スキャンで受注を出荷'**
  String get featPickingDesc;

  /// No description provided for @featProductLookup.
  ///
  /// In ja, this message translates to:
  /// **'商品照会'**
  String get featProductLookup;

  /// No description provided for @featProductLookupDesc.
  ///
  /// In ja, this message translates to:
  /// **'バーコードをスキャンして商品と在庫を表示'**
  String get featProductLookupDesc;

  /// No description provided for @featLocations.
  ///
  /// In ja, this message translates to:
  /// **'ロケーション'**
  String get featLocations;

  /// No description provided for @featLocationsDesc.
  ///
  /// In ja, this message translates to:
  /// **'棚・ゾーン・移動'**
  String get featLocationsDesc;

  /// No description provided for @featLotsSerials.
  ///
  /// In ja, this message translates to:
  /// **'ロット・シリアル'**
  String get featLotsSerials;

  /// No description provided for @featLotsSerialsDesc.
  ///
  /// In ja, this message translates to:
  /// **'バッチとシリアルの追跡'**
  String get featLotsSerialsDesc;

  /// No description provided for @featPurchaseOrders.
  ///
  /// In ja, this message translates to:
  /// **'発注'**
  String get featPurchaseOrders;

  /// No description provided for @featPurchaseOrdersDesc.
  ///
  /// In ja, this message translates to:
  /// **'発注書の作成・管理'**
  String get featPurchaseOrdersDesc;

  /// No description provided for @featSalesOrders.
  ///
  /// In ja, this message translates to:
  /// **'受注'**
  String get featSalesOrders;

  /// No description provided for @featSalesOrdersDesc.
  ///
  /// In ja, this message translates to:
  /// **'受注の閲覧・編集'**
  String get featSalesOrdersDesc;

  /// No description provided for @featSuppliers.
  ///
  /// In ja, this message translates to:
  /// **'仕入先'**
  String get featSuppliers;

  /// No description provided for @featSuppliersDesc.
  ///
  /// In ja, this message translates to:
  /// **'仕入先ディレクトリ'**
  String get featSuppliersDesc;

  /// No description provided for @featWarehouses.
  ///
  /// In ja, this message translates to:
  /// **'倉庫'**
  String get featWarehouses;

  /// No description provided for @featWarehousesDesc.
  ///
  /// In ja, this message translates to:
  /// **'倉庫マスタ'**
  String get featWarehousesDesc;

  /// No description provided for @featWorkOrders.
  ///
  /// In ja, this message translates to:
  /// **'作業指示'**
  String get featWorkOrders;

  /// No description provided for @featWorkOrdersDesc.
  ///
  /// In ja, this message translates to:
  /// **'組立・キッティング'**
  String get featWorkOrdersDesc;

  /// No description provided for @featReports.
  ///
  /// In ja, this message translates to:
  /// **'帳票'**
  String get featReports;

  /// No description provided for @featReportsDesc.
  ///
  /// In ja, this message translates to:
  /// **'保存済みレポートとエクスポート'**
  String get featReportsDesc;

  /// No description provided for @comingSoon.
  ///
  /// In ja, this message translates to:
  /// **'近日対応'**
  String get comingSoon;

  /// No description provided for @comingSoonBody.
  ///
  /// In ja, this message translates to:
  /// **'このサーバーAPIは準備済みです。モバイル画面が次の予定です。'**
  String get comingSoonBody;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en', 'ja', 'zh'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
    case 'ja':
      return AppLocalizationsJa();
    case 'zh':
      return AppLocalizationsZh();
  }

  throw FlutterError(
      'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
      'an issue with the localizations generation tool. Please file an issue '
      'on GitHub with a reproducible sample app and the gen-l10n configuration '
      'that was used.');
}
