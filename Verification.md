# Demo 0.2.0 验证记录

日期：2026-10-21（Asia/Shanghai）。组件源码保持 0.1.0。

- 工具链：Xcode 27.0（27A266a）、iOS Simulator 27.0 SDK。
- 独立 `build-for-testing` 成功，包含 arm64 / x86_64 模拟器构建、Swift 编译与 Objective-C 工厂调用。
- 运行环境：iPhone 18 Pro / iOS 27.0。
- **20 项测试通过，0 失败**：13 项原组件测试 + 7 项扩展 Demo 集成检查。
- 目录含四个分组、18 个独立入口；检查标识唯一、图标可加载及所有入口可构建和布局。
- 每个专题控制项实际执行，空配置和纯 Action 可恢复；检查静默选择、拦截、单项恢复继承、重排 / 重建保持选择。
- 检查目录 cell 全屏打开底栏示例及返回、push 独立按钮栏示例及返回。
- 实际打开解码和 Swift 创建的容器，验证其页面已经展示。
- 运行截图见 [Documentation/README.md](Documentation/README.md)；截图来自模拟器测试中实际展示的界面，不加入 App 资源。
- Demo / XBTabBar 代码无本轮构建编译警告。Masonry 仍有当前 SDK 下的原有弃用、noescape 和调试字典重复 key 提示，未修改第三方源码。

测试文件：`Tests/XBTabBarTests.m`、`Tests/XBDemoCatalogTests.m`。可在 Xcode 中按 ⌘U 重新运行全部检查，仓库不包含派生产物。

## 验证边界

自动检查覆盖入口、主要状态和导航进入 / 返回。交互返回取消、自定义导航转场、iPad / 旋转 / 极窄窗口、VoiceOver 和系统偏好切换仍需人工回归。当前没有 iOS 15 模拟器运行环境，最低版本完成部署目标构建，尚未在 iOS 15 运行。
