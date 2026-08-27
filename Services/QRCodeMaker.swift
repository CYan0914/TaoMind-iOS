import UIKit
import CoreImage

/// App Store 下载二维码（CoreImage 生成，进程内缓存）。
/// 分享卡（ShareCardView）与修行纪念卡共用——分享出去的纯图片也能带回下载。
@MainActor
enum QRCodeMaker {
    static let appStoreURL = "https://apps.apple.com/app/id6792008756"

    private static var cache: [String: UIImage] = [:]

    static func appStoreQR() -> UIImage? {
        image(for: appStoreURL, size: 108)
    }

    static func image(for string: String, size: CGFloat) -> UIImage? {
        if let cached = cache[string] { return cached }
        guard let filter = CIFilter(name: "CIQRCodeGenerator"),
              let data = string.data(using: .utf8) else { return nil }
        filter.setValue(data, forKey: "inputMessage")
        filter.setValue("M", forKey: "inputCorrectionLevel")
        guard let output = filter.outputImage else { return nil }
        let scale = size / output.extent.width
        let scaled = output.transformed(by: CGAffineTransform(scaleX: scale, y: scale))
        guard let cg = CIContext().createCGImage(scaled, from: scaled.extent) else { return nil }
        let image = UIImage(cgImage: cg)
        cache[string] = image
        return image
    }
}
