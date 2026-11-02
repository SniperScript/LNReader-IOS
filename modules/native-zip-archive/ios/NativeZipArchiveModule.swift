import ExpoModulesCore
import Foundation
import SSZipArchive

public class NativeZipArchiveModule: Module {
  public func definition() -> ModuleDefinition {
    Name("NativeZipArchive")

    AsyncFunction("unzip") { (sourceFilePath: String, distDirPath: String, promise: Promise) in
      DispatchQueue.global(qos: .userInitiated).async {
        let fileManager = FileManager.default
        try? fileManager.createDirectory(atPath: distDirPath, withIntermediateDirectories: true, attributes: nil)
        let success = SSZipArchive.unzipFile(atPath: sourceFilePath, toDestination: distDirPath)
        if success {
          promise.resolve(nil)
        } else {
          promise.reject("UNZIP_FAILED", "Failed to unzip file at \(sourceFilePath)")
        }
      }
    }

    AsyncFunction("zip") { (sourceDirPath: String, zipFilePath: String, promise: Promise) in
      DispatchQueue.global(qos: .userInitiated).async {
        let zipURL = URL(fileURLWithPath: zipFilePath)
        try? FileManager.default.createDirectory(at: zipURL.deletingLastPathComponent(), withIntermediateDirectories: true)
        if FileManager.default.fileExists(atPath: zipFilePath) {
          try? FileManager.default.removeItem(atPath: zipFilePath)
        }
        let success = SSZipArchive.createZipFile(atPath: zipFilePath, withContentsOfDirectory: sourceDirPath)
        if success {
          promise.resolve(nil)
        } else {
          promise.reject("ZIP_FAILED", "Failed to create zip file at \(zipFilePath)")
        }
      }
    }

    AsyncFunction("remoteUnzip") { (distDirPath: String, urlString: String, headers: [String: String], promise: Promise) in
      guard let url = URL(string: urlString) else {
        promise.reject("INVALID_URL", "Invalid URL: \(urlString)")
        return
      }
      var request = URLRequest(url: url)
      for (k, v) in headers {
        request.setValue(v, forHTTPHeaderField: k)
      }
      let task = URLSession.shared.downloadTask(with: request) { tempURL, _, error in
        if let error = error {
          promise.reject("DOWNLOAD_FAILED", error.localizedDescription)
          return
        }
        guard let tempURL = tempURL else {
          promise.reject("DOWNLOAD_FAILED", "No downloaded file")
          return
        }
        DispatchQueue.global(qos: .userInitiated).async {
          try? FileManager.default.createDirectory(atPath: distDirPath, withIntermediateDirectories: true, attributes: nil)
          let success = SSZipArchive.unzipFile(atPath: tempURL.path, toDestination: distDirPath)
          try? FileManager.default.removeItem(at: tempURL)
          if success {
            promise.resolve(distDirPath)
          } else {
            promise.reject("UNZIP_FAILED", "Failed to unzip downloaded file")
          }
        }
      }
      task.resume()
    }

    AsyncFunction("remoteZip") { (sourceDirPath: String, urlString: String, headers: [String: String], promise: Promise) in
      guard let url = URL(string: urlString) else {
        promise.reject("INVALID_URL", "Invalid URL: \(urlString)")
        return
      }
      let tempZip = FileManager.default.temporaryDirectory.appendingPathComponent("\(UUID().uuidString).zip")
      DispatchQueue.global(qos: .userInitiated).async {
        let success = SSZipArchive.createZipFile(atPath: tempZip.path, withContentsOfDirectory: sourceDirPath)
        guard success else {
          promise.reject("ZIP_FAILED", "Failed to create zip archive")
          return
        }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        for (k, v) in headers {
          request.setValue(v, forHTTPHeaderField: k)
        }
        let task = URLSession.shared.uploadTask(with: request, fromFile: tempZip) { data, _, error in
          try? FileManager.default.removeItem(at: tempZip)
          if let error = error {
            promise.reject("UPLOAD_FAILED", error.localizedDescription)
            return
          }
          let resultString = data.flatMap { String(data: $0, encoding: .utf8) } ?? ""
          promise.resolve(resultString)
        }
        task.resume()
      }
    }
  }
}
