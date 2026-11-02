import ExpoModulesCore
import Foundation
import UIKit
import UniformTypeIdentifiers

private class DocumentPickerDelegate: NSObject, UIDocumentPickerDelegate {
  private let onPick: ([URL]) -> Void
  private let onCancel: () -> Void

  init(onPick: @escaping ([URL]) -> Void, onCancel: @escaping () -> Void) {
    self.onPick = onPick
    self.onCancel = onCancel
    super.init()
  }

  func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
    onPick(urls)
  }

  func documentPickerWasCancelled(_ controller: UIDocumentPickerViewController) {
    onCancel()
  }
}

public class NativeFileModule: Module {
  private static var currentPickerDelegate: DocumentPickerDelegate?

  @MainActor
  private static func presentPicker(_ picker: UIDocumentPickerViewController, delegate: DocumentPickerDelegate) {
    currentPickerDelegate = delegate
    picker.delegate = delegate
    if let scene = UIApplication.shared.connectedScenes.first(where: { $0.activationState == .foregroundActive }) as? UIWindowScene ?? UIApplication.shared.connectedScenes.first as? UIWindowScene,
       let root = scene.windows.first(where: { $0.isKeyWindow })?.rootViewController {
      var presenter = root
      while let presented = presenter.presentedViewController {
        presenter = presented
      }
      if let popover = picker.popoverPresentationController {
        popover.sourceView = presenter.view
        popover.sourceRect = CGRect(x: presenter.view.bounds.midX, y: presenter.view.bounds.midY, width: 0, height: 0)
        popover.permittedArrowDirections = []
      }
      presenter.present(picker, animated: true)
    }
  }

