# macOS 自动更新

正式版在首次打开时询问是否启用自动检查。开启后在启动时补做逾期检查，以及运行期间每 24 小时检查一次。Folio 菜单与设置均可手动检查。自动检查、下载和安装可独立设置，后台失败显示在设置页。

Folio 将已验签的下载暂存在本次运行内。确认安装，或事先启用空闲安装后，Sparkle 再次验证签名、校验应用并替换 bundle。编辑、打开文件和原生媒体播放会延后重启。工作区文件与根目录偏好保存在应用 bundle 之外。

## 本地验收

运行 `scripts/prepare-update-qa`，从最后一行取得临时目录。在其中通过 `python3 -m http.server 18736 --bind 127.0.0.1 --directory "$qa/server"` 提供测试更新源。打开 `"$qa/installed/Folio Update QA.app"` 和同目录的 `Fixture.md`。从设置检查、下载并安装版本 0.1.1。QA 使用 Apple Silicon、本地 HTTP、独立应用标识、临时 Ed25519 密钥和 ad hoc Apple 签名。正式包走独立的 HTTPS 渠道、Developer ID 与公证。

## CI 与私有预览

推送到 `main` 后运行 Folio CI。Rust 和 macOS 检查均通过且发布路径有变化时，Meta 的 `release-tag` 从同一提交创建 `vX.Y.Z.<提交 Unix 秒>-<7 位 SHA>`。该 tag 的 push 启动独立 Release workflow。PR、失败的 CI 和手动运行都不会写入 tag 或 Release。

- 在仓库 Actions secrets 添加 `RELEASE_TAG_TOKEN`，使用只可写入此仓库 Contents 的 GitHub App 或细粒度 PAT。GitHub Actions 自带 token 可上传 Release assets，但用它创建 tag 无法触发独立的 tag-push workflow。
- 在 `folio-macos-preview` 环境设置 `FOLIO_UPDATE_PUBLIC_KEY` 变量及 `FOLIO_UPDATE_PRIVATE_KEY` secret。生成和保管方法与稳定版相同，两个环境使用各自的 Ed25519 密钥。预览不使用 Developer ID 或公证凭据。
- 每个预览在同一私有仓库发布为不可变的 prerelease，附带 ad hoc Apple Silicon DMG、SHA-256、Sparkle ZIP 和签名 appcast。Preview 使用独立的 bundle ID 和系统钥匙串项，只从已发布且带更新资产的不可变预览版本选取更新。正式版继续使用 stable latest。
- 首个手工预览 `preview-v0.1.0` 需要手动换成首个自动预览包一次。此后可在 Folio 的 **Settings → Updates → GitHub Access** 配置仓库只读 token 来检查并安装更新。

## 正式分发

首版发布在私有源码仓库的 GitHub Releases。需要仓库读取权限才能下载。启用不可变 Releases。发布任务使用该任务自身的 `GITHUB_TOKEN`，在 `folio-macos-release` 环境中配置稳定渠道的 `FOLIO_UPDATE_PUBLIC_KEY` 和下表的签名凭据。每次发布前更新 `.release/notes.txt` 和 `.release/units/folio.json` 中的版本。在 Meta 验证的 main 提交上创建并推送手动 `vX.Y.Z` 标签。手动选择既有 tag 运行 workflow 时，稳定版执行本地 QA 打包，预览版使用临时 Sparkle 密钥打包。

首次安装从登录 GitHub 后可见的 Releases 下载 DMG。要在应用里检查更新，到 **Settings → Updates → GitHub Access** 保存仅对此仓库有 **Contents: Read** 权限的细粒度 GitHub token。Folio 将它保存在 macOS Keychain，并只发给 GitHub API。Folio 下载签名的 appcast 和归档，再交给 Sparkle 核验和安装。

| 环境密钥 | 用途 |
| --- | --- |
| `FOLIO_APPLE_CERTIFICATE`、`FOLIO_APPLE_CERTIFICATE_PASSWORD` | base64 编码的 Developer ID Application PKCS#12 证书及密码 |
| `FOLIO_APPLE_NOTARY_KEY`、`FOLIO_APPLE_NOTARY_KEY_ID`、`FOLIO_APPLE_NOTARY_ISSUER` | Apple 公证凭据 |
| `FOLIO_UPDATE_PRIVATE_KEY` | 稳定渠道 Sparkle Ed25519 私钥种子 |

任务签名并公证应用和 DMG、装订公证票据，再生成单独签名的 ZIP 和 appcast。Meta 发布动作将固定版本资产上传至草稿。任务回读验证每个资产后将已核查的版本更新为 latest，再从实际经授权的下载入口 回读验证。首次交付通过已公证的 DMG，后续从 ZIP 更新。

发布中断后，在 GitHub Actions 重跑原 workflow run。上传草稿前，任务已将签名后的 ZIP、DMG 和 appcast 保存为该 run 的 `folio-signed-packages`。重跑会下载同一份文件，按 Meta 校验续传缺失的资产。若草稿不完整且原制品已过期或丢失，流程会停止，需要先找回原制品再继续。

更新私钥应保存在发布环境及安全的离线备份中。轮换时先验证旧客户端确实能使用旧信任链更新至过渡版本，再由已验证的过渡版本承接新密钥。当前打包任务仅接受一个私钥，计划轮换时应为过渡版本单独准备和验收签名路径。无法自动升级时，使用同一 Developer ID 公证的 DMG 手动替换应用。如需撤回错误版本，先停止分发该更新，为已安装的用户提供经过数据兼容验证的更高版本。
