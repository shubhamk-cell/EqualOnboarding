// Renders the Picture-in-Picture walkthrough shown while the user is in iPhone Settings.
// Equal can only open its own page there, so the video starts on it: ‹ Apps, then Phone,
// Live Voicemail off, Screen Unknown Callers › Never.
//
//   swift tools/render_settings_guide.swift EqualOrbOnboarding/Resources/Video/settings_guide.mp4 [stills-folder]
//
// Every frame is a pure function of time, drawn with SwiftUI and encoded to H.264.

import AVFoundation
import AppKit
import SwiftUI

let size = CGSize(width: 360, height: 480)
let phoneH: CGFloat = 400
let scale: CGFloat = 2
let fps: Int32 = 30
let duration = 12.0

// MARK: Timeline

func ramp(_ t: Double, _ a: Double, _ b: Double) -> Double {
    let x = min(max((t - a) / (b - a), 0), 1)
    return x * x * (3 - 2 * x)
}

/// Taps: (time, point in the phone area).
let taps: [(Double, CGPoint)] = [
    (0.9, CGPoint(x: 34, y: 28)),     // ‹ back to Apps
    (2.4, CGPoint(x: 150, y: 136)),   // Phone
    (4.2, CGPoint(x: 304, y: 136)),   // Live Voicemail switch
    (6.0, CGPoint(x: 150, y: 245)),   // Screen Unknown Callers
    (7.8, CGPoint(x: 150, y: 88)),    // Never
]

let backToApps = 1.15                       // Equal AI → Apps
let pushes: [Double] = [2.65, 6.25]         // Apps → Phone → Screen Unknown
let popAt = 8.6                              // back to Phone
let showPhone = 2.0                          // the page above Apps becomes Phone (it's off screen then)

struct Caption { let from: Double; let step: String; let text: String }
let captions = [
    Caption(from: 0, step: "Step 1 of 3", text: "Tap ‹ Apps, then Phone"),
    Caption(from: 3.3, step: "Step 2 of 3", text: "Turn Live Voicemail off"),
    Caption(from: 5.2, step: "Step 3 of 3", text: "Screen Unknown Callers › Never"),
    Caption(from: 9.4, step: "All set", text: "Now come back to Equal AI"),
]

// MARK: Drawing

let ios = Color(red: 0.95, green: 0.95, blue: 0.97)
let label = Color.black
let secondary = Color(white: 0.55)
let iosGreen = Color(red: 0.204, green: 0.78, blue: 0.349)
let equalGreen = Color(red: 0, green: 0.694, blue: 0.251)

struct Row: View {
    var icon: String? = nil
    var tint: Color = .gray
    var title: String
    var value: String? = nil
    var chevron = true
    var toggle: Double? = nil      // 1 on → 0 off
    var check = false
    var body: some View {
        HStack(spacing: 12) {
            if let icon {
                Image(systemName: icon).font(.system(size: 14, weight: .semibold)).foregroundStyle(.white)
                    .frame(width: 28, height: 28)
                    .background(RoundedRectangle(cornerRadius: 7, style: .continuous).fill(tint))
            }
            Text(title).font(.system(size: 16)).foregroundStyle(label).lineLimit(1)
            Spacer(minLength: 4)
            if let value { Text(value).font(.system(size: 15)).foregroundStyle(secondary).lineLimit(1) }
            if let toggle {
                Capsule().fill(iosGreen.opacity(toggle).blendedOver(Color(white: 0.91)))
                    .frame(width: 51, height: 31)
                    .overlay(alignment: .leading) {
                        Circle().fill(.white).frame(width: 27, height: 27)
                            .shadow(color: .black.opacity(0.15), radius: 3, y: 2)
                            .offset(x: 2 + 20 * toggle)
                    }
            } else if check {
                Image(systemName: "checkmark").font(.system(size: 15, weight: .semibold)).foregroundStyle(.blue)
            } else if chevron {
                Image(systemName: "chevron.right").font(.system(size: 13, weight: .semibold)).foregroundStyle(Color(white: 0.75))
            }
        }
        .padding(.horizontal, 16)
        .frame(height: 48)
    }
}

