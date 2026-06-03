import AppKit

extension StatusItemController {
    func addBurnbadgeHero(to menu: NSMenu, width: CGFloat) {
        let item = self.makeMenuCardItem(
            BurnbadgeHeroView(width: width),
            id: "burnbadgeHero",
            width: width,
            onClick: { [weak self, weak menu] in
                guard let self, let menu else { return }
                menu.cancelTrackingWithoutAnimation()
                self.forgetClosedMenu(menu)
                self.showSettingsBurnbadge()
            })
        item.toolTip = "Create a shareable Burnbadge for your AI usage"
        menu.addItem(item)
    }
}
