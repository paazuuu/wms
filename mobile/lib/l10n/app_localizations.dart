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
  /// **'商品マスタ'**
  String get featProducts;

  /// No description provided for @featProductsDesc.
  ///
  /// In ja, this message translates to:
  /// **'JANコードに紐づく商品名・カテゴリ・価格を管理'**
  String get featProductsDesc;

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
  /// **'商品マスタ'**
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
  /// **'商品マスタ'**
  String get productsTitle;

  /// No description provided for @productsShowInactive.
  ///
  /// In ja, this message translates to:
  /// **'無効な商品も表示'**
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
  /// **'右下の＋から商品を登録できます。'**
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
  /// **'この商品を無効にしますか？'**
  String get productDeactivateQ;

  /// No description provided for @productDeactivateBody.
  ///
  /// In ja, this message translates to:
  /// **'無効にすると、入荷・出荷などの操作でこの商品を選べなくなります。'**
  String get productDeactivateBody;

  /// No description provided for @productDeactivateAction.
  ///
  /// In ja, this message translates to:
  /// **'無効にする'**
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
  /// **'SKU'**
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
  /// **'このJANは商品マスタに未登録です'**
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
  /// **'検品待ち在庫'**
  String get heldStockTitle;

  /// Held-stock screen: nothing held, which is the good state.
  ///
  /// In ja, this message translates to:
  /// **'検品待ちの在庫はありません'**
  String get heldStockEmpty;

  /// Held-stock screen: what appears here and why it matters.
  ///
  /// In ja, this message translates to:
  /// **'入荷時に検品が必要な商品は、検品が終わるまでここに並びます。出荷はできません。'**
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
