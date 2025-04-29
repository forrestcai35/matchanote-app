private var gridNewButton: some View {
  VStack(spacing: 2) {
    ZStack {
      RoundedRectangle(cornerRadius: 8)
        .stroke(
          style: StrokeStyle(lineWidth: 2, dash: [5])
        )
        .frame(width: 81.92, height: 102.4)
      Image(systemName: "plus")
        .font(.title)
    }
    .foregroundColor(colorScheme == .dark ? Color.matchadark_dark : Color.matchadark_light)

    Text("New...")
      .padding(.top, 4)
      .foregroundColor(
        colorScheme == .dark ? Color.matchadark_dark : Color.matchadark_light
      )
      .frame(width: 81.92)
      .fontWeight(.medium)
      .multilineTextAlignment(.center)
      .font(.subheadline)

    Text(" ")
      .padding(.bottom, 4)
      .font(.caption)
      .frame(width: 81.92)
  }
  .frame(width: 81.92)
}
