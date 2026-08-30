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

  /// No description provided for @signIn.
  ///
  /// In ja, this message translates to:
  /// **'サインイン'**
  String get signIn;

  /// No description provided for @signInSubtitle.
  ///
  /// In ja, this message translates to:
  /// **'検品を始めるにはサインイン'**
  String get signInSubtitle;

  /// No description provided for @email.
  ///
  /// In ja, this message translates to:
  /// **'メールアドレス'**
  String get email;

  /// No description provided for @password.
  ///
  /// In ja, this message translates to:
  /// **'パスワード'**
  String get password;

  /// No description provided for @emailRequired.
  ///
  /// In ja, this message translates to:
  /// **'メールアドレスを入力してください'**
  String get emailRequired;

  /// No description provided for @passwordRequired.
  ///
  /// In ja, this message translates to:
  /// **'パスワードを入力してください'**
  String get passwordRequired;

  /// No description provided for @show.
  ///
  /// In ja, this message translates to:
  /// **'表示'**
  String get show;

  /// No description provided for @hide.
  ///
  /// In ja, this message translates to:
  /// **'非表示'**
  String get hide;

  /// No description provided for @searching.
  ///
  /// In ja, this message translates to:
  /// **'検索中…'**
  String get searching;

  /// No description provided for @scanTypeHint.
  ///
  /// In ja, this message translates to:
  /// **'バーコード・SKU・名称をスキャンまたは入力'**
  String get scanTypeHint;

  /// No description provided for @scanTypeMessage.
  ///
  /// In ja, this message translates to:
  /// **'バーコード・SKU・名称をスキャンまたは入力してください。'**
  String get scanTypeMessage;

  /// No description provided for @noMatchesFor.
  ///
  /// In ja, this message translates to:
  /// **'「{query}」に一致する結果がありません。'**
  String noMatchesFor(String query);

  /// No description provided for @tryDifferentScan.
  ///
  /// In ja, this message translates to:
  /// **'別のバーコード・SKU・名称をお試しください。'**
  String get tryDifferentScan;

  /// No description provided for @inStock.
  ///
  /// In ja, this message translates to:
  /// **'在庫'**
  String get inStock;

  /// No description provided for @productLookupEmpty.
  ///
  /// In ja, this message translates to:
  /// **'商品がまだありません。'**
  String get productLookupEmpty;

  /// No description provided for @findProductToAdjust.
  ///
  /// In ja, this message translates to:
  /// **'調整する商品を検索。'**
  String get findProductToAdjust;

  /// No description provided for @findProductToTrace.
  ///
  /// In ja, this message translates to:
  /// **'追跡する商品を検索。'**
  String get findProductToTrace;

  /// No description provided for @loading.
  ///
  /// In ja, this message translates to:
  /// **'読み込み中…'**
  String get loading;

  /// No description provided for @emptyLocations.
  ///
  /// In ja, this message translates to:
  /// **'ロケーションがまだありません。'**
  String get emptyLocations;

  /// No description provided for @emptyWarehouses.
  ///
  /// In ja, this message translates to:
  /// **'倉庫がまだありません。'**
  String get emptyWarehouses;

  /// No description provided for @emptySuppliers.
  ///
  /// In ja, this message translates to:
  /// **'仕入先がまだありません。'**
  String get emptySuppliers;

  /// No description provided for @emptySalesOrders.
  ///
  /// In ja, this message translates to:
  /// **'受注がまだありません。'**
  String get emptySalesOrders;

  /// No description provided for @emptyPurchaseOrders.
  ///
  /// In ja, this message translates to:
  /// **'発注がまだありません。'**
  String get emptyPurchaseOrders;

  /// No description provided for @emptyWorkOrders.
  ///
  /// In ja, this message translates to:
  /// **'作業指示がまだありません。'**
  String get emptyWorkOrders;

  /// No description provided for @tryDifferentNameCode.
  ///
  /// In ja, this message translates to:
  /// **'別の名称またはコードをお試しください。'**
  String get tryDifferentNameCode;

  /// No description provided for @tryDifferentOrder.
  ///
  /// In ja, this message translates to:
  /// **'別の受注番号または顧客をお試しください。'**
  String get tryDifferentOrder;

  /// No description provided for @tryDifferentPo.
  ///
  /// In ja, this message translates to:
  /// **'別の発注番号または仕入先をお試しください。'**
  String get tryDifferentPo;

  /// No description provided for @tryDifferentWo.
  ///
  /// In ja, this message translates to:
  /// **'別の作業指示番号・商品・SKUをお試しください。'**
  String get tryDifferentWo;

  /// No description provided for @hintLocations.
  ///
  /// In ja, this message translates to:
  /// **'名称・コードをスキャンまたは検索'**
  String get hintLocations;

  /// No description provided for @hintWarehouses.
  ///
  /// In ja, this message translates to:
  /// **'名称・コード・都市をスキャンまたは検索'**
  String get hintWarehouses;

  /// No description provided for @hintSuppliers.
  ///
  /// In ja, this message translates to:
  /// **'名称・コード・担当者・メールをスキャンまたは検索'**
  String get hintSuppliers;

  /// No description provided for @hintSalesOrders.
  ///
  /// In ja, this message translates to:
  /// **'受注番号・顧客・メールをスキャンまたは検索'**
  String get hintSalesOrders;

  /// No description provided for @hintPurchaseOrders.
  ///
  /// In ja, this message translates to:
  /// **'発注番号・仕入先をスキャンまたは検索'**
  String get hintPurchaseOrders;

  /// No description provided for @hintWorkOrders.
  ///
  /// In ja, this message translates to:
  /// **'作業指示番号・商品・SKUをスキャンまたは検索'**
  String get hintWorkOrders;

  /// No description provided for @warehouseDefault.
  ///
  /// In ja, this message translates to:
  /// **'既定'**
  String get warehouseDefault;

  /// No description provided for @noCustomer.
  ///
  /// In ja, this message translates to:
  /// **'顧客なし'**
  String get noCustomer;

  /// No description provided for @noSupplier.
  ///
  /// In ja, this message translates to:
  /// **'仕入先なし'**
  String get noSupplier;

  /// No description provided for @noProduct.
  ///
  /// In ja, this message translates to:
  /// **'商品なし'**
  String get noProduct;

  /// No description provided for @qtyLabel.
  ///
  /// In ja, this message translates to:
  /// **'数量 {quantity}'**
  String qtyLabel(int quantity);

  /// No description provided for @lineCount.
  ///
  /// In ja, this message translates to:
  /// **'{count, plural, other{{count}件の明細}}'**
  String lineCount(int count);

  /// No description provided for @statusActive.
  ///
  /// In ja, this message translates to:
  /// **'有効'**
  String get statusActive;

  /// No description provided for @statusInactive.
  ///
  /// In ja, this message translates to:
  /// **'無効'**
  String get statusInactive;

  /// No description provided for @statusCancelled.
  ///
  /// In ja, this message translates to:
  /// **'キャンセル'**
  String get statusCancelled;

  /// No description provided for @statusDraft.
  ///
  /// In ja, this message translates to:
  /// **'下書き'**
  String get statusDraft;

  /// No description provided for @statusCompleted.
  ///
  /// In ja, this message translates to:
  /// **'完了'**
  String get statusCompleted;

  /// No description provided for @statusInProgress.
  ///
  /// In ja, this message translates to:
  /// **'進行中'**
  String get statusInProgress;

  /// No description provided for @statusPending.
  ///
  /// In ja, this message translates to:
  /// **'保留'**
  String get statusPending;

  /// No description provided for @salesProcessing.
  ///
  /// In ja, this message translates to:
  /// **'処理中'**
  String get salesProcessing;

  /// No description provided for @salesShipped.
  ///
  /// In ja, this message translates to:
  /// **'出荷済み'**
  String get salesShipped;

  /// No description provided for @salesDelivered.
  ///
  /// In ja, this message translates to:
  /// **'配達済み'**
  String get salesDelivered;

  /// No description provided for @poSent.
  ///
  /// In ja, this message translates to:
  /// **'送信済み'**
  String get poSent;

  /// No description provided for @poPartiallyReceived.
  ///
  /// In ja, this message translates to:
  /// **'一部入荷'**
  String get poPartiallyReceived;

  /// No description provided for @poReceived.
  ///
  /// In ja, this message translates to:
  /// **'入荷済み'**
  String get poReceived;

  /// No description provided for @stockIn.
  ///
  /// In ja, this message translates to:
  /// **'在庫あり'**
  String get stockIn;

  /// No description provided for @stockLow.
  ///
  /// In ja, this message translates to:
  /// **'在庫僅少'**
  String get stockLow;

  /// No description provided for @stockOut.
  ///
  /// In ja, this message translates to:
  /// **'在庫切れ'**
  String get stockOut;

  /// No description provided for @inspectionPassed.
  ///
  /// In ja, this message translates to:
  /// **'合格'**
  String get inspectionPassed;

  /// No description provided for @inspectionFailed.
  ///
  /// In ja, this message translates to:
  /// **'不合格'**
  String get inspectionFailed;

  /// No description provided for @matchOk.
  ///
  /// In ja, this message translates to:
  /// **'OK'**
  String get matchOk;

  /// No description provided for @matchNg.
  ///
  /// In ja, this message translates to:
  /// **'NG'**
  String get matchNg;

  /// No description provided for @typeReceiving.
  ///
  /// In ja, this message translates to:
  /// **'入荷'**
  String get typeReceiving;

  /// No description provided for @typeShipping.
  ///
  /// In ja, this message translates to:
  /// **'出荷'**
  String get typeShipping;

  /// No description provided for @typeOther.
  ///
  /// In ja, this message translates to:
  /// **'その他'**
  String get typeOther;

  /// No description provided for @titleProduct.
  ///
  /// In ja, this message translates to:
  /// **'商品'**
  String get titleProduct;

  /// No description provided for @fieldDescription.
  ///
  /// In ja, this message translates to:
  /// **'説明'**
  String get fieldDescription;

  /// No description provided for @fieldPhone.
  ///
  /// In ja, this message translates to:
  /// **'電話'**
  String get fieldPhone;

  /// No description provided for @fieldAddress.
  ///
  /// In ja, this message translates to:
  /// **'住所'**
  String get fieldAddress;

  /// No description provided for @fieldStatus.
  ///
  /// In ja, this message translates to:
  /// **'ステータス'**
  String get fieldStatus;

  /// No description provided for @fieldCurrency.
  ///
  /// In ja, this message translates to:
  /// **'通貨'**
  String get fieldCurrency;

  /// No description provided for @fieldCategory.
  ///
  /// In ja, this message translates to:
  /// **'カテゴリ'**
  String get fieldCategory;

  /// No description provided for @fieldBarcode.
  ///
  /// In ja, this message translates to:
  /// **'バーコード'**
  String get fieldBarcode;

  /// No description provided for @fieldSku.
  ///
  /// In ja, this message translates to:
  /// **'SKU'**
  String get fieldSku;

  /// No description provided for @fieldPrice.
  ///
  /// In ja, this message translates to:
  /// **'価格'**
  String get fieldPrice;

  /// No description provided for @fieldSellingPrice.
  ///
  /// In ja, this message translates to:
  /// **'販売価格'**
  String get fieldSellingPrice;

  /// No description provided for @fieldMinStock.
  ///
  /// In ja, this message translates to:
  /// **'最小在庫'**
  String get fieldMinStock;

  /// No description provided for @fieldOnHand.
  ///
  /// In ja, this message translates to:
  /// **'在庫数'**
  String get fieldOnHand;

  /// No description provided for @fieldLocation.
  ///
  /// In ja, this message translates to:
  /// **'ロケーション'**
  String get fieldLocation;

  /// No description provided for @fieldHasVariants.
  ///
  /// In ja, this message translates to:
  /// **'バリエーションあり'**
  String get fieldHasVariants;

  /// No description provided for @fieldManager.
  ///
  /// In ja, this message translates to:
  /// **'管理者'**
  String get fieldManager;

  /// No description provided for @fieldTimezone.
  ///
  /// In ja, this message translates to:
  /// **'タイムゾーン'**
  String get fieldTimezone;

  /// No description provided for @fieldPriority.
  ///
  /// In ja, this message translates to:
  /// **'優先度'**
  String get fieldPriority;

  /// No description provided for @fieldUsers.
  ///
  /// In ja, this message translates to:
  /// **'ユーザー'**
  String get fieldUsers;

  /// No description provided for @fieldLocations.
  ///
  /// In ja, this message translates to:
  /// **'ロケーション'**
  String get fieldLocations;

  /// No description provided for @fieldContact.
  ///
  /// In ja, this message translates to:
  /// **'担当者'**
  String get fieldContact;

  /// No description provided for @fieldWebsite.
  ///
  /// In ja, this message translates to:
  /// **'ウェブサイト'**
  String get fieldWebsite;

  /// No description provided for @fieldPaymentTerms.
  ///
  /// In ja, this message translates to:
  /// **'支払条件'**
  String get fieldPaymentTerms;

  /// No description provided for @fieldNotes.
  ///
  /// In ja, this message translates to:
  /// **'備考'**
  String get fieldNotes;

  /// No description provided for @fieldProducts.
  ///
  /// In ja, this message translates to:
  /// **'商品'**
  String get fieldProducts;

  /// No description provided for @fieldAisle.
  ///
  /// In ja, this message translates to:
  /// **'通路'**
  String get fieldAisle;

  /// No description provided for @fieldShelf.
  ///
  /// In ja, this message translates to:
  /// **'棚'**
  String get fieldShelf;

  /// No description provided for @fieldBin.
  ///
  /// In ja, this message translates to:
  /// **'ビン'**
  String get fieldBin;

  /// No description provided for @fieldCode.
  ///
  /// In ja, this message translates to:
  /// **'コード'**
  String get fieldCode;

  /// No description provided for @fieldFullLocation.
  ///
  /// In ja, this message translates to:
  /// **'フルロケーション'**
  String get fieldFullLocation;

  /// No description provided for @itemCount.
  ///
  /// In ja, this message translates to:
  /// **'{count, plural, other{{count}点}}'**
  String itemCount(int count);

  /// No description provided for @productCount.
  ///
  /// In ja, this message translates to:
  /// **'{count, plural, other{{count}品目}}'**
  String productCount(int count);

  /// No description provided for @binCount.
  ///
  /// In ja, this message translates to:
  /// **'{count, plural, other{{count}ロケーション}}'**
  String binCount(int count);

  /// No description provided for @fieldCustomer.
  ///
  /// In ja, this message translates to:
  /// **'顧客'**
  String get fieldCustomer;

  /// No description provided for @lineItems.
  ///
  /// In ja, this message translates to:
  /// **'明細'**
  String get lineItems;

  /// No description provided for @noLineItems.
  ///
  /// In ja, this message translates to:
  /// **'明細がありません。'**
  String get noLineItems;

  /// No description provided for @fieldOrderDate.
  ///
  /// In ja, this message translates to:
  /// **'注文日'**
  String get fieldOrderDate;

  /// No description provided for @fieldSubtotal.
  ///
  /// In ja, this message translates to:
  /// **'小計'**
  String get fieldSubtotal;

  /// No description provided for @fieldTax.
  ///
  /// In ja, this message translates to:
  /// **'税'**
  String get fieldTax;

  /// No description provided for @fieldShipping.
  ///
  /// In ja, this message translates to:
  /// **'送料'**
  String get fieldShipping;

  /// No description provided for @fieldTotal.
  ///
  /// In ja, this message translates to:
  /// **'合計'**
  String get fieldTotal;

  /// No description provided for @fieldSupplier.
  ///
  /// In ja, this message translates to:
  /// **'仕入先'**
  String get fieldSupplier;

  /// No description provided for @fieldExpected.
  ///
  /// In ja, this message translates to:
  /// **'予定'**
  String get fieldExpected;

  /// No description provided for @fieldOrdered.
  ///
  /// In ja, this message translates to:
  /// **'発注'**
  String get fieldOrdered;

  /// No description provided for @fieldReceived.
  ///
  /// In ja, this message translates to:
  /// **'入荷'**
  String get fieldReceived;

  /// No description provided for @fieldRemaining.
  ///
  /// In ja, this message translates to:
  /// **'残'**
  String get fieldRemaining;

  /// No description provided for @actionComplete.
  ///
  /// In ja, this message translates to:
  /// **'完了'**
  String get actionComplete;

  /// No description provided for @fieldAssemblyProduct.
  ///
  /// In ja, this message translates to:
  /// **'組立製品'**
  String get fieldAssemblyProduct;

  /// No description provided for @fieldComponents.
  ///
  /// In ja, this message translates to:
  /// **'部品'**
  String get fieldComponents;

  /// No description provided for @noComponents.
  ///
  /// In ja, this message translates to:
  /// **'部品がありません。'**
  String get noComponents;

  /// No description provided for @fieldConsumed.
  ///
  /// In ja, this message translates to:
  /// **'消費'**
  String get fieldConsumed;

  /// No description provided for @fieldProduced.
  ///
  /// In ja, this message translates to:
  /// **'生産'**
  String get fieldProduced;

  /// No description provided for @fieldRequired.
  ///
  /// In ja, this message translates to:
  /// **'必要'**
  String get fieldRequired;

  /// No description provided for @fieldTarget.
  ///
  /// In ja, this message translates to:
  /// **'目標'**
  String get fieldTarget;

  /// No description provided for @fieldStarted.
  ///
  /// In ja, this message translates to:
  /// **'開始'**
  String get fieldStarted;

  /// No description provided for @productNumber.
  ///
  /// In ja, this message translates to:
  /// **'商品 #{id}'**
  String productNumber(int id);

  /// No description provided for @fieldCountedLines.
  ///
  /// In ja, this message translates to:
  /// **'カウント済み明細'**
  String get fieldCountedLines;

  /// No description provided for @noCountedLines.
  ///
  /// In ja, this message translates to:
  /// **'カウント済み明細がありません。'**
  String get noCountedLines;

  /// No description provided for @fieldCounted.
  ///
  /// In ja, this message translates to:
  /// **'カウント'**
  String get fieldCounted;

  /// No description provided for @fieldUncounted.
  ///
  /// In ja, this message translates to:
  /// **'未カウント'**
  String get fieldUncounted;

  /// No description provided for @fieldDiscrepancy.
  ///
  /// In ja, this message translates to:
  /// **'差異'**
  String get fieldDiscrepancy;

  /// No description provided for @fieldMatch.
  ///
  /// In ja, this message translates to:
  /// **'一致'**
  String get fieldMatch;

  /// No description provided for @fieldSystem.
  ///
  /// In ja, this message translates to:
  /// **'システム'**
  String get fieldSystem;

  /// No description provided for @fieldName.
  ///
  /// In ja, this message translates to:
  /// **'名称'**
  String get fieldName;

  /// No description provided for @fieldType.
  ///
  /// In ja, this message translates to:
  /// **'種別'**
  String get fieldType;

  /// No description provided for @filterAll.
  ///
  /// In ja, this message translates to:
  /// **'すべて'**
  String get filterAll;

  /// No description provided for @remainingLeft.
  ///
  /// In ja, this message translates to:
  /// **'残り {count}'**
  String remainingLeft(int count);

  /// No description provided for @remainingAmount.
  ///
  /// In ja, this message translates to:
  /// **'残り {amount}'**
  String remainingAmount(String amount);

  /// No description provided for @unknownSupplier.
  ///
  /// In ja, this message translates to:
  /// **'仕入先不明'**
  String get unknownSupplier;

  /// No description provided for @receivingEmpty.
  ///
  /// In ja, this message translates to:
  /// **'入荷対象がありません。'**
  String get receivingEmpty;

  /// No description provided for @receivingEmptyBody.
  ///
  /// In ja, this message translates to:
  /// **'送信済みまたは一部入荷の発注がここに表示されます。'**
  String get receivingEmptyBody;

  /// No description provided for @receivingDone.
  ///
  /// In ja, this message translates to:
  /// **'残りの入荷はありません。'**
  String get receivingDone;

  /// No description provided for @fieldQtyToReceive.
  ///
  /// In ja, this message translates to:
  /// **'入荷数量'**
  String get fieldQtyToReceive;

  /// No description provided for @receiveStock.
  ///
  /// In ja, this message translates to:
  /// **'入荷登録'**
  String get receiveStock;

  /// No description provided for @actionReceive.
  ///
  /// In ja, this message translates to:
  /// **'入荷'**
  String get actionReceive;

  /// No description provided for @receivingInProgress.
  ///
  /// In ja, this message translates to:
  /// **'入荷処理中…'**
  String get receivingInProgress;

  /// No description provided for @emptyInspections.
  ///
  /// In ja, this message translates to:
  /// **'検品がまだありません。'**
  String get emptyInspections;

  /// No description provided for @inspectionsEmptyBody.
  ///
  /// In ja, this message translates to:
  /// **'下に引いて更新するか、入荷受入から開始してください。'**
  String get inspectionsEmptyBody;

  /// No description provided for @pickingEmpty.
  ///
  /// In ja, this message translates to:
  /// **'ピッキング対象がありません。'**
  String get pickingEmpty;

  /// No description provided for @noLinesToPick.
  ///
  /// In ja, this message translates to:
  /// **'ピッキングする明細がありません。'**
  String get noLinesToPick;

  /// No description provided for @orderNoLineItems.
  ///
  /// In ja, this message translates to:
  /// **'この受注に明細はありません。'**
  String get orderNoLineItems;

  /// No description provided for @unnamedProduct.
  ///
  /// In ja, this message translates to:
  /// **'名称未設定の商品'**
  String get unnamedProduct;

  /// No description provided for @pickListTitle.
  ///
  /// In ja, this message translates to:
  /// **'ピッキングリスト'**
  String get pickListTitle;

  /// No description provided for @customReport.
  ///
  /// In ja, this message translates to:
  /// **'カスタムレポート'**
  String get customReport;

  /// No description provided for @emptyReports.
  ///
  /// In ja, this message translates to:
  /// **'保存済みレポートがまだありません。'**
  String get emptyReports;

  /// No description provided for @reportsEmptyBody.
  ///
  /// In ja, this message translates to:
  /// **'バックオフィスで保存したレポートがここに表示されます。'**
  String get reportsEmptyBody;

  /// No description provided for @reportShared.
  ///
  /// In ja, this message translates to:
  /// **'共有'**
  String get reportShared;

  /// No description provided for @columnCount.
  ///
  /// In ja, this message translates to:
  /// **'{count, plural, other{{count}列}}'**
  String columnCount(int count);

  /// No description provided for @allLocations.
  ///
  /// In ja, this message translates to:
  /// **'全ロケーション'**
  String get allLocations;

  /// No description provided for @emptyStockCounts.
  ///
  /// In ja, this message translates to:
  /// **'棚卸がまだありません。'**
  String get emptyStockCounts;

  /// No description provided for @pickingEmptyBody.
  ///
  /// In ja, this message translates to:
  /// **'出荷待ちの受注がここに表示されます。'**
  String get pickingEmptyBody;

  /// No description provided for @stockCountsEmptyBody.
  ///
  /// In ja, this message translates to:
  /// **'バックオフィスで作成した循環棚卸がここに表示されます。'**
  String get stockCountsEmptyBody;

  /// No description provided for @receivingDoneBody.
  ///
  /// In ja, this message translates to:
  /// **'この発注のすべての明細が入荷済みです。'**
  String get receivingDoneBody;

  /// No description provided for @receiveInvalidQty.
  ///
  /// In ja, this message translates to:
  /// **'「{product}」の数量を正しく入力してください。'**
  String receiveInvalidQty(String product);

  /// No description provided for @receiveExceedsRemaining.
  ///
  /// In ja, this message translates to:
  /// **'{product}：残り {remaining} を超えて入荷できません。'**
  String receiveExceedsRemaining(String product, int remaining);

  /// No description provided for @receiveEnterAtLeastOne.
  ///
  /// In ja, this message translates to:
  /// **'入荷する数量を1行以上入力してください。'**
  String get receiveEnterAtLeastOne;

  /// No description provided for @receiveSuccess.
  ///
  /// In ja, this message translates to:
  /// **'入荷しました。検品が自動的に開始されました。'**
  String get receiveSuccess;

  /// No description provided for @pickedProgress.
  ///
  /// In ja, this message translates to:
  /// **'{picked} / {total} ピック済み'**
  String pickedProgress(int picked, int total);

  /// No description provided for @attachFiles.
  ///
  /// In ja, this message translates to:
  /// **'添付'**
  String get attachFiles;

  /// No description provided for @cameraLabel.
  ///
  /// In ja, this message translates to:
  /// **'カメラ'**
  String get cameraLabel;

  /// No description provided for @scanToRecord.
  ///
  /// In ja, this message translates to:
  /// **'スキャンして記録'**
  String get scanToRecord;

  /// No description provided for @scanToRecordQty1.
  ///
  /// In ja, this message translates to:
  /// **'スキャンして記録（数量1）'**
  String get scanToRecordQty1;

  /// No description provided for @fastModeOnTooltip.
  ///
  /// In ja, this message translates to:
  /// **'高速モード：スキャンごとに数量1で記録'**
  String get fastModeOnTooltip;

  /// No description provided for @fastModeOffTooltip.
  ///
  /// In ja, this message translates to:
  /// **'スキャンごとに数量を入力'**
  String get fastModeOffTooltip;

  /// No description provided for @fastQtyOneLabel.
  ///
  /// In ja, this message translates to:
  /// **'数量1'**
  String get fastQtyOneLabel;

  /// No description provided for @actualQuantity.
  ///
  /// In ja, this message translates to:
  /// **'実数量'**
  String get actualQuantity;

  /// No description provided for @scannedCode.
  ///
  /// In ja, this message translates to:
  /// **'読取: {code}'**
  String scannedCode(String code);

  /// No description provided for @quantity.
  ///
  /// In ja, this message translates to:
  /// **'数量'**
  String get quantity;

  /// No description provided for @actionCancel.
  ///
  /// In ja, this message translates to:
  /// **'キャンセル'**
  String get actionCancel;

  /// No description provided for @actionRecord.
  ///
  /// In ja, this message translates to:
  /// **'記録'**
  String get actionRecord;

  /// No description provided for @itemRecorded.
  ///
  /// In ja, this message translates to:
  /// **'項目を記録しました'**
  String get itemRecorded;

  /// No description provided for @offlineItemQueued.
  ///
  /// In ja, this message translates to:
  /// **'オフライン — 項目を同期待ちに追加しました'**
  String get offlineItemQueued;

  /// No description provided for @filesUploaded.
  ///
  /// In ja, this message translates to:
  /// **'{count, plural, other{{count}件のファイルをアップロードしました}}'**
  String filesUploaded(int count);

  /// No description provided for @offlineFilesQueued.
  ///
  /// In ja, this message translates to:
  /// **'オフライン — {count}件のファイルを同期待ちに追加しました'**
  String offlineFilesQueued(int count);

  /// No description provided for @completeInspectionQ.
  ///
  /// In ja, this message translates to:
  /// **'検品を完了しますか？'**
  String get completeInspectionQ;

  /// No description provided for @completeInspectionBody.
  ///
  /// In ja, this message translates to:
  /// **'この検品を完了にします。完了後も閲覧できます。'**
  String get completeInspectionBody;

  /// No description provided for @inspectionCompleted.
  ///
  /// In ja, this message translates to:
  /// **'検品を完了しました'**
  String get inspectionCompleted;

  /// No description provided for @offlineCompletionQueued.
  ///
  /// In ja, this message translates to:
  /// **'オフライン — 完了を同期待ちに追加しました'**
  String get offlineCompletionQueued;

  /// No description provided for @sectionItems.
  ///
  /// In ja, this message translates to:
  /// **'項目'**
  String get sectionItems;

  /// No description provided for @sectionAttachments.
  ///
  /// In ja, this message translates to:
  /// **'添付ファイル'**
  String get sectionAttachments;

  /// No description provided for @noItemsYet.
  ///
  /// In ja, this message translates to:
  /// **'項目がまだありません。スキャンで記録してください。'**
  String get noItemsYet;

  /// No description provided for @noAttachments.
  ///
  /// In ja, this message translates to:
  /// **'添付はありません。クリップから写真やファイルを追加できます。'**
  String get noAttachments;

  /// No description provided for @completeInspection.
  ///
  /// In ja, this message translates to:
  /// **'検品を完了'**
  String get completeInspection;

  /// No description provided for @completedOn.
  ///
  /// In ja, this message translates to:
  /// **'完了 {date}'**
  String completedOn(String date);

  /// No description provided for @actualLabel.
  ///
  /// In ja, this message translates to:
  /// **'実績'**
  String get actualLabel;

  /// No description provided for @itemNumber.
  ///
  /// In ja, this message translates to:
  /// **'項目 {id}'**
  String itemNumber(int id);

  /// No description provided for @working.
  ///
  /// In ja, this message translates to:
  /// **'処理中…'**
  String get working;

  /// No description provided for @adjustAdd.
  ///
  /// In ja, this message translates to:
  /// **'追加'**
  String get adjustAdd;

  /// No description provided for @adjustRemove.
  ///
  /// In ja, this message translates to:
  /// **'減少'**
  String get adjustRemove;

  /// No description provided for @reasonType.
  ///
  /// In ja, this message translates to:
  /// **'理由区分'**
  String get reasonType;

  /// No description provided for @reasonOptional.
  ///
  /// In ja, this message translates to:
  /// **'理由（任意）'**
  String get reasonOptional;

  /// No description provided for @notesOptional.
  ///
  /// In ja, this message translates to:
  /// **'メモ（任意）'**
  String get notesOptional;

  /// No description provided for @onHandAfter.
  ///
  /// In ja, this message translates to:
  /// **'調整後の在庫'**
  String get onHandAfter;

  /// No description provided for @saving.
  ///
  /// In ja, this message translates to:
  /// **'保存中…'**
  String get saving;

  /// No description provided for @addStock.
  ///
  /// In ja, this message translates to:
  /// **'在庫を追加'**
  String get addStock;

  /// No description provided for @removeStock.
  ///
  /// In ja, this message translates to:
  /// **'在庫を減らす'**
  String get removeStock;

  /// No description provided for @onHandCount.
  ///
  /// In ja, this message translates to:
  /// **'在庫 {count}'**
  String onHandCount(int count);

  /// No description provided for @enterQtyPositive.
  ///
  /// In ja, this message translates to:
  /// **'0より大きい数量を入力してください。'**
  String get enterQtyPositive;

  /// No description provided for @cannotRemoveOnly.
  ///
  /// In ja, this message translates to:
  /// **'{qty} を減らせません。在庫は {current} のみです。'**
  String cannotRemoveOnly(int qty, int current);

  /// No description provided for @stockUpdatedTo.
  ///
  /// In ja, this message translates to:
  /// **'在庫を更新しました — 現在 {count}。'**
  String stockUpdatedTo(int count);

  /// No description provided for @adjustTypeManual.
  ///
  /// In ja, this message translates to:
  /// **'手動'**
  String get adjustTypeManual;

  /// No description provided for @adjustTypeCount.
  ///
  /// In ja, this message translates to:
  /// **'棚卸'**
  String get adjustTypeCount;

  /// No description provided for @adjustTypeDamage.
  ///
  /// In ja, this message translates to:
  /// **'破損'**
  String get adjustTypeDamage;

  /// No description provided for @adjustTypeReturn.
  ///
  /// In ja, this message translates to:
  /// **'返品'**
  String get adjustTypeReturn;

  /// No description provided for @adjustTypeTransfer.
  ///
  /// In ja, this message translates to:
  /// **'移動'**
  String get adjustTypeTransfer;

  /// No description provided for @sectionBatches.
  ///
  /// In ja, this message translates to:
  /// **'バッチ'**
  String get sectionBatches;

  /// No description provided for @sectionSerials.
  ///
  /// In ja, this message translates to:
  /// **'シリアル'**
  String get sectionSerials;

  /// No description provided for @noBatches.
  ///
  /// In ja, this message translates to:
  /// **'この商品のバッチはありません。'**
  String get noBatches;

  /// No description provided for @noSerials.
  ///
  /// In ja, this message translates to:
  /// **'この商品のシリアルはありません。'**
  String get noSerials;

  /// No description provided for @loadingBatches.
  ///
  /// In ja, this message translates to:
  /// **'バッチを読み込み中…'**
  String get loadingBatches;

  /// No description provided for @loadingSerials.
  ///
  /// In ja, this message translates to:
  /// **'シリアルを読み込み中…'**
  String get loadingSerials;

  /// No description provided for @batchExpired.
  ///
  /// In ja, this message translates to:
  /// **'期限切れ'**
  String get batchExpired;

  /// No description provided for @batchValid.
  ///
  /// In ja, this message translates to:
  /// **'有効'**
  String get batchValid;

  /// No description provided for @fieldExpiry.
  ///
  /// In ja, this message translates to:
  /// **'有効期限'**
  String get fieldExpiry;

  /// No description provided for @report.
  ///
  /// In ja, this message translates to:
  /// **'レポート'**
  String get report;

  /// No description provided for @runningReport.
  ///
  /// In ja, this message translates to:
  /// **'レポートを実行中…'**
  String get runningReport;

  /// No description provided for @noData.
  ///
  /// In ja, this message translates to:
  /// **'データがありません。'**
  String get noData;

  /// No description provided for @reportNoRows.
  ///
  /// In ja, this message translates to:
  /// **'このレポートに行がありません。'**
  String get reportNoRows;

  /// No description provided for @rowCount.
  ///
  /// In ja, this message translates to:
  /// **'{count, plural, other{{count} 行}}'**
  String rowCount(int count);

  /// No description provided for @scanBarcode.
  ///
  /// In ja, this message translates to:
  /// **'バーコードをスキャン'**
  String get scanBarcode;

  /// No description provided for @torchOn.
  ///
  /// In ja, this message translates to:
  /// **'ライトを点灯'**
  String get torchOn;

  /// No description provided for @torchOff.
  ///
  /// In ja, this message translates to:
  /// **'ライトを消灯'**
  String get torchOff;

  /// No description provided for @alignBarcode.
  ///
  /// In ja, this message translates to:
  /// **'枠内にバーコードを合わせてください'**
  String get alignBarcode;

  /// No description provided for @scanOrTypeBarcode.
  ///
  /// In ja, this message translates to:
  /// **'スキャンまたはバーコードを入力'**
  String get scanOrTypeBarcode;
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
