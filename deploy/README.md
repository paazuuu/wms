# VPS へのデプロイ手順

## 構成

| 役割 | 置き場所 | 備考 |
|---|---|---|
| データベース・ログイン・API（Edge Functions）・添付ファイル | **Supabase**（マネージド） | 今のプロジェクトをそのまま使う |
| 画面（Flutter Web 版） | **社内の VPS** | Caddy が静的ファイルを HTTPS で配信するだけ |
| Android 版 | 社員の端末 | `flutter build apk` で作って社内配布 |

- **Cloudflare は不要**です。HTTPS 証明書は Caddy が Let's Encrypt から自動で取得・更新します。
- **Stripe（決済）も使いません**。社内システムなので課金まわりはありません。
- VPS にはデータを置きません。VPS が止まっても在庫データは Supabase 側に残り、Android 版はそのまま使えます。
- 画面に必要なもの（CanvasKit、日本語・中国語フォント）はすべて VPS から配信するので、**中国の倉庫など Google につながらない環境でも文字化けせずに表示されます**。

## 1. VPS の準備（初回だけ）

1. Ubuntu などの VPS に Docker（Compose プラグイン込み）を入れる。
2. ファイアウォールで 80 番と 443 番を開ける（80 番は証明書の取得に使う）。
3. 社内で使うドメインの DNS に A レコードを追加し、VPS の IP を向ける（例: `wms.example.co.jp`）。
4. このディレクトリ（`deploy/`）の `Caddyfile`、`docker-compose.yml`、`.env.example` を VPS の `/opt/wms/` に置く。
5. VPS 上で次を実行する。

   ```bash
   cd /opt/wms
   cp .env.example .env    # WMS_DOMAIN を実際のドメインに書き換える
   mkdir -p site
   docker compose up -d
   ```

## 2. 画面のビルドと公開（更新のたび）

Flutter SDK が入った PC（または CI）で、リポジトリのルートから次を実行します。

```bash
./deploy/build_web.sh                                      # mobile/build/web に出力
VPS_HOST=deploy@wms.example.co.jp ./deploy/publish_web.sh  # VPS の /opt/wms/site に送る
```

- 送った時点で新しい画面が配信されます（Caddy の再起動は不要）。起動ファイルはキャッシュしない設定なので、利用者はページを開き直すだけで最新版になります。
- 初回のビルドではフォントを約 24MB 取得します。取得したフォントは `deploy/.cache/` に保存され、次回からは再利用します。
- 別の Supabase プロジェクトにつなぐときは、ビルドの前に `SUPABASE_URL` と `SUPABASE_ANON_KEY` を環境変数で指定します。

## 3. Supabase 側の設定（初回だけ）

Supabase ダッシュボードで次を確認します。

- **Authentication → Sign In / Providers →「Allow new users to sign up」をオフ。** 社外の人が勝手にアカウントを作れないようにするためです。アカウントは管理者が作ります。
- **Authentication → URL Configuration → Site URL** を `https://（社内ドメイン）` にする。

## 4. 部署ごとのアカウントと役割

1. **最初の 1 人**：Supabase ダッシュボード（Authentication → Users → Add user）でアカウントを作り、アプリにログインします。最初にログインした人が自動で System Admin になります。
2. **2 人目以降**：同じ手順でアカウントを作り、本人に一度ログインしてもらいます。そのあと管理者がアプリの「ユーザー管理」で**役割**と**担当倉庫**を付けます。役割は複数付けられます。
3. 画面のメニューは役割に応じて自動で出し分けます。サーバー側でも同じ権限で操作を止めるので、画面を細工されても権限外の操作はできません。

| 部署の例 | 付ける役割 | できること |
|---|---|---|
| 管理部・情報システム | System Admin / Company Admin | すべて（ユーザー管理を含む）。全倉庫が見える |
| 購買部 | Purchasing | 仕入先・仕入先ごとの商品名、要発注からの発注、注文との紐付け、発注の承認 |
| 営業部 | Sales | 受注の登録から承認まで、在庫からの引当、得意先 |
| 倉庫責任者 | Warehouse Manager | 担当倉庫の運用全般（入荷・出荷・転送・棚卸の承認など） |
| 入荷担当 | Receiving (+ Inspector) | 入荷照合・検品 |
| 棚入れ・ピッキング・梱包・出荷担当 | Put-away Operator / Picker / Packer / Shipper | それぞれの現場作業 |
| 在庫管理 | Inventory Controller | 棚卸・在庫調整・仮想在庫の実数入力 |
| 経営・閲覧のみ | Viewer | 参照とレポート |

- **承認は別の人が行います。** 発注も受注も、登録した本人は承認できません。同じ部署の中でも、登録する人と承認する人を分けてください。
- **担当倉庫**を付けた人は、その倉庫のデータだけを扱えます。中国の倉庫の担当者には中国の倉庫だけを付けます。
