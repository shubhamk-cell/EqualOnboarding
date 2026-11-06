// Renders the Picture-in-Picture walkthrough shown while the user sets up call forwarding in
// the Phone app (iOS 27+, where Equal can only copy the code): Home › Phone, Keypad, touch and
// hold › Paste, Call, the carrier's confirmation, then back to Equal AI.
//
//   swift tools/render_forwarding_guide.swift EqualOrbOnboarding/Resources/Video/forwarding_guide.mp4 [stills-folder]
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
let code = "**67*04048938092#"

// MARK: Timeline

func ramp(_ t: Double, _ a: Double, _ b: Double) -> Double {
    let x = min(max((t - a) / (b - a), 0), 1)
    return x * x * (3 - 2 * x)
}

/// Taps: (time, point in the phone area, long press).
let taps: [(Double, CGPoint, Bool)] = [
    (1.5, CGPoint(x: 62, y: 362), false),     // Phone, in the dock
    (3.5, CGPoint(x: 180, y: 52), true),      // touch and hold the number field
    (4.6, CGPoint(x: 180, y: 20), false),     // Paste
    (6.4, CGPoint(x: 180, y: 353), false),    // Call
]
let openPhone = 1.75          // Home → Phone (keypad)
let pasted = 4.75             // the code appears
let dialled = 6.6             // the call starts; the carrier replies
let answered = 7.6

struct Caption { let from: Double; let step: String; let text: String }
let captions = [
    Caption(from: 0, step: "Step 1 of 3", text: "Go Home and open Phone"),
    Caption(from: 2.6, step: "Step 2 of 3", text: "Keypad: touch and hold, then Paste"),
    Caption(from: 5.4, step: "Step 3 of 3", text: "Tap the green Call button"),
    Caption(from: 9.4, step: "All set", text: "Now come back to Equal AI"),
]

// MARK: Drawing

let ios = Color(red: 0.95, green: 0.95, blue: 0.97)
let label = Color.black
let secondary = Color(white: 0.55)
let iosGreen = Color(red: 0.204, green: 0.78, blue: 0.349)
let equalGreen = Color(red: 0, green: 0.694, blue: 0.251)

struct AppIcon: View {
    var symbol: String
    var colors: [Color]
    var body: some View {
        RoundedRectangle(cornerRadius: 13, style: .continuous)
            .fill(LinearGradient(colors: colors, startPoint: .top, endPoint: .bottom))
            .frame(width: 56, height: 56)
            .overlay(Image(systemName: symbol).font(.system(size: 26, weight: .semibold)).foregroundStyle(.white))
    }
}

/// The Home screen: a soft wallpaper, a grid of apps and the dock with Phone.
struct HomeScreen: View {
    let icons: [(String, [Color])] = [
        ("calendar", [.red, .orange]), ("photo.fill", [.yellow, .orange]), ("camera.fill", [.gray, .gray]),
        ("map.fill", [.green, .teal]), ("cloud.sun.fill", [.blue, .cyan]), ("clock.fill", [.black, .gray]),
        ("note.text", [.yellow, .yellow]), ("gearshape.fill", [.gray, Color(white: 0.4)]),
    ]
    var body: some View {
        ZStack(alignment: .bottom) {
            LinearGradient(colors: [Color(red: 0.55, green: 0.75, blue: 0.95), Color(red: 0.8, green: 0.62, blue: 0.9)],
                           startPoint: .topLeading, endPoint: .bottomTrailing)
            VStack(spacing: 22) {
                ForEach(0..<2, id: \.self) { r in
                    HStack(spacing: 26) {
                        ForEach(0..<4, id: \.self) { c in AppIcon(symbol: icons[r * 4 + c].0, colors: icons[r * 4 + c].1) }
                    }
                }
                Spacer()
            }
            .padding(.top, 34)
            HStack(spacing: 26) {
                AppIcon(symbol: "phone.fill", colors: [Color(red: 0.4, green: 0.88, blue: 0.4), iosGreen])
                AppIcon(symbol: "message.fill", colors: [Color(red: 0.4, green: 0.88, blue: 0.4), iosGreen])
                AppIcon(symbol: "safari.fill", colors: [.blue, .cyan])
                AppIcon(symbol: "music.note", colors: [.pink, .red])
            }
            .padding(.vertical, 12)
            .padding(.horizontal, 14)
            .background(RoundedRectangle(cornerRadius: 30, style: .continuous).fill(.white.opacity(0.35)))
            .padding(.bottom, 10)
        }
        .frame(width: size.width, height: phoneH)
    }
}

