// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Japanese (`ja`).
class AppLocalizationsJa extends AppLocalizations {
  AppLocalizationsJa([String locale = 'ja']) : super(locale);

  @override
  String get appTitle => 'WMS';

  @override
  String get search => '検索';

  @override
  String get retry => '再試行';

  @override
  String get signOut => 'サインアウト';

  @override
  String get backToMenu => 'メニューに戻る';

  @override
  String get somethingWentWrong => '問題が発生しました';

  @override
  String get languageTooltip => '言語を選択';

  @override
  String get textSizeMenu => '文字サイズ';

  @override
  String get textSizeNormal => '標準';

  @override
  String get textSizeLarge => '大';

  @override
  String get textSizeXLarge => '特大';

  @override
  String get textSizeXXLarge => '最大';

  @override
  String get languageJapanese => '日本語';

  @override
  String get languageEnglish => 'English';

  @override
  String get languageChinese => '中文';

  @override
  String get navDashboard => 'ダッシュボード';

  @override
  String get brandSubtitle => '倉庫管理';

  @override
  String get welcomeBack => 'おかえりなさい';

  @override
  String get operatorName => '作業者';

  @override
  String get scannerReady => 'スキャン準備完了';

  @override
  String get readyToScanTitle => 'スキャン準備完了';

  @override
  String get readyToScanBody => 'どこでもハンディでスキャン、またはタップしてバーコード・SKU・名称で検索。';

  @override
  String get topbarScanHint => 'バーコード / SKU をスキャンまたは検索';

  @override
  String get menu => 'メニュー';

  @override
  String get cameraScan => 'カメラでスキャン';

  @override
  String get groupFieldOperations => '現場作業';

  @override
  String get groupManagement => '管理';

  @override
  String get featInspection => '検品';

  @override
  String get featInspectionDesc => 'バーコード・数量照合、NG記録';

  @override
  String get featStockAdjustment => '在庫調整';

  @override
  String get featStockAdjustmentDesc => '理由付きでスキャンして増減';

  @override
  String get featStockCount => '棚卸';

  @override
  String get featStockCountDesc => 'ロケーション別の循環棚卸';

  @override
  String get featPicking => 'ピッキング';

  @override
  String get featPickingDesc => 'スキャンで受注を出荷';

  @override
  String get comingSoon => '近日対応';

  @override
  String get comingSoonBody => 'このサーバーAPIは準備済みです。モバイル画面が次の予定です。';

  @override
  String get signIn => 'サインイン';

  @override
  String get signInSubtitle => '検品を始めるにはサインイン';

  @override
  String get email => 'メールアドレス';

  @override
  String get password => 'パスワード';

  @override
  String get emailRequired => 'メールアドレスを入力してください';

  @override
  String get passwordRequired => 'パスワードを入力してください';

  @override
  String get show => '表示';

  @override
  String get hide => '非表示';

  @override
  String get loading => '読み込み中…';

