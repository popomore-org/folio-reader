# Progress

## Current

- Status: 候选已实现并通过本地打包与模拟验证。
- Blockers: 仓库当前没有可用的专用打标凭据。GitHub 真实发布须在配置凭据并合并后验收。
- Next: 提交现有 PR，检查当前 head 的 CI 与 Meta 门禁。
- Branch/PR: fix/folio-release-toolchain / Folio #5。
- Runtime/Follow-up: 新请求未要求另开原生目标，持续在本次交付执行。

## Plan

| Work | Done when | Status |
| --- | --- | --- |
| 自动打标 | 受成功的 main CI 与 Meta 清单约束 | complete |
| 私有预览 | 独立 ad hoc 包、签名更新和重试通过验证 | complete |
| PR | 当前候选通过 CI 和 Meta 合并检查 | active |

## Steps

### Step 1 — 2026-11-16 — 核对发布策略与现场配置

- 复用现有 Folio #5，保留已发布的 `preview-v0.1.0` 以及稳定 tag。
- Meta ADR 0025 要求使用专用 token 打标，由 tag push 独立发布。手动工作流保留只读验证。

### Step 2 — 2026-11-16 — 接通预览包、更新与发布复跑

- 主分支 CI 通过后使用 Meta 共享打标 Action。独立 tag workflow 根据校验后的 channel 区分 timestamp 与 stable。
- 本机生成 ad hoc Apple Silicon DMG 与 Sparkle ZIP，Quick Look 检查及签名验证通过。原生测试覆盖稳定和预览的更新选择、GitHub 授权请求和下载重定向。
- 模拟 GitHub 验证草稿发布为不可变 prerelease、复跑不再次改写、校验失败时拒绝。使用模拟数据完成这些验证。
