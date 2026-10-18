import CoreGraphics
import CoreImage
import CoreImage.CIFilterBuiltins
import Foundation
import ImageIO

/// A rendered picture handed from the render actor to the UI. CGImage is immutable, so sharing it is safe.
struct RenderedImage: @unchecked Sendable {
    let cgImage: CGImage
}

enum RenderError: LocalizedError {
    case unreadable
    case noPhoto
    case encodingFailed

    var errorDescription: String? {
        switch self {
        case .unreadable: "That file couldn't be opened as a photo."
        case .noPhoto: "Open a photo first."
        case .encodingFailed: "The photo couldn't be saved."
        }
    }
}

/// Turns the photo plus an EditState into pixels with Core Image (ED-2, ED-4).
/// Runs on its own actor so the UI never waits on it. Previews use a small copy
/// (longest side 2048 px); export uses the full-size original.
actor RenderPipeline {
    static let proxyMaxSide: CGFloat = 2048

    private let context = CIContext(options: [.cacheIntermediates: false])
    private var original: CIImage?
    private var proxy: CIImage?

    /// Loads a JPEG, PNG or HEIC, turned upright using its orientation tag. Returns the full size.
    func load(_ url: URL) throws -> CGSize {
        guard let image = CIImage(contentsOf: url, options: [.applyOrientationProperty: true]) else {
            throw RenderError.unreadable
        }
        original = image
        proxy = Self.downscaled(image, maxSide: Self.proxyMaxSide)
        return image.extent.size
    }

    func renderPreview(_ state: EditState) -> RenderedImage? {
        guard let proxy else { return nil }
        let output = Self.apply(state, to: proxy)
        guard let cgImage = context.createCGImage(output, from: proxy.extent) else { return nil }
        return RenderedImage(cgImage: cgImage)
    }

    /// Full-resolution JPEG at quality 0.9, keeping the original's color space (IO-2).
    func exportJPEG(_ state: EditState) throws -> Data {
        guard let original else { throw RenderError.noPhoto }
        let output = Self.apply(state, to: original)
        let colorSpace = original.colorSpace ?? CGColorSpace(name: CGColorSpace.sRGB)!
        let options = [kCGImageDestinationLossyCompressionQuality as CIImageRepresentationOption: 0.9]
        guard let data = context.jpegRepresentation(of: output, colorSpace: colorSpace, options: options) else {
            throw RenderError.encodingFailed
        }
        return data
    }

    // MARK: - Filters

    /// Applies the preset, then each tool that isn't at its default. Pure: same input, same output.
    static func apply(_ state: EditState, to input: CIImage) -> CIImage {
        var image = applyPreset(state.preset, to: input)

        if state[.exposure] != Tool.exposure.defaultValue {
            let filter = CIFilter.exposureAdjust()
            filter.inputImage = image
            filter.ev = Float(state[.exposure])
            image = filter.outputImage ?? image
        }

        if state[.brightness] != Tool.brightness.defaultValue
            || state[.contrast] != Tool.contrast.defaultValue
            || state[.saturation] != Tool.saturation.defaultValue {
            let filter = CIFilter.colorControls()
            filter.inputImage = image
            filter.brightness = Float(state[.brightness])
            filter.contrast = Float(state[.contrast])
            filter.saturation = Float(state[.saturation])
            image = filter.outputImage ?? image
        }

        if state[.warmth] != Tool.warmth.defaultValue {
            // "Shot under this colour of light, correct it to daylight": higher Kelvin looks warmer.
            let filter = CIFilter.temperatureAndTint()
            filter.inputImage = image
            filter.neutral = CIVector(x: CGFloat(state[.warmth]), y: 0)
            filter.targetNeutral = CIVector(x: 6500, y: 0)
            image = filter.outputImage ?? image
        }

        if state[.highlights] != Tool.highlights.defaultValue || state[.shadows] != Tool.shadows.defaultValue {
            let filter = CIFilter.highlightShadowAdjust()
            filter.inputImage = image
            filter.highlightAmount = Float(state[.highlights])
            filter.shadowAmount = Float(state[.shadows])
            image = filter.outputImage ?? image
        }

        if state[.vignette] != Tool.vignette.defaultValue {
            let filter = CIFilter.vignette()
            filter.inputImage = image
            filter.intensity = Float(state[.vignette])
            filter.radius = 2
            image = filter.outputImage ?? image
        }

        if state[.sharpness] != Tool.sharpness.defaultValue {
            let filter = CIFilter.sharpenLuminance()
            filter.inputImage = image
            filter.sharpness = Float(state[.sharpness])
            image = filter.outputImage ?? image
        }

        return image.cropped(to: input.extent)
    }

    private static func applyPreset(_ preset: Preset, to input: CIImage) -> CIImage {
        switch preset {
        case .original:
            return input
        case .vivid:
            return colorControls(input, saturation: 1.35, contrast: 1.1)
        case .warmFilm:
            let warm = temperature(input, kelvin: 7800)
            return colorControls(warm, saturation: 0.9, contrast: 0.95)
        case .coolMatte:
            let cool = temperature(input, kelvin: 5200)
            return colorControls(cool, saturation: 0.8, contrast: 0.85)
        case .noir:
            let filter = CIFilter.photoEffectNoir()
            filter.inputImage = input
            return filter.outputImage ?? input
        case .chrome:
            let filter = CIFilter.photoEffectChrome()
            filter.inputImage = input
            return filter.outputImage ?? input
        }
    }

    private static func colorControls(_ input: CIImage, saturation: Float, contrast: Float) -> CIImage {
        let filter = CIFilter.colorControls()
        filter.inputImage = input
        filter.saturation = saturation
        filter.contrast = contrast
        return filter.outputImage ?? input
    }

    private static func temperature(_ input: CIImage, kelvin: CGFloat) -> CIImage {
        let filter = CIFilter.temperatureAndTint()
        filter.inputImage = input
        filter.neutral = CIVector(x: kelvin, y: 0)
        filter.targetNeutral = CIVector(x: 6500, y: 0)
        return filter.outputImage ?? input
    }

    private static func downscaled(_ image: CIImage, maxSide: CGFloat) -> CIImage {
        let longest = max(image.extent.width, image.extent.height)
        guard longest > maxSide else { return image }
        let filter = CIFilter.lanczosScaleTransform()
        filter.inputImage = image
        filter.scale = Float(maxSide / longest)
        filter.aspectRatio = 1
        return filter.outputImage ?? image
    }
}
