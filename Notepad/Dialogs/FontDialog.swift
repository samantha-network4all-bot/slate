import AppKit

// MARK: - Simple table view data sources using arrays

protocol TableDataSource {
    var items: [String] { get }
    func numberOfRows(in tableView: NSTableView) -> Int
    func tableView(_ tableView: NSTableView, titleFor column: NSUserInterfaceItemIdentifier, row: Int) -> String
}

// MARK: - Font Dialog

class FontDialog: NSWindowController, NSTextFieldDelegate, NSTableViewDataSource, NSTableViewDelegate {
    
    // MARK: - State
    private var allFamilies: [String] = []
    private var currentFamily: String = "Menlo"
    private var currentStyle: String = "Regular"
    private var currentSize: Int = 11
    
    // MARK: - UI Elements
    private var fontFamilyTextField: NSTextField!
    private var fontFamilyTableView: NSTableView!
    private var fontFamilyScrollView: NSScrollView!
    private var fontStyleTextField: NSTextField!
    private var fontStyleTableView: NSTableView!
    private var fontStyleScrollView: NSScrollView!
    private var fontSizeTextField: NSTextField!
    private var fontSizeTableView: NSTableView!
    private var fontSizeScrollView: NSScrollView!
    private var sampleView: NSView!
    private var sampleLabel: NSTextField!
    private var okButton: NSButton!
    private var cancelButton: NSButton!
    
    // Keyboard monitor
    private var monitor: Any?
    
    // Editor references
    private var editors: [EditorView] = []
    
    // Available sizes
    private let fontSizes = [8, 9, 10, 11, 12, 14, 16, 18, 20, 22, 24, 26, 28, 36, 48, 72]
    
    // Style data source for current family
    private var familyStyles: [String] = ["Regular"]
    
    // MARK: - Init
    
