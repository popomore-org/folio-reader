# Progress

## Current

- Status: 本机旧注册已清理，设置及首次启动已通过隔离原生验证。
- Blockers: 无。系统启用开关当前关闭。
- Next: 更新 PR，等待当前 CI，并制作本地安装镜像。
- Branch/PR: fix/folio-release-toolchain / Folio #5。
- Runtime/Follow-up: 未要求新建原生目标，本次执行内完成代码交付。

## Plan

| Work | Done when | Status |
| --- | --- | --- |
| 清理 | macOS 仅保留当前 Folio 注册 | complete |
| 设置 | 按包路径识别注册，入口和首次启动通过验证 | complete |
| PR | 当前 CI 和 Meta 合并入口通过 | active |

## Steps

### Step 1 — 2026-11-16 — 清理本机 Folio 注册

- 按 Folio 标识核对系统记录后移除 4 条旧 Quick Look 登记和关联的 Launch Services 记录。重查仅有 /Applications/Folio.app 及其 Quick Look 扩展。
- 当前登记的系统选用状态为关闭。保留该选择。

### Step 2 — 2026-11-16 — 实现并在隔离应用中验收

- macOS 27.0.1 首次打开进入 Quick Look 设置，正常重启直接进入工作区。设置按钮到达系统的登录项与扩展页。
- 实际让隔离扩展处于未注册状态，点注册后回到已注册，原系统关闭选择仍保留。自动化测试校验读取、重复注册、部分清理和注册冲突路径。
- 验证结束撤销隔离测试注册。机器的 Quick Look 仅保留当前 /Applications/Folio.app。
