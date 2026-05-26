import Foundation

struct FindEngine {
    enum Direction {
        case forward
        case backward
    }
    
    struct Options {
        let matchCase: Bool
        let wrapAround: Bool
        let direction: Direction
    }
    
    static func find(
        text: String,
        needle: String,
        options: Options,
        cursorPosition: Int
    ) -> NSRange? {
        guard !needle.isEmpty else { return nil }
        
        let searchStart: Int
        let searchRange: NSRange
        
        switch options.direction {
        case .forward:
            searchStart = cursorPosition
            if searchStart >= text.count {
                if options.wrapAround {
                    searchRange = NSRange(location: 0, length: text.count)
                } else {
                    return nil
                }
            } else {
                searchRange = NSRange(location: searchStart, length: text.count - searchStart)
            }
        case .backward:
            searchStart = max(0, cursorPosition - needle.count)
            if searchStart < 0 {
                if options.wrapAround {
                    searchRange = NSRange(location: text.count - needle.count, length: needle.count)
                } else {
                    return nil
                }
            } else {
                searchRange = NSRange(location: 0, length: searchStart)
            }
        }
        
        let searchText = text as NSString
        let foundRange: NSRange
        
        if options.matchCase {
            foundRange = searchText.range(of: needle, options: [], range: searchRange)
        } else {
            foundRange = searchText.range(
                of: needle,
                options: .caseInsensitive,
                range: searchRange
            )
        }
        
        if foundRange.location != NSNotFound {
            return foundRange
        }
        
        // If not found and wrapAround is enabled, try the other part of the text
        if options.wrapAround {
            switch options.direction {
            case .forward:
                let remainingRange = NSRange(location: 0, length: cursorPosition)
                if options.matchCase {
                    return searchText.range(of: needle, options: [], range: remainingRange)
                } else {
                    return searchText.range(
                        of: needle,
                        options: .caseInsensitive,
                        range: remainingRange
                    )
                }
            case .backward:
                let remainingRange = NSRange(location: cursorPosition + needle.count, length: text.count - (cursorPosition + needle.count))
                if options.matchCase {
                    return searchText.range(of: needle, options: [], range: remainingRange)
                } else {
                    return searchText.range(
                        of: needle,
                        options: .caseInsensitive,
                        range: remainingRange
                    )
                }
            }
        }
        
        return nil
    }
}