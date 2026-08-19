import SwiftUI

private let windLabelKeysLobby = ["wE": "windE", "wS": "windS", "wW": "windW", "wN": "windN"]

struct OnlineLobbyView: View {
    @EnvironmentObject var loc: Localization
    @ObservedObject var client: OnlineClient
    let onBack: () -> Void
    let onStarted: () -> Void

    @State private var serverURL = OnlineClient.storedServerURL()
    @State private var roomCodeInput = ""
    @State private var statusMessage = ""
    @State private var isConnecting = false

    var body: some View {
        ZStack {
            BackgroundGlow()

            VStack(spacing: 16) {
                HStack {
                    Button(action: onBack) {
                        Image(systemName: "chevron.left")
                            .foregroundColor(Theme.text)
                            .frame(width: 30, height: 30)
                            .background(Circle().fill(Theme.bgPanel2))
                    }
                    .buttonStyle(.plain)
                    Spacer()
                    LangToggle()
                }
                .padding(.horizontal, 18)
                .padding(.top, 18)

                ScrollView {
                    VStack(spacing: 16) {
                        Text(loc.t("playOnline"))
                            .font(.system(size: 12, weight: .bold))
                            .tracking(2)
                            .foregroundColor(Theme.accent)

                        Text(loc.t("onlineIntro"))
                            .font(.system(size: 14))
                            .foregroundColor(Theme.textDim)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 24)

                        if client.roomCode == nil {
                            connectCard
                        } else {
                            roomCard
                        }

                        if !statusMessage.isEmpty {
                            Text(statusMessage)
                                .font(.system(size: 13))
                                .foregroundColor(Theme.danger)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal, 24)
                        }
                    }
                    .padding(.top, 8)
                }

                Spacer()
            }
        }
        .onChange(of: client.errorMessage) { message in
            guard let message else { return }
            isConnecting = false
            statusMessage = errorText(for: message)
        }
        .onChange(of: client.stateVersion) { version in
            if version == 1 { onStarted() }
        }
    }

    private func errorText(for code: String) -> String {
        switch code {
        case "room-not-found": return loc.t("roomNotFound")
        case "room-full-or-started": return loc.t("roomFull")
        default: return code
        }
    }

    // MARK: - Connect (create/join)

    private var connectCard: some View {
        VStack(spacing: 12) {
            Text(loc.t("serverUrlLabel"))
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(Theme.textFaint)
            TextField("wss://your-server.example.com", text: $serverURL)
                .textFieldStyle(.plain)
                .autocorrectionDisabled()
                #if os(iOS)
                .textInputAutocapitalization(.never)
                #endif
                .padding(10)
                .background(RoundedRectangle(cornerRadius: 8).fill(Theme.bgPanel2))
                .foregroundColor(Theme.text)

            Button(loc.t("createRoom"), action: createRoom)
                .buttonStyle(PrimaryButtonStyle())

            HStack(spacing: 8) {
                TextField(loc.t("roomCodePlaceholder"), text: $roomCodeInput)
                    .textFieldStyle(.plain)
                    .autocorrectionDisabled()
                    #if os(iOS)
                    .textInputAutocapitalization(.characters)
                    #endif
                    .padding(10)
                    .background(RoundedRectangle(cornerRadius: 8).fill(Theme.bgPanel2))
                    .foregroundColor(Theme.text)
                Button(loc.t("joinRoom"), action: joinRoom)
                    .buttonStyle(SecondaryButtonStyle())
            }

            if isConnecting {
                Text(loc.t("connecting"))
                    .font(.system(size: 13))
                    .foregroundColor(Theme.textFaint)
            }
        }
        .padding(16)
        .background(RoundedRectangle(cornerRadius: 12).fill(Theme.bgPanel).overlay(RoundedRectangle(cornerRadius: 12).stroke(Theme.border, lineWidth: 1)))
        .padding(.horizontal, 24)
    }

    private func createRoom() {
        guard !serverURL.isEmpty else { return }
        OnlineClient.storeServerURL(serverURL)
        statusMessage = ""
        isConnecting = true
        client.connect(url: serverURL) { ok in
            isConnecting = false
            if ok { client.createRoom() } else { statusMessage = loc.t("connectionError") }
        }
    }

    private func joinRoom() {
        guard !serverURL.isEmpty, !roomCodeInput.isEmpty else { return }
        OnlineClient.storeServerURL(serverURL)
        statusMessage = ""
        isConnecting = true
        client.connect(url: serverURL) { ok in
            isConnecting = false
            if ok { client.joinRoom(code: roomCodeInput.uppercased()) } else { statusMessage = loc.t("connectionError") }
        }
    }

    // MARK: - Room / seat list

    private var roomCard: some View {
        VStack(spacing: 12) {
            Text(loc.t("yourRoomCode"))
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(Theme.textFaint)
            Text(client.roomCode ?? "")
                .font(.system(size: 28, weight: .heavy, design: .monospaced))
                .tracking(4)
                .foregroundColor(Theme.accent)

            VStack(spacing: 6) {
                ForEach(0..<4, id: \.self) { i in
                    seatRow(i)
                }
            }

            Text(loc.t("onlineSeatFillNote"))
                .font(.system(size: 11))
                .foregroundColor(Theme.textFaint)
                .multilineTextAlignment(.center)

            if client.seat == 0 {
                Button(loc.t("startOnlineMatch"), action: { client.startMatch() })
                    .buttonStyle(PrimaryButtonStyle())
            }
        }
        .padding(16)
        .background(RoundedRectangle(cornerRadius: 12).fill(Theme.bgPanel).overlay(RoundedRectangle(cornerRadius: 12).stroke(Theme.border, lineWidth: 1)))
        .padding(.horizontal, 24)
    }

    private func seatRow(_ index: Int) -> some View {
        let windId = ["wE", "wS", "wW", "wN"][index]
        let seats = client.lobby?.array("seats") ?? []
        let seat = index < seats.count ? seats[index] as? [String: Any] : nil

        return HStack {
            Text(loc.t(windLabelKeysLobby[windId] ?? "windE"))
                .foregroundColor(Theme.text)
            if let seat {
                Text(seat.str("name") ?? "")
                    .foregroundColor(Theme.textDim)
                Spacer()
                let connected = seat.bool("connected") ?? false
                Text(connected ? loc.t("playerConnected") : loc.t("playerWaiting"))
                    .foregroundColor(connected ? Theme.ok : Theme.textFaint)
            } else {
                Spacer()
                Text(loc.t("bot"))
                    .foregroundColor(Theme.textFaint)
            }
        }
        .font(.system(size: 13, weight: .semibold))
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(RoundedRectangle(cornerRadius: 8).fill(Theme.bgPanel2))
    }
}
