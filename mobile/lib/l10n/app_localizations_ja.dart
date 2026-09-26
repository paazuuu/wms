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
  String get errorPermissionDenied => 'この操作を行う権限がありません。';

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
  String get receiptEmpty => '明細がありません';

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
  String get importLinesEmpty => '明細はまだありません。「行を追加」から入力できます。';

  @override
  String get importAddLine => '行を追加';

  @override
  String get importEditLine => '明細を編集';

  @override
  String get importLineJan => 'JANコード';

  @override
  String get importLineProduct => '商品名';

  @override
  String get importLineQuantity => '数量';

  @override
  String get importSplitLine => '行を分割';

  @override
  String get importMergeDuplicates => '同じJANをまとめる';

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
  String get cartonStatusOpen => '梱包中';

  @override
  String get cartonStatusPacked => '梱包済み';

  @override
  String get cartonStatusShipped => '出庫済み';

  @override
  String get cartonStatusCancelled => '取消';

  @override
  String get cartonMeasurementsAction => 'サイズ・重量を編集';

  @override
  String get cartonMeasurementsSection => 'サイズ・重量';

  @override
  String get cartonTypeHint => '種類（任意）例: 60サイズ';

  @override
  String get cartonLength => '長さ';

  @override
  String get cartonWidth => '幅';

  @override
  String get cartonHeight => '高さ';

  @override
  String cartonDimensionsCm(String length, String width, String height) {
    return '$length × $width × $height cm';
  }

  @override
  String get cartonClose => '箱を閉じる';

  @override
  String get cartonCloseEmptyHint => '空の箱は閉じられません';

  @override
  String get cartonClosed => '箱を閉じました';

  @override
  String get cartonReopen => '箱を開け直す';

  @override
  String get cartonReopened => '箱を開け直しました';

  @override
  String get cartonMustReopenToEdit => '編集するには箱を開け直してください';

  @override
  String get cartonAddParcel => '追加';

  @override
  String get cartonPackQuantity => '梱包数';

  @override
  String cartonUnpackedCount(int qty) {
    return '残り $qty';
  }

  @override
  String get cartonLineDone => '梱包完了';

  @override
  String get cartonRenameAction => '名前を変更';

  @override
  String get cartonRenameTitle => '段ボールの名前';

  @override
  String get cartonSerialNumber => 'シリアル番号';

  @override
  String get cartonContentsSection => 'この箱の中身';

  @override
  String get cartonContentsEmpty => 'まだ何も入っていません';

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
  String get noRoleAssigned => '権限がまだ割り当てられていません';

  @override
  String get noRoleAssignedBody =>
      'サインインはできていますが、まだ役割（ロール）が割り当てられていないため、使える機能がありません。管理者に権限の割り当てを依頼してください。';

  @override
  String get whNoAssignedWarehouse => '倉庫が割り当てられていません';

  @override
  String get whNoAssignedWarehouseBody =>
      'あなたのアカウントはまだどの倉庫にも割り当てられていないため、在庫の閲覧や作業ができません。管理者に倉庫の割り当てを依頼してください。';

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
  String get qcAttachmentsEmpty => '写真はまだありません';

  @override
  String get qcAttachmentCamera => 'カメラで撮影';

  @override
  String get qcAttachmentGallery => 'ギャラリーから選択';

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
  String get adjConfirmQ => '在庫を調整しますか？';

  @override
  String get adjConfirmIrreversible => 'この操作は取り消せません。';

  @override
  String get adjConfirmAction => '調整する';

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
  String get reasonInternalUse => '社内消費';

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
  String get pickItemNoLot => 'ロット未記録';

  @override
  String get pickItemRemove => 'この記録を取り消す';

  @override
  String pickItemUnattributed(int qty) {
    return '未記録 $qty';
  }

  @override
  String get pickLotCode => 'ロット番号';

  @override
  String get pickLotCodeHint => '任意';

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
  String get featProducts => '商品マスタ';

  @override
  String get featProductsDesc => 'JANコードに紐づく商品名・カテゴリ・価格を管理';

  @override
  String get featUnlinkedJan => '未紐付けJANコード';

  @override
  String get featUnlinkedJanDesc => '商品が登録されていないJANコードの一覧';

  @override
  String get unlinkedJanTitle => '未紐付けJANコード';

  @override
  String unlinkedJanCoverage(int linked, int rows) {
    return '$linked / $rows 件が紐付け済み';
  }

  @override
  String get unlinkedJanReady => 'すべて商品に紐付いています';

  @override
  String get unlinkedJanEmpty => '未紐付けのJANコードはありません';

  @override
  String get unlinkedJanEmptyBody => '在庫・入荷・出荷などの記録は、すべて商品マスタに紐付いています。';

  @override
  String unlinkedJanRows(int qty) {
    return '$qty 件';
  }

  @override
  String get unlinkedJanSeenAsUnknown => '名称不明';

  @override
  String get featPurchaseOrders => '発注';

  @override
  String get featPurchaseOrdersDesc => '仕入先への発注を作成・承認・管理';

  @override
  String get featSalesOrders => '受注';

  @override
  String get featSalesOrdersDesc => '顧客からの受注を作成・承認・管理';

  @override
  String get featPartners => '取引先';

  @override
  String get featPartnersDesc => '仕入先・顧客の連絡先や取引条件を管理';

  @override
  String get featWorkOrders => '作業指示';

  @override
  String get featWorkOrdersDesc => '部材を消費して完成品を作るキッティング・組立作業';

  @override
  String get featReports => 'レポート作成';

  @override
  String get featReportsDesc => 'データを選んで絞り込み、レポートとして保存';

  @override
  String get reportTitle => 'レポート作成';

  @override
  String get reportSource => 'データソース';

  @override
  String get reportSourceStockMovements => '在庫履歴';

  @override
  String get reportSourceInspections => '検品';

  @override
  String get reportSourceTransfers => '倉庫間移動';

  @override
  String get reportSourceShipments => '出庫';

  @override
  String get reportSourcePurchaseOrders => '発注';

  @override
  String get reportSourceSalesOrders => '受注';

  @override
  String get reportSourceWorkOrders => '作業指示';

  @override
  String get reportSourceAuditLog => '監査ログ';

  @override
  String get reportSourceProducts => '商品マスタ';

  @override
  String get reportWarehouse => '倉庫';

  @override
  String get reportAllWarehouses => 'すべての倉庫';

  @override
  String get reportFilterStatus => 'ステータス（任意）';

  @override
  String get reportFilterJan => 'JANコード（任意）';

  @override
  String get reportFilterCategory => 'カテゴリ（任意）';

  @override
  String get reportDateFrom => '開始日';

  @override
  String get reportDateTo => '終了日';

  @override
  String get reportRun => '実行';

  @override
  String get reportSave => '保存';

  @override
  String get reportSaveTitle => 'レポートを保存';

  @override
  String get reportName => 'レポート名';

  @override
  String get reportSaved => 'レポートを保存しました';

  @override
  String get reportEmpty => '該当するデータがありません';

  @override
  String reportRowCount(int count) {
    return '$count 件';
  }

  @override
  String get reportSavedTitle => '保存済みレポート';

  @override
  String get reportSavedEmpty => '保存済みのレポートはまだありません';

  @override
  String get woTitle => '作業指示';

  @override
  String get woNew => '作業指示を作成';

  @override
  String get woEmpty => '作業指示がまだありません';

  @override
  String get woEmptyBody => '右下のボタンから作業指示を作成できます。';

  @override
  String get woNeedsWarehouse => '倉庫がありません';

  @override
  String get woWarehouse => '作業倉庫';

  @override
  String get woOutputTitle => '完成品';

  @override
  String get woOutputQuantity => '完成数量';

  @override
  String get woOutputRequired => '完成品のJANコードと数量を入力してください';

  @override
  String get woComponentsTitle => '部材';

  @override
  String get woAddComponent => '部材を追加';

  @override
  String get woComponentRequired => '部材を1件以上追加してください';

  @override
  String get woComponentQuantity => '必要数量';

  @override
  String woComponentCount(int count) {
    return '$count 部材';
  }

  @override
  String get woNote => '備考';

  @override
  String get woCreate => '作成';

  @override
  String get woLineJan => 'JANコード';

  @override
  String get woLineProductName => '商品名';

  @override
  String get woStart => '作業開始';

  @override
  String get woStarted => '作業を開始しました';

  @override
  String get woComplete => '完了にする';

  @override
  String get woCompleteQ => 'この作業指示を完了にしますか？部材の在庫が消費され、完成品の在庫が増加します。';

  @override
  String get woCompleted => '作業指示を完了しました';

  @override
  String get woCancelAction => '作業指示を取消';

  @override
  String get woCancelBody => 'この作業指示を取り消しますか？';

  @override
  String get woCancelled => '作業指示を取り消しました';

  @override
  String get woStatusDraft => '下書き';

  @override
  String get woStatusInProgress => '作業中';

  @override
  String get woStatusCompleted => '完了';

  @override
  String get woStatusCancelled => '取消';

  @override
  String get partnersTitle => '取引先';

  @override
  String get partnersSearchHint => '取引先名またはコードで検索';

  @override
  String get partnersEmpty => '取引先がまだありません';

  @override
  String get partnersEmptyBody => '右下の＋から取引先を登録できます。';

  @override
  String get partnerKindAll => 'すべて';

  @override
  String get partnerKindSupplier => '仕入先';

  @override
  String get partnerKindCustomer => '顧客';

  @override
  String get partnerKindBoth => '仕入先/顧客';

  @override
  String get partnerNewTitle => '取引先を登録';

  @override
  String get partnerEditTitle => '取引先を編集';

  @override
  String get partnerName => '取引先名';

  @override
  String get partnerCode => 'コード';

  @override
  String get partnerContactName => '担当者名';

  @override
  String get partnerPhone => '電話番号';

  @override
  String get partnerEmail => 'メールアドレス';

  @override
  String get partnerAddress => '住所';

  @override
  String get partnerPaymentTerms => '取引条件';

  @override
  String get partnerNotes => '備考';

  @override
  String get partnerSave => '保存';

  @override
  String get partnerValidationRequired => '取引先名を入力してください';

  @override
  String get soTitle => '受注';

  @override
  String get soNew => '受注を作成';

  @override
  String get soEmpty => '受注がまだありません';

  @override
  String get soEmptyBody => '右下のボタンから受注を作成できます。';

  @override
  String get soNeedsWarehouse => '倉庫がありません';

  @override
  String get soCustomerName => '顧客名';

  @override
  String get soWarehouse => '出庫倉庫';

  @override
  String get soRequestedShipDate => '出荷希望日';

  @override
  String get soLinesTitle => '明細';

  @override
  String get soAddLine => '明細を追加';

  @override
  String get soNote => '備考';

  @override
  String get soCustomerRequired => '顧客名を入力してください';

  @override
  String get soLineRequired => '明細を1件以上追加してください';

  @override
  String get soCreate => '作成';

  @override
  String get soLineJan => 'JANコード';

  @override
  String get soLineProductName => '商品名';

  @override
  String get soLineQuantity => '数量';

  @override
  String get soLineUnitPrice => '単価';

  @override
  String get soTotalAmount => '金額';

  @override
  String get soSubmit => '提出';

  @override
  String get soSubmitted => '受注を提出しました';

  @override
  String get soApprove => '承認';

  @override
  String get soApproveQ => 'この受注を承認しますか？';

  @override
  String get soApproved => '受注を承認しました';

  @override
  String get soReject => '却下';

  @override
  String get soRejectQ => 'この受注を却下しますか？';

  @override
  String get soRejected => '受注を却下しました';

  @override
  String get soCancelAction => '受注を取消';

  @override
  String get soCancelBody => 'この受注を取り消しますか？';

  @override
  String get soCancelled => '受注を取り消しました';

  @override
  String get soComplete => '完了にする';

  @override
  String get soCompleteQ => 'この受注を完了にしますか？在庫は移動しません。';

  @override
  String get soCompleted => '受注を完了にしました';

  @override
  String get soStatusDraft => '下書き';

  @override
  String get soStatusSubmitted => '提出済み';

  @override
  String get soStatusApproved => '承認済み';

  @override
  String get soStatusRejected => '却下';

  @override
  String get soStatusCancelled => '取消';

  @override
  String get soStatusCompleted => '完了';

  @override
  String get poTitle => '発注';

  @override
  String get poNew => '発注を作成';

  @override
  String get poEmpty => '発注がまだありません';

  @override
  String get poEmptyBody => '右下のボタンから発注を作成できます。';

  @override
  String get poNeedsWarehouse => '倉庫がありません';

  @override
  String get poSupplierName => '仕入先名';

  @override
  String get poWarehouse => '入庫倉庫';

  @override
  String get poExpectedDate => '納期予定';

  @override
  String get poLinesTitle => '明細';

  @override
  String get poAddLine => '明細を追加';

  @override
  String get poNote => '備考';

  @override
  String get poSupplierRequired => '仕入先名を入力してください';

  @override
  String get poLineRequired => '明細を1件以上追加してください';

  @override
  String get poCreate => '作成';

  @override
  String get poLineJan => 'JANコード';

  @override
  String get poLineProductName => '商品名';

  @override
  String get poLineQuantity => '数量';

  @override
  String get poLineUnitPrice => '単価';

  @override
  String get poTotalAmount => '金額';

  @override
  String get poSubmit => '提出';

  @override
  String get poSubmitted => '発注を提出しました';

  @override
  String get poApprove => '承認';

  @override
  String get poApproveQ => 'この発注を承認しますか？';

  @override
  String get poApproved => '発注を承認しました';

  @override
  String get poReject => '却下';

  @override
  String get poRejectQ => 'この発注を却下しますか？';

  @override
  String get poRejected => '発注を却下しました';

  @override
  String get poCancelAction => '発注を取消';

  @override
  String get poCancelBody => 'この発注を取り消しますか？';

  @override
  String get poCancelled => '発注を取り消しました';

  @override
  String get poComplete => '完了にする';

  @override
  String get poCompleteQ => 'この発注を完了にしますか？在庫は移動しません。';

  @override
  String get poCompleted => '発注を完了にしました';

  @override
  String get poCreateDeliveryPlan => '入荷予定を作成';

  @override
  String get poCreateDeliveryPlanQ => 'この発注から入荷予定を作成しますか？';

  @override
  String poDeliveryPlanCreated(int lines) {
    return '入荷予定を作成しました（明細 $lines 件）';
  }

  @override
  String get poOpenDeliveryPlan => '入荷予定を開く';

  @override
  String get poStatusDraft => '下書き';

  @override
  String get poStatusSubmitted => '提出済み';

  @override
  String get poStatusApproved => '承認済み';

  @override
  String get poStatusRejected => '却下';

  @override
  String get poStatusCancelled => '取消';

  @override
  String get poStatusCompleted => '完了';

  @override
  String get productsTitle => '商品マスタ';

  @override
  String get productsShowInactive => '無効な商品も表示';

  @override
  String get productsSearchHint => '商品名またはJANコードで検索';

  @override
  String get productsEmpty => '商品がまだありません';

  @override
  String get productsEmptyBody => '右下の＋から商品を登録できます。';

  @override
  String get productActive => '有効';

  @override
  String get productInactive => '無効';

  @override
  String get productDeactivateQ => 'この商品を無効にしますか？';

  @override
  String get productDeactivateBody => '無効にすると、入荷・出荷などの操作でこの商品を選べなくなります。';

  @override
  String get productDeactivateAction => '無効にする';

  @override
  String get productNewTitle => '商品を登録';

  @override
  String get productEditTitle => '商品を編集';

  @override
  String get productJanCode => 'JANコード';

  @override
  String get productName => '商品名';

  @override
  String get productCategory => 'カテゴリ';

  @override
  String get productPrice => '価格';

  @override
  String get productSave => '保存';

  @override
  String get productValidationRequired => 'JANコードと商品名を入力してください';

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
  String aiReviewConfidence(String percent) {
    return '信頼度 $percent%';
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

  @override
  String get featPutaway => '棚入れ';

  @override
  String get featPutawayDesc => '入荷済みの在庫をロケーションに割り当てる';

  @override
  String get nextStepPutaway => '棚入れへ';

  @override
  String get nextStepPacking => '梱包へ';

  @override
  String get nextStepInspection => '検品へ';

  @override
  String get putawayTitle => '棚入れ';

  @override
  String get putawayNeedsWarehouse => '倉庫を選択してください';

  @override
  String get putawayNeedsWarehouseBody =>
      '棚入れは1つの倉庫の中で行う作業です。上部の倉庫切替から対象倉庫を選んでください。';

  @override
  String get putawayLocationsOff => 'この倉庫はロケーション管理なし';

  @override
  String get putawayLocationsOffBody =>
      'ロケーション（棚）を使わない倉庫では棚入れ作業はありません。倉庫設定でロケーション管理を有効にすると、この一覧に作業が表示されます。';

  @override
  String get putawayEmpty => '棚入れ待ちはありません';

  @override
  String get putawayEmptyBody => '入荷した在庫はすべてロケーションに割り当て済みです。';

  @override
  String putawayPendingCount(int count) {
    return '$count 品目';
  }

  @override
  String get putawayQueueHint => '入荷済みでロケーション未割り当ての在庫です。タップして棚をスキャンしてください。';

  @override
  String get putawayPendingLabel => '棚入れ待ち';

  @override
  String get putawayNoSuggestion => '推奨ロケーションなし';

  @override
  String putawaySuggested(String code) {
    return '推奨: $code';
  }

  @override
  String get putawayScanLocation => 'ロケーションをスキャン';

  @override
  String get putawayScanLocationHint => '棚のバーコードをスキャン';

  @override
  String putawayBinNotFound(String code) {
    return 'この倉庫に「$code」というロケーションはありません';
  }

  @override
  String putawayBinInactive(String code) {
    return '$code は使用停止中のロケーションです';
  }

  @override
  String get putawayBinCurrent => '現在の在庫';

  @override
  String get putawayBinEmpty => '空です';

  @override
  String get putawayThisTime => '今回入れる数量';

  @override
  String putawayOfPending(int pending) {
    return '/ 残 $pending';
  }

  @override
  String get putawayQuantityRequired => '数量を1以上で入力してください';

  @override
  String putawayQuantityTooLarge(int max) {
    return '棚入れ待ちは $max までです';
  }

  @override
  String get putawayConfirm => '棚入れを確定';

  @override
  String putawayConfirmed(int quantity, String bin, int pendingAfter) {
    return '$bin に $quantity 入れました（残 $pendingAfter）';
  }

  @override
  String get actionOk => 'OK';

  @override
  String scanWrongItem(String expected) {
    return '別の商品です（対象: $expected）';
  }

  @override
  String scanExpecting(String expected) {
    return '対象: $expected を枠内に合わせてください';
  }

  @override
  String get scanNothingYet => 'まだ読み取りがありません';

  @override
  String scanAcceptedCount(int count) {
    return '$count 件読み取り';
  }

  @override
  String get scanResultOk => 'OK';

  @override
  String get scanResultDuplicate => '重複（無視しました）';

  @override
  String get scanResultNg => 'NG';

  @override
  String get scanManualEntry => '手動入力';

  @override
  String get scanManualEntryHint => 'JAN / バーコード';

  @override
  String get scanDone => '完了';

  @override
  String get pickScanToConfirm => '数量を確定するには対象のJANをスキャンしてください';

  @override
  String get pickScanned => 'スキャン確認済み';

  @override
  String get pickScanAction => 'スキャン';

  @override
  String get taskInboundPlanned => '入荷予定';

  @override
  String get actionEdit => '編集';

  @override
  String get autopackAction => '箱数を自動計算';

  @override
  String autopackTotal(int total) {
    return '総数量 $total';
  }

  @override
  String get autopackPerCarton => '1箱あたりの数量';

  @override
  String get autopackHint => '1箱に入る数量を入力すると、必要な箱数を計算します。';

  @override
  String autopackBoxes(int boxes) {
    return '箱数 $boxes';
  }

  @override
  String autopackEven(int per) {
    return '全箱 $per 個';
  }

  @override
  String autopackSplit(int full, int per, int last) {
    return '$full 箱 × $per 個 ＋ 最終箱 $last 個';
  }

  @override
  String get autopackConfirm => 'この箱数で作成';

  @override
  String autopackDone(int boxes, int per) {
    return '$boxes 箱を作成しました（1箱 $per 個）';
  }

  @override
  String get printCartonLabels => '箱ラベルを印刷（全箱）';

  @override
  String get printThisLabel => '箱ラベル';

  @override
  String get shipmentParcelsAction => '出荷ロット履歴';

  @override
  String get shipmentParcelsTitle => '出荷ロット履歴';

  @override
  String get shipmentParcelsEmpty => 'まだ出荷されていません';

  @override
  String get shipmentParcelsEmptyBody => '出荷を確定すると、実際に出たロット・シリアルがここに表示されます。';

  @override
  String get shipmentParcelReversalTag => '取消分';

  @override
  String get shipLogisticsSection => '配送情報';

  @override
  String get shipLogisticsUnset => '未入力';

  @override
  String get shipWeight => '重量';

  @override
  String shipWeightKg(double kg) {
    final intl.NumberFormat kgNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String kgString = kgNumberFormat.format(kg);

    return '$kgString kg';
  }

  @override
  String get shipWeightInvalid => '重量は0以上の数値で入力してください';

  @override
  String get shipCarrier => '配送会社';

  @override
  String get shipTracking => '送り状番号';

  @override
  String get auditEventAiAnalysisCompleted => 'AI解析完了';

  @override
  String get auditEventAiConfirmed => 'AI結果を承認';

  @override
  String get auditEventAiRejected => 'AI結果を却下';

  @override
  String get auditEventAttachmentUploaded => '写真を添付';

  @override
  String get auditEventCountCancelled => '棚卸を中止';

  @override
  String get auditEventCountCompleted => '棚卸を確定';

  @override
  String get auditEventCountStarted => '棚卸を開始';

  @override
  String get auditEventInspectionConfirmed => '検品確定';

  @override
  String get auditEventInspectionStarted => '検品開始';

  @override
  String get auditEventInventoryAdjusted => '在庫調整';

  @override
  String get auditEventPartnerCreated => '取引先を登録';

  @override
  String get auditEventPartnerUpdated => '取引先を更新';

  @override
  String get auditEventPickListCancelled => 'ピッキング中止';

  @override
  String get auditEventPickListCompleted => 'ピッキング完了';

  @override
  String get auditEventPickListStarted => 'ピッキング開始';

  @override
  String get auditEventProductCreated => '商品を登録';

  @override
  String get auditEventProductUpdated => '商品を更新';

  @override
  String get auditEventPurchaseOrderApproved => '発注を承認';

  @override
  String get auditEventPurchaseOrderCancelled => '発注をキャンセル';

  @override
  String get auditEventPurchaseOrderCompleted => '発注を完了';

  @override
  String get auditEventPurchaseOrderCreated => '発注を作成';

  @override
  String get auditEventPurchaseOrderRejected => '発注を却下';

  @override
  String get auditEventPurchaseOrderSubmitted => '発注を申請';

  @override
  String get auditEventPutawayConfirmed => '棚入れ確定';

  @override
  String get auditEventReceivingCancelled => '入荷取消';

  @override
  String get auditEventReceivingConfirmed => '入荷確定';

  @override
  String get auditEventReportDeleted => 'レポートを削除';

  @override
  String get auditEventReportSaved => 'レポートを保存';

  @override
  String get auditEventSalesOrderApproved => '受注を承認';

  @override
  String get auditEventSalesOrderCancelled => '受注をキャンセル';

  @override
  String get auditEventSalesOrderCompleted => '受注を完了';

  @override
  String get auditEventSalesOrderCreated => '受注を作成';

  @override
  String get auditEventSalesOrderRejected => '受注を却下';

  @override
  String get auditEventSalesOrderSubmitted => '受注を申請';

  @override
  String get auditEventShipmentAutopacked => '箱を自動作成';

  @override
  String get auditEventShipmentCancelled => '出荷を取消';

  @override
  String get auditEventShipmentCompleted => '出荷確定';

  @override
  String get auditEventShipmentLogisticsSet => '配送情報を設定';

  @override
  String get auditEventTransferApproved => '倉庫間移動を承認';

  @override
  String get auditEventTransferCancelled => '倉庫間移動を中止';

  @override
  String get auditEventTransferCreated => '倉庫間移動を作成';

  @override
  String get auditEventTransferPickingStarted => '移動ピッキング開始';

  @override
  String get auditEventTransferReceived => '倉庫間移動を受領';

  @override
  String get auditEventTransferReceivingStarted => '移動受入開始';

  @override
  String get auditEventTransferRejected => '倉庫間移動を却下';

  @override
  String get auditEventTransferShipped => '倉庫間移動を出庫';

  @override
  String get auditEventTransferSubmitted => '倉庫間移動を申請';

  @override
  String get auditEventUserRoleAssigned => 'ロールを付与';

  @override
  String get auditEventUserRoleRevoked => 'ロールを削除';

  @override
  String get auditEventUserWarehouseAssigned => '倉庫アクセスを付与';

  @override
  String get auditEventUserWarehouseRevoked => '倉庫アクセスを削除';

  @override
  String get auditEventWorkOrderCancelled => '作業指示を中止';

  @override
  String get auditEventWorkOrderCompleted => '作業指示を完了';

  @override
  String get auditEventWorkOrderCreated => '作業指示を作成';

  @override
  String get auditEventWorkOrderStarted => '作業指示を開始';

  @override
  String get dashNotificationsTitle => '通知';

  @override
  String get dashNotificationsEmpty => '対応が必要な通知はありません';

  @override
  String notifCount(int count) {
    return '$count 件';
  }

  @override
  String get notifFailedInspection => '検品NG';

  @override
  String get notifOutstandingPlans => '入荷待ち';

  @override
  String get notifPutawayPending => '棚入れ待ち';

  @override
  String get notifOpenPicking => 'ピック待ち';

  @override
  String get sidebarCollapse => 'メニューを折りたたむ';

  @override
  String get sidebarExpand => 'メニューを展開';

  @override
  String get menuFilter => 'メニューを絞り込む';

  @override
  String get menuFilterNoMatch => '該当する項目がありません';

  @override
  String get unknownLocation => 'この画面は見つかりませんでした。メニューから選び直してください。';

  @override
  String get close => '閉じる';

  @override
  String get shortcutsTitle => 'キーボードショートカット';

  @override
  String get shortcutsHelp => 'キーボードショートカットを表示';

  @override
  String get shortcutFocusScan => 'スキャン欄にカーソルを移動';

  @override
  String get shortcutToggleSidebar => 'メニューの折りたたみを切り替え';

  @override
  String get shortcutGlobalSearch => '横断検索を開く';

  @override
  String get shortcutSwitchTab => 'N番目のタブに切り替え';

  @override
  String get shortcutShowHelp => 'この一覧を表示';

  @override
  String get productSku => 'SKU';

  @override
  String get productSkuHint => '社内品番（任意）';

  @override
  String get productTracking => '追跡区分';

  @override
  String get trackUntracked => '追跡なし';

  @override
  String get trackLot => 'ロット';

  @override
  String get trackSerial => 'シリアル';

  @override
  String get trackLotAndSerial => 'ロット＋シリアル';

  @override
  String get trackExpiry => '有効期限';

  @override
  String get productBaseUnit => '基本単位';

  @override
  String get productRequiresInspection => '入荷検品を必須にする';

  @override
  String get productRequiresInspectionHint =>
      'オンにすると、入荷時にこの商品は検品待ち（QC_PENDING）として保留され、検品完了までピッキング・出荷できません。';

  @override
  String get productPickingRule => 'ピッキング順序';

  @override
  String get productPickingRuleHint => '在庫からどの順で取るかの初期設定です。倉庫ごとの上書きは別途設定できます。';

  @override
  String get pickRuleFifo => '先入先出（FIFO）';

  @override
  String get pickRuleFefo => '期限が近い順（FEFO）';

  @override
  String get pickRuleLifo => '後入先出（LIFO）';

  @override
  String get pickRuleManual => '都度選択（MANUAL）';

  @override
  String productCodeCount(int count) {
    return 'コード $count 件';
  }

  @override
  String productPackUnit(String code, String factor, String base) {
    return '$code = $factor$base';
  }

  @override
  String productScanAlreadyUsed(String name) {
    return 'このコードは「$name」に登録済みです';
  }

  @override
  String get stockPositionTitle => '在庫内訳';

  @override
  String get stockAvailable => '引当可能';

  @override
  String get stockReserved => '予約済み';

  @override
  String get stockAllocated => '引当済み';

  @override
  String get stockUnavailable => '出荷不可';

  @override
  String get stockOverPromised => '予約が引当可能数を超えています';

  @override
  String get stockNotLinkedToProduct => 'このJANは商品マスタに未登録です';

  @override
  String stockPositionLot(String code) {
    return 'ロット $code';
  }

  @override
  String get stockPositionNoParcels => '内訳はまだありません';

  @override
  String get productDetailTitle => '商品詳細';

  @override
  String get productEdit => '編集';

  @override
  String get productBarcodesSection => 'バーコード';

  @override
  String get productBarcodeAdd => 'コードを追加';

  @override
  String get productBarcodePrimary => '主コード';

  @override
  String get productBarcodeType => '種別';

  @override
  String get productBarcodeUnit => '単位（任意）';

  @override
  String productBarcodeQtyPerScan(String qty) {
    return '1スキャン = $qty';
  }

  @override
  String get productBarcodeRemoveQ => 'このコードを削除しますか？';

  @override
  String get productBarcodeRemoveBody => 'このコードではスキャンできなくなります。商品自体は残ります。';

  @override
  String get productBarcodeEmpty => 'コードがまだありません';

  @override
  String get productUnitsSection => '単位';

  @override
  String get productUnitAdd => '単位を追加';

  @override
  String get productUnitFactor => '換算数';

  @override
  String get productUnitBase => '基本';

  @override
  String get productUnitRemoveQ => 'この単位を削除しますか？';

  @override
  String get productUnitRemoveBody =>
      'このパック単位は選べなくなります。基本単位、またはバーコードが参照している単位は削除できません。';

  @override
  String get productLotsSection => 'ロット';

  @override
  String get productLotsEmpty => 'ロットの記録はまだありません';

  @override
  String productLotExpiryOn(String date) {
    return '期限 $date';
  }

  @override
  String productLotDaysLeft(int days) {
    return 'あと$days日';
  }

  @override
  String get productLotExpired => '期限切れ';

  @override
  String productLotSerialCount(int count) {
    return 'シリアル $count 件';
  }

  @override
  String get productSerialsSection => 'シリアル';

  @override
  String get productSerialsEmpty => 'シリアルの記録はまだありません';

  @override
  String get productSerialFilterAll => 'すべて';

  @override
  String get serialInStock => '在庫あり';

  @override
  String get serialShipped => '出荷済';

  @override
  String get serialReturned => '返品';

  @override
  String get serialScrapped => '廃棄';

  @override
  String get serialHold => '保留';

  @override
  String get productSerialChangeStatus => 'ステータスを変更';

  @override
  String get productSerialStatus => 'ステータス';

  @override
  String get productSerialNote => 'メモ（任意）';

  @override
  String get whpSection => 'この倉庫での設定';

  @override
  String get whpNone => 'この倉庫には専用の設定がありません';

  @override
  String get whpNoWarehouse => '倉庫を選ぶと設定できます';

  @override
  String get whpEdit => '設定する';

  @override
  String get whpDefaultLocation => '既定ロケーション';

  @override
  String get whpDefaultLocationHint => 'ラックのコード（空欄で解除）';

  @override
  String get whpMinStock => '最小在庫';

  @override
  String get whpReorderPoint => '発注点';

  @override
  String get whpMaxStock => '最大在庫';

  @override
  String get whpPickPriority => 'ピッキング優先度';

  @override
  String get whpPutawayRule => '格納ルール';

  @override
  String get putawayManual => '手動';

  @override
  String get putawayFixed => '固定ロケーション';

  @override
  String get putawayConsolidate => '同じ品にまとめる';

  @override
  String get putawayNearestEmpty => '最も近い空き';

  @override
  String get whpLeadTime => 'リードタイム（日）';

  @override
  String get whpSupplier => '優先仕入先';

  @override
  String get whpClear => 'この倉庫の設定を削除';

  @override
  String get whpClearQ => 'この倉庫の設定を削除しますか？';

  @override
  String get whpClearBody => '既定ロケーションと発注点がなくなり、補充提案にも出なくなります。';

  @override
  String get whpNeedsReorder => '発注点を下回っています';

  @override
  String get featExpiringLots => '期限管理';

  @override
  String get featExpiringLotsDesc => '期限が近い・切れたロットを一覧';

  @override
  String get featReservations => '予約・引当';

  @override
  String get featReservationsDesc => '受注などのために確保した在庫と、その引当先';

  @override
  String get featLocations => 'ロケーション';

  @override
  String get featLocationsDesc => 'ゾーン・通路・ラック・棚の階層と種別';

  @override
  String get featReplenishment => '補充提案';

  @override
  String get featReplenishmentDesc => '発注点を下回った商品と発注数の目安';

  @override
  String get featStockReconciliation => '在庫整合性チェック';

  @override
  String get featStockReconciliationDesc => '在庫水準と実在庫のズレを確認';

  @override
  String get expiryTitle => '期限管理';

  @override
  String expiryHorizon(int days) {
    return '$days日以内';
  }

  @override
  String get expiryEmpty => '期限が近いロットはありません';

  @override
  String get expiryEmptyBody => 'この期間に期限を迎えるロットはありません。期間を広げると先の分も確認できます。';

  @override
  String expiryExpiredCount(int count) {
    return '期限切れ $count 件';
  }

  @override
  String expirySoonCount(int count) {
    return '期限間近 $count 件';
  }

  @override
  String get reservationsTitle => '予約・引当';

  @override
  String get reservationsEmpty => '予約はありません';

  @override
  String get reservationsEmptyBody => '受注や出荷のために確保された在庫がここに並びます。';

  @override
  String get reservationStatusActive => '有効';

  @override
  String get reservationStatusFulfilled => '出荷済';

  @override
  String get reservationStatusReleased => '解放済';

  @override
  String get reservationStatusAll => 'すべて';

  @override
  String get reservationLapsed => '期限切れ';

  @override
  String reservationFor(String type, String id) {
    return '$type $id';
  }

  @override
  String get refSalesOrder => '受注';

  @override
  String get refShipment => '出荷';

  @override
  String get refTransfer => '移動';

  @override
  String get refWorkOrder => '作業指示';

  @override
  String get refManual => '手動';

  @override
  String reservationQuantity(String qty) {
    return '予約 $qty';
  }

  @override
  String reservationAllocated(String qty) {
    return '引当済 $qty';
  }

  @override
  String reservationUnallocated(String qty) {
    return '未引当 $qty';
  }

  @override
  String reservationFulfilled(String qty) {
    return '出荷済 $qty';
  }

  @override
  String get reservationRelease => '解放';

  @override
  String get reservationReleaseQ => 'この予約を解放しますか？';

  @override
  String get reservationReleaseBody => '確保していた在庫が引当可能に戻り、引当先も取り消されます。記録は残ります。';

  @override
  String get reservationFulfil => '出荷済みにする';

  @override
  String get reservationFulfilTitle => '出荷済みとして記録する';

  @override
  String get reservationFulfilBody =>
      '在庫は動かしません。出荷の記録は別にあり、ここでは約束が果たされたことだけを記録します。';

  @override
  String get reservationFulfilQuantity => '数量';

  @override
  String get reservationAllocationsTitle => '引当先';

  @override
  String get reservationNoAllocations => '引当先はまだ決まっていません';

  @override
  String get overAllocatedTitle => '引当超過';

  @override
  String get overAllocatedBody => '在庫が引当より減っています。出荷が先に取ったためで、引当の解放か在庫の補充が必要です。';

  @override
  String overAllocatedRow(String quantity, String allocated, String over) {
    return '在庫 $quantity / 引当 $allocated（超過 $over）';
  }

  @override
  String get stockReconciliationTitle => '在庫整合性チェック';

  @override
  String get stockReconciliationEmpty => 'ズレはありません';

  @override
  String get stockReconciliationEmptyBody => '在庫水準と実在庫は一致しています。';

  @override
  String get stockReconciliationReasonUnlinked => '商品に紐付いていないJAN';

  @override
  String get stockReconciliationReasonDrift => '数量のズレ';

  @override
  String stockReconciliationLevels(int qty) {
    return '在庫水準 $qty';
  }

  @override
  String stockReconciliationUnits(int qty) {
    return '実在庫 $qty';
  }

  @override
  String stockReconciliationDrift(String diff) {
    return '差分 $diff';
  }

  @override
  String get locationsTitle => 'ロケーション';

  @override
  String get locationsEmpty => 'ロケーションがまだありません';

  @override
  String get locationsEmptyBody => 'ゾーンや棚を登録すると、ここに階層として表示されます。';

  @override
  String get locationsNoWarehouse => '倉庫を選ぶと表示できます';

  @override
  String get locationAdd => 'ロケーションを追加';

  @override
  String get locationCode => 'コード';

  @override
  String get locationName => '名称（任意）';

  @override
  String get locationType => '種別';

  @override
  String get locationParent => '親ロケーション（任意）';

  @override
  String get locationBarcode => 'ラベルのバーコード（任意）';

  @override
  String get locationShowInactive => '停止中も表示';

  @override
  String get binStockAction => 'ビン別在庫';

  @override
  String get binStockTitle => 'ビン別在庫';

  @override
  String get binStockEmpty => 'この倉庫にはロケーションがありません';

  @override
  String get binStockBinEmpty => '空';

  @override
  String binStockTotalUnits(int qty) {
    return '計 $qty 点';
  }

  @override
  String get locationPickable => 'ピッキング可';

  @override
  String get locationReceivable => '入荷可';

  @override
  String get locationShipping => '出荷';

  @override
  String get locationQuarantine => '隔離';

  @override
  String get locationVirtual => '仮想';

  @override
  String get locationInactive => '停止中';

  @override
  String locationOnHand(String qty) {
    return '在庫 $qty';
  }

  @override
  String get locTypeStorage => '保管';

  @override
  String get locTypePicking => 'ピッキング';

  @override
  String get locTypeReceiving => '入荷';

  @override
  String get locTypeQc => '検品';

  @override
  String get locTypePacking => '梱包';

  @override
  String get locTypeShipping => '出荷';

  @override
  String get locTypeQuarantine => '隔離';

  @override
  String get locTypeDamaged => '破損';

  @override
  String get locTypeReturn => '返品';

  @override
  String get locTypeTransit => '移動中';

  @override
  String get locTypeVirtual => '仮想';

  @override
  String get replenishmentTitle => '補充提案';

  @override
  String get replenishmentEmpty => '補充が必要な商品はありません';

  @override
  String get replenishmentEmptyBody => '発注点を設定した商品が、いずれも発注点を上回っています。';

  @override
  String replenishmentSuggest(String qty) {
    return '発注目安 $qty';
  }

  @override
  String replenishmentShortfall(String qty) {
    return '発注点まで $qty';
  }

  @override
  String replenishmentBlocked(String qty) {
    return 'うち出荷不可 $qty';
  }

  @override
  String replenishmentLeadTime(int days) {
    return 'リードタイム $days日';
  }

  @override
  String get replenishmentNoWarehouse => '倉庫を選ぶと表示できます';

  @override
  String get exceptionsTitle => '例外・不一致';

  @override
  String get exceptionsEmpty => '未処理の例外はありません';

  @override
  String get exceptionsEmptyBody => '入荷・検品・格納で不一致が出ると、ここに並びます。';

  @override
  String get exceptionsNoWarehouse => '倉庫を選ぶと表示できます';

  @override
  String get exceptionsAllCategories => 'すべての工程';

  @override
  String get exceptionCategoryReceiving => '入荷';

  @override
  String get exceptionCategoryQc => '検品';

  @override
  String get exceptionCategoryPutaway => '格納';

  @override
  String get exceptionShowClosed => '対応済みも表示';

  @override
  String get exceptionSeverityBlocker => '要対応';

  @override
  String get exceptionSeverityWarning => '注意';

  @override
  String get exceptionSeverityInfo => '参考';

  @override
  String get exceptionAcknowledge => '確認した';

  @override
  String get exceptionAcknowledged => '確認済み';

  @override
  String get exceptionResolve => '対応を記録';

  @override
  String get exceptionResolved => '対応済み';

  @override
  String get exceptionCancelled => '取消';

  @override
  String get exceptionResolveTitle => '対応を記録する';

  @override
  String get exceptionResolutionLabel => '対応';

  @override
  String get exceptionResolutionAccepted => '受入（このまま確定）';

  @override
  String get exceptionResolutionSupplierClaim => '仕入先へ連絡';

  @override
  String get exceptionResolutionReturned => '返送した';

  @override
  String get exceptionResolutionScrapped => '廃棄した';

  @override
  String get exceptionResolutionCorrected => '入力を訂正した';

  @override
  String get exceptionResolutionRecounted => '再カウントした';

  @override
  String get exceptionResolutionNoAction => '対応不要';

  @override
  String get exceptionNoteLabel => 'メモ（任意）';

  @override
  String get exceptionNoteRequiredLabel => 'メモ（必須）';

  @override
  String get exceptionNoteHint => '何をしたかを書く';

  @override
  String get exceptionNoteRequired => 'この対応にはメモが必要です';

  @override
  String get exceptionStockNotMovedHint =>
      'ここでは対応の記録だけを残します。在庫を動かす場合は在庫調整から行ってください。';

  @override
  String exceptionQuantity(int qty) {
    return '数量 $qty';
  }

  @override
  String exceptionLot(String lot, String expiry) {
    return 'ロット $lot / 期限 $expiry';
  }

  @override
  String exceptionRaisedAt(String date) {
    return '$date 起票';
  }

  @override
  String exceptionOpenCount(int count) {
    return '未処理 $count 件';
  }

  @override
  String exceptionBlockerCount(int blockers, int open) {
    return '要対応 $blockers 件（未処理 $open 件）';
  }

  @override
  String get exceptionRaise => '例外を起票';

  @override
  String get exceptionRaiseTitle => '例外を起票する';

  @override
  String get exceptionRaiseType => '種類';

  @override
  String get exceptionRaiseJanCode => 'JANコード（任意）';

  @override
  String get exceptionRaiseQuantity => '数量（任意）';

  @override
  String get exceptionRaiseNoTypes => '起票できる種類がありません';

  @override
  String get exceptionCancel => '取り消す';

  @override
  String get exceptionCancelTitle => 'この例外を取り消しますか？';

  @override
  String get exceptionCancelBody => '誤って起票した場合に使います。対応の記録は残りません。';

  @override
  String get exceptionCancelReasonLabel => '理由（任意）';

  @override
  String get featExceptions => '例外対応';

  @override
  String get featExceptionsDesc => '入荷・検品・格納の不一致を確認して対応を記録する';

  @override
  String get heldStockTitle => '検品待ち在庫';

  @override
  String get heldStockEmpty => '検品待ちの在庫はありません';

  @override
  String get heldStockEmptyBody => '入荷時に検品が必要な商品は、検品が終わるまでここに並びます。出荷はできません。';

  @override
  String get heldStockNoWarehouse => '倉庫を選ぶと表示できます';

  @override
  String get qcEffectTitle => '在庫への反映';

  @override
  String get qcEffectNothingMoved => '検品対象が検品待ち在庫になかったため、在庫は動いていません。';

  @override
  String get featHeldStock => '検品待ち在庫';

  @override
  String get featHeldStockDesc => '検品が終わるまで出荷できない在庫を確認する';

  @override
  String heldStockTotal(int units, int parcels) {
    return '合計 $units 点（$parcels 明細）が出荷できません';
  }

  @override
  String heldStockQuantity(int qty) {
    return '$qty 点';
  }

  @override
  String heldStockLot(String lot) {
    return 'ロット $lot';
  }

  @override
  String heldStockExpiry(String date) {
    return '期限 $date';
  }

  @override
  String heldStockDays(int days) {
    return '$days日経過';
  }

  @override
  String qcWillHold(int qty) {
    return '確定すると不合格 $qty 点は出荷できない在庫に移ります';
  }

  @override
  String qcEffectReleased(int qty) {
    return '合格 $qty 点を出荷可能にしました';
  }

  @override
  String qcEffectHeld(int qty, String status) {
    return '不合格 $qty 点を $status に移しました';
  }

  @override
  String qcEffectNotHeld(int qty) {
    return 'うち $qty 点は検品待ち在庫に無く、在庫は動いていません';
  }

  @override
  String get putawayNoSuggestionBody => 'この倉庫に置ける棚が見つかりません';

  @override
  String get putawayNoHeldBin => '出荷できない在庫を置ける棚（検品保留・破損など）がありません';

  @override
  String putawayLot(String lot) {
    return 'ロット $lot';
  }

  @override
  String get parcelAddTitle => 'パーセルを記録';

  @override
  String get parcelAdd => 'パーセル追加';

  @override
  String get parcelRemove => 'このパーセルを削除';

  @override
  String get parcelQuantity => '数量';

  @override
  String get parcelQuantityRequired => '数量を入力してください';

  @override
  String get parcelLot => 'ロット番号（任意）';

  @override
  String get parcelLotHint => '箱に書かれているロット';

  @override
  String get parcelExpiry => '期限（任意）';

  @override
  String get parcelExpiryNone => '未入力';

  @override
  String get parcelSerial => 'シリアル番号（任意）';

  @override
  String get parcelSerialHelp => 'シリアルを入れる場合は数量1';

  @override
  String get parcelSerialIsOne => 'シリアルは1点ごとに記録します';

  @override
  String get parcelLocation => '置いた場所（任意）';

  @override
  String get parcelLocationHint => '棚やエリアのコード';

  @override
  String get parcelDamaged => '到着時に破損していた';

  @override
  String get parcelDamagedHelp => '破損として記録します。出荷はできません。';

  @override
  String get parcelNote => 'メモ（任意）';

  @override
  String get parcelNoneYet => 'ロット・シリアル未記録';

  @override
  String get parcelAllAttributed => '全数記録済み';

  @override
  String parcelUnattributed(int qty) {
    return '未記録 $qty';
  }

  @override
  String parcelOverLine(int parcelled, int counted) {
    return 'パーセル合計 $parcelled が計上数 $counted を超えています';
  }

  @override
  String parcelLotShort(String lot) {
    return 'L:$lot';
  }

  @override
  String get receiptAddParcelTooltip => 'パーセルを追加';

  @override
  String get receiptDetailTitle => '入荷明細';

  @override
  String get receiptLineNoParcels => 'ロット・シリアル未記録';

  @override
  String get receiptParcelUnattributed => 'ロット未記録分';

  @override
  String get receiptUnlinkedTitle => '予定外の入荷';

  @override
  String get receiptUnlinkedBody => '発注明細に紐づかないパーセルです。';

  @override
  String receiptTotalUnits(int units) {
    return '合計 $units 点';
  }

  @override
  String receiptHeldUnits(int units) {
    return 'うち $units 点は出荷できません';
  }

  @override
  String receiptLinePlannedActual(int planned, int actual) {
    return '予定 $planned / 実績 $actual';
  }

  @override
  String receiptParcelLot(String lot) {
    return 'ロット $lot';
  }

  @override
  String receiptParcelExpiry(String date) {
    return '期限 $date';
  }

  @override
  String receiptParcelMovement(int id) {
    return '在庫履歴 #$id';
  }

  @override
  String get attachmentKindPhoto => '写真';

  @override
  String get attachmentKindDeliveryNote => '納品書';

  @override
  String get attachmentKindQcImage => '検品写真';

  @override
  String get attachmentKindDamage => '破損写真';

  @override
  String get attachmentKindDocument => '書類';

  @override
  String get attachmentKindLabel => 'ラベル';

  @override
  String get attachmentKindOther => 'その他';

  @override
  String get attachmentWithdraw => '取り下げ';

  @override
  String get attachmentWithdrawQ => 'この添付を取り下げますか？';

  @override
  String get attachmentWithdrawBody => '一覧からは外れますが、記録としては残ります。';

  @override
  String get attachmentWithdrawn => '添付を取り下げました';

  @override
  String get attachmentWithdrawnBadge => '取り下げ済み';

  @override
  String attachmentSize(int kb) {
    return '$kb KB';
  }

  @override
  String get attachmentNoCaption => '説明なし';

  @override
  String soApprovedWithReservations(int reserved) {
    return '受注を承認しました（引当 $reserved 件）';
  }

  @override
  String soApprovedWithSkips(int reserved, int skipped) {
    return '受注を承認しました（引当 $reserved 件・未引当 $skipped 件）';
  }

  @override
  String get soApprovalSkipDetail => '詳細';

  @override
  String get soSkippedLinesTitle => '引当できなかった明細';

  @override
  String get soSkipUnlinkedJan => '商品が未登録です';

  @override
  String soSkipInsufficientAvailable(int available, int requested) {
    return '在庫が不足しています（在庫 $available / 必要 $requested）';
  }

  @override
  String get soReservationsTitle => '引当状況';

  @override
  String get soReservationFulfilled => '出荷済み';

  @override
  String get soCreateShipment => '出荷を作成';

  @override
  String get soCreateShipmentQ => 'この受注から出荷を作成しますか？';

  @override
  String soShipmentCreated(int lines) {
    return '出荷を作成しました（明細 $lines 件）';
  }

  @override
  String get soOpenShipment => '出荷を開く';

  @override
  String get featWave => 'ウェーブピッキング';

  @override
  String get featWaveDesc => '複数の出荷をまとめて1回の巡回でピッキング';

  @override
  String get waveListTitle => 'ウェーブピッキング';

  @override
  String get waveEmpty => 'ウェーブがまだありません';

  @override
  String get waveEmptyBody => '複数の出荷をまとめて、一度の巡回でピッキングできます。';

  @override
  String get waveCreate => 'ウェーブを作成';

  @override
  String get waveChooseShipments => '出荷を選択（複数可）';

  @override
  String get waveNoShipments => '対象の出荷がありません';

  @override
  String get waveSelectAtLeastOne => '出荷を1件以上選択してください';

  @override
  String waveCreated(String code, int lists) {
    return 'ウェーブ $code を作成しました（$lists 件の出荷）';
  }

  @override
  String waveCreatedWithSkips(String code, int lists, int skipped) {
    return 'ウェーブ $code を作成しました（$lists 件・対象外 $skipped 件）';
  }

  @override
  String get waveStatusOpen => '未着手';

  @override
  String get waveStatusPicking => '作業中';

  @override
  String get waveStatusDone => '完了';

  @override
  String get waveStatusCancelled => '取消';

  @override
  String waveListsProgress(int picked, int total) {
    return '$picked / $total 明細';
  }

  @override
  String get waveUnassigned => '未担当';

  @override
  String get waveAssignToMe => '自分が担当する';

  @override
  String get waveUnassign => '担当を解除';

  @override
  String get waveViewSheet => 'ピッキング表を見る';

  @override
  String get waveSheetTitle => 'ピッキング表';

  @override
  String get waveSheetEmpty => 'ピッキング可能な明細がありません';

  @override
  String waveSheetTotalUnits(int total) {
    return '合計 $total 点';
  }

  @override
  String waveSheetForOrders(int count) {
    return '$count 件の出荷向け';
  }

  @override
  String get waveShortfallTitle => '不足分';

  @override
  String waveShortfallUnits(int short) {
    return '$short 点不足';
  }

  @override
  String get waveLists => '含まれる出荷';

  @override
  String get waveComplete => 'ウェーブを完了';

  @override
  String get waveCompleteQ => 'このウェーブを完了しますか？含まれる出荷はすべて確定します。';

  @override
  String waveCompleted(int count) {
    return 'ウェーブを完了しました（$count 件）';
  }

  @override
  String get waveIncomplete => '未ピックの明細が残っています';

  @override
  String get waveCancelAction => 'ウェーブを取消';

  @override
  String get waveCancelQ => 'このウェーブを取り消しますか？含まれる出荷は解放され、記録済みのピックはそのまま残ります。';

  @override
  String get waveCancelled => 'ウェーブを取り消しました';

  @override
  String get featDemand => '受注残・発注';

  @override
  String get featDemandDesc => '注文に在庫を引当て、足りない分をまとめて発注';

  @override
  String get demandTitle => '受注残・発注';

  @override
  String get demandEmpty => '待っている注文はありません';

  @override
  String get demandEmptyBody => '承認済みの受注のうち、在庫が足りずに引当できなかった分がここに集まります。';

  @override
  String get demandFillAll => '在庫からすべて引当';

  @override
  String get demandFillAllQ => '空いている在庫を、承認の古い注文から順に引当てます。よろしいですか？';

  @override
  String get demandNothingToFill => '引当できる在庫がありません';

  @override
  String demandFilled(int units) {
    return '$units 個を引当しました';
  }

  @override
  String demandPoCreated(int links) {
    return '発注を作成しました（$links 件の注文に紐付け）';
  }

  @override
  String demandCreatePo(int count) {
    return '発注を作成（$count 品目）';
  }

  @override
  String get demandBackordered => '受注残';

  @override
  String get demandCanFillNow => '今すぐ引当可';

  @override
  String get demandIncoming => '入荷予定';

  @override
  String get demandToPurchase => '要発注';

  @override
  String get demandAvailable => '空き在庫';

  @override
  String demandNeedsPurchase(int count) {
    return '要発注 $count';
  }

  @override
  String demandFillable(int count) {
    return '引当可 $count';
  }

  @override
  String get demandCovered => '手配済み';

  @override
  String demandFillNow(int count) {
    return '在庫から引当（$count）';
  }

  @override
  String demandWaitingOrders(int count) {
    return '待っている注文 $count 件';
  }

  @override
  String demandLineStatus(
      int ordered, int promised, int backordered, int onOrder) {
    return '受注 $ordered ・引当 $promised ・残 $backordered ・発注中 $onOrder';
  }

  @override
  String get demandLineFill => 'この注文に引当';

  @override
  String get demandLineFillQuantity => '引当数';

  @override
  String demandLineFillMax(int max) {
    return '最大 $max';
  }

  @override
  String get demandPoTitle => '受注残から発注';

  @override
  String get demandPoHint => '数量は要発注数が初期値です。少なく発注しても構いません — 足りない分は別の手配で補えます。';

  @override
  String demandPoLineHint(int backordered, int toPurchase) {
    return '受注残 $backordered ・要発注 $toPurchase';
  }

  @override
  String get demandQuantity => '発注数';

  @override
  String get demandOrdered => '受注';

  @override
  String get demandPromised => '引当済';

  @override
  String get demandShipped => '出荷済';

  @override
  String soSkipPartial(int reserved, int backordered) {
    return '引当 $reserved ・受注残 $backordered';
  }

  @override
  String soCreateShipmentReadyQ(int units) {
    return '引当済みで未出荷の $units 個を出荷に載せます。よろしいですか？';
  }

  @override
  String get soShipRemaining => '残りを出荷';

  @override
  String get soFillFromStock => '在庫から引当';

  @override
  String get soMoreActions => 'その他の操作';

  @override
  String get soReadyToShip => '出荷待ち';

  @override
  String get soShipments => '出荷';

  @override
  String get soShipmentShipped => '出荷済み';

  @override
  String get soShipmentOpen => '作業中';

  @override
  String get soLineUnlinked => '商品マスタ未登録のため引当できません';

  @override
  String soLineOnOrder(int count) {
    return '発注中 $count';
  }

  @override
  String get soFillLine => 'この明細に引当';

  @override
  String get poCreateRemainingDeliveryPlan => '残りの入荷予定を作成';

  @override
  String get poDeliveryPlans => '入荷予定';

  @override
  String get poPlanReceived => '入荷済み';

  @override
  String get poPlanOpen => '入荷待ち';

  @override
  String get poLinePlanned => '入荷予定';

  @override
  String get poLineReceived => '入荷済';

  @override
  String get poLineOutstanding => '未入荷';

  @override
  String get poLineForOrders => 'この発注の対象の受注';

  @override
  String get reconOpenPurchaseOrder => '発注を開く';

  @override
  String get reconLinkPurchaseOrder => '発注に紐付け';

  @override
  String get reconNoPurchaseOrderToLink => '紐付けできる発注がありません';

  @override
  String reconLinkedPurchaseOrder(String number) {
    return '$number に紐付けました';
  }

  @override
  String reservationAllocatedShort(int allocated, int short) {
    return '$allocated 個を割当（$short 個は在庫が見つかりません）';
  }

  @override
  String reservationAllocatedDone(int allocated) {
    return '$allocated 個を割当しました';
  }

  @override
  String reservationManualNoProduct(String jan) {
    return 'JAN $jan の商品が見つかりません';
  }

  @override
  String get reservationManualCreated => '引当を作成しました';

  @override
  String get reservationManualAdd => '手動で引当';

  @override
  String get reservationReleaseAllocation => '割当を外す';

  @override
  String get reservationAllocate => 'ロットを割当';

  @override
  String get reservationManualNote => '用途・メモ';

  @override
  String get reservationManualSubmit => '引当する';

  @override
  String get demandPoNeedSupplier => '仕入先名を入力してください';

  @override
  String demandPoOverLinked(int linked, int quantity) {
    return '紐付け $linked が発注数 $quantity を超えています';
  }

  @override
  String demandPoLineOverLinked(int backordered) {
    return 'この注文の受注残 $backordered を超えています';
  }

  @override
  String demandPoCreateN(int count) {
    return '発注を作成（$count 社）';
  }

  @override
  String demandPoProductHint(int backordered, int toPurchase, int incoming) {
    return '受注残 $backordered ・要発注 $toPurchase ・入荷予定 $incoming';
  }

  @override
  String demandPoProductTotal(int total) {
    return 'この商品の発注合計 $total';
  }

  @override
  String get demandPoSplitSupplier => '仕入先を分ける';

  @override
  String get demandPoRemoveRow => 'この仕入先を外す';

  @override
  String get demandPoLinksTitle => 'この発注をどの注文に充てるか';

  @override
  String get demandPoAutoLink => '古い順に自動で割り振り';

  @override
  String get demandPoNoWaiting => '待っている注文はありません — すべて見込みになります';

  @override
  String demandPoLineWaiting(int backordered, int onOrder) {
    return '受注残 $backordered ・発注中 $onOrder';
  }

  @override
  String demandPoRowSummary(int linked, int ahead) {
    return '紐付け $linked ・見込み（紐付けなし）$ahead';
  }

  @override
  String demandPosCreated(int count) {
    return '発注を $count 件作成しました';
  }

  @override
  String get demandAheadOnly => '見込みのみ';

  @override
  String demandIncomingBreakdown(int incoming) {
    return '入荷予定 $incoming（仕入先別）';
  }

  @override
  String demandIncomingBreakdownAhead(int incoming, int ahead) {
    return '入荷予定 $incoming（うち見込み $ahead）';
  }

  @override
  String demandIncomingPo(int outstanding) {
    return '残 $outstanding';
  }

  @override
  String demandIncomingPoAhead(int outstanding, int ahead) {
    return '残 $outstanding（見込み $ahead）';
  }

  @override
  String get demandIncomingAhead => '見込み入荷';

  @override
  String get poLinkEditTitle => '受注との紐付け';

  @override
  String poLinkOverOrdered(int ordered) {
    return 'この注文の受注数 $ordered を超えています';
  }

  @override
  String poLinkSaved(int linked, int reserved, int released) {
    return '紐付けを保存しました（紐付け $linked・入荷分から引当 $reserved・解除 $released）';
  }

  @override
  String poLinkLineSummary(int quantity, int received) {
    return '発注 $quantity ・入荷済 $received';
  }

  @override
  String get poLinkHint =>
      '入荷した分は紐付けた注文へ自動で引当てます。紐付けを変えると、この発注から引当てた分も移ります。紐付けない分は見込み在庫として、次の注文に回ります。';

  @override
  String get poLinkNoCandidates => 'この商品を待っている承認済みの受注はありません';

  @override
  String poLinkCandidateStatus(
      int ordered, int promised, int backordered, int onOrder) {
    return '受注 $ordered ・引当 $promised ・残 $backordered ・発注中 $onOrder';
  }

  @override
  String poLinkFilled(int filled) {
    return 'この発注の入荷分から引当済 $filled';
  }

  @override
  String get poLinkQuantity => '紐付け数';

  @override
  String poLineLinkedAhead(int linked, int ahead) {
    return '受注に紐付け $linked ・見込み $ahead';
  }

  @override
  String get poLinkEdit => '紐付けを編集';

  @override
  String poDemandFilled(int filled) {
    return '（入荷分引当 $filled）';
  }

  @override
  String get transferStatusExported => '国外へ出庫済み';

  @override
  String get transferExportBadge => '国外へ出庫';

  @override
  String transferCrossBorderExport(String country) {
    return '$countryへの国をまたぐ転送です。出庫した時点で在庫から除外され、受入はありません。';
  }

  @override
  String transferCrossBorderReceived(String country) {
    return '$countryの倉庫は国外からの受入を行う設定です。通常の転送と同じく受入まで行います。';
  }

  @override
  String get transferExportNotice =>
      '国をまたぐ転送：出庫した時点で実在庫から除外され、受入はありません。送った数は「国外倉庫の仮想在庫」に計上されます。';

  @override
  String get transferCrossBorderReceivedNotice =>
      '国をまたぐ転送：受け入れ先の倉庫が国外からの受入を行う設定のため、受入まで行います。';

  @override
  String transferCompletePickingExportBody(String warehouse) {
    return '$warehouseから出庫し、国外へ送った分として在庫から除外します。この転送は受入なしで完了します。';
  }

  @override
  String get whRoleEdit => '国・役割';

  @override
  String get whRoleSaved => '倉庫の国・役割を保存しました';

  @override
  String get whRoleCountry => '国';

  @override
  String get whRoleCountryCode => '国コード（2文字）';

  @override
  String get whRoleReceivesCrossBorder => '国外からの転送を受け入れて在庫を持つ';

  @override
  String get whRoleReceivesCrossBorderHint =>
      'オフのとき、他国の倉庫からこの倉庫への転送は出庫時点で在庫から除外されます。この倉庫から個別のお客さんへ出荷する場合はオンにします。';

  @override
  String get countryJP => '日本';

  @override
  String get countryCN => '中国';

  @override
  String get countryOther => 'その他';

  @override
  String get supplierNamesSection => '仕入先ごとの呼び名';

  @override
  String get supplierNamesHint =>
      '仕入先ごとの商品名・品番を登録すると、その呼び名で検索でき、納品書の照合にも使われます。出荷伝票には自社の商品名が印字されます。';

  @override
  String get supplierNamesEmpty => 'まだ登録がありません';

  @override
  String get supplierNameAdd => '呼び名を追加';

  @override
  String get supplierNameEdit => '呼び名を編集';

  @override
  String get supplierNameSaved => '呼び名を保存しました';

  @override
  String get supplierNameNoSuppliers => '先に取引先（仕入先）を登録してください';

  @override
  String get supplierNameSupplier => '仕入先';

  @override
  String get supplierNameName => '仕入先での商品名';

  @override
  String get supplierNameCode => '仕入先での品番（任意）';

  @override
  String get supplierNameNote => 'メモ（任意）';

  @override
  String supplierNameCodeLabel(String code) {
    return '品番 $code';
  }

  @override
  String poLineSupplierName(String name) {
    return '仕入先での呼び名：$name';
  }

  @override
  String get featVirtualStock => '国外倉庫の仮想在庫';

  @override
  String get featVirtualStockDesc => '日本から送った数と手入力の実数で、国外倉庫のおおよその在庫を月ごとに見る';

  @override
  String get virtualTitle => '国外倉庫の仮想在庫';

  @override
  String get virtualExplain =>
      '国外へ送った商品は実在庫からは除外されています。ここは日本からの出荷と手入力の実数による仮想の数で、引当や出荷には使われません。';

  @override
  String get virtualNoWarehouse => '国外の倉庫がありません';

  @override
  String get virtualNoWarehouseBody => '倉庫の「国・役割」で国を設定すると、ここに表示されます。';

  @override
  String get virtualWarehouse => '倉庫';

  @override
  String get virtualFromMonth => '開始月';

  @override
  String get virtualToMonth => '終了月';

  @override
  String virtualRangeTotal(String from, String to) {
    return '$from 〜 $to の合計';
  }

  @override
  String get virtualByMonth => '月別';

  @override
  String get virtualByProduct => '商品別';

  @override
  String get virtualEmpty => 'この期間の記録はありません';

  @override
  String get virtualOpening => '期首';

  @override
  String get virtualArrived => '日本から';

  @override
  String get virtualAdjusted => '手動増減';

  @override
  String get virtualCountDiff => '実数との差';

  @override
  String get virtualClosing => '期末';

  @override
  String get virtualMonth => '月';

  @override
  String virtualProductLine(int opening, int arrived, int change) {
    return '期首 $opening ・日本から +$arrived ・増減 $change';
  }

  @override
  String virtualLastCount(String date, int counted) {
    return '最終実数 $date：$counted';
  }

  @override
  String get virtualRecord => '実数・増減を入力';

  @override
  String get virtualRecorded => '記録しました';

  @override
  String get virtualHistory => '記録の履歴';

  @override
  String virtualBalanceThatDay(int balance) {
    return 'その日の数 $balance';
  }

  @override
  String virtualEntryExport(int quantity, String number) {
    return '日本から +$quantity（$number）';
  }

  @override
  String virtualEntryCount(int counted) {
    return '実数 $counted';
  }

  @override
  String virtualEntryAdjust(String change) {
    return '増減 $change';
  }

  @override
  String get virtualTypeCount => '実数';

  @override
  String get virtualTypeAdjust => '増減';

  @override
  String get virtualTypeCountHint => 'その日に実際にあった数を入力します。以後の数はこの数から計算されます。';

  @override
  String get virtualTypeAdjustHint => '分かっている出庫や入庫を入力します。';

  @override
  String get virtualAdjustOut => '出庫（減）';

  @override
  String get virtualAdjustIn => '入庫（増）';

  @override
  String get virtualCountedQuantity => '実数';

  @override
  String get virtualAdjustQuantity => '数量';

  @override
  String get virtualDate => '日付';

  @override
  String get virtualNote => 'メモ（任意）';
}
