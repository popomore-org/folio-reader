# macOS 自动更新

正式版在首次打开时询问是否启用自动检查。开启后在启动时补做逾期检查，以及运行期间每 24 小时检查一次。Folio 菜单与设置均可手动检查。自动检查、下载和安装可独立设置，后台失败显示在设置页。

Folio 将已验签的下载暂存在本次运行内。确认安装，或事先启用空闲安装后，Sparkle 再次验证签名、校验应用并替换 bundle。编辑、打开文件和原生媒体播放会延后重启。工作区文件与根目录偏好保存在应用 bundle 之外。

## 本地验收

运行 `scripts/prepare-update-qa`，从最后一行取得临时目录。在其中通过 `python3 -m http.server 18736 --bind 127.0.0.1 --directory "$qa/server"` 提供测试更新源。打开 `"$qa/installed/Folio Update QA.app"` 和同目录的 `Fixture.md`。从设置检查、下载并安装版本 0.1.1。QA 使用 Apple Silicon、本地 HTTP、独立应用标识、临时 Ed25519 密钥和 ad hoc Apple 签名。正式包走独立的 HTTPS 渠道、Developer ID 与公证。

## 正式分发

`folio-macos-release` 环境使用独立的 GitHub 下载仓库。将 `FOLIO_RELEASE_REPOSITORY` 设为组织批准的公共分发仓库，并在该仓库启用不可变 Releases。将 `FOLIO_UPDATE_PUBLIC_KEY` 设为稳定渠道的 Ed25519 公钥。私有源码的发行说明使用明确准备的 `.release/notes.txt`。每次发布前更新 Notes 和 `.release/units/folio.json` 中的版本。在 Meta 验证的 main 提交上创建并推送手动 `vX.Y.Z` 标签。手动运行 workflow 只会验源和生成本地 QA 包。

| 环境密钥 | 用途 |
| --- | --- |
| `FOLIO_DISTRIBUTION_TOKEN` | 分发仓库的 Contents 写权限 |
| `FOLIO_APPLE_CERTIFICATE`、`FOLIO_APPLE_CERTIFICATE_PASSWORD` | base64 编码的 Developer ID Application PKCS#12 证书及密码 |
| `FOLIO_APPLE_NOTARY_KEY`、`FOLIO_APPLE_NOTARY_KEY_ID`、`FOLIO_APPLE_NOTARY_ISSUER` | Apple 公证凭据 |
| `FOLIO_UPDATE_PRIVATE_KEY` | 稳定渠道 Sparkle Ed25519 私钥种子 |

任务签名并公证应用和 DMG、装订公证票据，再生成单独签名的 ZIP 和 appcast。Meta 发布动作将固定版本资产上传至草稿。任务回读验证每个资产后将已核查的版本更新为 latest，再从实际公开 URL 回读验证。首次交付通过已公证的 DMG，后续从 ZIP 更新。

发布中断后，在 GitHub Actions 重跑原 workflow run。上传草稿前，任务已将签名后的 ZIP、DMG 和 appcast 保存为该 run 的 `folio-signed-packages`。重跑会下载同一份文件，按 Meta 校验续传缺失的资产。若草稿不完整且原制品已过期或丢失，流程会停止，需要先找回原制品再继续。

更新私钥应保存在发布环境及安全的离线备份中。轮换时先验证旧客户端确实能使用旧信任链更新至过渡版本，再由已验证的过渡版本承接新密钥。当前打包任务仅接受一个私钥，计划轮换时应为过渡版本单独准备和验收签名路径。无法自动升级时，使用同一 Developer ID 公证的 DMG 手动替换应用。如需撤回错误版本，先停止分发该更新，为已安装的用户提供经过数据兼容验证的更高版本。
