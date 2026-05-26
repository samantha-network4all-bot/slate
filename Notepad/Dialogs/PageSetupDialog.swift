import AppKit

class PageSetupDialog: NSWindowController {
    private var contentStackView: NSStackView!
    private var paperSizePopup: NSPopUpButton!
    private var sourcePopup: NSPopUpButton!
    private var portraitRadio: NSButton!
    private var landscapeRadio: NSButton!
    private var leftMarginField: NSTextField!
    private var rightMarginField: NSTextField!
    private var topMarginField: NSTextField!
    private var bottomMarginField: NSTextField!
    private var headerField: NSTextField!
    private var footerField: NSTextField!
    private var previewView: NSView!
    
    private var okButton: NSButton!
    private var cancelButton: NSButton!
    
    // Current values
    private var paperSize: String = "Letter"
    private var source: String = "Automatic"
    private var orientation: String = "Portrait"
    private var leftMargin: Double = 19.1
    private var rightMargin: Double = 19.1
    private var topMargin: Double = 19.1
    private var bottomMargin: Double = 19.1
    private var header: String = "&f"
    private var footer: String = "Page &p"

    init() {
        super.init(window: nil)
        setupWindow()
        setupUI()
        loadSavedValues()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
    }
    
    private func setupWindow() {
        let window = NSWindow(
            contentRect: NSMakeRect(0, 0, 480, 460),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        
        window.title = "Page Setup"
        window.titlebarAppearsTransparent = true
        window.isOpaque = false
        window.backgroundColor = .clear
        
        let contentView = NSView()
        window.contentView = contentView
        
        self.window = window
    }
    
    private func setupUI() {
        let window = self.window!
        let contentView = window.contentView!
        
        // Create main stack view
        contentStackView = NSStackView(frame: NSRect(x: 20, y: 20, width: 440, height: 420))
        contentStackView.orientation = .vertical
        contentStackView.spacing = 16
        contentStackView.alignment = .left
        contentStackView.distribution = .fill
        contentView.addSubview(contentStackView)
        
        setupPaperControls()
        setupOrientationControls()
        setupMarginControls()
        setupHeaderFooterControls()
        setupPreview()
        setupButtons()
        setupLegend()
    }
    
    private func setupPaperControls() {
        let paperGroup = NSStackView()
        paperGroup.orientation = .vertical
        paperGroup.spacing = 8
        
        let paperLabel = NSTextField(labelWithString: "Paper")
        paperLabel.font = Fonts.dialogTitle
        paperGroup.addArrangedSubview(paperLabel)
        
        let paperRow = NSStackView()
        paperRow.orientation = .horizontal
        paperRow.spacing = 8
        
        paperSizePopup = NSPopUpButton(frame: NSRect(x: 0, y: 0, width: 150, height: 24))
        paperSizePopup.addItems(withTitles: ["Letter", "A4", "Legal"])
        paperSizePopup.target = self
        paperSizePopup.action = #selector(paperSizeChanged)
        paperRow.addArrangedSubview(paperSizePopup)
        
        sourcePopup = NSPopUpButton(frame: NSRect(x: 0, y: 0, width: 150, height: 24))
        sourcePopup.addItems(withTitles: ["Automatic"])
        sourcePopup.target = self
        sourcePopup.action = #selector(sourceChanged)
        paperRow.addArrangedSubview(sourcePopup)
        
        paperGroup.addArrangedSubview(paperRow)
        contentStackView.addArrangedSubview(paperGroup)
    }
    
    private func setupOrientationControls() {
        let orientationGroup = NSStackView()
        orientationGroup.orientation = .vertical
        orientationGroup.spacing = 8
        
        let orientationLabel = NSTextField(labelWithString: "Orientation")
        orientationLabel.font = Fonts.dialogTitle
        orientationGroup.addArrangedSubview(orientationLabel)
        
        let orientationRow = NSStackView()
        orientationRow.orientation = .horizontal
        orientationRow.spacing = 16
        
        portraitRadio = NSButton(radioButtonWithTitle: "Portrait", target: self, action: #selector(orientationChanged))
        portraitRadio.state = .on
        orientationRow.addArrangedSubview(portraitRadio)
        
        landscapeRadio = NSButton(radioButtonWithTitle: "Landscape", target: self, action: #selector(orientationChanged))
        orientationRow.addArrangedSubview(landscapeRadio)
        
        orientationGroup.addArrangedSubview(orientationRow)
        contentStackView.addArrangedSubview(orientationGroup)
    }
    
    private func setupMarginControls() {
        let marginGroup = NSStackView()
        marginGroup.orientation = .vertical
        marginGroup.spacing = 8
        
        let marginLabel = NSTextField(labelWithString: "Margins (millimeters)")
        marginLabel.font = Fonts.dialogTitle
        marginGroup.addArrangedSubview(marginLabel)
        
        var leftMarginField: NSTextField!
        var rightMarginField: NSTextField!
        var topMarginField: NSTextField!
        var bottomMarginField: NSTextField!
        
        let margins = [
            (field: leftMarginField, label: "Left", value: leftMargin),
            (field: rightMarginField, label: "Right", value: rightMargin),
            (field: topMarginField, label: "Top", value: topMargin),
            (field: bottomMarginField, label: "Bottom", value: bottomMargin)
        ]
        
        for (fieldVar, label, value) in margins {
            let field = NSTextField(frame: NSRect(x: 0, y: 0, width: 80, height: 24))
            field.isEditable = true
            field.isBordered = true
            field.font = Fonts.dialogLabel
            field.alignment = .right
            field.stringValue = String(format: "%.1f", value)
            field.target = self
            field.action = #selector(marginFieldChanged)
            field.tag = margins.firstIndex(where: { $0.0 === fieldVar }) ?? 0
            
            switch fieldVar {
            case leftMarginField: leftMarginField = field
            case rightMarginField: rightMarginField = field
            case topMarginField: topMarginField = field
            case bottomMarginField: bottomMarginField = field
            default: break
            }
            
            let labelField = NSTextField(labelWithString: label)
            labelField.font = Fonts.dialogLabel
            
            let row = NSStackView()
            row.orientation = .horizontal
            row.spacing = 8
            row.addArrangedSubview(labelField)
            row.addArrangedSubview(field)
            marginGroup.addArrangedSubview(row)
        }
        
        contentStackView.addArrangedSubview(marginGroup)
    }
    
    private func setupHeaderFooterControls() {
        let headerGroup = NSStackView()
        headerGroup.orientation = .vertical
        headerGroup.spacing = 8
        
        let headerLabel = NSTextField(labelWithString: "Header")
        headerLabel.font = Fonts.dialogTitle
        headerGroup.addArrangedSubview(headerLabel)
        
        headerField = NSTextField(frame: NSRect(x: 0, y: 0, width: 300, height: 24))
        headerField.isEditable = true
        headerField.isBordered = true
        headerField.font = Fonts.dialogLabel
        headerField.stringValue = header
        headerField.target = self
        headerField.action = #selector(headerFooterChanged)
        headerField.tag = 0
        headerGroup.addArrangedSubview(headerField)
        
        let footerLabel = NSTextField(labelWithString: "Footer")
        footerLabel.font = Fonts.dialogTitle
        headerGroup.addArrangedSubview(footerLabel)
        
        footerField = NSTextField(frame: NSRect(x: 0, y: 0, width: 300, height: 24))
        footerField.isEditable = true
        footerField.isBordered = true
        footerField.font = Fonts.dialogLabel
        footerField.stringValue = footer
        footerField.target = self
        footerField.action = #selector(headerFooterChanged)
        footerField.tag = 1
        headerGroup.addArrangedSubview(footerField)
        
        contentStackView.addArrangedSubview(headerGroup)
    }
    
    private func setupPreview() {
        let previewLabel = NSTextField(labelWithString: "Preview")
        previewLabel.font = Fonts.dialogTitle
        contentStackView.addArrangedSubview(previewLabel)
        
        previewView = NSView(frame: NSRect(x: 0, y: 0, width: 120, height: 160))
        previewView.wantsLayer = true
        previewView.layer?.borderColor = Colors.chromeBorderHeavy.cgColor
        previewView.layer?.borderWidth = 1.0
        previewView.layer?.backgroundColor = Colors.chromeBackground.cgColor
        contentStackView.addArrangedSubview(previewView)
    }
    
    private func setupButtons() {
        let buttonRow = NSStackView()
        buttonRow.orientation = .horizontal
        buttonRow.spacing = 8
        buttonRow.alignment = .right
        
        okButton = NSButton(frame: NSRect(x: 0, y: 0, width: 75, height: 23))
        okButton.title = "OK"
        okButton.target = self
        okButton.action = #selector(okClicked)
        okButton.keyEquivalent = "\r"
        okButton.keyEquivalent = "\r"
        buttonRow.addArrangedSubview(okButton)
        
        cancelButton = NSButton(frame: NSRect(x: 0, y: 0, width: 75, height: 23))
        cancelButton.title = "Cancel"
        cancelButton.target = self
        cancelButton.action = #selector(cancelClicked)
        cancelButton.keyEquivalent = "\u{1b}"
        cancelButton.keyEquivalent = "\u{1b}"
        buttonRow.addArrangedSubview(cancelButton)
        
        contentStackView.addArrangedSubview(buttonRow)
    }
    
    private func setupLegend() {
        let legendText = "&f filename, &p page number, &d date, &t time, && literal ampersand"
        let legendLabel = NSTextField(labelWithString: legendText)
        legendLabel.font = Fonts.dialogLabel
        legendLabel.textColor = Colors.chromeTextInactive
        legendLabel.alignment = .center
        contentStackView.addArrangedSubview(legendLabel)
    }
    
    private func loadSavedValues() {
        let defaults = UserDefaults.standard
        
        paperSize = defaults.string(forKey: "pageSetup.paperSize") ?? "Letter"
        source = defaults.string(forKey: "pageSetup.source") ?? "Automatic"
        orientation = defaults.string(forKey: "pageSetup.orientation") ?? "Portrait"
        leftMargin = defaults.double(forKey: "pageSetup.leftMargin")
        rightMargin = defaults.double(forKey: "pageSetup.rightMargin")
        topMargin = defaults.double(forKey: "pageSetup.topMargin")
        bottomMargin = defaults.double(forKey: "pageSetup.bottomMargin")
        header = defaults.string(forKey: "pageSetup.header") ?? "&f"
        footer = defaults.string(forKey: "pageSetup.footer") ?? "Page &p"
        
        updateUI()
    }
    
    private func updateUI() {
        paperSizePopup.selectItem(withTitle: paperSize)
        sourcePopup.selectItem(withTitle: source)
        
        portraitRadio.state = (orientation == "Portrait") ? .on : .off
        landscapeRadio.state = (orientation == "Landscape") ? .on : .off
        
        leftMarginField.stringValue = String(format: "%.1f", leftMargin)
        rightMarginField.stringValue = String(format: "%.1f", rightMargin)
        topMarginField.stringValue = String(format: "%.1f", topMargin)
        bottomMarginField.stringValue = String(format: "%.1f", bottomMargin)
        
        headerField.stringValue = header
        footerField.stringValue = footer
    }
    
    @objc private func paperSizeChanged() {
        paperSize = paperSizePopup.titleOfSelectedItem ?? "Letter"
    }
    
    @objc private func sourceChanged() {
        source = sourcePopup.titleOfSelectedItem ?? "Automatic"
    }
    
    @objc private func orientationChanged() {
        orientation = portraitRadio.state == .on ? "Portrait" : "Landscape"
    }
    
    @objc private func marginFieldChanged(_ sender: NSTextField) {
        let value = Double(sender.stringValue) ?? 19.1
        switch sender.tag {
        case 0: leftMargin = value
        case 1: rightMargin = value
        case 2: topMargin = value
        case 3: bottomMargin = value
        default: break
        }
    }
    
    @objc private func headerFooterChanged(_ sender: NSTextField) {
        if sender.tag == 0 {
            header = sender.stringValue
        } else {
            footer = sender.stringValue
        }
    }
    
    @objc private func okClicked() {
        saveValues()
        window?.sheetParent?.endSheet(window!)
    }
    
    @objc private func cancelClicked() {
        window?.sheetParent?.endSheet(window!)
    }
    
    private func saveValues() {
        let defaults = UserDefaults.standard
        defaults.set(paperSize, forKey: "pageSetup.paperSize")
        defaults.set(source, forKey: "pageSetup.source")
        defaults.set(orientation, forKey: "pageSetup.orientation")
        defaults.set(leftMargin, forKey: "pageSetup.leftMargin")
        defaults.set(rightMargin, forKey: "pageSetup.rightMargin")
        defaults.set(topMargin, forKey: "pageSetup.topMargin")
        defaults.set(bottomMargin, forKey: "pageSetup.bottomMargin")
        defaults.set(header, forKey: "pageSetup.header")
        defaults.set(footer, forKey: "pageSetup.footer")
        defaults.synchronize()
    }
}
