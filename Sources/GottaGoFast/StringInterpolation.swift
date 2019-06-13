//
//
//  GottaGoFast — a Swift benchmarking library.
//
//  StringInterpolation.swift
//
//  GitHub
//  https://github.com/broadwaylamb/GottaGoFast
//
//
//  Documentation
//  https://broadwaylamb.github.io/GottaGoFast
//
//
//  License
//  Copyright 2019 Sergej Jaskiewicz
//
//  Permission is hereby granted, free of charge, to any person obtaining a copy
//  of this software and associated documentation files (the "Software"), to
//  deal in the Software without restriction, including without limitation the
//  rights to use, copy, modify, merge, publish, distribute, sublicense, and/or
//  sell copies of the Software, and to permit persons to whom the Software is
//  furnished to do so, subject to the following conditions:
//
//  The above copyright notice and this permission notice shall be included in
//  all copies or substantial portions of the Software.
//
//  THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
//  IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
//  FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
//  AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
//  LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING
//  FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS
//  IN THE SOFTWARE.
//

import Foundation

extension Locale {
    static let posix = Locale(identifier: "en_US_POSIX")
}

internal struct NumberFormat {

    private let formatter: NumberFormatter

    private init(_ formatter: NumberFormatter) {
        self.formatter = formatter
    }

    func string(from number: Double) -> String {
        formatter.string(from: number as NSNumber) ?? String(number)
    }

    static func precision(_ p: Int) -> NumberFormat {
        let f = NumberFormatter()
        f.locale = .posix
        f.maximumFractionDigits = p
        return .init(f)
    }
}

extension String.StringInterpolation {
    internal mutating func appendInterpolation(_ d: Double, _ format: NumberFormat) {
        appendInterpolation(format.string(from: d))
    }
}
