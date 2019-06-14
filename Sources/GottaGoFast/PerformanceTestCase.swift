//
//
//  GottaGoFast — a Swift benchmarking library.
//
//  PerformanceTestCase.swift
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

import XCTest
import Foundation
import Yams

open class PerformanceTestCase: XCTestCase {

    public var overwriteBaseline: Bool = false

    private var _saveNewBaselineClosure: (() throws -> Void)? = nil

    public var benchmarkUserInfo: [String : String] = [:]

    private var _baselineDir: URL?

    private static var _destinationURL: URL?
    private static var _encodedBaselines: String?

    override open func setUp() {
        super.setUp()
        overwriteBaseline = false
        _saveNewBaselineClosure = nil
        benchmarkUserInfo = [:]
    }

    override open func tearDown() {

        do {
            try _saveNewBaselineClosure?()
        } catch {
            XCTFail(error.localizedDescription)
        }

        overwriteBaseline = false
        _saveNewBaselineClosure = nil
        benchmarkUserInfo = [:]

        super.tearDown()
    }

    open override class func tearDown() {

        if let destinationURL = _destinationURL,
           let encodedBaselines = _encodedBaselines {
            // Only display the final baselines after the whole suite has run.
            print("""
            If running on CI, you can update the baseline by copying \
            the following YAML and replace the contents of \(destinationURL) with it:

            """)

            print(encodedBaselines, terminator: "\n\n")
        }

        super.tearDown()
    }

    open var baselinesDir: URL {
        if let dir = _baselineDir {
            return dir
        }

        fatalError("baselineDir must be overriden in a subclass")
    }

    public final var baselinesInfo: URL {
        return baselinesDir.appendingPathComponent("Info.yml")
    }

    open var maxRelativeStandardDeviation: Double { 15.0 }

    open var standardDeviationNegligibilityThreshold: Double { 0.1 }

    internal var testcaseName: String {
        return String(describing: type(of: self))
    }

    internal var testName: String {
        // Since on Apple platforms `self.name` has
        // format `-[XCTestCaseSubclassName testMethodName]`,
        // and on other platforms the format is
        // `XCTestCaseSubclassName.testMethodName`
        // we have this workaround in order to unify the names
        let methodName = name
            .components(separatedBy: testcaseName)
            .last!
            .trimmingCharacters(in: CharacterSet.alphanumerics.inverted)

        if testInfo.isEmpty {
            return methodName
        } else {
            return "\(methodName) | \(testInfo)"
        }
    }

    open var testInfo: String { return "" }

    @discardableResult
    open func benchmark(file: StaticString = #file,
                        line: UInt = #line,
                        allowFailure: Bool = false,
                        executionCount: Int = 10,
                        strategy: BenchmarkStrategy = .minimum,
                        _ block: () throws -> Void) throws -> BenchmarkResult? {

        var baselineDir = URL(fileURLWithPath: file.description)
        baselineDir = URL(fileURLWithPath: file.description)
        baselineDir.deleteLastPathComponent()
        baselineDir.deleteLastPathComponent()
        baselineDir.appendPathComponent("PerformanceBaselines")
        try FileManager.default.createDirectory(at: baselineDir,
                                                withIntermediateDirectories: true)
        _baselineDir = baselineDir

        var measurements = [TimeInterval]()

        for _ in 0 ..< executionCount {
            let startTime = ProcessInfo.processInfo.systemUptime
            try block()
            let stopTime = ProcessInfo.processInfo.systemUptime
            measurements.append(stopTime - startTime)
        }

        let result = BenchmarkResult(
            measurements:
                measurements,
            maxRelativeStandardDeviation:
                maxRelativeStandardDeviation,
            standardDeviationNegligibilityThreshold:
                standardDeviationNegligibilityThreshold
        )

        result.print()
        _validateBenchmark(result,
                           strategy: strategy,
                           allowFailure: allowFailure,
                           file: file,
                           line: line)
        return result
    }

