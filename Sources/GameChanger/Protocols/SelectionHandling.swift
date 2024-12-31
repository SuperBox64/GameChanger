@preconcurrency protocol SelectionHandling: AnyObject {
    func moveLeft() async
    func moveRight() async
    func select(at index: Int) async
}

@MainActor
class SelectionHandler: SelectionHandling {
    private weak var viewModel: ContentViewModel?
    
    init(viewModel: ContentViewModel) {
        self.viewModel = viewModel
    }
    
    func moveLeft() async {
        viewModel?.moveLeft()
    }
    
    func moveRight() async {
        viewModel?.moveRight()
    }
    
    func select(at index: Int) async {
        viewModel?.selectedIndex = index
    }
} 