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

  /// No description provided for @errorPermissionDenied.
  ///
  /// In ja, this message translates to:
  /// **'この操作を行う権限がありません。'**
  String get errorPermissionDenied;

  /// No description provided for @errorInspectionCompleted.
  ///
  /// In ja, this message translates to:
  /// **'この検品はすでに完了しています。画面を開き直して最新の結果を確認してください。'**
  String get errorInspectionCompleted;

  /// No description provided for @errorReceiptInspected.
  ///
  /// In ja, this message translates to:
  /// **'検品が完了した入荷は取り消せません。在庫を直す場合は在庫調整を使ってください。'**
  String get errorReceiptInspected;

  /// No description provided for @errorInspectionClosedReceiveNew.
  ///
  /// In ja, this message translates to:
  /// **'この入荷の検品はすでに完了しています。追加の商品は、同じ入荷予定の新しい入荷として照合してください。'**
  String get errorInspectionClosedReceiveNew;

  /// No description provided for @languageTooltip.
  ///
  /// In ja, this message translates to:
  /// **'言語を選択'**
  String get languageTooltip;

  /// No description provided for @textSizeMenu.
  ///
  /// In ja, this message translates to:
  /// **'文字サイズ'**
  String get textSizeMenu;

  /// No description provided for @textSizeNormal.
  ///
  /// In ja, this message translates to:
  /// **'標準'**
  String get textSizeNormal;

  /// No description provided for @textSizeLarge.
  ///
  /// In ja, this message translates to:
  /// **'大'**
  String get textSizeLarge;

  /// No description provided for @textSizeXLarge.
  ///
  /// In ja, this message translates to:
  /// **'特大'**
  String get textSizeXLarge;

  /// No description provided for @textSizeXXLarge.
  ///
  /// In ja, this message translates to:
  /// **'最大'**
  String get textSizeXXLarge;

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

  /// No description provided for @loading.
  ///
  /// In ja, this message translates to:
  /// **'読み込み中…'**
  String get loading;

  /// No description provided for @lineCount.
  ///
  /// In ja, this message translates to:
  /// **'{count, plural, other{{count}件の明細}}'**
  String lineCount(int count);

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

  /// No description provided for @fieldContact.
  ///
  /// In ja, this message translates to:
  /// **'担当者'**
  String get fieldContact;

  /// No description provided for @fieldSupplier.
  ///
  /// In ja, this message translates to:
  /// **'仕入先'**
  String get fieldSupplier;

  /// No description provided for @actionComplete.
  ///
  /// In ja, this message translates to:
  /// **'完了'**
  String get actionComplete;

  /// No description provided for @actionContinue.
  ///
  /// In ja, this message translates to:
  /// **'続ける'**
  String get actionContinue;

  /// No description provided for @filterAll.
  ///
  /// In ja, this message translates to:
  /// **'すべて'**
  String get filterAll;

  /// No description provided for @unknownSupplier.
  ///
  /// In ja, this message translates to:
  /// **'仕入先不明'**
  String get unknownSupplier;

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

  /// No description provided for @unnamedProduct.
  ///
  /// In ja, this message translates to:
  /// **'名称未設定の商品'**
  String get unnamedProduct;

  /// No description provided for @pickingEmptyBody.
  ///
  /// In ja, this message translates to:
  /// **'出荷待ちの受注がここに表示されます。'**
  String get pickingEmptyBody;

  /// No description provided for @pickedProgress.
  ///
  /// In ja, this message translates to:
  /// **'{picked} / {total} ピック済み'**
  String pickedProgress(int picked, int total);

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

  /// No description provided for @featDelivery.
  ///
  /// In ja, this message translates to:
  /// **'納品照合'**
  String get featDelivery;

  /// No description provided for @featDeliveryDesc.
  ///
  /// In ja, this message translates to:
  /// **'納品書とExcel予定を照合し過不足を可視化'**
  String get featDeliveryDesc;

  /// No description provided for @deliveryStatusOpen.
  ///
  /// In ja, this message translates to:
  /// **'未照合'**
  String get deliveryStatusOpen;

  /// No description provided for @deliveryStatusReconciling.
  ///
  /// In ja, this message translates to:
  /// **'照合中'**
  String get deliveryStatusReconciling;

  /// No description provided for @deliveryStatusPartial.
  ///
  /// In ja, this message translates to:
  /// **'部分納品'**
  String get deliveryStatusPartial;

  /// No description provided for @deliveryStatusCompleted.
  ///
  /// In ja, this message translates to:
  /// **'照合済み'**
  String get deliveryStatusCompleted;

  /// No description provided for @reconPending.
  ///
  /// In ja, this message translates to:
  /// **'未確認'**
  String get reconPending;

  /// No description provided for @reconMatched.
  ///
  /// In ja, this message translates to:
  /// **'一致'**
  String get reconMatched;

  /// No description provided for @reconShortfall.
  ///
  /// In ja, this message translates to:
  /// **'不足'**
  String get reconShortfall;

  /// No description provided for @reconOver.
  ///
  /// In ja, this message translates to:
  /// **'過剰'**
  String get reconOver;

  /// No description provided for @reconUnexpected.
  ///
  /// In ja, this message translates to:
  /// **'想定外'**
  String get reconUnexpected;

  /// No description provided for @deliveryPlansTitle.
  ///
  /// In ja, this message translates to:
  /// **'納品照合'**
  String get deliveryPlansTitle;

  /// No description provided for @deliveryPlansEmpty.
  ///
  /// In ja, this message translates to:
  /// **'納品予定がありません。'**
  String get deliveryPlansEmpty;

  /// No description provided for @deliveryPlansEmptyBody.
  ///
  /// In ja, this message translates to:
  /// **'バックオフィスで取り込んだ納品予定（Excel）がここに表示されます。'**
  String get deliveryPlansEmptyBody;

  /// No description provided for @deliveryPlansHint.
  ///
  /// In ja, this message translates to:
  /// **'スキャンまたは伝票番号・仕入先で検索'**
  String get deliveryPlansHint;

  /// No description provided for @deliveryNoMatches.
  ///
  /// In ja, this message translates to:
  /// **'一致する納品予定がありません。'**
  String get deliveryNoMatches;

  /// No description provided for @deliverySearchTip.
  ///
  /// In ja, this message translates to:
  /// **'別の伝票番号または仕入先をお試しください。'**
  String get deliverySearchTip;

  /// No description provided for @plannedLines.
  ///
  /// In ja, this message translates to:
  /// **'{count, plural, other{予定明細 {count} 件}}'**
  String plannedLines(int count);

  /// No description provided for @deliveryNumberLabel.
  ///
  /// In ja, this message translates to:
  /// **'伝票番号'**
  String get deliveryNumberLabel;

  /// No description provided for @scanDeliveryHint.
  ///
  /// In ja, this message translates to:
  /// **'品物のJANをスキャン'**
  String get scanDeliveryHint;

  /// No description provided for @ocrAssist.
  ///
  /// In ja, this message translates to:
  /// **'納品書を撮影（OCR補助）'**
  String get ocrAssist;

  /// No description provided for @ocrFound.
  ///
  /// In ja, this message translates to:
  /// **'納品書から {count} 件のJANを検出しました'**
  String ocrFound(int count);

  /// No description provided for @ocrNoneFound.
  ///
  /// In ja, this message translates to:
  /// **'納品書からJANを検出できませんでした。'**
  String get ocrNoneFound;

  /// No description provided for @ocrUnavailable.
  ///
  /// In ja, this message translates to:
  /// **'この端末ではOCRを利用できません。'**
  String get ocrUnavailable;

  /// No description provided for @reconSummaryTitle.
  ///
  /// In ja, this message translates to:
  /// **'照合状況'**
  String get reconSummaryTitle;

  /// No description provided for @deliveryPlanned.
  ///
  /// In ja, this message translates to:
  /// **'予定'**
  String get deliveryPlanned;

  /// No description provided for @reconReceivedPrev.
  ///
  /// In ja, this message translates to:
  /// **'既納'**
  String get reconReceivedPrev;

  /// No description provided for @reconThisTime.
  ///
  /// In ja, this message translates to:
  /// **'今回'**
  String get reconThisTime;

  /// No description provided for @reconRemaining.
  ///
  /// In ja, this message translates to:
  /// **'残'**
  String get reconRemaining;

  /// No description provided for @completeReconcile.
  ///
  /// In ja, this message translates to:
  /// **'照合を完了'**
  String get completeReconcile;

  /// No description provided for @reconcileConfirmQ.
  ///
  /// In ja, this message translates to:
  /// **'照合を完了しますか？'**
  String get reconcileConfirmQ;

  /// No description provided for @reconcileConfirmBody.
  ///
  /// In ja, this message translates to:
  /// **'現在の計数結果を送信して照合を完了します。'**
  String get reconcileConfirmBody;

  /// No description provided for @reconcileConfirmDiscrepancy.
  ///
  /// In ja, this message translates to:
  /// **'差異があります（不足・過剰・想定外）。このまま完了しますか？'**
  String get reconcileConfirmDiscrepancy;

  /// No description provided for @reconcilePartialQ.
  ///
  /// In ja, this message translates to:
  /// **'未納の品目が残っています'**
  String get reconcilePartialQ;

  /// No description provided for @reconcilePartialBody.
  ///
  /// In ja, this message translates to:
  /// **'未納が {count} 本残っています。部分納品として保存し残りを未納リストに残しますか？　それとも完了にして残りを欠品として扱いますか？'**
  String reconcilePartialBody(int count);

  /// No description provided for @reconcileKeepOpen.
  ///
  /// In ja, this message translates to:
  /// **'部分納品として保存'**
  String get reconcileKeepOpen;

  /// No description provided for @reconcileFinalizeShort.
  ///
  /// In ja, this message translates to:
  /// **'完了にする（残りは欠品）'**
  String get reconcileFinalizeShort;

  /// No description provided for @reconcilePartialSaved.
  ///
  /// In ja, this message translates to:
  /// **'部分納品として保存しました（未納を継続保持）'**
  String get reconcilePartialSaved;

  /// No description provided for @reconNoteReference.
  ///
  /// In ja, this message translates to:
  /// **'備考'**
  String get reconNoteReference;

  /// No description provided for @reconAlreadyDoneQ.
  ///
  /// In ja, this message translates to:
  /// **'この予定は照合済みです'**
  String get reconAlreadyDoneQ;

  /// No description provided for @reconAlreadyDoneBody.
  ///
  /// In ja, this message translates to:
  /// **'追加で取り込むと在庫にもう一度加算されます。間違いを直す場合は、受領履歴から該当の受領を取り消してください。'**
  String get reconAlreadyDoneBody;

  /// No description provided for @doubleScanWarning.
  ///
  /// In ja, this message translates to:
  /// **'{code} が予定数を超えました（二重スキャン？）'**
  String doubleScanWarning(String code);

  /// No description provided for @receiptHistoryTitle.
  ///
  /// In ja, this message translates to:
  /// **'受領履歴／訂正'**
  String get receiptHistoryTitle;

  /// Receipt detail: no lines and no parcels.
  ///
  /// In ja, this message translates to:
  /// **'明細がありません'**
  String get receiptEmpty;

  /// No description provided for @receiptEmptyBody.
  ///
  /// In ja, this message translates to:
  /// **'この予定を照合するたびに、受領がここに記録され、取り消せます。'**
  String get receiptEmptyBody;

  /// No description provided for @receiptCancelAction.
  ///
  /// In ja, this message translates to:
  /// **'受領を取消'**
  String get receiptCancelAction;

  /// No description provided for @receiptCancelledBadge.
  ///
  /// In ja, this message translates to:
  /// **'取消済み'**
  String get receiptCancelledBadge;

  /// No description provided for @receiptCancelQ.
  ///
  /// In ja, this message translates to:
  /// **'この受領を取り消しますか？'**
  String get receiptCancelQ;

  /// No description provided for @receiptCancelBody.
  ///
  /// In ja, this message translates to:
  /// **'この受領で加算した数量と在庫を差し戻します。'**
  String get receiptCancelBody;

  /// No description provided for @receiptCancelledDone.
  ///
  /// In ja, this message translates to:
  /// **'受領を取り消しました'**
  String get receiptCancelledDone;

  /// No description provided for @showCompletedPlans.
  ///
  /// In ja, this message translates to:
  /// **'照合済みも表示'**
  String get showCompletedPlans;

  /// No description provided for @hideCompletedPlans.
  ///
  /// In ja, this message translates to:
  /// **'照合済みを隠す'**
  String get hideCompletedPlans;

  /// No description provided for @reconcileDone.
  ///
  /// In ja, this message translates to:
  /// **'照合を完了しました'**
  String get reconcileDone;

  /// No description provided for @reconcileEmptyCounts.
  ///
  /// In ja, this message translates to:
  /// **'まだ計数がありません。スキャンして開始してください。'**
  String get reconcileEmptyCounts;

  /// No description provided for @unexpectedItem.
  ///
  /// In ja, this message translates to:
  /// **'想定外の品目'**
  String get unexpectedItem;

  /// No description provided for @enterQuantityFor.
  ///
  /// In ja, this message translates to:
  /// **'{code} の数量'**
  String enterQuantityFor(String code);

  /// No description provided for @planImportTitle.
  ///
  /// In ja, this message translates to:
  /// **'予定を取り込む'**
  String get planImportTitle;

  /// No description provided for @planImportHint.
  ///
  /// In ja, this message translates to:
  /// **'Excel / PDF / 画像を選んでアップロードすると、自動で予定に登録します。'**
  String get planImportHint;

  /// No description provided for @planImportChooseFirst.
  ///
  /// In ja, this message translates to:
  /// **'ファイルを選び、伝票番号を入力してください。'**
  String get planImportChooseFirst;

  /// No description provided for @planImportedSummary.
  ///
  /// In ja, this message translates to:
  /// **'{count} 品目・合計 {total} 本を取り込みました'**
  String planImportedSummary(int count, int total);

  /// No description provided for @planReadAction.
  ///
  /// In ja, this message translates to:
  /// **'読み取る'**
  String get planReadAction;

  /// No description provided for @planReading.
  ///
  /// In ja, this message translates to:
  /// **'読取中…'**
  String get planReading;

  /// No description provided for @importFormatsHint.
  ///
  /// In ja, this message translates to:
  /// **'Excel / PDF / 画像 に対応'**
  String get importFormatsHint;

  /// No description provided for @importChooseFile.
  ///
  /// In ja, this message translates to:
  /// **'ファイルを選ぶ'**
  String get importChooseFile;

  /// No description provided for @changeFile.
  ///
  /// In ja, this message translates to:
  /// **'変更'**
  String get changeFile;

  /// No description provided for @importHeaderSection.
  ///
  /// In ja, this message translates to:
  /// **'ヘッダー情報'**
  String get importHeaderSection;

  /// No description provided for @importLinesPreview.
  ///
  /// In ja, this message translates to:
  /// **'明細プレビュー'**
  String get importLinesPreview;

  /// No description provided for @importLinesEmpty.
  ///
  /// In ja, this message translates to:
  /// **'明細はまだありません。「行を追加」から入力できます。'**
  String get importLinesEmpty;

  /// No description provided for @importAddLine.
  ///
  /// In ja, this message translates to:
  /// **'行を追加'**
  String get importAddLine;

  /// No description provided for @importEditLine.
  ///
  /// In ja, this message translates to:
  /// **'明細を編集'**
  String get importEditLine;

  /// No description provided for @importLineJan.
  ///
  /// In ja, this message translates to:
  /// **'JANコード'**
  String get importLineJan;

  /// No description provided for @importLineProduct.
  ///
  /// In ja, this message translates to:
  /// **'商品名'**
  String get importLineProduct;

  /// No description provided for @importLineQuantity.
  ///
  /// In ja, this message translates to:
  /// **'数量'**
  String get importLineQuantity;

  /// No description provided for @importSplitLine.
  ///
  /// In ja, this message translates to:
  /// **'行を分割'**
  String get importSplitLine;

  /// No description provided for @importMergeDuplicates.
  ///
  /// In ja, this message translates to:
  /// **'同じJANをまとめる'**
  String get importMergeDuplicates;

  /// No description provided for @planReviewTitle.
  ///
  /// In ja, this message translates to:
  /// **'ヘッダーの確認'**
  String get planReviewTitle;

  /// No description provided for @planReviewHint.
  ///
  /// In ja, this message translates to:
  /// **'納品書から自動で読み取りました。間違い・空欄は登録前にここで修正できます。'**
  String get planReviewHint;

  /// No description provided for @planCommitAction.
  ///
  /// In ja, this message translates to:
  /// **'登録する'**
  String get planCommitAction;

  /// No description provided for @planRegistering.
  ///
  /// In ja, this message translates to:
  /// **'登録中…'**
  String get planRegistering;

  /// No description provided for @planPreviewCount.
  ///
  /// In ja, this message translates to:
  /// **'{count} 品目・{total} 本'**
  String planPreviewCount(int count, int total);

  /// No description provided for @fieldRegistrationNumber.
  ///
  /// In ja, this message translates to:
  /// **'登録番号（T…）'**
  String get fieldRegistrationNumber;

  /// No description provided for @fieldCustomerCode.
  ///
  /// In ja, this message translates to:
  /// **'お客様コード'**
  String get fieldCustomerCode;

  /// No description provided for @fieldDocNumber.
  ///
  /// In ja, this message translates to:
  /// **'納品書番号'**
  String get fieldDocNumber;

  /// No description provided for @headerUnreadHint.
  ///
  /// In ja, this message translates to:
  /// **'読み取れませんでした。入力してください'**
  String get headerUnreadHint;

  /// No description provided for @planNeedsReviewBadge.
  ///
  /// In ja, this message translates to:
  /// **'要確認'**
  String get planNeedsReviewBadge;

  /// No description provided for @planUnidentifiedNote.
  ///
  /// In ja, this message translates to:
  /// **'会社名を読み取れなかったため「UNKNOWN」枠の識別番号を採番しました。仕入先を入力すると正しい会社に付け替えられます。'**
  String get planUnidentifiedNote;

  /// No description provided for @referenceNoLabel.
  ///
  /// In ja, this message translates to:
  /// **'整理番号'**
  String get referenceNoLabel;

  /// No description provided for @companyCode.
  ///
  /// In ja, this message translates to:
  /// **'会社コード'**
  String get companyCode;

  /// No description provided for @totalStockTitle.
  ///
  /// In ja, this message translates to:
  /// **'総在庫（JAN別）'**
  String get totalStockTitle;

  /// No description provided for @sortMenu.
  ///
  /// In ja, this message translates to:
  /// **'並び替え'**
  String get sortMenu;

  /// No description provided for @sortByStock.
  ///
  /// In ja, this message translates to:
  /// **'在庫数順'**
  String get sortByStock;

  /// No description provided for @sortByName.
  ///
  /// In ja, this message translates to:
  /// **'品名順'**
  String get sortByName;

  /// No description provided for @sortByJan.
  ///
  /// In ja, this message translates to:
  /// **'JAN順'**
  String get sortByJan;

  /// No description provided for @stockOnHandUnit.
  ///
  /// In ja, this message translates to:
  /// **'在庫'**
  String get stockOnHandUnit;

  /// No description provided for @stockEmpty.
  ///
  /// In ja, this message translates to:
  /// **'在庫がまだありません。'**
  String get stockEmpty;

  /// No description provided for @stockEmptyBody.
  ///
  /// In ja, this message translates to:
  /// **'照合を完了すると、JANごとの総在庫がここに集計されます。'**
  String get stockEmptyBody;

  /// No description provided for @featShipment.
  ///
  /// In ja, this message translates to:
  /// **'出庫'**
  String get featShipment;

  /// No description provided for @featShipmentDesc.
  ///
  /// In ja, this message translates to:
  /// **'出庫リストを取り込み、段ボールに小分けして在庫を引く'**
  String get featShipmentDesc;

  /// No description provided for @shipmentListTitle.
  ///
  /// In ja, this message translates to:
  /// **'出庫'**
  String get shipmentListTitle;

  /// No description provided for @shipmentImportTitle.
  ///
  /// In ja, this message translates to:
  /// **'出庫リストを取り込む'**
  String get shipmentImportTitle;

  /// No description provided for @shipmentEmpty.
  ///
  /// In ja, this message translates to:
  /// **'出庫はありません。'**
  String get shipmentEmpty;

  /// No description provided for @shipmentEmptyBody.
  ///
  /// In ja, this message translates to:
  /// **'得意先のExcel / PDF を取り込んで出庫を始めます。'**
  String get shipmentEmptyBody;

  /// No description provided for @shipmentSearchHint.
  ///
  /// In ja, this message translates to:
  /// **'出庫番号・得意先で検索'**
  String get shipmentSearchHint;

  /// No description provided for @shipmentStatusOpen.
  ///
  /// In ja, this message translates to:
  /// **'梱包待ち'**
  String get shipmentStatusOpen;

  /// No description provided for @shipmentStatusPacking.
  ///
  /// In ja, this message translates to:
  /// **'梱包中'**
  String get shipmentStatusPacking;

  /// No description provided for @shipmentStatusShipped.
  ///
  /// In ja, this message translates to:
  /// **'出庫済み'**
  String get shipmentStatusShipped;

  /// No description provided for @shipmentStatusCancelled.
  ///
  /// In ja, this message translates to:
  /// **'取消'**
  String get shipmentStatusCancelled;

  /// No description provided for @cartonCountLabel.
  ///
  /// In ja, this message translates to:
  /// **'{count} 箱'**
  String cartonCountLabel(int count);

  /// No description provided for @shipmentLinesSection.
  ///
  /// In ja, this message translates to:
  /// **'出庫リスト'**
  String get shipmentLinesSection;

  /// No description provided for @cartonsSection.
  ///
  /// In ja, this message translates to:
  /// **'段ボール'**
  String get cartonsSection;

  /// No description provided for @packProgress.
  ///
  /// In ja, this message translates to:
  /// **'梱包 {packed} / {total}'**
  String packProgress(int packed, int total);

  /// No description provided for @addCarton.
  ///
  /// In ja, this message translates to:
  /// **'段ボールを追加'**
  String get addCarton;

  /// No description provided for @cartonNoLabel.
  ///
  /// In ja, this message translates to:
  /// **'段ボール #{no}'**
  String cartonNoLabel(int no);

  /// No description provided for @cartonLabelHint.
  ///
  /// In ja, this message translates to:
  /// **'ラベル（任意）例: A-1'**
  String get cartonLabelHint;

  /// No description provided for @cartonEditTitle.
  ///
  /// In ja, this message translates to:
  /// **'段ボールの中身'**
  String get cartonEditTitle;

  /// No description provided for @cartonStatusOpen.
  ///
  /// In ja, this message translates to:
  /// **'梱包中'**
  String get cartonStatusOpen;

  /// No description provided for @cartonStatusPacked.
  ///
  /// In ja, this message translates to:
  /// **'梱包済み'**
  String get cartonStatusPacked;

  /// No description provided for @cartonStatusShipped.
  ///
  /// In ja, this message translates to:
  /// **'出庫済み'**
  String get cartonStatusShipped;

  /// No description provided for @cartonStatusCancelled.
  ///
  /// In ja, this message translates to:
  /// **'取消'**
  String get cartonStatusCancelled;

  /// No description provided for @cartonMeasurementsAction.
  ///
  /// In ja, this message translates to:
  /// **'サイズ・重量を編集'**
  String get cartonMeasurementsAction;

  /// No description provided for @cartonMeasurementsSection.
  ///
  /// In ja, this message translates to:
  /// **'サイズ・重量'**
  String get cartonMeasurementsSection;

  /// No description provided for @cartonTypeHint.
  ///
  /// In ja, this message translates to:
  /// **'種類（任意）例: 60サイズ'**
  String get cartonTypeHint;

  /// No description provided for @cartonLength.
  ///
  /// In ja, this message translates to:
  /// **'長さ'**
  String get cartonLength;

  /// No description provided for @cartonWidth.
  ///
  /// In ja, this message translates to:
  /// **'幅'**
  String get cartonWidth;

  /// No description provided for @cartonHeight.
  ///
  /// In ja, this message translates to:
  /// **'高さ'**
  String get cartonHeight;

  /// No description provided for @cartonDimensionsCm.
  ///
  /// In ja, this message translates to:
  /// **'{length} × {width} × {height} cm'**
  String cartonDimensionsCm(String length, String width, String height);

  /// No description provided for @cartonClose.
  ///
  /// In ja, this message translates to:
  /// **'箱を閉じる'**
  String get cartonClose;

  /// No description provided for @cartonCloseEmptyHint.
  ///
  /// In ja, this message translates to:
  /// **'空の箱は閉じられません'**
  String get cartonCloseEmptyHint;

  /// No description provided for @cartonClosed.
  ///
  /// In ja, this message translates to:
  /// **'箱を閉じました'**
  String get cartonClosed;

  /// No description provided for @cartonReopen.
  ///
  /// In ja, this message translates to:
  /// **'箱を開け直す'**
  String get cartonReopen;

  /// No description provided for @cartonReopened.
  ///
  /// In ja, this message translates to:
  /// **'箱を開け直しました'**
  String get cartonReopened;

  /// No description provided for @cartonMustReopenToEdit.
  ///
  /// In ja, this message translates to:
  /// **'編集するには箱を開け直してください'**
  String get cartonMustReopenToEdit;

  /// No description provided for @cartonAddParcel.
  ///
  /// In ja, this message translates to:
  /// **'追加'**
  String get cartonAddParcel;

  /// No description provided for @cartonPackQuantity.
  ///
  /// In ja, this message translates to:
  /// **'梱包数'**
  String get cartonPackQuantity;

  /// No description provided for @cartonUnpackedCount.
  ///
  /// In ja, this message translates to:
  /// **'残り {qty}'**
  String cartonUnpackedCount(int qty);

  /// No description provided for @cartonLineDone.
  ///
  /// In ja, this message translates to:
  /// **'梱包完了'**
  String get cartonLineDone;

  /// No description provided for @cartonRenameAction.
  ///
  /// In ja, this message translates to:
  /// **'名前を変更'**
  String get cartonRenameAction;

  /// No description provided for @cartonRenameTitle.
  ///
  /// In ja, this message translates to:
  /// **'段ボールの名前'**
  String get cartonRenameTitle;

  /// No description provided for @cartonSerialNumber.
  ///
  /// In ja, this message translates to:
  /// **'シリアル番号'**
  String get cartonSerialNumber;

  /// No description provided for @cartonContentsSection.
  ///
  /// In ja, this message translates to:
  /// **'この箱の中身'**
  String get cartonContentsSection;

  /// No description provided for @cartonContentsEmpty.
  ///
  /// In ja, this message translates to:
  /// **'まだ何も入っていません'**
  String get cartonContentsEmpty;

  /// No description provided for @packRemaining.
  ///
  /// In ja, this message translates to:
  /// **'未梱包'**
  String get packRemaining;

  /// No description provided for @packThisCarton.
  ///
  /// In ja, this message translates to:
  /// **'この箱'**
  String get packThisCarton;

  /// No description provided for @overpackWarning.
  ///
  /// In ja, this message translates to:
  /// **'梱包数が出庫数を超えています。'**
  String get overpackWarning;

  /// No description provided for @shipConfirmAction.
  ///
  /// In ja, this message translates to:
  /// **'出庫確定'**
  String get shipConfirmAction;

  /// No description provided for @shipConfirmQ.
  ///
  /// In ja, this message translates to:
  /// **'出庫を確定しますか？'**
  String get shipConfirmQ;

  /// No description provided for @shipConfirmBody.
  ///
  /// In ja, this message translates to:
  /// **'在庫から数量を引いて出庫を確定します。'**
  String get shipConfirmBody;

  /// No description provided for @shipShortWarning.
  ///
  /// In ja, this message translates to:
  /// **'在庫が不足している品目があります。在庫はマイナスにはなりません。確定しますか？'**
  String get shipShortWarning;

  /// No description provided for @shipDone.
  ///
  /// In ja, this message translates to:
  /// **'出庫を確定しました'**
  String get shipDone;

  /// No description provided for @shipCancelAction.
  ///
  /// In ja, this message translates to:
  /// **'出庫を取消'**
  String get shipCancelAction;

  /// No description provided for @shipCancelQ.
  ///
  /// In ja, this message translates to:
  /// **'この出庫を取り消しますか？'**
  String get shipCancelQ;

  /// No description provided for @shipCancelBody.
  ///
  /// In ja, this message translates to:
  /// **'引いた数量を在庫に戻し、出庫を未確定に戻します。'**
  String get shipCancelBody;

  /// No description provided for @shipCancelledDone.
  ///
  /// In ja, this message translates to:
  /// **'出庫を未確定に戻しました'**
  String get shipCancelledDone;

  /// No description provided for @printOverall.
  ///
  /// In ja, this message translates to:
  /// **'出庫リストを印刷/PDF'**
  String get printOverall;

  /// No description provided for @printAllCartons.
  ///
  /// In ja, this message translates to:
  /// **'段ボール別を印刷/PDF'**
  String get printAllCartons;

  /// No description provided for @printThisCarton.
  ///
  /// In ja, this message translates to:
  /// **'印刷/PDF'**
  String get printThisCarton;

  /// No description provided for @printDeliverySlip.
  ///
  /// In ja, this message translates to:
  /// **'送り状を印刷/PDF'**
  String get printDeliverySlip;

  /// No description provided for @printMenu.
  ///
  /// In ja, this message translates to:
  /// **'印刷/PDF'**
  String get printMenu;

  /// No description provided for @senderSettingsTitle.
  ///
  /// In ja, this message translates to:
  /// **'差出人（自社）設定'**
  String get senderSettingsTitle;

  /// No description provided for @senderSettingsHint.
  ///
  /// In ja, this message translates to:
  /// **'差出人のデフォルトとして保存します。印刷時にどの項目を載せるか毎回選べます。'**
  String get senderSettingsHint;

  /// No description provided for @senderPickTitle.
  ///
  /// In ja, this message translates to:
  /// **'この印刷の差出人'**
  String get senderPickTitle;

  /// No description provided for @senderInclude.
  ///
  /// In ja, this message translates to:
  /// **'差出人を印刷する'**
  String get senderInclude;

  /// No description provided for @senderNoneSet.
  ///
  /// In ja, this message translates to:
  /// **'差出人が未設定です。'**
  String get senderNoneSet;

  /// No description provided for @senderSaved.
  ///
  /// In ja, this message translates to:
  /// **'差出人情報を保存しました'**
  String get senderSaved;

  /// No description provided for @senderPreview.
  ///
  /// In ja, this message translates to:
  /// **'印刷プレビュー'**
  String get senderPreview;

  /// No description provided for @fieldCompanyName.
  ///
  /// In ja, this message translates to:
  /// **'会社名'**
  String get fieldCompanyName;

  /// No description provided for @fieldPostalCode.
  ///
  /// In ja, this message translates to:
  /// **'郵便番号'**
  String get fieldPostalCode;

  /// No description provided for @fieldFax.
  ///
  /// In ja, this message translates to:
  /// **'FAX'**
  String get fieldFax;

  /// No description provided for @fieldNote.
  ///
  /// In ja, this message translates to:
  /// **'備考'**
  String get fieldNote;

  /// No description provided for @deleteCartonQ.
  ///
  /// In ja, this message translates to:
  /// **'この段ボールを削除しますか？'**
  String get deleteCartonQ;

  /// No description provided for @actionSave.
  ///
  /// In ja, this message translates to:
  /// **'保存'**
  String get actionSave;

  /// No description provided for @actionDelete.
  ///
  /// In ja, this message translates to:
  /// **'削除'**
  String get actionDelete;

  /// No description provided for @dashOverview.
  ///
  /// In ja, this message translates to:
  /// **'概況'**
  String get dashOverview;

  /// No description provided for @dashInboundToday.
  ///
  /// In ja, this message translates to:
  /// **'本日の入庫'**
  String get dashInboundToday;

  /// No description provided for @dashOutboundToday.
  ///
  /// In ja, this message translates to:
  /// **'本日の出庫'**
  String get dashOutboundToday;

  /// No description provided for @dashOutstanding.
  ///
  /// In ja, this message translates to:
  /// **'未納'**
  String get dashOutstanding;

  /// No description provided for @dashTotalStock.
  ///
  /// In ja, this message translates to:
  /// **'総在庫'**
  String get dashTotalStock;

  /// No description provided for @dashLowStock.
  ///
  /// In ja, this message translates to:
  /// **'要注意在庫'**
  String get dashLowStock;

  /// No description provided for @dashTrendTitle.
  ///
  /// In ja, this message translates to:
  /// **'入出庫の推移（14日）'**
  String get dashTrendTitle;

  /// No description provided for @dashInbound.
  ///
  /// In ja, this message translates to:
  /// **'入庫'**
  String get dashInbound;

  /// No description provided for @dashOutbound.
  ///
  /// In ja, this message translates to:
  /// **'出庫'**
  String get dashOutbound;

  /// No description provided for @dashOutstandingListTitle.
  ///
  /// In ja, this message translates to:
  /// **'未納リスト'**
  String get dashOutstandingListTitle;

  /// No description provided for @dashLowStockListTitle.
  ///
  /// In ja, this message translates to:
  /// **'在庫アラート'**
  String get dashLowStockListTitle;

  /// No description provided for @dashNoOutstanding.
  ///
  /// In ja, this message translates to:
  /// **'未納はありません'**
  String get dashNoOutstanding;

  /// No description provided for @dashNoAlerts.
  ///
  /// In ja, this message translates to:
  /// **'在庫アラートはありません'**
  String get dashNoAlerts;

  /// No description provided for @dashCount.
  ///
  /// In ja, this message translates to:
  /// **'{count}件'**
  String dashCount(int count);

  /// No description provided for @dashSkuCount.
  ///
  /// In ja, this message translates to:
  /// **'{count} SKU'**
  String dashSkuCount(int count);

  /// No description provided for @dashThreshold.
  ///
  /// In ja, this message translates to:
  /// **'しきい値 {count}'**
  String dashThreshold(int count);

  /// No description provided for @whAllWarehouses.
  ///
  /// In ja, this message translates to:
  /// **'すべての倉庫'**
  String get whAllWarehouses;

  /// No description provided for @whSwitch.
  ///
  /// In ja, this message translates to:
  /// **'倉庫を切替'**
  String get whSwitch;

  /// No description provided for @whAdd.
  ///
  /// In ja, this message translates to:
  /// **'倉庫を追加'**
  String get whAdd;

  /// No description provided for @whAddTitle.
  ///
  /// In ja, this message translates to:
  /// **'倉庫を追加'**
  String get whAddTitle;

  /// No description provided for @whManage.
  ///
  /// In ja, this message translates to:
  /// **'倉庫を管理'**
  String get whManage;

  /// No description provided for @whOverviewTitle.
  ///
  /// In ja, this message translates to:
  /// **'倉庫一覧'**
  String get whOverviewTitle;

  /// No description provided for @whTotals.
  ///
  /// In ja, this message translates to:
  /// **'合計'**
  String get whTotals;

  /// No description provided for @whFieldCode.
  ///
  /// In ja, this message translates to:
  /// **'倉庫コード'**
  String get whFieldCode;

  /// No description provided for @whFieldName.
  ///
  /// In ja, this message translates to:
  /// **'倉庫名'**
  String get whFieldName;

  /// No description provided for @whFieldAddress.
  ///
  /// In ja, this message translates to:
  /// **'住所'**
  String get whFieldAddress;

  /// No description provided for @whFieldPhone.
  ///
  /// In ja, this message translates to:
  /// **'電話'**
  String get whFieldPhone;

  /// No description provided for @whFieldTimezone.
  ///
  /// In ja, this message translates to:
  /// **'タイムゾーン'**
  String get whFieldTimezone;

  /// No description provided for @whFieldActive.
  ///
  /// In ja, this message translates to:
  /// **'有効'**
  String get whFieldActive;

  /// No description provided for @whFieldDefaultBins.
  ///
  /// In ja, this message translates to:
  /// **'初期の棚を作成する'**
  String get whFieldDefaultBins;

  /// No description provided for @whFieldDefaultBinsHelp.
  ///
  /// In ja, this message translates to:
  /// **'入荷仮置・検品保留・出荷・通常棚の4つを自動作成します。'**
  String get whFieldDefaultBinsHelp;

  /// No description provided for @whFieldReceivingBin.
  ///
  /// In ja, this message translates to:
  /// **'デフォルト入荷エリア'**
  String get whFieldReceivingBin;

  /// No description provided for @whFieldShippingBin.
  ///
  /// In ja, this message translates to:
  /// **'デフォルト出荷エリア'**
  String get whFieldShippingBin;

  /// No description provided for @whCodeRequired.
  ///
  /// In ja, this message translates to:
  /// **'倉庫コードを入力してください'**
  String get whCodeRequired;

  /// No description provided for @whNameRequired.
  ///
  /// In ja, this message translates to:
  /// **'倉庫名を入力してください'**
  String get whNameRequired;

  /// No description provided for @whCreated.
  ///
  /// In ja, this message translates to:
  /// **'倉庫「{name}」を追加しました'**
  String whCreated(String name);

  /// No description provided for @whInactive.
  ///
  /// In ja, this message translates to:
  /// **'無効'**
  String get whInactive;

  /// No description provided for @whStatInbound.
  ///
  /// In ja, this message translates to:
  /// **'入荷待ち'**
  String get whStatInbound;

  /// No description provided for @whStatOutbound.
  ///
  /// In ja, this message translates to:
  /// **'出荷待ち'**
  String get whStatOutbound;

  /// No description provided for @whStatSku.
  ///
  /// In ja, this message translates to:
  /// **'SKU'**
  String get whStatSku;

  /// No description provided for @whStatOnHand.
  ///
  /// In ja, this message translates to:
  /// **'在庫'**
  String get whStatOnHand;

  /// No description provided for @noRoleAssigned.
  ///
  /// In ja, this message translates to:
  /// **'権限がまだ割り当てられていません'**
  String get noRoleAssigned;

  /// No description provided for @noRoleAssignedBody.
  ///
  /// In ja, this message translates to:
  /// **'サインインはできていますが、まだ役割（ロール）が割り当てられていないため、使える機能がありません。管理者に権限の割り当てを依頼してください。'**
  String get noRoleAssignedBody;

  /// No description provided for @whNoAssignedWarehouse.
  ///
  /// In ja, this message translates to:
  /// **'倉庫が割り当てられていません'**
  String get whNoAssignedWarehouse;

  /// No description provided for @whNoAssignedWarehouseBody.
  ///
  /// In ja, this message translates to:
  /// **'あなたのアカウントはまだどの倉庫にも割り当てられていないため、在庫の閲覧や作業ができません。管理者に倉庫の割り当てを依頼してください。'**
  String get whNoAssignedWarehouseBody;

  /// No description provided for @whNoWarehouses.
  ///
  /// In ja, this message translates to:
  /// **'倉庫がまだありません'**
  String get whNoWarehouses;

  /// No description provided for @whBinsTitle.
  ///
  /// In ja, this message translates to:
  /// **'棚（ロケーション）'**
  String get whBinsTitle;

  /// No description provided for @whBinStaging.
  ///
  /// In ja, this message translates to:
  /// **'入荷仮置'**
  String get whBinStaging;

  /// No description provided for @whBinPickable.
  ///
  /// In ja, this message translates to:
  /// **'通常棚'**
  String get whBinPickable;

  /// No description provided for @whBinPickableStaging.
  ///
  /// In ja, this message translates to:
  /// **'仮置(引当可)'**
  String get whBinPickableStaging;

  /// No description provided for @whBinQcHold.
  ///
  /// In ja, this message translates to:
  /// **'検品保留'**
  String get whBinQcHold;

  /// No description provided for @whBinShipping.
  ///
  /// In ja, this message translates to:
  /// **'出荷'**
  String get whBinShipping;

  /// No description provided for @whBinReturns.
  ///
  /// In ja, this message translates to:
  /// **'返品'**
  String get whBinReturns;

  /// No description provided for @whBinDamaged.
  ///
  /// In ja, this message translates to:
  /// **'破損'**
  String get whBinDamaged;

  /// No description provided for @whBinVirtual.
  ///
  /// In ja, this message translates to:
  /// **'仮想'**
  String get whBinVirtual;

  /// No description provided for @ledgerTitle.
  ///
  /// In ja, this message translates to:
  /// **'在庫履歴'**
  String get ledgerTitle;

  /// No description provided for @ledgerSubtitle.
  ///
  /// In ja, this message translates to:
  /// **'この商品の在庫が動いた理由'**
  String get ledgerSubtitle;

  /// No description provided for @ledgerEmpty.
  ///
  /// In ja, this message translates to:
  /// **'まだ在庫の動きがありません'**
  String get ledgerEmpty;

  /// No description provided for @ledgerBeforeAfter.
  ///
  /// In ja, this message translates to:
  /// **'変更前 → 変更後'**
  String get ledgerBeforeAfter;

  /// No description provided for @mvOpening.
  ///
  /// In ja, this message translates to:
  /// **'期首'**
  String get mvOpening;

  /// No description provided for @mvReceipt.
  ///
  /// In ja, this message translates to:
  /// **'入庫'**
  String get mvReceipt;

  /// No description provided for @mvReceiptCancel.
  ///
  /// In ja, this message translates to:
  /// **'入庫取消'**
  String get mvReceiptCancel;

  /// No description provided for @mvPutaway.
  ///
  /// In ja, this message translates to:
  /// **'棚入れ'**
  String get mvPutaway;

  /// No description provided for @mvPick.
  ///
  /// In ja, this message translates to:
  /// **'ピッキング'**
  String get mvPick;

  /// No description provided for @mvShip.
  ///
  /// In ja, this message translates to:
  /// **'出庫'**
  String get mvShip;

  /// No description provided for @mvShipCancel.
  ///
  /// In ja, this message translates to:
  /// **'出庫取消'**
  String get mvShipCancel;

  /// No description provided for @mvAdjust.
  ///
  /// In ja, this message translates to:
  /// **'在庫調整'**
  String get mvAdjust;

  /// No description provided for @mvCount.
  ///
  /// In ja, this message translates to:
  /// **'棚卸'**
  String get mvCount;

  /// No description provided for @mvTransferIn.
  ///
  /// In ja, this message translates to:
  /// **'移動入庫'**
  String get mvTransferIn;

  /// No description provided for @mvTransferOut.
  ///
  /// In ja, this message translates to:
  /// **'移動出庫'**
  String get mvTransferOut;

  /// No description provided for @qcTitle.
  ///
  /// In ja, this message translates to:
  /// **'検品'**
  String get qcTitle;

  /// No description provided for @qcListEmpty.
  ///
  /// In ja, this message translates to:
  /// **'検品はまだありません'**
  String get qcListEmpty;

  /// No description provided for @qcListEmptyBody.
  ///
  /// In ja, this message translates to:
  /// **'受領履歴から検品を開始できます。'**
  String get qcListEmptyBody;

  /// No description provided for @qcStart.
  ///
  /// In ja, this message translates to:
  /// **'検品を開始'**
  String get qcStart;

  /// No description provided for @qcComplete.
  ///
  /// In ja, this message translates to:
  /// **'検品を確定'**
  String get qcComplete;

  /// No description provided for @qcResultPending.
  ///
  /// In ja, this message translates to:
  /// **'未検品'**
  String get qcResultPending;

  /// No description provided for @qcResultPass.
  ///
  /// In ja, this message translates to:
  /// **'合格'**
  String get qcResultPass;

  /// No description provided for @qcResultFail.
  ///
  /// In ja, this message translates to:
  /// **'不合格'**
  String get qcResultFail;

  /// No description provided for @qcResultPartial.
  ///
  /// In ja, this message translates to:
  /// **'一部合格'**
  String get qcResultPartial;

  /// No description provided for @qcResultHold.
  ///
  /// In ja, this message translates to:
  /// **'保留'**
  String get qcResultHold;

  /// No description provided for @qcPassed.
  ///
  /// In ja, this message translates to:
  /// **'合格数'**
  String get qcPassed;

  /// No description provided for @qcFailed.
  ///
  /// In ja, this message translates to:
  /// **'不良数'**
  String get qcFailed;

  /// No description provided for @qcExpected.
  ///
  /// In ja, this message translates to:
  /// **'予定'**
  String get qcExpected;

  /// No description provided for @qcActual.
  ///
  /// In ja, this message translates to:
  /// **'実数'**
  String get qcActual;

  /// No description provided for @qcDiscrepancy.
  ///
  /// In ja, this message translates to:
  /// **'差異'**
  String get qcDiscrepancy;

  /// No description provided for @qcLot.
  ///
  /// In ja, this message translates to:
  /// **'ロット'**
  String get qcLot;

  /// No description provided for @qcNote.
  ///
  /// In ja, this message translates to:
  /// **'備考'**
  String get qcNote;

  /// No description provided for @qcHold.
  ///
  /// In ja, this message translates to:
  /// **'保留にする'**
  String get qcHold;

  /// No description provided for @qcRecord.
  ///
  /// In ja, this message translates to:
  /// **'記録'**
  String get qcRecord;

  /// No description provided for @qcUnchecked.
  ///
  /// In ja, this message translates to:
  /// **'未検品 {count} 件'**
  String qcUnchecked(int count);

  /// No description provided for @qcCompleteBlocked.
  ///
  /// In ja, this message translates to:
  /// **'未検品の明細があるため確定できません'**
  String get qcCompleteBlocked;

  /// No description provided for @qcCompleted.
  ///
  /// In ja, this message translates to:
  /// **'検品を確定しました（{status}）'**
  String qcCompleted(String status);

  /// No description provided for @qcFailedUnits.
  ///
  /// In ja, this message translates to:
  /// **'不良 {count}'**
  String qcFailedUnits(int count);

  /// No description provided for @qcSplitHint.
  ///
  /// In ja, this message translates to:
  /// **'合格数と不良数を入力してください（合計が実数になります）'**
  String get qcSplitHint;

  /// No description provided for @qcAttachmentsEmpty.
  ///
  /// In ja, this message translates to:
  /// **'写真はまだありません'**
  String get qcAttachmentsEmpty;

  /// No description provided for @qcAttachmentCamera.
  ///
  /// In ja, this message translates to:
  /// **'カメラで撮影'**
  String get qcAttachmentCamera;

  /// No description provided for @qcAttachmentGallery.
  ///
  /// In ja, this message translates to:
  /// **'ギャラリーから選択'**
  String get qcAttachmentGallery;

  /// No description provided for @whFieldUsesLocations.
  ///
  /// In ja, this message translates to:
  /// **'棚（ロケーション）で管理する'**
  String get whFieldUsesLocations;

  /// No description provided for @whFieldUsesLocationsHelp.
  ///
  /// In ja, this message translates to:
  /// **'オフのままなら在庫は倉庫単位で管理します。棚番で管理する場合だけオンにしてください（後から変更できます）。'**
  String get whFieldUsesLocationsHelp;

  /// No description provided for @whLocationsOn.
  ///
  /// In ja, this message translates to:
  /// **'棚管理'**
  String get whLocationsOn;

  /// No description provided for @adjTitle.
  ///
  /// In ja, this message translates to:
  /// **'在庫調整'**
  String get adjTitle;

  /// No description provided for @adjNew.
  ///
  /// In ja, this message translates to:
  /// **'在庫を調整'**
  String get adjNew;

  /// No description provided for @adjEmpty.
  ///
  /// In ja, this message translates to:
  /// **'調整履歴はまだありません'**
  String get adjEmpty;

  /// No description provided for @adjEmptyBody.
  ///
  /// In ja, this message translates to:
  /// **'破損・紛失・発見などの理由を付けて在庫を補正できます。'**
  String get adjEmptyBody;

  /// No description provided for @adjJan.
  ///
  /// In ja, this message translates to:
  /// **'JANコード'**
  String get adjJan;

  /// No description provided for @adjQuantity.
  ///
  /// In ja, this message translates to:
  /// **'数量'**
  String get adjQuantity;

  /// No description provided for @adjReason.
  ///
  /// In ja, this message translates to:
  /// **'理由'**
  String get adjReason;

  /// No description provided for @adjNote.
  ///
  /// In ja, this message translates to:
  /// **'備考'**
  String get adjNote;

  /// No description provided for @adjApply.
  ///
  /// In ja, this message translates to:
  /// **'調整を確定'**
  String get adjApply;

  /// No description provided for @adjConfirmQ.
  ///
  /// In ja, this message translates to:
  /// **'在庫を調整しますか？'**
  String get adjConfirmQ;

  /// No description provided for @adjConfirmIrreversible.
  ///
  /// In ja, this message translates to:
  /// **'この操作は取り消せません。'**
  String get adjConfirmIrreversible;

  /// No description provided for @adjConfirmAction.
  ///
  /// In ja, this message translates to:
  /// **'調整する'**
  String get adjConfirmAction;

  /// No description provided for @adjDone.
  ///
  /// In ja, this message translates to:
  /// **'在庫を調整しました（{delta}）'**
  String adjDone(String delta);

  /// No description provided for @adjNeedsWarehouse.
  ///
  /// In ja, this message translates to:
  /// **'先に倉庫を選んでください'**
  String get adjNeedsWarehouse;

  /// No description provided for @adjJanRequired.
  ///
  /// In ja, this message translates to:
  /// **'JANコードを入力してください'**
  String get adjJanRequired;

  /// No description provided for @adjDeltaRequired.
  ///
  /// In ja, this message translates to:
  /// **'1以上の数量を入力してください'**
  String get adjDeltaRequired;

  /// No description provided for @reasonDamage.
  ///
  /// In ja, this message translates to:
  /// **'破損'**
  String get reasonDamage;

  /// No description provided for @reasonLoss.
  ///
  /// In ja, this message translates to:
  /// **'紛失'**
  String get reasonLoss;

  /// No description provided for @reasonFound.
  ///
  /// In ja, this message translates to:
  /// **'発見'**
  String get reasonFound;

  /// No description provided for @reasonCorrection.
  ///
  /// In ja, this message translates to:
  /// **'入力訂正'**
  String get reasonCorrection;

  /// No description provided for @reasonReturn.
  ///
  /// In ja, this message translates to:
  /// **'返品戻し'**
  String get reasonReturn;

  /// No description provided for @reasonInternalUse.
  ///
  /// In ja, this message translates to:
  /// **'社内消費'**
  String get reasonInternalUse;

  /// No description provided for @reasonOther.
  ///
  /// In ja, this message translates to:
  /// **'その他'**
  String get reasonOther;

  /// No description provided for @cntTitle.
  ///
  /// In ja, this message translates to:
  /// **'棚卸'**
  String get cntTitle;

  /// No description provided for @cntEmpty.
  ///
  /// In ja, this message translates to:
  /// **'棚卸はまだありません'**
  String get cntEmpty;

  /// No description provided for @cntEmptyBody.
  ///
  /// In ja, this message translates to:
  /// **'実地棚卸を開始すると、現在の在庫が控えられます。'**
  String get cntEmptyBody;

  /// No description provided for @cntStart.
  ///
  /// In ja, this message translates to:
  /// **'棚卸を開始'**
  String get cntStart;

  /// No description provided for @cntBlind.
  ///
  /// In ja, this message translates to:
  /// **'ブラインド棚卸'**
  String get cntBlind;

  /// No description provided for @cntBlindHelp.
  ///
  /// In ja, this message translates to:
  /// **'数え終わるまで理論在庫を表示しません。先入観なく数えられます。'**
  String get cntBlindHelp;

  /// No description provided for @cntSystem.
  ///
  /// In ja, this message translates to:
  /// **'理論'**
  String get cntSystem;

  /// No description provided for @cntCounted.
  ///
  /// In ja, this message translates to:
  /// **'実査'**
  String get cntCounted;

  /// No description provided for @cntVariance.
  ///
  /// In ja, this message translates to:
  /// **'差異'**
  String get cntVariance;

  /// No description provided for @cntHidden.
  ///
  /// In ja, this message translates to:
  /// **'確定まで非表示'**
  String get cntHidden;

  /// No description provided for @cntRecord.
  ///
  /// In ja, this message translates to:
  /// **'実査数を入力'**
  String get cntRecord;

  /// No description provided for @cntComplete.
  ///
  /// In ja, this message translates to:
  /// **'棚卸を確定'**
  String get cntComplete;

  /// No description provided for @cntCancel.
  ///
  /// In ja, this message translates to:
  /// **'棚卸を中止'**
  String get cntCancel;

  /// No description provided for @cntCompleteQ.
  ///
  /// In ja, this message translates to:
  /// **'棚卸を確定しますか？'**
  String get cntCompleteQ;

  /// No description provided for @cntCompleteBody.
  ///
  /// In ja, this message translates to:
  /// **'差異のある行だけ在庫を補正し、棚卸として記録します。'**
  String get cntCompleteBody;

  /// No description provided for @cntCancelQ.
  ///
  /// In ja, this message translates to:
  /// **'この棚卸を中止しますか？'**
  String get cntCancelQ;

  /// No description provided for @cntCancelBody.
  ///
  /// In ja, this message translates to:
  /// **'実査した数値は破棄され、在庫は変わりません。'**
  String get cntCancelBody;

  /// No description provided for @cntCancelled.
  ///
  /// In ja, this message translates to:
  /// **'棚卸を中止しました'**
  String get cntCancelled;

  /// No description provided for @cntProgress.
  ///
  /// In ja, this message translates to:
  /// **'{counted}/{total} 実査済み'**
  String cntProgress(int counted, int total);

  /// No description provided for @cntCompleted.
  ///
  /// In ja, this message translates to:
  /// **'棚卸を確定しました（{lines}行を補正・純増減 {net}）'**
  String cntCompleted(int lines, String net);

  /// No description provided for @cntUncountedWarn.
  ///
  /// In ja, this message translates to:
  /// **'未実査 {count} 行はそのまま残ります（0とはみなしません）'**
  String cntUncountedWarn(int count);

  /// No description provided for @cntStatusCounting.
  ///
  /// In ja, this message translates to:
  /// **'実査中'**
  String get cntStatusCounting;

  /// No description provided for @cntStatusCompleted.
  ///
  /// In ja, this message translates to:
  /// **'確定済み'**
  String get cntStatusCompleted;

  /// No description provided for @cntStatusCancelled.
  ///
  /// In ja, this message translates to:
  /// **'中止'**
  String get cntStatusCancelled;

  /// No description provided for @pickListsTitle.
  ///
  /// In ja, this message translates to:
  /// **'ピッキング'**
  String get pickListsTitle;

  /// No description provided for @pickStart.
  ///
  /// In ja, this message translates to:
  /// **'ピッキング開始'**
  String get pickStart;

  /// No description provided for @pickChooseShipment.
  ///
  /// In ja, this message translates to:
  /// **'出荷を選択'**
  String get pickChooseShipment;

  /// No description provided for @pickNoShipments.
  ///
  /// In ja, this message translates to:
  /// **'ピッキング対象の出荷がありません'**
  String get pickNoShipments;

  /// No description provided for @pickStatusPicking.
  ///
  /// In ja, this message translates to:
  /// **'ピック中'**
  String get pickStatusPicking;

  /// No description provided for @pickStatusPicked.
  ///
  /// In ja, this message translates to:
  /// **'ピック完了'**
  String get pickStatusPicked;

  /// No description provided for @pickStatusCancelled.
  ///
  /// In ja, this message translates to:
  /// **'中止'**
  String get pickStatusCancelled;

  /// No description provided for @pickTaskPending.
  ///
  /// In ja, this message translates to:
  /// **'未ピック'**
  String get pickTaskPending;

  /// No description provided for @pickTaskPicked.
  ///
  /// In ja, this message translates to:
  /// **'完了'**
  String get pickTaskPicked;

  /// No description provided for @pickTaskShort.
  ///
  /// In ja, this message translates to:
  /// **'不足'**
  String get pickTaskShort;

  /// No description provided for @pickTaskOver.
  ///
  /// In ja, this message translates to:
  /// **'超過'**
  String get pickTaskOver;

  /// No description provided for @pickPlanned.
  ///
  /// In ja, this message translates to:
  /// **'予定'**
  String get pickPlanned;

  /// No description provided for @pickPickedQty.
  ///
  /// In ja, this message translates to:
  /// **'ピック数'**
  String get pickPickedQty;

  /// No description provided for @pickVariance.
  ///
  /// In ja, this message translates to:
  /// **'差異'**
  String get pickVariance;

  /// No description provided for @pickBin.
  ///
  /// In ja, this message translates to:
  /// **'ロケーション'**
  String get pickBin;

  /// No description provided for @pickBinNone.
  ///
  /// In ja, this message translates to:
  /// **'未指定'**
  String get pickBinNone;

  /// No description provided for @pickRecord.
  ///
  /// In ja, this message translates to:
  /// **'ピック数を記録'**
  String get pickRecord;

  /// No description provided for @pickComplete.
  ///
  /// In ja, this message translates to:
  /// **'ピッキング完了'**
  String get pickComplete;

  /// No description provided for @pickCompleteQ.
  ///
  /// In ja, this message translates to:
  /// **'ピッキングを完了しますか？'**
  String get pickCompleteQ;

  /// No description provided for @pickCompleteBody.
  ///
  /// In ja, this message translates to:
  /// **'梱包工程に進みます。出荷はこのあと別に確定します。'**
  String get pickCompleteBody;

  /// No description provided for @pickCancelAction.
  ///
  /// In ja, this message translates to:
  /// **'ピッキングを中止'**
  String get pickCancelAction;

  /// No description provided for @pickCancelQ.
  ///
  /// In ja, this message translates to:
  /// **'このピッキングを中止しますか？'**
  String get pickCancelQ;

  /// No description provided for @pickCancelBody.
  ///
  /// In ja, this message translates to:
  /// **'記録した数量は破棄されます。在庫は変わりません。'**
  String get pickCancelBody;

  /// No description provided for @pickCancelled.
  ///
  /// In ja, this message translates to:
  /// **'ピッキングを中止しました'**
  String get pickCancelled;

  /// No description provided for @pickCompleted.
  ///
  /// In ja, this message translates to:
  /// **'ピッキングを完了しました（{short}件不足・{over}件超過）'**
  String pickCompleted(int short, int over);

  /// No description provided for @pickCompleteBlocked.
  ///
  /// In ja, this message translates to:
  /// **'未ピックの明細があるため完了できません'**
  String get pickCompleteBlocked;

  /// Pick task item: this parcel has no lot or serial recorded.
  ///
  /// In ja, this message translates to:
  /// **'ロット未記録'**
  String get pickItemNoLot;

  /// Pick task item: tooltip on the remove button.
  ///
  /// In ja, this message translates to:
  /// **'この記録を取り消す'**
  String get pickItemRemove;

  /// Pick task: how much of the picked quantity has no parcel recorded.
  ///
  /// In ja, this message translates to:
  /// **'未記録 {qty}'**
  String pickItemUnattributed(int qty);

  /// Record-pick dialog: optional lot code field label.
  ///
  /// In ja, this message translates to:
  /// **'ロット番号'**
  String get pickLotCode;

  /// Record-pick dialog: hint that the lot code field is optional.
  ///
  /// In ja, this message translates to:
  /// **'任意'**
  String get pickLotCodeHint;

  /// No description provided for @transferTitle.
  ///
  /// In ja, this message translates to:
  /// **'倉庫間移動'**
  String get transferTitle;

  /// No description provided for @transferNew.
  ///
  /// In ja, this message translates to:
  /// **'移動を作成'**
  String get transferNew;

  /// No description provided for @transferEmpty.
  ///
  /// In ja, this message translates to:
  /// **'移動はまだありません'**
  String get transferEmpty;

  /// No description provided for @transferEmptyBody.
  ///
  /// In ja, this message translates to:
  /// **'倉庫間で在庫を移動すると、ここに表示されます。'**
  String get transferEmptyBody;

  /// No description provided for @transferSource.
  ///
  /// In ja, this message translates to:
  /// **'移動元'**
  String get transferSource;

  /// No description provided for @transferDestination.
  ///
  /// In ja, this message translates to:
  /// **'移動先'**
  String get transferDestination;

  /// No description provided for @transferNeedsTwoWarehouses.
  ///
  /// In ja, this message translates to:
  /// **'倉庫が2つ以上必要です'**
  String get transferNeedsTwoWarehouses;

  /// No description provided for @transferLinesTitle.
  ///
  /// In ja, this message translates to:
  /// **'移動する商品'**
  String get transferLinesTitle;

  /// No description provided for @transferAddLine.
  ///
  /// In ja, this message translates to:
  /// **'商品を追加'**
  String get transferAddLine;

  /// No description provided for @transferLineJan.
  ///
  /// In ja, this message translates to:
  /// **'JANコード'**
  String get transferLineJan;

  /// No description provided for @transferLineQuantity.
  ///
  /// In ja, this message translates to:
  /// **'数量'**
  String get transferLineQuantity;

  /// No description provided for @transferLineRequired.
  ///
  /// In ja, this message translates to:
  /// **'1件以上の商品を追加してください'**
  String get transferLineRequired;

  /// No description provided for @transferNote.
  ///
  /// In ja, this message translates to:
  /// **'備考'**
  String get transferNote;

  /// No description provided for @transferCreate.
  ///
  /// In ja, this message translates to:
  /// **'移動を作成'**
  String get transferCreate;

  /// No description provided for @transferCreated.
  ///
  /// In ja, this message translates to:
  /// **'移動 {number} を作成しました'**
  String transferCreated(String number);

  /// No description provided for @transferStatusDraft.
  ///
  /// In ja, this message translates to:
  /// **'下書き'**
  String get transferStatusDraft;

  /// No description provided for @transferStatusPendingApproval.
  ///
  /// In ja, this message translates to:
  /// **'承認待ち'**
  String get transferStatusPendingApproval;

  /// No description provided for @transferStatusApproved.
  ///
  /// In ja, this message translates to:
  /// **'承認済み'**
  String get transferStatusApproved;

  /// No description provided for @transferStatusPicking.
  ///
  /// In ja, this message translates to:
  /// **'ピック中'**
  String get transferStatusPicking;

  /// No description provided for @transferStatusInTransit.
  ///
  /// In ja, this message translates to:
  /// **'輸送中'**
  String get transferStatusInTransit;

  /// No description provided for @transferStatusReceiving.
  ///
  /// In ja, this message translates to:
  /// **'受入中'**
  String get transferStatusReceiving;

  /// No description provided for @transferStatusCompleted.
  ///
  /// In ja, this message translates to:
  /// **'完了'**
  String get transferStatusCompleted;

  /// No description provided for @transferStatusRejected.
  ///
  /// In ja, this message translates to:
  /// **'却下'**
  String get transferStatusRejected;

  /// No description provided for @transferStatusCancelled.
  ///
  /// In ja, this message translates to:
  /// **'中止'**
  String get transferStatusCancelled;

  /// No description provided for @transferSubmit.
  ///
  /// In ja, this message translates to:
  /// **'承認を申請'**
  String get transferSubmit;

  /// No description provided for @transferSubmitted.
  ///
  /// In ja, this message translates to:
  /// **'承認を申請しました'**
  String get transferSubmitted;

  /// No description provided for @transferApprove.
  ///
  /// In ja, this message translates to:
  /// **'承認する'**
  String get transferApprove;

  /// No description provided for @transferApproveQ.
  ///
  /// In ja, this message translates to:
  /// **'この移動を承認しますか？'**
  String get transferApproveQ;

  /// No description provided for @transferApproved.
  ///
  /// In ja, this message translates to:
  /// **'移動を承認しました'**
  String get transferApproved;

  /// No description provided for @transferReject.
  ///
  /// In ja, this message translates to:
  /// **'却下する'**
  String get transferReject;

  /// No description provided for @transferRejectQ.
  ///
  /// In ja, this message translates to:
  /// **'この移動を却下しますか？'**
  String get transferRejectQ;

  /// No description provided for @transferRejected.
  ///
  /// In ja, this message translates to:
  /// **'移動を却下しました'**
  String get transferRejected;

  /// No description provided for @transferCancelAction.
  ///
  /// In ja, this message translates to:
  /// **'移動を中止'**
  String get transferCancelAction;

  /// No description provided for @transferCancelBody.
  ///
  /// In ja, this message translates to:
  /// **'在庫はまだ動いていないため、中止しても在庫は変わりません。'**
  String get transferCancelBody;

  /// No description provided for @transferCancelled.
  ///
  /// In ja, this message translates to:
  /// **'移動を中止しました'**
  String get transferCancelled;

  /// No description provided for @transferStartPicking.
  ///
  /// In ja, this message translates to:
  /// **'ピッキング開始'**
  String get transferStartPicking;

  /// No description provided for @transferPickQty.
  ///
  /// In ja, this message translates to:
  /// **'ピック数'**
  String get transferPickQty;

  /// No description provided for @transferPickProgress.
  ///
  /// In ja, this message translates to:
  /// **'{picked} / {total} ピック済み'**
  String transferPickProgress(int picked, int total);

  /// No description provided for @transferCompletePicking.
  ///
  /// In ja, this message translates to:
  /// **'出庫を確定'**
  String get transferCompletePicking;

  /// No description provided for @transferCompletePickingBody.
  ///
  /// In ja, this message translates to:
  /// **'{source} の在庫からピック数を引き、輸送中に切り替えます。'**
  String transferCompletePickingBody(String source);

  /// No description provided for @transferPickIncomplete.
  ///
  /// In ja, this message translates to:
  /// **'未ピックの明細があるため出庫を確定できません'**
  String get transferPickIncomplete;

  /// No description provided for @transferStartReceiving.
  ///
  /// In ja, this message translates to:
  /// **'受入を開始'**
  String get transferStartReceiving;

  /// No description provided for @transferReceiveQty.
  ///
  /// In ja, this message translates to:
  /// **'受入数'**
  String get transferReceiveQty;

  /// No description provided for @transferReceiveProgress.
  ///
  /// In ja, this message translates to:
  /// **'{received} / {total} 受入済み'**
  String transferReceiveProgress(int received, int total);

  /// No description provided for @transferCompleteReceiving.
  ///
  /// In ja, this message translates to:
  /// **'受入を確定'**
  String get transferCompleteReceiving;

  /// No description provided for @transferCompleteReceivingBody.
  ///
  /// In ja, this message translates to:
  /// **'{destination} に受入数を加算し、移動を完了します。'**
  String transferCompleteReceivingBody(String destination);

  /// No description provided for @transferReceiveIncomplete.
  ///
  /// In ja, this message translates to:
  /// **'未受入の明細があるため受入を確定できません'**
  String get transferReceiveIncomplete;

  /// No description provided for @transferCompleted.
  ///
  /// In ja, this message translates to:
  /// **'移動が完了しました（{loss}件で数量差異）'**
  String transferCompleted(int loss);

  /// No description provided for @transferPlanned.
  ///
  /// In ja, this message translates to:
  /// **'予定'**
  String get transferPlanned;

  /// No description provided for @transferLineProductName.
  ///
  /// In ja, this message translates to:
  /// **'商品名（任意）'**
  String get transferLineProductName;

  /// No description provided for @featTransfer.
  ///
  /// In ja, this message translates to:
  /// **'倉庫間移動'**
  String get featTransfer;

  /// No description provided for @featTransferDesc.
  ///
  /// In ja, this message translates to:
  /// **'倉庫間で在庫を移動'**
  String get featTransferDesc;

  /// No description provided for @auditTitle.
  ///
  /// In ja, this message translates to:
  /// **'監査ログ'**
  String get auditTitle;

  /// No description provided for @auditEmpty.
  ///
  /// In ja, this message translates to:
  /// **'監査ログはまだありません'**
  String get auditEmpty;

  /// No description provided for @auditEmptyBody.
  ///
  /// In ja, this message translates to:
  /// **'承認・却下・取消などの操作がここに記録されます。'**
  String get auditEmptyBody;

  /// No description provided for @auditExport.
  ///
  /// In ja, this message translates to:
  /// **'CSVを書き出す'**
  String get auditExport;

  /// No description provided for @auditExported.
  ///
  /// In ja, this message translates to:
  /// **'CSVを保存しました'**
  String get auditExported;

  /// No description provided for @auditExportFailed.
  ///
  /// In ja, this message translates to:
  /// **'CSVの書き出しに失敗しました'**
  String get auditExportFailed;

  /// No description provided for @auditEntity.
  ///
  /// In ja, this message translates to:
  /// **'対象'**
  String get auditEntity;

  /// No description provided for @auditActor.
  ///
  /// In ja, this message translates to:
  /// **'実行者'**
  String get auditActor;

  /// No description provided for @auditActorSystem.
  ///
  /// In ja, this message translates to:
  /// **'システム'**
  String get auditActorSystem;

  /// No description provided for @csvExportTitle.
  ///
  /// In ja, this message translates to:
  /// **'CSVエクスポート'**
  String get csvExportTitle;

  /// No description provided for @featAuditLog.
  ///
  /// In ja, this message translates to:
  /// **'監査ログ'**
  String get featAuditLog;

  /// No description provided for @featAuditLogDesc.
  ///
  /// In ja, this message translates to:
  /// **'操作履歴をCSVで確認'**
  String get featAuditLogDesc;

  /// No description provided for @featUserManagement.
  ///
  /// In ja, this message translates to:
  /// **'ユーザー管理'**
  String get featUserManagement;

  /// No description provided for @featUserManagementDesc.
  ///
  /// In ja, this message translates to:
  /// **'サインイン済みのメンバーに権限ロールを割り当て'**
  String get featUserManagementDesc;

  /// No description provided for @featConnectors.
  ///
  /// In ja, this message translates to:
  /// **'コネクタ'**
  String get featConnectors;

  /// No description provided for @featConnectorsDesc.
  ///
  /// In ja, this message translates to:
  /// **'将来の外部連携のために登録された外部システム'**
  String get featConnectorsDesc;

  /// No description provided for @featAiReview.
  ///
  /// In ja, this message translates to:
  /// **'AIレビュー'**
  String get featAiReview;

  /// No description provided for @featAiReviewDesc.
  ///
  /// In ja, this message translates to:
  /// **'AIの抽出結果を反映前に承認・却下'**
  String get featAiReviewDesc;

  /// No description provided for @featProducts.
  ///
  /// In ja, this message translates to:
  /// **'商品ライブラリー'**
  String get featProducts;

  /// No description provided for @featProductsDesc.
  ///
  /// In ja, this message translates to:
  /// **'実際に扱う商品。在庫・発注・入荷・出荷はここにつながります'**
  String get featProductsDesc;

  /// Home menu: unlinked_jan_codes / product_id_coverage (0058) — the registration worklist.
  ///
  /// In ja, this message translates to:
  /// **'未紐付けJANコード'**
  String get featUnlinkedJan;

  /// Home menu description for the unlinked JAN worklist.
  ///
  /// In ja, this message translates to:
  /// **'商品が登録されていないJANコードの一覧'**
  String get featUnlinkedJanDesc;

  /// Unlinked JAN screen title.
  ///
  /// In ja, this message translates to:
  /// **'未紐付けJANコード'**
  String get unlinkedJanTitle;

  /// Unlinked JAN screen: the coverage summary line.
  ///
  /// In ja, this message translates to:
  /// **'{linked} / {rows} 件が紐付け済み'**
  String unlinkedJanCoverage(int linked, int rows);

  /// Unlinked JAN screen: product_id_coverage.ready_to_switch is true.
  ///
  /// In ja, this message translates to:
  /// **'すべて商品に紐付いています'**
  String get unlinkedJanReady;

  /// Unlinked JAN screen: empty state (the healthy state).
  ///
  /// In ja, this message translates to:
  /// **'未紐付けのJANコードはありません'**
  String get unlinkedJanEmpty;

  /// Unlinked JAN screen: empty state body.
  ///
  /// In ja, this message translates to:
  /// **'在庫・入荷・出荷などの記録は、すべて商品ライブラリーに紐付いています。'**
  String get unlinkedJanEmptyBody;

  /// Unlinked JAN screen: total row count for one JAN code.
  ///
  /// In ja, this message translates to:
  /// **'{qty} 件'**
  String unlinkedJanRows(int qty);

  /// Unlinked JAN screen: no product_name was ever recorded alongside this code.
  ///
  /// In ja, this message translates to:
  /// **'名称不明'**
  String get unlinkedJanSeenAsUnknown;

  /// No description provided for @featPurchaseOrders.
  ///
  /// In ja, this message translates to:
  /// **'発注'**
  String get featPurchaseOrders;

  /// No description provided for @featPurchaseOrdersDesc.
  ///
  /// In ja, this message translates to:
  /// **'仕入先への発注を作成・承認・管理'**
  String get featPurchaseOrdersDesc;

  /// No description provided for @featSalesOrders.
  ///
  /// In ja, this message translates to:
  /// **'受注'**
  String get featSalesOrders;

  /// No description provided for @featSalesOrdersDesc.
  ///
  /// In ja, this message translates to:
  /// **'顧客からの受注を作成・承認・管理'**
  String get featSalesOrdersDesc;

  /// No description provided for @featPartners.
  ///
  /// In ja, this message translates to:
  /// **'取引先'**
  String get featPartners;

  /// No description provided for @featPartnersDesc.
  ///
  /// In ja, this message translates to:
  /// **'仕入先・顧客の連絡先や取引条件を管理'**
  String get featPartnersDesc;

  /// No description provided for @featWorkOrders.
  ///
  /// In ja, this message translates to:
  /// **'作業指示'**
  String get featWorkOrders;

  /// No description provided for @featWorkOrdersDesc.
  ///
  /// In ja, this message translates to:
  /// **'部材を消費して完成品を作るキッティング・組立作業'**
  String get featWorkOrdersDesc;

  /// No description provided for @featReports.
  ///
  /// In ja, this message translates to:
  /// **'レポート作成'**
  String get featReports;

  /// No description provided for @featReportsDesc.
  ///
  /// In ja, this message translates to:
  /// **'データを選んで絞り込み、レポートとして保存'**
  String get featReportsDesc;

  /// No description provided for @reportTitle.
  ///
  /// In ja, this message translates to:
  /// **'レポート作成'**
  String get reportTitle;

  /// No description provided for @reportSource.
  ///
  /// In ja, this message translates to:
  /// **'データソース'**
  String get reportSource;

  /// No description provided for @reportSourceStockMovements.
  ///
  /// In ja, this message translates to:
  /// **'在庫履歴'**
  String get reportSourceStockMovements;

  /// No description provided for @reportSourceInspections.
  ///
  /// In ja, this message translates to:
  /// **'検品'**
  String get reportSourceInspections;

  /// No description provided for @reportSourceTransfers.
  ///
  /// In ja, this message translates to:
  /// **'倉庫間移動'**
  String get reportSourceTransfers;

  /// No description provided for @reportSourceShipments.
  ///
  /// In ja, this message translates to:
  /// **'出庫'**
  String get reportSourceShipments;

  /// No description provided for @reportSourcePurchaseOrders.
  ///
  /// In ja, this message translates to:
  /// **'発注'**
  String get reportSourcePurchaseOrders;

  /// No description provided for @reportSourceSalesOrders.
  ///
  /// In ja, this message translates to:
  /// **'受注'**
  String get reportSourceSalesOrders;

  /// No description provided for @reportSourceWorkOrders.
  ///
  /// In ja, this message translates to:
  /// **'作業指示'**
  String get reportSourceWorkOrders;

  /// No description provided for @reportSourceAuditLog.
  ///
  /// In ja, this message translates to:
  /// **'監査ログ'**
  String get reportSourceAuditLog;

  /// No description provided for @reportSourceProducts.
  ///
  /// In ja, this message translates to:
  /// **'商品ライブラリー'**
  String get reportSourceProducts;

  /// No description provided for @reportWarehouse.
  ///
  /// In ja, this message translates to:
  /// **'倉庫'**
  String get reportWarehouse;

  /// No description provided for @reportAllWarehouses.
  ///
  /// In ja, this message translates to:
  /// **'すべての倉庫'**
  String get reportAllWarehouses;

  /// No description provided for @reportCountry.
  ///
  /// In ja, this message translates to:
  /// **'国'**
  String get reportCountry;

  /// No description provided for @reportAllCountries.
  ///
  /// In ja, this message translates to:
  /// **'すべての国（行ごとに国を表示）'**
  String get reportAllCountries;

  /// No description provided for @reportFilterStatus.
  ///
  /// In ja, this message translates to:
  /// **'ステータス（任意）'**
  String get reportFilterStatus;

  /// No description provided for @reportFilterJan.
  ///
  /// In ja, this message translates to:
  /// **'JANコード（任意）'**
  String get reportFilterJan;

  /// No description provided for @reportFilterCategory.
  ///
  /// In ja, this message translates to:
  /// **'カテゴリ（任意）'**
  String get reportFilterCategory;

  /// No description provided for @reportDateFrom.
  ///
  /// In ja, this message translates to:
  /// **'開始日'**
  String get reportDateFrom;

  /// No description provided for @reportDateTo.
  ///
  /// In ja, this message translates to:
  /// **'終了日'**
  String get reportDateTo;

  /// No description provided for @reportRun.
  ///
  /// In ja, this message translates to:
  /// **'実行'**
  String get reportRun;

  /// No description provided for @reportSave.
  ///
  /// In ja, this message translates to:
  /// **'保存'**
  String get reportSave;

  /// No description provided for @reportSaveTitle.
  ///
  /// In ja, this message translates to:
  /// **'レポートを保存'**
  String get reportSaveTitle;

  /// No description provided for @reportName.
  ///
  /// In ja, this message translates to:
  /// **'レポート名'**
  String get reportName;

  /// No description provided for @reportSaved.
  ///
  /// In ja, this message translates to:
  /// **'レポートを保存しました'**
  String get reportSaved;

  /// No description provided for @reportEmpty.
  ///
  /// In ja, this message translates to:
  /// **'該当するデータがありません'**
  String get reportEmpty;

  /// No description provided for @reportRowCount.
  ///
  /// In ja, this message translates to:
  /// **'{count} 件'**
  String reportRowCount(int count);

  /// No description provided for @reportSavedTitle.
  ///
  /// In ja, this message translates to:
  /// **'保存済みレポート'**
  String get reportSavedTitle;

  /// No description provided for @reportSavedEmpty.
  ///
  /// In ja, this message translates to:
  /// **'保存済みのレポートはまだありません'**
  String get reportSavedEmpty;

  /// No description provided for @woTitle.
  ///
  /// In ja, this message translates to:
  /// **'作業指示'**
  String get woTitle;

  /// No description provided for @woNew.
  ///
  /// In ja, this message translates to:
  /// **'作業指示を作成'**
  String get woNew;

  /// No description provided for @woEmpty.
  ///
  /// In ja, this message translates to:
  /// **'作業指示がまだありません'**
  String get woEmpty;

  /// No description provided for @woEmptyBody.
  ///
  /// In ja, this message translates to:
  /// **'右下のボタンから作業指示を作成できます。'**
  String get woEmptyBody;

  /// No description provided for @woNeedsWarehouse.
  ///
  /// In ja, this message translates to:
  /// **'倉庫がありません'**
  String get woNeedsWarehouse;

  /// No description provided for @woWarehouse.
  ///
  /// In ja, this message translates to:
  /// **'作業倉庫'**
  String get woWarehouse;

  /// No description provided for @woOutputTitle.
  ///
  /// In ja, this message translates to:
  /// **'完成品'**
  String get woOutputTitle;

  /// No description provided for @woOutputQuantity.
  ///
  /// In ja, this message translates to:
  /// **'完成数量'**
  String get woOutputQuantity;

  /// No description provided for @woOutputRequired.
  ///
  /// In ja, this message translates to:
  /// **'完成品のJANコードと数量を入力してください'**
  String get woOutputRequired;

  /// No description provided for @woComponentsTitle.
  ///
  /// In ja, this message translates to:
  /// **'部材'**
  String get woComponentsTitle;

  /// No description provided for @woAddComponent.
  ///
  /// In ja, this message translates to:
  /// **'部材を追加'**
  String get woAddComponent;

  /// No description provided for @woComponentRequired.
  ///
  /// In ja, this message translates to:
  /// **'部材を1件以上追加してください'**
  String get woComponentRequired;

  /// No description provided for @woComponentQuantity.
  ///
  /// In ja, this message translates to:
  /// **'必要数量'**
  String get woComponentQuantity;

  /// No description provided for @woComponentCount.
  ///
  /// In ja, this message translates to:
  /// **'{count} 部材'**
  String woComponentCount(int count);

  /// No description provided for @woNote.
  ///
  /// In ja, this message translates to:
  /// **'備考'**
  String get woNote;

  /// No description provided for @woCreate.
  ///
  /// In ja, this message translates to:
  /// **'作成'**
  String get woCreate;

  /// No description provided for @woLineJan.
  ///
  /// In ja, this message translates to:
  /// **'JANコード'**
  String get woLineJan;

  /// No description provided for @woLineProductName.
  ///
  /// In ja, this message translates to:
  /// **'商品名'**
  String get woLineProductName;

  /// No description provided for @woStart.
  ///
  /// In ja, this message translates to:
  /// **'作業開始'**
  String get woStart;

  /// No description provided for @woStarted.
  ///
  /// In ja, this message translates to:
  /// **'作業を開始しました'**
  String get woStarted;

  /// No description provided for @woComplete.
  ///
  /// In ja, this message translates to:
  /// **'完了にする'**
  String get woComplete;

  /// No description provided for @woCompleteQ.
  ///
  /// In ja, this message translates to:
  /// **'この作業指示を完了にしますか？部材の在庫が消費され、完成品の在庫が増加します。'**
  String get woCompleteQ;

  /// No description provided for @woCompleted.
  ///
  /// In ja, this message translates to:
  /// **'作業指示を完了しました'**
  String get woCompleted;

  /// No description provided for @woCancelAction.
  ///
  /// In ja, this message translates to:
  /// **'作業指示を取消'**
  String get woCancelAction;

  /// No description provided for @woCancelBody.
  ///
  /// In ja, this message translates to:
  /// **'この作業指示を取り消しますか？'**
  String get woCancelBody;

  /// No description provided for @woCancelled.
  ///
  /// In ja, this message translates to:
  /// **'作業指示を取り消しました'**
  String get woCancelled;

  /// No description provided for @woStatusDraft.
  ///
  /// In ja, this message translates to:
  /// **'下書き'**
  String get woStatusDraft;

  /// No description provided for @woStatusInProgress.
  ///
  /// In ja, this message translates to:
  /// **'作業中'**
  String get woStatusInProgress;

  /// No description provided for @woStatusCompleted.
  ///
  /// In ja, this message translates to:
  /// **'完了'**
  String get woStatusCompleted;

  /// No description provided for @woStatusCancelled.
  ///
  /// In ja, this message translates to:
  /// **'取消'**
  String get woStatusCancelled;

  /// No description provided for @partnersTitle.
  ///
  /// In ja, this message translates to:
  /// **'取引先'**
  String get partnersTitle;

  /// No description provided for @partnersSearchHint.
  ///
  /// In ja, this message translates to:
  /// **'取引先名またはコードで検索'**
  String get partnersSearchHint;

  /// No description provided for @partnersEmpty.
  ///
  /// In ja, this message translates to:
  /// **'取引先がまだありません'**
  String get partnersEmpty;

  /// No description provided for @partnersEmptyBody.
  ///
  /// In ja, this message translates to:
  /// **'右下の＋から取引先を登録できます。'**
  String get partnersEmptyBody;

  /// No description provided for @partnerKindAll.
  ///
  /// In ja, this message translates to:
  /// **'すべて'**
  String get partnerKindAll;

  /// No description provided for @partnerKindSupplier.
  ///
  /// In ja, this message translates to:
  /// **'仕入先'**
  String get partnerKindSupplier;

  /// No description provided for @partnerKindCustomer.
  ///
  /// In ja, this message translates to:
  /// **'顧客'**
  String get partnerKindCustomer;

  /// No description provided for @partnerKindBoth.
  ///
  /// In ja, this message translates to:
  /// **'仕入先/顧客'**
  String get partnerKindBoth;

  /// No description provided for @partnerNewTitle.
  ///
  /// In ja, this message translates to:
  /// **'取引先を登録'**
  String get partnerNewTitle;

  /// No description provided for @partnerEditTitle.
  ///
  /// In ja, this message translates to:
  /// **'取引先を編集'**
  String get partnerEditTitle;

  /// No description provided for @partnerName.
  ///
  /// In ja, this message translates to:
  /// **'取引先名'**
  String get partnerName;

  /// No description provided for @partnerCode.
  ///
  /// In ja, this message translates to:
  /// **'コード'**
  String get partnerCode;

  /// No description provided for @partnerContactName.
  ///
  /// In ja, this message translates to:
  /// **'担当者名'**
  String get partnerContactName;

  /// No description provided for @partnerPhone.
  ///
  /// In ja, this message translates to:
  /// **'電話番号'**
  String get partnerPhone;

  /// No description provided for @partnerEmail.
  ///
  /// In ja, this message translates to:
  /// **'メールアドレス'**
  String get partnerEmail;

  /// No description provided for @partnerAddress.
  ///
  /// In ja, this message translates to:
  /// **'住所'**
  String get partnerAddress;

  /// No description provided for @partnerPaymentTerms.
  ///
  /// In ja, this message translates to:
  /// **'取引条件'**
  String get partnerPaymentTerms;

  /// No description provided for @partnerNotes.
  ///
  /// In ja, this message translates to:
  /// **'備考'**
  String get partnerNotes;

  /// No description provided for @partnerSave.
  ///
  /// In ja, this message translates to:
  /// **'保存'**
  String get partnerSave;

  /// No description provided for @partnerValidationRequired.
  ///
  /// In ja, this message translates to:
  /// **'取引先名を入力してください'**
  String get partnerValidationRequired;

  /// No description provided for @soTitle.
  ///
  /// In ja, this message translates to:
  /// **'受注'**
  String get soTitle;

  /// No description provided for @soNew.
  ///
  /// In ja, this message translates to:
  /// **'受注を作成'**
  String get soNew;

  /// No description provided for @soEmpty.
  ///
  /// In ja, this message translates to:
  /// **'受注がまだありません'**
  String get soEmpty;

  /// No description provided for @soEmptyBody.
  ///
  /// In ja, this message translates to:
  /// **'右下のボタンから受注を作成できます。'**
  String get soEmptyBody;

  /// No description provided for @soNeedsWarehouse.
  ///
  /// In ja, this message translates to:
  /// **'倉庫がありません'**
  String get soNeedsWarehouse;

  /// No description provided for @soCustomerName.
  ///
  /// In ja, this message translates to:
  /// **'顧客名'**
  String get soCustomerName;

  /// No description provided for @soWarehouse.
  ///
  /// In ja, this message translates to:
  /// **'出庫倉庫'**
  String get soWarehouse;

  /// No description provided for @soRequestedShipDate.
  ///
  /// In ja, this message translates to:
  /// **'出荷希望日'**
  String get soRequestedShipDate;

  /// No description provided for @soLinesTitle.
  ///
  /// In ja, this message translates to:
  /// **'明細'**
  String get soLinesTitle;

  /// No description provided for @soAddLine.
  ///
  /// In ja, this message translates to:
  /// **'明細を追加'**
  String get soAddLine;

  /// No description provided for @soNote.
  ///
  /// In ja, this message translates to:
  /// **'備考'**
  String get soNote;

  /// No description provided for @soCustomerRequired.
  ///
  /// In ja, this message translates to:
  /// **'顧客名を入力してください'**
  String get soCustomerRequired;

  /// No description provided for @soLineRequired.
  ///
  /// In ja, this message translates to:
  /// **'明細を1件以上追加してください'**
  String get soLineRequired;

  /// No description provided for @soCreate.
  ///
  /// In ja, this message translates to:
  /// **'作成'**
  String get soCreate;

  /// No description provided for @soLineJan.
  ///
  /// In ja, this message translates to:
  /// **'JANコード'**
  String get soLineJan;

  /// No description provided for @soLineProductName.
  ///
  /// In ja, this message translates to:
  /// **'商品名'**
  String get soLineProductName;

  /// No description provided for @soLineQuantity.
  ///
  /// In ja, this message translates to:
  /// **'数量'**
  String get soLineQuantity;

  /// No description provided for @soLineUnitPrice.
  ///
  /// In ja, this message translates to:
  /// **'単価'**
  String get soLineUnitPrice;

  /// No description provided for @soTotalAmount.
  ///
  /// In ja, this message translates to:
  /// **'金額'**
  String get soTotalAmount;

  /// No description provided for @soSubmit.
  ///
  /// In ja, this message translates to:
  /// **'提出'**
  String get soSubmit;

  /// No description provided for @soSubmitted.
  ///
  /// In ja, this message translates to:
  /// **'受注を提出しました'**
  String get soSubmitted;

  /// No description provided for @soApprove.
  ///
  /// In ja, this message translates to:
  /// **'承認'**
  String get soApprove;

  /// No description provided for @soApproveQ.
  ///
  /// In ja, this message translates to:
  /// **'この受注を承認しますか？'**
  String get soApproveQ;

  /// No description provided for @soApproved.
  ///
  /// In ja, this message translates to:
  /// **'受注を承認しました'**
  String get soApproved;

  /// No description provided for @soReject.
  ///
  /// In ja, this message translates to:
  /// **'却下'**
  String get soReject;

  /// No description provided for @soRejectQ.
  ///
  /// In ja, this message translates to:
  /// **'この受注を却下しますか？'**
  String get soRejectQ;

  /// No description provided for @soRejected.
  ///
  /// In ja, this message translates to:
  /// **'受注を却下しました'**
  String get soRejected;

  /// No description provided for @soCancelAction.
  ///
  /// In ja, this message translates to:
  /// **'受注を取消'**
  String get soCancelAction;

  /// No description provided for @soCancelBody.
  ///
  /// In ja, this message translates to:
  /// **'この受注を取り消しますか？'**
  String get soCancelBody;

  /// No description provided for @soCancelled.
  ///
  /// In ja, this message translates to:
  /// **'受注を取り消しました'**
  String get soCancelled;

  /// No description provided for @soComplete.
  ///
  /// In ja, this message translates to:
  /// **'完了にする'**
  String get soComplete;

  /// No description provided for @soCompleteQ.
  ///
  /// In ja, this message translates to:
  /// **'この受注を完了にしますか？在庫は移動しません。'**
  String get soCompleteQ;

  /// No description provided for @soCompleted.
  ///
  /// In ja, this message translates to:
  /// **'受注を完了にしました'**
  String get soCompleted;

  /// No description provided for @soStatusDraft.
  ///
  /// In ja, this message translates to:
  /// **'下書き'**
  String get soStatusDraft;

  /// No description provided for @soStatusSubmitted.
  ///
  /// In ja, this message translates to:
  /// **'提出済み'**
  String get soStatusSubmitted;

  /// No description provided for @soStatusApproved.
  ///
  /// In ja, this message translates to:
  /// **'承認済み'**
  String get soStatusApproved;

  /// No description provided for @soStatusRejected.
  ///
  /// In ja, this message translates to:
  /// **'却下'**
  String get soStatusRejected;

  /// No description provided for @soStatusCancelled.
  ///
  /// In ja, this message translates to:
  /// **'取消'**
  String get soStatusCancelled;

  /// No description provided for @soStatusCompleted.
  ///
  /// In ja, this message translates to:
  /// **'完了'**
  String get soStatusCompleted;

  /// No description provided for @poTitle.
  ///
  /// In ja, this message translates to:
  /// **'発注'**
  String get poTitle;

  /// No description provided for @poNew.
  ///
  /// In ja, this message translates to:
  /// **'発注を作成'**
  String get poNew;

  /// No description provided for @poEmpty.
  ///
  /// In ja, this message translates to:
  /// **'発注がまだありません'**
  String get poEmpty;

  /// No description provided for @poEmptyBody.
  ///
  /// In ja, this message translates to:
  /// **'右下のボタンから発注を作成できます。'**
  String get poEmptyBody;

  /// No description provided for @poNeedsWarehouse.
  ///
  /// In ja, this message translates to:
  /// **'倉庫がありません'**
  String get poNeedsWarehouse;

  /// No description provided for @poSupplierName.
  ///
  /// In ja, this message translates to:
  /// **'仕入先名'**
  String get poSupplierName;

  /// No description provided for @poWarehouse.
  ///
  /// In ja, this message translates to:
  /// **'入庫倉庫'**
  String get poWarehouse;

  /// No description provided for @poExpectedDate.
  ///
  /// In ja, this message translates to:
  /// **'納期予定'**
  String get poExpectedDate;

  /// No description provided for @poLinesTitle.
  ///
  /// In ja, this message translates to:
  /// **'明細'**
  String get poLinesTitle;

  /// No description provided for @poAddLine.
  ///
  /// In ja, this message translates to:
  /// **'明細を追加'**
  String get poAddLine;

  /// No description provided for @poNote.
  ///
  /// In ja, this message translates to:
  /// **'備考'**
  String get poNote;

  /// No description provided for @poSupplierRequired.
  ///
  /// In ja, this message translates to:
  /// **'仕入先名を入力してください'**
  String get poSupplierRequired;

  /// No description provided for @poLineRequired.
  ///
  /// In ja, this message translates to:
  /// **'明細を1件以上追加してください'**
  String get poLineRequired;

  /// No description provided for @poCreate.
  ///
  /// In ja, this message translates to:
  /// **'作成'**
  String get poCreate;

  /// No description provided for @poLineJan.
  ///
  /// In ja, this message translates to:
  /// **'JANコード'**
  String get poLineJan;

  /// No description provided for @poLineProductName.
  ///
  /// In ja, this message translates to:
  /// **'商品名'**
  String get poLineProductName;

  /// No description provided for @poLineQuantity.
  ///
  /// In ja, this message translates to:
  /// **'数量'**
  String get poLineQuantity;

  /// No description provided for @poLineUnitPrice.
  ///
  /// In ja, this message translates to:
  /// **'単価'**
  String get poLineUnitPrice;

  /// No description provided for @poTotalAmount.
  ///
  /// In ja, this message translates to:
  /// **'金額'**
  String get poTotalAmount;

  /// No description provided for @poSubmit.
  ///
  /// In ja, this message translates to:
  /// **'提出'**
  String get poSubmit;

  /// No description provided for @poSubmitted.
  ///
  /// In ja, this message translates to:
  /// **'発注を提出しました'**
  String get poSubmitted;

  /// No description provided for @poApprove.
  ///
  /// In ja, this message translates to:
  /// **'承認'**
  String get poApprove;

  /// No description provided for @poApproveQ.
  ///
  /// In ja, this message translates to:
  /// **'この発注を承認しますか？'**
  String get poApproveQ;

  /// No description provided for @poApproved.
  ///
  /// In ja, this message translates to:
  /// **'発注を承認しました'**
  String get poApproved;

  /// No description provided for @poReject.
  ///
  /// In ja, this message translates to:
  /// **'却下'**
  String get poReject;

  /// No description provided for @poRejectQ.
  ///
  /// In ja, this message translates to:
  /// **'この発注を却下しますか？'**
  String get poRejectQ;

  /// No description provided for @poRejected.
  ///
  /// In ja, this message translates to:
  /// **'発注を却下しました'**
  String get poRejected;

  /// No description provided for @poCancelAction.
  ///
  /// In ja, this message translates to:
  /// **'発注を取消'**
  String get poCancelAction;

  /// No description provided for @poCancelBody.
  ///
  /// In ja, this message translates to:
  /// **'この発注を取り消しますか？'**
  String get poCancelBody;

  /// No description provided for @poCancelled.
  ///
  /// In ja, this message translates to:
  /// **'発注を取り消しました'**
  String get poCancelled;

  /// No description provided for @poComplete.
  ///
  /// In ja, this message translates to:
  /// **'完了にする'**
  String get poComplete;

  /// No description provided for @poCompleteQ.
  ///
  /// In ja, this message translates to:
  /// **'この発注を完了にしますか？在庫は移動しません。'**
  String get poCompleteQ;

  /// No description provided for @poCompleted.
  ///
  /// In ja, this message translates to:
  /// **'発注を完了にしました'**
  String get poCompleted;

  /// No description provided for @poCreateDeliveryPlan.
  ///
  /// In ja, this message translates to:
  /// **'入荷予定を作成'**
  String get poCreateDeliveryPlan;

  /// No description provided for @poCreateDeliveryPlanQ.
  ///
  /// In ja, this message translates to:
  /// **'この発注から入荷予定を作成しますか？'**
  String get poCreateDeliveryPlanQ;

  /// Success message after creating a delivery plan from a purchase order.
  ///
  /// In ja, this message translates to:
  /// **'入荷予定を作成しました（明細 {lines} 件）'**
  String poDeliveryPlanCreated(int lines);

  /// No description provided for @poOpenDeliveryPlan.
  ///
  /// In ja, this message translates to:
  /// **'入荷予定を開く'**
  String get poOpenDeliveryPlan;

  /// No description provided for @poStatusDraft.
  ///
  /// In ja, this message translates to:
  /// **'下書き'**
  String get poStatusDraft;

  /// No description provided for @poStatusSubmitted.
  ///
  /// In ja, this message translates to:
  /// **'提出済み'**
  String get poStatusSubmitted;

  /// No description provided for @poStatusApproved.
  ///
  /// In ja, this message translates to:
  /// **'承認済み'**
  String get poStatusApproved;

  /// No description provided for @poStatusRejected.
  ///
  /// In ja, this message translates to:
  /// **'却下'**
  String get poStatusRejected;

  /// No description provided for @poStatusCancelled.
  ///
  /// In ja, this message translates to:
  /// **'取消'**
  String get poStatusCancelled;

  /// No description provided for @poStatusCompleted.
  ///
  /// In ja, this message translates to:
  /// **'完了'**
  String get poStatusCompleted;

  /// No description provided for @productsTitle.
  ///
  /// In ja, this message translates to:
  /// **'商品ライブラリー'**
  String get productsTitle;

  /// No description provided for @productsShowInactive.
  ///
  /// In ja, this message translates to:
  /// **'休眠・提供終了も表示'**
  String get productsShowInactive;

  /// No description provided for @productsSearchHint.
  ///
  /// In ja, this message translates to:
  /// **'商品名またはJANコードで検索'**
  String get productsSearchHint;

  /// No description provided for @productsEmpty.
  ///
  /// In ja, this message translates to:
  /// **'商品がまだありません'**
  String get productsEmpty;

  /// No description provided for @productsEmptyBody.
  ///
  /// In ja, this message translates to:
  /// **'「ファイルから登録」（自社のExcelなど）、「価格台帳から取り込む」、または右下の＋から1件ずつ登録できます。'**
  String get productsEmptyBody;

  /// No description provided for @productActive.
  ///
  /// In ja, this message translates to:
  /// **'有効'**
  String get productActive;

  /// No description provided for @productInactive.
  ///
  /// In ja, this message translates to:
  /// **'無効'**
  String get productInactive;

  /// No description provided for @productDeactivateQ.
  ///
  /// In ja, this message translates to:
  /// **'この商品を休眠にしますか？'**
  String get productDeactivateQ;

  /// No description provided for @productDeactivateBody.
  ///
  /// In ja, this message translates to:
  /// **'休眠にすると、入荷・出荷などの操作でこの商品を選べなくなります。いつでも取扱中に戻せます。'**
  String get productDeactivateBody;

  /// No description provided for @productDeactivateAction.
  ///
  /// In ja, this message translates to:
  /// **'休眠にする'**
  String get productDeactivateAction;

  /// No description provided for @productNewTitle.
  ///
  /// In ja, this message translates to:
  /// **'商品を登録'**
  String get productNewTitle;

  /// No description provided for @productEditTitle.
  ///
  /// In ja, this message translates to:
  /// **'商品を編集'**
  String get productEditTitle;

  /// No description provided for @productJanCode.
  ///
  /// In ja, this message translates to:
  /// **'JANコード'**
  String get productJanCode;

  /// No description provided for @productName.
  ///
  /// In ja, this message translates to:
  /// **'商品名'**
  String get productName;

  /// No description provided for @productCategory.
  ///
  /// In ja, this message translates to:
  /// **'カテゴリ'**
  String get productCategory;

  /// No description provided for @productPrice.
  ///
  /// In ja, this message translates to:
  /// **'価格'**
  String get productPrice;

  /// No description provided for @productSave.
  ///
  /// In ja, this message translates to:
  /// **'保存'**
  String get productSave;

  /// No description provided for @productValidationRequired.
  ///
  /// In ja, this message translates to:
  /// **'JANコードと商品名を入力してください'**
  String get productValidationRequired;

  /// No description provided for @dashTodayTasks.
  ///
  /// In ja, this message translates to:
  /// **'今日の作業'**
  String get dashTodayTasks;

  /// No description provided for @taskPackingWait.
  ///
  /// In ja, this message translates to:
  /// **'梱包待ち'**
  String get taskPackingWait;

  /// No description provided for @taskShippingWait.
  ///
  /// In ja, this message translates to:
  /// **'出荷待ち'**
  String get taskShippingWait;

  /// No description provided for @searchTitle.
  ///
  /// In ja, this message translates to:
  /// **'検索'**
  String get searchTitle;

  /// No description provided for @searchHint.
  ///
  /// In ja, this message translates to:
  /// **'JAN・伝票番号・取引先名で検索'**
  String get searchHint;

  /// No description provided for @searchNoQuery.
  ///
  /// In ja, this message translates to:
  /// **'入荷・出荷・移動の番号や商品名で横断検索できます。'**
  String get searchNoQuery;

  /// No description provided for @searchEmpty.
  ///
  /// In ja, this message translates to:
  /// **'一致する結果がありません'**
  String get searchEmpty;

  /// No description provided for @searchEmptyBody.
  ///
  /// In ja, this message translates to:
  /// **'別のキーワードでお試しください。'**
  String get searchEmptyBody;

  /// No description provided for @searchKindStock.
  ///
  /// In ja, this message translates to:
  /// **'商品'**
  String get searchKindStock;

  /// No description provided for @searchKindDelivery.
  ///
  /// In ja, this message translates to:
  /// **'入荷予定'**
  String get searchKindDelivery;

  /// No description provided for @searchKindShipment.
  ///
  /// In ja, this message translates to:
  /// **'出荷'**
  String get searchKindShipment;

  /// No description provided for @searchKindPickList.
  ///
  /// In ja, this message translates to:
  /// **'ピッキング'**
  String get searchKindPickList;

  /// No description provided for @searchKindTransfer.
  ///
  /// In ja, this message translates to:
  /// **'倉庫間移動'**
  String get searchKindTransfer;

  /// No description provided for @userMgmtTitle.
  ///
  /// In ja, this message translates to:
  /// **'ユーザー管理'**
  String get userMgmtTitle;

  /// No description provided for @userMgmtEmpty.
  ///
  /// In ja, this message translates to:
  /// **'ユーザーがまだいません'**
  String get userMgmtEmpty;

  /// No description provided for @userMgmtEmptyBody.
  ///
  /// In ja, this message translates to:
  /// **'メンバーが初めてサインインすると、ここに表示されます。'**
  String get userMgmtEmptyBody;

  /// No description provided for @userMgmtAddRole.
  ///
  /// In ja, this message translates to:
  /// **'ロールを追加'**
  String get userMgmtAddRole;

  /// No description provided for @userMgmtNoRoles.
  ///
  /// In ja, this message translates to:
  /// **'ロール未割り当て'**
  String get userMgmtNoRoles;

  /// No description provided for @userMgmtAllRolesHeld.
  ///
  /// In ja, this message translates to:
  /// **'このユーザーはすべてのロールを持っています。'**
  String get userMgmtAllRolesHeld;

  /// No description provided for @userMgmtRemoveRoleTitle.
  ///
  /// In ja, this message translates to:
  /// **'ロールを削除しますか？'**
  String get userMgmtRemoveRoleTitle;

  /// No description provided for @userMgmtRemoveRoleBody.
  ///
  /// In ja, this message translates to:
  /// **'{name} から {role} を削除しますか？'**
  String userMgmtRemoveRoleBody(String role, String name);

  /// No description provided for @userMgmtRemoveRoleAction.
  ///
  /// In ja, this message translates to:
  /// **'削除'**
  String get userMgmtRemoveRoleAction;

  /// No description provided for @userMgmtWarehousesLabel.
  ///
  /// In ja, this message translates to:
  /// **'倉庫アクセス'**
  String get userMgmtWarehousesLabel;

  /// No description provided for @userMgmtAddWarehouse.
  ///
  /// In ja, this message translates to:
  /// **'倉庫を追加'**
  String get userMgmtAddWarehouse;

  /// No description provided for @userMgmtNoWarehouses.
  ///
  /// In ja, this message translates to:
  /// **'倉庫が割り当てられていません（管理者は全倉庫、それ以外はどの倉庫にもアクセスできません）'**
  String get userMgmtNoWarehouses;

  /// No description provided for @userMgmtAllWarehousesHeld.
  ///
  /// In ja, this message translates to:
  /// **'このユーザーはすべての倉庫にアクセスできます。'**
  String get userMgmtAllWarehousesHeld;

  /// No description provided for @userMgmtRemoveWarehouseTitle.
  ///
  /// In ja, this message translates to:
  /// **'倉庫アクセスを削除しますか？'**
  String get userMgmtRemoveWarehouseTitle;

  /// No description provided for @userMgmtRemoveWarehouseBody.
  ///
  /// In ja, this message translates to:
  /// **'{name} から {warehouse} を削除しますか？'**
  String userMgmtRemoveWarehouseBody(String warehouse, String name);

  /// No description provided for @userMgmtRemoveWarehouseAction.
  ///
  /// In ja, this message translates to:
  /// **'削除'**
  String get userMgmtRemoveWarehouseAction;

  /// No description provided for @connectorsTitle.
  ///
  /// In ja, this message translates to:
  /// **'コネクタ'**
  String get connectorsTitle;

  /// No description provided for @connectorsEmpty.
  ///
  /// In ja, this message translates to:
  /// **'登録されたコネクタがありません'**
  String get connectorsEmpty;

  /// No description provided for @connectorsEmptyBody.
  ///
  /// In ja, this message translates to:
  /// **'登録された外部システムがここに表示されます。'**
  String get connectorsEmptyBody;

  /// No description provided for @connectorNoAdapterYet.
  ///
  /// In ja, this message translates to:
  /// **'まだ連携処理は実装されていません。この登録だけでは同期は行われません。'**
  String get connectorNoAdapterYet;

  /// No description provided for @connectorEnabled.
  ///
  /// In ja, this message translates to:
  /// **'有効'**
  String get connectorEnabled;

  /// No description provided for @connectorDisabled.
  ///
  /// In ja, this message translates to:
  /// **'無効'**
  String get connectorDisabled;

  /// No description provided for @connectorNeverRun.
  ///
  /// In ja, this message translates to:
  /// **'実行履歴なし'**
  String get connectorNeverRun;

  /// No description provided for @aiReviewTitle.
  ///
  /// In ja, this message translates to:
  /// **'AIレビュー'**
  String get aiReviewTitle;

  /// No description provided for @aiReviewEmpty.
  ///
  /// In ja, this message translates to:
  /// **'レビュー待ちはありません'**
  String get aiReviewEmpty;

  /// No description provided for @aiReviewEmptyBody.
  ///
  /// In ja, this message translates to:
  /// **'AIが抽出した結果は、承認または却下されるまでここに表示されます。'**
  String get aiReviewEmptyBody;

  /// No description provided for @aiReviewLinesCount.
  ///
  /// In ja, this message translates to:
  /// **'{count} 件の明細を抽出'**
  String aiReviewLinesCount(int count);

  /// No description provided for @aiReviewConfidence.
  ///
  /// In ja, this message translates to:
  /// **'信頼度 {percent}%'**
  String aiReviewConfidence(String percent);

  /// No description provided for @aiReviewConfirm.
  ///
  /// In ja, this message translates to:
  /// **'承認'**
  String get aiReviewConfirm;

  /// No description provided for @aiReviewReject.
  ///
  /// In ja, this message translates to:
  /// **'却下'**
  String get aiReviewReject;

  /// No description provided for @aiReviewRejectTitle.
  ///
  /// In ja, this message translates to:
  /// **'この結果を却下しますか？'**
  String get aiReviewRejectTitle;

  /// No description provided for @aiReviewRejectHint.
  ///
  /// In ja, this message translates to:
  /// **'理由（任意）'**
  String get aiReviewRejectHint;

  /// No description provided for @aiReviewConfirmed.
  ///
  /// In ja, this message translates to:
  /// **'承認しました'**
  String get aiReviewConfirmed;

  /// No description provided for @aiReviewRejected.
  ///
  /// In ja, this message translates to:
  /// **'却下しました'**
  String get aiReviewRejected;

  /// No description provided for @featPutaway.
  ///
  /// In ja, this message translates to:
  /// **'棚入れ'**
  String get featPutaway;

  /// No description provided for @featPutawayDesc.
  ///
  /// In ja, this message translates to:
  /// **'入荷済みの在庫をロケーションに割り当てる'**
  String get featPutawayDesc;

  /// No description provided for @nextStepPutaway.
  ///
  /// In ja, this message translates to:
  /// **'棚入れへ'**
  String get nextStepPutaway;

  /// No description provided for @nextStepPacking.
  ///
  /// In ja, this message translates to:
  /// **'梱包へ'**
  String get nextStepPacking;

  /// No description provided for @nextStepInspection.
  ///
  /// In ja, this message translates to:
  /// **'検品へ'**
  String get nextStepInspection;

  /// No description provided for @putawayTitle.
  ///
  /// In ja, this message translates to:
  /// **'棚入れ'**
  String get putawayTitle;

  /// No description provided for @putawayNeedsWarehouse.
  ///
  /// In ja, this message translates to:
  /// **'倉庫を選択してください'**
  String get putawayNeedsWarehouse;

  /// No description provided for @putawayNeedsWarehouseBody.
  ///
  /// In ja, this message translates to:
  /// **'棚入れは1つの倉庫の中で行う作業です。上部の倉庫切替から対象倉庫を選んでください。'**
  String get putawayNeedsWarehouseBody;

  /// No description provided for @putawayLocationsOff.
  ///
  /// In ja, this message translates to:
  /// **'この倉庫はロケーション管理なし'**
  String get putawayLocationsOff;

  /// No description provided for @putawayLocationsOffBody.
  ///
  /// In ja, this message translates to:
  /// **'ロケーション（棚）を使わない倉庫では棚入れ作業はありません。倉庫設定でロケーション管理を有効にすると、この一覧に作業が表示されます。'**
  String get putawayLocationsOffBody;

  /// No description provided for @putawayEmpty.
  ///
  /// In ja, this message translates to:
  /// **'棚入れ待ちはありません'**
  String get putawayEmpty;

  /// No description provided for @putawayEmptyBody.
  ///
  /// In ja, this message translates to:
  /// **'入荷した在庫はすべてロケーションに割り当て済みです。'**
  String get putawayEmptyBody;

  /// No description provided for @putawayPendingCount.
  ///
  /// In ja, this message translates to:
  /// **'{count} 品目'**
  String putawayPendingCount(int count);

  /// No description provided for @putawayQueueHint.
  ///
  /// In ja, this message translates to:
  /// **'入荷済みでロケーション未割り当ての在庫です。タップして棚をスキャンしてください。'**
  String get putawayQueueHint;

  /// No description provided for @putawayPendingLabel.
  ///
  /// In ja, this message translates to:
  /// **'棚入れ待ち'**
  String get putawayPendingLabel;

  /// No description provided for @putawayNoSuggestion.
  ///
  /// In ja, this message translates to:
  /// **'推奨ロケーションなし'**
  String get putawayNoSuggestion;

  /// No description provided for @putawaySuggested.
  ///
  /// In ja, this message translates to:
  /// **'推奨: {code}'**
  String putawaySuggested(String code);

  /// No description provided for @putawayScanLocation.
  ///
  /// In ja, this message translates to:
  /// **'ロケーションをスキャン'**
  String get putawayScanLocation;

  /// No description provided for @putawayScanLocationHint.
  ///
  /// In ja, this message translates to:
  /// **'棚のバーコードをスキャン'**
  String get putawayScanLocationHint;

  /// No description provided for @putawayBinNotFound.
  ///
  /// In ja, this message translates to:
  /// **'この倉庫に「{code}」というロケーションはありません'**
  String putawayBinNotFound(String code);

  /// No description provided for @putawayBinInactive.
  ///
  /// In ja, this message translates to:
  /// **'{code} は使用停止中のロケーションです'**
  String putawayBinInactive(String code);

  /// No description provided for @putawayBinCurrent.
  ///
  /// In ja, this message translates to:
  /// **'現在の在庫'**
  String get putawayBinCurrent;

  /// No description provided for @putawayBinEmpty.
  ///
  /// In ja, this message translates to:
  /// **'空です'**
  String get putawayBinEmpty;

  /// No description provided for @putawayThisTime.
  ///
  /// In ja, this message translates to:
  /// **'今回入れる数量'**
  String get putawayThisTime;

  /// No description provided for @putawayOfPending.
  ///
  /// In ja, this message translates to:
  /// **'/ 残 {pending}'**
  String putawayOfPending(int pending);

  /// No description provided for @putawayQuantityRequired.
  ///
  /// In ja, this message translates to:
  /// **'数量を1以上で入力してください'**
  String get putawayQuantityRequired;

  /// No description provided for @putawayQuantityTooLarge.
  ///
  /// In ja, this message translates to:
  /// **'棚入れ待ちは {max} までです'**
  String putawayQuantityTooLarge(int max);

  /// No description provided for @putawayConfirm.
  ///
  /// In ja, this message translates to:
  /// **'棚入れを確定'**
  String get putawayConfirm;

  /// No description provided for @putawayConfirmed.
  ///
  /// In ja, this message translates to:
  /// **'{bin} に {quantity} 入れました（残 {pendingAfter}）'**
  String putawayConfirmed(int quantity, String bin, int pendingAfter);

  /// No description provided for @actionOk.
  ///
  /// In ja, this message translates to:
  /// **'OK'**
  String get actionOk;

  /// No description provided for @scanWrongItem.
  ///
  /// In ja, this message translates to:
  /// **'別の商品です（対象: {expected}）'**
  String scanWrongItem(String expected);

  /// No description provided for @scanExpecting.
  ///
  /// In ja, this message translates to:
  /// **'対象: {expected} を枠内に合わせてください'**
  String scanExpecting(String expected);

  /// No description provided for @scanNothingYet.
  ///
  /// In ja, this message translates to:
  /// **'まだ読み取りがありません'**
  String get scanNothingYet;

  /// No description provided for @scanAcceptedCount.
  ///
  /// In ja, this message translates to:
  /// **'{count} 件読み取り'**
  String scanAcceptedCount(int count);

  /// No description provided for @scanResultOk.
  ///
  /// In ja, this message translates to:
  /// **'OK'**
  String get scanResultOk;

  /// No description provided for @scanResultDuplicate.
  ///
  /// In ja, this message translates to:
  /// **'重複（無視しました）'**
  String get scanResultDuplicate;

  /// No description provided for @scanResultNg.
  ///
  /// In ja, this message translates to:
  /// **'NG'**
  String get scanResultNg;

  /// No description provided for @scanManualEntry.
  ///
  /// In ja, this message translates to:
  /// **'手動入力'**
  String get scanManualEntry;

  /// No description provided for @scanManualEntryHint.
  ///
  /// In ja, this message translates to:
  /// **'JAN / バーコード'**
  String get scanManualEntryHint;

  /// No description provided for @scanDone.
  ///
  /// In ja, this message translates to:
  /// **'完了'**
  String get scanDone;

  /// No description provided for @pickScanToConfirm.
  ///
  /// In ja, this message translates to:
  /// **'数量を確定するには対象のJANをスキャンしてください'**
  String get pickScanToConfirm;

  /// No description provided for @pickScanned.
  ///
  /// In ja, this message translates to:
  /// **'スキャン確認済み'**
  String get pickScanned;

  /// No description provided for @pickScanAction.
  ///
  /// In ja, this message translates to:
  /// **'スキャン'**
  String get pickScanAction;

  /// No description provided for @taskInboundPlanned.
  ///
  /// In ja, this message translates to:
  /// **'入荷予定'**
  String get taskInboundPlanned;

  /// No description provided for @actionEdit.
  ///
  /// In ja, this message translates to:
  /// **'編集'**
  String get actionEdit;

  /// No description provided for @autopackAction.
  ///
  /// In ja, this message translates to:
  /// **'箱数を自動計算'**
  String get autopackAction;

  /// No description provided for @autopackTotal.
  ///
  /// In ja, this message translates to:
  /// **'総数量 {total}'**
  String autopackTotal(int total);

  /// No description provided for @autopackPerCarton.
  ///
  /// In ja, this message translates to:
  /// **'1箱あたりの数量'**
  String get autopackPerCarton;

  /// No description provided for @autopackHint.
  ///
  /// In ja, this message translates to:
  /// **'1箱に入る数量を入力すると、必要な箱数を計算します。'**
  String get autopackHint;

  /// No description provided for @autopackBoxes.
  ///
  /// In ja, this message translates to:
  /// **'箱数 {boxes}'**
  String autopackBoxes(int boxes);

  /// No description provided for @autopackEven.
  ///
  /// In ja, this message translates to:
  /// **'全箱 {per} 個'**
  String autopackEven(int per);

  /// No description provided for @autopackSplit.
  ///
  /// In ja, this message translates to:
  /// **'{full} 箱 × {per} 個 ＋ 最終箱 {last} 個'**
  String autopackSplit(int full, int per, int last);

  /// No description provided for @autopackConfirm.
  ///
  /// In ja, this message translates to:
  /// **'この箱数で作成'**
  String get autopackConfirm;

  /// No description provided for @autopackDone.
  ///
  /// In ja, this message translates to:
  /// **'{boxes} 箱を作成しました（1箱 {per} 個）'**
  String autopackDone(int boxes, int per);

  /// No description provided for @printCartonLabels.
  ///
  /// In ja, this message translates to:
  /// **'箱ラベルを印刷（全箱）'**
  String get printCartonLabels;

  /// No description provided for @printThisLabel.
  ///
  /// In ja, this message translates to:
  /// **'箱ラベル'**
  String get printThisLabel;

  /// No description provided for @shipmentParcelsAction.
  ///
  /// In ja, this message translates to:
  /// **'出荷ロット履歴'**
  String get shipmentParcelsAction;

  /// No description provided for @shipmentParcelsTitle.
  ///
  /// In ja, this message translates to:
  /// **'出荷ロット履歴'**
  String get shipmentParcelsTitle;

  /// No description provided for @shipmentParcelsEmpty.
  ///
  /// In ja, this message translates to:
  /// **'まだ出荷されていません'**
  String get shipmentParcelsEmpty;

  /// No description provided for @shipmentParcelsEmptyBody.
  ///
  /// In ja, this message translates to:
  /// **'出荷を確定すると、実際に出たロット・シリアルがここに表示されます。'**
  String get shipmentParcelsEmptyBody;

  /// No description provided for @shipmentParcelReversalTag.
  ///
  /// In ja, this message translates to:
  /// **'取消分'**
  String get shipmentParcelReversalTag;

  /// No description provided for @shipLogisticsSection.
  ///
  /// In ja, this message translates to:
  /// **'配送情報'**
  String get shipLogisticsSection;

  /// No description provided for @shipLogisticsUnset.
  ///
  /// In ja, this message translates to:
  /// **'未入力'**
  String get shipLogisticsUnset;

  /// No description provided for @shipWeight.
  ///
  /// In ja, this message translates to:
  /// **'重量'**
  String get shipWeight;

  /// No description provided for @shipWeightKg.
  ///
  /// In ja, this message translates to:
  /// **'{kg} kg'**
  String shipWeightKg(double kg);

  /// No description provided for @shipWeightInvalid.
  ///
  /// In ja, this message translates to:
  /// **'重量は0以上の数値で入力してください'**
  String get shipWeightInvalid;

  /// No description provided for @shipCarrier.
  ///
  /// In ja, this message translates to:
  /// **'配送会社'**
  String get shipCarrier;

  /// No description provided for @shipTracking.
  ///
  /// In ja, this message translates to:
  /// **'送り状番号'**
  String get shipTracking;

  /// No description provided for @auditEventAiAnalysisCompleted.
  ///
  /// In ja, this message translates to:
  /// **'AI解析完了'**
  String get auditEventAiAnalysisCompleted;

  /// No description provided for @auditEventAiConfirmed.
  ///
  /// In ja, this message translates to:
  /// **'AI結果を承認'**
  String get auditEventAiConfirmed;

  /// No description provided for @auditEventAiRejected.
  ///
  /// In ja, this message translates to:
  /// **'AI結果を却下'**
  String get auditEventAiRejected;

  /// No description provided for @auditEventAttachmentUploaded.
  ///
  /// In ja, this message translates to:
  /// **'写真を添付'**
  String get auditEventAttachmentUploaded;

  /// No description provided for @auditEventCountCancelled.
  ///
  /// In ja, this message translates to:
  /// **'棚卸を中止'**
  String get auditEventCountCancelled;

  /// No description provided for @auditEventCountCompleted.
  ///
  /// In ja, this message translates to:
  /// **'棚卸を確定'**
  String get auditEventCountCompleted;

  /// No description provided for @auditEventCountStarted.
  ///
  /// In ja, this message translates to:
  /// **'棚卸を開始'**
  String get auditEventCountStarted;

  /// No description provided for @auditEventInspectionConfirmed.
  ///
  /// In ja, this message translates to:
  /// **'検品確定'**
  String get auditEventInspectionConfirmed;

  /// No description provided for @auditEventInspectionStarted.
  ///
  /// In ja, this message translates to:
  /// **'検品開始'**
  String get auditEventInspectionStarted;

  /// No description provided for @auditEventInventoryAdjusted.
  ///
  /// In ja, this message translates to:
  /// **'在庫調整'**
  String get auditEventInventoryAdjusted;

  /// No description provided for @auditEventPartnerCreated.
  ///
  /// In ja, this message translates to:
  /// **'取引先を登録'**
  String get auditEventPartnerCreated;

  /// No description provided for @auditEventPartnerUpdated.
  ///
  /// In ja, this message translates to:
  /// **'取引先を更新'**
  String get auditEventPartnerUpdated;

  /// No description provided for @auditEventPickListCancelled.
  ///
  /// In ja, this message translates to:
  /// **'ピッキング中止'**
  String get auditEventPickListCancelled;

  /// No description provided for @auditEventPickListCompleted.
  ///
  /// In ja, this message translates to:
  /// **'ピッキング完了'**
  String get auditEventPickListCompleted;

  /// No description provided for @auditEventPickListStarted.
  ///
  /// In ja, this message translates to:
  /// **'ピッキング開始'**
  String get auditEventPickListStarted;

  /// No description provided for @auditEventProductCreated.
  ///
  /// In ja, this message translates to:
  /// **'商品を登録'**
  String get auditEventProductCreated;

  /// No description provided for @auditEventProductUpdated.
  ///
  /// In ja, this message translates to:
  /// **'商品を更新'**
  String get auditEventProductUpdated;

  /// No description provided for @auditEventPurchaseOrderApproved.
  ///
  /// In ja, this message translates to:
  /// **'発注を承認'**
  String get auditEventPurchaseOrderApproved;

  /// No description provided for @auditEventPurchaseOrderCancelled.
  ///
  /// In ja, this message translates to:
  /// **'発注をキャンセル'**
  String get auditEventPurchaseOrderCancelled;

  /// No description provided for @auditEventPurchaseOrderCompleted.
  ///
  /// In ja, this message translates to:
  /// **'発注を完了'**
  String get auditEventPurchaseOrderCompleted;

  /// No description provided for @auditEventPurchaseOrderCreated.
  ///
  /// In ja, this message translates to:
  /// **'発注を作成'**
  String get auditEventPurchaseOrderCreated;

  /// No description provided for @auditEventPurchaseOrderRejected.
  ///
  /// In ja, this message translates to:
  /// **'発注を却下'**
  String get auditEventPurchaseOrderRejected;

  /// No description provided for @auditEventPurchaseOrderSubmitted.
  ///
  /// In ja, this message translates to:
  /// **'発注を申請'**
  String get auditEventPurchaseOrderSubmitted;

  /// No description provided for @auditEventPutawayConfirmed.
  ///
  /// In ja, this message translates to:
  /// **'棚入れ確定'**
  String get auditEventPutawayConfirmed;

  /// No description provided for @auditEventReceivingCancelled.
  ///
  /// In ja, this message translates to:
  /// **'入荷取消'**
  String get auditEventReceivingCancelled;

  /// No description provided for @auditEventReceivingConfirmed.
  ///
  /// In ja, this message translates to:
  /// **'入荷確定'**
  String get auditEventReceivingConfirmed;

  /// No description provided for @auditEventReportDeleted.
  ///
  /// In ja, this message translates to:
  /// **'レポートを削除'**
  String get auditEventReportDeleted;

  /// No description provided for @auditEventReportSaved.
  ///
  /// In ja, this message translates to:
  /// **'レポートを保存'**
  String get auditEventReportSaved;

  /// No description provided for @auditEventSalesOrderApproved.
  ///
  /// In ja, this message translates to:
  /// **'受注を承認'**
  String get auditEventSalesOrderApproved;

  /// No description provided for @auditEventSalesOrderCancelled.
  ///
  /// In ja, this message translates to:
  /// **'受注をキャンセル'**
  String get auditEventSalesOrderCancelled;

  /// No description provided for @auditEventSalesOrderCompleted.
  ///
  /// In ja, this message translates to:
  /// **'受注を完了'**
  String get auditEventSalesOrderCompleted;

  /// No description provided for @auditEventSalesOrderCreated.
  ///
  /// In ja, this message translates to:
  /// **'受注を作成'**
  String get auditEventSalesOrderCreated;

  /// No description provided for @auditEventSalesOrderRejected.
  ///
  /// In ja, this message translates to:
  /// **'受注を却下'**
  String get auditEventSalesOrderRejected;

  /// No description provided for @auditEventSalesOrderSubmitted.
  ///
  /// In ja, this message translates to:
  /// **'受注を申請'**
  String get auditEventSalesOrderSubmitted;

  /// No description provided for @auditEventShipmentAutopacked.
  ///
  /// In ja, this message translates to:
  /// **'箱を自動作成'**
  String get auditEventShipmentAutopacked;

  /// No description provided for @auditEventShipmentCancelled.
  ///
  /// In ja, this message translates to:
  /// **'出荷を取消'**
  String get auditEventShipmentCancelled;

  /// No description provided for @auditEventShipmentCompleted.
  ///
  /// In ja, this message translates to:
  /// **'出荷確定'**
  String get auditEventShipmentCompleted;

  /// No description provided for @auditEventShipmentLogisticsSet.
  ///
  /// In ja, this message translates to:
  /// **'配送情報を設定'**
  String get auditEventShipmentLogisticsSet;

  /// No description provided for @auditEventTransferApproved.
  ///
  /// In ja, this message translates to:
  /// **'倉庫間移動を承認'**
  String get auditEventTransferApproved;

  /// No description provided for @auditEventTransferCancelled.
  ///
  /// In ja, this message translates to:
  /// **'倉庫間移動を中止'**
  String get auditEventTransferCancelled;

  /// No description provided for @auditEventTransferCreated.
  ///
  /// In ja, this message translates to:
  /// **'倉庫間移動を作成'**
  String get auditEventTransferCreated;

  /// No description provided for @auditEventTransferPickingStarted.
  ///
  /// In ja, this message translates to:
  /// **'移動ピッキング開始'**
  String get auditEventTransferPickingStarted;

  /// No description provided for @auditEventTransferReceived.
  ///
  /// In ja, this message translates to:
  /// **'倉庫間移動を受領'**
  String get auditEventTransferReceived;

  /// No description provided for @auditEventTransferReceivingStarted.
  ///
  /// In ja, this message translates to:
  /// **'移動受入開始'**
  String get auditEventTransferReceivingStarted;

  /// No description provided for @auditEventTransferRejected.
  ///
  /// In ja, this message translates to:
  /// **'倉庫間移動を却下'**
  String get auditEventTransferRejected;

  /// No description provided for @auditEventTransferShipped.
  ///
  /// In ja, this message translates to:
  /// **'倉庫間移動を出庫'**
  String get auditEventTransferShipped;

  /// No description provided for @auditEventTransferSubmitted.
  ///
  /// In ja, this message translates to:
  /// **'倉庫間移動を申請'**
  String get auditEventTransferSubmitted;

  /// No description provided for @auditEventUserRoleAssigned.
  ///
  /// In ja, this message translates to:
  /// **'ロールを付与'**
  String get auditEventUserRoleAssigned;

  /// No description provided for @auditEventUserRoleRevoked.
  ///
  /// In ja, this message translates to:
  /// **'ロールを削除'**
  String get auditEventUserRoleRevoked;

  /// No description provided for @auditEventUserWarehouseAssigned.
  ///
  /// In ja, this message translates to:
  /// **'倉庫アクセスを付与'**
  String get auditEventUserWarehouseAssigned;

  /// No description provided for @auditEventUserWarehouseRevoked.
  ///
  /// In ja, this message translates to:
  /// **'倉庫アクセスを削除'**
  String get auditEventUserWarehouseRevoked;

  /// No description provided for @auditEventWorkOrderCancelled.
  ///
  /// In ja, this message translates to:
  /// **'作業指示を中止'**
  String get auditEventWorkOrderCancelled;

  /// No description provided for @auditEventWorkOrderCompleted.
  ///
  /// In ja, this message translates to:
  /// **'作業指示を完了'**
  String get auditEventWorkOrderCompleted;

  /// No description provided for @auditEventWorkOrderCreated.
  ///
  /// In ja, this message translates to:
  /// **'作業指示を作成'**
  String get auditEventWorkOrderCreated;

  /// No description provided for @auditEventWorkOrderStarted.
  ///
  /// In ja, this message translates to:
  /// **'作業指示を開始'**
  String get auditEventWorkOrderStarted;

  /// No description provided for @dashNotificationsTitle.
  ///
  /// In ja, this message translates to:
  /// **'通知'**
  String get dashNotificationsTitle;

  /// No description provided for @dashNotificationsEmpty.
  ///
  /// In ja, this message translates to:
  /// **'対応が必要な通知はありません'**
  String get dashNotificationsEmpty;

  /// No description provided for @notifCount.
  ///
  /// In ja, this message translates to:
  /// **'{count} 件'**
  String notifCount(int count);

  /// No description provided for @notifFailedInspection.
  ///
  /// In ja, this message translates to:
  /// **'検品NG'**
  String get notifFailedInspection;

  /// No description provided for @notifOutstandingPlans.
  ///
  /// In ja, this message translates to:
  /// **'入荷待ち'**
  String get notifOutstandingPlans;

  /// No description provided for @notifPutawayPending.
  ///
  /// In ja, this message translates to:
  /// **'棚入れ待ち'**
  String get notifPutawayPending;

  /// No description provided for @notifOpenPicking.
  ///
  /// In ja, this message translates to:
  /// **'ピック待ち'**
  String get notifOpenPicking;

  /// Tooltip on the sidebar collapse/expand toggle (wide layout only).
  ///
  /// In ja, this message translates to:
  /// **'メニューを折りたたむ'**
  String get sidebarCollapse;

  /// Tooltip on the sidebar collapse/expand toggle (wide layout only).
  ///
  /// In ja, this message translates to:
  /// **'メニューを展開'**
  String get sidebarExpand;

  /// Sidebar menu filter field: hint text, and the empty-result message.
  ///
  /// In ja, this message translates to:
  /// **'メニューを絞り込む'**
  String get menuFilter;

  /// Sidebar menu filter field: hint text, and the empty-result message.
  ///
  /// In ja, this message translates to:
  /// **'該当する項目がありません'**
  String get menuFilterNoMatch;

  /// Shown in a tab whose location this build does not serve.
  ///
  /// In ja, this message translates to:
  /// **'この画面は見つかりませんでした。メニューから選び直してください。'**
  String get unknownLocation;

  /// Keyboard shortcut help sheet.
  ///
  /// In ja, this message translates to:
  /// **'閉じる'**
  String get close;

  /// Keyboard shortcut help sheet.
  ///
  /// In ja, this message translates to:
  /// **'キーボードショートカット'**
  String get shortcutsTitle;

  /// Keyboard shortcut help sheet.
  ///
  /// In ja, this message translates to:
  /// **'キーボードショートカットを表示'**
  String get shortcutsHelp;

  /// Keyboard shortcut help sheet.
  ///
  /// In ja, this message translates to:
  /// **'スキャン欄にカーソルを移動'**
  String get shortcutFocusScan;

  /// Keyboard shortcut help sheet.
  ///
  /// In ja, this message translates to:
  /// **'メニューの折りたたみを切り替え'**
  String get shortcutToggleSidebar;

  /// Keyboard shortcut help sheet.
  ///
  /// In ja, this message translates to:
  /// **'横断検索を開く'**
  String get shortcutGlobalSearch;

  /// Keyboard shortcut help sheet.
  ///
  /// In ja, this message translates to:
  /// **'N番目のタブに切り替え'**
  String get shortcutSwitchTab;

  /// Keyboard shortcut help sheet.
  ///
  /// In ja, this message translates to:
  /// **'この一覧を表示'**
  String get shortcutShowHelp;

  /// Product master: internal code, separate from the JAN barcode (0057).
  ///
  /// In ja, this message translates to:
  /// **'品番（SKU）'**
  String get productSku;

  /// Product master: SKU field helper text.
  ///
  /// In ja, this message translates to:
  /// **'社内品番（任意）'**
  String get productSkuHint;

  /// Product master: what must be recorded about this product (0057/0060).
  ///
  /// In ja, this message translates to:
  /// **'追跡区分'**
  String get productTracking;

  /// Tracking mode UNTRACKED.
  ///
  /// In ja, this message translates to:
  /// **'追跡なし'**
  String get trackUntracked;

  /// Tracking mode LOT.
  ///
  /// In ja, this message translates to:
  /// **'ロット'**
  String get trackLot;

  /// Tracking mode SERIAL.
  ///
  /// In ja, this message translates to:
  /// **'シリアル'**
  String get trackSerial;

  /// Tracking mode LOT_AND_SERIAL.
  ///
  /// In ja, this message translates to:
  /// **'ロット＋シリアル'**
  String get trackLotAndSerial;

  /// Tracking mode EXPIRY: every lot must carry a date.
  ///
  /// In ja, this message translates to:
  /// **'有効期限'**
  String get trackExpiry;

  /// Product master: the unit on-hand quantities are counted in (0059).
  ///
  /// In ja, this message translates to:
  /// **'基本単位'**
  String get productBaseUnit;

  /// Product master: this product's goods arrive held for QC (0068, §13).
  ///
  /// In ja, this message translates to:
  /// **'入荷検品を必須にする'**
  String get productRequiresInspection;

  /// Product master: requires-inspection field helper text.
  ///
  /// In ja, this message translates to:
  /// **'オンにすると、入荷時にこの商品は検品待ち（QC_PENDING）として保留され、検品完了までピッキング・出荷できません。'**
  String get productRequiresInspectionHint;

  /// Product master: the default picking draw order (0074, §16).
  ///
  /// In ja, this message translates to:
  /// **'ピッキング順序'**
  String get productPickingRule;

  /// Product master: picking rule field helper text.
  ///
  /// In ja, this message translates to:
  /// **'在庫からどの順で取るかの初期設定です。倉庫ごとの上書きは別途設定できます。'**
  String get productPickingRuleHint;

  /// Picking rule FIFO.
  ///
  /// In ja, this message translates to:
  /// **'先入先出（FIFO）'**
  String get pickRuleFifo;

  /// Picking rule FEFO.
  ///
  /// In ja, this message translates to:
  /// **'期限が近い順（FEFO）'**
  String get pickRuleFefo;

  /// Picking rule LIFO.
  ///
  /// In ja, this message translates to:
  /// **'後入先出（LIFO）'**
  String get pickRuleLifo;

  /// Picking rule MANUAL: no automatic suggestion.
  ///
  /// In ja, this message translates to:
  /// **'都度選択（MANUAL）'**
  String get pickRuleManual;

  /// Product master: how many barcodes resolve to this product.
  ///
  /// In ja, this message translates to:
  /// **'コード {count} 件'**
  String productCodeCount(int count);

  /// Product master: one pack unit and what it converts to.
  ///
  /// In ja, this message translates to:
  /// **'{code} = {factor}{base}'**
  String productPackUnit(String code, String factor, String base);

  /// Product form: resolve_barcode found the scanned code on another product.
  ///
  /// In ja, this message translates to:
  /// **'このコードは「{name}」に登録済みです'**
  String productScanAlreadyUsed(String name);

  /// Stock: the four numbers §5 keeps apart (0061/0064).
  ///
  /// In ja, this message translates to:
  /// **'在庫内訳'**
  String get stockPositionTitle;

  /// Stock position: usable on-hand less what is reserved.
  ///
  /// In ja, this message translates to:
  /// **'引当可能'**
  String get stockAvailable;

  /// Stock position: promised to orders, not yet shipped.
  ///
  /// In ja, this message translates to:
  /// **'予約済み'**
  String get stockReserved;

  /// Stock position: of the reserved quantity, how much is pinned to parcels.
  ///
  /// In ja, this message translates to:
  /// **'引当済み'**
  String get stockAllocated;

  /// Stock position: on hand but quarantined, damaged or held.
  ///
  /// In ja, this message translates to:
  /// **'出荷不可'**
  String get stockUnavailable;

  /// Stock position: available went negative.
  ///
  /// In ja, this message translates to:
  /// **'予約が引当可能数を超えています'**
  String get stockOverPromised;

  /// Stock: stock_levels row whose product_id is still null (0058).
  ///
  /// In ja, this message translates to:
  /// **'このJANは商品ライブラリーに未登録です'**
  String get stockNotLinkedToProduct;

  /// Stock position: which lot a parcel came from.
  ///
  /// In ja, this message translates to:
  /// **'ロット {code}'**
  String stockPositionLot(String code);

  /// Stock position: the product has no stock_units rows in this warehouse.
  ///
  /// In ja, this message translates to:
  /// **'内訳はまだありません'**
  String get stockPositionNoParcels;

  /// Product detail screen title.
  ///
  /// In ja, this message translates to:
  /// **'商品詳細'**
  String get productDetailTitle;

  /// Product detail: open the edit sheet.
  ///
  /// In ja, this message translates to:
  /// **'編集'**
  String get productEdit;

  /// Product detail: the codes that resolve to this product (0057).
  ///
  /// In ja, this message translates to:
  /// **'バーコード'**
  String get productBarcodesSection;

  /// Product detail: register another barcode.
  ///
  /// In ja, this message translates to:
  /// **'コードを追加'**
  String get productBarcodeAdd;

  /// Product detail: the one code that cannot be removed.
  ///
  /// In ja, this message translates to:
  /// **'主コード'**
  String get productBarcodePrimary;

  /// Product detail: barcode type (JAN/EAN/CASE/…).
  ///
  /// In ja, this message translates to:
  /// **'種別'**
  String get productBarcodeType;

  /// Product detail: naming a unit makes the conversion authoritative (0059).
  ///
  /// In ja, this message translates to:
  /// **'単位（任意）'**
  String get productBarcodeUnit;

  /// Product detail: how much one scan of this code counts.
  ///
  /// In ja, this message translates to:
  /// **'1スキャン = {qty}'**
  String productBarcodeQtyPerScan(String qty);

  /// Product detail: confirm removing a barcode.
  ///
  /// In ja, this message translates to:
  /// **'このコードを削除しますか？'**
  String get productBarcodeRemoveQ;

  /// Product detail: what removing a barcode does.
  ///
  /// In ja, this message translates to:
  /// **'このコードではスキャンできなくなります。商品自体は残ります。'**
  String get productBarcodeRemoveBody;

  /// Product detail: empty barcode list.
  ///
  /// In ja, this message translates to:
  /// **'コードがまだありません'**
  String get productBarcodeEmpty;

  /// Product detail: base unit and pack sizes (0059).
  ///
  /// In ja, this message translates to:
  /// **'単位'**
  String get productUnitsSection;

  /// Product detail: define a pack size.
  ///
  /// In ja, this message translates to:
  /// **'単位を追加'**
  String get productUnitAdd;

  /// Product detail: how many base units one of this unit is.
  ///
  /// In ja, this message translates to:
  /// **'換算数'**
  String get productUnitFactor;

  /// Product detail: marks the base unit row.
  ///
  /// In ja, this message translates to:
  /// **'基本'**
  String get productUnitBase;

  /// Product detail: confirm removing a pack size (0059).
  ///
  /// In ja, this message translates to:
  /// **'この単位を削除しますか？'**
  String get productUnitRemoveQ;

  /// Product detail: pack-size removal confirmation body.
  ///
  /// In ja, this message translates to:
  /// **'このパック単位は選べなくなります。基本単位、またはバーコードが参照している単位は削除できません。'**
  String get productUnitRemoveBody;

  /// Product detail: lots recorded against this product (0060).
  ///
  /// In ja, this message translates to:
  /// **'ロット'**
  String get productLotsSection;

  /// Product detail: empty lot list.
  ///
  /// In ja, this message translates to:
  /// **'ロットの記録はまだありません'**
  String get productLotsEmpty;

  /// Product detail / expiry list: a lot's expiry date.
  ///
  /// In ja, this message translates to:
  /// **'期限 {date}'**
  String productLotExpiryOn(String date);

  /// Product detail / expiry list: days until a lot expires.
  ///
  /// In ja, this message translates to:
  /// **'あと{days}日'**
  String productLotDaysLeft(int days);

  /// Product detail / expiry list: past its date.
  ///
  /// In ja, this message translates to:
  /// **'期限切れ'**
  String get productLotExpired;

  /// Product detail: how many serials belong to a lot.
  ///
  /// In ja, this message translates to:
  /// **'シリアル {count} 件'**
  String productLotSerialCount(int count);

  /// Product detail: serials recorded against this product (0060).
  ///
  /// In ja, this message translates to:
  /// **'シリアル'**
  String get productSerialsSection;

  /// Product detail: empty serial list.
  ///
  /// In ja, this message translates to:
  /// **'シリアルの記録はまだありません'**
  String get productSerialsEmpty;

  /// Product detail: serial status filter, no filter.
  ///
  /// In ja, this message translates to:
  /// **'すべて'**
  String get productSerialFilterAll;

  /// Serial status IN_STOCK.
  ///
  /// In ja, this message translates to:
  /// **'在庫あり'**
  String get serialInStock;

  /// Serial status SHIPPED.
  ///
  /// In ja, this message translates to:
  /// **'出荷済'**
  String get serialShipped;

  /// Serial status RETURNED.
  ///
  /// In ja, this message translates to:
  /// **'返品'**
  String get serialReturned;

  /// Serial status SCRAPPED.
  ///
  /// In ja, this message translates to:
  /// **'廃棄'**
  String get serialScrapped;

  /// Serial status HOLD.
  ///
  /// In ja, this message translates to:
  /// **'保留'**
  String get serialHold;

  /// Product detail: tooltip on the serial status edit button (0060).
  ///
  /// In ja, this message translates to:
  /// **'ステータスを変更'**
  String get productSerialChangeStatus;

  /// Serial status dialog: the dropdown field label.
  ///
  /// In ja, this message translates to:
  /// **'ステータス'**
  String get productSerialStatus;

  /// Serial status dialog: optional note field label.
  ///
  /// In ja, this message translates to:
  /// **'メモ（任意）'**
  String get productSerialNote;

  /// Product detail: warehouse_products, §22's per-warehouse handling.
  ///
  /// In ja, this message translates to:
  /// **'この倉庫での設定'**
  String get whpSection;

  /// Product detail: no warehouse_products row, which is the normal case.
  ///
  /// In ja, this message translates to:
  /// **'この倉庫には専用の設定がありません'**
  String get whpNone;

  /// Product detail: the settings are per warehouse, and none is active.
  ///
  /// In ja, this message translates to:
  /// **'倉庫を選ぶと設定できます'**
  String get whpNoWarehouse;

  /// Product detail: open the warehouse settings sheet.
  ///
  /// In ja, this message translates to:
  /// **'設定する'**
  String get whpEdit;

  /// warehouse_products.default_location_id, named by its code.
  ///
  /// In ja, this message translates to:
  /// **'既定ロケーション'**
  String get whpDefaultLocation;

  /// warehouse_products: how the default location is entered.
  ///
  /// In ja, this message translates to:
  /// **'ラックのコード（空欄で解除）'**
  String get whpDefaultLocationHint;

  /// warehouse_products.min_stock.
  ///
  /// In ja, this message translates to:
  /// **'最小在庫'**
  String get whpMinStock;

  /// warehouse_products.reorder_point, compared against available (§31).
  ///
  /// In ja, this message translates to:
  /// **'発注点'**
  String get whpReorderPoint;

  /// warehouse_products.max_stock, the level a suggestion orders up to.
  ///
  /// In ja, this message translates to:
  /// **'最大在庫'**
  String get whpMaxStock;

  /// warehouse_products.pick_priority, lower picks first.
  ///
  /// In ja, this message translates to:
  /// **'ピッキング優先度'**
  String get whpPickPriority;

  /// warehouse_products.putaway_rule; records the intent, Phase B acts on it.
  ///
  /// In ja, this message translates to:
  /// **'格納ルール'**
  String get whpPutawayRule;

  /// Put-away rule MANUAL.
  ///
  /// In ja, this message translates to:
  /// **'手動'**
  String get putawayManual;

  /// Put-away rule FIXED.
  ///
  /// In ja, this message translates to:
  /// **'固定ロケーション'**
  String get putawayFixed;

  /// Put-away rule CONSOLIDATE.
  ///
  /// In ja, this message translates to:
  /// **'同じ品にまとめる'**
  String get putawayConsolidate;

  /// Put-away rule NEAREST_EMPTY.
  ///
  /// In ja, this message translates to:
  /// **'最も近い空き'**
  String get putawayNearestEmpty;

  /// warehouse_products.lead_time_days.
  ///
  /// In ja, this message translates to:
  /// **'リードタイム（日）'**
  String get whpLeadTime;

  /// warehouse_products.preferred_supplier_id.
  ///
  /// In ja, this message translates to:
  /// **'優先仕入先'**
  String get whpSupplier;

  /// Product detail: clear_warehouse_product.
  ///
  /// In ja, this message translates to:
  /// **'この倉庫の設定を削除'**
  String get whpClear;

  /// Product detail: confirm clearing warehouse_products.
  ///
  /// In ja, this message translates to:
  /// **'この倉庫の設定を削除しますか？'**
  String get whpClearQ;

  /// Product detail: what clearing warehouse_products does.
  ///
  /// In ja, this message translates to:
  /// **'既定ロケーションと発注点がなくなり、補充提案にも出なくなります。'**
  String get whpClearBody;

  /// Product detail: available < reorder_point.
  ///
  /// In ja, this message translates to:
  /// **'発注点を下回っています'**
  String get whpNeedsReorder;

  /// Home menu: lots running out of time (§4).
  ///
  /// In ja, this message translates to:
  /// **'期限管理'**
  String get featExpiringLots;

  /// Home menu description for the expiry watch.
  ///
  /// In ja, this message translates to:
  /// **'期限が近い・切れたロットを一覧'**
  String get featExpiringLotsDesc;

  /// Home menu: promises against stock (§6).
  ///
  /// In ja, this message translates to:
  /// **'予約・引当'**
  String get featReservations;

  /// Home menu description for reservations.
  ///
  /// In ja, this message translates to:
  /// **'受注などのために確保した在庫と、その引当先'**
  String get featReservationsDesc;

  /// Home menu: the location tree (§7/§8).
  ///
  /// In ja, this message translates to:
  /// **'ロケーション'**
  String get featLocations;

  /// Home menu description for locations.
  ///
  /// In ja, this message translates to:
  /// **'ゾーン・通路・ラック・棚の階層と種別'**
  String get featLocationsDesc;

  /// Home menu: products under their reorder point (§31).
  ///
  /// In ja, this message translates to:
  /// **'補充提案'**
  String get featReplenishment;

  /// Home menu description for replenishment.
  ///
  /// In ja, this message translates to:
  /// **'発注点を下回った商品と発注数の目安'**
  String get featReplenishmentDesc;

  /// Home menu: where stock_levels and stock_units disagree (0061).
  ///
  /// In ja, this message translates to:
  /// **'在庫整合性チェック'**
  String get featStockReconciliation;

  /// Home menu description for stock reconciliation.
  ///
  /// In ja, this message translates to:
  /// **'在庫水準と実在庫のズレを確認'**
  String get featStockReconciliationDesc;

  /// Expiry screen title.
  ///
  /// In ja, this message translates to:
  /// **'期限管理'**
  String get expiryTitle;

  /// Expiry screen: how far ahead the list looks.
  ///
  /// In ja, this message translates to:
  /// **'{days}日以内'**
  String expiryHorizon(int days);

  /// Expiry screen: empty state.
  ///
  /// In ja, this message translates to:
  /// **'期限が近いロットはありません'**
  String get expiryEmpty;

  /// Expiry screen: empty state body.
  ///
  /// In ja, this message translates to:
  /// **'この期間に期限を迎えるロットはありません。期間を広げると先の分も確認できます。'**
  String get expiryEmptyBody;

  /// Expiry screen: how many rows are already past their date.
  ///
  /// In ja, this message translates to:
  /// **'期限切れ {count} 件'**
  String expiryExpiredCount(int count);

  /// Expiry screen: how many rows are close to their date.
  ///
  /// In ja, this message translates to:
  /// **'期限間近 {count} 件'**
  String expirySoonCount(int count);

  /// Reservations screen title.
  ///
  /// In ja, this message translates to:
  /// **'予約・引当'**
  String get reservationsTitle;

  /// Reservations screen: empty state.
  ///
  /// In ja, this message translates to:
  /// **'予約はありません'**
  String get reservationsEmpty;

  /// Reservations screen: empty state body.
  ///
  /// In ja, this message translates to:
  /// **'受注や出荷のために確保された在庫がここに並びます。'**
  String get reservationsEmptyBody;

  /// Reservation status ACTIVE.
  ///
  /// In ja, this message translates to:
  /// **'有効'**
  String get reservationStatusActive;

  /// Reservation status FULFILLED.
  ///
  /// In ja, this message translates to:
  /// **'出荷済'**
  String get reservationStatusFulfilled;

  /// Reservation status RELEASED.
  ///
  /// In ja, this message translates to:
  /// **'解放済'**
  String get reservationStatusReleased;

  /// Reservations screen: no status filter.
  ///
  /// In ja, this message translates to:
  /// **'すべて'**
  String get reservationStatusAll;

  /// Reservations screen: past expires_at, so it holds nothing.
  ///
  /// In ja, this message translates to:
  /// **'期限切れ'**
  String get reservationLapsed;

  /// Reservations screen: what the promise is for.
  ///
  /// In ja, this message translates to:
  /// **'{type} {id}'**
  String reservationFor(String type, String id);

  /// Reservation reference type sales_order.
  ///
  /// In ja, this message translates to:
  /// **'受注'**
  String get refSalesOrder;

  /// Reservation reference type shipment.
  ///
  /// In ja, this message translates to:
  /// **'出荷'**
  String get refShipment;

  /// Reservation reference type transfer.
  ///
  /// In ja, this message translates to:
  /// **'移動'**
  String get refTransfer;

  /// Reservation reference type work_order.
  ///
  /// In ja, this message translates to:
  /// **'作業指示'**
  String get refWorkOrder;

  /// Reservation reference type manual.
  ///
  /// In ja, this message translates to:
  /// **'手動'**
  String get refManual;

  /// Reservations screen: the promised quantity.
  ///
  /// In ja, this message translates to:
  /// **'予約 {qty}'**
  String reservationQuantity(String qty);

  /// Reservations screen: how much is pinned to parcels.
  ///
  /// In ja, this message translates to:
  /// **'引当済 {qty}'**
  String reservationAllocated(String qty);

  /// Reservations screen: promised but not pinned to any parcel yet.
  ///
  /// In ja, this message translates to:
  /// **'未引当 {qty}'**
  String reservationUnallocated(String qty);

  /// Reservations screen: how much of the promise has shipped.
  ///
  /// In ja, this message translates to:
  /// **'出荷済 {qty}'**
  String reservationFulfilled(String qty);

  /// Reservations screen: release_reservation.
  ///
  /// In ja, this message translates to:
  /// **'解放'**
  String get reservationRelease;

  /// Reservations screen: confirm releasing.
  ///
  /// In ja, this message translates to:
  /// **'この予約を解放しますか？'**
  String get reservationReleaseQ;

  /// Reservations screen: what releasing does.
  ///
  /// In ja, this message translates to:
  /// **'確保していた在庫が引当可能に戻り、引当先も取り消されます。記録は残ります。'**
  String get reservationReleaseBody;

  /// Reservations screen: action to record fulfil_reservation.
  ///
  /// In ja, this message translates to:
  /// **'出荷済みにする'**
  String get reservationFulfil;

  /// Reservations screen: fulfil dialog title.
  ///
  /// In ja, this message translates to:
  /// **'出荷済みとして記録する'**
  String get reservationFulfilTitle;

  /// Reservations screen: fulfil dialog explains it moves no stock, mirroring the exception-resolve sheet's same caveat.
  ///
  /// In ja, this message translates to:
  /// **'在庫は動かしません。出荷の記録は別にあり、ここでは約束が果たされたことだけを記録します。'**
  String get reservationFulfilBody;

  /// Reservations screen: fulfil dialog quantity field, prefilled with what is still outstanding.
  ///
  /// In ja, this message translates to:
  /// **'数量'**
  String get reservationFulfilQuantity;

  /// Reservations screen: which parcels will supply this promise.
  ///
  /// In ja, this message translates to:
  /// **'引当先'**
  String get reservationAllocationsTitle;

  /// Reservations screen: a reservation with no allocations, which is a valid state.
  ///
  /// In ja, this message translates to:
  /// **'引当先はまだ決まっていません'**
  String get reservationNoAllocations;

  /// Reservations screen: parcels promised to more than they hold.
  ///
  /// In ja, this message translates to:
  /// **'引当超過'**
  String get overAllocatedTitle;

  /// Reservations screen: why over-allocation happens (an allocation never blocks a movement).
  ///
  /// In ja, this message translates to:
  /// **'在庫が引当より減っています。出荷が先に取ったためで、引当の解放か在庫の補充が必要です。'**
  String get overAllocatedBody;

  /// Reservations screen: one over-allocated parcel.
  ///
  /// In ja, this message translates to:
  /// **'在庫 {quantity} / 引当 {allocated}（超過 {over}）'**
  String overAllocatedRow(String quantity, String allocated, String over);

  /// Stock reconciliation screen title.
  ///
  /// In ja, this message translates to:
  /// **'在庫整合性チェック'**
  String get stockReconciliationTitle;

  /// Stock reconciliation screen: empty state (the healthy state).
  ///
  /// In ja, this message translates to:
  /// **'ズレはありません'**
  String get stockReconciliationEmpty;

  /// Stock reconciliation screen: empty state body.
  ///
  /// In ja, this message translates to:
  /// **'在庫水準と実在庫は一致しています。'**
  String get stockReconciliationEmptyBody;

  /// Stock reconciliation reason: a movement recorded against a barcode with no product.
  ///
  /// In ja, this message translates to:
  /// **'商品に紐付いていないJAN'**
  String get stockReconciliationReasonUnlinked;

  /// Stock reconciliation reason: the ledger and the stock units disagree.
  ///
  /// In ja, this message translates to:
  /// **'数量のズレ'**
  String get stockReconciliationReasonDrift;

  /// Stock reconciliation row: stock_levels.on_hand.
  ///
  /// In ja, this message translates to:
  /// **'在庫水準 {qty}'**
  String stockReconciliationLevels(int qty);

  /// Stock reconciliation row: sum of stock_units.quantity.
  ///
  /// In ja, this message translates to:
  /// **'実在庫 {qty}'**
  String stockReconciliationUnits(int qty);

  /// Stock reconciliation row: the signed gap between the two.
  ///
  /// In ja, this message translates to:
  /// **'差分 {diff}'**
  String stockReconciliationDrift(String diff);

  /// Location tree screen title.
  ///
  /// In ja, this message translates to:
  /// **'ロケーション'**
  String get locationsTitle;

  /// Location tree: empty state.
  ///
  /// In ja, this message translates to:
  /// **'ロケーションがまだありません'**
  String get locationsEmpty;

  /// Location tree: empty state body.
  ///
  /// In ja, this message translates to:
  /// **'ゾーンや棚を登録すると、ここに階層として表示されます。'**
  String get locationsEmptyBody;

  /// Location tree: the tree is per warehouse.
  ///
  /// In ja, this message translates to:
  /// **'倉庫を選ぶと表示できます'**
  String get locationsNoWarehouse;

  /// Location tree: create_location.
  ///
  /// In ja, this message translates to:
  /// **'ロケーションを追加'**
  String get locationAdd;

  /// Location: its code, unique within the warehouse.
  ///
  /// In ja, this message translates to:
  /// **'コード'**
  String get locationCode;

  /// Location: a human name beside the code.
  ///
  /// In ja, this message translates to:
  /// **'名称（任意）'**
  String get locationName;

  /// Location: its type, which sets the default flags (§8).
  ///
  /// In ja, this message translates to:
  /// **'種別'**
  String get locationType;

  /// Location: the node above it; empty means directly under the warehouse.
  ///
  /// In ja, this message translates to:
  /// **'親ロケーション（任意）'**
  String get locationParent;

  /// Location: what a scan gun reads off the shelf label.
  ///
  /// In ja, this message translates to:
  /// **'ラベルのバーコード（任意）'**
  String get locationBarcode;

  /// Location tree: include is_active = false nodes.
  ///
  /// In ja, this message translates to:
  /// **'停止中も表示'**
  String get locationShowInactive;

  /// Location tree app bar: opens the bin stock overview (0016).
  ///
  /// In ja, this message translates to:
  /// **'ビン別在庫'**
  String get binStockAction;

  /// Bin stock overview screen title.
  ///
  /// In ja, this message translates to:
  /// **'ビン別在庫'**
  String get binStockTitle;

  /// Bin stock overview: no bins (warehouse does not use locations, or none exist).
  ///
  /// In ja, this message translates to:
  /// **'この倉庫にはロケーションがありません'**
  String get binStockEmpty;

  /// Bin stock overview: a bin with nothing in it.
  ///
  /// In ja, this message translates to:
  /// **'空'**
  String get binStockBinEmpty;

  /// Bin stock overview: total units in one bin.
  ///
  /// In ja, this message translates to:
  /// **'計 {qty} 点'**
  String binStockTotalUnits(int qty);

  /// Location flag pickable.
  ///
  /// In ja, this message translates to:
  /// **'ピッキング可'**
  String get locationPickable;

  /// Location flag receivable.
  ///
  /// In ja, this message translates to:
  /// **'入荷可'**
  String get locationReceivable;

  /// Location flag shipping.
  ///
  /// In ja, this message translates to:
  /// **'出荷'**
  String get locationShipping;

  /// Location flag quarantine.
  ///
  /// In ja, this message translates to:
  /// **'隔離'**
  String get locationQuarantine;

  /// Location flag is_virtual.
  ///
  /// In ja, this message translates to:
  /// **'仮想'**
  String get locationVirtual;

  /// Location: is_active = false.
  ///
  /// In ja, this message translates to:
  /// **'停止中'**
  String get locationInactive;

  /// Location tree: bin_stock for a node that is a bin.
  ///
  /// In ja, this message translates to:
  /// **'在庫 {qty}'**
  String locationOnHand(String qty);

  /// Location type STORAGE.
  ///
  /// In ja, this message translates to:
  /// **'保管'**
  String get locTypeStorage;

  /// Location type PICKING.
  ///
  /// In ja, this message translates to:
  /// **'ピッキング'**
  String get locTypePicking;

  /// Location type RECEIVING.
  ///
  /// In ja, this message translates to:
  /// **'入荷'**
  String get locTypeReceiving;

  /// Location type QC.
  ///
  /// In ja, this message translates to:
  /// **'検品'**
  String get locTypeQc;

  /// Location type PACKING.
  ///
  /// In ja, this message translates to:
  /// **'梱包'**
  String get locTypePacking;

  /// Location type SHIPPING.
  ///
  /// In ja, this message translates to:
  /// **'出荷'**
  String get locTypeShipping;

  /// Location type QUARANTINE.
  ///
  /// In ja, this message translates to:
  /// **'隔離'**
  String get locTypeQuarantine;

  /// Location type DAMAGED.
  ///
  /// In ja, this message translates to:
  /// **'破損'**
  String get locTypeDamaged;

  /// Location type RETURN.
  ///
  /// In ja, this message translates to:
  /// **'返品'**
  String get locTypeReturn;

  /// Location type TRANSIT.
  ///
  /// In ja, this message translates to:
  /// **'移動中'**
  String get locTypeTransit;

  /// Location type VIRTUAL.
  ///
  /// In ja, this message translates to:
  /// **'仮想'**
  String get locTypeVirtual;

  /// Replenishment screen title.
  ///
  /// In ja, this message translates to:
  /// **'補充提案'**
  String get replenishmentTitle;

  /// Replenishment screen: empty state.
  ///
  /// In ja, this message translates to:
  /// **'補充が必要な商品はありません'**
  String get replenishmentEmpty;

  /// Replenishment screen: empty state body.
  ///
  /// In ja, this message translates to:
  /// **'発注点を設定した商品が、いずれも発注点を上回っています。'**
  String get replenishmentEmptyBody;

  /// Replenishment screen: suggested_quantity.
  ///
  /// In ja, this message translates to:
  /// **'発注目安 {qty}'**
  String replenishmentSuggest(String qty);

  /// Replenishment screen: how far under the reorder point.
  ///
  /// In ja, this message translates to:
  /// **'発注点まで {qty}'**
  String replenishmentShortfall(String qty);

  /// Replenishment screen: on hand but unusable — why a product with stock is listed.
  ///
  /// In ja, this message translates to:
  /// **'うち出荷不可 {qty}'**
  String replenishmentBlocked(String qty);

  /// Replenishment screen: lead_time_days.
  ///
  /// In ja, this message translates to:
  /// **'リードタイム {days}日'**
  String replenishmentLeadTime(int days);

  /// Replenishment screen: the list is per warehouse.
  ///
  /// In ja, this message translates to:
  /// **'倉庫を選ぶと表示できます'**
  String get replenishmentNoWarehouse;

  /// Title of the exception queue screen (0071).
  ///
  /// In ja, this message translates to:
  /// **'例外・不一致'**
  String get exceptionsTitle;

  /// Exception queue: nothing open, which is the good state.
  ///
  /// In ja, this message translates to:
  /// **'未処理の例外はありません'**
  String get exceptionsEmpty;

  /// Exception queue: what will appear here.
  ///
  /// In ja, this message translates to:
  /// **'入荷・検品・格納で不一致が出ると、ここに並びます。'**
  String get exceptionsEmptyBody;

  /// Exception queue with no active warehouse.
  ///
  /// In ja, this message translates to:
  /// **'倉庫を選ぶと表示できます'**
  String get exceptionsNoWarehouse;

  /// Exception queue filter: every stage.
  ///
  /// In ja, this message translates to:
  /// **'すべての工程'**
  String get exceptionsAllCategories;

  /// Exception category: receiving.
  ///
  /// In ja, this message translates to:
  /// **'入荷'**
  String get exceptionCategoryReceiving;

  /// Exception category: QC.
  ///
  /// In ja, this message translates to:
  /// **'検品'**
  String get exceptionCategoryQc;

  /// Exception category: put-away.
  ///
  /// In ja, this message translates to:
  /// **'格納'**
  String get exceptionCategoryPutaway;

  /// Exception queue toggle: include resolved and cancelled.
  ///
  /// In ja, this message translates to:
  /// **'対応済みも表示'**
  String get exceptionShowClosed;

  /// Exception severity: blocks work.
  ///
  /// In ja, this message translates to:
  /// **'要対応'**
  String get exceptionSeverityBlocker;

  /// Exception severity: worth attention.
  ///
  /// In ja, this message translates to:
  /// **'注意'**
  String get exceptionSeverityWarning;

  /// Exception severity: for information.
  ///
  /// In ja, this message translates to:
  /// **'参考'**
  String get exceptionSeverityInfo;

  /// Exception action: mark as seen.
  ///
  /// In ja, this message translates to:
  /// **'確認した'**
  String get exceptionAcknowledge;

  /// Exception state: seen but not yet dealt with.
  ///
  /// In ja, this message translates to:
  /// **'確認済み'**
  String get exceptionAcknowledged;

  /// Exception action: record what was decided.
  ///
  /// In ja, this message translates to:
  /// **'対応を記録'**
  String get exceptionResolve;

  /// Exception state: dealt with.
  ///
  /// In ja, this message translates to:
  /// **'対応済み'**
  String get exceptionResolved;

  /// Exception state: raised in error.
  ///
  /// In ja, this message translates to:
  /// **'取消'**
  String get exceptionCancelled;

  /// Title of the resolve-exception sheet.
  ///
  /// In ja, this message translates to:
  /// **'対応を記録する'**
  String get exceptionResolveTitle;

  /// Resolve sheet: the decision field.
  ///
  /// In ja, this message translates to:
  /// **'対応'**
  String get exceptionResolutionLabel;

  /// Resolution: accept the discrepancy as it stands.
  ///
  /// In ja, this message translates to:
  /// **'受入（このまま確定）'**
  String get exceptionResolutionAccepted;

  /// Resolution: take it up with the supplier.
  ///
  /// In ja, this message translates to:
  /// **'仕入先へ連絡'**
  String get exceptionResolutionSupplierClaim;

  /// Resolution: the goods went back.
  ///
  /// In ja, this message translates to:
  /// **'返送した'**
  String get exceptionResolutionReturned;

  /// Resolution: the goods were scrapped.
  ///
  /// In ja, this message translates to:
  /// **'廃棄した'**
  String get exceptionResolutionScrapped;

  /// Resolution: the entry was wrong and was fixed.
  ///
  /// In ja, this message translates to:
  /// **'入力を訂正した'**
  String get exceptionResolutionCorrected;

  /// Resolution: counted again.
  ///
  /// In ja, this message translates to:
  /// **'再カウントした'**
  String get exceptionResolutionRecounted;

  /// Resolution: nothing to do.
  ///
  /// In ja, this message translates to:
  /// **'対応不要'**
  String get exceptionResolutionNoAction;

  /// Resolve sheet: note field when optional.
  ///
  /// In ja, this message translates to:
  /// **'メモ（任意）'**
  String get exceptionNoteLabel;

  /// Resolve sheet: note field when the server requires one.
  ///
  /// In ja, this message translates to:
  /// **'メモ（必須）'**
  String get exceptionNoteRequiredLabel;

  /// Resolve sheet: note hint.
  ///
  /// In ja, this message translates to:
  /// **'何をしたかを書く'**
  String get exceptionNoteHint;

  /// Resolve sheet: validation when a required note is empty.
  ///
  /// In ja, this message translates to:
  /// **'この対応にはメモが必要です'**
  String get exceptionNoteRequired;

  /// Resolve sheet: recording a decision does not move stock.
  ///
  /// In ja, this message translates to:
  /// **'ここでは対応の記録だけを残します。在庫を動かす場合は在庫調整から行ってください。'**
  String get exceptionStockNotMovedHint;

  /// Exception card: how much the discrepancy is about.
  ///
  /// In ja, this message translates to:
  /// **'数量 {qty}'**
  String exceptionQuantity(int qty);

  /// Exception card: which lot, and when it expires.
  ///
  /// In ja, this message translates to:
  /// **'ロット {lot} / 期限 {expiry}'**
  String exceptionLot(String lot, String expiry);

  /// Exception card: when the exception was raised.
  ///
  /// In ja, this message translates to:
  /// **'{date} 起票'**
  String exceptionRaisedAt(String date);

  /// Exception summary bar when nothing is blocking.
  ///
  /// In ja, this message translates to:
  /// **'未処理 {count} 件'**
  String exceptionOpenCount(int count);

  /// Exception summary bar when something is blocking work.
  ///
  /// In ja, this message translates to:
  /// **'要対応 {blockers} 件（未処理 {open} 件）'**
  String exceptionBlockerCount(int blockers, int open);

  /// Exceptions screen: FAB and sheet action to manually raise a new exception.
  ///
  /// In ja, this message translates to:
  /// **'例外を起票'**
  String get exceptionRaise;

  /// Raise-exception sheet title.
  ///
  /// In ja, this message translates to:
  /// **'例外を起票する'**
  String get exceptionRaiseTitle;

  /// Raise-exception sheet: which kind of exception.
  ///
  /// In ja, this message translates to:
  /// **'種類'**
  String get exceptionRaiseType;

  /// Raise-exception sheet: optional JAN code field.
  ///
  /// In ja, this message translates to:
  /// **'JANコード（任意）'**
  String get exceptionRaiseJanCode;

  /// Raise-exception sheet: optional quantity field.
  ///
  /// In ja, this message translates to:
  /// **'数量（任意）'**
  String get exceptionRaiseQuantity;

  /// Raise-exception sheet: the type vocabulary came back empty.
  ///
  /// In ja, this message translates to:
  /// **'起票できる種類がありません'**
  String get exceptionRaiseNoTypes;

  /// Action to cancel (withdraw) an exception raised in error, distinct from exceptionCancelled (its resulting status label).
  ///
  /// In ja, this message translates to:
  /// **'取り消す'**
  String get exceptionCancel;

  /// Cancel-exception confirmation dialog title.
  ///
  /// In ja, this message translates to:
  /// **'この例外を取り消しますか？'**
  String get exceptionCancelTitle;

  /// Cancel-exception confirmation dialog body.
  ///
  /// In ja, this message translates to:
  /// **'誤って起票した場合に使います。対応の記録は残りません。'**
  String get exceptionCancelBody;

  /// Cancel-exception dialog: optional reason field.
  ///
  /// In ja, this message translates to:
  /// **'理由（任意）'**
  String get exceptionCancelReasonLabel;

  /// Menu entry: the exception queue (0071).
  ///
  /// In ja, this message translates to:
  /// **'例外対応'**
  String get featExceptions;

  /// Menu entry description for the exception queue.
  ///
  /// In ja, this message translates to:
  /// **'入荷・検品・格納の不一致を確認して対応を記録する'**
  String get featExceptionsDesc;

  /// Title of the held-for-QC stock screen (0068).
  ///
  /// In ja, this message translates to:
  /// **'出荷できない在庫'**
  String get heldStockTitle;

  /// Held-stock screen: nothing held, which is the good state.
  ///
  /// In ja, this message translates to:
  /// **'出荷できない在庫はありません'**
  String get heldStockEmpty;

  /// Held-stock screen: what appears here and why it matters.
  ///
  /// In ja, this message translates to:
  /// **'検品待ち・保留・隔離・破損などの在庫はここに並びます。出荷はできません。'**
  String get heldStockEmptyBody;

  /// Held-stock screen with no active warehouse.
  ///
  /// In ja, this message translates to:
  /// **'倉庫を選ぶと表示できます'**
  String get heldStockNoWarehouse;

  /// Inspection detail: heading for what completing moved.
  ///
  /// In ja, this message translates to:
  /// **'在庫への反映'**
  String get qcEffectTitle;

  /// Inspection detail: completing moved no stock at all.
  ///
  /// In ja, this message translates to:
  /// **'検品対象が検品待ち在庫になかったため、在庫は動いていません。'**
  String get qcEffectNothingMoved;

  /// Menu entry: stock held for QC.
  ///
  /// In ja, this message translates to:
  /// **'検品待ち在庫'**
  String get featHeldStock;

  /// Menu entry description for held-for-QC stock.
  ///
  /// In ja, this message translates to:
  /// **'検品が終わるまで出荷できない在庫を確認する'**
  String get featHeldStockDesc;

  /// Held-stock screen: the headline total.
  ///
  /// In ja, this message translates to:
  /// **'合計 {units} 点（{parcels} 明細）が出荷できません'**
  String heldStockTotal(int units, int parcels);

  /// Held-stock card: how much is held.
  ///
  /// In ja, this message translates to:
  /// **'{qty} 点'**
  String heldStockQuantity(int qty);

  /// Held-stock card: which lot.
  ///
  /// In ja, this message translates to:
  /// **'ロット {lot}'**
  String heldStockLot(String lot);

  /// Held-stock card: the expiry date.
  ///
  /// In ja, this message translates to:
  /// **'期限 {date}'**
  String heldStockExpiry(String date);

  /// Held-stock card: how long it has been waiting.
  ///
  /// In ja, this message translates to:
  /// **'{days}日経過'**
  String heldStockDays(int days);

  /// Inspection detail: what completing will do, shown before the operator taps.
  ///
  /// In ja, this message translates to:
  /// **'確定すると不合格 {qty} 点は出荷できない在庫に移ります'**
  String qcWillHold(int qty);

  /// Inspection detail: quantity released to OK.
  ///
  /// In ja, this message translates to:
  /// **'合格 {qty} 点を出荷可能にしました'**
  String qcEffectReleased(int qty);

  /// Inspection detail: quantity held, and which status it went to.
  ///
  /// In ja, this message translates to:
  /// **'不合格 {qty} 点を {status} に移しました'**
  String qcEffectHeld(int qty, String status);

  /// Inspection detail: judged quantity that was never in QC_PENDING.
  ///
  /// In ja, this message translates to:
  /// **'うち {qty} 点は検品待ち在庫に無く、在庫は動いていません'**
  String qcEffectNotHeld(int qty);

  /// Put-away queue: a parcel with no bin available at all.
  ///
  /// In ja, this message translates to:
  /// **'この倉庫に置ける棚が見つかりません'**
  String get putawayNoSuggestionBody;

  /// Put-away queue: held stock with no bin allowed to hold it.
  ///
  /// In ja, this message translates to:
  /// **'出荷できない在庫を置ける棚（検品保留・破損など）がありません'**
  String get putawayNoHeldBin;

  /// Put-away queue: which lot the parcel is on.
  ///
  /// In ja, this message translates to:
  /// **'ロット {lot}'**
  String putawayLot(String lot);

  /// Title of the sheet that records one receiving parcel (§12).
  ///
  /// In ja, this message translates to:
  /// **'パーセルを記録'**
  String get parcelAddTitle;

  /// Action: add a parcel to a receiving line.
  ///
  /// In ja, this message translates to:
  /// **'パーセル追加'**
  String get parcelAdd;

  /// Action: remove a recorded parcel.
  ///
  /// In ja, this message translates to:
  /// **'このパーセルを削除'**
  String get parcelRemove;

  /// Parcel sheet: quantity field.
  ///
  /// In ja, this message translates to:
  /// **'数量'**
  String get parcelQuantity;

  /// Parcel sheet: quantity validation.
  ///
  /// In ja, this message translates to:
  /// **'数量を入力してください'**
  String get parcelQuantityRequired;

  /// Parcel sheet: lot field.
  ///
  /// In ja, this message translates to:
  /// **'ロット番号（任意）'**
  String get parcelLot;

  /// Parcel sheet: lot hint.
  ///
  /// In ja, this message translates to:
  /// **'箱に書かれているロット'**
  String get parcelLotHint;

  /// Parcel sheet: expiry field.
  ///
  /// In ja, this message translates to:
  /// **'期限（任意）'**
  String get parcelExpiry;

  /// Parcel sheet: no expiry entered.
  ///
  /// In ja, this message translates to:
  /// **'未入力'**
  String get parcelExpiryNone;

  /// Parcel sheet: serial field.
  ///
  /// In ja, this message translates to:
  /// **'シリアル番号（任意）'**
  String get parcelSerial;

  /// Parcel sheet: a serial means quantity one.
  ///
  /// In ja, this message translates to:
  /// **'シリアルを入れる場合は数量1'**
  String get parcelSerialHelp;

  /// Parcel sheet: validation when a serial carries more than one.
  ///
  /// In ja, this message translates to:
  /// **'シリアルは1点ごとに記録します'**
  String get parcelSerialIsOne;

  /// Parcel sheet: location field.
  ///
  /// In ja, this message translates to:
  /// **'置いた場所（任意）'**
  String get parcelLocation;

  /// Parcel sheet: location hint.
  ///
  /// In ja, this message translates to:
  /// **'棚やエリアのコード'**
  String get parcelLocationHint;

  /// Parcel sheet: the carton arrived damaged.
  ///
  /// In ja, this message translates to:
  /// **'到着時に破損していた'**
  String get parcelDamaged;

  /// Parcel sheet: what recording damage does.
  ///
  /// In ja, this message translates to:
  /// **'破損として記録します。出荷はできません。'**
  String get parcelDamagedHelp;

  /// Parcel sheet: note field.
  ///
  /// In ja, this message translates to:
  /// **'メモ（任意）'**
  String get parcelNote;

  /// Receiving line: nothing attributed to a lot or serial yet.
  ///
  /// In ja, this message translates to:
  /// **'ロット・シリアル未記録'**
  String get parcelNoneYet;

  /// Receiving line: every counted unit is on a parcel.
  ///
  /// In ja, this message translates to:
  /// **'全数記録済み'**
  String get parcelAllAttributed;

  /// Receiving line: how much of the count is not yet on a parcel.
  ///
  /// In ja, this message translates to:
  /// **'未記録 {qty}'**
  String parcelUnattributed(int qty);

  /// Receiving line: the disagreement the server refuses.
  ///
  /// In ja, this message translates to:
  /// **'パーセル合計 {parcelled} が計上数 {counted} を超えています'**
  String parcelOverLine(int parcelled, int counted);

  /// Parcel row: compact lot label.
  ///
  /// In ja, this message translates to:
  /// **'L:{lot}'**
  String parcelLotShort(String lot);

  /// Receipt detail screen: tooltip for adding a parcel to an existing line by hand (record_receipt_item).
  ///
  /// In ja, this message translates to:
  /// **'パーセルを追加'**
  String get receiptAddParcelTooltip;

  /// Title of the receipt detail screen (§12, 0067).
  ///
  /// In ja, this message translates to:
  /// **'入荷明細'**
  String get receiptDetailTitle;

  /// Receipt line: nothing was attributed to a lot or serial.
  ///
  /// In ja, this message translates to:
  /// **'ロット・シリアル未記録'**
  String get receiptLineNoParcels;

  /// Receipt parcel: the remainder with no lot recorded.
  ///
  /// In ja, this message translates to:
  /// **'ロット未記録分'**
  String get receiptParcelUnattributed;

  /// Receipt detail: parcels belonging to no ordered line.
  ///
  /// In ja, this message translates to:
  /// **'予定外の入荷'**
  String get receiptUnlinkedTitle;

  /// Receipt detail: what the unlinked section holds.
  ///
  /// In ja, this message translates to:
  /// **'発注明細に紐づかないパーセルです。'**
  String get receiptUnlinkedBody;

  /// Receipt detail: total units received.
  ///
  /// In ja, this message translates to:
  /// **'合計 {units} 点'**
  String receiptTotalUnits(int units);

  /// Receipt detail: how much of the receipt is held (§13).
  ///
  /// In ja, this message translates to:
  /// **'うち {units} 点は出荷できません'**
  String receiptHeldUnits(int units);

  /// Receipt detail line: planned against received.
  ///
  /// In ja, this message translates to:
  /// **'予定 {planned} / 実績 {actual}'**
  String receiptLinePlannedActual(int planned, int actual);

  /// Receipt parcel: which lot.
  ///
  /// In ja, this message translates to:
  /// **'ロット {lot}'**
  String receiptParcelLot(String lot);

  /// Receipt parcel: the expiry date.
  ///
  /// In ja, this message translates to:
  /// **'期限 {date}'**
  String receiptParcelExpiry(String date);

  /// Receipt parcel: the ledger row this parcel posted (§5).
  ///
  /// In ja, this message translates to:
  /// **'在庫履歴 #{id}'**
  String receiptParcelMovement(int id);

  /// Attachment kind: a plain photo.
  ///
  /// In ja, this message translates to:
  /// **'写真'**
  String get attachmentKindPhoto;

  /// Attachment kind: the supplier's delivery note.
  ///
  /// In ja, this message translates to:
  /// **'納品書'**
  String get attachmentKindDeliveryNote;

  /// Attachment kind: a photo taken during QC.
  ///
  /// In ja, this message translates to:
  /// **'検品写真'**
  String get attachmentKindQcImage;

  /// Attachment kind: evidence of damage.
  ///
  /// In ja, this message translates to:
  /// **'破損写真'**
  String get attachmentKindDamage;

  /// Attachment kind: a document.
  ///
  /// In ja, this message translates to:
  /// **'書類'**
  String get attachmentKindDocument;

  /// Attachment kind: a label or barcode image.
  ///
  /// In ja, this message translates to:
  /// **'ラベル'**
  String get attachmentKindLabel;

  /// Attachment kind: anything else.
  ///
  /// In ja, this message translates to:
  /// **'その他'**
  String get attachmentKindOther;

  /// Attachment action: withdraw the file (not delete).
  ///
  /// In ja, this message translates to:
  /// **'取り下げ'**
  String get attachmentWithdraw;

  /// Attachment withdraw confirmation title.
  ///
  /// In ja, this message translates to:
  /// **'この添付を取り下げますか？'**
  String get attachmentWithdrawQ;

  /// Attachment withdraw confirmation body: withdrawn, not deleted (0070).
  ///
  /// In ja, this message translates to:
  /// **'一覧からは外れますが、記録としては残ります。'**
  String get attachmentWithdrawBody;

  /// Attachment withdraw success message.
  ///
  /// In ja, this message translates to:
  /// **'添付を取り下げました'**
  String get attachmentWithdrawn;

  /// Badge on a withdrawn attachment.
  ///
  /// In ja, this message translates to:
  /// **'取り下げ済み'**
  String get attachmentWithdrawnBadge;

  /// Attachment file size in kilobytes.
  ///
  /// In ja, this message translates to:
  /// **'{kb} KB'**
  String attachmentSize(int kb);

  /// Shown when an attachment has no caption.
  ///
  /// In ja, this message translates to:
  /// **'説明なし'**
  String get attachmentNoCaption;

  /// Sales order approved, all lines reserved.
  ///
  /// In ja, this message translates to:
  /// **'受注を承認しました（引当 {reserved} 件）'**
  String soApprovedWithReservations(int reserved);

  /// Sales order approved, some lines could not be reserved.
  ///
  /// In ja, this message translates to:
  /// **'受注を承認しました（引当 {reserved} 件・未引当 {skipped} 件）'**
  String soApprovedWithSkips(int reserved, int skipped);

  /// Action on the approval snackbar: show which lines were not reserved.
  ///
  /// In ja, this message translates to:
  /// **'詳細'**
  String get soApprovalSkipDetail;

  /// Dialog title listing lines approval could not reserve stock for.
  ///
  /// In ja, this message translates to:
  /// **'引当できなかった明細'**
  String get soSkippedLinesTitle;

  /// Approval skip reason: unlinked_jan_code.
  ///
  /// In ja, this message translates to:
  /// **'商品が未登録です'**
  String get soSkipUnlinkedJan;

  /// Approval skip reason: insufficient_available.
  ///
  /// In ja, this message translates to:
  /// **'在庫が不足しています（在庫 {available} / 必要 {requested}）'**
  String soSkipInsufficientAvailable(int available, int requested);

  /// Section heading: the reservations backing this order (§6).
  ///
  /// In ja, this message translates to:
  /// **'引当状況'**
  String get soReservationsTitle;

  /// Reservation status: fully shipped.
  ///
  /// In ja, this message translates to:
  /// **'出荷済み'**
  String get soReservationFulfilled;

  /// Action: turn an approved sales order into a shipment (0073).
  ///
  /// In ja, this message translates to:
  /// **'出荷を作成'**
  String get soCreateShipment;

  /// Confirmation body for creating a shipment from a sales order.
  ///
  /// In ja, this message translates to:
  /// **'この受注から出荷を作成しますか？'**
  String get soCreateShipmentQ;

  /// Success message after creating a shipment from a sales order.
  ///
  /// In ja, this message translates to:
  /// **'出荷を作成しました（明細 {lines} 件）'**
  String soShipmentCreated(int lines);

  /// Action: open the shipment this sales order already became.
  ///
  /// In ja, this message translates to:
  /// **'出荷を開く'**
  String get soOpenShipment;

  /// Home menu label: pick waves (§15, 0077).
  ///
  /// In ja, this message translates to:
  /// **'ウェーブピッキング'**
  String get featWave;

  /// Home menu one-line description for wave picking.
  ///
  /// In ja, this message translates to:
  /// **'複数の出荷をまとめて1回の巡回でピッキング'**
  String get featWaveDesc;

  /// Wave list screen title.
  ///
  /// In ja, this message translates to:
  /// **'ウェーブピッキング'**
  String get waveListTitle;

  /// Wave list empty state title.
  ///
  /// In ja, this message translates to:
  /// **'ウェーブがまだありません'**
  String get waveEmpty;

  /// Wave list empty state body.
  ///
  /// In ja, this message translates to:
  /// **'複数の出荷をまとめて、一度の巡回でピッキングできます。'**
  String get waveEmptyBody;

  /// Action: build a new pick wave from several shipments.
  ///
  /// In ja, this message translates to:
  /// **'ウェーブを作成'**
  String get waveCreate;

  /// Wave creation: pick which shipments to group.
  ///
  /// In ja, this message translates to:
  /// **'出荷を選択（複数可）'**
  String get waveChooseShipments;

  /// No open shipments available to build a wave from.
  ///
  /// In ja, this message translates to:
  /// **'対象の出荷がありません'**
  String get waveNoShipments;

  /// Wave creation validation: nothing selected.
  ///
  /// In ja, this message translates to:
  /// **'出荷を1件以上選択してください'**
  String get waveSelectAtLeastOne;

  /// Wave created successfully.
  ///
  /// In ja, this message translates to:
  /// **'ウェーブ {code} を作成しました（{lists} 件の出荷）'**
  String waveCreated(String code, int lists);

  /// Wave created, some shipments could not join.
  ///
  /// In ja, this message translates to:
  /// **'ウェーブ {code} を作成しました（{lists} 件・対象外 {skipped} 件）'**
  String waveCreatedWithSkips(String code, int lists, int skipped);

  /// Wave status: OPEN.
  ///
  /// In ja, this message translates to:
  /// **'未着手'**
  String get waveStatusOpen;

  /// Wave status: PICKING.
  ///
  /// In ja, this message translates to:
  /// **'作業中'**
  String get waveStatusPicking;

  /// Wave status: DONE.
  ///
  /// In ja, this message translates to:
  /// **'完了'**
  String get waveStatusDone;

  /// Wave status: CANCELLED.
  ///
  /// In ja, this message translates to:
  /// **'取消'**
  String get waveStatusCancelled;

  /// Wave progress: tasks picked over total.
  ///
  /// In ja, this message translates to:
  /// **'{picked} / {total} 明細'**
  String waveListsProgress(int picked, int total);

  /// No one is assigned to this wave yet.
  ///
  /// In ja, this message translates to:
  /// **'未担当'**
  String get waveUnassigned;

  /// Action: take this wave.
  ///
  /// In ja, this message translates to:
  /// **'自分が担当する'**
  String get waveAssignToMe;

  /// Action: hand the wave back to the pool.
  ///
  /// In ja, this message translates to:
  /// **'担当を解除'**
  String get waveUnassign;

  /// Action: open the aggregated pick sheet for this wave.
  ///
  /// In ja, this message translates to:
  /// **'ピッキング表を見る'**
  String get waveViewSheet;

  /// The aggregated sheet screen title — one stop per place, not per order.
  ///
  /// In ja, this message translates to:
  /// **'ピッキング表'**
  String get waveSheetTitle;

  /// Wave sheet empty state.
  ///
  /// In ja, this message translates to:
  /// **'ピッキング可能な明細がありません'**
  String get waveSheetEmpty;

  /// Total units across the wave's sheet.
  ///
  /// In ja, this message translates to:
  /// **'合計 {total} 点'**
  String waveSheetTotalUnits(int total);

  /// How many distinct orders one stop's units are for.
  ///
  /// In ja, this message translates to:
  /// **'{count} 件の出荷向け'**
  String waveSheetForOrders(int count);

  /// Section heading: what the wave could not cover.
  ///
  /// In ja, this message translates to:
  /// **'不足分'**
  String get waveShortfallTitle;

  /// How many units short one line is.
  ///
  /// In ja, this message translates to:
  /// **'{short} 点不足'**
  String waveShortfallUnits(int short);

  /// Section heading: the shipments' pick lists this wave groups.
  ///
  /// In ja, this message translates to:
  /// **'含まれる出荷'**
  String get waveLists;

  /// Action: close every list in this wave.
  ///
  /// In ja, this message translates to:
  /// **'ウェーブを完了'**
  String get waveComplete;

  /// Confirmation body for completing a wave.
  ///
  /// In ja, this message translates to:
  /// **'このウェーブを完了しますか？含まれる出荷はすべて確定します。'**
  String get waveCompleteQ;

  /// Wave completed successfully.
  ///
  /// In ja, this message translates to:
  /// **'ウェーブを完了しました（{count} 件）'**
  String waveCompleted(int count);

  /// A wave with unpicked tasks cannot be completed.
  ///
  /// In ja, this message translates to:
  /// **'未ピックの明細が残っています'**
  String get waveIncomplete;

  /// Action: cancel the wave, releasing its shipments.
  ///
  /// In ja, this message translates to:
  /// **'ウェーブを取消'**
  String get waveCancelAction;

  /// Confirmation body for cancelling a wave.
  ///
  /// In ja, this message translates to:
  /// **'このウェーブを取り消しますか？含まれる出荷は解放され、記録済みのピックはそのまま残ります。'**
  String get waveCancelQ;

  /// Wave cancelled successfully.
  ///
  /// In ja, this message translates to:
  /// **'ウェーブを取り消しました'**
  String get waveCancelled;

  /// featDemand
  ///
  /// In ja, this message translates to:
  /// **'受注残・発注'**
  String get featDemand;

  /// featDemandDesc
  ///
  /// In ja, this message translates to:
  /// **'注文に在庫を引当て、足りない分をまとめて発注'**
  String get featDemandDesc;

  /// demandTitle
  ///
  /// In ja, this message translates to:
  /// **'受注残・発注'**
  String get demandTitle;

  /// demandEmpty
  ///
  /// In ja, this message translates to:
  /// **'待っている注文はありません'**
  String get demandEmpty;

  /// demandEmptyBody
  ///
  /// In ja, this message translates to:
  /// **'承認済みの受注のうち、在庫が足りずに引当できなかった分がここに集まります。'**
  String get demandEmptyBody;

  /// demandFillAll
  ///
  /// In ja, this message translates to:
  /// **'在庫からすべて引当'**
  String get demandFillAll;

  /// demandFillAllQ
  ///
  /// In ja, this message translates to:
  /// **'空いている在庫を、承認の古い注文から順に引当てます。よろしいですか？'**
  String get demandFillAllQ;

  /// demandNothingToFill
  ///
  /// In ja, this message translates to:
  /// **'引当できる在庫がありません'**
  String get demandNothingToFill;

  /// demandFilled
  ///
  /// In ja, this message translates to:
  /// **'{units} 個を引当しました'**
  String demandFilled(int units);

  /// demandPoCreated
  ///
  /// In ja, this message translates to:
  /// **'発注を作成しました（{links} 件の注文に紐付け）'**
  String demandPoCreated(int links);

  /// demandCreatePo
  ///
  /// In ja, this message translates to:
  /// **'発注を作成（{count} 品目）'**
  String demandCreatePo(int count);

  /// demandBackordered
  ///
  /// In ja, this message translates to:
  /// **'受注残'**
  String get demandBackordered;

  /// demandCanFillNow
  ///
  /// In ja, this message translates to:
  /// **'今すぐ引当可'**
  String get demandCanFillNow;

  /// demandIncoming
  ///
  /// In ja, this message translates to:
  /// **'入荷予定'**
  String get demandIncoming;

  /// demandToPurchase
  ///
  /// In ja, this message translates to:
  /// **'要発注'**
  String get demandToPurchase;

  /// demandAvailable
  ///
  /// In ja, this message translates to:
  /// **'空き在庫'**
  String get demandAvailable;

  /// demandNeedsPurchase
  ///
  /// In ja, this message translates to:
  /// **'要発注 {count}'**
  String demandNeedsPurchase(int count);

  /// demandFillable
  ///
  /// In ja, this message translates to:
  /// **'引当可 {count}'**
  String demandFillable(int count);

  /// demandCovered
  ///
  /// In ja, this message translates to:
  /// **'手配済み'**
  String get demandCovered;

  /// demandFillNow
  ///
  /// In ja, this message translates to:
  /// **'在庫から引当（{count}）'**
  String demandFillNow(int count);

  /// demandWaitingOrders
  ///
  /// In ja, this message translates to:
  /// **'待っている注文 {count} 件'**
  String demandWaitingOrders(int count);

  /// demandLineStatus
  ///
  /// In ja, this message translates to:
  /// **'受注 {ordered} ・引当 {promised} ・残 {backordered} ・発注中 {onOrder}'**
  String demandLineStatus(
      int ordered, int promised, int backordered, int onOrder);

  /// demandLineFill
  ///
  /// In ja, this message translates to:
  /// **'この注文に引当'**
  String get demandLineFill;

  /// demandLineFillQuantity
  ///
  /// In ja, this message translates to:
  /// **'引当数'**
  String get demandLineFillQuantity;

  /// demandLineFillMax
  ///
  /// In ja, this message translates to:
  /// **'最大 {max}'**
  String demandLineFillMax(int max);

  /// demandPoTitle
  ///
  /// In ja, this message translates to:
  /// **'受注残から発注'**
  String get demandPoTitle;

  /// demandPoHint
  ///
  /// In ja, this message translates to:
  /// **'数量は要発注数が初期値です。少なく発注しても構いません — 足りない分は別の手配で補えます。'**
  String get demandPoHint;

  /// demandPoLineHint
  ///
  /// In ja, this message translates to:
  /// **'受注残 {backordered} ・要発注 {toPurchase}'**
  String demandPoLineHint(int backordered, int toPurchase);

  /// demandQuantity
  ///
  /// In ja, this message translates to:
  /// **'発注数'**
  String get demandQuantity;

  /// demandOrdered
  ///
  /// In ja, this message translates to:
  /// **'受注'**
  String get demandOrdered;

  /// demandPromised
  ///
  /// In ja, this message translates to:
  /// **'引当済'**
  String get demandPromised;

  /// demandShipped
  ///
  /// In ja, this message translates to:
  /// **'出荷済'**
  String get demandShipped;

  /// soSkipPartial
  ///
  /// In ja, this message translates to:
  /// **'引当 {reserved} ・受注残 {backordered}'**
  String soSkipPartial(int reserved, int backordered);

  /// soCreateShipmentReadyQ
  ///
  /// In ja, this message translates to:
  /// **'引当済みで未出荷の {units} 個を出荷に載せます。よろしいですか？'**
  String soCreateShipmentReadyQ(int units);

  /// soShipRemaining
  ///
  /// In ja, this message translates to:
  /// **'残りを出荷'**
  String get soShipRemaining;

  /// soFillFromStock
  ///
  /// In ja, this message translates to:
  /// **'在庫から引当'**
  String get soFillFromStock;

  /// soMoreActions
  ///
  /// In ja, this message translates to:
  /// **'その他の操作'**
  String get soMoreActions;

  /// soReadyToShip
  ///
  /// In ja, this message translates to:
  /// **'出荷待ち'**
  String get soReadyToShip;

  /// soShipments
  ///
  /// In ja, this message translates to:
  /// **'出荷'**
  String get soShipments;

  /// soShipmentShipped
  ///
  /// In ja, this message translates to:
  /// **'出荷済み'**
  String get soShipmentShipped;

  /// soShipmentOpen
  ///
  /// In ja, this message translates to:
  /// **'作業中'**
  String get soShipmentOpen;

  /// soLineUnlinked
  ///
  /// In ja, this message translates to:
  /// **'商品ライブラリー未登録のため引当できません'**
  String get soLineUnlinked;

  /// soLineOnOrder
  ///
  /// In ja, this message translates to:
  /// **'発注中 {count}'**
  String soLineOnOrder(int count);

  /// soFillLine
  ///
  /// In ja, this message translates to:
  /// **'この明細に引当'**
  String get soFillLine;

  /// poCreateRemainingDeliveryPlan
  ///
  /// In ja, this message translates to:
  /// **'残りの入荷予定を作成'**
  String get poCreateRemainingDeliveryPlan;

  /// poDeliveryPlans
  ///
  /// In ja, this message translates to:
  /// **'入荷予定'**
  String get poDeliveryPlans;

  /// poPlanReceived
  ///
  /// In ja, this message translates to:
  /// **'入荷済み'**
  String get poPlanReceived;

  /// poPlanOpen
  ///
  /// In ja, this message translates to:
  /// **'入荷待ち'**
  String get poPlanOpen;

  /// poLinePlanned
  ///
  /// In ja, this message translates to:
  /// **'入荷予定'**
  String get poLinePlanned;

  /// poLineReceived
  ///
  /// In ja, this message translates to:
  /// **'入荷済'**
  String get poLineReceived;

  /// poLineOutstanding
  ///
  /// In ja, this message translates to:
  /// **'未入荷'**
  String get poLineOutstanding;

  /// poLineForOrders
  ///
  /// In ja, this message translates to:
  /// **'この発注の対象の受注'**
  String get poLineForOrders;

  /// reconOpenPurchaseOrder
  ///
  /// In ja, this message translates to:
  /// **'発注を開く'**
  String get reconOpenPurchaseOrder;

  /// reconLinkPurchaseOrder
  ///
  /// In ja, this message translates to:
  /// **'発注に紐付け'**
  String get reconLinkPurchaseOrder;

  /// reconNoPurchaseOrderToLink
  ///
  /// In ja, this message translates to:
  /// **'紐付けできる発注がありません'**
  String get reconNoPurchaseOrderToLink;

  /// reconLinkedPurchaseOrder
  ///
  /// In ja, this message translates to:
  /// **'{number} に紐付けました'**
  String reconLinkedPurchaseOrder(String number);

  /// reservationAllocatedShort
  ///
  /// In ja, this message translates to:
  /// **'{allocated} 個を割当（{short} 個は在庫が見つかりません）'**
  String reservationAllocatedShort(int allocated, int short);

  /// reservationAllocatedDone
  ///
  /// In ja, this message translates to:
  /// **'{allocated} 個を割当しました'**
  String reservationAllocatedDone(int allocated);

  /// reservationManualNoProduct
  ///
  /// In ja, this message translates to:
  /// **'JAN {jan} の商品が見つかりません'**
  String reservationManualNoProduct(String jan);

  /// reservationManualCreated
  ///
  /// In ja, this message translates to:
  /// **'引当を作成しました'**
  String get reservationManualCreated;

  /// reservationManualAdd
  ///
  /// In ja, this message translates to:
  /// **'手動で引当'**
  String get reservationManualAdd;

  /// reservationReleaseAllocation
  ///
  /// In ja, this message translates to:
  /// **'割当を外す'**
  String get reservationReleaseAllocation;

  /// reservationAllocate
  ///
  /// In ja, this message translates to:
  /// **'ロットを割当'**
  String get reservationAllocate;

  /// reservationManualNote
  ///
  /// In ja, this message translates to:
  /// **'用途・メモ'**
  String get reservationManualNote;

  /// reservationManualSubmit
  ///
  /// In ja, this message translates to:
  /// **'引当する'**
  String get reservationManualSubmit;

  /// demandPoNeedSupplier
  ///
  /// In ja, this message translates to:
  /// **'仕入先名を入力してください'**
  String get demandPoNeedSupplier;

  /// demandPoOverLinked
  ///
  /// In ja, this message translates to:
  /// **'紐付け {linked} が発注数 {quantity} を超えています'**
  String demandPoOverLinked(int linked, int quantity);

  /// demandPoLineOverLinked
  ///
  /// In ja, this message translates to:
  /// **'この注文の受注残 {backordered} を超えています'**
  String demandPoLineOverLinked(int backordered);

  /// demandPoCreateN
  ///
  /// In ja, this message translates to:
  /// **'発注を作成（{count} 社）'**
  String demandPoCreateN(int count);

  /// demandPoProductHint
  ///
  /// In ja, this message translates to:
  /// **'受注残 {backordered} ・要発注 {toPurchase} ・入荷予定 {incoming}'**
  String demandPoProductHint(int backordered, int toPurchase, int incoming);

  /// demandPoProductTotal
  ///
  /// In ja, this message translates to:
  /// **'この商品の発注合計 {total}'**
  String demandPoProductTotal(int total);

  /// demandPoSplitSupplier
  ///
  /// In ja, this message translates to:
  /// **'仕入先を分ける'**
  String get demandPoSplitSupplier;

  /// demandPoRemoveRow
  ///
  /// In ja, this message translates to:
  /// **'この仕入先を外す'**
  String get demandPoRemoveRow;

  /// demandPoLinksTitle
  ///
  /// In ja, this message translates to:
  /// **'この発注をどの注文に充てるか'**
  String get demandPoLinksTitle;

  /// demandPoAutoLink
  ///
  /// In ja, this message translates to:
  /// **'古い順に自動で割り振り'**
  String get demandPoAutoLink;

  /// demandPoNoWaiting
  ///
  /// In ja, this message translates to:
  /// **'待っている注文はありません — すべて見込みになります'**
  String get demandPoNoWaiting;

  /// demandPoLineWaiting
  ///
  /// In ja, this message translates to:
  /// **'受注残 {backordered} ・発注中 {onOrder}'**
  String demandPoLineWaiting(int backordered, int onOrder);

  /// demandPoRowSummary
  ///
  /// In ja, this message translates to:
  /// **'紐付け {linked} ・見込み（紐付けなし）{ahead}'**
  String demandPoRowSummary(int linked, int ahead);

  /// demandPosCreated
  ///
  /// In ja, this message translates to:
  /// **'発注を {count} 件作成しました'**
  String demandPosCreated(int count);

  /// demandAheadOnly
  ///
  /// In ja, this message translates to:
  /// **'見込みのみ'**
  String get demandAheadOnly;

  /// demandIncomingBreakdown
  ///
  /// In ja, this message translates to:
  /// **'入荷予定 {incoming}（仕入先別）'**
  String demandIncomingBreakdown(int incoming);

  /// demandIncomingBreakdownAhead
  ///
  /// In ja, this message translates to:
  /// **'入荷予定 {incoming}（うち見込み {ahead}）'**
  String demandIncomingBreakdownAhead(int incoming, int ahead);

  /// demandIncomingPo
  ///
  /// In ja, this message translates to:
  /// **'残 {outstanding}'**
  String demandIncomingPo(int outstanding);

  /// demandIncomingPoAhead
  ///
  /// In ja, this message translates to:
  /// **'残 {outstanding}（見込み {ahead}）'**
  String demandIncomingPoAhead(int outstanding, int ahead);

  /// demandIncomingAhead
  ///
  /// In ja, this message translates to:
  /// **'見込み入荷'**
  String get demandIncomingAhead;

  /// poLinkEditTitle
  ///
  /// In ja, this message translates to:
  /// **'受注との紐付け'**
  String get poLinkEditTitle;

  /// poLinkOverOrdered
  ///
  /// In ja, this message translates to:
  /// **'この注文の受注数 {ordered} を超えています'**
  String poLinkOverOrdered(int ordered);

  /// poLinkSaved
  ///
  /// In ja, this message translates to:
  /// **'紐付けを保存しました（紐付け {linked}・入荷分から引当 {reserved}・解除 {released}）'**
  String poLinkSaved(int linked, int reserved, int released);

  /// poLinkLineSummary
  ///
  /// In ja, this message translates to:
  /// **'発注 {quantity} ・入荷済 {received}'**
  String poLinkLineSummary(int quantity, int received);

  /// poLinkHint
  ///
  /// In ja, this message translates to:
  /// **'入荷した分は紐付けた注文へ自動で引当てます。紐付けを変えると、この発注から引当てた分も移ります。紐付けない分は見込み在庫として、次の注文に回ります。'**
  String get poLinkHint;

  /// poLinkNoCandidates
  ///
  /// In ja, this message translates to:
  /// **'この商品を待っている承認済みの受注はありません'**
  String get poLinkNoCandidates;

  /// poLinkCandidateStatus
  ///
  /// In ja, this message translates to:
  /// **'受注 {ordered} ・引当 {promised} ・残 {backordered} ・発注中 {onOrder}'**
  String poLinkCandidateStatus(
      int ordered, int promised, int backordered, int onOrder);

  /// poLinkFilled
  ///
  /// In ja, this message translates to:
  /// **'この発注の入荷分から引当済 {filled}'**
  String poLinkFilled(int filled);

  /// poLinkQuantity
  ///
  /// In ja, this message translates to:
  /// **'紐付け数'**
  String get poLinkQuantity;

  /// Link editor: a link cut below what has already been promised from this purchase's arrivals
  ///
  /// In ja, this message translates to:
  /// **'保存すると、この注文に引当済みの {count} 個が解除されます'**
  String poLinkReleaseWarning(int count);

  /// Link editor: confirm dialog title before a save that releases promised stock
  ///
  /// In ja, this message translates to:
  /// **'引当を解除しますか？'**
  String get poLinkReleaseTitle;

  /// Link editor: confirm dialog body explaining where released stock goes
  ///
  /// In ja, this message translates to:
  /// **'入荷済みで引当済みの商品を、次の注文から外します。外した分は他の紐付け先に回り、紐付け先がなければ空き在庫に戻ります。'**
  String get poLinkReleaseBody;

  /// Link editor: one order in the release confirm dialog
  ///
  /// In ja, this message translates to:
  /// **'{order}：{count} 個を解除'**
  String poLinkReleaseLine(String order, int count);

  /// Link editor: confirm button that saves and releases promised stock
  ///
  /// In ja, this message translates to:
  /// **'解除して保存'**
  String get poLinkReleaseConfirm;

  /// poLineLinkedAhead
  ///
  /// In ja, this message translates to:
  /// **'受注に紐付け {linked} ・見込み {ahead}'**
  String poLineLinkedAhead(int linked, int ahead);

  /// poLinkEdit
  ///
  /// In ja, this message translates to:
  /// **'紐付けを編集'**
  String get poLinkEdit;

  /// poDemandFilled
  ///
  /// In ja, this message translates to:
  /// **'（入荷分引当 {filled}）'**
  String poDemandFilled(int filled);

  /// transferStatusExported
  ///
  /// In ja, this message translates to:
  /// **'国外へ出庫済み'**
  String get transferStatusExported;

  /// transferExportBadge
  ///
  /// In ja, this message translates to:
  /// **'国外へ出庫'**
  String get transferExportBadge;

  /// transferCrossBorderExport
  ///
  /// In ja, this message translates to:
  /// **'{country}への国をまたぐ転送です。出庫した時点で在庫から除外され、受入はありません。'**
  String transferCrossBorderExport(String country);

  /// transferCrossBorderReceived
  ///
  /// In ja, this message translates to:
  /// **'{country}の倉庫は国外からの受入を行う設定です。通常の転送と同じく受入まで行います。'**
  String transferCrossBorderReceived(String country);

  /// transferExportNotice
  ///
  /// In ja, this message translates to:
  /// **'国をまたぐ転送：出庫した時点で実在庫から除外され、受入はありません。送った数は「国外倉庫の仮想在庫」に計上されます。'**
  String get transferExportNotice;

  /// transferCrossBorderReceivedNotice
  ///
  /// In ja, this message translates to:
  /// **'国をまたぐ転送：受け入れ先の倉庫が国外からの受入を行う設定のため、受入まで行います。'**
  String get transferCrossBorderReceivedNotice;

  /// transferCompletePickingExportBody
  ///
  /// In ja, this message translates to:
  /// **'{warehouse}から出庫し、国外へ送った分として在庫から除外します。この転送は受入なしで完了します。'**
  String transferCompletePickingExportBody(String warehouse);

  /// whRoleEdit
  ///
  /// In ja, this message translates to:
  /// **'国・役割'**
  String get whRoleEdit;

  /// whRoleSaved
  ///
  /// In ja, this message translates to:
  /// **'倉庫の国・役割を保存しました'**
  String get whRoleSaved;

  /// whRoleCountry
  ///
  /// In ja, this message translates to:
  /// **'国'**
  String get whRoleCountry;

  /// whRoleCountryCode
  ///
  /// In ja, this message translates to:
  /// **'国コード（2文字）'**
  String get whRoleCountryCode;

  /// whRoleReceivesCrossBorder
  ///
  /// In ja, this message translates to:
  /// **'国外からの転送を受け入れて在庫を持つ'**
  String get whRoleReceivesCrossBorder;

  /// whRoleReceivesCrossBorderHint
  ///
  /// In ja, this message translates to:
  /// **'オフのとき、他国の倉庫からこの倉庫への転送は出庫時点で在庫から除外されます。この倉庫から個別のお客さんへ出荷する場合はオンにします。'**
  String get whRoleReceivesCrossBorderHint;

  /// countryJP
  ///
  /// In ja, this message translates to:
  /// **'日本'**
  String get countryJP;

  /// countryCN
  ///
  /// In ja, this message translates to:
  /// **'中国'**
  String get countryCN;

  /// countryOther
  ///
  /// In ja, this message translates to:
  /// **'その他'**
  String get countryOther;

  /// supplierNamesSection
  ///
  /// In ja, this message translates to:
  /// **'仕入先ごとの呼び名'**
  String get supplierNamesSection;

  /// supplierNamesHint
  ///
  /// In ja, this message translates to:
  /// **'仕入先ごとの商品名・品番を登録すると、その呼び名で検索でき、納品書の照合にも使われます。出荷伝票には自社の商品名が印字されます。'**
  String get supplierNamesHint;

  /// supplierNamesEmpty
  ///
  /// In ja, this message translates to:
  /// **'まだ登録がありません'**
  String get supplierNamesEmpty;

  /// supplierNameAdd
  ///
  /// In ja, this message translates to:
  /// **'呼び名を追加'**
  String get supplierNameAdd;

  /// supplierNameEdit
  ///
  /// In ja, this message translates to:
  /// **'呼び名を編集'**
  String get supplierNameEdit;

  /// supplierNameSaved
  ///
  /// In ja, this message translates to:
  /// **'呼び名を保存しました'**
  String get supplierNameSaved;

  /// supplierNameNoSuppliers
  ///
  /// In ja, this message translates to:
  /// **'先に取引先（仕入先）を登録してください'**
  String get supplierNameNoSuppliers;

  /// supplierNameSupplier
  ///
  /// In ja, this message translates to:
  /// **'仕入先'**
  String get supplierNameSupplier;

  /// supplierNameName
  ///
  /// In ja, this message translates to:
  /// **'仕入先での商品名'**
  String get supplierNameName;

  /// supplierNameCode
  ///
  /// In ja, this message translates to:
  /// **'仕入先での品番（任意）'**
  String get supplierNameCode;

  /// supplierNameNote
  ///
  /// In ja, this message translates to:
  /// **'メモ（任意）'**
  String get supplierNameNote;

  /// supplierNameCodeLabel
  ///
  /// In ja, this message translates to:
  /// **'品番 {code}'**
  String supplierNameCodeLabel(String code);

  /// poLineSupplierName
  ///
  /// In ja, this message translates to:
  /// **'仕入先での呼び名：{name}'**
  String poLineSupplierName(String name);

  /// featVirtualStock
  ///
  /// In ja, this message translates to:
  /// **'国外倉庫の仮想在庫'**
  String get featVirtualStock;

  /// featVirtualStockDesc
  ///
  /// In ja, this message translates to:
  /// **'日本から送った数と手入力の実数で、国外倉庫のおおよその在庫を月ごとに見る'**
  String get featVirtualStockDesc;

  /// virtualTitle
  ///
  /// In ja, this message translates to:
  /// **'国外倉庫の仮想在庫'**
  String get virtualTitle;

  /// virtualExplain
  ///
  /// In ja, this message translates to:
  /// **'国外へ送った商品は実在庫からは除外されています。ここは日本からの出荷と手入力の実数による仮想の数で、引当や出荷には使われません。'**
  String get virtualExplain;

  /// virtualNoWarehouse
  ///
  /// In ja, this message translates to:
  /// **'国外の倉庫がありません'**
  String get virtualNoWarehouse;

  /// virtualNoWarehouseBody
  ///
  /// In ja, this message translates to:
  /// **'倉庫の「国・役割」で国を設定すると、ここに表示されます。'**
  String get virtualNoWarehouseBody;

  /// virtualWarehouse
  ///
  /// In ja, this message translates to:
  /// **'倉庫'**
  String get virtualWarehouse;

  /// virtualFromMonth
  ///
  /// In ja, this message translates to:
  /// **'開始月'**
  String get virtualFromMonth;

  /// virtualToMonth
  ///
  /// In ja, this message translates to:
  /// **'終了月'**
  String get virtualToMonth;

  /// virtualRangeTotal
  ///
  /// In ja, this message translates to:
  /// **'{from} 〜 {to} の合計'**
  String virtualRangeTotal(String from, String to);

  /// virtualByMonth
  ///
  /// In ja, this message translates to:
  /// **'月別'**
  String get virtualByMonth;

  /// virtualByProduct
  ///
  /// In ja, this message translates to:
  /// **'商品別'**
  String get virtualByProduct;

  /// virtualEmpty
  ///
  /// In ja, this message translates to:
  /// **'この期間の記録はありません'**
  String get virtualEmpty;

  /// virtualOpening
  ///
  /// In ja, this message translates to:
  /// **'期首'**
  String get virtualOpening;

  /// virtualArrived
  ///
  /// In ja, this message translates to:
  /// **'日本から'**
  String get virtualArrived;

  /// virtualAdjusted
  ///
  /// In ja, this message translates to:
  /// **'手動増減'**
  String get virtualAdjusted;

  /// virtualCountDiff
  ///
  /// In ja, this message translates to:
  /// **'実数との差'**
  String get virtualCountDiff;

  /// virtualClosing
  ///
  /// In ja, this message translates to:
  /// **'期末'**
  String get virtualClosing;

  /// virtualMonth
  ///
  /// In ja, this message translates to:
  /// **'月'**
  String get virtualMonth;

  /// virtualProductLine
  ///
  /// In ja, this message translates to:
  /// **'期首 {opening} ・日本から +{arrived} ・増減 {change}'**
  String virtualProductLine(int opening, int arrived, int change);

  /// virtualLastCount
  ///
  /// In ja, this message translates to:
  /// **'最終実数 {date}：{counted}'**
  String virtualLastCount(String date, int counted);

  /// virtualRecord
  ///
  /// In ja, this message translates to:
  /// **'実数・増減を入力'**
  String get virtualRecord;

  /// virtualRecorded
  ///
  /// In ja, this message translates to:
  /// **'記録しました'**
  String get virtualRecorded;

  /// virtualHistory
  ///
  /// In ja, this message translates to:
  /// **'記録の履歴'**
  String get virtualHistory;

  /// virtualBalanceThatDay
  ///
  /// In ja, this message translates to:
  /// **'その日の数 {balance}'**
  String virtualBalanceThatDay(int balance);

  /// virtualEntryExport
  ///
  /// In ja, this message translates to:
  /// **'日本から +{quantity}（{number}）'**
  String virtualEntryExport(int quantity, String number);

  /// virtualEntryCount
  ///
  /// In ja, this message translates to:
  /// **'実数 {counted}'**
  String virtualEntryCount(int counted);

  /// virtualEntryAdjust
  ///
  /// In ja, this message translates to:
  /// **'増減 {change}'**
  String virtualEntryAdjust(String change);

  /// virtualTypeCount
  ///
  /// In ja, this message translates to:
  /// **'実数'**
  String get virtualTypeCount;

  /// virtualTypeAdjust
  ///
  /// In ja, this message translates to:
  /// **'増減'**
  String get virtualTypeAdjust;

  /// virtualTypeCountHint
  ///
  /// In ja, this message translates to:
  /// **'その日に実際にあった数を入力します。以後の数はこの数から計算されます。'**
  String get virtualTypeCountHint;

  /// virtualTypeAdjustHint
  ///
  /// In ja, this message translates to:
  /// **'分かっている出庫や入庫を入力します。'**
  String get virtualTypeAdjustHint;

  /// virtualAdjustOut
  ///
  /// In ja, this message translates to:
  /// **'出庫（減）'**
  String get virtualAdjustOut;

  /// virtualAdjustIn
  ///
  /// In ja, this message translates to:
  /// **'入庫（増）'**
  String get virtualAdjustIn;

  /// virtualCountedQuantity
  ///
  /// In ja, this message translates to:
  /// **'実数'**
  String get virtualCountedQuantity;

  /// virtualAdjustQuantity
  ///
  /// In ja, this message translates to:
  /// **'数量'**
  String get virtualAdjustQuantity;

  /// virtualDate
  ///
  /// In ja, this message translates to:
  /// **'日付'**
  String get virtualDate;

  /// virtualNote
  ///
  /// In ja, this message translates to:
  /// **'メモ（任意）'**
  String get virtualNote;

  /// chartStockTitle
  ///
  /// In ja, this message translates to:
  /// **'商品在庫の内訳'**
  String get chartStockTitle;

  /// chartByWarehouse
  ///
  /// In ja, this message translates to:
  /// **'倉庫別'**
  String get chartByWarehouse;

  /// chartByState
  ///
  /// In ja, this message translates to:
  /// **'状態別'**
  String get chartByState;

  /// chartShowTable
  ///
  /// In ja, this message translates to:
  /// **'表で見る'**
  String get chartShowTable;

  /// chartShowChart
  ///
  /// In ja, this message translates to:
  /// **'グラフで見る'**
  String get chartShowChart;

  /// chartEmpty
  ///
  /// In ja, this message translates to:
  /// **'在庫のある商品はまだありません'**
  String get chartEmpty;

  /// Dashboard stock chart: stock under JANs with no product record is left out of the bars (0094)
  ///
  /// In ja, this message translates to:
  /// **'商品ライブラリー未登録のJAN {jans} 件（計 {units} 個）はグラフに含まれていません'**
  String chartUnregisteredNote(int jans, String units);

  /// Dashboard stock chart: opens the unregistered-JAN list
  ///
  /// In ja, this message translates to:
  /// **'登録する'**
  String get chartUnregisteredAction;

  /// chartTopOf
  ///
  /// In ja, this message translates to:
  /// **'在庫の多い上位 {shown} 商品（全 {total} 商品）'**
  String chartTopOf(int shown, int total);

  /// chartFree
  ///
  /// In ja, this message translates to:
  /// **'空き'**
  String get chartFree;

  /// chartReserved
  ///
  /// In ja, this message translates to:
  /// **'引当済'**
  String get chartReserved;

  /// chartUnusable
  ///
  /// In ja, this message translates to:
  /// **'使用不可（保留・検品待ち）'**
  String get chartUnusable;

  /// chartVirtualAbroad
  ///
  /// In ja, this message translates to:
  /// **'国外（仮想）'**
  String get chartVirtualAbroad;

  /// chartWarehouseVirtual
  ///
  /// In ja, this message translates to:
  /// **'{name}（仮想）'**
  String chartWarehouseVirtual(String name);

  /// chartOther
  ///
  /// In ja, this message translates to:
  /// **'その他'**
  String get chartOther;

  /// chartProduct
  ///
  /// In ja, this message translates to:
  /// **'商品'**
  String get chartProduct;

  /// chartTotal
  ///
  /// In ja, this message translates to:
  /// **'合計'**
  String get chartTotal;

  /// recentPoTitle
  ///
  /// In ja, this message translates to:
  /// **'直近の発注'**
  String get recentPoTitle;

  /// recentPoEmpty
  ///
  /// In ja, this message translates to:
  /// **'発注はまだありません'**
  String get recentPoEmpty;

  /// recentPoDestination
  ///
  /// In ja, this message translates to:
  /// **'宛先 {warehouse}{country}'**
  String recentPoDestination(String warehouse, String country);

  /// recentPoExpected
  ///
  /// In ja, this message translates to:
  /// **'納期 {date}'**
  String recentPoExpected(String date);

  /// recentPoReceived
  ///
  /// In ja, this message translates to:
  /// **'入荷 {received} / {ordered}'**
  String recentPoReceived(String received, String ordered);

  /// recentPoOpenAll
  ///
  /// In ja, this message translates to:
  /// **'発注一覧へ'**
  String get recentPoOpenAll;

  /// whTotalsCountry
  ///
  /// In ja, this message translates to:
  /// **'合計（{country}）'**
  String whTotalsCountry(String country);

  /// chartTopOfCountry
  ///
  /// In ja, this message translates to:
  /// **'{country}：在庫の多い上位 {shown} 商品（全 {total} 商品）'**
  String chartTopOfCountry(String country, int shown, int total);

  /// dashOverviewCountry
  ///
  /// In ja, this message translates to:
  /// **'概要（{country}）'**
  String dashOverviewCountry(String country);

  /// Held stock / disposition (0098): heldStatusQcPending
  ///
  /// In ja, this message translates to:
  /// **'検品待ち'**
  String get heldStatusQcPending;

  /// Held stock / disposition (0098): heldStatusHold
  ///
  /// In ja, this message translates to:
  /// **'保留'**
  String get heldStatusHold;

  /// Held stock / disposition (0098): heldStatusQuarantine
  ///
  /// In ja, this message translates to:
  /// **'隔離'**
  String get heldStatusQuarantine;

  /// Held stock / disposition (0098): heldStatusDamaged
  ///
  /// In ja, this message translates to:
  /// **'破損'**
  String get heldStatusDamaged;

  /// Held stock / disposition (0098): heldStatusExpired
  ///
  /// In ja, this message translates to:
  /// **'期限切れ'**
  String get heldStatusExpired;

  /// Held stock / disposition (0098): heldStatusBlocked
  ///
  /// In ja, this message translates to:
  /// **'出荷停止'**
  String get heldStatusBlocked;

  /// Held stock / disposition (0098): heldAwaitsInspection
  ///
  /// In ja, this message translates to:
  /// **'検品で合否を決めます'**
  String get heldAwaitsInspection;

  /// Held stock / disposition (0098): heldDispose
  ///
  /// In ja, this message translates to:
  /// **'処理'**
  String get heldDispose;

  /// Held stock / disposition (0098): dispTitle
  ///
  /// In ja, this message translates to:
  /// **'{name} の処理'**
  String dispTitle(String name);

  /// Held stock / disposition (0098): dispQuantity
  ///
  /// In ja, this message translates to:
  /// **'数量'**
  String get dispQuantity;

  /// Held stock / disposition (0098): dispMax
  ///
  /// In ja, this message translates to:
  /// **'最大 {qty} 点'**
  String dispMax(int qty);

  /// Held stock / disposition (0098): dispRelease
  ///
  /// In ja, this message translates to:
  /// **'良品に戻す'**
  String get dispRelease;

  /// Held stock / disposition (0098): dispHold
  ///
  /// In ja, this message translates to:
  /// **'保留にする'**
  String get dispHold;

  /// Held stock / disposition (0098): dispQuarantine
  ///
  /// In ja, this message translates to:
  /// **'隔離する'**
  String get dispQuarantine;

  /// Held stock / disposition (0098): dispDamaged
  ///
  /// In ja, this message translates to:
  /// **'破損にする'**
  String get dispDamaged;

  /// Held stock / disposition (0098): dispScrap
  ///
  /// In ja, this message translates to:
  /// **'廃棄する'**
  String get dispScrap;

  /// Held stock / disposition (0098): dispReturn
  ///
  /// In ja, this message translates to:
  /// **'仕入先へ返品'**
  String get dispReturn;

  /// Held stock / disposition (0098): dispReason
  ///
  /// In ja, this message translates to:
  /// **'理由・返品番号など'**
  String get dispReason;

  /// Held stock / disposition (0098): dispReasonRequired
  ///
  /// In ja, this message translates to:
  /// **'廃棄・返品には理由が必要です'**
  String get dispReasonRequired;

  /// Held stock / disposition (0098): dispOverMax
  ///
  /// In ja, this message translates to:
  /// **'{qty} 点までです'**
  String dispOverMax(int qty);

  /// Held stock / disposition (0098): dispConfirm
  ///
  /// In ja, this message translates to:
  /// **'実行'**
  String get dispConfirm;

  /// Held stock / disposition (0098): dispDone
  ///
  /// In ja, this message translates to:
  /// **'{qty} 点を処理しました'**
  String dispDone(int qty);

  /// Held stock / disposition (0098): mvScrap
  ///
  /// In ja, this message translates to:
  /// **'廃棄'**
  String get mvScrap;

  /// Held stock / disposition (0098): mvReturnToSupplier
  ///
  /// In ja, this message translates to:
  /// **'仕入先返品'**
  String get mvReturnToSupplier;

  /// Bulk inspection / arrival date (0099): bulkQcTitle
  ///
  /// In ja, this message translates to:
  /// **'一括検品'**
  String get bulkQcTitle;

  /// Bulk inspection / arrival date (0099): bulkQcGroupDate
  ///
  /// In ja, this message translates to:
  /// **'入荷日'**
  String get bulkQcGroupDate;

  /// Bulk inspection / arrival date (0099): bulkQcGroupPo
  ///
  /// In ja, this message translates to:
  /// **'発注'**
  String get bulkQcGroupPo;

  /// Bulk inspection / arrival date (0099): bulkQcAllDates
  ///
  /// In ja, this message translates to:
  /// **'すべての入荷日'**
  String get bulkQcAllDates;

  /// Bulk inspection / arrival date (0099): bulkQcAllPos
  ///
  /// In ja, this message translates to:
  /// **'すべての発注'**
  String get bulkQcAllPos;

  /// Bulk inspection / arrival date (0099): bulkQcNoPo
  ///
  /// In ja, this message translates to:
  /// **'発注なし'**
  String get bulkQcNoPo;

  /// Bulk inspection / arrival date (0099): bulkQcProductFilter
  ///
  /// In ja, this message translates to:
  /// **'商品：{name}'**
  String bulkQcProductFilter(String name);

  /// Bulk inspection / arrival date (0099): bulkQcScanHint
  ///
  /// In ja, this message translates to:
  /// **'JANを読み込んで商品で絞り込み'**
  String get bulkQcScanHint;

  /// Bulk inspection / arrival date (0099): bulkQcNoMatch
  ///
  /// In ja, this message translates to:
  /// **'このJANの検品待ちはありません'**
  String get bulkQcNoMatch;

  /// Bulk inspection / arrival date (0099): bulkQcSelectAll
  ///
  /// In ja, this message translates to:
  /// **'すべて選択'**
  String get bulkQcSelectAll;

  /// Bulk inspection / arrival date (0099): bulkQcSelectNone
  ///
  /// In ja, this message translates to:
  /// **'選択解除'**
  String get bulkQcSelectNone;

  /// Bulk inspection / arrival date (0099): bulkQcSummary
  ///
  /// In ja, this message translates to:
  /// **'選択 {lines} 行・計 {units} 点'**
  String bulkQcSummary(int lines, int units);

  /// Bulk inspection / arrival date (0099): bulkQcPass
  ///
  /// In ja, this message translates to:
  /// **'選択した分を良品として検品完了'**
  String get bulkQcPass;

  /// Bulk inspection / arrival date (0099): bulkQcConfirmTitle
  ///
  /// In ja, this message translates to:
  /// **'良品として検品完了しますか？'**
  String get bulkQcConfirmTitle;

  /// Bulk inspection / arrival date (0099): bulkQcConfirmBody
  ///
  /// In ja, this message translates to:
  /// **'{lines} 行・計 {units} 点を良品として確定し、すぐに出荷できる在庫にします。選択しなかった行は検品待ちのまま残ります。'**
  String bulkQcConfirmBody(int lines, int units);

  /// Bulk inspection / arrival date (0099): bulkQcDone
  ///
  /// In ja, this message translates to:
  /// **'{lines} 行（{units} 点）を良品として確定しました'**
  String bulkQcDone(int lines, int units);

  /// Bulk inspection / arrival date (0099): bulkQcEmpty
  ///
  /// In ja, this message translates to:
  /// **'検品待ちの行はありません'**
  String get bulkQcEmpty;

  /// Bulk inspection / arrival date (0099): bulkQcEmptyBody
  ///
  /// In ja, this message translates to:
  /// **'検品が必要な商品を入荷すると、ここに並びます。'**
  String get bulkQcEmptyBody;

  /// Bulk inspection / arrival date (0099): bulkQcArrived
  ///
  /// In ja, this message translates to:
  /// **'入荷 {date}'**
  String bulkQcArrived(String date);

  /// Bulk inspection / arrival date (0099): bulkQcRecordedBadge
  ///
  /// In ja, this message translates to:
  /// **'記録あり'**
  String get bulkQcRecordedBadge;

  /// Bulk inspection / arrival date (0099): qcPassAll
  ///
  /// In ja, this message translates to:
  /// **'全数良品'**
  String get qcPassAll;

  /// Bulk inspection / arrival date (0099): qcPassAllDone
  ///
  /// In ja, this message translates to:
  /// **'{units} 点を良品として確定しました'**
  String qcPassAllDone(int units);

  /// Bulk inspection / arrival date (0099): qcFinalBadge
  ///
  /// In ja, this message translates to:
  /// **'確定済'**
  String get qcFinalBadge;

  /// Bulk inspection / arrival date (0099): qcScanHint
  ///
  /// In ja, this message translates to:
  /// **'JANを読み込むとその商品の行を検品できます'**
  String get qcScanHint;

  /// Bulk inspection / arrival date (0099): qcScanNotInInspection
  ///
  /// In ja, this message translates to:
  /// **'この検品に含まれないJANです'**
  String get qcScanNotInInspection;

  /// Bulk inspection / arrival date (0099): qcScanPrompt
  ///
  /// In ja, this message translates to:
  /// **'{name}：{units} 点'**
  String qcScanPrompt(String name, int units);

  /// Bulk inspection / arrival date (0099): qcScanRecordEach
  ///
  /// In ja, this message translates to:
  /// **'個別に記録'**
  String get qcScanRecordEach;

  /// Bulk inspection / arrival date (0099): receiptArrivedOn
  ///
  /// In ja, this message translates to:
  /// **'入荷日 {date}'**
  String receiptArrivedOn(String date);

  /// Bulk inspection / arrival date (0099): receiptArrivedOnEdit
  ///
  /// In ja, this message translates to:
  /// **'入荷日を変更'**
  String get receiptArrivedOnEdit;

  /// Bulk inspection / arrival date (0099): receiptArrivedOnSaved
  ///
  /// In ja, this message translates to:
  /// **'入荷日を {date} にしました'**
  String receiptArrivedOnSaved(String date);

  /// Home menu: bulk inspection (0099)
  ///
  /// In ja, this message translates to:
  /// **'一括検品'**
  String get featBulkInspection;

  /// Home menu: bulk inspection description
  ///
  /// In ja, this message translates to:
  /// **'入荷日・発注・商品で絞り込み、まとめて良品として検品完了'**
  String get featBulkInspectionDesc;

  /// Inspection count check (0100): qcCountMatch
  ///
  /// In ja, this message translates to:
  /// **'数量一致'**
  String get qcCountMatch;

  /// Inspection count check (0100): qcCountShort
  ///
  /// In ja, this message translates to:
  /// **'不足 {n}'**
  String qcCountShort(int n);

  /// Inspection count check (0100): qcCountOver
  ///
  /// In ja, this message translates to:
  /// **'過剰 {n}'**
  String qcCountOver(int n);

  /// Inspection count check (0100): qcCountNone
  ///
  /// In ja, this message translates to:
  /// **'未カウント'**
  String get qcCountNone;

  /// Inspection count check (0100): qcCountLine
  ///
  /// In ja, this message translates to:
  /// **'検品数 {counted} / 入荷 {received}'**
  String qcCountLine(int counted, int received);

  /// Inspection count check (0100): qcEnterCount
  ///
  /// In ja, this message translates to:
  /// **'数量を入力'**
  String get qcEnterCount;

  /// Inspection count check (0100): qcEnterCountTitle
  ///
  /// In ja, this message translates to:
  /// **'{name} の検品数'**
  String qcEnterCountTitle(String name);

  /// Inspection count check (0100): qcScanCounted
  ///
  /// In ja, this message translates to:
  /// **'{name}：{counted} / {received}'**
  String qcScanCounted(String name, int counted, int received);

  /// Inspection count check (0100): qcScanCountMatched
  ///
  /// In ja, this message translates to:
  /// **'{name} の数量が一致しました（{n} 点）'**
  String qcScanCountMatched(String name, int n);

  /// Inspection count check (0100): qcWrongItemTitle
  ///
  /// In ja, this message translates to:
  /// **'この入荷にない商品です'**
  String get qcWrongItemTitle;

  /// Inspection count check (0100): qcWrongItemBody
  ///
  /// In ja, this message translates to:
  /// **'JAN {jan} は今回の入荷に含まれていません。誤品として記録しますか？'**
  String qcWrongItemBody(String jan);

  /// Inspection count check (0100): qcWrongItemRecord
  ///
  /// In ja, this message translates to:
  /// **'誤品として記録'**
  String get qcWrongItemRecord;

  /// Inspection count check (0100): qcWrongItemDone
  ///
  /// In ja, this message translates to:
  /// **'誤品として記録しました'**
  String get qcWrongItemDone;

  /// Inspection count check (0100): qcMatchedSummary
  ///
  /// In ja, this message translates to:
  /// **'数量一致 {matched} / {total} 行'**
  String qcMatchedSummary(int matched, int total);

  /// Inspection count check (0100): qcCompleteDefaultTitle
  ///
  /// In ja, this message translates to:
  /// **'未チェックの行があります'**
  String get qcCompleteDefaultTitle;

  /// Inspection count check (0100): qcCompleteDefaultBody
  ///
  /// In ja, this message translates to:
  /// **'未チェックの {n} 行は良品として完了します。数量を数えた行は、数えた数で確定します。'**
  String qcCompleteDefaultBody(int n);

  /// Inspection count check (0100): qcCompleteConfirm
  ///
  /// In ja, this message translates to:
  /// **'完了する'**
  String get qcCompleteConfirm;

  /// Inspection count check (0100): qcEffectCountShort
  ///
  /// In ja, this message translates to:
  /// **'数えられなかった {n} 点を保留に移しました'**
  String qcEffectCountShort(int n);

  /// Inspection counting by carton / delivery note (0101): qcScanPieceMode
  ///
  /// In ja, this message translates to:
  /// **'スキャンで1個ずつ数える'**
  String get qcScanPieceMode;

  /// Inspection counting by carton / delivery note (0101): qcScanPieceOn
  ///
  /// In ja, this message translates to:
  /// **'スキャン1回で1個数えます'**
  String get qcScanPieceOn;

  /// Inspection counting by carton / delivery note (0101): qcScanPieceOff
  ///
  /// In ja, this message translates to:
  /// **'スキャンで商品を選び、数量を入力します'**
  String get qcScanPieceOff;

  /// Inspection counting by carton / delivery note (0101): qcReadNote
  ///
  /// In ja, this message translates to:
  /// **'納品書を読み取る'**
  String get qcReadNote;

  /// Inspection counting by carton / delivery note (0101): qcNoteApplied
  ///
  /// In ja, this message translates to:
  /// **'納品書の {matched} 行を検品に反映しました'**
  String qcNoteApplied(int matched);

  /// Inspection counting by carton / delivery note (0101): qcNoteNone
  ///
  /// In ja, this message translates to:
  /// **'納品書から明細を読み取れませんでした'**
  String get qcNoteNone;

  /// Inspection counting by carton / delivery note (0101): qcNoteUnmatchedTitle
  ///
  /// In ja, this message translates to:
  /// **'照合できなかった納品書の行'**
  String get qcNoteUnmatchedTitle;

  /// Inspection counting by carton / delivery note (0101): qcNoteUnmatchedBody
  ///
  /// In ja, this message translates to:
  /// **'次の行は今回の入荷の商品と一致しませんでした。品違いなら誤品として記録してください。'**
  String get qcNoteUnmatchedBody;

  /// Inspection counting by carton / delivery note (0101): qcNoteQuantity
  ///
  /// In ja, this message translates to:
  /// **'納品書 {n}'**
  String qcNoteQuantity(int n);

  /// Inspection counting by carton / delivery note (0101): qcCountRemaining
  ///
  /// In ja, this message translates to:
  /// **'残り {n}'**
  String qcCountRemaining(int n);

  /// Inspection counting by carton / delivery note (0101): qcCountModeAdd
  ///
  /// In ja, this message translates to:
  /// **'追加する'**
  String get qcCountModeAdd;

  /// Inspection counting by carton / delivery note (0101): qcCountModeSet
  ///
  /// In ja, this message translates to:
  /// **'合計を直す'**
  String get qcCountModeSet;

  /// Inspection counting by carton / delivery note (0101): qcCountSoFar
  ///
  /// In ja, this message translates to:
  /// **'これまで {counted} / 入荷 {received}'**
  String qcCountSoFar(int counted, int received);

  /// Inspection counting by carton / delivery note (0101): qcCountAddHint
  ///
  /// In ja, this message translates to:
  /// **'今回数えた数（箱の入数など）'**
  String get qcCountAddHint;

  /// Inspection counting by carton / delivery note (0101): qcCountSetHint
  ///
  /// In ja, this message translates to:
  /// **'数えた合計'**
  String get qcCountSetHint;

  /// Inspection counting by carton / delivery note (0101): qcTick
  ///
  /// In ja, this message translates to:
  /// **'品と数を確認'**
  String get qcTick;

  /// Role dashboards (0102): partnerCountry
  ///
  /// In ja, this message translates to:
  /// **'国'**
  String get partnerCountry;

  /// Role dashboards (0102): dashViewOverview
  ///
  /// In ja, this message translates to:
  /// **'概要'**
  String get dashViewOverview;

  /// Role dashboards (0102): dashViewInspection
  ///
  /// In ja, this message translates to:
  /// **'検品'**
  String get dashViewInspection;

  /// Role dashboards (0102): dashViewPurchasing
  ///
  /// In ja, this message translates to:
  /// **'発注'**
  String get dashViewPurchasing;

  /// Role dashboards (0102): dashViewSales
  ///
  /// In ja, this message translates to:
  /// **'受注'**
  String get dashViewSales;

  /// Role dashboards (0102): dashAwaitingInspection
  ///
  /// In ja, this message translates to:
  /// **'検品待ち'**
  String get dashAwaitingInspection;

  /// Role dashboards (0102): dashAwaitingBody
  ///
  /// In ja, this message translates to:
  /// **'{inspections}件・{lines}行・{units}個'**
  String dashAwaitingBody(int inspections, int lines, int units);

  /// Role dashboards (0102): dashAwaitingNone
  ///
  /// In ja, this message translates to:
  /// **'検品待ちはありません'**
  String get dashAwaitingNone;

  /// Role dashboards (0102): dashOpenInspections
  ///
  /// In ja, this message translates to:
  /// **'検品一覧'**
  String get dashOpenInspections;

  /// Role dashboards (0102): dashBulkInspection
  ///
  /// In ja, this message translates to:
  /// **'一括検品'**
  String get dashBulkInspection;

  /// Role dashboards (0102): dashIncomingTitle
  ///
  /// In ja, this message translates to:
  /// **'入荷予定'**
  String get dashIncomingTitle;

  /// Role dashboards (0102): dashIncomingEmpty
  ///
  /// In ja, this message translates to:
  /// **'入荷予定はありません'**
  String get dashIncomingEmpty;

  /// Role dashboards (0102): dashDayToday
  ///
  /// In ja, this message translates to:
  /// **'今日'**
  String get dashDayToday;

  /// Role dashboards (0102): dashDayTomorrow
  ///
  /// In ja, this message translates to:
  /// **'明日'**
  String get dashDayTomorrow;

  /// Role dashboards (0102): dashDayOverdue
  ///
  /// In ja, this message translates to:
  /// **'予定日を過ぎたもの'**
  String get dashDayOverdue;

  /// Role dashboards (0102): dashDayNone
  ///
  /// In ja, this message translates to:
  /// **'日付未定'**
  String get dashDayNone;

  /// Role dashboards (0102): dashManualBadge
  ///
  /// In ja, this message translates to:
  /// **'手動'**
  String get dashManualBadge;

  /// Role dashboards (0102): dashPlanSummary
  ///
  /// In ja, this message translates to:
  /// **'{lines}品目・{units}個'**
  String dashPlanSummary(int lines, int units);

  /// Role dashboards (0102): dashMoreLines
  ///
  /// In ja, this message translates to:
  /// **'ほか{count}品目'**
  String dashMoreLines(int count);

  /// Role dashboards (0102): dashUnplannedTitle
  ///
  /// In ja, this message translates to:
  /// **'出荷表のない発注'**
  String get dashUnplannedTitle;

  /// Role dashboards (0102): dashUnplannedBody
  ///
  /// In ja, this message translates to:
  /// **'仕入先から出荷表が届いていない承認済みの発注です。手動で入荷リストを作れます。'**
  String get dashUnplannedBody;

  /// Role dashboards (0102): dashCreateManualList
  ///
  /// In ja, this message translates to:
  /// **'手動で入荷リストを作成'**
  String get dashCreateManualList;

  /// Role dashboards (0102): manualListTitle
  ///
  /// In ja, this message translates to:
  /// **'入荷リストを手動作成'**
  String get manualListTitle;

  /// Role dashboards (0102): manualListSupplier
  ///
  /// In ja, this message translates to:
  /// **'仕入先名（任意）'**
  String get manualListSupplier;

  /// Role dashboards (0102): manualListExpected
  ///
  /// In ja, this message translates to:
  /// **'入荷予定日'**
  String get manualListExpected;

  /// Role dashboards (0102): manualListNoDate
  ///
  /// In ja, this message translates to:
  /// **'未定'**
  String get manualListNoDate;

  /// Role dashboards (0102): manualListScanHint
  ///
  /// In ja, this message translates to:
  /// **'JANをスキャンまたは入力'**
  String get manualListScanHint;

  /// Role dashboards (0102): manualListQuantity
  ///
  /// In ja, this message translates to:
  /// **'数量'**
  String get manualListQuantity;

  /// Role dashboards (0102): manualListEmpty
  ///
  /// In ja, this message translates to:
  /// **'入荷する商品のJANをスキャンして追加してください'**
  String get manualListEmpty;

  /// Role dashboards (0102): manualListSave
  ///
  /// In ja, this message translates to:
  /// **'リストを作成'**
  String get manualListSave;

  /// Role dashboards (0102): manualListCreated
  ///
  /// In ja, this message translates to:
  /// **'入荷リスト {number} を作成しました'**
  String manualListCreated(String number);

  /// Role dashboards (0102): manualListNoWarehouse
  ///
  /// In ja, this message translates to:
  /// **'倉庫を選択してから作成してください'**
  String get manualListNoWarehouse;

  /// Role dashboards (0102): manualListBadJan
  ///
  /// In ja, this message translates to:
  /// **'JANは数字8桁または13桁です'**
  String get manualListBadJan;

  /// Role dashboards (0102): dashStockUsable
  ///
  /// In ja, this message translates to:
  /// **'良品'**
  String get dashStockUsable;

  /// Role dashboards (0102): dashStockQcPending
  ///
  /// In ja, this message translates to:
  /// **'検品待ち'**
  String get dashStockQcPending;

  /// Role dashboards (0102): dashStockHeld
  ///
  /// In ja, this message translates to:
  /// **'保留'**
  String get dashStockHeld;

  /// Role dashboards (0102): dashStockReserved
  ///
  /// In ja, this message translates to:
  /// **'引当'**
  String get dashStockReserved;

  /// Role dashboards (0102): dashStockIncoming
  ///
  /// In ja, this message translates to:
  /// **'入荷予定'**
  String get dashStockIncoming;

  /// Role dashboards (0102): dashStockShortfall
  ///
  /// In ja, this message translates to:
  /// **'不足'**
  String get dashStockShortfall;

  /// Role dashboards (0102): dashStockNext
  ///
  /// In ja, this message translates to:
  /// **'次回 {date}'**
  String dashStockNext(String date);

  /// Role dashboards (0102): dashStockSearch
  ///
  /// In ja, this message translates to:
  /// **'商品名・JANで検索'**
  String get dashStockSearch;

  /// Role dashboards (0102): dashStockEmpty
  ///
  /// In ja, this message translates to:
  /// **'該当する商品はありません'**
  String get dashStockEmpty;

  /// Role dashboards (0102): dashStockProducts
  ///
  /// In ja, this message translates to:
  /// **'{count}商品'**
  String dashStockProducts(int count);

  /// Role dashboards (0102): dashOpenDemand
  ///
  /// In ja, this message translates to:
  /// **'受注残・発注を開く'**
  String get dashOpenDemand;

  /// Role dashboards (0102): dashSalesUnits
  ///
  /// In ja, this message translates to:
  /// **'直近{months}か月の受注数'**
  String dashSalesUnits(int months);

  /// Role dashboards (0102): dashSalesVsLastYear
  ///
  /// In ja, this message translates to:
  /// **'前年比 {pct}'**
  String dashSalesVsLastYear(String pct);

  /// Role dashboards (0102): dashSalesNoCompare
  ///
  /// In ja, this message translates to:
  /// **'前年のデータなし'**
  String get dashSalesNoCompare;

  /// Role dashboards (0102): dashSalesOrders
  ///
  /// In ja, this message translates to:
  /// **'受注件数'**
  String get dashSalesOrders;

  /// Role dashboards (0102): dashSalesMonthly
  ///
  /// In ja, this message translates to:
  /// **'月別の受注数'**
  String get dashSalesMonthly;

  /// Role dashboards (0102): dashSalesThisYear
  ///
  /// In ja, this message translates to:
  /// **'今年'**
  String get dashSalesThisYear;

  /// Role dashboards (0102): dashSalesLastYear
  ///
  /// In ja, this message translates to:
  /// **'前年'**
  String get dashSalesLastYear;

  /// Role dashboards (0102): dashSalesTop
  ///
  /// In ja, this message translates to:
  /// **'よく注文される商品'**
  String get dashSalesTop;

  /// Role dashboards (0102): dashSalesToPurchase
  ///
  /// In ja, this message translates to:
  /// **'これから発注が必要な商品'**
  String get dashSalesToPurchase;

  /// Role dashboards (0102): dashSalesToPurchaseEmpty
  ///
  /// In ja, this message translates to:
  /// **'発注が必要な商品はありません'**
  String get dashSalesToPurchaseEmpty;

  /// Role dashboards (0102): dashSalesAllCountries
  ///
  /// In ja, this message translates to:
  /// **'すべての国'**
  String get dashSalesAllCountries;

  /// Role dashboards (0102): dashSalesEmpty
  ///
  /// In ja, this message translates to:
  /// **'この期間の受注はありません'**
  String get dashSalesEmpty;

  /// Role dashboards (0102): dashBackordered
  ///
  /// In ja, this message translates to:
  /// **'受注残'**
  String get dashBackordered;

  /// Role dashboards (0102): dashUnitsCount
  ///
  /// In ja, this message translates to:
  /// **'{count}個'**
  String dashUnitsCount(int count);

  /// Supplier notation / warehouse inspection (0103-0104): productMaker
  ///
  /// In ja, this message translates to:
  /// **'メーカー'**
  String get productMaker;

  /// Supplier notation / warehouse inspection (0103-0104): productInspectionByWarehouse
  ///
  /// In ja, this message translates to:
  /// **'入荷検品の要否は倉庫ごとの設定（倉庫画面の「検品方式」）に従います。'**
  String get productInspectionByWarehouse;

  /// Supplier notation / warehouse inspection (0103-0104): supplierNameJan
  ///
  /// In ja, this message translates to:
  /// **'仕入先でのJAN表記（任意）'**
  String get supplierNameJan;

  /// Supplier notation / warehouse inspection (0103-0104): supplierNameMaker
  ///
  /// In ja, this message translates to:
  /// **'仕入先でのメーカー表記（任意）'**
  String get supplierNameMaker;

  /// Supplier notation / warehouse inspection (0103-0104): qcUnconvertedBlock
  ///
  /// In ja, this message translates to:
  /// **'自社商品に変換していない行が{count}行あります。各行の「自社商品に変換」から変換してください。'**
  String qcUnconvertedBlock(int count);

  /// Supplier notation / warehouse inspection (0103-0104): qcSampleDone
  ///
  /// In ja, this message translates to:
  /// **'{name}：抜き取りが済み、この行を合格にしました'**
  String qcSampleDone(String name);

  /// Supplier notation / warehouse inspection (0103-0104): qcSampleProgress
  ///
  /// In ja, this message translates to:
  /// **'{name}：抜き取り {done}/{target}'**
  String qcSampleProgress(String name, int done, int target);

  /// Supplier notation / warehouse inspection (0103-0104): qcConverted
  ///
  /// In ja, this message translates to:
  /// **'「{name}」に変換しました'**
  String qcConverted(String name);

  /// Supplier notation / warehouse inspection (0103-0104): qcSamplingBadge
  ///
  /// In ja, this message translates to:
  /// **'抜き取り検品（{percent}%・最低{min}個）'**
  String qcSamplingBadge(int percent, int min);

  /// Supplier notation / warehouse inspection (0103-0104): qcUnconvertedCount
  ///
  /// In ja, this message translates to:
  /// **'未変換 {count}行'**
  String qcUnconvertedCount(int count);

  /// Supplier notation / warehouse inspection (0103-0104): qcOwnSku
  ///
  /// In ja, this message translates to:
  /// **'品番 {code}'**
  String qcOwnSku(String code);

  /// Supplier notation / warehouse inspection (0103-0104): qcSupplierNotation
  ///
  /// In ja, this message translates to:
  /// **'仕入先表記：{text}'**
  String qcSupplierNotation(String text);

  /// Supplier notation / warehouse inspection (0103-0104): qcUnconverted
  ///
  /// In ja, this message translates to:
  /// **'未変換'**
  String get qcUnconverted;

  /// Supplier notation / warehouse inspection (0103-0104): qcSampleState
  ///
  /// In ja, this message translates to:
  /// **'抜き取り {done}/{target}'**
  String qcSampleState(int done, int target);

  /// Supplier notation / warehouse inspection (0103-0104): qcConvert
  ///
  /// In ja, this message translates to:
  /// **'自社商品に変換'**
  String get qcConvert;

  /// Supplier notation / warehouse inspection (0103-0104): qcConvertChange
  ///
  /// In ja, this message translates to:
  /// **'変換先を変更'**
  String get qcConvertChange;

  /// Supplier notation / warehouse inspection (0103-0104): qcSampleAdd
  ///
  /// In ja, this message translates to:
  /// **'抜き取り +1'**
  String get qcSampleAdd;

  /// Supplier notation / warehouse inspection (0103-0104): qcConvertTitle
  ///
  /// In ja, this message translates to:
  /// **'自社商品に変換'**
  String get qcConvertTitle;

  /// Supplier notation / warehouse inspection (0103-0104): qcConvertSearch
  ///
  /// In ja, this message translates to:
  /// **'自社の商品名・JAN・品番・メーカーで検索'**
  String get qcConvertSearch;

  /// Supplier notation / warehouse inspection (0103-0104): qcConvertRemember
  ///
  /// In ja, this message translates to:
  /// **'この仕入先の表記を記憶し、次回から自動で変換する'**
  String get qcConvertRemember;

  /// Supplier notation / warehouse inspection (0103-0104): qcConvertNone
  ///
  /// In ja, this message translates to:
  /// **'該当する商品がありません'**
  String get qcConvertNone;

  /// Supplier notation / warehouse inspection (0103-0104): qcErrorUnconverted
  ///
  /// In ja, this message translates to:
  /// **'自社商品に変換していない行は合格にできません。先に「自社商品に変換」してください。'**
  String get qcErrorUnconverted;

  /// Supplier notation / warehouse inspection (0103-0104): qcErrorNotSampling
  ///
  /// In ja, this message translates to:
  /// **'この検品は抜き取り検品ではありません'**
  String get qcErrorNotSampling;

  /// Supplier notation / warehouse inspection (0103-0104): qcErrorNoJan
  ///
  /// In ja, this message translates to:
  /// **'変換先の商品にJANが登録されていません'**
  String get qcErrorNoJan;

  /// Supplier notation / warehouse inspection (0103-0104): qcErrorSerialConvert
  ///
  /// In ja, this message translates to:
  /// **'シリアル管理の行は変換できません。入荷を取り消して受け直してください'**
  String get qcErrorSerialConvert;

  /// Supplier notation / warehouse inspection (0103-0104): whInspectionEdit
  ///
  /// In ja, this message translates to:
  /// **'検品方式'**
  String get whInspectionEdit;

  /// Supplier notation / warehouse inspection (0103-0104): whInspectionFull
  ///
  /// In ja, this message translates to:
  /// **'全数検品'**
  String get whInspectionFull;

  /// Supplier notation / warehouse inspection (0103-0104): whInspectionSampleShort
  ///
  /// In ja, this message translates to:
  /// **'抜き取り {percent}%（最低{min}）'**
  String whInspectionSampleShort(int percent, int min);

  /// Supplier notation / warehouse inspection (0103-0104): whInspectionNone
  ///
  /// In ja, this message translates to:
  /// **'検品不要（仕入のみ）'**
  String get whInspectionNone;

  /// Supplier notation / warehouse inspection (0103-0104): whInspectionSaved
  ///
  /// In ja, this message translates to:
  /// **'検品方式を保存しました'**
  String get whInspectionSaved;

  /// Supplier notation / warehouse inspection (0103-0104): whInspectionTitle
  ///
  /// In ja, this message translates to:
  /// **'{name} の検品方式'**
  String whInspectionTitle(String name);

  /// Supplier notation / warehouse inspection (0103-0104): whInspectionFullBody
  ///
  /// In ja, this message translates to:
  /// **'仕入先からの入荷はすべて検品待ちになり、検品が終わるまで出荷できません。'**
  String get whInspectionFullBody;

  /// Supplier notation / warehouse inspection (0103-0104): whInspectionSample
  ///
  /// In ja, this message translates to:
  /// **'抜き取り検品'**
  String get whInspectionSample;

  /// Supplier notation / warehouse inspection (0103-0104): whInspectionSampleBody
  ///
  /// In ja, this message translates to:
  /// **'検品待ちになりますが、各行の一部だけを確認します。抜き取り分が済むとその行は合格になります。'**
  String get whInspectionSampleBody;

  /// Supplier notation / warehouse inspection (0103-0104): whInspectionSamplePercent
  ///
  /// In ja, this message translates to:
  /// **'抜き取り率'**
  String get whInspectionSamplePercent;

  /// Supplier notation / warehouse inspection (0103-0104): whInspectionSampleMin
  ///
  /// In ja, this message translates to:
  /// **'最低個数'**
  String get whInspectionSampleMin;

  /// Supplier notation / warehouse inspection (0103-0104): whInspectionNoneBody
  ///
  /// In ja, this message translates to:
  /// **'検品をこのシステムの外（外部に依頼するなど）で行う倉庫向けです。入荷した品はそのまま使える在庫になります。'**
  String get whInspectionNoneBody;

  /// Supplier notation / warehouse inspection (0103-0104): whInspectionApplies
  ///
  /// In ja, this message translates to:
  /// **'仕入先からの入荷に適用されます。倉庫間の移動には影響しません。'**
  String get whInspectionApplies;

  /// Notation dialects / training (0105-0106): productMakerRequired
  ///
  /// In ja, this message translates to:
  /// **'メーカーを入力してください（商品には必ずメーカーが必要です）'**
  String get productMakerRequired;

  /// Notation dialects / training (0105-0106): productPickerTitle
  ///
  /// In ja, this message translates to:
  /// **'自社商品を選ぶ'**
  String get productPickerTitle;

  /// Notation dialects / training (0105-0106): featNotationTraining
  ///
  /// In ja, this message translates to:
  /// **'表記の事前学習'**
  String get featNotationTraining;

  /// Notation dialects / training (0105-0106): featNotationTrainingDesc
  ///
  /// In ja, this message translates to:
  /// **'商社ごとの書き方（方言）を事前にExcel・PDF・写真から学習'**
  String get featNotationTrainingDesc;

  /// Notation dialects / training (0105-0106): ntTitle
  ///
  /// In ja, this message translates to:
  /// **'表記の事前学習'**
  String get ntTitle;

  /// Notation dialects / training (0105-0106): ntTabTrain
  ///
  /// In ja, this message translates to:
  /// **'事前学習'**
  String get ntTabTrain;

  /// Notation dialects / training (0105-0106): ntTabDialects
  ///
  /// In ja, this message translates to:
  /// **'方言辞書'**
  String get ntTabDialects;

  /// Notation dialects / training (0105-0106): ntTabColumns
  ///
  /// In ja, this message translates to:
  /// **'列見出し'**
  String get ntTabColumns;

  /// Notation dialects / training (0105-0106): ntTabHistory
  ///
  /// In ja, this message translates to:
  /// **'履歴・傾向'**
  String get ntTabHistory;

  /// Notation dialects / training (0105-0106): ntPartner
  ///
  /// In ja, this message translates to:
  /// **'商社（取引先）'**
  String get ntPartner;

  /// Notation dialects / training (0105-0106): ntAllPartners
  ///
  /// In ja, this message translates to:
  /// **'すべて（共通）'**
  String get ntAllPartners;

  /// Notation dialects / training (0105-0106): ntChoosePartner
  ///
  /// In ja, this message translates to:
  /// **'商社を選んでください'**
  String get ntChoosePartner;

  /// Notation dialects / training (0105-0106): ntChooseFile
  ///
  /// In ja, this message translates to:
  /// **'ファイルを選んでください'**
  String get ntChooseFile;

  /// Notation dialects / training (0105-0106): ntLearned
  ///
  /// In ja, this message translates to:
  /// **'{learned}件を学習しました（新規{added}・衝突{conflicts}）'**
  String ntLearned(int learned, int added, int conflicts);

  /// Notation dialects / training (0105-0106): ntTrainIntro
  ///
  /// In ja, this message translates to:
  /// **'商社から届くExcel・CSV・PDF・写真の見本を読み込み、実際の入荷と同じ方法（AIで2回読み取り、品名と品番の分解、自社商品への変換）で試します。登録は一切されません。結果を確認・修正して「学習する」と、その商社の書き方（方言）と列見出しを覚えます。'**
  String get ntTrainIntro;

  /// Notation dialects / training (0105-0106): ntPickFile
  ///
  /// In ja, this message translates to:
  /// **'見本ファイルを選ぶ'**
  String get ntPickFile;

  /// Notation dialects / training (0105-0106): ntRead
  ///
  /// In ja, this message translates to:
  /// **'読み取って試す'**
  String get ntRead;

  /// Notation dialects / training (0105-0106): ntReread
  ///
  /// In ja, this message translates to:
  /// **'直した列で読み直す'**
  String get ntReread;

  /// Notation dialects / training (0105-0106): ntReading
  ///
  /// In ja, this message translates to:
  /// **'読み取り中です（PDF・写真はAIで2回読み取ります）…'**
  String get ntReading;

  /// Notation dialects / training (0105-0106): ntLinesTitle
  ///
  /// In ja, this message translates to:
  /// **'明細 {count}行'**
  String ntLinesTitle(int count);

  /// Notation dialects / training (0105-0106): ntDiscard
  ///
  /// In ja, this message translates to:
  /// **'破棄'**
  String get ntDiscard;

  /// Notation dialects / training (0105-0106): ntLearn
  ///
  /// In ja, this message translates to:
  /// **'{count}行を学習する'**
  String ntLearn(int count);

  /// Notation dialects / training (0105-0106): ntSummaryLines
  ///
  /// In ja, this message translates to:
  /// **'{count}行'**
  String ntSummaryLines(int count);

  /// Notation dialects / training (0105-0106): ntSummaryResolved
  ///
  /// In ja, this message translates to:
  /// **'自社商品に変換 {done}/{total}'**
  String ntSummaryResolved(int done, int total);

  /// Notation dialects / training (0105-0106): ntSummaryReview
  ///
  /// In ja, this message translates to:
  /// **'要確認 {count}行'**
  String ntSummaryReview(int count);

  /// Notation dialects / training (0105-0106): ntReadTwice
  ///
  /// In ja, this message translates to:
  /// **'AIで2回読み取り照合済み'**
  String get ntReadTwice;

  /// Notation dialects / training (0105-0106): ntReadOnce
  ///
  /// In ja, this message translates to:
  /// **'確認の読み取りに失敗（1回のみ）'**
  String get ntReadOnce;

  /// Notation dialects / training (0105-0106): ntReadSheet
  ///
  /// In ja, this message translates to:
  /// **'表から読み取り（列はAIでも確認）'**
  String get ntReadSheet;

  /// Notation dialects / training (0105-0106): ntErrorsTitle
  ///
  /// In ja, this message translates to:
  /// **'見つかった問題'**
  String get ntErrorsTitle;

  /// Notation dialects / training (0105-0106): ntColumnsTitle
  ///
  /// In ja, this message translates to:
  /// **'列の読み方'**
  String get ntColumnsTitle;

  /// Notation dialects / training (0105-0106): ntColumnsHint
  ///
  /// In ja, this message translates to:
  /// **'違っていれば直して「直した列で読み直す」。学習するとこの商社の見出しとして覚えます。'**
  String get ntColumnsHint;

  /// Notation dialects / training (0105-0106): ntNoHeader
  ///
  /// In ja, this message translates to:
  /// **'（見出しなし）'**
  String get ntNoHeader;

  /// Notation dialects / training (0105-0106): ntAiThinks
  ///
  /// In ja, this message translates to:
  /// **'AIの判断：{field}'**
  String ntAiThinks(String field);

  /// Notation dialects / training (0105-0106): ntNotMatched
  ///
  /// In ja, this message translates to:
  /// **'自社商品が見つかりません'**
  String get ntNotMatched;

  /// Notation dialects / training (0105-0106): ntChooseProduct
  ///
  /// In ja, this message translates to:
  /// **'自社商品を選ぶ'**
  String get ntChooseProduct;

  /// Notation dialects / training (0105-0106): ntChangeProduct
  ///
  /// In ja, this message translates to:
  /// **'変更'**
  String get ntChangeProduct;

  /// Notation dialects / training (0105-0106): ntSplitFrom
  ///
  /// In ja, this message translates to:
  /// **'分解前：{text}'**
  String ntSplitFrom(String text);

  /// Notation dialects / training (0105-0106): ntOtherReading
  ///
  /// In ja, this message translates to:
  /// **'もう一方の読み（{field}）：{value}'**
  String ntOtherReading(String field, String value);

  /// Notation dialects / training (0105-0106): ntDialectsIntro
  ///
  /// In ja, this message translates to:
  /// **'商社ごとの書き方（方言）とそれが指す自社の商品・メーカー。それぞれにID（D-000000）が付きます。'**
  String get ntDialectsIntro;

  /// Notation dialects / training (0105-0106): ntAllFields
  ///
  /// In ja, this message translates to:
  /// **'すべて'**
  String get ntAllFields;

  /// Notation dialects / training (0105-0106): ntUnconfirmedOnly
  ///
  /// In ja, this message translates to:
  /// **'未確認のみ'**
  String get ntUnconfirmedOnly;

  /// Notation dialects / training (0105-0106): ntDialectSearch
  ///
  /// In ja, this message translates to:
  /// **'書き方・品名・JANで検索'**
  String get ntDialectSearch;

  /// Notation dialects / training (0105-0106): ntDialectsEmpty
  ///
  /// In ja, this message translates to:
  /// **'まだ学習した書き方はありません'**
  String get ntDialectsEmpty;

  /// Notation dialects / training (0105-0106): ntSeen
  ///
  /// In ja, this message translates to:
  /// **'{count}回'**
  String ntSeen(int count);

  /// Notation dialects / training (0105-0106): ntConfirm
  ///
  /// In ja, this message translates to:
  /// **'確認済みにする'**
  String get ntConfirm;

  /// Notation dialects / training (0105-0106): ntAddColumn
  ///
  /// In ja, this message translates to:
  /// **'見出しを追加'**
  String get ntAddColumn;

  /// Notation dialects / training (0105-0106): ntColumnHeader
  ///
  /// In ja, this message translates to:
  /// **'見出し（商社の書き方どおり）'**
  String get ntColumnHeader;

  /// Notation dialects / training (0105-0106): ntColumnsIntro
  ///
  /// In ja, this message translates to:
  /// **'表の見出しと意味。日本語（漢字・カナ）や英語の見出しを自社の項目に対応させます。商社を選ぶとその商社専用の見出しも表示します。'**
  String get ntColumnsIntro;

  /// Notation dialects / training (0105-0106): ntCommon
  ///
  /// In ja, this message translates to:
  /// **'共通'**
  String get ntCommon;

  /// Notation dialects / training (0105-0106): ntStatsTitle
  ///
  /// In ja, this message translates to:
  /// **'商社ごとの傾向'**
  String get ntStatsTitle;

  /// Notation dialects / training (0105-0106): ntHistoryEmpty
  ///
  /// In ja, this message translates to:
  /// **'まだ事前学習の記録はありません'**
  String get ntHistoryEmpty;

  /// Notation dialects / training (0105-0106): ntUnknownPartner
  ///
  /// In ja, this message translates to:
  /// **'商社未指定'**
  String get ntUnknownPartner;

  /// Notation dialects / training (0105-0106): ntStatsLine
  ///
  /// In ja, this message translates to:
  /// **'{runs}回・{lines}行・変換率{rate}・方言{dialects}件・見出し{columns}件'**
  String ntStatsLine(
      int runs, int lines, String rate, int dialects, int columns);

  /// Notation dialects / training (0105-0106): ntRunsTitle
  ///
  /// In ja, this message translates to:
  /// **'読み取り履歴'**
  String get ntRunsTitle;

  /// Notation dialects / training (0105-0106): ntStatusLearned
  ///
  /// In ja, this message translates to:
  /// **'学習済み'**
  String get ntStatusLearned;

  /// Notation dialects / training (0105-0106): ntStatusDiscarded
  ///
  /// In ja, this message translates to:
  /// **'破棄'**
  String get ntStatusDiscarded;

  /// Notation dialects / training (0105-0106): ntStatusRead
  ///
  /// In ja, this message translates to:
  /// **'未学習'**
  String get ntStatusRead;

  /// Notation dialects / training (0105-0106): ntFieldJan
  ///
  /// In ja, this message translates to:
  /// **'JAN'**
  String get ntFieldJan;

  /// Notation dialects / training (0105-0106): ntFieldMaker
  ///
  /// In ja, this message translates to:
  /// **'メーカー'**
  String get ntFieldMaker;

  /// Notation dialects / training (0105-0106): ntFieldName
  ///
  /// In ja, this message translates to:
  /// **'品名'**
  String get ntFieldName;

  /// Notation dialects / training (0105-0106): ntFieldCode
  ///
  /// In ja, this message translates to:
  /// **'品番'**
  String get ntFieldCode;

  /// Notation dialects / training (0105-0106): ntFieldNameCode
  ///
  /// In ja, this message translates to:
  /// **'品名＋品番（1欄）'**
  String get ntFieldNameCode;

  /// Notation dialects / training (0105-0106): ntFieldQuantity
  ///
  /// In ja, this message translates to:
  /// **'数量'**
  String get ntFieldQuantity;

  /// Notation dialects / training (0105-0106): ntFieldCaseQuantity
  ///
  /// In ja, this message translates to:
  /// **'入数'**
  String get ntFieldCaseQuantity;

  /// Notation dialects / training (0105-0106): ntFieldCases
  ///
  /// In ja, this message translates to:
  /// **'ケース数'**
  String get ntFieldCases;

  /// Notation dialects / training (0105-0106): ntFieldUnitPrice
  ///
  /// In ja, this message translates to:
  /// **'単価'**
  String get ntFieldUnitPrice;

  /// Notation dialects / training (0105-0106): ntFieldAmount
  ///
  /// In ja, this message translates to:
  /// **'金額'**
  String get ntFieldAmount;

  /// Notation dialects / training (0105-0106): ntFieldSpec
  ///
  /// In ja, this message translates to:
  /// **'規格'**
  String get ntFieldSpec;

  /// Notation dialects / training (0105-0106): ntFieldTaxRate
  ///
  /// In ja, this message translates to:
  /// **'税率'**
  String get ntFieldTaxRate;

  /// Notation dialects / training (0105-0106): ntFieldDate
  ///
  /// In ja, this message translates to:
  /// **'日付'**
  String get ntFieldDate;

  /// Notation dialects / training (0105-0106): ntFieldIgnore
  ///
  /// In ja, this message translates to:
  /// **'使わない'**
  String get ntFieldIgnore;

  /// Notation dialects / training (0105-0106): ntFieldUnknown
  ///
  /// In ja, this message translates to:
  /// **'不明'**
  String get ntFieldUnknown;

  /// Notation dialects / training (0105-0106): ntSourcePartner
  ///
  /// In ja, this message translates to:
  /// **'この商社で学習済み'**
  String get ntSourcePartner;

  /// Notation dialects / training (0105-0106): ntSourceGlobal
  ///
  /// In ja, this message translates to:
  /// **'共通の見出し'**
  String get ntSourceGlobal;

  /// Notation dialects / training (0105-0106): ntSourceContains
  ///
  /// In ja, this message translates to:
  /// **'見出しの一部から推定'**
  String get ntSourceContains;

  /// Notation dialects / training (0105-0106): ntSourceValues
  ///
  /// In ja, this message translates to:
  /// **'値から判定'**
  String get ntSourceValues;

  /// Notation dialects / training (0105-0106): ntSourceAi
  ///
  /// In ja, this message translates to:
  /// **'AIが判定'**
  String get ntSourceAi;

  /// Notation dialects / training (0105-0106): ntSourceOverride
  ///
  /// In ja, this message translates to:
  /// **'手動で修正'**
  String get ntSourceOverride;

  /// Notation dialects / training (0105-0106): ntSourceNone
  ///
  /// In ja, this message translates to:
  /// **'判定できず'**
  String get ntSourceNone;

  /// Notation dialects / training (0105-0106): ntFlagUnresolved
  ///
  /// In ja, this message translates to:
  /// **'自社商品なし'**
  String get ntFlagUnresolved;

  /// Notation dialects / training (0105-0106): ntFlagJanCheck
  ///
  /// In ja, this message translates to:
  /// **'JANのチェック数字が不正'**
  String get ntFlagJanCheck;

  /// Notation dialects / training (0105-0106): ntFlagNoJan
  ///
  /// In ja, this message translates to:
  /// **'JANなし'**
  String get ntFlagNoJan;

  /// Notation dialects / training (0105-0106): ntFlagNoMaker
  ///
  /// In ja, this message translates to:
  /// **'メーカーなし'**
  String get ntFlagNoMaker;

  /// Notation dialects / training (0105-0106): ntFlagNoQuantity
  ///
  /// In ja, this message translates to:
  /// **'数量なし'**
  String get ntFlagNoQuantity;

  /// Notation dialects / training (0105-0106): ntFlagAmount
  ///
  /// In ja, this message translates to:
  /// **'金額≠数量×単価'**
  String get ntFlagAmount;

  /// Notation dialects / training (0105-0106): ntFlagAiDisagree
  ///
  /// In ja, this message translates to:
  /// **'AIの2回の読みが不一致'**
  String get ntFlagAiDisagree;

  /// Notation dialects / training (0105-0106): ntFlagAiDisagreeOn
  ///
  /// In ja, this message translates to:
  /// **'AIの読みが不一致：{field}'**
  String ntFlagAiDisagreeOn(String field);

  /// Notation dialects / training (0105-0106): ntFlagSplitDisagree
  ///
  /// In ja, this message translates to:
  /// **'品名と品番の分け方が不一致'**
  String get ntFlagSplitDisagree;

  /// Notation dialects / training (0105-0106): ntFlagSplitSingle
  ///
  /// In ja, this message translates to:
  /// **'品名と品番を分解（片方の方法のみ）'**
  String get ntFlagSplitSingle;

  /// Notation dialects / training (0105-0106): ntFlagSplitFailed
  ///
  /// In ja, this message translates to:
  /// **'品名と品番を分けられず'**
  String get ntFlagSplitFailed;

  /// Notation dialects / training (0105-0106): ntFlagAdded
  ///
  /// In ja, this message translates to:
  /// **'確認で追加された行'**
  String get ntFlagAdded;

  /// Notation dialects / training (0105-0106): ntFlagDropped
  ///
  /// In ja, this message translates to:
  /// **'確認で消えた行'**
  String get ntFlagDropped;

  /// Notation dialects / training (0105-0106): ntFlagNotVerified
  ///
  /// In ja, this message translates to:
  /// **'確認の読み取りなし'**
  String get ntFlagNotVerified;

  /// Notation dialects / training (0105-0106): ntFlagQtyFromCases
  ///
  /// In ja, this message translates to:
  /// **'数量＝入数×ケース数'**
  String get ntFlagQtyFromCases;

  /// Notation dialects / training (0105-0106): ntMatchJan
  ///
  /// In ja, this message translates to:
  /// **'JANで一致'**
  String get ntMatchJan;

  /// Notation dialects / training (0105-0106): ntMatchDialect
  ///
  /// In ja, this message translates to:
  /// **'学習済みの方言で一致'**
  String get ntMatchDialect;

  /// Notation dialects / training (0105-0106): ntMatchSku
  ///
  /// In ja, this message translates to:
  /// **'自社品番で一致'**
  String get ntMatchSku;

  /// Notation dialects / training (0105-0106): ntMatchName
  ///
  /// In ja, this message translates to:
  /// **'自社品名で一致'**
  String get ntMatchName;

  /// Notation dialects / training (0105-0106): ntMatchManual
  ///
  /// In ja, this message translates to:
  /// **'手動で選択'**
  String get ntMatchManual;

  /// Notation dialects / training (0105-0106): ntMatchNone
  ///
  /// In ja, this message translates to:
  /// **''**
  String get ntMatchNone;

  /// No description provided for @importSupplierWriting.
  ///
  /// In ja, this message translates to:
  /// **'先方の表記：{text}'**
  String importSupplierWriting(String text);

  /// No description provided for @importUnresolvedLines.
  ///
  /// In ja, this message translates to:
  /// **'{count}行が自社商品に未変換です。選ぶか、このまま登録して検品で変換してください。'**
  String importUnresolvedLines(int count);

  /// No description provided for @importColumnsRead.
  ///
  /// In ja, this message translates to:
  /// **'列の読み方'**
  String get importColumnsRead;

  /// No description provided for @importNotVerified.
  ///
  /// In ja, this message translates to:
  /// **'AIの確認の読み取りに失敗しました（1回のみの読み取り）。明細をよく確認してください。'**
  String get importNotVerified;

  /// No description provided for @groupSupplyChain.
  ///
  /// In ja, this message translates to:
  /// **'サプライチェーン'**
  String get groupSupplyChain;

  /// No description provided for @featScDashboard.
  ///
  /// In ja, this message translates to:
  /// **'収益ダッシュボード'**
  String get featScDashboard;

  /// No description provided for @featScDashboardDesc.
  ///
  /// In ja, this message translates to:
  /// **'仕入から販売まで、最終的にいくら残るか'**
  String get featScDashboardDesc;

  /// No description provided for @featScSuppliers.
  ///
  /// In ja, this message translates to:
  /// **'仕入先比較'**
  String get featScSuppliers;

  /// No description provided for @featScSuppliersDesc.
  ///
  /// In ja, this message translates to:
  /// **'最安値ではなく最終利益で比べる'**
  String get featScSuppliersDesc;

  /// No description provided for @featScCosts.
  ///
  /// In ja, this message translates to:
  /// **'原価構造'**
  String get featScCosts;

  /// No description provided for @featScCostsDesc.
  ///
  /// In ja, this message translates to:
  /// **'原価の内訳と、原価・関税・為替のルール'**
  String get featScCostsDesc;

  /// No description provided for @featScRoutes.
  ///
  /// In ja, this message translates to:
  /// **'物流ルート'**
  String get featScRoutes;

  /// No description provided for @featScRoutesDesc.
  ///
  /// In ja, this message translates to:
  /// **'船・航空・トラック・通関の経路と費用'**
  String get featScRoutesDesc;

  /// No description provided for @featScSimulation.
  ///
  /// In ja, this message translates to:
  /// **'利益シミュレーション'**
  String get featScSimulation;

  /// No description provided for @featScSimulationDesc.
  ///
  /// In ja, this message translates to:
  /// **'仕入先・掛率・送料・関税・為替などを変えて試算'**
  String get featScSimulationDesc;

  /// No description provided for @featScRisk.
  ///
  /// In ja, this message translates to:
  /// **'リスク分析'**
  String get featScRisk;

  /// No description provided for @featScRiskDesc.
  ///
  /// In ja, this message translates to:
  /// **'仕入先・拠点・ルートのリスクとその理由'**
  String get featScRiskDesc;

  /// No description provided for @featScBottleneck.
  ///
  /// In ja, this message translates to:
  /// **'ボトルネック'**
  String get featScBottleneck;

  /// No description provided for @featScBottleneckDesc.
  ///
  /// In ja, this message translates to:
  /// **'容量の逼迫と、止まった時の影響'**
  String get featScBottleneckDesc;

  /// No description provided for @featScHistory.
  ///
  /// In ja, this message translates to:
  /// **'シナリオ履歴'**
  String get featScHistory;

  /// No description provided for @featScHistoryDesc.
  ///
  /// In ja, this message translates to:
  /// **'保存したシナリオと実行結果'**
  String get featScHistoryDesc;

  /// No description provided for @scRevenue.
  ///
  /// In ja, this message translates to:
  /// **'売上'**
  String get scRevenue;

  /// No description provided for @scPurchase.
  ///
  /// In ja, this message translates to:
  /// **'仕入原価'**
  String get scPurchase;

  /// No description provided for @scFxImpact.
  ///
  /// In ja, this message translates to:
  /// **'為替影響'**
  String get scFxImpact;

  /// No description provided for @scLogistics.
  ///
  /// In ja, this message translates to:
  /// **'物流費'**
  String get scLogistics;

  /// No description provided for @scCustoms.
  ///
  /// In ja, this message translates to:
  /// **'通関・関税'**
  String get scCustoms;

  /// No description provided for @scWarehouse.
  ///
  /// In ja, this message translates to:
  /// **'倉庫費'**
  String get scWarehouse;

  /// No description provided for @scLabor.
  ///
  /// In ja, this message translates to:
  /// **'人件費'**
  String get scLabor;

  /// No description provided for @scOther.
  ///
  /// In ja, this message translates to:
  /// **'その他経費'**
  String get scOther;

  /// No description provided for @scTotalCost.
  ///
  /// In ja, this message translates to:
  /// **'総原価'**
  String get scTotalCost;

  /// No description provided for @scProfit.
  ///
  /// In ja, this message translates to:
  /// **'粗利益'**
  String get scProfit;

  /// No description provided for @scMargin.
  ///
  /// In ja, this message translates to:
  /// **'利益率'**
  String get scMargin;

  /// No description provided for @scLeadTime.
  ///
  /// In ja, this message translates to:
  /// **'平均納期'**
  String get scLeadTime;

  /// No description provided for @scSalesRelated.
  ///
  /// In ja, this message translates to:
  /// **'販売関連費'**
  String get scSalesRelated;

  /// No description provided for @scRecoverable.
  ///
  /// In ja, this message translates to:
  /// **'控除・還付対象（原価外）'**
  String get scRecoverable;

  /// No description provided for @scLinePurchase.
  ///
  /// In ja, this message translates to:
  /// **'仕入'**
  String get scLinePurchase;

  /// No description provided for @scLineFx.
  ///
  /// In ja, this message translates to:
  /// **'為替影響'**
  String get scLineFx;

  /// No description provided for @scLineIntlFreight.
  ///
  /// In ja, this message translates to:
  /// **'国際送料'**
  String get scLineIntlFreight;

  /// No description provided for @scLineInsurance.
  ///
  /// In ja, this message translates to:
  /// **'保険'**
  String get scLineInsurance;

  /// No description provided for @scLineDuty.
  ///
  /// In ja, this message translates to:
  /// **'関税'**
  String get scLineDuty;

  /// No description provided for @scLineImportTax.
  ///
  /// In ja, this message translates to:
  /// **'輸入税（控除不可）'**
  String get scLineImportTax;

  /// No description provided for @scLineCustomsFee.
  ///
  /// In ja, this message translates to:
  /// **'通関費'**
  String get scLineCustomsFee;

  /// No description provided for @scLinePortFee.
  ///
  /// In ja, this message translates to:
  /// **'港湾・空港費'**
  String get scLinePortFee;

  /// No description provided for @scLineDomesticFreight.
  ///
  /// In ja, this message translates to:
  /// **'国内送料'**
  String get scLineDomesticFreight;

  /// No description provided for @scLineWarehouse.
  ///
  /// In ja, this message translates to:
  /// **'倉庫費'**
  String get scLineWarehouse;

  /// No description provided for @scLineReceiving.
  ///
  /// In ja, this message translates to:
  /// **'入荷作業'**
  String get scLineReceiving;

  /// No description provided for @scLineInspection.
  ///
  /// In ja, this message translates to:
  /// **'検品'**
  String get scLineInspection;

  /// No description provided for @scLinePacking.
  ///
  /// In ja, this message translates to:
  /// **'梱包'**
  String get scLinePacking;

  /// No description provided for @scLineLabor.
  ///
  /// In ja, this message translates to:
  /// **'人件費'**
  String get scLineLabor;

  /// No description provided for @scLineOverhead.
  ///
  /// In ja, this message translates to:
  /// **'共通経費'**
  String get scLineOverhead;

  /// No description provided for @scLineOther.
  ///
  /// In ja, this message translates to:
  /// **'その他'**
  String get scLineOther;

  /// No description provided for @scLineRevenue.
  ///
  /// In ja, this message translates to:
  /// **'売上'**
  String get scLineRevenue;

  /// No description provided for @scLandedCost.
  ///
  /// In ja, this message translates to:
  /// **'最終原価'**
  String get scLandedCost;

  /// No description provided for @scSalesPrice.
  ///
  /// In ja, this message translates to:
  /// **'販売価格'**
  String get scSalesPrice;

  /// No description provided for @scProfitPerUnit.
  ///
  /// In ja, this message translates to:
  /// **'利益/個'**
  String get scProfitPerUnit;

  /// No description provided for @scAnnualProfit.
  ///
  /// In ja, this message translates to:
  /// **'年間利益'**
  String get scAnnualProfit;

  /// No description provided for @scVolume.
  ///
  /// In ja, this message translates to:
  /// **'年間数量'**
  String get scVolume;

  /// No description provided for @scDays.
  ///
  /// In ja, this message translates to:
  /// **'{days}日'**
  String scDays(String days);

  /// No description provided for @scCurrent.
  ///
  /// In ja, this message translates to:
  /// **'現在'**
  String get scCurrent;

  /// No description provided for @scSimulated.
  ///
  /// In ja, this message translates to:
  /// **'シミュレーション'**
  String get scSimulated;

  /// No description provided for @scDifference.
  ///
  /// In ja, this message translates to:
  /// **'現在との差'**
  String get scDifference;

  /// No description provided for @scCurrentValues.
  ///
  /// In ja, this message translates to:
  /// **'現在値'**
  String get scCurrentValues;

  /// No description provided for @scSimulatedValues.
  ///
  /// In ja, this message translates to:
  /// **'シミュレーション値（実データは変わりません）'**
  String get scSimulatedValues;

  /// No description provided for @scDrivers.
  ///
  /// In ja, this message translates to:
  /// **'変動の原因'**
  String get scDrivers;

  /// No description provided for @scNoData.
  ///
  /// In ja, this message translates to:
  /// **'まだ原価を計算できる商品がありません'**
  String get scNoData;

  /// No description provided for @scNoDataBody.
  ///
  /// In ja, this message translates to:
  /// **'商品ごとの仕入条件（仕入先・価格・掛率）を登録すると、原価と利益を計算します。発注や納品書の単価から取り込むこともできます。'**
  String get scNoDataBody;

  /// No description provided for @scSeed.
  ///
  /// In ja, this message translates to:
  /// **'仕入実績から取り込む'**
  String get scSeed;

  /// No description provided for @scSeeded.
  ///
  /// In ja, this message translates to:
  /// **'発注から{po}件、納品書から{doc}件を取り込みました'**
  String scSeeded(int po, int doc);

  /// No description provided for @scSnapshot.
  ///
  /// In ja, this message translates to:
  /// **'スナップショット保存'**
  String get scSnapshot;

  /// No description provided for @scSnapshotSaved.
  ///
  /// In ja, this message translates to:
  /// **'現在の状態を保存しました'**
  String get scSnapshotSaved;

  /// No description provided for @scAllWarehouses.
  ///
  /// In ja, this message translates to:
  /// **'全倉庫'**
  String get scAllWarehouses;

  /// No description provided for @scAlerts.
  ///
  /// In ja, this message translates to:
  /// **'要注意'**
  String get scAlerts;

  /// No description provided for @scAlertBottlenecks.
  ///
  /// In ja, this message translates to:
  /// **'容量超過・停止 {count}件'**
  String scAlertBottlenecks(int count);

  /// No description provided for @scAlertRisks.
  ///
  /// In ja, this message translates to:
  /// **'高リスク {count}件'**
  String scAlertRisks(int count);

  /// No description provided for @scAlertNoSupply.
  ///
  /// In ja, this message translates to:
  /// **'仕入先のない商品 {count}件'**
  String scAlertNoSupply(int count);

  /// No description provided for @scAlertLoss.
  ///
  /// In ja, this message translates to:
  /// **'赤字の商品 {count}件'**
  String scAlertLoss(int count);

  /// No description provided for @scProductsTitle.
  ///
  /// In ja, this message translates to:
  /// **'商品別の利益'**
  String get scProductsTitle;

  /// No description provided for @scCostBreakdown.
  ///
  /// In ja, this message translates to:
  /// **'原価の内訳'**
  String get scCostBreakdown;

  /// No description provided for @scWaterfall.
  ///
  /// In ja, this message translates to:
  /// **'販売価格から利益まで（1個あたり）'**
  String get scWaterfall;

  /// No description provided for @scChosen.
  ///
  /// In ja, this message translates to:
  /// **'現在の仕入'**
  String get scChosen;

  /// No description provided for @scNoRoute.
  ///
  /// In ja, this message translates to:
  /// **'ルート未登録'**
  String get scNoRoute;

  /// No description provided for @scProduct.
  ///
  /// In ja, this message translates to:
  /// **'商品'**
  String get scProduct;

  /// No description provided for @scChooseProduct.
  ///
  /// In ja, this message translates to:
  /// **'商品を選んでください'**
  String get scChooseProduct;

  /// No description provided for @scQuantity.
  ///
  /// In ja, this message translates to:
  /// **'1回の発注数量'**
  String get scQuantity;

  /// No description provided for @scRates.
  ///
  /// In ja, this message translates to:
  /// **'掛率を比較'**
  String get scRates;

  /// No description provided for @scRatesHint.
  ///
  /// In ja, this message translates to:
  /// **'例: 65,70,75'**
  String get scRatesHint;

  /// No description provided for @scDiscountRate.
  ///
  /// In ja, this message translates to:
  /// **'掛率'**
  String get scDiscountRate;

  /// No description provided for @scUnitPrice.
  ///
  /// In ja, this message translates to:
  /// **'仕入単価'**
  String get scUnitPrice;

  /// No description provided for @scListPrice.
  ///
  /// In ja, this message translates to:
  /// **'定価'**
  String get scListPrice;

  /// No description provided for @scCurrency.
  ///
  /// In ja, this message translates to:
  /// **'通貨'**
  String get scCurrency;

  /// No description provided for @scMoq.
  ///
  /// In ja, this message translates to:
  /// **'MOQ'**
  String get scMoq;

  /// No description provided for @scOrderLot.
  ///
  /// In ja, this message translates to:
  /// **'発注ロット'**
  String get scOrderLot;

  /// No description provided for @scLeadTimeDays.
  ///
  /// In ja, this message translates to:
  /// **'納期（日）'**
  String get scLeadTimeDays;

  /// No description provided for @scPaymentTerms.
  ///
  /// In ja, this message translates to:
  /// **'支払条件'**
  String get scPaymentTerms;

  /// No description provided for @scPrimary.
  ///
  /// In ja, this message translates to:
  /// **'主要仕入先'**
  String get scPrimary;

  /// No description provided for @scDefaultRoute.
  ///
  /// In ja, this message translates to:
  /// **'標準ルート'**
  String get scDefaultRoute;

  /// No description provided for @scSupplyTerms.
  ///
  /// In ja, this message translates to:
  /// **'仕入条件'**
  String get scSupplyTerms;

  /// No description provided for @scAddTerm.
  ///
  /// In ja, this message translates to:
  /// **'仕入条件を追加'**
  String get scAddTerm;

  /// No description provided for @scSupplier.
  ///
  /// In ja, this message translates to:
  /// **'仕入先'**
  String get scSupplier;

  /// No description provided for @scSupplierStats.
  ///
  /// In ja, this message translates to:
  /// **'仕入先の実績'**
  String get scSupplierStats;

  /// No description provided for @scStatLine.
  ///
  /// In ja, this message translates to:
  /// **'{products}品目・単独供給{sole}・発注{orders}件'**
  String scStatLine(int products, int sole, int orders);

  /// No description provided for @scLateRate.
  ///
  /// In ja, this message translates to:
  /// **'遅延率'**
  String get scLateRate;

  /// No description provided for @scDefectRate.
  ///
  /// In ja, this message translates to:
  /// **'不良率'**
  String get scDefectRate;

  /// No description provided for @scPurchased.
  ///
  /// In ja, this message translates to:
  /// **'仕入額'**
  String get scPurchased;

  /// No description provided for @scProfile.
  ///
  /// In ja, this message translates to:
  /// **'商品の前提'**
  String get scProfile;

  /// No description provided for @scEditProfile.
  ///
  /// In ja, this message translates to:
  /// **'前提を編集'**
  String get scEditProfile;

  /// No description provided for @scAnnualVolume.
  ///
  /// In ja, this message translates to:
  /// **'年間販売数量'**
  String get scAnnualVolume;

  /// No description provided for @scAnnualVolumeHint.
  ///
  /// In ja, this message translates to:
  /// **'空欄: 過去12か月の出荷数'**
  String get scAnnualVolumeHint;

  /// No description provided for @scSalesPriceHint.
  ///
  /// In ja, this message translates to:
  /// **'空欄: 商品ライブラリーの価格'**
  String get scSalesPriceHint;

  /// No description provided for @scWeight.
  ///
  /// In ja, this message translates to:
  /// **'重量（kg/個）'**
  String get scWeight;

  /// No description provided for @scUnitsPerCarton.
  ///
  /// In ja, this message translates to:
  /// **'入数（個/箱）'**
  String get scUnitsPerCarton;

  /// No description provided for @scStorageDays.
  ///
  /// In ja, this message translates to:
  /// **'保管日数'**
  String get scStorageDays;

  /// No description provided for @scHsCode.
  ///
  /// In ja, this message translates to:
  /// **'HSコード'**
  String get scHsCode;

  /// No description provided for @scOriginCountry.
  ///
  /// In ja, this message translates to:
  /// **'原産国'**
  String get scOriginCountry;

  /// No description provided for @scCostRules.
  ///
  /// In ja, this message translates to:
  /// **'原価ルール'**
  String get scCostRules;

  /// No description provided for @scTariffRules.
  ///
  /// In ja, this message translates to:
  /// **'関税・輸入税'**
  String get scTariffRules;

  /// No description provided for @scFxRates.
  ///
  /// In ja, this message translates to:
  /// **'為替'**
  String get scFxRates;

  /// No description provided for @scByProduct.
  ///
  /// In ja, this message translates to:
  /// **'商品別'**
  String get scByProduct;

  /// No description provided for @scAddRule.
  ///
  /// In ja, this message translates to:
  /// **'ルールを追加'**
  String get scAddRule;

  /// No description provided for @scRuleName.
  ///
  /// In ja, this message translates to:
  /// **'名称'**
  String get scRuleName;

  /// No description provided for @scCategory.
  ///
  /// In ja, this message translates to:
  /// **'区分'**
  String get scCategory;

  /// No description provided for @scBasis.
  ///
  /// In ja, this message translates to:
  /// **'単位'**
  String get scBasis;

  /// No description provided for @scAmount.
  ///
  /// In ja, this message translates to:
  /// **'金額・率'**
  String get scAmount;

  /// No description provided for @scAmountPercentHint.
  ///
  /// In ja, this message translates to:
  /// **'率は小数で（3% = 0.03）'**
  String get scAmountPercentHint;

  /// No description provided for @scUnitsPerBasis.
  ///
  /// In ja, this message translates to:
  /// **'基準数量'**
  String get scUnitsPerBasis;

  /// No description provided for @scUnitsPerBasisHint.
  ///
  /// In ja, this message translates to:
  /// **'時間あたり処理数・箱の入数・月の配賦数量など'**
  String get scUnitsPerBasisHint;

  /// No description provided for @scExpensed.
  ///
  /// In ja, this message translates to:
  /// **'原価に含める（外すと控除・還付扱い）'**
  String get scExpensed;

  /// No description provided for @scAll.
  ///
  /// In ja, this message translates to:
  /// **'すべて'**
  String get scAll;

  /// No description provided for @scCatStorage.
  ///
  /// In ja, this message translates to:
  /// **'保管'**
  String get scCatStorage;

  /// No description provided for @scCatReceiving.
  ///
  /// In ja, this message translates to:
  /// **'入荷作業'**
  String get scCatReceiving;

  /// No description provided for @scCatInspection.
  ///
  /// In ja, this message translates to:
  /// **'検品'**
  String get scCatInspection;

  /// No description provided for @scCatPacking.
  ///
  /// In ja, this message translates to:
  /// **'梱包'**
  String get scCatPacking;

  /// No description provided for @scCatPicking.
  ///
  /// In ja, this message translates to:
  /// **'ピッキング'**
  String get scCatPicking;

  /// No description provided for @scCatShipping.
  ///
  /// In ja, this message translates to:
  /// **'出荷作業'**
  String get scCatShipping;

  /// No description provided for @scCatLabor.
  ///
  /// In ja, this message translates to:
  /// **'人件費'**
  String get scCatLabor;

  /// No description provided for @scCatOverhead.
  ///
  /// In ja, this message translates to:
  /// **'共通経費'**
  String get scCatOverhead;

  /// No description provided for @scCatDomesticFreight.
  ///
  /// In ja, this message translates to:
  /// **'国内配送'**
  String get scCatDomesticFreight;

  /// No description provided for @scCatSalesRelated.
  ///
  /// In ja, this message translates to:
  /// **'販売関連'**
  String get scCatSalesRelated;

  /// No description provided for @scCatOther.
  ///
  /// In ja, this message translates to:
  /// **'その他'**
  String get scCatOther;

  /// No description provided for @scBasisPerUnit.
  ///
  /// In ja, this message translates to:
  /// **'1個あたり'**
  String get scBasisPerUnit;

  /// No description provided for @scBasisPerUnitMonth.
  ///
  /// In ja, this message translates to:
  /// **'1個・1か月あたり'**
  String get scBasisPerUnitMonth;

  /// No description provided for @scBasisPerCarton.
  ///
  /// In ja, this message translates to:
  /// **'1箱あたり'**
  String get scBasisPerCarton;

  /// No description provided for @scBasisPerLine.
  ///
  /// In ja, this message translates to:
  /// **'1行あたり'**
  String get scBasisPerLine;

  /// No description provided for @scBasisPerOrder.
  ///
  /// In ja, this message translates to:
  /// **'1件あたり'**
  String get scBasisPerOrder;

  /// No description provided for @scBasisPerHour.
  ///
  /// In ja, this message translates to:
  /// **'1時間あたり'**
  String get scBasisPerHour;

  /// No description provided for @scBasisPercentRevenue.
  ///
  /// In ja, this message translates to:
  /// **'売上に対する率'**
  String get scBasisPercentRevenue;

  /// No description provided for @scBasisPercentPurchase.
  ///
  /// In ja, this message translates to:
  /// **'仕入に対する率'**
  String get scBasisPercentPurchase;

  /// No description provided for @scBasisFixedMonthly.
  ///
  /// In ja, this message translates to:
  /// **'月額固定'**
  String get scBasisFixedMonthly;

  /// No description provided for @scTariffRate.
  ///
  /// In ja, this message translates to:
  /// **'関税率'**
  String get scTariffRate;

  /// No description provided for @scImportTaxRate.
  ///
  /// In ja, this message translates to:
  /// **'輸入消費税等の率'**
  String get scImportTaxRate;

  /// No description provided for @scImportTaxRecoverable.
  ///
  /// In ja, this message translates to:
  /// **'輸入消費税等は控除・還付される'**
  String get scImportTaxRecoverable;

  /// No description provided for @scOtherRate.
  ///
  /// In ja, this message translates to:
  /// **'その他の輸入税率'**
  String get scOtherRate;

  /// No description provided for @scValuation.
  ///
  /// In ja, this message translates to:
  /// **'課税価格'**
  String get scValuation;

  /// No description provided for @scHsPrefix.
  ///
  /// In ja, this message translates to:
  /// **'HSコード（前方一致）'**
  String get scHsPrefix;

  /// No description provided for @scDestinationCountry.
  ///
  /// In ja, this message translates to:
  /// **'仕向国'**
  String get scDestinationCountry;

  /// No description provided for @scAddTariff.
  ///
  /// In ja, this message translates to:
  /// **'関税ルールを追加'**
  String get scAddTariff;

  /// No description provided for @scRateToBase.
  ///
  /// In ja, this message translates to:
  /// **'換算レート（1単位あたり）'**
  String get scRateToBase;

  /// No description provided for @scAddFx.
  ///
  /// In ja, this message translates to:
  /// **'通貨を追加'**
  String get scAddFx;

  /// No description provided for @scRoutesTab.
  ///
  /// In ja, this message translates to:
  /// **'ルート'**
  String get scRoutesTab;

  /// No description provided for @scNodesTab.
  ///
  /// In ja, this message translates to:
  /// **'拠点'**
  String get scNodesTab;

  /// No description provided for @scAddRoute.
  ///
  /// In ja, this message translates to:
  /// **'ルートを追加'**
  String get scAddRoute;

  /// No description provided for @scAddNode.
  ///
  /// In ja, this message translates to:
  /// **'拠点を追加'**
  String get scAddNode;

  /// No description provided for @scRouteName.
  ///
  /// In ja, this message translates to:
  /// **'ルート名'**
  String get scRouteName;

  /// No description provided for @scLegs.
  ///
  /// In ja, this message translates to:
  /// **'区間'**
  String get scLegs;

  /// No description provided for @scAddLeg.
  ///
  /// In ja, this message translates to:
  /// **'区間を追加'**
  String get scAddLeg;

  /// No description provided for @scFrom.
  ///
  /// In ja, this message translates to:
  /// **'出発'**
  String get scFrom;

  /// No description provided for @scTo.
  ///
  /// In ja, this message translates to:
  /// **'到着'**
  String get scTo;

  /// No description provided for @scMode.
  ///
  /// In ja, this message translates to:
  /// **'輸送手段'**
  String get scMode;

  /// No description provided for @scBaseCost.
  ///
  /// In ja, this message translates to:
  /// **'基本料金（1便）'**
  String get scBaseCost;

  /// No description provided for @scCostPerKg.
  ///
  /// In ja, this message translates to:
  /// **'kg単価'**
  String get scCostPerKg;

  /// No description provided for @scCostPerUnit.
  ///
  /// In ja, this message translates to:
  /// **'1個あたり'**
  String get scCostPerUnit;

  /// No description provided for @scInsuranceRate.
  ///
  /// In ja, this message translates to:
  /// **'保険料率'**
  String get scInsuranceRate;

  /// No description provided for @scCapacityKg.
  ///
  /// In ja, this message translates to:
  /// **'容量（kg/月）'**
  String get scCapacityKg;

  /// No description provided for @scCapacityUnits.
  ///
  /// In ja, this message translates to:
  /// **'容量（個/月）'**
  String get scCapacityUnits;

  /// No description provided for @scCustomsClearance.
  ///
  /// In ja, this message translates to:
  /// **'この区間で輸入通関'**
  String get scCustomsClearance;

  /// No description provided for @scCustomsCost.
  ///
  /// In ja, this message translates to:
  /// **'通関費（1便）'**
  String get scCustomsCost;

  /// No description provided for @scRisk.
  ///
  /// In ja, this message translates to:
  /// **'リスク'**
  String get scRisk;

  /// No description provided for @scApplyRoute.
  ///
  /// In ja, this message translates to:
  /// **'このルートをシナリオに適用'**
  String get scApplyRoute;

  /// No description provided for @scNoRoutes.
  ///
  /// In ja, this message translates to:
  /// **'まだルートがありません'**
  String get scNoRoutes;

  /// No description provided for @scNoRoutesBody.
  ///
  /// In ja, this message translates to:
  /// **'仕入先から倉庫までの区間（船・航空・トラック・通関）を登録すると、送料・関税・納期が計算に入ります。'**
  String get scNoRoutesBody;

  /// No description provided for @scNodeName.
  ///
  /// In ja, this message translates to:
  /// **'名称'**
  String get scNodeName;

  /// No description provided for @scNodeKind.
  ///
  /// In ja, this message translates to:
  /// **'種類'**
  String get scNodeKind;

  /// No description provided for @scCountry.
  ///
  /// In ja, this message translates to:
  /// **'国コード'**
  String get scCountry;

  /// No description provided for @scDwellDays.
  ///
  /// In ja, this message translates to:
  /// **'滞留日数'**
  String get scDwellDays;

  /// No description provided for @scHandlingPerUnit.
  ///
  /// In ja, this message translates to:
  /// **'荷役費（1個）'**
  String get scHandlingPerUnit;

  /// No description provided for @scKindSupplier.
  ///
  /// In ja, this message translates to:
  /// **'仕入先'**
  String get scKindSupplier;

  /// No description provided for @scKindPort.
  ///
  /// In ja, this message translates to:
  /// **'港'**
  String get scKindPort;

  /// No description provided for @scKindAirport.
  ///
  /// In ja, this message translates to:
  /// **'空港'**
  String get scKindAirport;

  /// No description provided for @scKindCustoms.
  ///
  /// In ja, this message translates to:
  /// **'通関'**
  String get scKindCustoms;

  /// No description provided for @scKindWarehouse.
  ///
  /// In ja, this message translates to:
  /// **'倉庫'**
  String get scKindWarehouse;

  /// No description provided for @scKindDc.
  ///
  /// In ja, this message translates to:
  /// **'配送センター'**
  String get scKindDc;

  /// No description provided for @scKindCustomer.
  ///
  /// In ja, this message translates to:
  /// **'顧客'**
  String get scKindCustomer;

  /// No description provided for @scKindHub.
  ///
  /// In ja, this message translates to:
  /// **'中継拠点'**
  String get scKindHub;

  /// No description provided for @scModeSea.
  ///
  /// In ja, this message translates to:
  /// **'船便'**
  String get scModeSea;

  /// No description provided for @scModeAir.
  ///
  /// In ja, this message translates to:
  /// **'航空便'**
  String get scModeAir;

  /// No description provided for @scModeTruck.
  ///
  /// In ja, this message translates to:
  /// **'トラック'**
  String get scModeTruck;

  /// No description provided for @scModeRail.
  ///
  /// In ja, this message translates to:
  /// **'鉄道'**
  String get scModeRail;

  /// No description provided for @scModeCourier.
  ///
  /// In ja, this message translates to:
  /// **'宅配・クーリエ'**
  String get scModeCourier;

  /// No description provided for @scModeInternal.
  ///
  /// In ja, this message translates to:
  /// **'社内移動'**
  String get scModeInternal;

  /// No description provided for @scRiskLow.
  ///
  /// In ja, this message translates to:
  /// **'低'**
  String get scRiskLow;

  /// No description provided for @scRiskMedium.
  ///
  /// In ja, this message translates to:
  /// **'中'**
  String get scRiskMedium;

  /// No description provided for @scRiskHigh.
  ///
  /// In ja, this message translates to:
  /// **'高'**
  String get scRiskHigh;

  /// No description provided for @scRiskCritical.
  ///
  /// In ja, this message translates to:
  /// **'重大'**
  String get scRiskCritical;

  /// No description provided for @scScenario.
  ///
  /// In ja, this message translates to:
  /// **'シナリオ'**
  String get scScenario;

  /// No description provided for @scCurrentConditions.
  ///
  /// In ja, this message translates to:
  /// **'現在条件'**
  String get scCurrentConditions;

  /// No description provided for @scScenarioName.
  ///
  /// In ja, this message translates to:
  /// **'シナリオ名'**
  String get scScenarioName;

  /// No description provided for @scSuppliersUsed.
  ///
  /// In ja, this message translates to:
  /// **'使う仕入先'**
  String get scSuppliersUsed;

  /// No description provided for @scRouteChoice.
  ///
  /// In ja, this message translates to:
  /// **'物流'**
  String get scRouteChoice;

  /// No description provided for @scRouteCurrent.
  ///
  /// In ja, this message translates to:
  /// **'現在のルート'**
  String get scRouteCurrent;

  /// No description provided for @scRouteCheapest.
  ///
  /// In ja, this message translates to:
  /// **'最安'**
  String get scRouteCheapest;

  /// No description provided for @scRouteFastest.
  ///
  /// In ja, this message translates to:
  /// **'最速'**
  String get scRouteFastest;

  /// No description provided for @scSupplierChoice.
  ///
  /// In ja, this message translates to:
  /// **'仕入先の選び方'**
  String get scSupplierChoice;

  /// No description provided for @scChoiceCurrent.
  ///
  /// In ja, this message translates to:
  /// **'現在の仕入先'**
  String get scChoiceCurrent;

  /// No description provided for @scChoiceCheapest.
  ///
  /// In ja, this message translates to:
  /// **'利益が最大'**
  String get scChoiceCheapest;

  /// No description provided for @scChoiceFastest.
  ///
  /// In ja, this message translates to:
  /// **'納期が最短'**
  String get scChoiceFastest;

  /// No description provided for @scChanges.
  ///
  /// In ja, this message translates to:
  /// **'変更する条件（±%）'**
  String get scChanges;

  /// No description provided for @scChangeHint.
  ///
  /// In ja, this message translates to:
  /// **'例: +10 は10%上がる、-5 は5%下がる'**
  String get scChangeHint;

  /// No description provided for @scPriceChange.
  ///
  /// In ja, this message translates to:
  /// **'仕入価格'**
  String get scPriceChange;

  /// No description provided for @scFreightChange.
  ///
  /// In ja, this message translates to:
  /// **'送料（全体）'**
  String get scFreightChange;

  /// No description provided for @scSeaChange.
  ///
  /// In ja, this message translates to:
  /// **'海上運賃'**
  String get scSeaChange;

  /// No description provided for @scAirChange.
  ///
  /// In ja, this message translates to:
  /// **'航空運賃'**
  String get scAirChange;

  /// No description provided for @scTariffChange.
  ///
  /// In ja, this message translates to:
  /// **'関税'**
  String get scTariffChange;

  /// No description provided for @scCustomsChange.
  ///
  /// In ja, this message translates to:
  /// **'通関費'**
  String get scCustomsChange;

  /// No description provided for @scWarehouseChange.
  ///
  /// In ja, this message translates to:
  /// **'倉庫費'**
  String get scWarehouseChange;

  /// No description provided for @scLaborChange.
  ///
  /// In ja, this message translates to:
  /// **'人件費'**
  String get scLaborChange;

  /// No description provided for @scOverheadChange.
  ///
  /// In ja, this message translates to:
  /// **'共通経費'**
  String get scOverheadChange;

  /// No description provided for @scFxChange.
  ///
  /// In ja, this message translates to:
  /// **'為替（外貨高）'**
  String get scFxChange;

  /// No description provided for @scSalesPriceChange.
  ///
  /// In ja, this message translates to:
  /// **'販売価格'**
  String get scSalesPriceChange;

  /// No description provided for @scVolumeChange.
  ///
  /// In ja, this message translates to:
  /// **'販売数量'**
  String get scVolumeChange;

  /// No description provided for @scRatesBySupplier.
  ///
  /// In ja, this message translates to:
  /// **'掛率の変更'**
  String get scRatesBySupplier;

  /// No description provided for @scRateNow.
  ///
  /// In ja, this message translates to:
  /// **'現在 {rate}'**
  String scRateNow(String rate);

  /// No description provided for @scAddSupplier.
  ///
  /// In ja, this message translates to:
  /// **'仕入先を追加（試算）'**
  String get scAddSupplier;

  /// No description provided for @scAddedSupplier.
  ///
  /// In ja, this message translates to:
  /// **'追加する仕入先'**
  String get scAddedSupplier;

  /// No description provided for @scApplyRiskEvents.
  ///
  /// In ja, this message translates to:
  /// **'登録済みのリスクを反映'**
  String get scApplyRiskEvents;

  /// No description provided for @scRun.
  ///
  /// In ja, this message translates to:
  /// **'シミュレーション実行'**
  String get scRun;

  /// No description provided for @scSaveScenario.
  ///
  /// In ja, this message translates to:
  /// **'シナリオを保存'**
  String get scSaveScenario;

  /// No description provided for @scScenarioSaved.
  ///
  /// In ja, this message translates to:
  /// **'シナリオを保存しました'**
  String get scScenarioSaved;

  /// No description provided for @scAddToCompare.
  ///
  /// In ja, this message translates to:
  /// **'比較に追加'**
  String get scAddToCompare;

  /// No description provided for @scCompare.
  ///
  /// In ja, this message translates to:
  /// **'比較（最大5件）'**
  String get scCompare;

  /// No description provided for @scRunCompare.
  ///
  /// In ja, this message translates to:
  /// **'比較する'**
  String get scRunCompare;

  /// No description provided for @scClearCompare.
  ///
  /// In ja, this message translates to:
  /// **'クリア'**
  String get scClearCompare;

  /// No description provided for @scCompareFull.
  ///
  /// In ja, this message translates to:
  /// **'比較できるのは5件までです'**
  String get scCompareFull;

  /// No description provided for @scResultTitle.
  ///
  /// In ja, this message translates to:
  /// **'シナリオ: {name}'**
  String scResultTitle(String name);

  /// No description provided for @scProductChanges.
  ///
  /// In ja, this message translates to:
  /// **'商品別の変化'**
  String get scProductChanges;

  /// No description provided for @scNotBest.
  ///
  /// In ja, this message translates to:
  /// **'どれが最良かはシステムでは決めません。利益・納期・リスクを見て判断してください。'**
  String get scNotBest;

  /// No description provided for @scHighRisks.
  ///
  /// In ja, this message translates to:
  /// **'高リスク'**
  String get scHighRisks;

  /// No description provided for @scOverCapacity.
  ///
  /// In ja, this message translates to:
  /// **'容量超過'**
  String get scOverCapacity;

  /// No description provided for @scRiskTitle.
  ///
  /// In ja, this message translates to:
  /// **'リスク一覧'**
  String get scRiskTitle;

  /// No description provided for @scRiskRuleNote.
  ///
  /// In ja, this message translates to:
  /// **'リスク値は設定値・登録リスク・容量・単独供給・遅延率・不良率から計算した説明可能なルールです。'**
  String get scRiskRuleNote;

  /// No description provided for @scRiskEvents.
  ///
  /// In ja, this message translates to:
  /// **'登録済みのリスク'**
  String get scRiskEvents;

  /// No description provided for @scAddRiskEvent.
  ///
  /// In ja, this message translates to:
  /// **'リスクを登録'**
  String get scAddRiskEvent;

  /// No description provided for @scRiskEventTitle.
  ///
  /// In ja, this message translates to:
  /// **'内容'**
  String get scRiskEventTitle;

  /// No description provided for @scRiskKind.
  ///
  /// In ja, this message translates to:
  /// **'種類'**
  String get scRiskKind;

  /// No description provided for @scSeverity.
  ///
  /// In ja, this message translates to:
  /// **'深刻度'**
  String get scSeverity;

  /// No description provided for @scStartsOn.
  ///
  /// In ja, this message translates to:
  /// **'開始日'**
  String get scStartsOn;

  /// No description provided for @scEndsOn.
  ///
  /// In ja, this message translates to:
  /// **'終了日'**
  String get scEndsOn;

  /// No description provided for @scPriceMultiplier.
  ///
  /// In ja, this message translates to:
  /// **'価格倍率'**
  String get scPriceMultiplier;

  /// No description provided for @scCostMultiplier.
  ///
  /// In ja, this message translates to:
  /// **'費用倍率'**
  String get scCostMultiplier;

  /// No description provided for @scCapacityMultiplier.
  ///
  /// In ja, this message translates to:
  /// **'容量倍率'**
  String get scCapacityMultiplier;

  /// No description provided for @scDelayDays.
  ///
  /// In ja, this message translates to:
  /// **'遅延日数'**
  String get scDelayDays;

  /// No description provided for @scTarget.
  ///
  /// In ja, this message translates to:
  /// **'対象'**
  String get scTarget;

  /// No description provided for @scReasonLevel.
  ///
  /// In ja, this message translates to:
  /// **'設定値: {level}'**
  String scReasonLevel(String level);

  /// No description provided for @scReasonSole.
  ///
  /// In ja, this message translates to:
  /// **'単独供給 {count}品目'**
  String scReasonSole(String count);

  /// No description provided for @scReasonEvent.
  ///
  /// In ja, this message translates to:
  /// **'登録リスク: {kind}'**
  String scReasonEvent(String kind);

  /// No description provided for @scReasonLate.
  ///
  /// In ja, this message translates to:
  /// **'遅延率 {rate}%'**
  String scReasonLate(String rate);

  /// No description provided for @scReasonDefect.
  ///
  /// In ja, this message translates to:
  /// **'不良率 {rate}%'**
  String scReasonDefect(String rate);

  /// No description provided for @scReasonLoadExceeded.
  ///
  /// In ja, this message translates to:
  /// **'容量超過'**
  String get scReasonLoadExceeded;

  /// No description provided for @scReasonLoadBusy.
  ///
  /// In ja, this message translates to:
  /// **'容量逼迫'**
  String get scReasonLoadBusy;

  /// No description provided for @scReasonNoAlt.
  ///
  /// In ja, this message translates to:
  /// **'代替経路なし'**
  String get scReasonNoAlt;

  /// No description provided for @scReasonLongLead.
  ///
  /// In ja, this message translates to:
  /// **'長い納期 {days}日'**
  String scReasonLongLead(String days);

  /// No description provided for @scReasonCrossBorder.
  ///
  /// In ja, this message translates to:
  /// **'国境をまたぐ'**
  String get scReasonCrossBorder;

  /// No description provided for @scEvSupplierStop.
  ///
  /// In ja, this message translates to:
  /// **'仕入先停止'**
  String get scEvSupplierStop;

  /// No description provided for @scEvSupplierPrice.
  ///
  /// In ja, this message translates to:
  /// **'仕入先の値上げ'**
  String get scEvSupplierPrice;

  /// No description provided for @scEvSupplierDelay.
  ///
  /// In ja, this message translates to:
  /// **'仕入先の納期遅延'**
  String get scEvSupplierDelay;

  /// No description provided for @scEvRouteStop.
  ///
  /// In ja, this message translates to:
  /// **'ルート停止'**
  String get scEvRouteStop;

  /// No description provided for @scEvModeStop.
  ///
  /// In ja, this message translates to:
  /// **'輸送手段の停止'**
  String get scEvModeStop;

  /// No description provided for @scEvPortStop.
  ///
  /// In ja, this message translates to:
  /// **'港湾停止'**
  String get scEvPortStop;

  /// No description provided for @scEvAirportStop.
  ///
  /// In ja, this message translates to:
  /// **'空港停止'**
  String get scEvAirportStop;

  /// No description provided for @scEvCustomsDelay.
  ///
  /// In ja, this message translates to:
  /// **'通関遅延'**
  String get scEvCustomsDelay;

  /// No description provided for @scEvWarehouseCapacity.
  ///
  /// In ja, this message translates to:
  /// **'倉庫容量不足'**
  String get scEvWarehouseCapacity;

  /// No description provided for @scEvWarehouseStop.
  ///
  /// In ja, this message translates to:
  /// **'倉庫停止'**
  String get scEvWarehouseStop;

  /// No description provided for @scEvDomesticStop.
  ///
  /// In ja, this message translates to:
  /// **'国内配送停止'**
  String get scEvDomesticStop;

  /// No description provided for @scEvStaffShortage.
  ///
  /// In ja, this message translates to:
  /// **'人員不足'**
  String get scEvStaffShortage;

  /// No description provided for @scEvCostSpike.
  ///
  /// In ja, this message translates to:
  /// **'コスト急増'**
  String get scEvCostSpike;

  /// No description provided for @scRiskKindSupplier.
  ///
  /// In ja, this message translates to:
  /// **'仕入先'**
  String get scRiskKindSupplier;

  /// No description provided for @scRiskKindNode.
  ///
  /// In ja, this message translates to:
  /// **'拠点'**
  String get scRiskKindNode;

  /// No description provided for @scRiskKindRoute.
  ///
  /// In ja, this message translates to:
  /// **'ルート'**
  String get scRiskKindRoute;

  /// No description provided for @scNoRisks.
  ///
  /// In ja, this message translates to:
  /// **'リスクの対象がまだありません'**
  String get scNoRisks;

  /// No description provided for @scLoadsTitle.
  ///
  /// In ja, this message translates to:
  /// **'容量と負荷'**
  String get scLoadsTitle;

  /// No description provided for @scStatusOk.
  ///
  /// In ja, this message translates to:
  /// **'余裕'**
  String get scStatusOk;

  /// No description provided for @scStatusBusy.
  ///
  /// In ja, this message translates to:
  /// **'逼迫'**
  String get scStatusBusy;

  /// No description provided for @scStatusExceeded.
  ///
  /// In ja, this message translates to:
  /// **'容量超過'**
  String get scStatusExceeded;

  /// No description provided for @scStatusNoCapacity.
  ///
  /// In ja, this message translates to:
  /// **'容量未設定'**
  String get scStatusNoCapacity;

  /// No description provided for @scStatusStopped.
  ///
  /// In ja, this message translates to:
  /// **'停止'**
  String get scStatusStopped;

  /// No description provided for @scAlternative.
  ///
  /// In ja, this message translates to:
  /// **'代替あり'**
  String get scAlternative;

  /// No description provided for @scNoAlternative.
  ///
  /// In ja, this message translates to:
  /// **'代替なし'**
  String get scNoAlternative;

  /// No description provided for @scPerMonth.
  ///
  /// In ja, this message translates to:
  /// **'{units}個/月'**
  String scPerMonth(String units);

  /// No description provided for @scLoadPercent.
  ///
  /// In ja, this message translates to:
  /// **'負荷 {percent}'**
  String scLoadPercent(String percent);

  /// No description provided for @scDisruptionTitle.
  ///
  /// In ja, this message translates to:
  /// **'障害シミュレーション'**
  String get scDisruptionTitle;

  /// No description provided for @scDisruptionTarget.
  ///
  /// In ja, this message translates to:
  /// **'止まるもの'**
  String get scDisruptionTarget;

  /// No description provided for @scDisruptionDays.
  ///
  /// In ja, this message translates to:
  /// **'日数'**
  String get scDisruptionDays;

  /// No description provided for @scDisruptionKind.
  ///
  /// In ja, this message translates to:
  /// **'障害の種類'**
  String get scDisruptionKind;

  /// No description provided for @scStop.
  ///
  /// In ja, this message translates to:
  /// **'停止'**
  String get scStop;

  /// No description provided for @scDelay.
  ///
  /// In ja, this message translates to:
  /// **'遅延'**
  String get scDelay;

  /// No description provided for @scRunDisruption.
  ///
  /// In ja, this message translates to:
  /// **'影響を計算'**
  String get scRunDisruption;

  /// No description provided for @scImpact.
  ///
  /// In ja, this message translates to:
  /// **'利益への影響'**
  String get scImpact;

  /// No description provided for @scExtraCost.
  ///
  /// In ja, this message translates to:
  /// **'追加費用'**
  String get scExtraCost;

  /// No description provided for @scLostProfit.
  ///
  /// In ja, this message translates to:
  /// **'販売機会損失'**
  String get scLostProfit;

  /// No description provided for @scLostUnits.
  ///
  /// In ja, this message translates to:
  /// **'欠品数'**
  String get scLostUnits;

  /// No description provided for @scRerouted.
  ///
  /// In ja, this message translates to:
  /// **'代替輸送'**
  String get scRerouted;

  /// No description provided for @scCoverage.
  ///
  /// In ja, this message translates to:
  /// **'在庫で{days}日分'**
  String scCoverage(String days);

  /// No description provided for @scNoAlternativeRoute.
  ///
  /// In ja, this message translates to:
  /// **'代替ルートなし'**
  String get scNoAlternativeRoute;

  /// No description provided for @scAlternativeVia.
  ///
  /// In ja, this message translates to:
  /// **'代替: {name}'**
  String scAlternativeVia(String name);

  /// No description provided for @scNoLoads.
  ///
  /// In ja, this message translates to:
  /// **'まだ物の流れがありません。ルートと数量を登録してください。'**
  String get scNoLoads;

  /// No description provided for @scSavedScenarios.
  ///
  /// In ja, this message translates to:
  /// **'保存したシナリオ'**
  String get scSavedScenarios;

  /// No description provided for @scRunHistory.
  ///
  /// In ja, this message translates to:
  /// **'実行履歴'**
  String get scRunHistory;

  /// No description provided for @scRunAgain.
  ///
  /// In ja, this message translates to:
  /// **'もう一度実行'**
  String get scRunAgain;

  /// No description provided for @scNoScenarios.
  ///
  /// In ja, this message translates to:
  /// **'保存したシナリオはありません'**
  String get scNoScenarios;

  /// No description provided for @scNoRuns.
  ///
  /// In ja, this message translates to:
  /// **'実行履歴はありません'**
  String get scNoRuns;

  /// No description provided for @scRunKindBaseline.
  ///
  /// In ja, this message translates to:
  /// **'現在'**
  String get scRunKindBaseline;

  /// No description provided for @scRunKindScenario.
  ///
  /// In ja, this message translates to:
  /// **'シナリオ'**
  String get scRunKindScenario;

  /// No description provided for @scRunKindCompare.
  ///
  /// In ja, this message translates to:
  /// **'比較'**
  String get scRunKindCompare;

  /// No description provided for @scRunKindDisruption.
  ///
  /// In ja, this message translates to:
  /// **'障害'**
  String get scRunKindDisruption;

  /// No description provided for @scRunKindProduct.
  ///
  /// In ja, this message translates to:
  /// **'商品'**
  String get scRunKindProduct;

  /// No description provided for @scRunKindPurchaseCheck.
  ///
  /// In ja, this message translates to:
  /// **'発注前チェック'**
  String get scRunKindPurchaseCheck;

  /// No description provided for @scProductCard.
  ///
  /// In ja, this message translates to:
  /// **'原価・利益'**
  String get scProductCard;

  /// No description provided for @scOpenComparison.
  ///
  /// In ja, this message translates to:
  /// **'仕入先を比較'**
  String get scOpenComparison;

  /// No description provided for @scNoTerms.
  ///
  /// In ja, this message translates to:
  /// **'この商品の仕入条件がまだありません'**
  String get scNoTerms;

  /// No description provided for @scProfitWarning.
  ///
  /// In ja, this message translates to:
  /// **'利益の警告'**
  String get scProfitWarning;

  /// No description provided for @scProfitWarningBody.
  ///
  /// In ja, this message translates to:
  /// **'今回の条件では利益率が {before} → {after} に変わります。'**
  String scProfitWarningBody(String before, String after);

  /// No description provided for @scWarnMarginLow.
  ///
  /// In ja, this message translates to:
  /// **'利益率が基準を下回ります'**
  String get scWarnMarginLow;

  /// No description provided for @scWarnMarginDrop.
  ///
  /// In ja, this message translates to:
  /// **'利益率が大きく下がります'**
  String get scWarnMarginDrop;

  /// No description provided for @scWarnLoss.
  ///
  /// In ja, this message translates to:
  /// **'赤字です'**
  String get scWarnLoss;

  /// No description provided for @scCauses.
  ///
  /// In ja, this message translates to:
  /// **'原因'**
  String get scCauses;

  /// No description provided for @scContinueOrder.
  ///
  /// In ja, this message translates to:
  /// **'発注を続ける'**
  String get scContinueOrder;

  /// No description provided for @scBackToEdit.
  ///
  /// In ja, this message translates to:
  /// **'戻る'**
  String get scBackToEdit;

  /// No description provided for @scNoteNoRoute.
  ///
  /// In ja, this message translates to:
  /// **'ルート未登録（物流費なし）'**
  String get scNoteNoRoute;

  /// No description provided for @scNoteNoWeight.
  ///
  /// In ja, this message translates to:
  /// **'重量未設定'**
  String get scNoteNoWeight;

  /// No description provided for @scNoteNoVolume.
  ///
  /// In ja, this message translates to:
  /// **'数量なし（1個で計算）'**
  String get scNoteNoVolume;

  /// No description provided for @scNoteNoPrice.
  ///
  /// In ja, this message translates to:
  /// **'仕入価格なし'**
  String get scNoteNoPrice;

  /// No description provided for @scNoteNoFx.
  ///
  /// In ja, this message translates to:
  /// **'為替レートなし'**
  String get scNoteNoFx;

  /// No description provided for @scNoteNoTariff.
  ///
  /// In ja, this message translates to:
  /// **'関税ルールなし'**
  String get scNoteNoTariff;

  /// No description provided for @scNoteFixed.
  ///
  /// In ja, this message translates to:
  /// **'固定費を配賦できません'**
  String get scNoteFixed;

  /// No description provided for @scHypothetical.
  ///
  /// In ja, this message translates to:
  /// **'試算用'**
  String get scHypothetical;

  /// No description provided for @scManageOnly.
  ///
  /// In ja, this message translates to:
  /// **'編集には supply_chain.manage 権限が必要です'**
  String get scManageOnly;

  /// No description provided for @scRecalculate.
  ///
  /// In ja, this message translates to:
  /// **'再計算'**
  String get scRecalculate;

  /// No description provided for @scBlocked.
  ///
  /// In ja, this message translates to:
  /// **'使用不可'**
  String get scBlocked;

  /// No description provided for @scErrorRouteLegs.
  ///
  /// In ja, this message translates to:
  /// **'区間がつながっていません（次の区間は前の到着地から出発してください）'**
  String get scErrorRouteLegs;

  /// No description provided for @scErrorNameRequired.
  ///
  /// In ja, this message translates to:
  /// **'名称を入力してください'**
  String get scErrorNameRequired;

  /// No description provided for @scNoChange.
  ///
  /// In ja, this message translates to:
  /// **'変化はありません'**
  String get scNoChange;

  /// No description provided for @aiFieldProduct.
  ///
  /// In ja, this message translates to:
  /// **'自社商品'**
  String get aiFieldProduct;

  /// No description provided for @aiBandAuto.
  ///
  /// In ja, this message translates to:
  /// **'自動候補'**
  String get aiBandAuto;

  /// No description provided for @aiBandReview.
  ///
  /// In ja, this message translates to:
  /// **'確認推奨'**
  String get aiBandReview;

  /// No description provided for @aiBandHuman.
  ///
  /// In ja, this message translates to:
  /// **'要確認'**
  String get aiBandHuman;

  /// No description provided for @aiSaved.
  ///
  /// In ja, this message translates to:
  /// **'しきい値を保存しました'**
  String get aiSaved;

  /// No description provided for @featAiSettings.
  ///
  /// In ja, this message translates to:
  /// **'AI設定'**
  String get featAiSettings;

  /// No description provided for @featAiSettingsDesc.
  ///
  /// In ja, this message translates to:
  /// **'読み取りの確信度のしきい値'**
  String get featAiSettingsDesc;

  /// No description provided for @aiSettingsIntro.
  ///
  /// In ja, this message translates to:
  /// **'書類の読み取りは項目ごとに確信度を持ちます（AIの2回の読みの一致、JANのチェック数字、品名と品番の分け方、数量×単価＝金額などから計算）。確信度がどの帯に入るかで、自動候補・確認推奨・要確認に分かれます。'**
  String get aiSettingsIntro;

  /// No description provided for @aiAutoThreshold.
  ///
  /// In ja, this message translates to:
  /// **'自動候補の下限'**
  String get aiAutoThreshold;

  /// No description provided for @aiReviewThreshold.
  ///
  /// In ja, this message translates to:
  /// **'確認推奨の下限（これ未満は要確認）'**
  String get aiReviewThreshold;

  /// No description provided for @aiExample.
  ///
  /// In ja, this message translates to:
  /// **'例'**
  String get aiExample;

  /// No description provided for @featDocExceptions.
  ///
  /// In ja, this message translates to:
  /// **'書類の差異'**
  String get featDocExceptions;

  /// No description provided for @featDocExceptionsDesc.
  ///
  /// In ja, this message translates to:
  /// **'発注・請求書・納品・検品の食い違い'**
  String get featDocExceptionsDesc;

  /// No description provided for @docFlagNotOrdered.
  ///
  /// In ja, this message translates to:
  /// **'発注にない商品'**
  String get docFlagNotOrdered;

  /// No description provided for @docFlagNotInvoiced.
  ///
  /// In ja, this message translates to:
  /// **'請求書にない'**
  String get docFlagNotInvoiced;

  /// No description provided for @docFlagInvoiceQty.
  ///
  /// In ja, this message translates to:
  /// **'請求数量が発注と違う'**
  String get docFlagInvoiceQty;

  /// No description provided for @docFlagInvoicePrice.
  ///
  /// In ja, this message translates to:
  /// **'請求単価が発注と違う'**
  String get docFlagInvoicePrice;

  /// No description provided for @docFlagShortDelivery.
  ///
  /// In ja, this message translates to:
  /// **'請求より受領が少ない'**
  String get docFlagShortDelivery;

  /// No description provided for @docFlagInspectShort.
  ///
  /// In ja, this message translates to:
  /// **'検品数が受領より少ない'**
  String get docFlagInspectShort;

  /// No description provided for @docFlagDefective.
  ///
  /// In ja, this message translates to:
  /// **'不良あり'**
  String get docFlagDefective;

  /// No description provided for @docInvoiceOpen.
  ///
  /// In ja, this message translates to:
  /// **'未照合'**
  String get docInvoiceOpen;

  /// No description provided for @docInvoiceMatched.
  ///
  /// In ja, this message translates to:
  /// **'一致'**
  String get docInvoiceMatched;

  /// No description provided for @docInvoiceMismatch.
  ///
  /// In ja, this message translates to:
  /// **'差異あり'**
  String get docInvoiceMismatch;

  /// No description provided for @docInvoiceApproved.
  ///
  /// In ja, this message translates to:
  /// **'承認済み'**
  String get docInvoiceApproved;

  /// No description provided for @docInvoiceVoid.
  ///
  /// In ja, this message translates to:
  /// **'無効'**
  String get docInvoiceVoid;

  /// No description provided for @docMatchOk.
  ///
  /// In ja, this message translates to:
  /// **'照合OK'**
  String get docMatchOk;

  /// No description provided for @docMatchMismatch.
  ///
  /// In ja, this message translates to:
  /// **'差異あり'**
  String get docMatchMismatch;

  /// No description provided for @docMatchPending.
  ///
  /// In ja, this message translates to:
  /// **'請求書待ち'**
  String get docMatchPending;

  /// No description provided for @docMatchTitle.
  ///
  /// In ja, this message translates to:
  /// **'書類照合'**
  String get docMatchTitle;

  /// No description provided for @docAddInvoice.
  ///
  /// In ja, this message translates to:
  /// **'請求書を登録'**
  String get docAddInvoice;

  /// No description provided for @docTolerance.
  ///
  /// In ja, this message translates to:
  /// **'許容差'**
  String get docTolerance;

  /// No description provided for @docToleranceQty.
  ///
  /// In ja, this message translates to:
  /// **'数量'**
  String get docToleranceQty;

  /// No description provided for @docTolerancePrice.
  ///
  /// In ja, this message translates to:
  /// **'単価'**
  String get docTolerancePrice;

  /// No description provided for @docOrder.
  ///
  /// In ja, this message translates to:
  /// **'発注'**
  String get docOrder;

  /// No description provided for @docInvoice.
  ///
  /// In ja, this message translates to:
  /// **'請求書'**
  String get docInvoice;

  /// No description provided for @docDelivery.
  ///
  /// In ja, this message translates to:
  /// **'納品'**
  String get docDelivery;

  /// No description provided for @docReceived.
  ///
  /// In ja, this message translates to:
  /// **'受領'**
  String get docReceived;

  /// No description provided for @docInspection.
  ///
  /// In ja, this message translates to:
  /// **'検品'**
  String get docInspection;

  /// No description provided for @docOrderAmount.
  ///
  /// In ja, this message translates to:
  /// **'発注額'**
  String get docOrderAmount;

  /// No description provided for @docInvoiceAmount.
  ///
  /// In ja, this message translates to:
  /// **'請求額'**
  String get docInvoiceAmount;

  /// No description provided for @docDifference.
  ///
  /// In ja, this message translates to:
  /// **'差額'**
  String get docDifference;

  /// No description provided for @docFailedShort.
  ///
  /// In ja, this message translates to:
  /// **'不良{n}'**
  String docFailedShort(String n);

  /// No description provided for @docUnitPrice.
  ///
  /// In ja, this message translates to:
  /// **'単価'**
  String get docUnitPrice;

  /// No description provided for @docApproved.
  ///
  /// In ja, this message translates to:
  /// **'承認しました（仕入条件{n}件を更新）'**
  String docApproved(int n);

  /// No description provided for @docInvoices.
  ///
  /// In ja, this message translates to:
  /// **'請求書'**
  String get docInvoices;

  /// No description provided for @docNoInvoices.
  ///
  /// In ja, this message translates to:
  /// **'請求書はまだありません'**
  String get docNoInvoices;

  /// No description provided for @docLinesSuffix.
  ///
  /// In ja, this message translates to:
  /// **'行'**
  String get docLinesSuffix;

  /// No description provided for @docReadFromDocument.
  ///
  /// In ja, this message translates to:
  /// **'書類から読取'**
  String get docReadFromDocument;

  /// No description provided for @docApprove.
  ///
  /// In ja, this message translates to:
  /// **'承認'**
  String get docApprove;

  /// No description provided for @docVoid.
  ///
  /// In ja, this message translates to:
  /// **'無効にする'**
  String get docVoid;

  /// No description provided for @docInvoiceNumberRequired.
  ///
  /// In ja, this message translates to:
  /// **'請求書番号を入力してください'**
  String get docInvoiceNumberRequired;

  /// No description provided for @docSaved.
  ///
  /// In ja, this message translates to:
  /// **'保存しました'**
  String get docSaved;

  /// No description provided for @docReadFromFile.
  ///
  /// In ja, this message translates to:
  /// **'請求書（PDF・写真・Excel）から読み取る'**
  String get docReadFromFile;

  /// No description provided for @docInvoiceNumber.
  ///
  /// In ja, this message translates to:
  /// **'請求書番号'**
  String get docInvoiceNumber;

  /// No description provided for @docInvoiceDate.
  ///
  /// In ja, this message translates to:
  /// **'請求日'**
  String get docInvoiceDate;

  /// No description provided for @docInvoiceTotal.
  ///
  /// In ja, this message translates to:
  /// **'請求合計'**
  String get docInvoiceTotal;

  /// No description provided for @docLines.
  ///
  /// In ja, this message translates to:
  /// **'明細'**
  String get docLines;

  /// No description provided for @docAddLine.
  ///
  /// In ja, this message translates to:
  /// **'明細を追加'**
  String get docAddLine;

  /// No description provided for @docSaveAndMatch.
  ///
  /// In ja, this message translates to:
  /// **'保存して照合'**
  String get docSaveAndMatch;

  /// No description provided for @docExceptionsTitle.
  ///
  /// In ja, this message translates to:
  /// **'書類の差異'**
  String get docExceptionsTitle;

  /// No description provided for @docNoExceptions.
  ///
  /// In ja, this message translates to:
  /// **'差異はありません'**
  String get docNoExceptions;

  /// No description provided for @docExceptionCount.
  ///
  /// In ja, this message translates to:
  /// **'要確認 {count}件'**
  String docExceptionCount(int count);

  /// No description provided for @docDeltaQty.
  ///
  /// In ja, this message translates to:
  /// **'数量 {n}'**
  String docDeltaQty(String n);

  /// No description provided for @docDeltaPrice.
  ///
  /// In ja, this message translates to:
  /// **'単価 {n}'**
  String docDeltaPrice(String n);

  /// No description provided for @poDocumentMatch.
  ///
  /// In ja, this message translates to:
  /// **'書類照合'**
  String get poDocumentMatch;

  /// No description provided for @ntTabVersions.
  ///
  /// In ja, this message translates to:
  /// **'バージョン'**
  String get ntTabVersions;

  /// No description provided for @ntSnapshot.
  ///
  /// In ja, this message translates to:
  /// **'今の状態を保存'**
  String get ntSnapshot;

  /// No description provided for @ntSnapshotNote.
  ///
  /// In ja, this message translates to:
  /// **'メモ（例: 新書式対応）'**
  String get ntSnapshotNote;

  /// No description provided for @ntRestored.
  ///
  /// In ja, this message translates to:
  /// **'v{version}を戻しました（方言{dialects}件・見出し{aliases}件、衝突{conflicts}件）'**
  String ntRestored(int version, int dialects, int aliases, int conflicts);

  /// No description provided for @ntVersionTraining.
  ///
  /// In ja, this message translates to:
  /// **'事前学習'**
  String get ntVersionTraining;

  /// No description provided for @ntVersionRestore.
  ///
  /// In ja, this message translates to:
  /// **'復元'**
  String get ntVersionRestore;

  /// No description provided for @ntVersionManual.
  ///
  /// In ja, this message translates to:
  /// **'手動保存'**
  String get ntVersionManual;

  /// No description provided for @ntVersionsIntro.
  ///
  /// In ja, this message translates to:
  /// **'商社ごとの辞書（方言と列見出し）を番号付きで残します。学習するたびに自動で保存され、上書きはされません。古いバージョンを戻すと、今の辞書に足りない分だけを追加します（今と違う意味の書き方は上書きせず衝突として報告）。'**
  String get ntVersionsIntro;

  /// No description provided for @ntNoVersions.
  ///
  /// In ja, this message translates to:
  /// **'まだバージョンはありません'**
  String get ntNoVersions;

  /// No description provided for @ntVersionCounts.
  ///
  /// In ja, this message translates to:
  /// **'方言{dialects}・見出し{aliases}'**
  String ntVersionCounts(int dialects, int aliases);

  /// No description provided for @ntVersionCurrent.
  ///
  /// In ja, this message translates to:
  /// **'現在'**
  String get ntVersionCurrent;

  /// No description provided for @ntRestore.
  ///
  /// In ja, this message translates to:
  /// **'戻す'**
  String get ntRestore;

  /// No description provided for @syncSent.
  ///
  /// In ja, this message translates to:
  /// **'{count}件を送信しました'**
  String syncSent(int count);

  /// No description provided for @syncOffline.
  ///
  /// In ja, this message translates to:
  /// **'オフライン — 記録は端末に保存し、通信が戻ったら送ります（未送信 {count}件）'**
  String syncOffline(int count);

  /// No description provided for @syncPending.
  ///
  /// In ja, this message translates to:
  /// **'未送信の記録 {count}件'**
  String syncPending(int count);

  /// No description provided for @syncNow.
  ///
  /// In ja, this message translates to:
  /// **'今すぐ送信'**
  String get syncNow;

  /// No description provided for @syncRefused.
  ///
  /// In ja, this message translates to:
  /// **'送信できなかった記録: {reason}'**
  String syncRefused(String reason);

  /// No description provided for @syncDismiss.
  ///
  /// In ja, this message translates to:
  /// **'閉じる'**
  String get syncDismiss;

  /// No description provided for @errorOffline.
  ///
  /// In ja, this message translates to:
  /// **'通信できません。確定は通信が戻ってから行ってください（数え・検品の記録は端末に保存されます）。'**
  String get errorOffline;

  /// No description provided for @featProductLibrary.
  ///
  /// In ja, this message translates to:
  /// **'商品の写真'**
  String get featProductLibrary;

  /// No description provided for @featProductLibraryDesc.
  ///
  /// In ja, this message translates to:
  /// **'商品ごとの写真。先頭の写真が商品名の前に表示されます'**
  String get featProductLibraryDesc;

  /// No description provided for @plSearchHint.
  ///
  /// In ja, this message translates to:
  /// **'商品名・JAN・品番・メーカーで検索'**
  String get plSearchHint;

  /// No description provided for @plWithoutImages.
  ///
  /// In ja, this message translates to:
  /// **'写真なしのみ'**
  String get plWithoutImages;

  /// No description provided for @plNoProducts.
  ///
  /// In ja, this message translates to:
  /// **'該当する商品がありません'**
  String get plNoProducts;

  /// No description provided for @plImageCount.
  ///
  /// In ja, this message translates to:
  /// **'写真{count}枚'**
  String plImageCount(int count);

  /// No description provided for @plNoImages.
  ///
  /// In ja, this message translates to:
  /// **'写真がまだありません'**
  String get plNoImages;

  /// No description provided for @plAddPhoto.
  ///
  /// In ja, this message translates to:
  /// **'写真を追加'**
  String get plAddPhoto;

  /// No description provided for @plFromCamera.
  ///
  /// In ja, this message translates to:
  /// **'カメラで撮る'**
  String get plFromCamera;

  /// No description provided for @plFromGallery.
  ///
  /// In ja, this message translates to:
  /// **'写真を選ぶ'**
  String get plFromGallery;

  /// No description provided for @plPutFirst.
  ///
  /// In ja, this message translates to:
  /// **'先頭に置く（商品名の前に表示）'**
  String get plPutFirst;

  /// No description provided for @plFace.
  ///
  /// In ja, this message translates to:
  /// **'表紙'**
  String get plFace;

  /// No description provided for @plMakeFace.
  ///
  /// In ja, this message translates to:
  /// **'先頭にする'**
  String get plMakeFace;

  /// No description provided for @plWithdraw.
  ///
  /// In ja, this message translates to:
  /// **'取り下げ'**
  String get plWithdraw;

  /// No description provided for @plWithdrawConfirm.
  ///
  /// In ja, this message translates to:
  /// **'この写真を取り下げますか？（記録は残ります）'**
  String get plWithdrawConfirm;

  /// No description provided for @plUploaded.
  ///
  /// In ja, this message translates to:
  /// **'写真を追加しました'**
  String get plUploaded;

  /// No description provided for @plReorderHint.
  ///
  /// In ja, this message translates to:
  /// **'ドラッグで並べ替えできます。先頭の写真（表紙）が、入荷・検品・棚入れ・ピッキング・出荷・発注などの画面で商品名の前に表示されます。'**
  String get plReorderHint;

  /// No description provided for @plFaceHint.
  ///
  /// In ja, this message translates to:
  /// **'先頭の写真（表紙）が、各画面で商品名の前に表示されます。'**
  String get plFaceHint;

  /// No description provided for @plGalleryTitle.
  ///
  /// In ja, this message translates to:
  /// **'商品の写真'**
  String get plGalleryTitle;

  /// No description provided for @plOpenLibrary.
  ///
  /// In ja, this message translates to:
  /// **'商品の写真'**
  String get plOpenLibrary;

  /// No description provided for @plTabPhotos.
  ///
  /// In ja, this message translates to:
  /// **'写真'**
  String get plTabPhotos;

  /// No description provided for @plTabAttributes.
  ///
  /// In ja, this message translates to:
  /// **'属性'**
  String get plTabAttributes;

  /// No description provided for @plTabSuppliers.
  ///
  /// In ja, this message translates to:
  /// **'仕入先の呼び名'**
  String get plTabSuppliers;

  /// No description provided for @plAttributesHint.
  ///
  /// In ja, this message translates to:
  /// **'自社の値です。仕入先ごとの書き方（例: カラー「BK」）は「仕入先の呼び名」に並び、読み取りのときに自社の値（色「黒」）に置き換えられます。'**
  String get plAttributesHint;

  /// No description provided for @plAttrNew.
  ///
  /// In ja, this message translates to:
  /// **'属性を追加'**
  String get plAttrNew;

  /// No description provided for @plAttrName.
  ///
  /// In ja, this message translates to:
  /// **'属性名'**
  String get plAttrName;

  /// No description provided for @plAttrUnit.
  ///
  /// In ja, this message translates to:
  /// **'単位（任意）'**
  String get plAttrUnit;

  /// No description provided for @plAttrValue.
  ///
  /// In ja, this message translates to:
  /// **'値'**
  String get plAttrValue;

  /// No description provided for @plAttrHeading.
  ///
  /// In ja, this message translates to:
  /// **'見出し（例: カラー）'**
  String get plAttrHeading;

  /// No description provided for @plSuppliersHint.
  ///
  /// In ja, this message translates to:
  /// **'仕入先ごとの呼び名・品番・JAN・メーカーと属性の書き方。事前学習・取込・検品で確認したものが自動でたまります。'**
  String get plSuppliersHint;

  /// No description provided for @plNoSuppliers.
  ///
  /// In ja, this message translates to:
  /// **'まだ仕入先の呼び名はありません'**
  String get plNoSuppliers;

  /// No description provided for @plSupplierAdd.
  ///
  /// In ja, this message translates to:
  /// **'仕入先の呼び名を追加'**
  String get plSupplierAdd;

  /// No description provided for @plSupplier.
  ///
  /// In ja, this message translates to:
  /// **'仕入先'**
  String get plSupplier;

  /// No description provided for @plSupplierSaved.
  ///
  /// In ja, this message translates to:
  /// **'保存しました'**
  String get plSupplierSaved;

  /// No description provided for @plWritings.
  ///
  /// In ja, this message translates to:
  /// **'これまでの書き方'**
  String get plWritings;

  /// No description provided for @plAdopt.
  ///
  /// In ja, this message translates to:
  /// **'自社の値にする'**
  String get plAdopt;

  /// No description provided for @plRemoveSupplierConfirm.
  ///
  /// In ja, this message translates to:
  /// **'{name} の呼び名と属性を外しますか？（読み取り用の辞書は残ります）'**
  String plRemoveSupplierConfirm(String name);

  /// No description provided for @ntFieldAttr.
  ///
  /// In ja, this message translates to:
  /// **'属性'**
  String get ntFieldAttr;

  /// No description provided for @ntAttr.
  ///
  /// In ja, this message translates to:
  /// **'属性: {name}'**
  String ntAttr(String name);

  /// No description provided for @ntLearnedLibrary.
  ///
  /// In ja, this message translates to:
  /// **'学習済み：仕入先の呼び名{profiles}件・属性{attributes}件'**
  String ntLearnedLibrary(int profiles, int attributes);

  /// No description provided for @featNameFormats.
  ///
  /// In ja, this message translates to:
  /// **'商品様式'**
  String get featNameFormats;

  /// No description provided for @featNameFormatsDesc.
  ///
  /// In ja, this message translates to:
  /// **'商品名の組み立て方（様式）と、メーカー名・色などの呼び方を一括で変更'**
  String get featNameFormatsDesc;

  /// No description provided for @nfTitle.
  ///
  /// In ja, this message translates to:
  /// **'商品様式'**
  String get nfTitle;

  /// No description provided for @nfTabFormats.
  ///
  /// In ja, this message translates to:
  /// **'様式'**
  String get nfTabFormats;

  /// No description provided for @nfTabMakers.
  ///
  /// In ja, this message translates to:
  /// **'メーカー'**
  String get nfTabMakers;

  /// No description provided for @nfTabValues.
  ///
  /// In ja, this message translates to:
  /// **'属性の値'**
  String get nfTabValues;

  /// No description provided for @nfIntro.
  ///
  /// In ja, this message translates to:
  /// **'商品名は「基本名」とメーカー・品番・サイズ・色などの部品から、選んだ様式で組み立てられます。様式を変えると、その様式を使う商品名がすべて作り直されます。手入力の商品名はそのまま残ります。'**
  String get nfIntro;

  /// No description provided for @nfDefault.
  ///
  /// In ja, this message translates to:
  /// **'既定'**
  String get nfDefault;

  /// No description provided for @nfProducts.
  ///
  /// In ja, this message translates to:
  /// **'{count}件の商品'**
  String nfProducts(int count);

  /// No description provided for @nfNew.
  ///
  /// In ja, this message translates to:
  /// **'様式を追加'**
  String get nfNew;

  /// No description provided for @nfEdit.
  ///
  /// In ja, this message translates to:
  /// **'様式の編集'**
  String get nfEdit;

  /// No description provided for @nfName.
  ///
  /// In ja, this message translates to:
  /// **'様式の名前'**
  String get nfName;

  /// No description provided for @nfTemplate.
  ///
  /// In ja, this message translates to:
  /// **'組み立て方'**
  String get nfTemplate;

  /// No description provided for @nfTemplateHint.
  ///
  /// In ja, this message translates to:
  /// **'「基本名」は必ず入れてください'**
  String get nfTemplateHint;

  /// No description provided for @nfInsert.
  ///
  /// In ja, this message translates to:
  /// **'差し込む項目（タップで追加）'**
  String get nfInsert;

  /// No description provided for @nfPartBase.
  ///
  /// In ja, this message translates to:
  /// **'基本名'**
  String get nfPartBase;

  /// No description provided for @nfPartMaker.
  ///
  /// In ja, this message translates to:
  /// **'メーカー'**
  String get nfPartMaker;

  /// No description provided for @nfPartCode.
  ///
  /// In ja, this message translates to:
  /// **'品番'**
  String get nfPartCode;

  /// No description provided for @nfPartJan.
  ///
  /// In ja, this message translates to:
  /// **'JAN'**
  String get nfPartJan;

  /// No description provided for @nfPartUnit.
  ///
  /// In ja, this message translates to:
  /// **'単位'**
  String get nfPartUnit;

  /// No description provided for @nfSample.
  ///
  /// In ja, this message translates to:
  /// **'例'**
  String get nfSample;

  /// No description provided for @nfSampleBase.
  ///
  /// In ja, this message translates to:
  /// **'ボールペン'**
  String get nfSampleBase;

  /// No description provided for @nfSampleMaker.
  ///
  /// In ja, this message translates to:
  /// **'サンプル文具'**
  String get nfSampleMaker;

  /// No description provided for @nfSampleUnit.
  ///
  /// In ja, this message translates to:
  /// **'本'**
  String get nfSampleUnit;

  /// No description provided for @nfSampleColor.
  ///
  /// In ja, this message translates to:
  /// **'赤'**
  String get nfSampleColor;

  /// No description provided for @nfMakeDefault.
  ///
  /// In ja, this message translates to:
  /// **'新しい商品の既定の様式にする'**
  String get nfMakeDefault;

  /// No description provided for @nfPreview.
  ///
  /// In ja, this message translates to:
  /// **'実際の商品名の変わり方'**
  String get nfPreview;

  /// No description provided for @nfPreviewRefresh.
  ///
  /// In ja, this message translates to:
  /// **'確認'**
  String get nfPreviewRefresh;

  /// No description provided for @nfPreviewNone.
  ///
  /// In ja, this message translates to:
  /// **'この様式の商品はまだありません'**
  String get nfPreviewNone;

  /// No description provided for @nfNeedsBase.
  ///
  /// In ja, this message translates to:
  /// **'組み立て方に「基本名」を入れてください'**
  String get nfNeedsBase;

  /// No description provided for @nfNeedsName.
  ///
  /// In ja, this message translates to:
  /// **'様式の名前を入れてください'**
  String get nfNeedsName;

  /// No description provided for @nfSaved.
  ///
  /// In ja, this message translates to:
  /// **'保存しました。{count}件の商品名を作り直しました'**
  String nfSaved(int count);

  /// No description provided for @nfSearchMaker.
  ///
  /// In ja, this message translates to:
  /// **'メーカーを検索（別表記でも可）'**
  String get nfSearchMaker;

  /// No description provided for @nfMakersHint.
  ///
  /// In ja, this message translates to:
  /// **'メーカー名を変えると、そのメーカーの商品名もすべて変わります。旧名は今後も同じメーカーとして読み取ります。'**
  String get nfMakersHint;

  /// No description provided for @nfRename.
  ///
  /// In ja, this message translates to:
  /// **'メーカー名を変える'**
  String get nfRename;

  /// No description provided for @nfNewName.
  ///
  /// In ja, this message translates to:
  /// **'新しい名前'**
  String get nfNewName;

  /// No description provided for @nfDialects.
  ///
  /// In ja, this message translates to:
  /// **'別表記{count}件'**
  String nfDialects(int count);

  /// No description provided for @nfMakerRenamed.
  ///
  /// In ja, this message translates to:
  /// **'{count}件の商品に反映しました'**
  String nfMakerRenamed(int count);

  /// No description provided for @nfValuesHint.
  ///
  /// In ja, this message translates to:
  /// **'属性の値の呼び方を一括で変えます（例：色「赤」→「レッド」）。その値を持つ商品の名前と、仕入先の書き方の対応も変わります。旧い値は今後も新しい値として読み取ります。'**
  String get nfValuesHint;

  /// No description provided for @nfAttribute.
  ///
  /// In ja, this message translates to:
  /// **'属性'**
  String get nfAttribute;

  /// No description provided for @nfFrom.
  ///
  /// In ja, this message translates to:
  /// **'今の値'**
  String get nfFrom;

  /// No description provided for @nfTo.
  ///
  /// In ja, this message translates to:
  /// **'新しい値'**
  String get nfTo;

  /// No description provided for @nfRenameEverywhere.
  ///
  /// In ja, this message translates to:
  /// **'一括で変更'**
  String get nfRenameEverywhere;

  /// No description provided for @nfValueRenamed.
  ///
  /// In ja, this message translates to:
  /// **'{count}件の商品を変更しました'**
  String nfValueRenamed(int count);

  /// No description provided for @pnTitle.
  ///
  /// In ja, this message translates to:
  /// **'商品名の組み立て'**
  String get pnTitle;

  /// No description provided for @pnBaseName.
  ///
  /// In ja, this message translates to:
  /// **'基本名（サイズ・色を除いた名前）'**
  String get pnBaseName;

  /// No description provided for @pnUnit.
  ///
  /// In ja, this message translates to:
  /// **'単位'**
  String get pnUnit;

  /// No description provided for @pnListPrice.
  ///
  /// In ja, this message translates to:
  /// **'定価'**
  String get pnListPrice;

  /// No description provided for @pnFormat.
  ///
  /// In ja, this message translates to:
  /// **'様式'**
  String get pnFormat;

  /// No description provided for @pnFormatDefault.
  ///
  /// In ja, this message translates to:
  /// **'既定の様式（{name}）'**
  String pnFormatDefault(String name);

  /// No description provided for @pnManual.
  ///
  /// In ja, this message translates to:
  /// **'商品名を手入力する（様式を使わない）'**
  String get pnManual;

  /// No description provided for @pnName.
  ///
  /// In ja, this message translates to:
  /// **'商品名'**
  String get pnName;

  /// No description provided for @pnPreview.
  ///
  /// In ja, this message translates to:
  /// **'商品名'**
  String get pnPreview;

  /// No description provided for @pnLegacy.
  ///
  /// In ja, this message translates to:
  /// **'この商品はまだ部品に分かれていません。基本名を入れると様式で名前が作られます。'**
  String get pnLegacy;

  /// No description provided for @pnAttrsHint.
  ///
  /// In ja, this message translates to:
  /// **'サイズ・色などは商品の写真画面の「属性」タブで設定します'**
  String get pnAttrsHint;

  /// No description provided for @pnNeedsBase.
  ///
  /// In ja, this message translates to:
  /// **'基本名を入れてください'**
  String get pnNeedsBase;

  /// No description provided for @pnSaved.
  ///
  /// In ja, this message translates to:
  /// **'商品名を更新しました'**
  String get pnSaved;

  /// No description provided for @rpOpen.
  ///
  /// In ja, this message translates to:
  /// **'未登録の商品を自社様式で登録（{count}）'**
  String rpOpen(int count);

  /// No description provided for @rpTitle.
  ///
  /// In ja, this message translates to:
  /// **'自社様式で商品登録'**
  String get rpTitle;

  /// No description provided for @rpIntro.
  ///
  /// In ja, this message translates to:
  /// **'書類の行から、自社の様式に整えた商品案を作りました。確認・修正して登録してください。登録すると、この仕入先の書き方も一緒に学習します。'**
  String get rpIntro;

  /// No description provided for @rpNone.
  ///
  /// In ja, this message translates to:
  /// **'登録できる新しい商品はありません（JANの無い行と登録済みの商品は除きます）'**
  String get rpNone;

  /// No description provided for @rpFromCode.
  ///
  /// In ja, this message translates to:
  /// **'書類に商品名がありません。品番を仮の名前にしています'**
  String get rpFromCode;

  /// No description provided for @rpRegister.
  ///
  /// In ja, this message translates to:
  /// **'{count}件を登録'**
  String rpRegister(int count);

  /// No description provided for @rpRegistered.
  ///
  /// In ja, this message translates to:
  /// **'{count}件の商品を登録しました'**
  String rpRegistered(int count);

  /// No description provided for @rpNeedsMaker.
  ///
  /// In ja, this message translates to:
  /// **'選んだ商品にはメーカーと基本名が必要です'**
  String get rpNeedsMaker;

  /// No description provided for @ntFieldListPrice.
  ///
  /// In ja, this message translates to:
  /// **'定価'**
  String get ntFieldListPrice;

  /// No description provided for @ntFieldDiscountRate.
  ///
  /// In ja, this message translates to:
  /// **'掛率'**
  String get ntFieldDiscountRate;

  /// No description provided for @ntFieldUnit.
  ///
  /// In ja, this message translates to:
  /// **'単位'**
  String get ntFieldUnit;

  /// No description provided for @ntFieldSupplierCode.
  ///
  /// In ja, this message translates to:
  /// **'仕入先の商品コード'**
  String get ntFieldSupplierCode;

  /// No description provided for @ntMatchRegistered.
  ///
  /// In ja, this message translates to:
  /// **'自社様式で新規登録'**
  String get ntMatchRegistered;

  /// No description provided for @featFieldLibrary.
  ///
  /// In ja, this message translates to:
  /// **'項目ライブラリー'**
  String get featFieldLibrary;

  /// No description provided for @featFieldLibraryDesc.
  ///
  /// In ja, this message translates to:
  /// **'取引先ごとに違う見出し（JAN・JANコード・ジャパンコード…）をまとめ、システムで表示する名前を決める'**
  String get featFieldLibraryDesc;

  /// No description provided for @flTitle.
  ///
  /// In ja, this message translates to:
  /// **'項目ライブラリー'**
  String get flTitle;

  /// No description provided for @flIntro.
  ///
  /// In ja, this message translates to:
  /// **'書類の列の意味（JAN・メーカー・品番など）ごとに、各社がどんな見出しで書いてくるかをまとめています。見出しは取り込みや事前学習で自動的に増えます。鉛筆のボタンで、このシステムで表示する名前を言語ごとに決められます（空欄は標準の名前）。'**
  String get flIntro;

  /// No description provided for @flBuiltIn.
  ///
  /// In ja, this message translates to:
  /// **'標準の名前：{name}'**
  String flBuiltIn(String name);

  /// No description provided for @flEditNames.
  ///
  /// In ja, this message translates to:
  /// **'表示名を決める'**
  String get flEditNames;

  /// No description provided for @flNamesHint.
  ///
  /// In ja, this message translates to:
  /// **'空欄の言語は標準の名前「{name}」のままです。'**
  String flNamesHint(String name);

  /// No description provided for @flLangJa.
  ///
  /// In ja, this message translates to:
  /// **'日本語'**
  String get flLangJa;

  /// No description provided for @flLangEn.
  ///
  /// In ja, this message translates to:
  /// **'英語'**
  String get flLangEn;

  /// No description provided for @flLangZh.
  ///
  /// In ja, this message translates to:
  /// **'中国語'**
  String get flLangZh;

  /// No description provided for @flSaved.
  ///
  /// In ja, this message translates to:
  /// **'表示名を保存しました'**
  String get flSaved;

  /// No description provided for @flHeadings.
  ///
  /// In ja, this message translates to:
  /// **'各社の見出し {count}件'**
  String flHeadings(int count);

  /// No description provided for @flAddHeading.
  ///
  /// In ja, this message translates to:
  /// **'見出しを追加'**
  String get flAddHeading;

  /// No description provided for @flAddHeadingTo.
  ///
  /// In ja, this message translates to:
  /// **'「{name}」の見出しを追加'**
  String flAddHeadingTo(String name);

  /// No description provided for @flHeading.
  ///
  /// In ja, this message translates to:
  /// **'見出し（書類に書かれているとおり）'**
  String get flHeading;

  /// No description provided for @flEveryone.
  ///
  /// In ja, this message translates to:
  /// **'全社共通'**
  String get flEveryone;

  /// No description provided for @flOnlyFor.
  ///
  /// In ja, this message translates to:
  /// **'{name} だけ'**
  String flOnlyFor(String name);

  /// No description provided for @flHeadingAdded.
  ///
  /// In ja, this message translates to:
  /// **'「{header}」を追加しました'**
  String flHeadingAdded(String header);

  /// No description provided for @flAttributes.
  ///
  /// In ja, this message translates to:
  /// **'商品の属性'**
  String get flAttributes;

  /// No description provided for @flAttributesHint.
  ///
  /// In ja, this message translates to:
  /// **'色・サイズなどの属性の名前は、商品の写真画面の「属性」タブで変えられます。'**
  String get flAttributesHint;

  /// No description provided for @ntFieldUpstreamCode.
  ///
  /// In ja, this message translates to:
  /// **'取引先の仕入先コード'**
  String get ntFieldUpstreamCode;

  /// No description provided for @ntFieldCustomerCode.
  ///
  /// In ja, this message translates to:
  /// **'得意先コード（先方での当社コード）'**
  String get ntFieldCustomerCode;

  /// No description provided for @ntFlagJanExponent.
  ///
  /// In ja, this message translates to:
  /// **'JANが指数表記（4.90E+12など）で桁が失われています'**
  String get ntFlagJanExponent;

  /// No description provided for @pcRulesTitle.
  ///
  /// In ja, this message translates to:
  /// **'取引先コードの採番'**
  String get pcRulesTitle;

  /// No description provided for @pcRulesHint.
  ///
  /// In ja, this message translates to:
  /// **'新しい取引先にコードを入れなかったとき、この規則で自社のコードを振ります。あとから取引先ごとに変更できます。'**
  String get pcRulesHint;

  /// No description provided for @pcPrefix.
  ///
  /// In ja, this message translates to:
  /// **'頭文字'**
  String get pcPrefix;

  /// No description provided for @pcDigits.
  ///
  /// In ja, this message translates to:
  /// **'桁数'**
  String get pcDigits;

  /// No description provided for @pcNext.
  ///
  /// In ja, this message translates to:
  /// **'次の番号'**
  String get pcNext;

  /// No description provided for @pcNextCode.
  ///
  /// In ja, this message translates to:
  /// **'次に振るコード：{code}'**
  String pcNextCode(String code);

  /// No description provided for @pcRulesSaved.
  ///
  /// In ja, this message translates to:
  /// **'採番の規則を保存しました'**
  String get pcRulesSaved;

  /// No description provided for @pcIssueMissing.
  ///
  /// In ja, this message translates to:
  /// **'未採番の取引先に振る'**
  String get pcIssueMissing;

  /// No description provided for @pcIssued.
  ///
  /// In ja, this message translates to:
  /// **'{count}社にコードを振りました'**
  String pcIssued(int count);

  /// No description provided for @pcOurCode.
  ///
  /// In ja, this message translates to:
  /// **'自社の取引先コード'**
  String get pcOurCode;

  /// No description provided for @pcAutoHint.
  ///
  /// In ja, this message translates to:
  /// **'空欄なら採番の規則で自動的に振ります'**
  String get pcAutoHint;

  /// No description provided for @pcTheirCode.
  ///
  /// In ja, this message translates to:
  /// **'先方での当社コード（得意先コード）'**
  String get pcTheirCode;

  /// No description provided for @pcTheirCodeHint.
  ///
  /// In ja, this message translates to:
  /// **'相手の請求書・見積書にある当社の番号。書類から自動で入ることもあります'**
  String get pcTheirCodeHint;

  /// No description provided for @pcOurCodeShort.
  ///
  /// In ja, this message translates to:
  /// **'自社コード {code}'**
  String pcOurCodeShort(String code);

  /// No description provided for @pcTheirCodeShort.
  ///
  /// In ja, this message translates to:
  /// **'先方での当社 {code}'**
  String pcTheirCodeShort(String code);

  /// No description provided for @pcVendorCodesTitle.
  ///
  /// In ja, this message translates to:
  /// **'この取引先の仕入先コード'**
  String get pcVendorCodesTitle;

  /// No description provided for @pcVendorCodesHint.
  ///
  /// In ja, this message translates to:
  /// **'取引先が自分の仕入先（メーカー等）に付けている番号です。自社のコードではありません。'**
  String get pcVendorCodesHint;

  /// No description provided for @ntFlagJanDisplayExponent.
  ///
  /// In ja, this message translates to:
  /// **'JANの表示が指数表記（4.90E+12など）です。中身の13桁で読み取りました'**
  String get ntFlagJanDisplayExponent;

  /// No description provided for @ntFlagJanRestored.
  ///
  /// In ja, this message translates to:
  /// **'JANの桁が失われていたため、品番の商品から補いました（先頭の桁は一致）。確認してください'**
  String get ntFlagJanRestored;

  /// No description provided for @ntFlagJanRestoreMismatch.
  ///
  /// In ja, this message translates to:
  /// **'JANの桁が失われています。品番の商品とJANの先頭の桁が合わないため、補っていません'**
  String get ntFlagJanRestoreMismatch;

  /// No description provided for @ntFlagJanCodeMismatch.
  ///
  /// In ja, this message translates to:
  /// **'JANと品番が別の商品を指しています'**
  String get ntFlagJanCodeMismatch;

  /// No description provided for @ntAltCodeProduct.
  ///
  /// In ja, this message translates to:
  /// **'品番から引いた商品'**
  String get ntAltCodeProduct;

  /// No description provided for @ntMatchJanRestored.
  ///
  /// In ja, this message translates to:
  /// **'品番から補ったJAN'**
  String get ntMatchJanRestored;

  /// No description provided for @importJanWarnings.
  ///
  /// In ja, this message translates to:
  /// **'JANの確認が必要な行が{count}行あります（⚠をタップすると、警告が正しかったか報告できます）'**
  String importJanWarnings(int count);

  /// No description provided for @importJanDisplayExponent.
  ///
  /// In ja, this message translates to:
  /// **'{count}行のJANはファイル上で指数表記（4.90E+12など）で表示されていますが、中身の13桁で正しく読み取りました。CSVで保存し直すと桁が消えるので、Excel（.xlsx）のまま送ってもらってください'**
  String importJanDisplayExponent(int count);

  /// No description provided for @wrTitle.
  ///
  /// In ja, this message translates to:
  /// **'警告の確認'**
  String get wrTitle;

  /// No description provided for @wrQuestion.
  ///
  /// In ja, this message translates to:
  /// **'この警告は正しかったですか？ 答えは警告のルールの見直しに使います。'**
  String get wrQuestion;

  /// No description provided for @wrNote.
  ///
  /// In ja, this message translates to:
  /// **'メモ（任意）'**
  String get wrNote;

  /// No description provided for @wrNoteHint.
  ///
  /// In ja, this message translates to:
  /// **'例：ケース品と単品で同じ品番'**
  String get wrNoteHint;

  /// No description provided for @wrRight.
  ///
  /// In ja, this message translates to:
  /// **'正しかった'**
  String get wrRight;

  /// No description provided for @wrWrong.
  ///
  /// In ja, this message translates to:
  /// **'誤り（問題なかった）'**
  String get wrWrong;

  /// No description provided for @wrThanks.
  ///
  /// In ja, this message translates to:
  /// **'報告しました。警告の見直しに使います'**
  String get wrThanks;

  /// No description provided for @wrStatsTitle.
  ///
  /// In ja, this message translates to:
  /// **'警告の正確さ'**
  String get wrStatsTitle;

  /// No description provided for @wrStatsHint.
  ///
  /// In ja, this message translates to:
  /// **'確認した人が「正しかった／誤り」と報告した数です。誤りが多い警告はルールを見直します。'**
  String get wrStatsHint;

  /// No description provided for @wrStatsEmpty.
  ///
  /// In ja, this message translates to:
  /// **'まだ報告はありません。行の⚠をタップすると報告できます'**
  String get wrStatsEmpty;

  /// No description provided for @wrRightCount.
  ///
  /// In ja, this message translates to:
  /// **'正しい {count}'**
  String wrRightCount(int count);

  /// No description provided for @wrWrongCount.
  ///
  /// In ja, this message translates to:
  /// **'誤り {count}'**
  String wrWrongCount(int count);

  /// No description provided for @ntFieldMulti.
  ///
  /// In ja, this message translates to:
  /// **'複数項目（区切って読む）'**
  String get ntFieldMulti;

  /// No description provided for @ntFieldMultiPick.
  ///
  /// In ja, this message translates to:
  /// **'複数項目（区切って読む）…'**
  String get ntFieldMultiPick;

  /// No description provided for @ntMultiOf.
  ///
  /// In ja, this message translates to:
  /// **'複数：{parts}'**
  String ntMultiOf(String parts);

  /// No description provided for @ntPartSkip.
  ///
  /// In ja, this message translates to:
  /// **'読まない'**
  String get ntPartSkip;

  /// No description provided for @ntSepAuto.
  ///
  /// In ja, this message translates to:
  /// **'自動（／か / があればそれで、なければ空白）'**
  String get ntSepAuto;

  /// No description provided for @ntSepSpace.
  ///
  /// In ja, this message translates to:
  /// **'空白'**
  String get ntSepSpace;

  /// No description provided for @ntSepChar.
  ///
  /// In ja, this message translates to:
  /// **'「{sep}」'**
  String ntSepChar(String sep);

  /// No description provided for @ntSeparator.
  ///
  /// In ja, this message translates to:
  /// **'区切り'**
  String get ntSeparator;

  /// No description provided for @ntPartsTitle.
  ///
  /// In ja, this message translates to:
  /// **'「{header}」の分け方'**
  String ntPartsTitle(String header);

  /// No description provided for @ntPartsHint.
  ///
  /// In ja, this message translates to:
  /// **'この欄に入っている項目を、左から順にタップして並べてください。最後の項目には残りがすべて入ります（品番に空白があっても切れません）。'**
  String get ntPartsHint;

  /// No description provided for @ntPartsEmpty.
  ///
  /// In ja, this message translates to:
  /// **'まだ選んでいません'**
  String get ntPartsEmpty;

  /// No description provided for @ntPartsAdd.
  ///
  /// In ja, this message translates to:
  /// **'項目を追加'**
  String get ntPartsAdd;

  /// No description provided for @ntFlagTotalMismatch.
  ///
  /// In ja, this message translates to:
  /// **'明細の合計が書類の合計と合いません'**
  String get ntFlagTotalMismatch;

  /// No description provided for @ntReadPdfText.
  ///
  /// In ja, this message translates to:
  /// **'PDFの文字をそのまま読み取り'**
  String get ntReadPdfText;

  /// No description provided for @ntNotesTitle.
  ///
  /// In ja, this message translates to:
  /// **'書式メモ（AIへの指示）'**
  String get ntNotesTitle;

  /// No description provided for @ntNotesHint.
  ///
  /// In ja, this message translates to:
  /// **'この取引先の書類の読み方を書いておくと、PDFや写真を読むたびにAIに伝えます'**
  String get ntNotesHint;

  /// No description provided for @ntNotesExample.
  ///
  /// In ja, this message translates to:
  /// **'例：JANは「備考」欄にあります。品番の前の「9A」「8E」などの記号は読まない。'**
  String get ntNotesExample;

  /// No description provided for @ntNotesSaved.
  ///
  /// In ja, this message translates to:
  /// **'書式メモを保存しました'**
  String get ntNotesSaved;

  /// No description provided for @totalsOk.
  ///
  /// In ja, this message translates to:
  /// **'明細の合計 {sum} が書類の合計と一致しました'**
  String totalsOk(String sum);

  /// No description provided for @totalsMismatch.
  ///
  /// In ja, this message translates to:
  /// **'明細の合計 {sum} が書類の合計 {expected} と合いません。数量や単価を読み間違えた行がある可能性があります'**
  String totalsMismatch(String sum, String expected);

  /// No description provided for @totalsNotFound.
  ///
  /// In ja, this message translates to:
  /// **'明細の合計 {sum} が、書類のどの合計とも一致しませんでした'**
  String totalsNotFound(String sum);

  /// No description provided for @totalsReport.
  ///
  /// In ja, this message translates to:
  /// **'警告を報告'**
  String get totalsReport;

  /// No description provided for @wtSection.
  ///
  /// In ja, this message translates to:
  /// **'重量'**
  String get wtSection;

  /// No description provided for @wtAdd.
  ///
  /// In ja, this message translates to:
  /// **'重量を入力'**
  String get wtAdd;

  /// No description provided for @wtEdit.
  ///
  /// In ja, this message translates to:
  /// **'重量を変更'**
  String get wtEdit;

  /// No description provided for @wtNone.
  ///
  /// In ja, this message translates to:
  /// **'まだ重量が入っていません。出荷時の総重量には入りません'**
  String get wtNone;

  /// No description provided for @wtPerUnit.
  ///
  /// In ja, this message translates to:
  /// **'{weight} / 1{unit}'**
  String wtPerUnit(String weight, String unit);

  /// No description provided for @wtGramsLabel.
  ///
  /// In ja, this message translates to:
  /// **'{unit}あたりの重さ'**
  String wtGramsLabel(String unit);

  /// No description provided for @wtSourceManual.
  ///
  /// In ja, this message translates to:
  /// **'手入力'**
  String get wtSourceManual;

  /// No description provided for @wtSourceMeasured.
  ///
  /// In ja, this message translates to:
  /// **'実測'**
  String get wtSourceMeasured;

  /// No description provided for @wtSourceWeb.
  ///
  /// In ja, this message translates to:
  /// **'ネットで調べた値'**
  String get wtSourceWeb;

  /// No description provided for @wtUrl.
  ///
  /// In ja, this message translates to:
  /// **'調べたページ（任意）'**
  String get wtUrl;

  /// No description provided for @wtNote.
  ///
  /// In ja, this message translates to:
  /// **'メモ（任意）'**
  String get wtNote;

  /// No description provided for @wtClear.
  ///
  /// In ja, this message translates to:
  /// **'重量を消す'**
  String get wtClear;

  /// No description provided for @wtInvalid.
  ///
  /// In ja, this message translates to:
  /// **'重さは0以上の数字で入れてください'**
  String get wtInvalid;

  /// No description provided for @wtPackEdit.
  ///
  /// In ja, this message translates to:
  /// **'単位と重さを変更'**
  String get wtPackEdit;

  /// No description provided for @wtPackageLabel.
  ///
  /// In ja, this message translates to:
  /// **'箱・ケースそのものの重さ（任意）'**
  String get wtPackageLabel;

  /// No description provided for @wtPackageHint.
  ///
  /// In ja, this message translates to:
  /// **'中身の重さ（入数 × 1個の重さ）に足して計算します'**
  String get wtPackageHint;

  /// No description provided for @wtGrossLabel.
  ///
  /// In ja, this message translates to:
  /// **'1ケースを丸ごと量った重さ（任意）'**
  String get wtGrossLabel;

  /// No description provided for @wtGrossHint.
  ///
  /// In ja, this message translates to:
  /// **'入れると、計算よりこちらを優先します'**
  String get wtGrossHint;

  /// No description provided for @wtPackNoUnitWeight.
  ///
  /// In ja, this message translates to:
  /// **'この商品の1個あたりの重さがまだないため、丸ごとの重さを入れない限りケースの重さは計算できません'**
  String get wtPackNoUnitWeight;

  /// No description provided for @swSection.
  ///
  /// In ja, this message translates to:
  /// **'出荷重量の見込み'**
  String get swSection;

  /// No description provided for @swGoods.
  ///
  /// In ja, this message translates to:
  /// **'商品'**
  String get swGoods;

  /// No description provided for @swGoodsLine.
  ///
  /// In ja, this message translates to:
  /// **'商品だけで {weight}'**
  String swGoodsLine(String weight);

  /// No description provided for @swBoxes.
  ///
  /// In ja, this message translates to:
  /// **'ダンボール {count}箱'**
  String swBoxes(int count);

  /// No description provided for @swMaterial.
  ///
  /// In ja, this message translates to:
  /// **'梱包材'**
  String get swMaterial;

  /// No description provided for @swTotal.
  ///
  /// In ja, this message translates to:
  /// **'総重量（見込み）'**
  String get swTotal;

  /// No description provided for @swMeasured.
  ///
  /// In ja, this message translates to:
  /// **'実際に量った重さ'**
  String get swMeasured;

  /// No description provided for @swMissing.
  ///
  /// In ja, this message translates to:
  /// **'{count}件の商品に重量がなく、合計に入っていません'**
  String swMissing(int count);

  /// No description provided for @swNoPlan.
  ///
  /// In ja, this message translates to:
  /// **'ダンボールの数はまだ決めていません'**
  String get swNoPlan;

  /// No description provided for @swPlanned.
  ///
  /// In ja, this message translates to:
  /// **'予定しているダンボール'**
  String get swPlanned;

  /// No description provided for @swSuggest.
  ///
  /// In ja, this message translates to:
  /// **'重さからの目安: {list}'**
  String swSuggest(String list);

  /// No description provided for @swSuggestOne.
  ///
  /// In ja, this message translates to:
  /// **'重さからの目安 {count}箱'**
  String swSuggestOne(int count);

  /// No description provided for @swCarton.
  ///
  /// In ja, this message translates to:
  /// **'{no}箱目 {type}'**
  String swCarton(int no, String type);

  /// No description provided for @swNoType.
  ///
  /// In ja, this message translates to:
  /// **'（種類未設定）'**
  String get swNoType;

  /// No description provided for @swEmpty.
  ///
  /// In ja, this message translates to:
  /// **'箱 {weight}'**
  String swEmpty(String weight);

  /// No description provided for @swMaterialOf.
  ///
  /// In ja, this message translates to:
  /// **'梱包材 {weight}'**
  String swMaterialOf(String weight);

  /// No description provided for @swEstimate.
  ///
  /// In ja, this message translates to:
  /// **'見込み {weight}'**
  String swEstimate(String weight);

  /// No description provided for @swSetBox.
  ///
  /// In ja, this message translates to:
  /// **'ダンボールの種類と重さ'**
  String get swSetBox;

  /// No description provided for @swPlanAction.
  ///
  /// In ja, this message translates to:
  /// **'ダンボールの数を決める'**
  String get swPlanAction;

  /// No description provided for @swBoxType.
  ///
  /// In ja, this message translates to:
  /// **'ダンボールの種類'**
  String get swBoxType;

  /// No description provided for @ctTitle.
  ///
  /// In ja, this message translates to:
  /// **'ダンボールの種類'**
  String get ctTitle;

  /// No description provided for @ctAdd.
  ///
  /// In ja, this message translates to:
  /// **'ダンボールを追加'**
  String get ctAdd;

  /// No description provided for @ctEdit.
  ///
  /// In ja, this message translates to:
  /// **'ダンボールを変更'**
  String get ctEdit;

  /// No description provided for @ctHint.
  ///
  /// In ja, this message translates to:
  /// **'出荷に使うダンボールの大きさと重さです。総重量の見込みはここの値で計算します。使わなくなったものは「使う」を切ってください（過去の出荷が名前を参照しているため消しません）。'**
  String get ctHint;

  /// No description provided for @ctName.
  ///
  /// In ja, this message translates to:
  /// **'名前（例：100サイズ）'**
  String get ctName;

  /// No description provided for @ctLength.
  ///
  /// In ja, this message translates to:
  /// **'縦'**
  String get ctLength;

  /// No description provided for @ctWidth.
  ///
  /// In ja, this message translates to:
  /// **'横'**
  String get ctWidth;

  /// No description provided for @ctHeight.
  ///
  /// In ja, this message translates to:
  /// **'高さ'**
  String get ctHeight;

  /// No description provided for @ctEmptyWeight.
  ///
  /// In ja, this message translates to:
  /// **'空のダンボールの重さ'**
  String get ctEmptyWeight;

  /// No description provided for @ctMaterial.
  ///
  /// In ja, this message translates to:
  /// **'緩衝材など梱包材の重さ'**
  String get ctMaterial;

  /// No description provided for @ctMaxLoad.
  ///
  /// In ja, this message translates to:
  /// **'1箱に入れられる重さの上限'**
  String get ctMaxLoad;

  /// No description provided for @ctMaxLoadOf.
  ///
  /// In ja, this message translates to:
  /// **'上限 {kg} kg'**
  String ctMaxLoadOf(String kg);

  /// No description provided for @ctDefault.
  ///
  /// In ja, this message translates to:
  /// **'いつも使う箱'**
  String get ctDefault;

  /// No description provided for @ctActive.
  ///
  /// In ja, this message translates to:
  /// **'使う'**
  String get ctActive;

  /// No description provided for @ctInactive.
  ///
  /// In ja, this message translates to:
  /// **'使わない'**
  String get ctInactive;

  /// No description provided for @ctSaved.
  ///
  /// In ja, this message translates to:
  /// **'ダンボールを保存しました'**
  String get ctSaved;

  /// No description provided for @groupProducts.
  ///
  /// In ja, this message translates to:
  /// **'商品'**
  String get groupProducts;

  /// No description provided for @planMenu.
  ///
  /// In ja, this message translates to:
  /// **'その他の操作'**
  String get planMenu;

  /// No description provided for @planDelete.
  ///
  /// In ja, this message translates to:
  /// **'この予定を削除'**
  String get planDelete;

  /// No description provided for @planDeleteQ.
  ///
  /// In ja, this message translates to:
  /// **'「{number}」を削除しますか？'**
  String planDeleteQ(String number);

  /// No description provided for @planDeleteBody.
  ///
  /// In ja, this message translates to:
  /// **'予定明細も一緒に消えます。必要になったら「予定を取り込む」からもう一度アップロードできます。入荷を記録したあとの予定は削除できません。'**
  String get planDeleteBody;

  /// No description provided for @planDeleted.
  ///
  /// In ja, this message translates to:
  /// **'「{number}」を削除しました'**
  String planDeleted(String number);

  /// No description provided for @productsListView.
  ///
  /// In ja, this message translates to:
  /// **'一覧'**
  String get productsListView;

  /// No description provided for @productsPhotoView.
  ///
  /// In ja, this message translates to:
  /// **'写真'**
  String get productsPhotoView;

  /// No description provided for @productNameEnTitle.
  ///
  /// In ja, this message translates to:
  /// **'英語名'**
  String get productNameEnTitle;

  /// No description provided for @productNameEnAdd.
  ///
  /// In ja, this message translates to:
  /// **'英語名を入れる'**
  String get productNameEnAdd;

  /// No description provided for @productNameEnLabel.
  ///
  /// In ja, this message translates to:
  /// **'英語名（英語・中国語の画面ではこの名前で表示）'**
  String get productNameEnLabel;

  /// No description provided for @uomPcs.
  ///
  /// In ja, this message translates to:
  /// **'個'**
  String get uomPcs;

  /// No description provided for @uomSet.
  ///
  /// In ja, this message translates to:
  /// **'セット'**
  String get uomSet;

  /// No description provided for @uomPack.
  ///
  /// In ja, this message translates to:
  /// **'パック'**
  String get uomPack;

  /// No description provided for @uomBox.
  ///
  /// In ja, this message translates to:
  /// **'箱'**
  String get uomBox;

  /// No description provided for @uomCase.
  ///
  /// In ja, this message translates to:
  /// **'ケース'**
  String get uomCase;

  /// No description provided for @uomBag.
  ///
  /// In ja, this message translates to:
  /// **'袋'**
  String get uomBag;

  /// No description provided for @uomRoll.
  ///
  /// In ja, this message translates to:
  /// **'巻'**
  String get uomRoll;

  /// No description provided for @uomSheet.
  ///
  /// In ja, this message translates to:
  /// **'枚'**
  String get uomSheet;

  /// No description provided for @uomDozen.
  ///
  /// In ja, this message translates to:
  /// **'ダース'**
  String get uomDozen;

  /// No description provided for @uomPallet.
  ///
  /// In ja, this message translates to:
  /// **'パレット'**
  String get uomPallet;

  /// No description provided for @productNamesTitle.
  ///
  /// In ja, this message translates to:
  /// **'商品名（言語別）'**
  String get productNamesTitle;

  /// No description provided for @productNamesJa.
  ///
  /// In ja, this message translates to:
  /// **'日本語（商品名）'**
  String get productNamesJa;

  /// No description provided for @productNamesJaHint.
  ///
  /// In ja, this message translates to:
  /// **'日本語名は商品様式で作られます。変更は「商品名の組み立て」から'**
  String get productNamesJaHint;

  /// No description provided for @productNamesEn.
  ///
  /// In ja, this message translates to:
  /// **'English（英語の画面と、中国語名がないときに表示）'**
  String get productNamesEn;

  /// No description provided for @productNamesZh.
  ///
  /// In ja, this message translates to:
  /// **'中文（中国語の画面と、中国語を選んだ印刷物に表示）'**
  String get productNamesZh;

  /// No description provided for @featPrintLanguage.
  ///
  /// In ja, this message translates to:
  /// **'印刷の言語'**
  String get featPrintLanguage;

  /// No description provided for @featPrintLanguageDesc.
  ///
  /// In ja, this message translates to:
  /// **'送り状・内容リスト・箱ラベルを何語で印刷するかと、その用語'**
  String get featPrintLanguageDesc;

  /// No description provided for @plLanguagesTitle.
  ///
  /// In ja, this message translates to:
  /// **'印刷する言語'**
  String get plLanguagesTitle;

  /// No description provided for @plLanguagesHint.
  ///
  /// In ja, this message translates to:
  /// **'押した順に並びます。1番目が大きく、2番目以降がその下に小さく印刷されます。商品名もこの順に、その言語の名前があれば印刷されます。'**
  String get plLanguagesHint;

  /// No description provided for @plPreview.
  ///
  /// In ja, this message translates to:
  /// **'例: {sample}'**
  String plPreview(String sample);

  /// No description provided for @plSaved.
  ///
  /// In ja, this message translates to:
  /// **'保存しました'**
  String get plSaved;

  /// No description provided for @plWordsTitle.
  ///
  /// In ja, this message translates to:
  /// **'帳票とラベルの用語'**
  String get plWordsTitle;

  /// No description provided for @plWordsHint.
  ///
  /// In ja, this message translates to:
  /// **'押すと日本語・英語・中国語を直せます。'**
  String get plWordsHint;

  /// No description provided for @plWordNeedsAll.
  ///
  /// In ja, this message translates to:
  /// **'3つの言語すべてに入れてください'**
  String get plWordNeedsAll;

  /// No description provided for @productMenu.
  ///
  /// In ja, this message translates to:
  /// **'操作'**
  String get productMenu;

  /// No description provided for @productActivate.
  ///
  /// In ja, this message translates to:
  /// **'有効にする'**
  String get productActivate;

  /// No description provided for @productAddOne.
  ///
  /// In ja, this message translates to:
  /// **'商品を1件追加'**
  String get productAddOne;

  /// No description provided for @productDeleteQ.
  ///
  /// In ja, this message translates to:
  /// **'この商品を削除しますか？'**
  String get productDeleteQ;

  /// No description provided for @productDeleteBody.
  ///
  /// In ja, this message translates to:
  /// **'{name}（JAN {jan}）を削除します。元に戻せません。在庫や取引で使われた商品は削除できないため、その場合は無効にします。'**
  String productDeleteBody(String name, String jan);

  /// No description provided for @productDeleteAction.
  ///
  /// In ja, this message translates to:
  /// **'削除'**
  String get productDeleteAction;

  /// No description provided for @productDeleted.
  ///
  /// In ja, this message translates to:
  /// **'「{name}」を削除しました'**
  String productDeleted(String name);

  /// No description provided for @productDeleteInUseTitle.
  ///
  /// In ja, this message translates to:
  /// **'この商品は削除できません'**
  String get productDeleteInUseTitle;

  /// No description provided for @productDeleteInUse.
  ///
  /// In ja, this message translates to:
  /// **'在庫・発注・入荷・出荷・請求のどれかで使われています。履歴が読めるよう、削除ではなく無効にしてください。'**
  String get productDeleteInUse;

  /// No description provided for @productDeleteNotReady.
  ///
  /// In ja, this message translates to:
  /// **'削除の機能がまだデータベースに入っていません（0119 の delete_product）。管理者に適用を依頼してください。'**
  String get productDeleteNotReady;

  /// No description provided for @quoteImportTitle.
  ///
  /// In ja, this message translates to:
  /// **'ファイルから一括登録'**
  String get quoteImportTitle;

  /// No description provided for @quoteImportIntro.
  ///
  /// In ja, this message translates to:
  /// **'見積書・請求書・納品書・自社の商品カタログなど、商品が並んだファイル（Excel・PDF・写真）をAIが読み取り、メーカー・品名・品番・JAN・規格・価格に仕分けます。まだない商品は自社の様式で登録できます。仕入先は選ばなくても読み取れます（ファイルに書かれた会社を探します）。'**
  String get quoteImportIntro;

  /// No description provided for @quoteSupplier.
  ///
  /// In ja, this message translates to:
  /// **'仕入先'**
  String get quoteSupplier;

  /// No description provided for @quoteChooseSupplier.
  ///
  /// In ja, this message translates to:
  /// **'先に仕入先を選んでください'**
  String get quoteChooseSupplier;

  /// No description provided for @quoteChooseFile.
  ///
  /// In ja, this message translates to:
  /// **'見積書のファイルを選ぶ'**
  String get quoteChooseFile;

  /// No description provided for @quoteRead.
  ///
  /// In ja, this message translates to:
  /// **'AIで読み取る'**
  String get quoteRead;

  /// No description provided for @quoteReading.
  ///
  /// In ja, this message translates to:
  /// **'読み取り中です。PDFや写真は1分ほどかかることがあります。'**
  String get quoteReading;

  /// No description provided for @quoteNothingRead.
  ///
  /// In ja, this message translates to:
  /// **'商品の行が読み取れませんでした。表の見出し（JAN・品名・単価など）があるか確かめてください。'**
  String get quoteNothingRead;

  /// No description provided for @quoteUnverified.
  ///
  /// In ja, this message translates to:
  /// **'AIの2回の読み取りが一部食い違いました。数字を確かめてください'**
  String get quoteUnverified;

  /// No description provided for @quoteSummary.
  ///
  /// In ja, this message translates to:
  /// **'{total}行：登録済み {known}・新しい商品 {fresh}・JANなし {noJan}'**
  String quoteSummary(int total, int known, int fresh, int noJan);

  /// No description provided for @quoteRegister.
  ///
  /// In ja, this message translates to:
  /// **'新しい商品を登録（{count}件）'**
  String quoteRegister(int count);

  /// No description provided for @quoteSave.
  ///
  /// In ja, this message translates to:
  /// **'価格を保存（{count}件）'**
  String quoteSave(int count);

  /// No description provided for @quoteSaved.
  ///
  /// In ja, this message translates to:
  /// **'{prices}件の価格を保存しました（商品 {products}件）'**
  String quoteSaved(int prices, int products);

  /// No description provided for @quoteLineKnown.
  ///
  /// In ja, this message translates to:
  /// **'登録済み'**
  String get quoteLineKnown;

  /// No description provided for @quoteLineRegistered.
  ///
  /// In ja, this message translates to:
  /// **'今回登録'**
  String get quoteLineRegistered;

  /// No description provided for @quoteLineNew.
  ///
  /// In ja, this message translates to:
  /// **'新しい商品'**
  String get quoteLineNew;

  /// No description provided for @quoteLineNoJan.
  ///
  /// In ja, this message translates to:
  /// **'JANなし'**
  String get quoteLineNoJan;

  /// No description provided for @quoteTheirName.
  ///
  /// In ja, this message translates to:
  /// **'仕入先の表記: {name}'**
  String quoteTheirName(String name);

  /// No description provided for @quoteUnitPrice.
  ///
  /// In ja, this message translates to:
  /// **'単価 {price}'**
  String quoteUnitPrice(String price);

  /// No description provided for @quoteListPrice.
  ///
  /// In ja, this message translates to:
  /// **'定価 {price}'**
  String quoteListPrice(String price);

  /// No description provided for @quoteRate.
  ///
  /// In ja, this message translates to:
  /// **'掛率 {rate}'**
  String quoteRate(String rate);

  /// No description provided for @quoteCase.
  ///
  /// In ja, this message translates to:
  /// **'入数 {count}'**
  String quoteCase(String count);

  /// No description provided for @lifecycleActive.
  ///
  /// In ja, this message translates to:
  /// **'取扱中'**
  String get lifecycleActive;

  /// No description provided for @lifecycleDormant.
  ///
  /// In ja, this message translates to:
  /// **'休眠'**
  String get lifecycleDormant;

  /// No description provided for @lifecycleDiscontinued.
  ///
  /// In ja, this message translates to:
  /// **'提供終了'**
  String get lifecycleDiscontinued;

  /// No description provided for @lifecycleArchived.
  ///
  /// In ja, this message translates to:
  /// **'アーカイブ'**
  String get lifecycleArchived;

  /// No description provided for @lifecycleToActive.
  ///
  /// In ja, this message translates to:
  /// **'取扱中に戻す'**
  String get lifecycleToActive;

  /// No description provided for @lifecycleToDormant.
  ///
  /// In ja, this message translates to:
  /// **'休眠にする'**
  String get lifecycleToDormant;

  /// No description provided for @lifecycleToDiscontinued.
  ///
  /// In ja, this message translates to:
  /// **'提供終了にする'**
  String get lifecycleToDiscontinued;

  /// No description provided for @lifecycleToArchived.
  ///
  /// In ja, this message translates to:
  /// **'アーカイブする'**
  String get lifecycleToArchived;

  /// No description provided for @lcSelect.
  ///
  /// In ja, this message translates to:
  /// **'選択して一括操作'**
  String get lcSelect;

  /// No description provided for @lcSelected.
  ///
  /// In ja, this message translates to:
  /// **'{count}件を選択中'**
  String lcSelected(int count);

  /// No description provided for @lcSelectAll.
  ///
  /// In ja, this message translates to:
  /// **'表示中をすべて選択（{count}件）'**
  String lcSelectAll(int count);

  /// No description provided for @lcClear.
  ///
  /// In ja, this message translates to:
  /// **'選択を解除'**
  String get lcClear;

  /// No description provided for @lcChange.
  ///
  /// In ja, this message translates to:
  /// **'状態を変える'**
  String get lcChange;

  /// No description provided for @lcHint.
  ///
  /// In ja, this message translates to:
  /// **'商品を押すと選択／除外を切り替えます。絞り込みで対象を減らしてから「すべて選択」も使えます。'**
  String get lcHint;

  /// No description provided for @lcConfirm.
  ///
  /// In ja, this message translates to:
  /// **'{count}件を「{state}」にしますか？'**
  String lcConfirm(int count, String state);

  /// No description provided for @lcActiveBody.
  ///
  /// In ja, this message translates to:
  /// **'入荷・出荷・発注などで、また選べるようになります。'**
  String get lcActiveBody;

  /// No description provided for @lcDormantBody.
  ///
  /// In ja, this message translates to:
  /// **'しばらく扱わない商品です。入荷・出荷などで選べなくなりますが、いつでも取扱中に戻せます。'**
  String get lcDormantBody;

  /// No description provided for @lcDiscontinuedBody.
  ///
  /// In ja, this message translates to:
  /// **'メーカーの廃番や取扱いの終了です。入荷・出荷などで選べなくなります。履歴と在庫の記録は残ります。'**
  String get lcDiscontinuedBody;

  /// No description provided for @lcArchivedBody.
  ///
  /// In ja, this message translates to:
  /// **'普段の一覧から外して保管します。データ・履歴・在庫の記録はすべて残り、いつでも取扱中に戻せます（「状態」の絞り込みで「アーカイブ」を選ぶと見られます）。'**
  String get lcArchivedBody;

  /// No description provided for @lcReason.
  ///
  /// In ja, this message translates to:
  /// **'理由（任意）　例：メーカー廃番'**
  String get lcReason;

  /// No description provided for @lcDone.
  ///
  /// In ja, this message translates to:
  /// **'{count}件を「{state}」にしました'**
  String lcDone(int count, String state);

  /// No description provided for @pfLifecycle.
  ///
  /// In ja, this message translates to:
  /// **'状態'**
  String get pfLifecycle;

  /// No description provided for @pfMaker.
  ///
  /// In ja, this message translates to:
  /// **'メーカー'**
  String get pfMaker;

  /// No description provided for @pfSupplier.
  ///
  /// In ja, this message translates to:
  /// **'仕入先'**
  String get pfSupplier;

  /// No description provided for @pfCategory.
  ///
  /// In ja, this message translates to:
  /// **'カテゴリ'**
  String get pfCategory;

  /// No description provided for @pfStock.
  ///
  /// In ja, this message translates to:
  /// **'在庫'**
  String get pfStock;

  /// No description provided for @pfStockAll.
  ///
  /// In ja, this message translates to:
  /// **'すべて'**
  String get pfStockAll;

  /// No description provided for @pfStockIn.
  ///
  /// In ja, this message translates to:
  /// **'在庫あり'**
  String get pfStockIn;

  /// No description provided for @pfStockOut.
  ///
  /// In ja, this message translates to:
  /// **'在庫なし'**
  String get pfStockOut;

  /// No description provided for @pfClear.
  ///
  /// In ja, this message translates to:
  /// **'絞り込みを解除'**
  String get pfClear;

  /// No description provided for @pfShowing.
  ///
  /// In ja, this message translates to:
  /// **'{shown}件を表示（全{total}件）'**
  String pfShowing(int shown, int total);

  /// No description provided for @pfNoneMatch.
  ///
  /// In ja, this message translates to:
  /// **'絞り込みに合う商品がありません。条件を変えるか「絞り込みを解除」を押してください。'**
  String get pfNoneMatch;

  /// No description provided for @stockNone.
  ///
  /// In ja, this message translates to:
  /// **'在庫なし'**
  String get stockNone;

  /// No description provided for @stockLine.
  ///
  /// In ja, this message translates to:
  /// **'在庫 {onHand}'**
  String stockLine(int onHand);

  /// No description provided for @stockLineReserved.
  ///
  /// In ja, this message translates to:
  /// **'在庫 {onHand}・引当 {reserved}・引当可能 {available}'**
  String stockLineReserved(int onHand, int reserved, int available);

  /// No description provided for @stockTitle.
  ///
  /// In ja, this message translates to:
  /// **'在庫（倉庫別）'**
  String get stockTitle;

  /// No description provided for @stockWarehouseRow.
  ///
  /// In ja, this message translates to:
  /// **'在庫 {onHand}・引当 {reserved}・引当可能 {available}'**
  String stockWarehouseRow(int onHand, int reserved, int available);

  /// No description provided for @pdBasics.
  ///
  /// In ja, this message translates to:
  /// **'基本情報'**
  String get pdBasics;

  /// No description provided for @pdMaker.
  ///
  /// In ja, this message translates to:
  /// **'メーカー'**
  String get pdMaker;

  /// No description provided for @pdBaseName.
  ///
  /// In ja, this message translates to:
  /// **'品名'**
  String get pdBaseName;

  /// No description provided for @pdCode.
  ///
  /// In ja, this message translates to:
  /// **'品番'**
  String get pdCode;

  /// No description provided for @pdJan.
  ///
  /// In ja, this message translates to:
  /// **'JANコード'**
  String get pdJan;

  /// No description provided for @pdCategory.
  ///
  /// In ja, this message translates to:
  /// **'カテゴリ'**
  String get pdCategory;

  /// No description provided for @pdUnit.
  ///
  /// In ja, this message translates to:
  /// **'単位'**
  String get pdUnit;

  /// No description provided for @pdListPrice.
  ///
  /// In ja, this message translates to:
  /// **'定価'**
  String get pdListPrice;

  /// No description provided for @pdPrice.
  ///
  /// In ja, this message translates to:
  /// **'販売価格'**
  String get pdPrice;

  /// No description provided for @pdSuppliers.
  ///
  /// In ja, this message translates to:
  /// **'仕入先'**
  String get pdSuppliers;

  /// No description provided for @pdSpec.
  ///
  /// In ja, this message translates to:
  /// **'規格'**
  String get pdSpec;

  /// No description provided for @quoteSupplierOptional.
  ///
  /// In ja, this message translates to:
  /// **'仕入先（任意）'**
  String get quoteSupplierOptional;

  /// No description provided for @quoteSupplierNone.
  ///
  /// In ja, this message translates to:
  /// **'指定しない（ファイルから判断）'**
  String get quoteSupplierNone;

  /// No description provided for @quoteSupplierHint.
  ///
  /// In ja, this message translates to:
  /// **'選ぶと、その仕入先の書き方で読み、価格も保存できます'**
  String get quoteSupplierHint;

  /// No description provided for @quoteSupplierDetected.
  ///
  /// In ja, this message translates to:
  /// **'ファイルに書かれた会社から判断しました'**
  String get quoteSupplierDetected;

  /// No description provided for @quoteSaveNeedsSupplier.
  ///
  /// In ja, this message translates to:
  /// **'価格を保存するには仕入先を選んでください（商品の登録だけなら不要です）'**
  String get quoteSaveNeedsSupplier;

  /// No description provided for @quoteOurProduct.
  ///
  /// In ja, this message translates to:
  /// **'登録済みの自社商品'**
  String get quoteOurProduct;

  /// No description provided for @quoteTheirCode.
  ///
  /// In ja, this message translates to:
  /// **'先方コード'**
  String get quoteTheirCode;

  /// No description provided for @quoteCaseLabel.
  ///
  /// In ja, this message translates to:
  /// **'入数'**
  String get quoteCaseLabel;

  /// No description provided for @quoteUnitPriceLabel.
  ///
  /// In ja, this message translates to:
  /// **'単価'**
  String get quoteUnitPriceLabel;

  /// No description provided for @quoteRateLabel.
  ///
  /// In ja, this message translates to:
  /// **'掛率'**
  String get quoteRateLabel;

  /// No description provided for @quoteLineArchived.
  ///
  /// In ja, this message translates to:
  /// **'アーカイブ中'**
  String get quoteLineArchived;

  /// No description provided for @quoteLineDormant.
  ///
  /// In ja, this message translates to:
  /// **'休眠中'**
  String get quoteLineDormant;

  /// No description provided for @quoteLineDiscontinued.
  ///
  /// In ja, this message translates to:
  /// **'提供終了'**
  String get quoteLineDiscontinued;

  /// No description provided for @quoteInactiveNote.
  ///
  /// In ja, this message translates to:
  /// **'{count}件は登録済みですが取扱中ではありません（アーカイブ・休眠・提供終了）。このままでは商品ライブラリーの一覧に出ません。'**
  String quoteInactiveNote(int count);

  /// No description provided for @quoteRestore.
  ///
  /// In ja, this message translates to:
  /// **'取扱中に戻す（{count}件）'**
  String quoteRestore(int count);

  /// No description provided for @quoteRestored.
  ///
  /// In ja, this message translates to:
  /// **'{count}件を取扱中に戻しました'**
  String quoteRestored(int count);

  /// No description provided for @pfNoneMatchTitle.
  ///
  /// In ja, this message translates to:
  /// **'絞り込みに合う商品がありません'**
  String get pfNoneMatchTitle;

  /// No description provided for @pfHiddenByState.
  ///
  /// In ja, this message translates to:
  /// **'今の「状態」の絞り込みで表示されていない商品があります：{states}'**
  String pfHiddenByState(String states);

  /// No description provided for @pfShowState.
  ///
  /// In ja, this message translates to:
  /// **'{state}の{count}件を表示'**
  String pfShowState(String state, int count);

  /// No description provided for @pfShowEverything.
  ///
  /// In ja, this message translates to:
  /// **'すべての商品を表示'**
  String get pfShowEverything;

  /// No description provided for @quoteWakePolicy.
  ///
  /// In ja, this message translates to:
  /// **'ファイルに載っている商品は扱う予定の商品とみなし、状態ごとに次のように扱います。休眠 → 取扱中に戻す／アーカイブ → 取扱中に戻す（管理者のみ）／提供終了 → そのまま（メーカー廃番などのため。戻すときは各行でチェック）。各行のチェックで変えられます。在庫数は入荷で増えるもので、ここでは変わりません。'**
  String get quoteWakePolicy;

  /// No description provided for @quoteWakeCount.
  ///
  /// In ja, this message translates to:
  /// **'取扱中に戻す {wake}件・そのまま {keep}件'**
  String quoteWakeCount(int wake, int keep);

  /// No description provided for @quoteWakeLine.
  ///
  /// In ja, this message translates to:
  /// **'この商品を取扱中に戻す'**
  String get quoteWakeLine;

  /// No description provided for @quoteWakeDiscontinued.
  ///
  /// In ja, this message translates to:
  /// **'提供終了の商品です（メーカー廃番など）。また扱うならチェックしてください'**
  String get quoteWakeDiscontinued;

  /// No description provided for @quoteWakeNeedsAdmin.
  ///
  /// In ja, this message translates to:
  /// **'アーカイブ・提供終了から戻すには管理者の権限が必要です'**
  String get quoteWakeNeedsAdmin;

  /// No description provided for @quoteSaveAndWake.
  ///
  /// In ja, this message translates to:
  /// **'価格を保存（{count}件）＋取扱中に戻す（{wake}件）'**
  String quoteSaveAndWake(int count, int wake);

  /// No description provided for @quoteRestoredSome.
  ///
  /// In ja, this message translates to:
  /// **'{changed}件を取扱中に戻しました（{skipped}件は権限がないためそのままです）'**
  String quoteRestoredSome(int changed, int skipped);

  /// No description provided for @supTitle.
  ///
  /// In ja, this message translates to:
  /// **'仕入先（{count}社）'**
  String supTitle(int count);

  /// No description provided for @supCount.
  ///
  /// In ja, this message translates to:
  /// **'仕入先 {count}社'**
  String supCount(int count);

  /// No description provided for @supMore.
  ///
  /// In ja, this message translates to:
  /// **'ほか{count}社'**
  String supMore(int count);

  /// No description provided for @supCheapest.
  ///
  /// In ja, this message translates to:
  /// **'最安'**
  String get supCheapest;

  /// No description provided for @supPrimary.
  ///
  /// In ja, this message translates to:
  /// **'主な仕入先'**
  String get supPrimary;

  /// No description provided for @supTheirName.
  ///
  /// In ja, this message translates to:
  /// **'先方表記: {name}'**
  String supTheirName(String name);

  /// No description provided for @supTheirCode.
  ///
  /// In ja, this message translates to:
  /// **'先方コード: {code}'**
  String supTheirCode(String code);

  /// No description provided for @supUpdated.
  ///
  /// In ja, this message translates to:
  /// **'更新 {date}'**
  String supUpdated(String date);

  /// No description provided for @supNoPrice.
  ///
  /// In ja, this message translates to:
  /// **'価格未登録'**
  String get supNoPrice;

  /// No description provided for @pdTabOurs.
  ///
  /// In ja, this message translates to:
  /// **'自社'**
  String get pdTabOurs;

  /// No description provided for @pdSupplierTerms.
  ///
  /// In ja, this message translates to:
  /// **'{name}の取引条件'**
  String pdSupplierTerms(String name);

  /// No description provided for @pdProductId.
  ///
  /// In ja, this message translates to:
  /// **'商品ID'**
  String get pdProductId;

  /// No description provided for @featPriceBook.
  ///
  /// In ja, this message translates to:
  /// **'価格台帳'**
  String get featPriceBook;

  /// No description provided for @featPriceBookDesc.
  ///
  /// In ja, this message translates to:
  /// **'仕入先ごとの商品の呼び方・価格・掛率の台帳（支店・時期ごと）。ファイルから取り込み、商品ライブラリーとは別に管理します'**
  String get featPriceBookDesc;

  /// No description provided for @clTitle.
  ///
  /// In ja, this message translates to:
  /// **'価格台帳'**
  String get clTitle;

  /// No description provided for @clSearchHint.
  ///
  /// In ja, this message translates to:
  /// **'品名・メーカー・品番・JAN・仕入先の表記で検索'**
  String get clSearchHint;

  /// No description provided for @clEmpty.
  ///
  /// In ja, this message translates to:
  /// **'価格台帳は空です'**
  String get clEmpty;

  /// No description provided for @clEmptyBody.
  ///
  /// In ja, this message translates to:
  /// **'「ファイルから取り込む」で、見積書・請求書・カタログなどを読み込んでください。'**
  String get clEmptyBody;

  /// No description provided for @clInMaster.
  ///
  /// In ja, this message translates to:
  /// **'ライブラリー登録済み'**
  String get clInMaster;

  /// No description provided for @clNotInMaster.
  ///
  /// In ja, this message translates to:
  /// **'ライブラリー未登録'**
  String get clNotInMaster;

  /// No description provided for @clToMaster.
  ///
  /// In ja, this message translates to:
  /// **'商品ライブラリーに登録'**
  String get clToMaster;

  /// No description provided for @clToMasterDone.
  ///
  /// In ja, this message translates to:
  /// **'商品ライブラリーに登録しました（新規 {created}件・既存とつなげた {linked}件・JANかメーカーがなく登録できない {skipped}件）'**
  String clToMasterDone(int created, int linked, int skipped);

  /// No description provided for @clDelete.
  ///
  /// In ja, this message translates to:
  /// **'価格台帳から削除'**
  String get clDelete;

  /// No description provided for @clDeleteQ.
  ///
  /// In ja, this message translates to:
  /// **'{count}件を価格台帳から削除しますか？'**
  String clDeleteQ(int count);

  /// No description provided for @clDeleteBody.
  ///
  /// In ja, this message translates to:
  /// **'価格台帳の商品と、その仕入先ごとの価格の履歴を削除します。元に戻せません。商品ライブラリー・在庫・発注・入荷などには影響しません。'**
  String get clDeleteBody;

  /// No description provided for @clDeleted.
  ///
  /// In ja, this message translates to:
  /// **'{count}件を価格台帳から削除しました'**
  String clDeleted(int count);

  /// No description provided for @ciTitle.
  ///
  /// In ja, this message translates to:
  /// **'ファイルから取り込む'**
  String get ciTitle;

  /// No description provided for @ciIntro.
  ///
  /// In ja, this message translates to:
  /// **'見積書・請求書・納品書・カタログなどのファイル（Excel・PDF・写真）をAIが読み取り、メーカー・品名・品番・JAN・規格・価格に仕分けて価格台帳に入れます。同じJANの商品は更新されます。商品ライブラリー・在庫には影響しません。'**
  String get ciIntro;

  /// No description provided for @ciTermsFor.
  ///
  /// In ja, this message translates to:
  /// **'価格の扱い（任意）'**
  String get ciTermsFor;

  /// No description provided for @ciBranch.
  ///
  /// In ja, this message translates to:
  /// **'仕入先の支店'**
  String get ciBranch;

  /// No description provided for @ciBranchHint.
  ///
  /// In ja, this message translates to:
  /// **'例: 大阪支店（空欄なら全支店共通）'**
  String get ciBranchHint;

  /// No description provided for @ciValidFrom.
  ///
  /// In ja, this message translates to:
  /// **'適用開始日: {date}'**
  String ciValidFrom(String date);

  /// No description provided for @ciSummary.
  ///
  /// In ja, this message translates to:
  /// **'{total}行：新しい商品 {fresh}件・価格台帳にある商品の更新 {known}件'**
  String ciSummary(int total, int fresh, int known);

  /// No description provided for @ciNoSupplierNote.
  ///
  /// In ja, this message translates to:
  /// **'仕入先を選ばないと、商品だけが取り込まれ、価格は保存されません。'**
  String get ciNoSupplierNote;

  /// No description provided for @ciImport.
  ///
  /// In ja, this message translates to:
  /// **'価格台帳に取り込む（{count}件）'**
  String ciImport(int count);

  /// No description provided for @ciDone.
  ///
  /// In ja, this message translates to:
  /// **'取り込みました：新規 {created}件・更新 {updated}件・価格 {terms}件'**
  String ciDone(int created, int updated, int terms);

  /// No description provided for @ciLineNew.
  ///
  /// In ja, this message translates to:
  /// **'新規'**
  String get ciLineNew;

  /// No description provided for @ciLineUpdate.
  ///
  /// In ja, this message translates to:
  /// **'更新'**
  String get ciLineUpdate;

  /// No description provided for @citOverview.
  ///
  /// In ja, this message translates to:
  /// **'概要'**
  String get citOverview;

  /// No description provided for @citSourceFile.
  ///
  /// In ja, this message translates to:
  /// **'取り込んだファイル'**
  String get citSourceFile;

  /// No description provided for @citMaster.
  ///
  /// In ja, this message translates to:
  /// **'商品ライブラリー・在庫'**
  String get citMaster;

  /// No description provided for @citFoundByJan.
  ///
  /// In ja, this message translates to:
  /// **'JANが同じ商品ライブラリーの商品です（まだつなげていません）'**
  String get citFoundByJan;

  /// No description provided for @citOpenMaster.
  ///
  /// In ja, this message translates to:
  /// **'商品ライブラリーで開く'**
  String get citOpenMaster;

  /// No description provided for @citNotInMaster.
  ///
  /// In ja, this message translates to:
  /// **'商品ライブラリーにはまだありません。一覧で選んで「商品ライブラリーに登録」すると、在庫・発注で使えるようになります。'**
  String get citNotInMaster;

  /// No description provided for @citCurrentTerms.
  ///
  /// In ja, this message translates to:
  /// **'今の取引条件（仕入先・支店ごと）'**
  String get citCurrentTerms;

  /// No description provided for @citNoTerms.
  ///
  /// In ja, this message translates to:
  /// **'価格はまだありません'**
  String get citNoTerms;

  /// No description provided for @citAddTerm.
  ///
  /// In ja, this message translates to:
  /// **'取引条件を追加'**
  String get citAddTerm;

  /// No description provided for @citNewTerm.
  ///
  /// In ja, this message translates to:
  /// **'新しい条件'**
  String get citNewTerm;

  /// No description provided for @citAddBranch.
  ///
  /// In ja, this message translates to:
  /// **'別の支店の条件を追加'**
  String get citAddBranch;

  /// No description provided for @citAllBranches.
  ///
  /// In ja, this message translates to:
  /// **'全支店共通'**
  String get citAllBranches;

  /// No description provided for @citSupplierHint.
  ///
  /// In ja, this message translates to:
  /// **'{name}の取引条件の履歴です。新しい条件を入れると、それまでの条件は前日までで終わり、ここに残ります。'**
  String citSupplierHint(String name);

  /// No description provided for @citFrom.
  ///
  /// In ja, this message translates to:
  /// **'{date}〜'**
  String citFrom(String date);

  /// No description provided for @citPeriod.
  ///
  /// In ja, this message translates to:
  /// **'{from}〜{to}'**
  String citPeriod(String from, String to);

  /// No description provided for @citPast.
  ///
  /// In ja, this message translates to:
  /// **'終了'**
  String get citPast;

  /// No description provided for @citValidFromField.
  ///
  /// In ja, this message translates to:
  /// **'適用開始日（YYYY-MM-DD）'**
  String get citValidFromField;

  /// No description provided for @citRateField.
  ///
  /// In ja, this message translates to:
  /// **'掛率（60 または 0.6）'**
  String get citRateField;

  /// No description provided for @citTheirName.
  ///
  /// In ja, this message translates to:
  /// **'先方の商品名'**
  String get citTheirName;

  /// No description provided for @clOpenPriceBook.
  ///
  /// In ja, this message translates to:
  /// **'価格台帳を開く'**
  String get clOpenPriceBook;

  /// No description provided for @specSizeWeight.
  ///
  /// In ja, this message translates to:
  /// **'サイズ・重量'**
  String get specSizeWeight;

  /// No description provided for @specWeight.
  ///
  /// In ja, this message translates to:
  /// **'重量'**
  String get specWeight;

  /// No description provided for @specSize.
  ///
  /// In ja, this message translates to:
  /// **'サイズ'**
  String get specSize;

  /// No description provided for @specSizeValue.
  ///
  /// In ja, this message translates to:
  /// **'幅 {w} × 奥行 {d} × 高さ {h} mm'**
  String specSizeValue(String w, String d, String h);

  /// No description provided for @specNotEntered.
  ///
  /// In ja, this message translates to:
  /// **'未登録'**
  String get specNotEntered;

  /// No description provided for @specSizeAdd.
  ///
  /// In ja, this message translates to:
  /// **'サイズを入力'**
  String get specSizeAdd;

  /// No description provided for @specSizeEdit.
  ///
  /// In ja, this message translates to:
  /// **'サイズを変更'**
  String get specSizeEdit;

  /// No description provided for @specWidth.
  ///
  /// In ja, this message translates to:
  /// **'幅'**
  String get specWidth;

  /// No description provided for @specDepth.
  ///
  /// In ja, this message translates to:
  /// **'奥行'**
  String get specDepth;

  /// No description provided for @specHeight.
  ///
  /// In ja, this message translates to:
  /// **'高さ'**
  String get specHeight;

  /// No description provided for @specSizeNote.
  ///
  /// In ja, this message translates to:
  /// **'その他の表記（A4、φ10×140mm など・任意）'**
  String get specSizeNote;

  /// No description provided for @specSizeHint.
  ///
  /// In ja, this message translates to:
  /// **'外箱ではなく商品そのものの外寸を、ミリ単位で入れてください。'**
  String get specSizeHint;

  /// No description provided for @specSizeInvalid.
  ///
  /// In ja, this message translates to:
  /// **'サイズは0以上の数字で入れてください'**
  String get specSizeInvalid;

  /// No description provided for @specSizeClear.
  ///
  /// In ja, this message translates to:
  /// **'サイズを消す'**
  String get specSizeClear;

  /// No description provided for @specSourceFile.
  ///
  /// In ja, this message translates to:
  /// **'ファイルから'**
  String get specSourceFile;

  /// No description provided for @specWeightField.
  ///
  /// In ja, this message translates to:
  /// **'重量 (g)'**
  String get specWeightField;

  /// No description provided for @citEdit.
  ///
  /// In ja, this message translates to:
  /// **'商品情報を編集'**
  String get citEdit;

  /// No description provided for @citNameField.
  ///
  /// In ja, this message translates to:
  /// **'品名（表示名）'**
  String get citNameField;

  /// No description provided for @citSaved.
  ///
  /// In ja, this message translates to:
  /// **'保存しました'**
  String get citSaved;

  /// No description provided for @citSpecFromPriceBook.
  ///
  /// In ja, this message translates to:
  /// **'サイズ・重量・写真は価格台帳の記録です。商品ライブラリーを変えても、ここは変わりません。'**
  String get citSpecFromPriceBook;

  /// No description provided for @citHowTheyCall.
  ///
  /// In ja, this message translates to:
  /// **'この仕入先での呼び方と今の条件'**
  String get citHowTheyCall;

  /// No description provided for @citRateLabel.
  ///
  /// In ja, this message translates to:
  /// **'掛率'**
  String get citRateLabel;

  /// No description provided for @citTheirCodeLabel.
  ///
  /// In ja, this message translates to:
  /// **'先方の品番'**
  String get citTheirCodeLabel;

  /// No description provided for @citWhere.
  ///
  /// In ja, this message translates to:
  /// **'支店'**
  String get citWhere;

  /// No description provided for @citNoNaming.
  ///
  /// In ja, this message translates to:
  /// **'この仕入先での呼び方はまだ記録されていません'**
  String get citNoNaming;

  /// No description provided for @rmAction.
  ///
  /// In ja, this message translates to:
  /// **'完全に削除'**
  String get rmAction;

  /// No description provided for @rmQ.
  ///
  /// In ja, this message translates to:
  /// **'{count}件を商品ライブラリーから完全に削除しますか？'**
  String rmQ(int count);

  /// No description provided for @rmBody.
  ///
  /// In ja, this message translates to:
  /// **'商品ライブラリーから消え、元に戻せません。商品名・コード・単位・写真の登録も一緒に消えます。\n在庫・入荷・出荷・発注などの記録がある商品は削除されず、そのまま残ります。\n価格台帳の商品は残ります（つながりだけが外れ、同じJANで登録し直すと自動でつながります）。'**
  String get rmBody;

  /// No description provided for @rmConfirmLabel.
  ///
  /// In ja, this message translates to:
  /// **'確認のため「削除」と入力してください'**
  String get rmConfirmLabel;

  /// No description provided for @rmConfirmWord.
  ///
  /// In ja, this message translates to:
  /// **'削除'**
  String get rmConfirmWord;

  /// No description provided for @rmDone.
  ///
  /// In ja, this message translates to:
  /// **'{removed}件を完全に削除しました'**
  String rmDone(int removed);

  /// No description provided for @rmDoneInUse.
  ///
  /// In ja, this message translates to:
  /// **'{removed}件を完全に削除しました。{inUse}件は在庫・入出荷などの記録があるため削除できず、残しています（アーカイブのままにしておけます）'**
  String rmDoneInUse(int removed, int inUse);

  /// No description provided for @ciLineNoMaster.
  ///
  /// In ja, this message translates to:
  /// **'ライブラリー登録不可（JAN・メーカーなし）'**
  String get ciLineNoMaster;

  /// No description provided for @pmImportFile.
  ///
  /// In ja, this message translates to:
  /// **'ファイルから登録'**
  String get pmImportFile;

  /// No description provided for @pkTitle.
  ///
  /// In ja, this message translates to:
  /// **'価格台帳から取り込む'**
  String get pkTitle;

  /// No description provided for @pkIntro.
  ///
  /// In ja, this message translates to:
  /// **'価格台帳にある商品のうち、まだ商品ライブラリーにないものです。仕入れると決めた商品を選んで取り込んでください。同じJANの商品が商品ライブラリーにあれば、新しく作らずにつなぎます。価格台帳の記録はそのまま残ります。'**
  String get pkIntro;

  /// No description provided for @pkEmpty.
  ///
  /// In ja, this message translates to:
  /// **'取り込める商品はありません'**
  String get pkEmpty;

  /// No description provided for @pkEmptyBody.
  ///
  /// In ja, this message translates to:
  /// **'価格台帳の商品は、すべて商品ライブラリーに入っています。価格台帳が空のときは、先に「価格台帳」でファイルを取り込んでください。'**
  String get pkEmptyBody;

  /// No description provided for @pkSelectAll.
  ///
  /// In ja, this message translates to:
  /// **'取り込めるものをすべて選ぶ（{count}件）'**
  String pkSelectAll(int count);

  /// No description provided for @pkImport.
  ///
  /// In ja, this message translates to:
  /// **'選んだ{count}件を商品ライブラリーに取り込む'**
  String pkImport(int count);

  /// No description provided for @pkBlocked.
  ///
  /// In ja, this message translates to:
  /// **'JAN・メーカーなし（取り込めません）'**
  String get pkBlocked;

  /// No description provided for @pmFromPriceBook.
  ///
  /// In ja, this message translates to:
  /// **'価格台帳から取り込む'**
  String get pmFromPriceBook;

  /// No description provided for @libImportTitle.
  ///
  /// In ja, this message translates to:
  /// **'ファイルから商品ライブラリーに登録'**
  String get libImportTitle;

  /// No description provided for @libImportIntro.
  ///
  /// In ja, this message translates to:
  /// **'自社で作ったExcel・CSV・PDF・写真などの商品一覧をAIが読み取り、メーカー・品名・品番・JAN・属性・サイズ・重量に仕分けて、商品ライブラリーに直接登録します。同じJANの商品は内容を更新します。価格台帳には記録しません（仕入先の見積は「価格台帳」で取り込んでください）。'**
  String get libImportIntro;

  /// No description provided for @libImportSummary.
  ///
  /// In ja, this message translates to:
  /// **'{total}行：新規 {fresh}件・更新 {known}件・登録できない {blocked}件（JANかメーカーがない）'**
  String libImportSummary(int total, int fresh, int known, int blocked);

  /// No description provided for @libImportAction.
  ///
  /// In ja, this message translates to:
  /// **'商品ライブラリーに登録（{count}件）'**
  String libImportAction(int count);

  /// No description provided for @libImportDone.
  ///
  /// In ja, this message translates to:
  /// **'登録しました：新規 {created}件・更新 {updated}件・登録できなかった {skipped}件'**
  String libImportDone(int created, int updated, int skipped);

  /// No description provided for @libImportInactive.
  ///
  /// In ja, this message translates to:
  /// **'更新した商品のうち{count}件はアーカイブ・休眠などのままです。使うときは一覧で選んで「取扱中に戻す」を押してください。'**
  String libImportInactive(int count);

  /// No description provided for @libLineNew.
  ///
  /// In ja, this message translates to:
  /// **'新規'**
  String get libLineNew;

  /// No description provided for @libLineUpdate.
  ///
  /// In ja, this message translates to:
  /// **'更新'**
  String get libLineUpdate;

  /// No description provided for @pmNew.
  ///
  /// In ja, this message translates to:
  /// **'新規登録'**
  String get pmNew;

  /// No description provided for @pmNewTitle.
  ///
  /// In ja, this message translates to:
  /// **'商品の登録方法を選んでください'**
  String get pmNewTitle;

  /// No description provided for @pmNewFileDesc.
  ///
  /// In ja, this message translates to:
  /// **'自社で作ったExcel・CSV・PDF・写真などの商品一覧から、まとめて登録します'**
  String get pmNewFileDesc;

  /// No description provided for @pmNewPriceBookDesc.
  ///
  /// In ja, this message translates to:
  /// **'価格台帳（仕入先の見積）から、仕入れると決めた商品を選んで取り込みます'**
  String get pmNewPriceBookDesc;

  /// No description provided for @pmNewManual.
  ///
  /// In ja, this message translates to:
  /// **'手動で1件追加'**
  String get pmNewManual;

  /// No description provided for @pmNewManualDesc.
  ///
  /// In ja, this message translates to:
  /// **'項目を入力して1件ずつ登録します（必須の項目はありません）'**
  String get pmNewManualDesc;

  /// No description provided for @plTabList.
  ///
  /// In ja, this message translates to:
  /// **'商品一覧'**
  String get plTabList;

  /// No description provided for @plTabAlerts.
  ///
  /// In ja, this message translates to:
  /// **'アラート（{count}）'**
  String plTabAlerts(int count);

  /// No description provided for @alEmpty.
  ///
  /// In ja, this message translates to:
  /// **'アラートはありません'**
  String get alEmpty;

  /// No description provided for @alEmptyBody.
  ///
  /// In ja, this message translates to:
  /// **'ファイルから登録したとき、JANや品番がすでに登録されている行はここに入り、登録されません。'**
  String get alEmptyBody;

  /// No description provided for @alHint.
  ///
  /// In ja, this message translates to:
  /// **'ここにある行は登録されていません。必要なら、登録済みの商品を開いて編集するか、内容を直してから登録し直してください。'**
  String get alHint;

  /// No description provided for @alReasonJanExists.
  ///
  /// In ja, this message translates to:
  /// **'JANがすでに登録されています'**
  String get alReasonJanExists;

  /// No description provided for @alReasonJanInFile.
  ///
  /// In ja, this message translates to:
  /// **'同じファイルの中でJANが重複しています'**
  String get alReasonJanInFile;

  /// No description provided for @alReasonSkuExists.
  ///
  /// In ja, this message translates to:
  /// **'品番がすでに登録されています'**
  String get alReasonSkuExists;

  /// No description provided for @alExisting.
  ///
  /// In ja, this message translates to:
  /// **'登録済みの商品：{name}'**
  String alExisting(String name);

  /// No description provided for @alFrom.
  ///
  /// In ja, this message translates to:
  /// **'{file}　{row}行目'**
  String alFrom(String file, int row);

  /// No description provided for @alOpenExisting.
  ///
  /// In ja, this message translates to:
  /// **'登録済みの商品を開く'**
  String get alOpenExisting;

  /// No description provided for @alDeleteSelected.
  ///
  /// In ja, this message translates to:
  /// **'選んだアラートを削除（{count}件）'**
  String alDeleteSelected(int count);

  /// No description provided for @alDeleteAll.
  ///
  /// In ja, this message translates to:
  /// **'アラートをすべて削除（{count}件）'**
  String alDeleteAll(int count);

  /// No description provided for @alDeleteQ.
  ///
  /// In ja, this message translates to:
  /// **'{count}件のアラートを完全に削除しますか？'**
  String alDeleteQ(int count);

  /// No description provided for @alDeleteBody.
  ///
  /// In ja, this message translates to:
  /// **'アラートの記録だけが消え、元に戻せません。商品ライブラリーの商品には影響しません。'**
  String get alDeleteBody;

  /// No description provided for @alDeleted.
  ///
  /// In ja, this message translates to:
  /// **'{count}件のアラートを削除しました'**
  String alDeleted(int count);

  /// No description provided for @libImportSummary2.
  ///
  /// In ja, this message translates to:
  /// **'{total}行：登録 {fresh}件・アラート {alerts}件（JAN・品番が登録済み、またはファイル内で重複）'**
  String libImportSummary2(int total, int fresh, int alerts);

  /// No description provided for @libImportDone2.
  ///
  /// In ja, this message translates to:
  /// **'登録しました：{created}件・アラート {alerts}件（アラートのタブで確認できます）'**
  String libImportDone2(int created, int alerts);

  /// No description provided for @libLineAlert.
  ///
  /// In ja, this message translates to:
  /// **'アラート（重複）'**
  String get libLineAlert;

  /// No description provided for @pfDupTitle.
  ///
  /// In ja, this message translates to:
  /// **'同じJAN・品番の商品があります'**
  String get pfDupTitle;

  /// No description provided for @pfDupJanBody.
  ///
  /// In ja, this message translates to:
  /// **'このJANは「{name}」で登録済みのため、登録できません。'**
  String pfDupJanBody(String name);

  /// No description provided for @pfDupSkuBody.
  ///
  /// In ja, this message translates to:
  /// **'この品番は「{name}」で登録済みのため、登録できません。'**
  String pfDupSkuBody(String name);

  /// No description provided for @productColor.
  ///
  /// In ja, this message translates to:
  /// **'色'**
  String get productColor;

  /// No description provided for @productNewHint.
  ///
  /// In ja, this message translates to:
  /// **'入力した項目だけで登録できます（必須の項目はありません）。'**
  String get productNewHint;

  /// No description provided for @productNameRequiredEdit.
  ///
  /// In ja, this message translates to:
  /// **'品名を入力してください'**
  String get productNameRequiredEdit;

  /// No description provided for @ntFlagQtyFromAmount.
  ///
  /// In ja, this message translates to:
  /// **'数量＝金額÷単価（行に数量が無いため計算）'**
  String get ntFlagQtyFromAmount;

  /// No description provided for @featCompanyProfile.
  ///
  /// In ja, this message translates to:
  /// **'自社情報'**
  String get featCompanyProfile;

  /// No description provided for @featCompanyProfileDesc.
  ///
  /// In ja, this message translates to:
  /// **'自社の名前・別名・登録番号。書類の宛先（自社）と発行元（仕入先）を見分けるのに使います'**
  String get featCompanyProfileDesc;

  /// No description provided for @featEvidence.
  ///
  /// In ja, this message translates to:
  /// **'アップロード履歴'**
  String get featEvidence;

  /// No description provided for @featEvidenceDesc.
  ///
  /// In ja, this message translates to:
  /// **'読み込んだ納品書・請求書・見積書などのファイルを証拠として保管し、いつでも再ダウンロード'**
  String get featEvidenceDesc;

  /// No description provided for @cpHint.
  ///
  /// In ja, this message translates to:
  /// **'書類を読むとき、ここの名前（別名を含む）と登録番号の会社は宛先＝自社として扱い、もう一方の会社を仕入先として読み取ります。'**
  String get cpHint;

  /// No description provided for @cpNotSet.
  ///
  /// In ja, this message translates to:
  /// **'自社名がまだ設定されていません。設定すると仕入先の判定がより確実になります（未設定でも、宛名「〇〇御中」や登録番号・住所の位置から判定します）。'**
  String get cpNotSet;

  /// No description provided for @cpName.
  ///
  /// In ja, this message translates to:
  /// **'会社名'**
  String get cpName;

  /// No description provided for @cpNameKana.
  ///
  /// In ja, this message translates to:
  /// **'会社名（カナ）'**
  String get cpNameKana;

  /// No description provided for @cpNameEn.
  ///
  /// In ja, this message translates to:
  /// **'会社名（英語）'**
  String get cpNameEn;

  /// No description provided for @cpAliases.
  ///
  /// In ja, this message translates to:
  /// **'別名・略称・旧社名・支店名（1行に1つ）'**
  String get cpAliases;

  /// No description provided for @cpRegNo.
  ///
  /// In ja, this message translates to:
  /// **'登録番号（T＋13桁）'**
  String get cpRegNo;

  /// No description provided for @cpPostal.
  ///
  /// In ja, this message translates to:
  /// **'郵便番号'**
  String get cpPostal;

  /// No description provided for @cpAddress.
  ///
  /// In ja, this message translates to:
  /// **'住所'**
  String get cpAddress;

  /// No description provided for @cpPhone.
  ///
  /// In ja, this message translates to:
  /// **'電話'**
  String get cpPhone;

  /// No description provided for @cpFax.
  ///
  /// In ja, this message translates to:
  /// **'FAX'**
  String get cpFax;

  /// No description provided for @cpEmail.
  ///
  /// In ja, this message translates to:
  /// **'メール'**
  String get cpEmail;

  /// No description provided for @cpSave.
  ///
  /// In ja, this message translates to:
  /// **'保存'**
  String get cpSave;

  /// No description provided for @cpSaved.
  ///
  /// In ja, this message translates to:
  /// **'自社情報を保存しました'**
  String get cpSaved;

  /// No description provided for @cpNameRequired.
  ///
  /// In ja, this message translates to:
  /// **'会社名を入力してください'**
  String get cpNameRequired;

  /// No description provided for @cpReadOnly.
  ///
  /// In ja, this message translates to:
  /// **'変更するにはユーザー管理の権限が必要です'**
  String get cpReadOnly;

  /// No description provided for @cpSuggestions.
  ///
  /// In ja, this message translates to:
  /// **'最近の書類の宛先'**
  String get cpSuggestions;

  /// No description provided for @cpSuggestionsHint.
  ///
  /// In ja, this message translates to:
  /// **'読み込んだ書類で「〇〇御中」と書かれていた会社です。自社なら社名か別名に入れてください。'**
  String get cpSuggestionsHint;

  /// No description provided for @cpSuggestionCount.
  ///
  /// In ja, this message translates to:
  /// **'{count}件'**
  String cpSuggestionCount(int count);

  /// No description provided for @cpUseAsName.
  ///
  /// In ja, this message translates to:
  /// **'社名にする'**
  String get cpUseAsName;

  /// No description provided for @cpAddAlias.
  ///
  /// In ja, this message translates to:
  /// **'別名に追加'**
  String get cpAddAlias;

  /// No description provided for @evSupplierCandidates.
  ///
  /// In ja, this message translates to:
  /// **'書類にある他の会社:'**
  String get evSupplierCandidates;

  /// No description provided for @evAddressee.
  ///
  /// In ja, this message translates to:
  /// **'宛先（自社）: {name}'**
  String evAddressee(String name);

  /// No description provided for @evSearch.
  ///
  /// In ja, this message translates to:
  /// **'ファイル名・仕入先・伝票番号で検索'**
  String get evSearch;

  /// No description provided for @evAll.
  ///
  /// In ja, this message translates to:
  /// **'すべて'**
  String get evAll;

  /// No description provided for @evPurposePlan.
  ///
  /// In ja, this message translates to:
  /// **'入荷・納品照合'**
  String get evPurposePlan;

  /// No description provided for @evPurposeShipment.
  ///
  /// In ja, this message translates to:
  /// **'出荷'**
  String get evPurposeShipment;

  /// No description provided for @evPurposeTraining.
  ///
  /// In ja, this message translates to:
  /// **'事前学習'**
  String get evPurposeTraining;

  /// No description provided for @evPurposeQuote.
  ///
  /// In ja, this message translates to:
  /// **'見積'**
  String get evPurposeQuote;

  /// No description provided for @evPurposePriceBook.
  ///
  /// In ja, this message translates to:
  /// **'価格台帳'**
  String get evPurposePriceBook;

  /// No description provided for @evPurposeLibrary.
  ///
  /// In ja, this message translates to:
  /// **'商品ライブラリー'**
  String get evPurposeLibrary;

  /// No description provided for @evPurposeOcr.
  ///
  /// In ja, this message translates to:
  /// **'納品書の写真'**
  String get evPurposeOcr;

  /// No description provided for @evDownload.
  ///
  /// In ja, this message translates to:
  /// **'ダウンロード'**
  String get evDownload;

  /// No description provided for @evDownloaded.
  ///
  /// In ja, this message translates to:
  /// **'ファイルを保存しました'**
  String get evDownloaded;

  /// No description provided for @evEmpty.
  ///
  /// In ja, this message translates to:
  /// **'保管されたファイルはまだありません'**
  String get evEmpty;

  /// No description provided for @evEmptyBody.
  ///
  /// In ja, this message translates to:
  /// **'納品照合・出荷・見積などでファイルを読み込むと、ここに自動で保管されます。'**
  String get evEmptyBody;

  /// No description provided for @evCommitted.
  ///
  /// In ja, this message translates to:
  /// **'登録済み {ref}'**
  String evCommitted(String ref);

  /// No description provided for @evNotCommitted.
  ///
  /// In ja, this message translates to:
  /// **'読み取りのみ（未登録）'**
  String get evNotCommitted;

  /// No description provided for @evLines.
  ///
  /// In ja, this message translates to:
  /// **'{count}行'**
  String evLines(int count);

  /// No description provided for @evFile.
  ///
  /// In ja, this message translates to:
  /// **'元のファイル'**
  String get evFile;

  /// No description provided for @featAiHealth.
  ///
  /// In ja, this message translates to:
  /// **'AIの稼働状況'**
  String get featAiHealth;

  /// No description provided for @featAiHealthDesc.
  ///
  /// In ja, this message translates to:
  /// **'AIが正しく動いているかを、応答率・応答時間・読み取りの一致率・合計の一致率で判定します'**
  String get featAiHealthDesc;

  /// No description provided for @ahVerdictGood.
  ///
  /// In ja, this message translates to:
  /// **'正常'**
  String get ahVerdictGood;

  /// No description provided for @ahVerdictWarn.
  ///
  /// In ja, this message translates to:
  /// **'注意'**
  String get ahVerdictWarn;

  /// No description provided for @ahVerdictBad.
  ///
  /// In ja, this message translates to:
  /// **'異常'**
  String get ahVerdictBad;

  /// No description provided for @ahVerdictUnknown.
  ///
  /// In ja, this message translates to:
  /// **'データなし'**
  String get ahVerdictUnknown;

  /// No description provided for @ahPeriod24h.
  ///
  /// In ja, this message translates to:
  /// **'24時間'**
  String get ahPeriod24h;

  /// No description provided for @ahPeriod7d.
  ///
  /// In ja, this message translates to:
  /// **'7日間'**
  String get ahPeriod7d;

  /// No description provided for @ahPeriod30d.
  ///
  /// In ja, this message translates to:
  /// **'30日間'**
  String get ahPeriod30d;

  /// No description provided for @ahAvailability.
  ///
  /// In ja, this message translates to:
  /// **'応答率'**
  String get ahAvailability;

  /// No description provided for @ahAvailabilityFormula.
  ///
  /// In ja, this message translates to:
  /// **'正常に返った回数 ÷ 呼び出した回数'**
  String get ahAvailabilityFormula;

  /// No description provided for @ahLatency.
  ///
  /// In ja, this message translates to:
  /// **'応答時間（遅い方の5%）'**
  String get ahLatency;

  /// No description provided for @ahLatencyFormula.
  ///
  /// In ja, this message translates to:
  /// **'応答した呼び出しを速い順に並べて95%目の時間'**
  String get ahLatencyFormula;

  /// No description provided for @ahAgreement.
  ///
  /// In ja, this message translates to:
  /// **'読み取りの一致率'**
  String get ahAgreement;

  /// No description provided for @ahAgreementFormula.
  ///
  /// In ja, this message translates to:
  /// **'1 −（2回の読み取りで食い違った行＋確認で追加・削除された行）÷ AIが読んだ行'**
  String get ahAgreementFormula;

  /// No description provided for @ahTotals.
  ///
  /// In ja, this message translates to:
  /// **'合計の一致率'**
  String get ahTotals;

  /// No description provided for @ahTotalsFormula.
  ///
  /// In ja, this message translates to:
  /// **'明細の合計が書類の合計と合ったファイル ÷ 比べられたファイル'**
  String get ahTotalsFormula;

  /// No description provided for @ahThresholdHigher.
  ///
  /// In ja, this message translates to:
  /// **'正常 {good} 以上・注意 {warn} 以上・それ未満は異常'**
  String ahThresholdHigher(String good, String warn);

  /// No description provided for @ahThresholdLower.
  ///
  /// In ja, this message translates to:
  /// **'正常 {good} 以下・注意 {warn} 以下・それを超えると異常'**
  String ahThresholdLower(String good, String warn);

  /// No description provided for @ahCalls.
  ///
  /// In ja, this message translates to:
  /// **'呼び出し {total}回（成功 {ok}・失敗 {failed}）'**
  String ahCalls(int total, int ok, int failed);

  /// No description provided for @ahTokens.
  ///
  /// In ja, this message translates to:
  /// **'使用トークン 入力 {input}・出力 {output}'**
  String ahTokens(String input, String output);

  /// No description provided for @ahFiles.
  ///
  /// In ja, this message translates to:
  /// **'読み込んだファイル {files}件（うちAIで読んだもの {aiFiles}件）'**
  String ahFiles(int files, int aiFiles);

  /// No description provided for @ahLastCall.
  ///
  /// In ja, this message translates to:
  /// **'最後の呼び出し {when}'**
  String ahLastCall(String when);

  /// No description provided for @ahLastOk.
  ///
  /// In ja, this message translates to:
  /// **'最後に成功 {when}'**
  String ahLastOk(String when);

  /// No description provided for @ahBlockingNoKey.
  ///
  /// In ja, this message translates to:
  /// **'サーバーに GEMINI_API_KEY が設定されていません。Supabase のシークレットに設定してください。'**
  String get ahBlockingNoKey;

  /// No description provided for @ahBlockingAuth.
  ///
  /// In ja, this message translates to:
  /// **'APIキーが拒否されました（無効・削除済み・別のプロジェクト）。Google AI Studio でキーを確認してください。'**
  String get ahBlockingAuth;

  /// No description provided for @ahBlockingQuota.
  ///
  /// In ja, this message translates to:
  /// **'回数の上限に達しています。無料枠なら有料枠への切り替えを検討してください。'**
  String get ahBlockingQuota;

  /// No description provided for @ahKindNoKey.
  ///
  /// In ja, this message translates to:
  /// **'キー未設定'**
  String get ahKindNoKey;

  /// No description provided for @ahKindAuth.
  ///
  /// In ja, this message translates to:
  /// **'キー拒否'**
  String get ahKindAuth;

  /// No description provided for @ahKindQuota.
  ///
  /// In ja, this message translates to:
  /// **'回数上限'**
  String get ahKindQuota;

  /// No description provided for @ahKindOverload.
  ///
  /// In ja, this message translates to:
  /// **'混雑・障害'**
  String get ahKindOverload;

  /// No description provided for @ahKindBadRequest.
  ///
  /// In ja, this message translates to:
  /// **'要求エラー'**
  String get ahKindBadRequest;

  /// No description provided for @ahKindNetwork.
  ///
  /// In ja, this message translates to:
  /// **'接続できない'**
  String get ahKindNetwork;

  /// No description provided for @ahKindParse.
  ///
  /// In ja, this message translates to:
  /// **'応答の形式違い'**
  String get ahKindParse;

  /// No description provided for @ahKindOther.
  ///
  /// In ja, this message translates to:
  /// **'その他'**
  String get ahKindOther;

  /// No description provided for @ahRecentErrors.
  ///
  /// In ja, this message translates to:
  /// **'最近のエラー'**
  String get ahRecentErrors;

  /// No description provided for @ahNoErrors.
  ///
  /// In ja, this message translates to:
  /// **'この期間のエラーはありません'**
  String get ahNoErrors;

  /// No description provided for @ahPing.
  ///
  /// In ja, this message translates to:
  /// **'接続テスト'**
  String get ahPing;

  /// No description provided for @ahPingOk.
  ///
  /// In ja, this message translates to:
  /// **'接続OK（{ms} ms・{model}）'**
  String ahPingOk(int ms, String model);

  /// No description provided for @ahPingFailed.
  ///
  /// In ja, this message translates to:
  /// **'接続できません: {kind}'**
  String ahPingFailed(String kind);

  /// No description provided for @ahHowJudged.
  ///
  /// In ja, this message translates to:
  /// **'判定のしかた'**
  String get ahHowJudged;

  /// No description provided for @ahHowJudgedBody.
  ///
  /// In ja, this message translates to:
  /// **'4つの指標のうち一番悪い判定が全体の判定です（データのない指標は数えません）。最後の呼び出しがキー未設定・キー拒否・回数上限で失敗していれば、ほかの指標に関係なく「異常」になります。'**
  String get ahHowJudgedBody;

  /// No description provided for @ahRefresh.
  ///
  /// In ja, this message translates to:
  /// **'更新'**
  String get ahRefresh;
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
