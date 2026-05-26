import AppKit

class FileBrowserDialog: NSWindowController {
    private var currentPath: URL
    private var fileBrowserSidebar: FileBrowserSidebar!
    private var fileBrowserBreadcrumb: FileBrowserBreadcrumb!
    private var fileBrowserList: FileBrowserList!
    private var filterDropdown: NSPopUpButton!
    private var searchField: NSSearchField!
    private var fileNameField: NSTextField!
    private var fileOpenButton: NSButton!
    private var fileCancelButton: NSButton!
    private var encodingDropdown: NSPopUpButton?
    private var lineEndingDropdown: NSPopUpButton?
    private var isSaveAsMode = false
    private var documentEncoding: FileEncoding = .utf8
    private var documentLineEnding: LineEnding = .crlf
    
    private let windowWidth: CGFloat = 800
    private let windowHeight: CGFloat = 520
    
    enum LineEnding: String, CaseIterable {
        case crlf = "Windows (CRLF)"
        case lf = "Unix (LF)"
        case cr = "Macintosh (CR)"
        
        var displayString: String {
            switch self {
            case .crlf: return "Windows (CRLF)"
            case .lf: return "Unix (LF)"
            case .cr: return "Macintosh (CR)"
            }
        }
    }
    
    enum FileEncoding: String, CaseIterable {
        case utf8 = "UTF-8"
        case utf8WithBOM = "UTF-8 with BOM"
        case utf16LE = "UTF-16 LE"
        case utf16BE = "UTF-16 BE"
        
        var nsEncoding: String.Encoding {
            switch self {
            case .utf8: return .utf8
            case .utf8WithBOM: return .utf8
            case .utf16LE: return .utf16LittleEndian
            case .utf16BE: return .utf16BigEndian
            }
        }
    }
    
    var onFileSelected: ((URL, FileEncoding?, LineEnding?) -> Void)?
    var onFileOpen: ((URL) -> Void)?
    
    init(saveAsMode: Bool = false, initialPath: URL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!) {
        self.isSaveAsMode = saveAsMode
        self.currentPath = initialPath
        super.init(window: nil)
        setupWindow()
    }
    
    convenience init(saveAsMode: Bool = false, initialPath: URL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!, completion: @escaping (URL, FileEncoding?, LineEnding?) -> Void) {
        self.init(saveAsMode: saveAsMode, initialPath: initialPath)
        self.onFileSelected = { url, encoding, lineEnding in
            completion(url, encoding, lineEnding)
        }
    }
    