    private func _validateBenchmark(_ result: BenchmarkResult,
                                    strategy: BenchmarkStrategy,
                                    allowFailure: Bool,
                                    file: StaticString,
                                    line: UInt) {

        if strategy == .average,
            result.relativeStandardDeviation > maxRelativeStandardDeviation,
            result.standardDeviation > standardDeviationNegligibilityThreshold {

            let failureReason = """
            The relative standard deviation of the measurements is \
            \(result.relativeStandardDeviation, .precision(3))% \
            which is higher than the max allowed of \
            \(maxRelativeStandardDeviation, .precision(3))%.
            """

            if allowFailure {
                testLog(failureReason)
            } else {
                XCTFail(failureReason, file: file, line: line)
            }
            return
        }

        do {

            let data = (try? String(contentsOf: baselinesInfo)) ?? ""

            let decoder = Self._decoder

            let destinations = (try? decoder
                .decode([String : RunDestination].self, from: data)) ?? [:]

            let currentDestination = try RunDestination.current()

            guard let baselineUUID = destinations
                .first(where: { $0.value == currentDestination })?.key else {

                    _saveNewBaselineClosure = { [unowned self] in
                        try self._saveNewBaselineIfNeeded(currentDestination,
                                                  result,
                                                  strategy: strategy,
                                                  existingDestinationUUID: nil,
                                                  existingDestinations: destinations,
                                                  existingBaselines: [:])
                    }

                    throw BenchmarkError.baselineNotFound
            }

            let baselineData = try String(
                contentsOf: baselinesDir.appendingPathComponent("\(baselineUUID).yml")
            )

            let baselines = try decoder
                .decode([String : [String : Baseline]].self, from: baselineData)

            guard let baseline = baselines[testcaseName]?[testName] else {

                _saveNewBaselineClosure = { [unowned self] in
                    try self._saveNewBaselineIfNeeded(currentDestination,
                                              result,
                                              strategy: strategy,
                                              existingDestinationUUID: baselineUUID,
                                              existingDestinations: destinations,
                                              existingBaselines: baselines)
                }
                

                throw BenchmarkError.baselineNotFound
            }

            let metric: KeyPath<BenchmarkResult, TimeInterval>
            switch strategy {
            case .average:
                metric = \.average
            case .minimum:
                metric = \.minimum
            }

            let relativePercentDiff = baseline.measurement / result[keyPath: metric] * 100

            let withinMargin =
                abs(relativePercentDiff) <= baseline.maxPercentRelativeStandardDeviation

            if relativePercentDiff < 1 {

                let failureSecription = """

                \(withinMargin || allowFailure ? "" : "⛔️⛔️⛔️")
                Strategy: \(strategy),
                Baseline measurement: \(baseline.measurement, .precision(5)), \
                new measurement: \(result[keyPath: metric], .precision(5)), \
                which is \(1 / relativePercentDiff, .precision(3))% slower, \
                (\(withinMargin
                ? "but withing the margin of"
                : "max allowed deviation is") \
                \(baseline.maxPercentRelativeStandardDeviation, .precision(3))%).


                """

                if allowFailure || withinMargin {
                    testLog(failureSecription)
                } else {
                    XCTFail(failureSecription)
                }
            } else {

                let successSecription = """


                \(withinMargin || allowFailure ? "" : "🎉🎉🎉")
                Strategy: \(strategy),
                Baseline measurement: \(baseline.measurement, .precision(5)), \
                new measurement: \(result[keyPath: metric], .precision(5)), \
                which is \(relativePercentDiff, .precision(3))% faster.


                """
                print(successSecription)
            }

            _saveNewBaselineClosure = { [unowned self] in
                try self._saveNewBaselineIfNeeded(currentDestination,
                                          result,
                                          strategy: strategy,
                                          existingDestinationUUID: baselineUUID,
                                          existingDestinations: destinations,
                                          existingBaselines: baselines)
            }
        } catch {
            XCTFail(String(describing: error), file: file, line: line)
            return
        }
    }

    private static let _encoder: YAMLEncoder = {
        let encoder = YAMLEncoder()
        encoder.options.sortKeys = true
        encoder.options.width = 90
        return encoder
    }()

    private static let _decoder = YAMLDecoder()

    private func _saveNewBaselineIfNeeded(
        _ runDestination: RunDestination,
        _ result: BenchmarkResult,
        strategy: BenchmarkStrategy,
        existingDestinationUUID: String?,
        existingDestinations: [String : RunDestination],
        existingBaselines: [String : [String : Baseline]]
    ) throws {

        var existingDestinations = existingDestinations
        var existingBaselines = existingBaselines

        let hasDestination = existingDestinationUUID != nil

        let uuid = existingDestinationUUID ?? UUID().uuidString
        existingDestinations[uuid] = runDestination

        let encoder = Self._encoder

        let encodedDestinations = try encoder.encode(existingDestinations)

        if overwriteBaseline {
            try encodedDestinations.write(to: baselinesInfo,
                                          atomically: true,
                                          encoding: .utf8)
        }

        let baseline = Baseline(
            strategy: strategy,
            measurement: result.average,
            maxPercentRelativeStandardDeviation: 10.0,
            userInfo: benchmarkUserInfo.isEmpty ? nil : benchmarkUserInfo
        )

        existingBaselines[testcaseName,
                          default: [testName : baseline]][testName] = baseline

        let destinationURL = baselinesDir.appendingPathComponent("\(uuid).yml")

        Self._destinationURL = destinationURL

        let encodedBaselines = try encoder.encode(existingBaselines)
        Self._encodedBaselines = encodedBaselines

        if overwriteBaseline {
            try encodedBaselines.write(to: destinationURL,
                                       atomically: true,
                                       encoding: .utf8)
        }

        if !hasDestination {
            print("""
            If running on CI, you can update the destinations by copying \
            the following YAML and replace the contents of \(baselinesInfo) with it:

            """)

            print(encodedDestinations, terminator: "\n\n")
        }
    }

    func testLog(_ log: Any) {
        print("\(testcaseName).\(testName):", log, terminator: "\n\n")
    }
}
