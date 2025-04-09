import SwiftUI
import matchanote_app

struct UserPreferences: Codable {
  var defaultPaperStyle: PaperStyle = .blank
  var defaultPaperColor: PaperColor = .white
  var defaultPaperSize: PaperSize = .a4
//  var penColor1: Color = .white
//  var penColor2: Color = .gray
//  var penColor3: Color = .black
//  var penSize1: CGFloat = 1
//  var penSize2: CGFloat = 2
//  var penSize3: CGFloat = 3
//  var highlighterColor1: Color = .yellow
//  var highlighterColor2: Color = .orange
//  var highlighterColor3: Color = .red

}
