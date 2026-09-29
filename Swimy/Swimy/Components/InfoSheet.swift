import SwiftUI

/// The ⓘ sheet: what a metric means, in plain words. Opens at medium height.
struct InfoSheet: View {
    let metric: SwimMetric

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: Spacing.medium) {
                    Image(systemName: metric.symbolName)
                        .font(.largeTitle)
                        .foregroundStyle(metric.tint)
                        .accessibilityHidden(true)

                    Text(metric.explainer)
                        .font(.title3.weight(.semibold))

                    Text(metric.howItWorks)
                        .font(.body)
                        .foregroundStyle(.secondary)

                    if let note = metric.note {
                        Label {
                            Text(note)
                        } icon: {
                            Image(systemName: "lightbulb.fill")
                                .foregroundStyle(metric.tint)
                        }
                        .font(.subheadline)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .cardStyle()
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(Spacing.medium)
            }
            .background(Color.screenBackground)
            .navigationTitle(metric.title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        dismiss()
                    } label: {
                        Label("Close", systemImage: "xmark")
                    }
                }
            }
        }
        .presentationDetents([.medium, .large])
    }
}

#Preview {
    Color.clear
        .sheet(isPresented: .constant(true)) {
            InfoSheet(metric: .swolf)
        }
}
