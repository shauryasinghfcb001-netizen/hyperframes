// Face track a video with Apple's Vision framework (no installs needed).
// Usage: swift facetrack.swift <video> [samples_per_second=10] > face.json
// Output: [{"t":sec,"cx":0-1,"cy":0-1,"w":0-1,"h":0-1}] — normalized, origin top-left,
// largest face per sampled frame. Frames with no face are skipped.
import AVFoundation
import Foundation
import Vision

let args = CommandLine.arguments
guard args.count >= 2 else {
    FileHandle.standardError.write("usage: facetrack.swift <video> [samples_per_second]\n".data(using: .utf8)!)
    exit(1)
}
let sps = args.count >= 3 ? (Double(args[2]) ?? 10) : 10
let asset = AVURLAsset(url: URL(fileURLWithPath: args[1]))
let duration = CMTimeGetSeconds(asset.duration)

let gen = AVAssetImageGenerator(asset: asset)
gen.appliesPreferredTrackTransform = true
gen.requestedTimeToleranceBefore = .zero
gen.requestedTimeToleranceAfter = .zero
gen.maximumSize = CGSize(width: 540, height: 960)

var rows: [String] = []
var t = 0.0
while t < duration {
    let time = CMTime(seconds: t, preferredTimescale: 600)
    if let img = try? gen.copyCGImage(at: time, actualTime: nil) {
        let req = VNDetectFaceRectanglesRequest()
        try? VNImageRequestHandler(cgImage: img, options: [:]).perform([req])
        if let f = (req.results ?? []).max(by: {
            $0.boundingBox.width * $0.boundingBox.height < $1.boundingBox.width * $1.boundingBox.height
        }) {
            let b = f.boundingBox  // Vision origin is bottom-left; flip y
            rows.append(String(format: "{\"t\":%.3f,\"cx\":%.4f,\"cy\":%.4f,\"w\":%.4f,\"h\":%.4f}",
                               t, b.midX, 1 - b.midY, b.width, b.height))
        }
    }
    t += 1.0 / sps
}
print("[" + rows.joined(separator: ",\n") + "]")
