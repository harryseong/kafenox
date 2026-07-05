import SwiftUI

/// The "Ask AI" tab of the Insights screen: empty state with suggested
/// questions, chat thread, and a composer pinned above the tab bar.
struct AskAIView: View {
    @Bindable var viewModel: AskAIViewModel
    let palette: Palette

    @FocusState private var inputFocused: Bool

    private enum ScrollTarget: Hashable { case bottom }

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                VStack(alignment: .leading, spacing: 10) {
                    if viewModel.showsEmptyState {
                        emptyState
                    } else {
                        thread
                    }
                    Color.clear.frame(height: 1).id(ScrollTarget.bottom)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.top, 16)
            }
            .scrollDismissesKeyboard(.interactively)
            .onChange(of: viewModel.messages) {
                withAnimation { proxy.scrollTo(ScrollTarget.bottom, anchor: .bottom) }
            }
            .onChange(of: viewModel.isBusy) {
                withAnimation { proxy.scrollTo(ScrollTarget.bottom, anchor: .bottom) }
            }
        }
        // As a safe-area inset (not a VStack sibling) the composer stacks
        // above the tab bar's own bottom inset instead of sliding under the
        // opaque bar, and keyboard avoidance keeps working.
        .safeAreaInset(edge: .bottom) { composer }
    }

    // MARK: Empty state

    private var emptyState: some View {
        VStack(spacing: 0) {
            Circle()
                .fill(palette.surface2)
                .frame(width: 44, height: 44)
                .overlay(
                    Image(systemName: "sparkle")
                        .font(.system(size: 19, weight: .regular))
                        .foregroundStyle(palette.fg)
                )
            Text("Ask about your taste")
                .font(.app(15.5, weight: .semibold))
                .foregroundStyle(palette.fg)
                .padding(.top, 12)
            Text("Answers are based on your ratings, origins, and flavor notes.")
                .font(.app(13))
                .foregroundStyle(palette.muted)
                .lineSpacing(3)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 250)
                .padding(.top, 5)

            VStack(spacing: 7) {
                ForEach(AskAIViewModel.suggestions, id: \.self) { suggestion in
                    Button {
                        viewModel.send(suggestion)
                    } label: {
                        Text(suggestion)
                            .font(.app(13.5, weight: .medium))
                            .foregroundStyle(palette.fg)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.vertical, 11)
                            .padding(.horizontal, 14)
                            .background(palette.surface, in: RoundedRectangle(cornerRadius: 14))
                            .overlay(RoundedRectangle(cornerRadius: 14).stroke(palette.line, lineWidth: 1))
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.top, 14)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 34)
        .padding(.horizontal, 16)
        .padding(.bottom, 10)
    }

    // MARK: Thread

    private var thread: some View {
        VStack(alignment: .leading, spacing: 10) {
            ForEach(viewModel.messages) { message in
                bubble(message)
            }
            if viewModel.isBusy {
                thinkingBubble
            }
            if viewModel.isError {
                Text("Couldn't reach the model. Try again in a moment.")
                    .font(.app(12.5))
                    .foregroundStyle(Palette.error)
                    .padding(.vertical, 2)
                    .padding(.horizontal, 4)
            }
        }
    }

    private func bubble(_ message: ChatMessage) -> some View {
        let fromUser = message.role == .user
        return HStack {
            if fromUser { Spacer(minLength: 0) }
            Text(message.text)
                .font(.app(13.5, weight: fromUser ? .medium : .regular))
                .foregroundStyle(fromUser ? palette.bg : palette.fg)
                .lineSpacing(3)
                .padding(.vertical, 10)
                .padding(.horizontal, 14)
                .background(
                    BubbleShape(sharpCorner: fromUser ? .bottomRight : .bottomLeft)
                        .fill(fromUser ? palette.fg : palette.surface)
                )
                .overlay(
                    fromUser
                        ? nil
                        : BubbleShape(sharpCorner: .bottomLeft).stroke(palette.line, lineWidth: 1)
                )
                .frame(maxWidth: fromUser ? 280 : 310, alignment: fromUser ? .trailing : .leading)
            if !fromUser { Spacer(minLength: 0) }
        }
    }

    private var thinkingBubble: some View {
        HStack(spacing: 8) {
            ProgressView()
                .controlSize(.small)
                .tint(palette.fg)
            Text("Thinking")
                .font(.app(12.5, weight: .medium))
                .foregroundStyle(palette.muted)
        }
        .padding(.vertical, 11)
        .padding(.horizontal, 14)
        .background(BubbleShape(sharpCorner: .bottomLeft).fill(palette.surface))
        .overlay(BubbleShape(sharpCorner: .bottomLeft).stroke(palette.line, lineWidth: 1))
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: Composer

    private var composer: some View {
        HStack(spacing: 8) {
            TextField("What should I try next?", text: $viewModel.input)
                .font(.app(14))
                .foregroundStyle(palette.fg)
                .focused($inputFocused)
                .submitLabel(.send)
                .onSubmit { viewModel.send(viewModel.input) }
                .padding(.leading, 16)

            Button {
                viewModel.send(viewModel.input)
            } label: {
                Circle()
                    .fill(palette.fg)
                    .frame(width: 36, height: 36)
                    .overlay(
                        Image(systemName: "arrow.up")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(palette.bg)
                    )
            }
            .buttonStyle(.plain)
            .disabled(viewModel.isBusy)
            .opacity(viewModel.isBusy ? 0.5 : 1)
        }
        .padding(5)
        .background(palette.surface, in: Capsule())
        .overlay(Capsule().stroke(palette.line, lineWidth: 1))
        .padding(.top, 8)
        .padding(.bottom, 6)
        .background(palette.bg)
    }
}

/// Rounded chat bubble with one sharper corner on the sender's side,
/// mirroring the design's 16px radius / 5px anchored corner.
private struct BubbleShape: Shape {
    enum Corner { case bottomLeft, bottomRight }
    let sharpCorner: Corner

    func path(in rect: CGRect) -> Path {
        let radii = RectangleCornerRadii(
            topLeading: 16,
            bottomLeading: sharpCorner == .bottomLeft ? 5 : 16,
            bottomTrailing: sharpCorner == .bottomRight ? 5 : 16,
            topTrailing: 16
        )
        return UnevenRoundedRectangle(cornerRadii: radii).path(in: rect)
    }
}