/// The Phone app's keypad, with the pasted code once it's in.
struct Keypad: View {
    let t: Double
    let keys = [["1", "2", "3"], ["4", "5", "6"], ["7", "8", "9"], ["*", "0", "#"]]
    var body: some View {
        let shown = t >= pasted
        VStack(spacing: 0) {
            Text(shown ? code : " ")
                .font(.system(size: 26, weight: .regular))
                .foregroundStyle(label)
                .frame(height: 50)
                .padding(.top, 26)
                .opacity(ramp(t, pasted, pasted + 0.2))
            VStack(spacing: 8) {
                ForEach(0..<4, id: \.self) { r in
                    HStack(spacing: 24) {
                        ForEach(keys[r], id: \.self) { k in
                            Text(k).font(.system(size: 24)).foregroundStyle(label)
                                .frame(width: 52, height: 52)
                                .background(Circle().fill(Color(white: 0.89)))
                        }
                    }
                }
            }
            .padding(.top, 8)
            Circle().fill(iosGreen).frame(width: 54, height: 54)
                .overlay(Image(systemName: "phone.fill").font(.system(size: 22)).foregroundStyle(.white))
                .padding(.top, 10)
            Spacer()
        }
        .frame(width: size.width, height: phoneH)
        .background(.white)
        .overlay(alignment: .top) {
            // The Paste menu above the number, after touch and hold.
            let k = ramp(t, 3.9, 4.1) * (1 - ramp(t, 4.7, 4.85))
            if k > 0 {
                Text("Paste").font(.system(size: 15, weight: .medium)).foregroundStyle(.white)
                    .padding(.horizontal, 16).frame(height: 34)
                    .background(RoundedRectangle(cornerRadius: 9, style: .continuous).fill(Color(white: 0.15)))
                    .padding(.top, 2)
                    .scaleEffect(0.8 + 0.2 * k).opacity(k)
            }
        }
    }
}

/// The carrier's reply once the code is dialled.
struct CarrierReply: View {
    var body: some View {
        VStack(spacing: 14) {
            Text("Calling…").font(.system(size: 15)).foregroundStyle(.white.opacity(0.6)).padding(.top, 70)
            Text("Setting Registration Succeeded").font(.system(size: 17, weight: .semibold)).foregroundStyle(.white)
            Text("Voice Call Forwarding").font(.system(size: 15)).foregroundStyle(.white.opacity(0.85))
            Text("Dismiss").font(.system(size: 16, weight: .semibold)).foregroundStyle(.black)
                .padding(.horizontal, 30).frame(height: 44)
                .background(Capsule().fill(.white))
                .padding(.top, 18)
            Spacer()
        }
        .frame(width: size.width, height: phoneH)
        .background(Color.black)
    }
}

struct Frame: View {
    let t: Double

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
                let open = ramp(t, openPhone, openPhone + 0.35)
                HomeScreen()
                    .scaleEffect(1 + 0.15 * open)
                    .opacity(1 - open)
                Keypad(t: t)
                    .scaleEffect(0.3 + 0.7 * open, anchor: UnitPoint(x: 62 / size.width, y: 362 / phoneH))
                    .opacity(open)
                let reply = ramp(t, answered, answered + 0.35)
                if t > dialled {
                    CarrierReply().opacity(reply)
                }
                ForEach(taps.indices, id: \.self) { i in
                    let (at, p, hold) = taps[i]
                    let lift = hold ? 0.6 : 0.2
                    let a = ramp(t, at - 0.45, at - 0.15) * (1 - ramp(t, at + lift, at + lift + 0.25))
                    let press = ramp(t, at - 0.15, at) * (1 - ramp(t, at + lift, at + lift + 0.2))
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
                        Color.white.opacity(0.9 * k)
                        VStack(spacing: 12) {
                            Image(systemName: "checkmark.circle.fill").font(.system(size: 64)).foregroundStyle(equalGreen)
                            Text("Call forwarding is on.\nHead back to Equal AI").font(.system(size: 16, weight: .semibold))
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

let out = URL(fileURLWithPath: CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "forwarding_guide.mp4")
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
        if CommandLine.arguments.count > 2, [20, 60, 110, 140, 200, 250, 300, 340].contains(f), let png = NSBitmapImageRep(cgImage: cg).representation(using: .png, properties: [:]) {
            try? png.write(to: URL(fileURLWithPath: CommandLine.arguments[2]).appendingPathComponent("guide_\(f).png"))
        }
    }
}
input.markAsFinished()
let sem = DispatchSemaphore(value: 0)
writer.finishWriting { sem.signal() }
sem.wait()
print(writer.status == .completed ? "wrote \(out.path) (\(frames) frames)" : "failed: \(String(describing: writer.error))")
