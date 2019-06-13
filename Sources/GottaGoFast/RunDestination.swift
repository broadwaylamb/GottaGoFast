//
//
//  GottaGoFast — a Swift benchmarking library.
//
//  RunDestination.swift
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
import CoreFoundation

#if canImport(Darwin)
import Darwin
#elseif canImport(Glibc)
import Glibc
#else
#error("This platform is not supported")
#endif

struct RunDestination: Codable, Equatable {

  let busSpeedInMHz: Int?
  let cpuCount: Int
  let cpuKind: String
  let cpuSpeedInMHz: Int
  let logicalCPUCoresPerPackage: Int
  let modelCode: String?
  let physicalCPUCoresPerPackage: Int
  let platform: String
  let arch: String

  private init(busSpeedInMHz: Int?,
               cpuCount: Int,
               cpuKind: String,
               cpuSpeedInMHz: Int,
               logicalCPUCoresPerPackage: Int,
               modelCode: String?,
               physicalCPUCoresPerPackage: Int,
               platform: String,
               arch: String) {
    self.busSpeedInMHz = busSpeedInMHz
    self.cpuCount = cpuCount
    self.cpuKind = cpuKind
    self.cpuSpeedInMHz = cpuSpeedInMHz
    self.logicalCPUCoresPerPackage = logicalCPUCoresPerPackage
    self.modelCode = modelCode
    self.physicalCPUCoresPerPackage = physicalCPUCoresPerPackage
    self.platform = platform
    self.arch = arch
  }

  static func current() throws -> RunDestination {
#if canImport(Darwin)

    func bufferSize(for name: String) -> Int {
        var sizeof = 0
        sysctlbyname(name, nil, &sizeof, nil, 0)
        precondition(sizeof > 0)
        return sizeof
    }

    func numericValue<T: BinaryInteger>(for name: String) -> T {
        var val = T.zero
        var size = MemoryLayout.size(ofValue: val)
        let status = sysctlbyname(name, &val, &size, nil, 0)
        precondition(status == 0, "Cannot read \(name) using sysctl")
        return val
    }

    func stringValue(for name: String) -> String {
        var size = bufferSize(for: name)
        let buffer = UnsafeMutablePointer<CChar>.allocate(capacity: size + 1)
        defer { buffer.deallocate() }
        let status = sysctlbyname(name, buffer, &size, nil, 0)
        precondition(status == 0, "Cannot read \(name) using sysctl")
        buffer[size] = 0
        return String(cString: buffer)
    }

    let busFrequency: Int64 = numericValue(for: "hw.busfrequency")
    let packageCount: Int32 = numericValue(for: "hw.packages")
    let cpuName = stringValue(for: "machdep.cpu.brand_string")
    let cpuFrequency: Int64 = numericValue(for: "hw.cpufrequency")
#if os(iOS) && !arch(x86_64) && !arch(i386)
    let modelCode = stringValue(for: "hw.machine")
    let arch = stringValue(for: "hw.model")
#else
    let modelCode = stringValue(for: "hw.model")
    let arch = stringValue(for: "hw.machine")
#endif
    let logicalCoresPerPackage: Int32 = numericValue(for: "machdep.cpu.cores_per_package")
    let physicalCoresPerPackage: Int32 = numericValue(for: "hw.physicalcpu")
    let osName = stringValue(for: "kern.ostype")
    let osRelease = stringValue(for: "kern.osrelease")


    return RunDestination(
      busSpeedInMHz: Int(busFrequency / 1_000_000),
      cpuCount: Int(packageCount),
      cpuKind: cpuName,
      cpuSpeedInMHz: Int(cpuFrequency / 1_000_000),
      logicalCPUCoresPerPackage: Int(logicalCoresPerPackage),
      modelCode: modelCode,
      physicalCPUCoresPerPackage: Int(physicalCoresPerPackage),
      platform: "\(osName) \(osRelease)",
      arch: arch
    )

#elseif canImport(Glibc)
    let cpuinfo = try String(contentsOfFile: "/proc/cpuinfo")
        .split(separator: "\n")
        .map { line -> (key: String, value: String) in
            let components = line
                .split(separator: ":", maxSplits: 2, omittingEmptySubsequences: false)
                .map { $0.trimmingCharacters(in: .whitespaces) }
            if components.count != 2 { throw BenchmarkError.wrongProcInfoFormat }
            return (key: components[0], value: components[1])
        }.lazy

    let packageCount = cpuinfo
        .filter { $0.key == "physical id" }
        .compactMap { Int($0.value) }
        .max()!

    let cpuName = cpuinfo.first { $0.key == "model name" }!.value

    let cpuFrequency = cpuinfo
        .first { $0.key == "cpu MHz" }
        .flatMap { Double($0.value) }
        .map(Int.init)!

    let logicalCoresPerPackage = cpuinfo
        .first { $0.key == "cpu cores" }
        .flatMap { Int($0.value) }!

    var unameResult = utsname()
    uname(&unameResult)

    let osName = withUnsafeBytes(of: &unameResult.sysname) { ptr -> String in
        return String(cString: ptr.baseAddress!.assumingMemoryBound(to: CChar.self))
    }

    let osRelease = withUnsafeBytes(of: &unameResult.release) { ptr -> String in
        return String(cString: ptr.baseAddress!.assumingMemoryBound(to: CChar.self))
    }

    let arch = withUnsafeBytes(of: &unameResult.machine) { ptr -> String in
        return String(cString: ptr.baseAddress!.assumingMemoryBound(to: CChar.self))
    }

    return RunDestination(
        busSpeedInMHz: nil,
        cpuCount: packageCount,
        cpuKind: cpuName,
        cpuSpeedInMHz: cpuFrequency,
        logicalCPUCoresPerPackage: logicalCoresPerPackage,
        modelCode: nil,
        physicalCPUCoresPerPackage: logicalCoresPerPackage,
        platform: "\(osName) \(osRelease)",
        arch: arch
    )
#else
#error("This platform does not support benchmarking")
#endif
  }
}