    init(editors: [EditorView]) {
        self.editors = editors
        
        // Get all families sorted
        self.allFamilies = Array(NSFontManager.shared.availableFontFamilies).sorted()
        
        // Determine initial selections
        if let firstEditor = editors.first, let font = firstEditor.font {
            self.currentFamily = font.familyName ?? "Menlo"
            self.currentSize = Int(font.pointSize)
        }
        
        // Try to load from UserDefaults
        if let data = UserDefaults.standard.data(forKey: "editor.font"),
           let font = NSKeyedUnarchiver.unarchiveObject(with: data) as? NSFont {
            self.currentFamily = font.familyName ?? self.currentFamily
            self.currentSize = Int(font.pointSize)
        }
        
        super.init(window: nil)
        
        setupWindow()
        setupUI()
        selectFamily(currentFamily)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    // MARK: - Window Setup
    
    private func setupWindow() {
        let window = DialogWindow(
            contentRect: NSRect(x: 0, y: 0, width: 480, height: 360),
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )
        window.title = "Font"
        self.window = window
    }
    
    // MARK: - UI Setup
    
    private func setupUI() {
        guard let window = window else { return }
        
        let w: CGFloat = 480
        let h: CGFloat = 360
        let titleH = Metrics.titleBarHeight
        
        // Content view
        let contentView = NSView(frame: window.contentRect(forFrameRect: window.frame))
        window.contentView = contentView
        
        // Custom title bar
        let titleBar = TitleBarView(frame: NSRect(
            x: 0, y: h - titleH, width: w, height: titleH
        ))
        titleBar.parentWindow = window
        titleBar.setTitle("Font")
        if let closeBtn = titleBar.subviews.compactMap({ $0 as? TitleBarButton }).first(where: { $0.buttonType == .close }) {
            closeBtn.onAction = { [weak window] in window?.close() }
        }
        contentView.addSubview(titleBar)
        
        let contentTop = h - titleH
        
        // Column positions
        let col1X: CGFloat = 12
        let col2X: CGFloat = 204
        let col3X: CGFloat = 316
        let colW: CGFloat = 152
        let tableH = contentTop - 136
        let btnY: CGFloat = 8
        
        // ===== COLUMN 1: Font Family =====
        let famLabel = makeLabel("Font:", x: col1X, y: contentTop - 24)
        contentView.addSubview(famLabel)
        
        fontFamilyTextField = NSTextField(frame: NSRect(x: col1X, y: contentTop - 46, width: colW, height: 22))
        configureTextField(fontFamilyTextField)
        fontFamilyTextField.isSelectable = true
        contentView.addSubview(fontFamilyTextField)
        
        fontFamilyScrollView = makeScrollView(col1X, y: 60, w: colW, h: tableH)
        fontFamilyTableView = makeTableView()
        fontFamilyTableView.dataSource = self
        fontFamilyTableView.delegate = self
        fontFamilyTableView.columnAutoresizingStyle = .firstColumnOnlyAutoresizingStyle
        let famCol = makeColumn("family", width: colW)
        fontFamilyTableView.addTableColumn(famCol)
        fontFamilyScrollView.documentView = fontFamilyTableView
        contentView.addSubview(fontFamilyScrollView)
        
        // ===== COLUMN 2: Font Style =====
        let styLabel = makeLabel("Style:", x: col2X, y: contentTop - 24)
        contentView.addSubview(styLabel)
        
        fontStyleTextField = NSTextField(frame: NSRect(x: col2X, y: contentTop - 46, width: 90, height: 22))
        configureTextField(fontStyleTextField)
        fontStyleTextField.isSelectable = true
        contentView.addSubview(fontStyleTextField)
        
        fontStyleScrollView = makeScrollView(col2X, y: 60, w: 90, h: tableH)
        fontStyleTableView = makeTableView()
        fontStyleTableView.dataSource = self
        fontStyleTableView.delegate = self
        fontStyleTableView.columnAutoresizingStyle = .firstColumnOnlyAutoresizingStyle
        let styCol = makeColumn("style", width: 90)
        fontStyleTableView.addTableColumn(styCol)
        fontStyleScrollView.documentView = fontStyleTableView
        contentView.addSubview(fontStyleScrollView)
        
        // ===== COLUMN 3: Font Size =====
        let szLabel = makeLabel("Size:", x: col3X, y: contentTop - 24)
        contentView.addSubview(szLabel)
        
        fontSizeTextField = NSTextField(frame: NSRect(x: col3X, y: contentTop - 46, width: colW, height: 22))
        configureTextField(fontSizeTextField)
        fontSizeTextField.isSelectable = true
        contentView.addSubview(fontSizeTextField)
        
        fontSizeScrollView = makeScrollView(col3X, y: 60, w: colW, h: tableH)
        fontSizeTableView = makeTableView()
        fontSizeTableView.dataSource = self
        fontSizeTableView.delegate = self
        fontSizeTableView.columnAutoresizingStyle = .firstColumnOnlyAutoresizingStyle
        let szCol = makeColumn("size", width: colW)
        fontSizeTableView.addTableColumn(szCol)
        fontSizeScrollView.documentView = fontSizeTableView
        contentView.addSubview(fontSizeScrollView)
        
        // ===== SAMPLE BOX =====
        sampleView = NSView(frame: NSRect(x: 12, y: 32, width: 280, height: 60))
        sampleView.wantsLayer = true
        sampleView.layer?.backgroundColor = Colors.chromeBackground.cgColor
        sampleView.layer?.borderWidth = 1
        sampleView.layer?.borderColor = Colors.chromeBorderHeavy.cgColor
        contentView.addSubview(sampleView)
        
        sampleLabel = NSTextField(labelWithString: "AaBbYyZz")
        sampleLabel.frame = sampleView.bounds.insetBy(dx: 4, dy: 4)
        sampleLabel.font = Fonts.editorDefault
        sampleLabel.textColor = Colors.chromeText
        sampleLabel.alignment = .center
        sampleLabel.isEditable = false
        sampleLabel.isBordered = false
        sampleLabel.focusRingType = .none
        sampleView.addSubview(sampleLabel)
        
        // ===== BUTTONS =====
        let btnW: CGFloat = 75
        okButton = makeButton("OK", x: w - 8 - btnW, y: btnY, w: btnW, h: 23)
        okButton.target = self
        okButton.action = #selector(okClicked)
        okButton.wantsLayer = true
        okButton.layer?.borderWidth = 2
        okButton.layer?.borderColor = Colors.selectionBg.cgColor
        contentView.addSubview(okButton)
        
        cancelButton = makeButton("Cancel", x: w - 8 - btnW - 8 - btnW, y: btnY, w: btnW, h: 23)
        cancelButton.target = self
        cancelButton.action = #selector(cancelClicked)
        contentView.addSubview(cancelButton)
        
        // Keyboard shortcuts
        setupKeyboardShortcuts()
    }
    
    // MARK: - Helpers
    
    private func makeLabel(_ text: String, x: CGFloat, y: CGFloat) -> NSTextField {
        let label = NSTextField(labelWithString: text)
        label.frame = NSRect(x: x, y: y, width: 60, height: 18)
        label.font = Fonts.dialogLabel
        label.textColor = Colors.chromeText
        return label
    }
    
    private func configureTextField(_ field: NSTextField) {
        field.font = Fonts.dialogLabel
        field.textColor = Colors.chromeText
        field.backgroundColor = Colors.chromeBackground
        field.isBordered = false
        field.focusRingType = .none
    }
    
    private func makeScrollView(_ x: CGFloat, y: CGFloat, w: CGFloat, h: CGFloat) -> NSScrollView {
        let sv = NSScrollView(frame: NSRect(x: x, y: y, width: w, height: h))
        sv.hasVerticalScroller = true
        sv.backgroundColor = Colors.chromeBackground
        return sv
    }
    
    private func makeTableView() -> NSTableView {
        let tv = NSTableView(frame: .zero)
        tv.rowHeight = 20
        tv.allowsMultipleSelection = false
        return tv
    }
    
    private func makeColumn(_ id: String, width: CGFloat) -> NSTableColumn {
        let col = NSTableColumn(identifier: NSUserInterfaceItemIdentifier(id))
        col.title = id.capitalized
        col.width = width
        return col
    }
    
    private func makeButton(_ title: String, x: CGFloat, y: CGFloat, w: CGFloat, h: CGFloat) -> NSButton {
        let btn = NSButton(frame: NSRect(x: x, y: y, width: w, height: h))
        btn.title = title
        btn.font = Fonts.dialogLabel
        btn.alignment = .center
        btn.bezelStyle = .regularSquare
        btn.isBordered = false
        return btn
    }
    
    private func setupKeyboardShortcuts() {
        monitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event -> NSEvent? in
            guard let self = self, let win = self.window, win.isKeyWindow else { return event }
            let ch = event.characters?.lowercased()
            if ch == "\r" || ch == "\n" {
                self.okClicked(nil)
                return nil
            } else if ch == "\u{1b}" {
                self.cancelClicked(nil)
                return nil
            }
            return event
        }
    }
    