    convenience init(saveAsMode: Bool = false, completion: @escaping (URL) -> Void) {
        self.init(saveAsMode: saveAsMode)
        self.onFileOpen = completion
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private func setupWindow() {
        let contentRect = NSRect(x: 0, y: 0, width: windowWidth, height: windowHeight)
        let styleMask: NSWindow.StyleMask = [.borderless, .resizable, .miniaturizable]
        let window = DialogWindow(contentRect: contentRect, styleMask: styleMask, backing: .buffered, defer: false)
        
        window.title = isSaveAsMode ? "Save As" : "Open"
        window.isReleasedWhenClosed = false
        
        setupDialogView(in: window)
        self.window = window
    }
    
    private func setupDialogView(in window: NSWindow) {
        let contentView = window.contentView!
        contentView.wantsLayer = true
        contentView.layer?.backgroundColor = Colors.chromeBackground.cgColor
        
        // Title bar
        let titleBar = TitleBarView(frame: NSRect(x: 0, y: windowHeight - 32, width: windowWidth, height: 32))
        titleBar.setTitle(isSaveAsMode ? "Save As" : "Open")
        contentView.addSubview(titleBar)
        
        // Main content area
        let mainContentY = windowHeight - 32 - Metrics.titleBarHeight
        let mainContentHeight = mainContentY - Metrics.statusBarHeight
        
        // Top toolbar
        let toolbarY = mainContentY
        setupToolbar(at: toolbarY, height: 32, in: contentView)
        
        // Content area (sidebar + file list)
        let contentY = toolbarY - 32
        setupContentArea(at: contentY, height: contentHeight(), in: contentView)
        
        // Bottom panel (filename + buttons)
        setupBottomPanel(at: 0, height: Metrics.statusBarHeight, in: contentView)
        
        // Load initial directory
        loadDirectory(at: currentPath)
    }
    
    private func setupToolbar(at y: CGFloat, height: CGFloat, in contentView: NSView) {
        let toolbarView = NSView(frame: NSRect(x: 0, y: y, width: windowWidth, height: height))
        toolbarView.wantsLayer = true
        toolbarView.layer?.backgroundColor = Colors.chromeBackground.cgColor
        
        // Refresh button
        let refreshButton = NSButton(frame: NSRect(x: 10, y: 6, width: 20, height: 20))
        refreshButton.bezelStyle = .regularSquare
        refreshButton.image = NSImage(named: NSImage.refreshTemplateName)
        refreshButton.target = self
        refreshButton.action = #selector(refreshDirectory)
        toolbarView.addSubview(refreshButton)
        
        // Search field
        searchField = NSSearchField(frame: NSRect(x: 40, y: 4, width: 300, height: 24))
        searchField.placeholderString = "Search"
        searchField.target = self
        searchField.action = #selector(searchFiles)
        searchField.sendsWholeSearchString = false
        toolbarView.addSubview(searchField)
        
        // Filter dropdown
        filterDropdown = NSPopUpButton(frame: NSRect(x: 350, y: 4, width: 180, height: 24))
        filterDropdown.addItems(withTitles: ["Text Documents (*.txt)", "All Files (*.*)"])
        filterDropdown.target = self
        filterDropdown.action = #selector(filterChanged)
        toolbarView.addSubview(filterDropdown)
        
        contentView.addSubview(toolbarView)
    }
    
    private func setupContentArea(at y: CGFloat, height: CGFloat, in contentView: NSView) {
        let contentContainer = NSView(frame: NSRect(x: 0, y: y, width: windowWidth, height: height))
        
        // Sidebar (200px wide)
        fileBrowserSidebar = FileBrowserSidebar(frame: NSRect(x: 0, y: 0, width: 200, height: height))
        fileBrowserSidebar.onDirectorySelected = { [weak self] path in
            self?.navigate(to: path)
        }
        contentContainer.addSubview(fileBrowserSidebar)
        
        // Breadcrumb
        fileBrowserBreadcrumb = FileBrowserBreadcrumb(frame: NSRect(x: 210, y: height - 32, width: windowWidth - 210 - 200, height: 32))
        fileBrowserBreadcrumb.onPathSelected = { [weak self] path in
            self?.navigate(to: path)
        }
        contentContainer.addSubview(fileBrowserBreadcrumb)
        
        // File list
        fileBrowserList = FileBrowserList(frame: NSRect(x: 210, y: 0, width: windowWidth - 210 - 200, height: height - 32))
        fileBrowserList.onFileSelected = { [weak self] url in
            self?.fileNameField.stringValue = url.lastPathComponent
        }
        fileBrowserList.onFileOpen = { [weak self] url in
            self?.handleFileOpen(url: url)
        }
        contentContainer.addSubview(fileBrowserList)
        
        contentView.addSubview(contentContainer)
    }
    
    private func setupBottomPanel(at y: CGFloat, height: CGFloat, in contentView: NSView) {
        let bottomPanel = NSView(frame: NSRect(x: 0, y: y, width: windowWidth, height: height))
        bottomPanel.wantsLayer = true
        bottomPanel.layer?.backgroundColor = Colors.statusBarBg.cgColor
        
        // Filename field
        fileNameField = NSTextField(frame: NSRect(x: 10, y: 2, width: 400, height: 18))
        fileNameField.placeholderString = "File name"
        fileNameField.font = Fonts.dialogLabel
        bottomPanel.addSubview(fileNameField)
        
        // Additional controls for Save As mode
        if isSaveAsMode {
            // Encoding dropdown
            encodingDropdown = NSPopUpButton(frame: NSRect(x: 420, y: 2, width: 150, height: 18))
            encodingDropdown?.addItems(withTitles: FileEncoding.allCases.map { $0.rawValue })
            encodingDropdown?.target = self
            encodingDropdown?.action = #selector(encodingChanged)
            bottomPanel.addSubview(encodingDropdown ?? NSButton())
            
            // Line ending dropdown
            lineEndingDropdown = NSPopUpButton(frame: NSRect(x: 580, y: 2, width: 150, height: 18))
            lineEndingDropdown?.addItems(withTitles: LineEnding.allCases.map { $0.displayString })
            lineEndingDropdown?.target = self
            lineEndingDropdown?.action = #selector(lineEndingChanged)
            bottomPanel.addSubview(lineEndingDropdown ?? NSButton())
        }
        
        // Buttons
        let buttonY: CGFloat = 2
        let buttonWidth: CGFloat = 75
        let buttonHeight: CGFloat = 23
        let buttonSpacing: CGFloat = 8
        
        let openButtonX = windowWidth - buttonWidth - buttonSpacing - (isSaveAsMode ? buttonWidth + buttonSpacing : 0)
        fileOpenButton = NSButton(frame: NSRect(x: openButtonX, y: buttonY, width: buttonWidth, height: buttonHeight))
        fileOpenButton.bezelStyle = .rounded
        fileOpenButton.title = isSaveAsMode ? "Save" : "Open"
        fileOpenButton.target = self
        fileOpenButton.action = #selector(openFile)
        fileOpenButton.keyEquivalent = "\r"
        bottomPanel.addSubview(fileOpenButton)
        
        let cancelButtonX = openButtonX - buttonWidth - buttonSpacing
        fileCancelButton = NSButton(frame: NSRect(x: cancelButtonX, y: buttonY, width: buttonWidth, height: buttonHeight))
        fileCancelButton.bezelStyle = .rounded
        fileCancelButton.title = "Cancel"
        fileCancelButton.target = self
        fileCancelButton.action = #selector(cancelDialog)
        fileCancelButton.keyEquivalent = "\u{1b}" // Escape
        bottomPanel.addSubview(fileCancelButton)
        
        contentView.addSubview(bottomPanel)
    }
    
    private func contentHeight() -> CGFloat {
        return windowHeight - Metrics.titleBarHeight - 32 - Metrics.statusBarHeight // titlebar - toolbar - bottompanel
    }
    
    private func loadDirectory(at url: URL) {
        currentPath = url
        fileBrowserSidebar?.selectDirectory(at: url)
        fileBrowserBreadcrumb?.setPath(url)
        fileBrowserList?.loadDirectory(at: url)
    }
    
    private func navigate(to url: URL) {
        loadDirectory(at: url)
    }
    
    private func handleFileOpen(url: URL) {
        if isSaveAsMode {
            // For Save As, we still need to validate the filename
            let finalURL = currentPath.appendingPathComponent(fileNameField.stringValue)
            onFileSelected?(finalURL, documentEncoding, documentLineEnding)
        } else {
            onFileOpen?(url)
        }
        window?.close()
    }
    
    @objc private func refreshDirectory() {
        loadDirectory(at: currentPath)
    }
    
    @objc private func searchFiles() {
        let searchTerm = searchField.stringValue.lowercased()
        fileBrowserList?.filterFiles(searchTerm: searchTerm)
    }
    
    @objc private func filterChanged() {
        let filterText = filterDropdown?.titleOfSelectedItem ?? "All Files (*.*)"
        let isTextFilter = filterText.contains("*.txt")
        fileBrowserList?.setFilterTextOnly(isTextFilter)
    }
    
    @objc private func encodingChanged() {
        if let encodingTitle = encodingDropdown?.titleOfSelectedItem,
           let encoding = FileEncoding.allCases.first(where: { $0.rawValue == encodingTitle }) {
            documentEncoding = encoding
        }
    }
    
    @objc private func lineEndingChanged() {
        if let lineEndingTitle = lineEndingDropdown?.titleOfSelectedItem {
            let lineEnding = LineEnding.allCases.first(where: { $0.displayString == lineEndingTitle })
            documentLineEnding = lineEnding ?? .crlf
        }
    }
    
    @objc private func openFile() {
        let fileName = fileNameField.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
        if fileName.isEmpty {
            NSSound.beep()
            return
        }
        
        let finalURL = currentPath.appendingPathComponent(fileName)
        handleFileOpen(url: finalURL)
    }
    
    @objc private func cancelDialog() {
        window?.close()
    }
    
    func show() {
        window?.center()
        window?.makeKeyAndOrderFront(nil)
    }
}