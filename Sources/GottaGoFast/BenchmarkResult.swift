//
//
//  GottaGoFast — a Swift benchmarking library.
//
//  BenchmarkResult.swift
//
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

public struct BenchmarkResult {
    public let measurements: [TimeInterval]
    public let maxRelativeStandardDeviation: Double
    public let standardDeviationNegligibilityThreshold: Double

    public var average: TimeInterval {
        measurements.reduce(0, +) / Double(Int(measurements.count))
    }

    public var standardDeviation: TimeInterval {
        let average = self.average
        let squaredDifferences = measurements.lazy.map { pow($0 - average, 2) }
        let variance = squaredDifferences
            .reduce(0, +) / Double(Int(measurements.count - 1))
        return variance.squareRoot()
    }

    public var relativeStandardDeviation: Double { (standardDeviation * 100) / average }

    public var minimum: TimeInterval { measurements.min()! }

    internal func print() {

        let average = "Average: \(self.average, .precision(3)) seconds"

        let relativeSD = """
        relative standard deviation: \(relativeStandardDeviation, .precision(3))%
        """

        let maxRelativeSD = """
        maxPercentRelativeStandardDeviation: \
        \(maxRelativeStandardDeviation, .precision(3))%
        """

        let maxSD = """
        maxStandardDeviation: \(standardDeviationNegligibilityThreshold, .precision(3))
        """

        let results = [
            average,
            relativeSD,
            maxRelativeSD,
            maxSD
        ]

        Swift.print(results.joined(separator: ", "))
    }
}

public enum BenchmarkStrategy: String, Codable {
    case minimum, average
}

internal struct Baseline: Codable {
    let strategy: BenchmarkStrategy
    let measurement: TimeInterval
    let maxPercentRelativeStandardDeviation: Double
    let userInfo: [String : String]?
}

internal enum BenchmarkError: Error {
    case baselineNotFound
    case osError(POSIXError.Code)
    case wrongProcInfoFormat
}
