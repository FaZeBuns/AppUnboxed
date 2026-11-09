import SwiftUI

/// Lets the user add any app or game the automatic scan missed, by searching
/// the App Store. iOS does not let a normally installed app list what is on
/// the phone, so this is the guaranteed way to get a missing app into the reel,
/// with its real name and icon.
struct AddAppsView: View {

    struct StoreApp: Identifiable {
        let id: String        // bundle id
        let name: String
        let seller: String
        let artwork: String
    }

    @ObservedObject var model: InstalledAppsModel
    @Environment(\.dismiss) private var dismiss

    @State private var query = ""
    @State private var results: [StoreApp] = []
    @State private var searching = false
    @State private var storeIcons = InstalledAppsModel.storeIconsEnabled
    @State private var message = "Search for any app or game the scan missed, then tap it to add it to your case."

    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                HStack(spacing: 10) {
                    TextField("App or game name", text: $query)
                        .textFieldStyle(.roundedBorder)
                        .autocorrectionDisabled(true)
                        .submitLabel(.search)
                        .onSubmit(search)
                    Button("Search", action: search)
                        .disabled(query.trimmingCharacters(in: .whitespaces).isEmpty || searching)
                }
                .padding(16)

                VStack(alignment: .leading, spacing: 4) {
                    Toggle("Download missing icons from the App Store", isOn: $storeIcons)
                        .font(.footnote.weight(.semibold))
                        .onChange(of: storeIcons) { on in InstalledAppsModel.storeIconsEnabled = on }
                    Text("Your app list never leaves this phone. With this on, the bundle ids of apps iOS gave no icon for are sent to Apple's App Store lookup to fetch their artwork. Searching here also goes to the App Store.")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 10)

                if results.isEmpty {
                    Spacer()
                    if searching {
                        ProgressView()
                    } else {
                        Text(message)
                            .font(.callout)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 32)
                    }
                    Spacer()
                } else {
                    List(results) { app in
                        Button(action: { toggle(app) }) {
                            HStack(spacing: 12) {
                                AsyncImage(url: URL(string: app.artwork)) { image in
                                    image.resizable()
                                } placeholder: {
                                    Color.gray.opacity(0.25)
                                }
                                .frame(width: 48, height: 48)
                                .clipShape(RoundedRectangle(cornerRadius: 11, style: .continuous))

                                VStack(alignment: .leading, spacing: 2) {
                                    Text(app.name).font(.body.weight(.semibold)).lineLimit(1)
                                    Text(app.seller).font(.caption).foregroundColor(.secondary).lineLimit(1)
                                }
                                Spacer()
                                Image(systemName: model.manualIDs.contains(app.id) ? "checkmark.circle.fill" : "plus.circle")
                                    .font(.title2)
                                    .foregroundColor(model.manualIDs.contains(app.id) ? .green : .accentColor)
                            }
                        }
                        .foregroundColor(.primary)
                    }
                    .listStyle(.plain)
                }
            }
            .navigationTitle("Add apps")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
        .navigationViewStyle(.stack)
        .preferredColorScheme(.dark)
    }

    private func toggle(_ app: StoreApp) {
        if model.manualIDs.contains(app.id) {
            model.removeManual(id: app.id)
        } else {
            model.addManual(id: app.id, name: app.name, artwork: app.artwork)
        }
    }

    private func search() {
        let term = query.trimmingCharacters(in: .whitespaces)
        guard !term.isEmpty, !searching,
              let encoded = term.addingPercentEncoding(withAllowedCharacters: .alphanumerics),
              let url = URL(string: "https://itunes.apple.com/search?entity=software&limit=30&term=\(encoded)") else { return }
        searching = true
        results = []
        URLSession.shared.dataTask(with: url) { data, _, _ in
            var found: [StoreApp] = []
            if let data = data,
               let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let rows = json["results"] as? [[String: Any]] {
                for row in rows {
                    guard let id = row["bundleId"] as? String, let name = row["trackName"] as? String else { continue }
                    found.append(StoreApp(id: id, name: name,
                                          seller: row["sellerName"] as? String ?? "",
                                          artwork: row["artworkUrl100"] as? String ?? ""))
                }
            }
            DispatchQueue.main.async {
                searching = false
                results = found
                if found.isEmpty {
                    message = data == nil ? "Couldn't reach the App Store. Check your connection and try again."
                                          : "No apps found for “\(term)”."
                }
            }
        }.resume()
    }
}