extension Color {
    /// Mix toward `base` as opacity drops (the switch track fades from green to grey).
    func blendedOver(_ base: Color) -> Color {
        let a = NSColor(self).usingColorSpace(.sRGB)!, b = NSColor(base).usingColorSpace(.sRGB)!
        let k = a.alphaComponent
        return Color(red: a.redComponent * k + b.redComponent * (1 - k),
                     green: a.greenComponent * k + b.greenComponent * (1 - k),
                     blue: a.blueComponent * k + b.blueComponent * (1 - k))
    }
}

struct Card: View {
    var rows: [Row]
    var body: some View {
        VStack(spacing: 0) {
            ForEach(rows.indices, id: \.self) { i in
                rows[i]
                if i < rows.count - 1 { Rectangle().fill(Color(white: 0.88)).frame(height: 0.5).padding(.leading, rows[i].icon == nil ? 16 : 56) }
            }
        }
        .background(RoundedRectangle(cornerRadius: 22, style: .continuous).fill(.white))
        .padding(.horizontal, 14)
    }
}

struct Page<Content: View>: View {
    var title: String
    @ViewBuilder var content: Content
    var body: some View {
        VStack(spacing: 0) {
            Text(title).font(.system(size: 17, weight: .semibold)).frame(maxWidth: .infinity).frame(height: 44)
                .overlay(alignment: .leading) {
                    // iOS 26 back button: a round glass chevron.
                    Image(systemName: "chevron.left").font(.system(size: 17, weight: .semibold)).foregroundStyle(label)
                        .frame(width: 40, height: 40)
                        .background(Circle().fill(.white).shadow(color: .black.opacity(0.08), radius: 4, y: 1))
                        .padding(.leading, 14)
                }
                .padding(.top, 6)
            VStack(spacing: 22) { content }.padding(.top, 14)
            Spacer()
        }
        .frame(width: size.width, height: phoneH)
        .background(ios)
    }
}

