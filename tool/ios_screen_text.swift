// Prints the text the Vision framework reads in a screenshot, one line per
// text box (macOS only). tool/ios_screenshots.sh uses it to check that a shot
// shows the right screen in the right language (#87).
//
//   swiftc -o <bin> tool/ios_screen_text.swift && <bin> <png>
import Foundation
import ImageIO
import Vision

guard CommandLine.arguments.count == 2 else {
  FileHandle.standardError.write("usage: ios_screen_text <png>\n".data(using: .utf8)!)
  exit(2)
}
let url = URL(fileURLWithPath: CommandLine.arguments[1]) as CFURL
guard let source = CGImageSourceCreateWithURL(url, nil),
  let image = CGImageSourceCreateImageAtIndex(source, 0, nil)
else {
  FileHandle.standardError.write("cannot read \(CommandLine.arguments[1])\n".data(using: .utf8)!)
  exit(1)
}

let request = VNRecognizeTextRequest()
request.recognitionLevel = .accurate
request.recognitionLanguages = ["de-DE", "en-US"]
request.usesLanguageCorrection = false
try VNImageRequestHandler(cgImage: image).perform([request])
for observation in request.results ?? [] {
  if let line = observation.topCandidates(1).first?.string { print(line) }
}
