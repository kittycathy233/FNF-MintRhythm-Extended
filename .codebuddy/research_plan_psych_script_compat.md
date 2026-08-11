# Research Plan: KathyEngine (新版 Psych) 与 Psych 0.6.3 脚本系统兼容性

## 目标
分析当前 KathyEngine 项目（基于最新版 Psych Engine 改版）的 Lua/HScript 脚本支持，重点研究：
- `addHaxeLibrary` / `addHaxeClass` 等导入本地 Haxe 库/类到脚本命名空间的逻辑
- 脚本中 `import` 相关机制
- 暴露给脚本（Lua/HScript）的引擎类与全局名称

并对照旧版 Psych 0.6.3（`E:\EXTRA\FNF\ENGINE\PE\FNF-PsychEngine-0.6.3`）的脚本 API 差异，
最终给出让新版引擎兼容 0.6.3 模组的方案。

## 子任务（并行）
1. 探索 KathyEngine 当前脚本系统：定位 Lua/HScript 支持类、addHaxeLibrary 实现、类暴露方式、目录结构（source/psych 等）。
2. 探索 Psych 0.6.3 脚本系统：定位同样的实现，记录 0.6.3 暴露给脚本的类名/路径与全局命名。

## 信息检索策略
- 主要依赖本地代码探索（search_content / read_file / lsp / code-explorer 子代理）。
- 微信文章检索（wechat-article-search）不适用于本地源码分析，故不采用；若涉及 Psych Engine 社区迁移文档，可使用 web_search 作为补充。

## 预期产出
- 两份代码库脚本 API 的对照表（类名、路径、addHaxeLibrary 签名差异）
- 兼容性断点清单
- 具体兼容方案（shim 层 / 别名注册 / 兼容 include / 配置开关）
