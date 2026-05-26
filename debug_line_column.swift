import Foundation

let text1 = "Hello" + String(format: "%C%C", 13, 10) + "World"
print("Text1: '\(text1)'")
print("Count: \(text1.count)")

let longText = """
Line 1 with text
Line 2 has more content
Line 3 is short
Line 4 is very very very very long line that should test column counting
"""
print("\nLong text:")
print("'\(longText)'")
print("Count: \(longText.count)")

print("\nCharacter by character:")
for (i, char) in longText.enumerated() {
    if i < 70 {  // Only show first 70 to avoid too much output
        if char == "\n" {
            print("Index \(i): newline")
        } else {
            print("Index \(i): '\(char)'")
        }
    }
}

print("\nLine break positions:")
for (i, char) in longText.enumerated() {
    if char == "\n" {
        print("Newline at index \(i)")
    }
}

print("\nTesting trailing newline scenarios:")
let textCR = "Hello\nWorld\n"
print("TextCR: '\(textCR)' (count: \(textCR.count))")
for (i, char) in textCR.enumerated() {
    if char == "\n" {
        print("Newline at index \(i)")
    }
}

// Manual calculation for "Hello\nWorld\n":
// Text: H e l l o \n W o r l d \n
// At position 12 (text.count = 12): we've processed all characters
// H(0), e(1), l(2), l(3), o(4), \n(5) -> line=2, col=1
// W(6), o(7), r(8), l(9), d(10), \n(11) -> line=3, col=1

print("\nManual calculation for textCR with count=12:")
print("After processing all 12 characters, we should be at line=3, col=1")
print("But test expects line=2, col=1")