import Foundation
import UIKit
import Photos

public enum ShareExport {
    public static func share(items: [Any], from controller: UIViewController) {
        let av = UIActivityViewController(activityItems: items, applicationActivities: nil)
        controller.present(av, animated: true)
    }

    public static func saveToPhotos(_ image: UIImage, completion: ((Bool)->Void)? = nil) {
        PHPhotoLibrary.requestAuthorization { status in
            guard status == .authorized || status == .limited else { completion?(false); return }
            UIImageWriteToSavedPhotosAlbum(image, nil, nil, nil)
            completion?(true)
        }
    }

    public static func saveData(_ data: Data, suggestedName: String) throws -> URL {
        let dir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        let url = dir.appendingPathComponent(suggestedName)
        try data.write(to: url, options: .atomic)
        return url
    }
}
