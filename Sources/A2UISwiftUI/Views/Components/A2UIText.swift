// Copyright 2026 Google LLC
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//      https://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

import SwiftUI
import A2UISwiftCore

/// # Text
/// Maps `variant` (h1-h5, caption, body) to semantic `Font` and `AccessibilityHeadingLevel`.
/// Supports inline Markdown via `AttributedString(markdown:)`. Styles are overridable through
/// `A2UIStyle.textStyles` (font, weight, color per variant). Caption defaults to `.secondary` color.
struct A2UIText: View {
    let node: ComponentNode
    let surface: SurfaceModel

    @Environment(\.a2uiStyle) private var style

    private var dataContextPath: String { node.dataContextPath }

    var body: some View {
        if let props = try? node.typedProperties(TextProperties.self) {
            let dc = DataContext(surface: surface, path: dataContextPath)

            if dc.isUnresolvedBinding(props.text) {
                placeholderText(variant: props.variant)
                    .redacted(reason: .placeholder)
                    .a2uiAccessibility(node.accessibility, dataContext: dc)
                    .padding(style.leafMargin)
            } else {
                let resolved = dc.resolve(props.text)
                let variant = props.variant
                let override = style.textStyles[variant?.rawValue ?? "body"]

                // LOCAL DEVIATION (poc0, 2026-11-23): a value that resolved
                // to an EMPTY/whitespace/punctuation-only string (payloads do
                // carry bare "-" locations) renders NOTHING — not an
                // empty line. The clause uses sub:"" for "no location";
                // without this the row reserves a caption line of air.
                // Unresolved bindings (streaming skeletons) unchanged.
                if !resolved.contains(where: { $0.isLetter || $0.isNumber }) {
                    EmptyView()
                } else {
                    styledText(resolved, variant: variant, override: override)
                        .a2uiAccessibility(node.accessibility, dataContext: dc)
                        .padding(style.leafMargin)
                }
            }
        }
    }

    /// Returns a dummy `Text` of appropriate length for the variant.
    /// The content is irrelevant — it will be hidden by `.redacted(reason: .placeholder)`.
    private func placeholderText(variant: TextVariant?) -> Text {
        switch variant {
        case .h1:      return Text("Loading heading")
        case .h2:      return Text("Loading heading")
        case .h3:      return Text("Loading heading")
        case .h4:      return Text("Loading heading")
        case .h5:      return Text("Loading heading")
        case .caption: return Text("Loading")
        default:       return Text("Loading content text")
        }
    }

    private func styledText(
        _ resolved: String,
        variant: TextVariant?,
        override: A2UIStyle.TextStyle?
    ) -> some View {
        let weight = override?.weight
        let color = override?.color ?? defaultColor(for: variant)
        let level = accessibilityHeadingLevel(for: variant)

        return Text(markdownAttributedString(resolved))
            .font(override?.font ?? defaultFont(for: variant))
            .fontWeight(weight)
            .foregroundColor(color)
            // LOCAL DEVIATION (poc0, 2026-11-24 11:46): long titles
            // intermittently truncated to ONE line inside our List rows —
            // which pill got hit moved between renders of identical data
            // (field 11:31 vs 11:45), i.e. the row was typeset against a
            // stale one-line height proposal from the placeholder pass
            // (A2UIBubble builds its view model in onAppear). fixedSize
            // vertical makes every Text commit the height IT needs for
            // the width it is given, so the row can never under-reserve.
            // Horizontal stays flexible: wrapping is exactly what we want.
            .fixedSize(horizontal: false, vertical: true)
            .accessibilityAddTraits(level != nil ? .isHeader : [])
            .accessibilityHeading(level ?? .unspecified)
    }

    /// Default semantic font for the given variant.
    private func defaultFont(for variant: TextVariant?) -> Font {
        switch variant {
        case .h1: return .largeTitle
        case .h2: return .title
        case .h3: return .title2
        case .h4: return .title3
        case .h5: return .headline
        case .caption: return .caption
        default: return .body
        }
    }

    /// Default foreground color for the given variant (nil = inherit).
    private func defaultColor(for variant: TextVariant?) -> Color? {
        variant == .caption ? .secondary : nil
    }

    /// Maps heading variants to VoiceOver heading levels.
    private func accessibilityHeadingLevel(
        for variant: TextVariant?
    ) -> AccessibilityHeadingLevel? {
        switch variant {
        case .h1: return .h1
        case .h2: return .h2
        case .h3: return .h3
        case .h4: return .h4
        case .h5: return .h5
        default: return nil
        }
    }

    private func markdownAttributedString(_ string: String) -> AttributedString {
        (try? AttributedString(markdown: string, options: .init(interpretedSyntax: .inlineOnlyPreservingWhitespace))) ?? AttributedString(string)
    }
}
