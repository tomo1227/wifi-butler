# WiFi Butler

飲食店、列車、駅、空港のフリー Wi-Fi を対象とする、macOS メニューバーアプリです。対象 Wi-Fi への再接続と手動認証を補助する PoC です。通信障害と Captive Portal の候補を区別し、確認した URL を選んだブラウザで開けます。利用規約への同意やログイン操作はアプリから行いません。

| 監視対象 | SSID |
| --- | --- |
| ドトール | `DOUTOR_FREE_Wi-Fi` |
| サンマルクカフェ | `309cafe_Wi-Fi` |
| [スターバックス](https://starbucks.wi2.co.jp/sp/sma_index_jp.html?locale=jp) | `at_STARBUCKS_Wi2` |
| [タリーズコーヒー](https://www.tullys.co.jp/wifi/) | `tullys_Wi-Fi` |
| [マクドナルド](https://www.mcdonalds.co.jp/shop/mcdwifi/) | `00_MCD-FREE-WIFI` |
| 東海道・山陽・九州新幹線の車内 | `Shinkansen_Free_Wi-Fi` |
| [JR東日本の対象車両](https://jreastfaq.jreast.co.jp/faq/show/2968)・[一部の駅](https://www.gotokyo.org/en/plan/wifi-connectivity/wifi_hotspotguide.html) | `JR-EAST_FREE_Wi-Fi` |
| [東海道新幹線の駅構内など](https://railway.jr-central.co.jp/wireless/free_wifi.html) | `JR-Central_FREE` |
| [羽田空港](https://tokyo-haneda.com/service/facilities/wireless_lan.html) | `HANEDA-FREE-WIFI` |
| [成田空港](https://www.narita-airport.jp/ja/service/internet/power-outlet/) | `FreeWiFi-NARITA` |

提供場所や SSID は現地の案内で確認してください。表にない SSID は監視対象外です。各サービスでの実地認証は未検証です。

## ビルド・実行

Swift 6.4 以降を含む Xcode と、macOS 15 以降が必要です。外部ライブラリは不要です。

```sh
make test   # XCTest（実際の Wi-Fi やブラウザ操作に依存しません）
make build  # .build/WiFiButler.app を作成・署名
make run    # アプリをビルドして起動
make lint   # swift-format のルールを確認
```

ローカルビルドは既定でアドホック署名です。継続して位置情報権限を使う場合は、安定したコード署名 ID を `make build SIGN_IDENTITY="…"` で指定してください。署名し直した際に macOS が権限を再確認することがあります。

## 使い方

1. macOS で上記の監視対象 Wi-Fi に接続します。
2. メニューバーの蝶ネクタイのアイコンから **監視を開始** を選び、SSID の読み取りに必要な位置情報の利用を許可します。位置座標は取得しません。
3. つなぎ直したいときはメニューまたは **状況・履歴** の **Wi-Fi に再接続** を押します。接続中に押すと通信が一時的に切れます。**今すぐ確認** は通信状態を調べ直すだけです。
4. 再接続後に認証ページ候補を検出すると、選択したブラウザで一度だけ開きます。それ以外の場合も、候補が表示されたら手動で開けます。接続先が Wi-Fi 提供者のページであることを確かめ、利用規約への同意やログインはブラウザで行ってください。
5. ブラウザを開いた後、アプリは Apple の疎通確認ページへの HTTPS 通信を再確認します。再接続できない場合は macOS の Wi-Fi メニューで接続し、認証ページが表示されない場合は macOS の Wi-Fi ログイン画面を使ってください。

蝶ネクタイの右の印は、インターネット接続済みならチェック、認証ページ候補・想定外の応答・ブラウザ起動失敗なら感嘆符、それ以外は横線です。

ブラウザは Dia、Safari、Google Chrome、Firefox、Microsoft Edge、Brave、Arc、Opera、Vivaldi から選べます。ほかのブラウザも、macOS でデフォルトの Web ブラウザに設定して **「macOS のデフォルト」** を選べば使えます。未インストールのブラウザを指定して開けなかった場合は、別のブラウザを選んで再試行してください。

メニューの **Wi-Fi の DNS 設定** から、デフォルト（自動）、Cloudflare DNS、Google Public DNS を選択して適用できます。選択しただけでは設定は変更されず、**適用** を押したときに IPv4・IPv6 の DNS サーバーをまとめて変更します。

DNS 設定は現在の Wi-Fi サービス全体に適用されます。SSID ごとの設定ではありません。Wi-Fi サービスを一意に特定できない場合は設定を変更しません。

デフォルト（自動）を適用すると、手動指定の DNS サーバーだけを削除します。検索ドメインなど、その他の DNS 設定は保持します。既知のプリセットと一致しない手動 DNS 設定は「カスタム」と表示します。

DNS の変更には macOS の認証が必要です。認証がキャンセルされた場合や、設定の保存・反映に失敗した場合は成功として扱いません。監視や Wi-Fi の再接続に連動した DNS の自動切り替えは行いません。

監視は初期状態で停止しています。監視中は通常 30 秒おきに確認し、スリープ中は停止します。履歴はローカルに日時とイベント種類だけを最大 7 日間・300 件保存します。認証 URL、SSID、認証情報、Cookie は履歴に保存しません。

監視中に Wi-Fi 自体が切断された場合は、直前に接続していた対象 SSID への自動再接続を一度試します。インターネットに届かないだけの場合、Wi-Fi がオフの場合、または別の Wi-Fi に接続している場合は自動ではつなぎ直しません。自動再接続は **状況・履歴** で無効にできます。再接続はパスワード不要のオープンネットワークが対象です。

## 技術調査と制約

| 項目 | 採用方針・確認結果 |
| --- | --- |
| SSID・ネットワーク経路 | [CoreWLAN](https://developer.apple.com/documentation/corewlan) の `CWWiFiClient` で SSID を取得し、`NWPathMonitor` で Wi-Fi の経路を確認します。SSID が不明・対象外の場合は HTTP/HTTPS の疎通確認を行いません。`URLSession` はシステムの経路を使うため、VPN・プロキシなどの影響は受けます。 |
| 再接続 | CoreWLAN で対象 SSID のオープンネットワークを探して接続します。再接続先になる最後の SSID は監視中だけメモリに保持します。実環境のアクセスポイントでの動作は未検証です。 |
| Captive Portal | `captive.apple.com` の既知の HTTPS 応答を疎通判定に使用します。HTTPS だけで判定できない場合のみ HTTP を試し、リダイレクトは自動追跡しません。異なるホストへの同じリダイレクト（または `511` と `Location`）が続いた場合のみ候補を表示します。候補は提供者の真正性を保証しません。別の応答形式のポータルや、一部の通信だけを許可するネットワークは誤判定・見逃しがあり得ます。 |
| ブラウザ | AppleScript や JavaScript は使わず、`NSWorkspace` で選択したブラウザに URL を渡します。起動済みなら既存のインスタンスを使います。 |
| Accessibility | 自動操作の候補実装は、アクセシビリティ権限、フォーカスされたウィンドウ、承認済みの HTTPS URL、一意かつ有効な `AXPress` 対象を要求します。実店舗の Dia/Safari における AX ツリーは未検証で、アプリからは起動しません。現行アプリの利用にアクセシビリティ権限は不要です。 |
| 対応店舗の情報 | ドトールは[公式案内](https://www.doutor.co.jp/dcs/service/dtr-wifi.html)、サンマルクカフェは[公式の店舗情報](https://www.saint-marc-hd.com/saintmarccafe/search/)と[SSID の利用報告](https://realnet-engineering.jp/mobile/saintmarccafe/)を参照しています。どちらも実店舗でのポータル検出から認証成功までの動作は未検証です。事業者の規約やセッション制限は回避しません。 |
| 新幹線車内 Wi-Fi | [JR東海の SSID・利用案内](https://railway.jr-central.co.jp/wireless/shinkansen_free_wifi.html)と[JR西日本の提供区間案内](https://www.jr-odekake.net/railroad/service/shinkansen-wifi.html)を参照しています。メール登録や SNS 認証は手動です。実車内でのポータル検出から認証成功までの動作は未検証です。 |
| DNS 設定 | `SystemConfiguration` の公開 API で現在のネットワークセットから Wi-Fi サービスを特定し、DNS プロトコル設定を変更します。`CoreWLAN` のアクティブな Wi-Fi インターフェース名と照合し、一意に特定できない場合は変更しません。認証には macOS 標準の Authorization Services を使用します。DNS サーバー以外の設定は保持し、監視・再接続時の自動変更は行いません。 |

自動同意の事前承認設定、監視対象 SSID のユーザー設定、設定の永続化、ログイン時の自動起動、終了後のバックグラウンド監視、通知は未対応です。次の段階では、実店舗で正規ポータルの URL・AX 要素を確認し、承認を撤回できる設定を実装してから自動操作の有効化を検討します。
