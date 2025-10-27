import Foundation

#if ADS
    import GoogleMobileAds
#endif

public enum Ads {}

public final class AdsManager {
    public init() {}
    public func startIfEnabled() {
        #if ADS
            GADMobileAds.sharedInstance().start(completionHandler: nil)
        #endif
    }
}

#if ADS
    import GoogleMobileAds
    import SwiftUI

    public struct BannerAdView: UIViewRepresentable {
        public init() {}
        public func makeUIView(context _: Context) -> GADBannerView {
            let view = GADBannerView(adSize: GADAdSizeBanner)
            // Placeholder ad unit ID; replace with production ID when enabling ads.
            view.adUnitID = "ca-app-pub-XXXXXXXXXXXXXXXX/BBBBBBBBBB"
            view.rootViewController = UIApplication.shared.connectedScenes.compactMap { ($0 as? UIWindowScene)?.keyWindow?.rootViewController }.first
            let request = GADRequest()
            if !Settings.shared.personalizedAds { let extras = GADExtras(); extras.additionalParameters = ["npa": "1"]; request.register(extras) }
            view.load(request)
            return view
        }

        public func updateUIView(_: GADBannerView, context _: Context) {}
    }
#else
    import SwiftUI

    public struct BannerAdView: View {
        public init() {}
        public var body: some View { EmptyView() }
    }
#endif
