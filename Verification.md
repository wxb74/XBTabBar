# 验证记录

## iPhone Duo 适配（main）— 2026-10-22

- 工具链：Xcode 27.1（27A9275）、iOS Simulator 27.1 SDK；CocoaPods 1.16.2，本地 XBTabBar Pod 和 Masonry 1.1.0。
- `pod install --no-repo-update` 成功，`Podfile.lock` 未变化；最低部署目标仍为 iOS 15。
- `build-for-testing` 成功，包含 arm64 / x86_64 模拟器构建、Objective-C 与 Swift 接入编译。
- iPhone Duo / iOS 27.1：**29 项测试通过，0 失败**（22 项组件回归 + 7 项 Demo 集成检查）。
- iPhone 18 Pro / iOS 27.0：**29 项测试通过，0 失败**，验证旧运行系统的兼容性。
- 另使用 Xcode 27.0（27A266a）、iOS Simulator 27.0 SDK 完成 `build-for-testing`，验证新系统 API 的编译保护及旧 SDK 回退路径。
- 新增 9 项组件回归覆盖自动位置解析、左右切换与业务边距恢复、缺图文字回退、重排 / 行高变化后选中项可见、整行及宽度边界、重新出现时清理过期键盘帧、按钮身份和状态保留、纵向溢出滚动，以及侧栏外观复制隔离。
- Demo 18 个目录入口及原 7 项导航、交互、解码和 Swift 集成检查继续通过；检查了 Duo 本轮集成测试生成的页面截图。历史截图仍保留在 Documentation，不作为完整 Duo 姿态验证记录。
- 组件与 Demo 源码无编译警告，第三方 Masonry 仍有原有 SDK 弃用 / noescape / 调试字典提示；构建工具的 AppIntents 元数据提示不影响结果。

本轮自动检查未覆盖所有折叠姿态与 Split View 组合，也未逐项触发真实键盘和系统保留区域变化；这些路径仍需实际体验回归。没有 iOS 15 运行验证。`v0.1.0` 标签保持不变，以上适配从 `main` 获取。

## Demo 0.2.0 / v0.1.0 历史验证

日期：2026-10-21（Asia/Shanghai）。组件源码保持 0.1.0。

- 工具链：Xcode 27.0（27A266a）、iOS Simulator 27.0 SDK。
- CocoaPods workspace 的 `build-for-testing` 成功，包含 arm64 / x86_64 模拟器构建、Swift 的 `import XBTabBar` 与 Objective-C 工厂调用。
- `pod install --no-repo-update` 成功：本地 XBTabBar 0.1.0、Masonry 1.1.0；`pod lib lint --quick --allow-warnings` 通过。
- 项目已移除 Vendor/Masonry，源码不再手工参与 App 编译；Masonry 由 podspec 依赖安装。
- Demo / XBTabBar / Tests 分组各自保存目录路径，文件引用保存实际文件名。
- 运行环境：iPhone 18 Pro / iOS 27.0。
- **20 项测试通过，0 失败**：13 项原组件测试 + 7 项扩展 Demo 集成检查。
- 目录含四个分组、18 个独立入口；检查标识唯一、图标可加载及所有入口可构建和布局。
- 每个专题控制项实际执行，空配置和纯 Action 可恢复；检查静默选择、拦截、单项恢复继承、重排 / 重建保持选择。
- 检查目录 cell 全屏打开底栏示例及返回、push 独立按钮栏示例及返回。
- 实际打开解码和 Swift 创建的容器，验证其页面已经展示。
- 运行截图见 [Documentation/README.md](Documentation/README.md)；截图来自模拟器测试中实际展示的界面，不加入 App 资源。
- Demo / XBTabBar 代码无本轮构建编译警告。Masonry 仍有当前 SDK 下的原有弃用、noescape 和调试字典重复 key 提示，未修改第三方源码。

测试文件：`Tests/XBTabBarTests.m`、`Tests/XBDemoCatalogTests.m`。执行 `pod install` 并打开 `XBTabBarDemo.xcworkspace`，可在 Xcode 中按 ⌘U 重新运行全部检查，仓库不包含派生产物。

## 验证边界

自动检查覆盖入口、主要状态和导航进入 / 返回。交互返回取消、自定义导航转场、iPad / 旋转 / 极窄窗口、VoiceOver 和系统偏好切换仍需人工回归。当前没有 iOS 15 模拟器运行环境，最低版本完成部署目标构建，尚未在 iOS 15 运行。
