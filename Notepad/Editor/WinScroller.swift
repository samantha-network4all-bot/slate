import AppKit

class WinScroller: NSScroller {
    private var hoverTimer: Timer?
    private var scrollTimer: Timer?
    private var isArrowHovered = false
    
    override init(frame: NSRect) {
        super.init(frame: frame)
        setup()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setup()
    }
    
    private func setup() {
        scrollerStyle = .legacy
        knobStyle = .default
    }
    
    // MARK: - Override properties
    override class var isCompatibleWithOverlayScrollers: Bool {
        return false
    }
    
    // MARK: - Custom drawing
    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
        
        // Draw custom track
        Colors.scrollbarTrack.setFill()
        bounds.fill()
        
        // Draw custom thumb
        let knobRect = rect(for: .knob)
        let isHovered = isArrowHovered || knobRect.contains(convert(NSEvent.mouseLocation, from: nil))
        let thumbColor = isHovered ? Colors.scrollbarThumbHover : Colors.scrollbarThumb
        thumbColor.setFill()
        knobRect.fill()
        
        // Draw arrow buttons
        drawArrowButtons()
    }
    
    private func drawArrowButtons() {
        let bounds = self.bounds
        
        // Up arrow (top)
        let upArrowRect = NSRect(x: 0, y: bounds.height - Metrics.scrollbarArrowButtonHeight, width: bounds.width, height: Metrics.scrollbarArrowButtonHeight)
        Colors.scrollbarArrow.setFill()
        drawTriangleInRect(upArrowRect, direction: .up)
        
        // Down arrow (bottom)
        let downArrowRect = NSRect(x: 0, y: 0, width: bounds.width, height: Metrics.scrollbarArrowButtonHeight)
        drawTriangleInRect(downArrowRect, direction: .down)
    }
    
    private func drawTriangleInRect(_ rect: NSRect, direction: ScrollDirection) {
        let triangleSize = NSSize(width: 5, height: 3)
        let triangleRect = NSRect(
            x: rect.midX - triangleSize.width / 2,
            y: rect.midY - triangleSize.height / 2,
            width: triangleSize.width,
            height: triangleSize.height
        )
        
        let path = NSBezierPath()
        if direction == .up {
            path.move(to: NSPoint(x: triangleRect.minX, y: triangleRect.maxY))
            path.line(to: NSPoint(x: triangleRect.midX, y: triangleRect.minY))
            path.line(to: NSPoint(x: triangleRect.maxX, y: triangleRect.maxY))
        } else {
            path.move(to: NSPoint(x: triangleRect.minX, y: triangleRect.minY))
            path.line(to: NSPoint(x: triangleRect.midX, y: triangleRect.maxY))
            path.line(to: NSPoint(x: triangleRect.maxX, y: triangleRect.minY))
        }
        path.fill()
    }
    
    // MARK: - Mouse events
    override func mouseDown(with event: NSEvent) {
        let point = convert(event.locationInWindow, from: nil)
        let bounds = self.bounds
        
        // Check if clicking on arrow areas (top and bottom 17px)
        let upperArrowRect = NSRect(x: 0, y: bounds.height - Metrics.scrollbarArrowButtonHeight, width: bounds.width, height: Metrics.scrollbarArrowButtonHeight)
        let lowerArrowRect = NSRect(x: 0, y: 0, width: bounds.width, height: Metrics.scrollbarArrowButtonHeight)
        
        if upperArrowRect.contains(point) {
            // Up arrow clicked
            isArrowHovered = true
            scrollOneLine(direction: .up)
            setupContinuousScroll(direction: .up)
            needsDisplay = true
        } else if lowerArrowRect.contains(point) {
            // Down arrow clicked
            isArrowHovered = true
            scrollOneLine(direction: .down)
            setupContinuousScroll(direction: .down)
            needsDisplay = true
        }
        
        super.mouseDown(with: event)
    }
    
    override func mouseUp(with event: NSEvent) {
        super.mouseUp(with: event)
        stopContinuousScroll()
        isArrowHovered = false
        needsDisplay = true
    }
    
    override func mouseExited(with event: NSEvent) {
        super.mouseExited(with: event)
        isArrowHovered = false
        needsDisplay = true
    }
    
    // MARK: - Private helpers
    private func scrollOneLine(direction: ScrollDirection) {
        guard let scrollView = superview as? NSScrollView else { return }
        guard let textView = scrollView.documentView as? NSTextView else { return }
        
        let lineHeight = textView.font?.boundingRectForFont.height ?? 13
        let scrollAmount = direction == .up ? -lineHeight : lineHeight
        
        textView.scroll(NSPoint(x: 0, y: scrollAmount))
    }
    
    private func setupContinuousScroll(direction: ScrollDirection) {
        hoverTimer = Timer.scheduledTimer(withTimeInterval: 0.3, repeats: false) { [weak self] _ in
            self?.startContinuousScroll(direction: direction)
        }
    }
    
    private func startContinuousScroll(direction: ScrollDirection) {
        scrollTimer = Timer.scheduledTimer(withTimeInterval: 0.05, repeats: true) { [weak self] _ in
            self?.scrollOneLine(direction: direction)
        }
    }
    
    private func stopContinuousScroll() {
        hoverTimer?.invalidate()
        hoverTimer = nil
        scrollTimer?.invalidate()
        scrollTimer = nil
    }
    
    private enum ScrollDirection {
        case up, down
    }
}
