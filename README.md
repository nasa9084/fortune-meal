# ごはんくじ

食事の候補を複数選んで、ボタンを押すとその中から1つ選ばれるiOSアプリ。

GitHub Actionsで未署名のIPAをビルドし、SideStoreで無料Apple IDで署名してiPhoneにインストールする。

## 構成

- `project.yml` — XcodeGenの定義（Actions上で `.xcodeproj` を生成する。プロジェクトファイルはコミットしない）
- `Sources/` — SwiftUIのコードとアイコン
- `.github/workflows/build.yml` — mainへのpushでビルドし、次を行う
  - `build-<番号>` リリースに `GohanKuji.ipa` を添付
  - `source` リリースの `source.json`（SideStore用ソース）を最新ビルドで上書き

## 初回セットアップ

1. リポジトリは**public**のままにする（SideStoreが認証なしでリリースからダウンロードするため）
2. Actionsが成功したら、ソースURLを控える
   `https://github.com/nasa9084/fortune-meal/releases/download/source/source.json`
3. iPhoneにSideStoreを入れる（PCが必要なのはここだけ）
   - App Storeから LocalDevVPN を入れて接続
   - PCに iloader（https://iloader.app）を入れ、USB接続したiPhoneへSideStoreをインストール
   - iPhoneでデベロッパモードをオン、「VPNとデバイス管理」で自分のApple IDを信頼
   - SideStoreを開いてApple IDでサインインし、SideStore自身を一度Refresh
4. SideStoreの Sources → ＋ で2のURLを追加し、「ごはんくじ」をインストール

## 更新

- mainにpushするとビルド番号が上がり、SideStoreにアップデートとして表示される（タップで更新）
- 7日ごとの署名延長は、ショートカットのオートメーションで「LocalDevVPN接続 → 待機 → SideStoreのRefresh All Apps」を定期実行する

## 注意

- 無料Apple IDでは同時に有効なアプリが3つまで（SideStore自身を含む）
- iOSのアップデートなどでペアリングファイルが無効になると、PCでの再設定が必要