    // MARK: - Selection
    
    private func selectFamily(_ family: String) {
        currentFamily = family
        fontFamilyTextField.stringValue = family
        
        // Build available styles for this family
        familyStyles = buildStylesForFamily(family)
        
        // Update style table view
        fontStyleTableView.reloadData()
        if familyStyles.count > 0 {
            currentStyle = familyStyles[0]
            fontStyleTextField.stringValue = currentStyle
            // Select first row
            fontStyleTableView.selectRowIndexes(IndexSet(integer: 0), byExtendingSelection: false)
        }
        
        updateSample()
    }
    
    private func buildStylesForFamily(_ family: String) -> [String] {
        var styles: [String] = ["Regular"]
        _ = NSFontManager.shared
        
        // We check if a bold variant exists by looking for a font name that differs
        let regularDesc = NSFontDescriptor(fontAttributes: [.name: family, .size: 12.0])
        let boldDesc = regularDesc.withSymbolicTraits(.bold)
        let italicDesc = regularDesc.withSymbolicTraits(.italic)
        let boldItalicDesc = regularDesc.withSymbolicTraits([.bold, .italic])
        
        // Bold exists if the bold descriptor produces a different font
        if let _ = NSFont(descriptor: boldDesc, size: 12) {
            let regularFont = NSFont(descriptor: regularDesc, size: 12)
            let boldFont = NSFont(descriptor: boldDesc, size: 12)
            if let rf = regularFont, let bf = boldFont, rf.fontName != bf.fontName {
                styles.append("Bold")
            }
        }
        
        if let _ = NSFont(descriptor: italicDesc, size: 12) {
            styles.append("Italic")
        }
        
        if let _ = NSFont(descriptor: boldItalicDesc, size: 12) {
            styles.append("Bold Italic")
        }
        
        return styles
    }
    
