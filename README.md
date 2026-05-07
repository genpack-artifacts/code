# code — Collabora Online (CODE) サーバー

[Collabora Online Development Edition](https://www.collaboraonline.com/code/) のgenpackアーティファクト。
ブラウザ上でドキュメントを共同編集できるセルフホスト型オフィスサービス。

## 概要

- **coolwsd** (Collabora Online WebSocket Daemon) を9980/tcpで起動
- nftables により80/tcp → 9980/tcp へポート転送（TLS終端リバースプロキシからの接続を想定）
- SSL無効・TLS終端はリバースプロキシ側で行う前提
- Collabora本体（LibreOffice）はビルド時にCollabora公式DEBリポジトリから取得

## Nextcloudとの連携

Collabora OnlineはWOPIプロトコルでNextcloudと連携する。
ブラウザはNextcloudとCollabora Online両方に直接アクセスするため、
**2つのサービスをそれぞれエンドユーザーから到達できるアドレスに公開する必要がある**。

```
ブラウザ ──HTTPS──▶ リバースプロキシ ──▶ Nextcloud
ブラウザ ──HTTPS──▶ リバースプロキシ ──▶ このVM:80 (→ coolwsd:9980)
```

### 初期設定

起動後、VMにログインして以下を実行する。

**① WOPIホスト（Nextcloudのドメイン）を許可**

```bash
coolconfig set storage.wopi.host <nextcloud.example.com>
systemctl restart coolwsd
```

**② 管理者パスワードを設定**

```bash
coolconfig set-admin-password
systemctl restart coolwsd
```

### Nextcloud側の設定

1. アプリ管理から **Nextcloud Office** をインストール
2. 管理者設定 → Office → 「独自サーバーを使用」
3. CollaboraのURLを入力: `https://collabora.example.com`

## ホストからのアクセス

`vm run` の `--sock-proxy` でホスト側の UNIX ドメインソケットを VM の vsock ポートに転送できる。
ソケットのライフサイクルは VM と一致する。

```bash
vm run --name collabora --sock-proxy 80 code-x86_64.squashfs
```

ソケットは `$XDG_RUNTIME_DIR/vm/collabora/tcp/80.sock` に作成される。
