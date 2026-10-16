import SwiftUI

extension View {
    /// Shows a short confirmation pill at the bottom of the view.
    func successToast(isPresented: Bool, message: LocalizedStringKey) -> some View {
        overlay(alignment: .bottom) {
            if isPresented {
                Text(message)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    .background(.black.opacity(0.8), in: RoundedRectangle(cornerRadius: 12))
                    .padding(.bottom, 24)
                    .transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: 0.2), value: isPresented)
    }
}
