import XCTest
@testable import ClearFile

final class ScanEngineTests: XCTestCase {
    func testDiskUsageReturnsPositiveValues() async throws {
        let usage = try await ScanEngine.shared.diskUsage()
        XCTAssertGreaterThan(usage.totalBytes, 0)
        XCTAssertGreaterThanOrEqual(usage.freeBytes, 0)
        XCTAssertLessThanOrEqual(usage.freeBytes, usage.totalBytes)
    }

    func testByteFormatter() {
        XCTAssertFalse(ByteFormatter.format(0).isEmpty)
        XCTAssertFalse(ByteFormatter.format(1024 * 1024 * 1024).isEmpty)
    }

    func testLargeFilesScanInTempDir() async throws {
        let tmp = FileManager.default.temporaryDirectory
            .appendingPathComponent("clearfile-test-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: tmp, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tmp) }

        // 写一个 2MB 文件
        let data = Data(repeating: 0, count: 2 * 1024 * 1024)
        let bigFile = tmp.appendingPathComponent("big.bin")
        try data.write(to: bigFile)

        // 阈值 1MB，应该被找到
        let result = try await ScanEngine.shared.scanLargeFiles(
            roots: [tmp],
            minSizeBytes: 1 * 1024 * 1024
        ) { _, _ in }

        XCTAssertEqual(result.count, 1)
        XCTAssertEqual(result.first?.url.lastPathComponent, "big.bin")
    }
}
