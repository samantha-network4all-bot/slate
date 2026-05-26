import AppKit

class FileBrowserList: NSView {
    private var files: [FileInfo] = []
    fileprivate var filteredFiles: [FileInfo] = []
    private var tableView: NSTableView!
    private var scrollView: NSScrollView!
    var onFileSelected: ((URL) -> Void)?
    var onFileOpen: ((URL) -> Void)?
    private var filterTextOnly: Bool = false
    private var searchTerm: String = ""
    
    override init(frame: NSRect) {
        super.init(frame: frame)
        setup()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private func setup() {
        wantsLayer = true
        layer?.backgroundColor = Colors.chromeBackground.cgColor
        
        setupScrollView()
        setupTableView()
    }
    
    private func setupScrollView() {
        scrollView = NSScrollView(frame: bounds)
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = false
        scrollView.autohidesScrollers = false
        scrollView.borderType = .noBorder
        scrollView.backgroundColor = Colors.chromeBackground
        addSubview(scrollView)
    }
    
    private func setupTableView() {
        tableView = FileBrowserTableView(frame: scrollView.bounds)
        tableView.dataSource = self
        tableView.delegate = self
        tableView.backgroundColor = Colors.chromeBackground
        tableView.headerView = nil
        tableView.selectionHighlightStyle = .regular
        tableView.gridStyleMask = [.solidHorizontalGridLineMask]
        scrollView.documentView = tableView
    }
    
    func loadDirectory(at url: URL) {
        do {
            let directoryContents = try FileManager.default.contentsOfDirectory(at: url, includingPropertiesForKeys: [.isDirectoryKey, .contentModificationDateKey], options: [.skipsHiddenFiles])
            
            files = directoryContents.map { fileURL in
                let resourceValues = try? fileURL.resourceValues(forKeys: [.isDirectoryKey, .contentModificationDateKey])
                let isDirectory = resourceValues?.isDirectory ?? false
                let modificationDate = resourceValues?.contentModificationDate ?? Date.distantPast
                
                return FileInfo(
                    url: fileURL,
                    name: fileURL.lastPathComponent,
                    isDirectory: isDirectory,
                    modificationDate: modificationDate,
                    size: nil // Could be added later if needed
                )
            }
            
            // Sort: directories first, then files, both alphabetically
            files.sort { first, second in
                if first.isDirectory && !second.isDirectory {
                    return true
                } else if !first.isDirectory && second.isDirectory {
                    return false
                } else {
                    return first.name.lowercased() < second.name.lowercased()
                }
            }
            
            applyFilters()
            tableView.reloadData()
            
        } catch {
            // Handle error - could show an alert
            print("Error loading directory: \(error)")
            files = []
            filteredFiles = []
            tableView.reloadData()
        }
    }
    
    func setFilterTextOnly(_ filterTextOnly: Bool) {
        self.filterTextOnly = filterTextOnly
        applyFilters()
        tableView.reloadData()
    }
    
    func filterFiles(searchTerm: String) {
        self.searchTerm = searchTerm.lowercased()
        applyFilters()
        tableView.reloadData()
    }
    
    private func applyFilters() {
        filteredFiles = files.filter { file in
            // First filter by file type
            if filterTextOnly {
                let isTextFile = file.name.lowercased().hasSuffix(".txt") || 
                                file.name.lowercased().hasSuffix(".log") || 
                                file.name.lowercased().hasSuffix(".md") || 
                                file.name.lowercased().hasSuffix(".csv") ||
                                !file.name.contains(".")
                if !isTextFile {
                    return false
                }
            }
            
            // Then filter by search term
            if !searchTerm.isEmpty {
                return file.name.lowercased().contains(searchTerm)
            }
            
            return true
        }
    }
    
    override func layout() {
        super.layout()
        scrollView.frame = bounds
        tableView.frame = scrollView.bounds
    }
}

extension FileBrowserList: NSTableViewDataSource {
    func numberOfRows(in tableView: NSTableView) -> Int {
        return filteredFiles.count
    }
    
    func tableView(_ tableView: NSTableView, objectValueFor tableColumn: NSTableColumn?, row: Int) -> Any? {
        guard row < filteredFiles.count else { return nil }
        
        let file = filteredFiles[row]
        
        if tableColumn?.identifier.rawValue == "name" {
            return file.isDirectory ? "📁 \(file.name)" : "📄 \(file.name)"
        } else if tableColumn?.identifier.rawValue == "date" {
            let formatter = DateFormatter()
            formatter.dateStyle = .short
            formatter.timeStyle = .short
            return formatter.string(from: file.modificationDate)
        }
        
        return nil
    }
}

extension FileBrowserList: NSTableViewDelegate {
    func tableView(_ tableView: NSTableView, shouldSelectRow row: Int) -> Bool {
        return true
    }
    