  @override
  String lineCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count件の明細',
    );
    return '$_temp0';
  }

  @override
  String get fieldPhone => '電話';

  @override
  String get fieldAddress => '住所';

  @override
  String get fieldContact => '担当者';

  @override
  String get fieldSupplier => '仕入先';

  @override
  String get actionComplete => '完了';

  @override
  String get actionContinue => '続ける';

  @override
  String get filterAll => 'すべて';

  @override
  String get unknownSupplier => '仕入先不明';

  @override
  String get pickingEmpty => 'ピッキング対象がありません。';

  @override
  String get noLinesToPick => 'ピッキングする明細がありません。';

  @override
  String get unnamedProduct => '名称未設定の商品';

  @override
  String get pickingEmptyBody => '出荷待ちの受注がここに表示されます。';

  @override
  String pickedProgress(int picked, int total) {
    return '$picked / $total ピック済み';
  }

  @override
  String get quantity => '数量';

  @override
  String get actionCancel => 'キャンセル';

  @override
  String get actionRecord => '記録';

  @override
  String get working => '処理中…';

  @override
  String get adjustAdd => '追加';

  @override
  String get adjustRemove => '減少';

  @override
  String get scanBarcode => 'バーコードをスキャン';

  @override
  String get torchOn => 'ライトを点灯';

  @override
  String get torchOff => 'ライトを消灯';

  @override
  String get alignBarcode => '枠内にバーコードを合わせてください';

  @override
  String get scanOrTypeBarcode => 'スキャンまたはバーコードを入力';

  @override
  String get featDelivery => '納品照合';

  @override
  String get featDeliveryDesc => '納品書とExcel予定を照合し過不足を可視化';

  @override
  String get deliveryStatusOpen => '未照合';

  @override
  String get deliveryStatusReconciling => '照合中';

  @override
  String get deliveryStatusPartial => '部分納品';

  @override
  String get deliveryStatusCompleted => '照合済み';

  @override
  String get reconPending => '未確認';

  @override
  String get reconMatched => '一致';

  @override
  String get reconShortfall => '不足';

  @override
  String get reconOver => '過剰';

  @override
  String get reconUnexpected => '想定外';

  @override
  String get deliveryPlansTitle => '納品照合';

  @override
  String get deliveryPlansEmpty => '納品予定がありません。';

  @override
  String get deliveryPlansEmptyBody => 'バックオフィスで取り込んだ納品予定（Excel）がここに表示されます。';

  @override
  String get deliveryPlansHint => 'スキャンまたは伝票番号・仕入先で検索';

  @override
  String get deliveryNoMatches => '一致する納品予定がありません。';

  @override
  String get deliverySearchTip => '別の伝票番号または仕入先をお試しください。';

  @override
  String plannedLines(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '予定明細 $count 件',
    );
    return '$_temp0';
  }

  @override
  String get deliveryNumberLabel => '伝票番号';

  @override
  String get scanDeliveryHint => '品物のJANをスキャン';

  @override
  String get ocrAssist => '納品書を撮影（OCR補助）';

  @override
  String ocrFound(int count) {
    return '納品書から $count 件のJANを検出しました';
  }

  @override
  String get ocrNoneFound => '納品書からJANを検出できませんでした。';

  @override
  String get ocrUnavailable => 'この端末ではOCRを利用できません。';

  @override
  String get reconSummaryTitle => '照合状況';

  @override
  String get deliveryPlanned => '予定';

  @override
  String get reconReceivedPrev => '既納';

  @override
  String get reconThisTime => '今回';

  @override
  String get reconRemaining => '残';

  @override
  String get completeReconcile => '照合を完了';

  @override
  String get reconcileConfirmQ => '照合を完了しますか？';

  @override
  String get reconcileConfirmBody => '現在の計数結果を送信して照合を完了します。';

  @override
  String get reconcileConfirmDiscrepancy => '差異があります（不足・過剰・想定外）。このまま完了しますか？';

  @override
  String get reconcilePartialQ => '未納の品目が残っています';

  @override
  String reconcilePartialBody(int count) {
    return '未納が $count 本残っています。部分納品として保存し残りを未納リストに残しますか？　それとも完了にして残りを欠品として扱いますか？';
  }

  @override
  String get reconcileKeepOpen => '部分納品として保存';

  @override
  String get reconcileFinalizeShort => '完了にする（残りは欠品）';

  @override
  String get reconcilePartialSaved => '部分納品として保存しました（未納を継続保持）';

  @override
  String get reconNoteReference => '備考';

  @override
  String get reconAlreadyDoneQ => 'この予定は照合済みです';

  @override
  String get reconAlreadyDoneBody =>
      '追加で取り込むと在庫にもう一度加算されます。間違いを直す場合は、受領履歴から該当の受領を取り消してください。';

  @override
  String doubleScanWarning(String code) {
    return '$code が予定数を超えました（二重スキャン？）';
  }

  @override
  String get receiptHistoryTitle => '受領履歴／訂正';

  @override
  String get receiptEmpty => '受領履歴はまだありません。';

  @override
  String get receiptEmptyBody => 'この予定を照合するたびに、受領がここに記録され、取り消せます。';

  @override
  String get receiptCancelAction => '受領を取消';

  @override
  String get receiptCancelledBadge => '取消済み';

  @override
  String get receiptCancelQ => 'この受領を取り消しますか？';

  @override
  String get receiptCancelBody => 'この受領で加算した数量と在庫を差し戻します。';

  @override
  String get receiptCancelledDone => '受領を取り消しました';

  @override
  String get showCompletedPlans => '照合済みも表示';

  @override
  String get hideCompletedPlans => '照合済みを隠す';

  @override
  String get reconcileDone => '照合を完了しました';

  @override
  String get reconcileEmptyCounts => 'まだ計数がありません。スキャンして開始してください。';

  @override
  String get unexpectedItem => '想定外の品目';

  @override
  String enterQuantityFor(String code) {
    return '$code の数量';
  }

  @override
  String get planImportTitle => '予定を取り込む';

  @override
  String get planImportHint => 'Excel / PDF / 画像を選んでアップロードすると、自動で予定に登録します。';

  @override
  String get planImportChooseFirst => 'ファイルを選び、伝票番号を入力してください。';

  @override
  String planImportedSummary(int count, int total) {
    return '$count 品目・合計 $total 本を取り込みました';
  }

  @override
  String get planReadAction => '読み取る';

  @override
  String get planReading => '読取中…';

  @override
  String get importFormatsHint => 'Excel / PDF / 画像 に対応';

  @override
  String get importChooseFile => 'ファイルを選ぶ';

  @override
  String get changeFile => '変更';

  @override
  String get importHeaderSection => 'ヘッダー情報';

  @override
  String get importLinesPreview => '明細プレビュー';

  @override
  String importMoreLines(int count) {
    return '他 $count 件';
  }

  @override
  String get planReviewTitle => 'ヘッダーの確認';

  @override
  String get planReviewHint => '納品書から自動で読み取りました。間違い・空欄は登録前にここで修正できます。';

  @override
  String get planCommitAction => '登録する';

  @override
  String get planRegistering => '登録中…';

  @override
  String planPreviewCount(int count, int total) {
    return '$count 品目・$total 本';
  }

  @override
  String get fieldRegistrationNumber => '登録番号（T…）';

  @override
  String get fieldCustomerCode => 'お客様コード';

  @override
  String get fieldDocNumber => '納品書番号';

  @override
  String get headerUnreadHint => '読み取れませんでした。入力してください';

  @override
  String get planNeedsReviewBadge => '要確認';

  @override
  String get planUnidentifiedNote =>
      '会社名を読み取れなかったため「UNKNOWN」枠の識別番号を採番しました。仕入先を入力すると正しい会社に付け替えられます。';

  @override
  String get referenceNoLabel => '整理番号';

  @override
  String get companyCode => '会社コード';

  @override
  String get totalStockTitle => '総在庫（JAN別）';

  @override
  String get sortMenu => '並び替え';

  @override
  String get sortByStock => '在庫数順';

  @override
  String get sortByName => '品名順';

  @override
  String get sortByJan => 'JAN順';

  @override
  String get stockOnHandUnit => '在庫';

  @override
  String get stockEmpty => '在庫がまだありません。';

  @override
  String get stockEmptyBody => '照合を完了すると、JANごとの総在庫がここに集計されます。';

  @override
  String get featShipment => '出庫';

  @override
  String get featShipmentDesc => '出庫リストを取り込み、段ボールに小分けして在庫を引く';

  @override
  String get shipmentListTitle => '出庫';

  @override
  String get shipmentImportTitle => '出庫リストを取り込む';

  @override
  String get shipmentEmpty => '出庫はありません。';

  @override
  String get shipmentEmptyBody => '得意先のExcel / PDF を取り込んで出庫を始めます。';

  @override
  String get shipmentSearchHint => '出庫番号・得意先で検索';

  @override
  String get shipmentStatusOpen => '梱包待ち';

  @override
  String get shipmentStatusPacking => '梱包中';

  @override
  String get shipmentStatusShipped => '出庫済み';

  @override
  String get shipmentStatusCancelled => '取消';

  @override
  String cartonCountLabel(int count) {
    return '$count 箱';
  }

  @override
  String get shipmentLinesSection => '出庫リスト';

  @override
  String get cartonsSection => '段ボール';

  @override
  String packProgress(int packed, int total) {
    return '梱包 $packed / $total';
  }

  @override
  String get addCarton => '段ボールを追加';

  @override
  String cartonNoLabel(int no) {
    return '段ボール #$no';
  }

  @override
  String get cartonLabelHint => 'ラベル（任意）例: A-1';

  @override
  String get cartonEditTitle => '段ボールの中身';

  @override
  String get packRemaining => '未梱包';

  @override
  String get packThisCarton => 'この箱';

  @override
  String get overpackWarning => '梱包数が出庫数を超えています。';

  @override
  String get shipConfirmAction => '出庫確定';

  @override
  String get shipConfirmQ => '出庫を確定しますか？';

  @override
  String get shipConfirmBody => '在庫から数量を引いて出庫を確定します。';

  @override
  String get shipShortWarning => '在庫が不足している品目があります。在庫はマイナスにはなりません。確定しますか？';

  @override
  String get shipDone => '出庫を確定しました';

  @override
  String get shipCancelAction => '出庫を取消';

  @override
  String get shipCancelQ => 'この出庫を取り消しますか？';

  @override
  String get shipCancelBody => '引いた数量を在庫に戻し、出庫を未確定に戻します。';

  @override
  String get shipCancelledDone => '出庫を未確定に戻しました';

  @override
  String get printOverall => '出庫リストを印刷/PDF';

  @override
  String get printAllCartons => '段ボール別を印刷/PDF';

  @override
  String get printThisCarton => '印刷/PDF';

  @override
  String get printDeliverySlip => '送り状を印刷/PDF';

  @override
  String get printMenu => '印刷/PDF';

  @override
  String get senderSettingsTitle => '差出人（自社）設定';

  @override
  String get senderSettingsHint => '差出人のデフォルトとして保存します。印刷時にどの項目を載せるか毎回選べます。';

  @override
  String get senderPickTitle => 'この印刷の差出人';

  @override
  String get senderInclude => '差出人を印刷する';

  @override
  String get senderNoneSet => '差出人が未設定です。';

  @override
  String get senderSaved => '差出人情報を保存しました';

  @override
  String get senderPreview => '印刷プレビュー';

  @override
  String get fieldCompanyName => '会社名';

  @override
  String get fieldPostalCode => '郵便番号';

  @override
  String get fieldFax => 'FAX';

  @override
  String get fieldNote => '備考';

  @override
  String get deleteCartonQ => 'この段ボールを削除しますか？';

  @override
  String get actionSave => '保存';

  @override
  String get actionDelete => '削除';

  @override
  String get dashOverview => '概況';

  @override
  String get dashInboundToday => '本日の入庫';

  @override
  String get dashOutboundToday => '本日の出庫';

  @override
  String get dashOutstanding => '未納';

  @override
  String get dashTotalStock => '総在庫';

  @override
  String get dashLowStock => '要注意在庫';

  @override
  String get dashTrendTitle => '入出庫の推移（14日）';

  @override
  String get dashInbound => '入庫';

  @override
  String get dashOutbound => '出庫';

  @override
  String get dashOutstandingListTitle => '未納リスト';

  @override
  String get dashLowStockListTitle => '在庫アラート';

  @override
  String get dashNoOutstanding => '未納はありません';

  @override
  String get dashNoAlerts => '在庫アラートはありません';

  @override
  String dashCount(int count) {
    return '$count件';
  }

  @override
  String dashSkuCount(int count) {
    return '$count SKU';
  }

  @override
  String dashThreshold(int count) {
    return 'しきい値 $count';
  }

  @override
  String get whAllWarehouses => 'すべての倉庫';

  @override
  String get whSwitch => '倉庫を切替';

  @override
  String get whAdd => '倉庫を追加';

  @override
  String get whAddTitle => '倉庫を追加';

  @override
  String get whManage => '倉庫を管理';

  @override
  String get whOverviewTitle => '倉庫一覧';

  @override
  String get whTotals => '合計';

  @override
  String get whFieldCode => '倉庫コード';

  @override
  String get whFieldName => '倉庫名';

  @override
  String get whFieldAddress => '住所';

  @override
  String get whFieldPhone => '電話';

  @override
  String get whFieldTimezone => 'タイムゾーン';

  @override
  String get whFieldActive => '有効';

  @override
  String get whFieldDefaultBins => '初期の棚を作成する';

  @override
  String get whFieldDefaultBinsHelp => '入荷仮置・検品保留・出荷・通常棚の4つを自動作成します。';

  @override
  String get whFieldReceivingBin => 'デフォルト入荷エリア';

  @override
  String get whFieldShippingBin => 'デフォルト出荷エリア';

  @override
  String get whCodeRequired => '倉庫コードを入力してください';

  @override
  String get whNameRequired => '倉庫名を入力してください';

  @override
  String whCreated(String name) {
    return '倉庫「$name」を追加しました';
  }

  @override
  String get whInactive => '無効';

  @override
  String get whStatInbound => '入荷待ち';

  @override
  String get whStatOutbound => '出荷待ち';

  @override
  String get whStatSku => 'SKU';

  @override
  String get whStatOnHand => '在庫';

  @override
  String get whNoWarehouses => '倉庫がまだありません';

  @override
  String get whBinsTitle => '棚（ロケーション）';

  @override
  String get whBinStaging => '入荷仮置';

  @override
  String get whBinPickable => '通常棚';

  @override
  String get whBinPickableStaging => '仮置(引当可)';

  @override
  String get whBinQcHold => '検品保留';

  @override
  String get whBinShipping => '出荷';

  @override
  String get whBinReturns => '返品';

  @override
  String get whBinDamaged => '破損';

  @override
  String get whBinVirtual => '仮想';

  @override
  String get ledgerTitle => '在庫履歴';

  @override
  String get ledgerSubtitle => 'この商品の在庫が動いた理由';

  @override
  String get ledgerEmpty => 'まだ在庫の動きがありません';

  @override
  String get ledgerBeforeAfter => '変更前 → 変更後';

  @override
  String get mvOpening => '期首';

  @override
  String get mvReceipt => '入庫';

  @override
  String get mvReceiptCancel => '入庫取消';

  @override
  String get mvPutaway => '棚入れ';

  @override
  String get mvPick => 'ピッキング';

  @override
  String get mvShip => '出庫';

  @override
  String get mvShipCancel => '出庫取消';

  @override
  String get mvAdjust => '在庫調整';

  @override
  String get mvCount => '棚卸';

  @override
  String get mvTransferIn => '移動入庫';

  @override
  String get mvTransferOut => '移動出庫';

  @override
  String get qcTitle => '検品';

  @override
  String get qcListEmpty => '検品はまだありません';

  @override
  String get qcListEmptyBody => '受領履歴から検品を開始できます。';

  @override
  String get qcStart => '検品を開始';

  @override
  String get qcComplete => '検品を確定';

  @override
  String get qcResultPending => '未検品';

  @override
  String get qcResultPass => '合格';

  @override
  String get qcResultFail => '不合格';

  @override
  String get qcResultPartial => '一部合格';

  @override
  String get qcResultHold => '保留';

  @override
  String get qcPassed => '合格数';

  @override
  String get qcFailed => '不良数';

  @override
  String get qcExpected => '予定';

  @override
  String get qcActual => '実数';

  @override
  String get qcDiscrepancy => '差異';

  @override
  String get qcLot => 'ロット';

  @override
  String get qcNote => '備考';

  @override
  String get qcHold => '保留にする';

  @override
  String get qcRecord => '記録';

  @override
  String qcUnchecked(int count) {
    return '未検品 $count 件';
  }

  @override
  String get qcCompleteBlocked => '未検品の明細があるため確定できません';

  @override
  String qcCompleted(String status) {
    return '検品を確定しました（$status）';
  }

  @override
  String qcFailedUnits(int count) {
    return '不良 $count';
  }

  @override
  String get qcSplitHint => '合格数と不良数を入力してください（合計が実数になります）';

  @override
  String get whFieldUsesLocations => '棚（ロケーション）で管理する';

  @override
  String get whFieldUsesLocationsHelp =>
      'オフのままなら在庫は倉庫単位で管理します。棚番で管理する場合だけオンにしてください（後から変更できます）。';

  @override
  String get whLocationsOn => '棚管理';

  @override
  String get adjTitle => '在庫調整';

  @override
  String get adjNew => '在庫を調整';

  @override
  String get adjEmpty => '調整履歴はまだありません';

  @override
  String get adjEmptyBody => '破損・紛失・発見などの理由を付けて在庫を補正できます。';

  @override
  String get adjJan => 'JANコード';

  @override
  String get adjQuantity => '数量';

  @override
  String get adjReason => '理由';

  @override
  String get adjNote => '備考';

  @override
  String get adjApply => '調整を確定';

  @override
  String adjDone(String delta) {
    return '在庫を調整しました（$delta）';
  }

  @override
  String get adjNeedsWarehouse => '先に倉庫を選んでください';

  @override
  String get adjJanRequired => 'JANコードを入力してください';

  @override
  String get adjDeltaRequired => '1以上の数量を入力してください';

  @override
  String get reasonDamage => '破損';

  @override
  String get reasonLoss => '紛失';

  @override
  String get reasonFound => '発見';

  @override
  String get reasonCorrection => '入力訂正';

  @override
  String get reasonReturn => '返品戻し';

  @override
  String get reasonOther => 'その他';

  @override
  String get cntTitle => '棚卸';

  @override
  String get cntEmpty => '棚卸はまだありません';

  @override
  String get cntEmptyBody => '実地棚卸を開始すると、現在の在庫が控えられます。';

  @override
  String get cntStart => '棚卸を開始';

  @override
  String get cntBlind => 'ブラインド棚卸';

  @override
  String get cntBlindHelp => '数え終わるまで理論在庫を表示しません。先入観なく数えられます。';

  @override
  String get cntSystem => '理論';

  @override
  String get cntCounted => '実査';

  @override
  String get cntVariance => '差異';

  @override
  String get cntHidden => '確定まで非表示';

  @override
  String get cntRecord => '実査数を入力';

  @override
  String get cntComplete => '棚卸を確定';

  @override
  String get cntCancel => '棚卸を中止';

  @override
  String get cntCompleteQ => '棚卸を確定しますか？';

  @override
  String get cntCompleteBody => '差異のある行だけ在庫を補正し、棚卸として記録します。';

  @override
  String get cntCancelQ => 'この棚卸を中止しますか？';

  @override
  String get cntCancelBody => '実査した数値は破棄され、在庫は変わりません。';

  @override
  String get cntCancelled => '棚卸を中止しました';

  @override
  String cntProgress(int counted, int total) {
    return '$counted/$total 実査済み';
  }

  @override
  String cntCompleted(int lines, String net) {
    return '棚卸を確定しました（$lines行を補正・純増減 $net）';
  }

  @override
  String cntUncountedWarn(int count) {
    return '未実査 $count 行はそのまま残ります（0とはみなしません）';
  }

  @override
  String get cntStatusCounting => '実査中';

  @override
  String get cntStatusCompleted => '確定済み';

  @override
  String get cntStatusCancelled => '中止';

  @override
  String get pickListsTitle => 'ピッキング';

  @override
  String get pickStart => 'ピッキング開始';

  @override
  String get pickChooseShipment => '出荷を選択';

  @override
  String get pickNoShipments => 'ピッキング対象の出荷がありません';

  @override
  String get pickStatusPicking => 'ピック中';

  @override
  String get pickStatusPicked => 'ピック完了';

  @override
  String get pickStatusCancelled => '中止';

  @override
  String get pickTaskPending => '未ピック';

  @override
  String get pickTaskPicked => '完了';

  @override
  String get pickTaskShort => '不足';

  @override
  String get pickTaskOver => '超過';

  @override
  String get pickPlanned => '予定';

  @override
  String get pickPickedQty => 'ピック数';

  @override
  String get pickVariance => '差異';

  @override
  String get pickBin => 'ロケーション';

  @override
  String get pickBinNone => '未指定';

  @override
  String get pickRecord => 'ピック数を記録';

  @override
  String get pickComplete => 'ピッキング完了';

  @override
  String get pickCompleteQ => 'ピッキングを完了しますか？';

  @override
  String get pickCompleteBody => '梱包工程に進みます。出荷はこのあと別に確定します。';

  @override
  String get pickCancelAction => 'ピッキングを中止';

  @override
  String get pickCancelQ => 'このピッキングを中止しますか？';

  @override
  String get pickCancelBody => '記録した数量は破棄されます。在庫は変わりません。';

  @override
  String get pickCancelled => 'ピッキングを中止しました';

  @override
  String pickCompleted(int short, int over) {
    return 'ピッキングを完了しました（$short件不足・$over件超過）';
  }

  @override
  String get pickCompleteBlocked => '未ピックの明細があるため完了できません';

  @override
  String get transferTitle => '倉庫間移動';

  @override
  String get transferNew => '移動を作成';

  @override
  String get transferEmpty => '移動はまだありません';

  @override
  String get transferEmptyBody => '倉庫間で在庫を移動すると、ここに表示されます。';

  @override
  String get transferSource => '移動元';

  @override
  String get transferDestination => '移動先';

  @override
  String get transferNeedsTwoWarehouses => '倉庫が2つ以上必要です';

  @override
  String get transferLinesTitle => '移動する商品';

  @override
  String get transferAddLine => '商品を追加';

  @override
  String get transferLineJan => 'JANコード';

  @override
  String get transferLineQuantity => '数量';

  @override
  String get transferLineRequired => '1件以上の商品を追加してください';

  @override
  String get transferNote => '備考';

  @override
  String get transferCreate => '移動を作成';

  @override
  String transferCreated(String number) {
    return '移動 $number を作成しました';
  }

  @override
  String get transferStatusDraft => '下書き';

  @override
  String get transferStatusPendingApproval => '承認待ち';

  @override
  String get transferStatusApproved => '承認済み';

  @override
  String get transferStatusPicking => 'ピック中';

  @override
  String get transferStatusInTransit => '輸送中';

  @override
  String get transferStatusReceiving => '受入中';

  @override
  String get transferStatusCompleted => '完了';

  @override
  String get transferStatusRejected => '却下';

  @override
  String get transferStatusCancelled => '中止';

  @override
  String get transferSubmit => '承認を申請';

  @override
  String get transferSubmitted => '承認を申請しました';

  @override
  String get transferApprove => '承認する';

  @override
  String get transferApproveQ => 'この移動を承認しますか？';

  @override
  String get transferApproved => '移動を承認しました';

  @override
  String get transferReject => '却下する';

  @override
  String get transferRejectQ => 'この移動を却下しますか？';

  @override
  String get transferRejected => '移動を却下しました';

  @override
  String get transferCancelAction => '移動を中止';

  @override
  String get transferCancelBody => '在庫はまだ動いていないため、中止しても在庫は変わりません。';

  @override
  String get transferCancelled => '移動を中止しました';

  @override
  String get transferStartPicking => 'ピッキング開始';

  @override
  String get transferPickQty => 'ピック数';

  @override
  String transferPickProgress(int picked, int total) {
    return '$picked / $total ピック済み';
  }

  @override
  String get transferCompletePicking => '出庫を確定';

  @override
  String transferCompletePickingBody(String source) {
    return '$source の在庫からピック数を引き、輸送中に切り替えます。';
  }

  @override
  String get transferPickIncomplete => '未ピックの明細があるため出庫を確定できません';

  @override
  String get transferStartReceiving => '受入を開始';

  @override
  String get transferReceiveQty => '受入数';

  @override
  String transferReceiveProgress(int received, int total) {
    return '$received / $total 受入済み';
  }

  @override
  String get transferCompleteReceiving => '受入を確定';

  @override
  String transferCompleteReceivingBody(String destination) {
    return '$destination に受入数を加算し、移動を完了します。';
  }

  @override
  String get transferReceiveIncomplete => '未受入の明細があるため受入を確定できません';

  @override
  String transferCompleted(int loss) {
    return '移動が完了しました（$loss件で数量差異）';
  }

  @override
  String get transferPlanned => '予定';

  @override
  String get transferLineProductName => '商品名（任意）';

  @override
  String get featTransfer => '倉庫間移動';

  @override
  String get featTransferDesc => '倉庫間で在庫を移動';

  @override
  String get auditTitle => '監査ログ';

  @override
  String get auditEmpty => '監査ログはまだありません';

  @override
  String get auditEmptyBody => '承認・却下・取消などの操作がここに記録されます。';

  @override
  String get auditExport => 'CSVを書き出す';

  @override
  String get auditExported => 'CSVを保存しました';

  @override
  String get auditExportFailed => 'CSVの書き出しに失敗しました';

  @override
  String get auditEntity => '対象';

  @override
  String get auditActor => '実行者';

  @override
  String get auditActorSystem => 'システム';

  @override
  String get csvExportTitle => 'CSVエクスポート';

  @override
  String get featAuditLog => '監査ログ';

  @override
  String get featAuditLogDesc => '操作履歴をCSVで確認';

  @override
  String get featUserManagement => 'ユーザー管理';

  @override
  String get featUserManagementDesc => 'サインイン済みのメンバーに権限ロールを割り当て';

  @override
  String get featConnectors => 'コネクタ';

  @override
  String get featConnectorsDesc => '将来の外部連携のために登録された外部システム';

  @override
  String get featAiReview => 'AIレビュー';

  @override
  String get featAiReviewDesc => 'AIの抽出結果を反映前に承認・却下';

  @override
  String get dashTodayTasks => '今日の作業';

  @override
  String get taskPackingWait => '梱包待ち';

  @override
  String get taskShippingWait => '出荷待ち';

  @override
  String get searchTitle => '検索';

  @override
  String get searchHint => 'JAN・伝票番号・取引先名で検索';

  @override
  String get searchNoQuery => '入荷・出荷・移動の番号や商品名で横断検索できます。';

  @override
  String get searchEmpty => '一致する結果がありません';

  @override
  String get searchEmptyBody => '別のキーワードでお試しください。';

  @override
  String get searchKindStock => '商品';

  @override
  String get searchKindDelivery => '入荷予定';

  @override
  String get searchKindShipment => '出荷';

  @override
  String get searchKindPickList => 'ピッキング';

  @override
  String get searchKindTransfer => '倉庫間移動';

  @override
  String get userMgmtTitle => 'ユーザー管理';

  @override
  String get userMgmtEmpty => 'ユーザーがまだいません';

  @override
  String get userMgmtEmptyBody => 'メンバーが初めてサインインすると、ここに表示されます。';

  @override
  String get userMgmtAddRole => 'ロールを追加';

  @override
  String get userMgmtNoRoles => 'ロール未割り当て';

  @override
  String get userMgmtAllRolesHeld => 'このユーザーはすべてのロールを持っています。';

  @override
  String get userMgmtRemoveRoleTitle => 'ロールを削除しますか？';

  @override
  String userMgmtRemoveRoleBody(String role, String name) {
    return '$name から $role を削除しますか？';
  }

  @override
  String get userMgmtRemoveRoleAction => '削除';

  @override
  String get userMgmtWarehousesLabel => '倉庫アクセス';

  @override
  String get userMgmtAddWarehouse => '倉庫を追加';

  @override
  String get userMgmtNoWarehouses =>
      '倉庫が割り当てられていません（管理者は全倉庫、それ以外はどの倉庫にもアクセスできません）';

  @override
  String get userMgmtAllWarehousesHeld => 'このユーザーはすべての倉庫にアクセスできます。';

  @override
  String get userMgmtRemoveWarehouseTitle => '倉庫アクセスを削除しますか？';

  @override
  String userMgmtRemoveWarehouseBody(String warehouse, String name) {
    return '$name から $warehouse を削除しますか？';
  }

  @override
  String get userMgmtRemoveWarehouseAction => '削除';

  @override
  String get connectorsTitle => 'コネクタ';

  @override
  String get connectorsEmpty => '登録されたコネクタがありません';

  @override
  String get connectorsEmptyBody => '登録された外部システムがここに表示されます。';

  @override
  String get connectorNoAdapterYet => 'まだ連携処理は実装されていません。この登録だけでは同期は行われません。';

  @override
  String get connectorEnabled => '有効';

  @override
  String get connectorDisabled => '無効';

  @override
  String get connectorNeverRun => '実行履歴なし';

  @override
  String get aiReviewTitle => 'AIレビュー';

  @override
  String get aiReviewEmpty => 'レビュー待ちはありません';

  @override
  String get aiReviewEmptyBody => 'AIが抽出した結果は、承認または却下されるまでここに表示されます。';

  @override
  String aiReviewLinesCount(int count) {
    return '$count 件の明細を抽出';
  }

  @override
  String get aiReviewConfirm => '承認';

  @override
  String get aiReviewReject => '却下';

  @override
  String get aiReviewRejectTitle => 'この結果を却下しますか？';

  @override
  String get aiReviewRejectHint => '理由（任意）';

  @override
  String get aiReviewConfirmed => '承認しました';

  @override
  String get aiReviewRejected => '却下しました';
}
