# Folio macOS 自动预发布

将 MusicX 的主分支 CI、自动预览 tag、独立 tag 发布流程接入现有私有发行 PR。沿用 Meta 的 tag 格式、发布凭据和写入入口。自动 tag 产出 ad hoc Apple Silicon 预览和独立签名的 Sparkle 更新；手动三段 tag 保留原稳定发布路径。

验收覆盖当前 PR 的 Meta 门禁、预览包和签名、更新入口分流及重跑行为。凭据配置和合并后的实际 tag、GitHub 制品与客户端更新单独记录。合并依照仓库规则单独授权。