struct Footer: View {
    var text: String
    var body: some View {
        Text(text).font(.system(size: 12.5)).foregroundStyle(secondary)
            .padding(.horizontal, 30).padding(.top, -14).frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct Frame: View {
    let t: Double

    var voicemail: Double { 1 - ramp(t, 4.25, 4.55) }
    var never: Bool { t >= 7.85 }

    /// Apps, then the page above it (Equal AI, later Phone), then Screen Unknown Callers.
    func pages() -> [AnyView] {
        [
            AnyView(Page(title: "Apps") {
                Card(rows: [Row(icon: "message.fill", tint: iosGreen, title: "Messages"),
                             Row(icon: "phone.fill", tint: iosGreen, title: "Phone"),
                             Row(icon: "camera.fill", tint: .gray, title: "Camera")])
            }),
            t < showPhone ? equalPage : phonePage,
            AnyView(Page(title: "Screen Unknown Callers") {
                Card(rows: [Row(title: "Never", chevron: false, check: never),
                             Row(title: "Ask Reason for Calling", chevron: false, check: !never),
                             Row(title: "Silence", chevron: false)])
            }),
        ]
    }

    /// Where “Open Settings” lands: Equal AI's own page.
    var equalPage: AnyView {
        AnyView(Page(title: "Equal AI") {
            Text("ALLOW EQUAL AI TO ACCESS").font(.system(size: 12.5)).foregroundStyle(secondary)
                .padding(.horizontal, 30).padding(.bottom, -16).frame(maxWidth: .infinity, alignment: .leading)
            Card(rows: [Row(icon: "person.crop.circle.fill", tint: .gray, title: "Contacts", toggle: 1),
                         Row(icon: "bell.badge.fill", tint: .red, title: "Notifications", value: "Allow"),
                         Row(icon: "arrow.clockwise", tint: .gray, title: "Background App Refresh", toggle: 1)])
        })
    }

    var phonePage: AnyView {
            AnyView(Page(title: "Phone") {
                Card(rows: [Row(title: "Calls on Other Devices"),
                             Row(title: "Live Voicemail", toggle: voicemail)])
                Footer(text: "View a transcript of an incoming voicemail and answer the call before it ends.")
                Card(rows: [Row(title: "Screen Unknown Callers", value: never ? "Never" : "Ask"),
                             Row(title: "Silence Junk Callers", toggle: 0)])
            })
    }

    /// Current navigation position as a fractional page index: back to Apps, two pushes, one pop.
    var position: Double {
        var p = 1 - ramp(t, backToApps, backToApps + 0.4)
        for at in pushes { p += ramp(t, at, at + 0.4) }
        return p - ramp(t, popAt, popAt + 0.4)
    }

    var body: some View {
        let caption = captions.last { t >= $0.from }!
        let done = caption.step == "All set"
        VStack(spacing: 0) {
            // Instruction banner
            HStack(spacing: 12) {
                ZStack {
                    Circle().fill(.white.opacity(0.22)).frame(width: 36, height: 36)
                    Image(systemName: done ? "checkmark" : "hand.tap.fill").font(.system(size: 17, weight: .bold)).foregroundStyle(.white)
                }
                VStack(alignment: .leading, spacing: 1) {
                    Text(caption.step.uppercased()).font(.system(size: 11.5, weight: .bold)).foregroundStyle(.white.opacity(0.75)).tracking(0.6)
                    Text(caption.text).font(.system(size: 17, weight: .bold)).foregroundStyle(.white).lineLimit(2).minimumScaleFactor(0.8)
                }
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 18)
            .frame(height: 80)
            .background(equalGreen)

            // Phone
            ZStack(alignment: .topLeading) {
                let ps = pages(), pos = position
                ForEach(ps.indices, id: \.self) { i in
                    let d = Double(i) - pos
                    if d > -1, d < 1 {
                        ps[i]
                            .offset(x: d > 0 ? size.width * d : size.width * 0.3 * d)
                            .overlay(Color.black.opacity(d < 0 ? 0.08 * -d : 0))
                            .shadow(color: .black.opacity(d > 0 && d < 1 ? 0.15 : 0), radius: 8)
                            .zIndex(Double(i))
                    }
                }
                ForEach(taps.indices, id: \.self) { i in
                    let (at, p) = taps[i]
                    let a = ramp(t, at - 0.45, at - 0.15) * (1 - ramp(t, at + 0.2, at + 0.45))
                    let press = ramp(t, at - 0.15, at) * (1 - ramp(t, at, at + 0.2))
                    if a > 0 {
                        Circle().fill(Color.black.opacity(0.18)).frame(width: 46, height: 46)
                            .overlay(Circle().stroke(.white, lineWidth: 3))
                            .scaleEffect(1 - 0.18 * press)
                            .opacity(a)
                            .position(p)
                            .zIndex(10)
                    }
                }
                if done {
                    let k = ramp(t, 9.4, 9.8)
                    ZStack {
                        Color.white.opacity(0.85 * k)
                        VStack(spacing: 12) {
                            Image(systemName: "checkmark.circle.fill").font(.system(size: 64)).foregroundStyle(equalGreen)
                            Text("Head back to Equal AI\nto finish setting up").font(.system(size: 16, weight: .semibold))
                                .multilineTextAlignment(.center).foregroundStyle(label)
                        }
                        .scaleEffect(0.85 + 0.15 * k).opacity(k)
                    }
                    .frame(width: size.width, height: phoneH)
                    .zIndex(20)
                }
            }
            .frame(width: size.width, height: phoneH, alignment: .topLeading)
            .clipped()
        }
        .frame(width: size.width, height: size.height)
        .background(ios)
        // Green border round the whole picture (iOS draws the PiP window itself, so it lives here).
        // Its inner edge is rounded to follow the PiP window's own rounded corners.
        .overlay(GreenFrame().fill(equalGreen, style: FillStyle(eoFill: true)))
        .environment(\.colorScheme, .light)
    }
}

/// Everything outside a rounded rectangle inset by the border width. The PiP window's corners
/// measure about 32 at this video size and it trims a few units off each edge, so the inner
/// corners use a 26 radius to run parallel to the window's curve instead of thinning out.
struct GreenFrame: Shape {
    var width: CGFloat = 10
    var innerRadius: CGFloat = 26
    func path(in r: CGRect) -> Path {
        var p = Path(r)
        p.addRoundedRect(in: r.insetBy(dx: width, dy: width),
                         cornerSize: CGSize(width: innerRadius, height: innerRadius), style: .continuous)
        return p
    }
}

// MARK: Encode

let out = URL(fileURLWithPath: CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "settings_guide.mp4")
try? FileManager.default.removeItem(at: out)
try FileManager.default.createDirectory(at: out.deletingLastPathComponent(), withIntermediateDirectories: true)

let w = Int(size.width * scale), h = Int(size.height * scale)
let writer = try AVAssetWriter(outputURL: out, fileType: .mp4)
let input = AVAssetWriterInput(mediaType: .video, outputSettings: [
    AVVideoCodecKey: AVVideoCodecType.h264, AVVideoWidthKey: w, AVVideoHeightKey: h,
    AVVideoCompressionPropertiesKey: [AVVideoAverageBitRateKey: 1_200_000],
])
let adaptor = AVAssetWriterInputPixelBufferAdaptor(assetWriterInput: input, sourcePixelBufferAttributes: [
    kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32ARGB, kCVPixelBufferWidthKey as String: w, kCVPixelBufferHeightKey as String: h,
])
writer.add(input)
writer.startWriting()
writer.startSession(atSourceTime: .zero)

let frames = Int(duration * Double(fps))
MainActor.assumeIsolated {
    for f in 0..<frames {
        let t = Double(f) / Double(fps)
        let r = ImageRenderer(content: Frame(t: t))
        r.scale = scale
        guard let cg = r.cgImage else { fatalError("render failed at \(t)") }
        var pb: CVPixelBuffer?
        CVPixelBufferPoolCreatePixelBuffer(nil, adaptor.pixelBufferPool!, &pb)
        let buf = pb!
        CVPixelBufferLockBaseAddress(buf, [])
        let ctx = CGContext(data: CVPixelBufferGetBaseAddress(buf), width: w, height: h, bitsPerComponent: 8,
                            bytesPerRow: CVPixelBufferGetBytesPerRow(buf), space: CGColorSpaceCreateDeviceRGB(),
                            bitmapInfo: CGImageAlphaInfo.noneSkipFirst.rawValue)!
        ctx.draw(cg, in: CGRect(x: 0, y: 0, width: w, height: h))
        CVPixelBufferUnlockBaseAddress(buf, [])
        while !input.isReadyForMoreMediaData { Thread.sleep(forTimeInterval: 0.005) }
        adaptor.append(buf, withPresentationTime: CMTime(value: CMTimeValue(f), timescale: fps))
        // Optional second argument: a folder for a few still frames to eyeball.
        if CommandLine.arguments.count > 2, [12, 27, 40, 69, 123, 177, 231, 315].contains(f), let png = NSBitmapImageRep(cgImage: cg).representation(using: .png, properties: [:]) {
            try? png.write(to: URL(fileURLWithPath: CommandLine.arguments[2]).appendingPathComponent("guide_\(f).png"))
        }
    }
}
input.markAsFinished()
let sem = DispatchSemaphore(value: 0)
writer.finishWriting { sem.signal() }
sem.wait()
print(writer.status == .completed ? "wrote \(out.path) (\(frames) frames)" : "failed: \(String(describing: writer.error))")
