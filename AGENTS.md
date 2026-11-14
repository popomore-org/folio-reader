# Folio

- 遵循 [Meta 规范](https://github.com/popomore-org/meta/tree/main/docs/standards)，默认分支走 PR，合并前从当前可信 Meta checkout 运行只读合并检查。
- 修改阅读或保存链路时，从原生应用入口验收。使用 `scripts/build-macos`，验证时使用独立示例文件，保留预览 bundle 身份。
- `folio-core` 的公共入口由外部 Cargo 消费样例验证。平台预览和本地应用框架留在 macOS 层。