    private func fontForSelection() -> NSFont {
        let baseDesc = NSFontDescriptor(name: currentFamily, size: CGFloat(currentSize))
        var traits: NSFontDescriptor.SymbolicTraits = []
        switch currentStyle {
        case "Bold": traits.insert(.bold)
        case "Italic": traits.insert(.italic)
        case "Bold Italic": traits.insert([.bold, .italic])
        default: break
        }
        let desc = baseDesc.withSymbolicTraits(traits)
        return NSFont(descriptor: desc, size: CGFloat(currentSize)) ?? Fonts.editorDefault
    }
    
    private func updateSample() {
        sampleLabel.font = fontForSelection()
    }
    
    // MARK: - Actions
    
    @objc private func okClicked(_ sender: Any?) {
        let font = fontForSelection()
        applyFontToAllEditors(font)
        
        // Persist to UserDefaults
        do {
            let data = try NSKeyedArchiver.archivedData(withRootObject: font, requiringSecureCoding: false)
            UserDefaults.standard.set(data, forKey: "editor.font")
        } catch {
            // Best effort
        }
        
        window?.close()
    }
    
    private func applyFontToAllEditors(_ font: NSFont) {
        for editor in editors {
            let range = editor.selectedRange()
            editor.font = font
            editor.setSelectedRange(range)
        }
    }
    
    @objc private func cancelClicked(_ sender: Any?) {
        window?.close()
    }
    
    // MARK: - NSTableViewDataSource
    
    nonisolated func tableView(_ tableView: NSTableView, objectValueFor column: NSUserInterfaceItemIdentifier?, row: Int) -> Any? {
        let colId = column?.rawValue ?? ""
        switch colId {
        case "family":
            return allFamilies[row]
        case "style":
            return familyStyles[row]
        case "size":
            return "\(fontSizes[row])"
        default:
            return ""
        }
    }
    
    nonisolated func tableView(_ tableView: NSTableView, numberOfRowsIn section: Int) -> Int {
        let colId = tableView.tableColumns.first?.identifier.rawValue ?? ""
        switch colId {
        case "family":
            return allFamilies.count
        case "style":
            return familyStyles.count
        case "size":
            return fontSizes.count
        default:
            return 0
        }
    }
    
    // MARK: - NSTableViewDataSource
    
    func tableView(_ tableView: NSTableView, objectValueFor tableColumn: NSTableColumn?, row: Int) -> Any? {
        guard let colId = tableColumn?.identifier.rawValue else { return "" }
        switch colId {
        case "family":
            return allFamilies[row]
        case "style":
            return familyStyles[row]
        case "size":
            return String(fontSizes[row])
        default:
            return ""
        }
    }
    
    func numberOfRows(in tableView: NSTableView) -> Int {
        let colId = tableView.tableColumns.first?.identifier.rawValue ?? ""
        switch colId {
        case "family":
            return allFamilies.count
        case "style":
            return familyStyles.count
        case "size":
            return fontSizes.count
        default:
            return 0
        }
    }
    
    // MARK: - NSTableViewDelegate
    
    func tableView(_ tableView: NSTableView, heightOfRow row: Int) -> CGFloat {
        return 20
    }
    
    func tableViewSelectionDidChange(_ notification: Notification) {
        guard let tv = notification.object as? NSTableView else { return }
        guard tv.selectedRow >= 0 else { return }
        
        let colId = tv.tableColumns.first?.identifier.rawValue ?? ""
        switch colId {
        case "family":
            selectFamily(allFamilies[tv.selectedRow])
        case "style":
            currentStyle = familyStyles[tv.selectedRow]
            fontStyleTextField.stringValue = currentStyle
            updateSample()
        case "size":
            currentSize = fontSizes[tv.selectedRow]
            fontSizeTextField.stringValue = "\(currentSize)"
            updateSample()
        default:
            break
        }
    }
    
    // MARK: - Public
    
    func show() {
        window?.makeKeyAndOrderFront(nil)
    }
}
