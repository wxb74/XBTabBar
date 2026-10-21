import UIKit

/// 编入 Demo 的最小 Swift 接入样例，保证 Objective-C 接口可从 Swift 导入。
@MainActor
func makeSwiftTabExample() -> XBTabContainerViewController {
    let tabs = XBTabContainerViewController()
    let home = UINavigationController(rootViewController: UIViewController())
    let item = XBTabBarItem(identifier: "home", title: "首页",
                            image: UIImage(systemName: "house"), selectedImage: nil)
    tabs.setViewControllers([home], tabBarItems: [item])
    let appearance = tabs.tabBarAppearance
    appearance.selectedColor = .systemIndigo
    tabs.tabBarAppearance = appearance
    return tabs
}


/// 目录页真正调用的 Swift 工厂，用来体验 Swift 创建的容器。
@objc(XBSwiftExampleFactory)
@MainActor
final class XBSwiftExampleFactory: NSObject {
    @objc static func makeExample() -> XBTabContainerViewController {
        let tabs = makeSwiftTabExample()
        let navigation = tabs.viewControllers[0] as! UINavigationController
        let page = navigation.viewControllers[0]
        page.title = "Swift 创建成功"
        page.view.backgroundColor = .systemGroupedBackground
        let label = UILabel()
        label.text = "这个容器由 Swift 代码实际创建。\nObjective-C 通过公开工厂打开它。"
        label.numberOfLines = 0
        label.textAlignment = .center
        label.translatesAutoresizingMaskIntoConstraints = false
        page.view.addSubview(label)
        NSLayoutConstraint.activate([
            label.leadingAnchor.constraint(equalTo: page.view.leadingAnchor, constant: 20),
            label.trailingAnchor.constraint(equalTo: page.view.trailingAnchor, constant: -20),
            label.centerYAnchor.constraint(equalTo: page.view.safeAreaLayoutGuide.centerYAnchor)
        ])
        return tabs
    }
}