    func tableView(_ tableView: NSTableView, rowActionsForRow row: Int, edge: NSTableView.RowActionEdge) -> [NSTableViewRowAction] {
        return []
    }
    
    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        guard row < filteredFiles.count else { return nil }
        
        let file = filteredFiles[row]
        let cellIdentifier = "FileBrowserCell"
        
        var cell = tableView.makeView(withIdentifier: NSUserInterfaceItemIdentifier(rawValue: cellIdentifier), owner: self) as? FileBrowserCellView
        
        if cell == nil {
            cell = FileBrowserCellView(frame: NSRect(x: 0, y: 0, width: tableView.frame.width, height: 30))
            cell?.identifier = NSUserInterfaceItemIdentifier(rawValue: cellIdentifier)
        }
        
        cell?.setup(with: file)
        
        return cell
    }
    
    func tableViewSelectionDidChange(_ notification: Notification) {
        let tableView = notification.object as! NSTableView
        let selectedRow = tableView.selectedRow
        
        if selectedRow >= 0 && selectedRow < filteredFiles.count {
            let file = filteredFiles[selectedRow]
            onFileSelected?(file.url)
        }
    }
    
    func tableView(_ tableView: NSTableView, shouldDoubleClickFor tableColumn: NSTableColumn?, row: Int) -> Bool {
        guard row < filteredFiles.count else { return false }
        
        let file = filteredFiles[row]
        
        if file.isDirectory {
            // Navigate into directory
            onFileSelected?(file.url) // This will be handled by the parent to reload the list
        } else {
            // Open file
            onFileOpen?(file.url)
        }
        
        return true
    }
}

fileprivate struct FileInfo {
    let url: URL
    let name: String
    let isDirectory: Bool
    let modificationDate: Date
    let size: Int?
}

private class FileBrowserTableView: NSTableView {
    override func keyDown(with event: NSEvent) {
        if event.characters == "\r" { // Enter key
            let selectedRow = self.selectedRow
            if selectedRow >= 0 {
                // Handle double click manually
                if let file = (dataSource as? FileBrowserList)?.filteredFiles[selectedRow] {
                    if file.isDirectory {
                        (dataSource as? FileBrowserList)?.onFileSelected?(file.url)
                    } else {
                        (dataSource as? FileBrowserList)?.onFileOpen?(file.url)
                    }
                }
            }
        } else {
            super.keyDown(with: event)
        }
    }
}

private class FileBrowserCellView: NSView {
    private var nameLabel: NSTextField!
    private var dateLabel: NSTextField!
    private var fileIcon: NSImageView!
    
    override init(frame: NSRect) {
        super.init(frame: frame)
        setup()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private func setup() {
        wantsLayer = true
        layer?.backgroundColor = .clear
        
        // File icon
        fileIcon = NSImageView(frame: NSRect(x: 5, y: 8, width: 14, height: 14))
        addSubview(fileIcon)
        
        // Name label
        nameLabel = NSTextField(frame: NSRect(x: 25, y: 8, width: 200, height: 14))
        nameLabel.isEditable = false
        nameLabel.isBordered = false
        nameLabel.backgroundColor = .clear
        nameLabel.font = Fonts.chrome
        nameLabel.textColor = Colors.chromeText
        nameLabel.cell?.isScrollable = true
        nameLabel.cell?.lineBreakMode = .byTruncatingTail
        addSubview(nameLabel)
        
        // Date label
        dateLabel = NSTextField(frame: NSRect(x: frame.width - 150, y: 8, width: 140, height: 14))
        dateLabel.isEditable = false
        dateLabel.isBordered = false
        dateLabel.backgroundColor = .clear
        dateLabel.font = Fonts.chrome
        dateLabel.textColor = Colors.chromeText
        dateLabel.alignment = .right
        dateLabel.cell?.isScrollable = true
        dateLabel.cell?.lineBreakMode = .byTruncatingTail
        addSubview(dateLabel)
    }
    
    func setup(with file: FileInfo) {
        // Set icon
        fileIcon.image = file.isDirectory ? 
            NSImage(imageLiteralResourceName: "NSTouchBarFolderIcon") : 
            NSImage(imageLiteralResourceName: "NSTouchBarTextSnippetIcon")
        
        // Set labels
        nameLabel.stringValue = file.name
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .short
        dateLabel.stringValue = formatter.string(from: file.modificationDate)
    }
    
    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        trackingAreas.forEach { removeTrackingArea($0) }
        
        let trackingArea = NSTrackingArea(rect: bounds, options: [.activeInActiveApp, .mouseEnteredAndExited], owner: self, userInfo: nil)
        addTrackingArea(trackingArea)
    }
    
    override func mouseEntered(with event: NSEvent) {
        layer?.backgroundColor = Colors.menuHoverBg.cgColor
    }
    
    override func mouseExited(with event: NSEvent) {
        layer?.backgroundColor = .clear
    }
}