import SwiftUI

struct CropView: View {
    @StateObject private var viewModel = CropViewModel()

    var body: some View {
        VStack(spacing: 16) {
            Text("Crop").font(.largeTitle)
            NavigationLink("Go to Review", destination: ReviewView())
        }
        .padding()
        .navigationTitle("Crop")
    }
}

final class CropViewModel: ObservableObject {}