  public func definition() -> ModuleDefinition {
    Name("NativeFile")

    Function("writeFile") { (path: String, content: String) in
      try content.write(toFile: path, atomically: true, encoding: .utf8)
    }

    Function("readFile") { (path: String) in
      try String(contentsOfFile: path, encoding: .utf8)
    }

    Function("copyFile") { (sourcePath: String, destPath: String) in
      try FileManager.default.copyItem(atPath: sourcePath, toPath: destPath)
    }

    AsyncFunction("copyFileToDirectory") { (sourcePath: String, directoryUri: String, fileName: String, mimeType: String, replace: Bool) -> [String: Any] in
      _ = mimeType
      guard !fileName.isEmpty,
            fileName != ".",
            fileName != "..",
            !fileName.contains("/"),
            !fileName.contains("\\") else {
        throw NSError(
          domain: "NativeFile",
          code: 1,
          userInfo: [NSLocalizedDescriptionKey: "Invalid destination file name"]
        )
      }

      let fileManager = FileManager.default
      let directoryURL: URL
      if let parsedURL = URL(string: directoryUri), parsedURL.isFileURL {
        directoryURL = parsedURL
      } else {
        directoryURL = URL(fileURLWithPath: directoryUri, isDirectory: true)
      }
      let sourceURL = URL(fileURLWithPath: sourcePath)
      let destinationURL = directoryURL.appendingPathComponent(fileName)
      let stagingURL = directoryURL.appendingPathComponent(".\(fileName).\(UUID().uuidString).tmp")

      guard fileManager.fileExists(atPath: directoryURL.path) else {
        throw NSError(
          domain: "NativeFile",
          code: 2,
          userInfo: [NSLocalizedDescriptionKey: "Destination directory does not exist"]
        )
      }
      if fileManager.fileExists(atPath: destinationURL.path) && !replace {
        throw CocoaError(.fileWriteFileExists)
      }

      defer { try? fileManager.removeItem(at: stagingURL) }
      try fileManager.copyItem(at: sourceURL, to: stagingURL)
      let attributes = try fileManager.attributesOfItem(atPath: stagingURL.path)
      let copiedSize = (attributes[.size] as? NSNumber)?.int64Value ?? 0

      if fileManager.fileExists(atPath: destinationURL.path) {
        _ = try fileManager.replaceItemAt(destinationURL, withItemAt: stagingURL)
      } else {
        try fileManager.moveItem(at: stagingURL, to: destinationURL)
      }
      return ["uri": destinationURL.absoluteString, "size": copiedSize]
    }

    Function("moveFile") { (sourcePath: String, destPath: String) in
      try FileManager.default.moveItem(atPath: sourcePath, toPath: destPath)
    }

    Function("exists") { (filePath: String) in
      FileManager.default.fileExists(atPath: filePath)
    }

    Function("mkdir") { (filePath: String) in
      try FileManager.default.createDirectory(atPath: filePath, withIntermediateDirectories: true, attributes: nil)
    }

    Function("unlink") { (filePath: String) in
      try FileManager.default.removeItem(atPath: filePath)
    }

    Function("readDir") { (dirPath: String) -> [[String: Any]] in
      let contents = try FileManager.default.contentsOfDirectory(atPath: dirPath)
      return contents.map { fileName in
        let path = (dirPath as NSString).appendingPathComponent(fileName)
        var isDirectory: ObjCBool = false
        FileManager.default.fileExists(atPath: path, isDirectory: &isDirectory)
        return [
          "name": fileName,
          "path": path,
          "isDirectory": isDirectory.boolValue
        ]
      }
    }

    AsyncFunction("downloadFile") { (url: String, destPath: String, method: String, headers: [String: String], body: String?, promise: Promise) in
      guard let requestURL = URL(string: url) else {
        promise.reject("INVALID_URL", "Invalid URL: \(url)")
        return
      }
      var request = URLRequest(url: requestURL)
      request.httpMethod = method.isEmpty ? "GET" : method
      for (key, value) in headers {
        request.setValue(value, forHTTPHeaderField: key)
      }
      if let body = body {
        request.httpBody = body.data(using: .utf8)
      }
      let task = URLSession.shared.downloadTask(with: request) { tempURL, _, error in
        if let error = error {
          promise.reject("DOWNLOAD_ERROR", error.localizedDescription)
          return
        }
        guard let tempURL = tempURL else {
          promise.reject("DOWNLOAD_ERROR", "Download produced no file")
          return
        }
        do {
          let destURL = URL(fileURLWithPath: destPath)
          let fileManager = FileManager.default
          try fileManager.createDirectory(at: destURL.deletingLastPathComponent(), withIntermediateDirectories: true)
          if fileManager.fileExists(atPath: destPath) {
            try fileManager.removeItem(atPath: destPath)
          }
          try fileManager.moveItem(at: tempURL, to: destURL)
          promise.resolve(["path": destPath])
        } catch {
          promise.reject("FILE_ERROR", error.localizedDescription)
        }
      }
      task.resume()
    }

    AsyncFunction("pickDocument") { (mimeType: String, promise: Promise) in
      DispatchQueue.main.async {
        let picker = UIDocumentPickerViewController(forOpeningContentTypes: [.item], asCopy: true)
        let delegate = DocumentPickerDelegate(
          onPick: { urls in
            if let first = urls.first {
              _ = first.startAccessingSecurityScopedResource()
              promise.resolve(first.absoluteString)
            } else {
              promise.reject("ECANCELLED", "No document selected")
            }
          },
          onCancel: {
            promise.reject("ECANCELLED", "Document selection was cancelled")
          }
        )
        Self.presentPicker(picker, delegate: delegate)
      }
    }

    AsyncFunction("pickDirectory") { (promise: Promise) in
      DispatchQueue.main.async {
        let picker = UIDocumentPickerViewController(forOpeningContentTypes: [.folder], asCopy: false)
        let delegate = DocumentPickerDelegate(
          onPick: { urls in
            if let first = urls.first {
              _ = first.startAccessingSecurityScopedResource()
              let folderName = first.lastPathComponent
              promise.resolve([
                "uri": first.absoluteString,
                "name": folderName.isEmpty ? "Selected Folder" : folderName
              ])
            } else {
              promise.reject("ECANCELLED", "No directory selected")
            }
          },
          onCancel: {
            promise.reject("ECANCELLED", "Directory selection was cancelled")
          }
        )
        Self.presentPicker(picker, delegate: delegate)
      }
    }

    AsyncFunction("createDocument") { (filename: String, mimeType: String, promise: Promise) in
      DispatchQueue.main.async {
        let tempDir = FileManager.default.temporaryDirectory
        let tempURL = tempDir.appendingPathComponent(filename)
        if !FileManager.default.fileExists(atPath: tempURL.path) {
          FileManager.default.createFile(atPath: tempURL.path, contents: nil)
        }
        let picker = UIDocumentPickerViewController(forExporting: [tempURL], asCopy: true)
        let delegate = DocumentPickerDelegate(
          onPick: { urls in
            if let first = urls.first {
              _ = first.startAccessingSecurityScopedResource()
              promise.resolve(first.absoluteString)
            } else {
              promise.reject("ECANCELLED", "No document created")
            }
          },
          onCancel: {
            promise.reject("ECANCELLED", "Document creation was cancelled")
          }
        )
        Self.presentPicker(picker, delegate: delegate)
      }
    }

    Constant("DocumentDirectoryPath") {
      let paths = NSSearchPathForDirectoriesInDomains(.documentDirectory, .userDomainMask, true)
      return paths.first ?? ""
    }

    Constant("ExternalDirectoryPath") {
      let paths = NSSearchPathForDirectoriesInDomains(.documentDirectory, .userDomainMask, true)
      return paths.first ?? ""
    }

    Constant("ExternalCachesDirectoryPath") {
      let paths = NSSearchPathForDirectoriesInDomains(.cachesDirectory, .userDomainMask, true)
      return paths.first ?? ""
    }

    Constant("MainBundlePath") {
      Bundle.main.resourcePath ?? Bundle.main.bundlePath
    }
  }
}
