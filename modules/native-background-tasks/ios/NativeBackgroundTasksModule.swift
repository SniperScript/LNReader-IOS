import ExpoModulesCore
import Foundation

private struct NativeTask: Codable {
  var id: String
  var type: String
  var payload: String
  var title: String
  var description: String?
  var queueName: String
  var state: String
  var progress: Double?
  var progressText: String?
  var checkpoint: String?
  var attempt: Int
  var createdAt: Double
  var updatedAt: Double
}

public class NativeBackgroundTasksModule: Module {
  private static let storageKey = "LNReader_NativeBackgroundTasks_Store"
  private static let lock = NSLock()
  private static var tasks: [String: NativeTask] = loadTasks()

  private static func loadTasks() -> [String: NativeTask] {
    guard let data = UserDefaults.standard.data(forKey: storageKey),
          let decoded = try? JSONDecoder().decode([String: NativeTask].self, from: data) else {
      return [:]
    }
    return decoded
  }

  private static func persistTasks() {
    if let data = try? JSONEncoder().encode(tasks) {
      UserDefaults.standard.set(data, forKey: storageKey)
    }
  }

  public func definition() -> ModuleDefinition {
    Name("NativeBackgroundTasks")

    Events("LNReaderTaskInterrupted")

    AsyncFunction("enqueue") { (type: String, payload: String, title: String, description: String, allowsDuplicates: Bool, queueName: String) -> String in
      Self.lock.lock()
      defer { Self.lock.unlock() }

      if !allowsDuplicates {
        if let existing = Self.tasks.values.first(where: { $0.type == type && ($0.state == "queued" || $0.state == "running") }) {
          return existing.id
        }
      }

      let now = Date().timeIntervalSince1970 * 1000.0
      let taskId = UUID().uuidString
      let task = NativeTask(
        id: taskId,
        type: type,
        payload: payload,
        title: title,
        description: description.isEmpty ? nil : description,
        queueName: queueName,
        state: "queued",
        progress: nil,
        progressText: nil,
        checkpoint: nil,
        attempt: 0,
        createdAt: now,
        updatedAt: now
      )
      Self.tasks[taskId] = task
      Self.persistTasks()
      return taskId
    }

    AsyncFunction("getTasks") { () -> [[String: Any]] in
      Self.lock.lock()
      defer { Self.lock.unlock() }

      let activeStates: Set<String> = ["queued", "running", "paused"]
      return Self.tasks.values
        .filter { activeStates.contains($0.state) }
        .map { task in
          var dict: [String: Any] = [
            "id": task.id,
            "type": task.type,
            "title": task.title,
            "state": task.state,
            "attempt": task.attempt,
            "createdAt": task.createdAt,
            "updatedAt": task.updatedAt
          ]
          if let desc = task.description { dict["description"] = desc }
          if let prog = task.progress { dict["progress"] = prog }
          if let text = task.progressText { dict["progressText"] = text }
          return dict
        }
    }

    AsyncFunction("getTask") { (taskId: String) -> [String: Any]? in
      Self.lock.lock()
      defer { Self.lock.unlock() }

      guard let task = Self.tasks[taskId] else { return nil }
      var dict: [String: Any] = [
        "id": task.id,
        "type": task.type,
        "title": task.title,
        "state": task.state,
        "attempt": task.attempt,
        "createdAt": task.createdAt,
        "updatedAt": task.updatedAt,
        "payload": task.payload
      ]
      if let desc = task.description { dict["description"] = desc }
      if let prog = task.progress { dict["progress"] = prog }
      if let text = task.progressText { dict["progressText"] = text }
      if let checkpoint = task.checkpoint { dict["checkpoint"] = checkpoint }
      return dict
    }

    AsyncFunction("pause") { (taskId: String) in
      Self.lock.lock()
      defer { Self.lock.unlock() }

      guard var task = Self.tasks[taskId] else { return }
      task.state = "paused"
      task.updatedAt = Date().timeIntervalSince1970 * 1000.0
      Self.tasks[taskId] = task
      Self.persistTasks()

      self.sendEvent("LNReaderTaskInterrupted", ["taskId": taskId, "action": "pause"])
    }

    AsyncFunction("resume") { (taskId: String) in
      Self.lock.lock()
      defer { Self.lock.unlock() }

      guard var task = Self.tasks[taskId] else { return }
      task.state = "queued"
      task.updatedAt = Date().timeIntervalSince1970 * 1000.0
      Self.tasks[taskId] = task
      Self.persistTasks()
    }

    AsyncFunction("cancel") { (taskId: String) in
      Self.lock.lock()
      defer { Self.lock.unlock() }

      guard var task = Self.tasks[taskId] else { return }
      task.state = "cancelled"
      task.updatedAt = Date().timeIntervalSince1970 * 1000.0
      Self.tasks[taskId] = task
      Self.persistTasks()

      self.sendEvent("LNReaderTaskInterrupted", ["taskId": taskId, "action": "cancel"])
    }

    AsyncFunction("updateProgress") { (taskId: String, progress: Double, progressText: String) in
      Self.lock.lock()
      defer { Self.lock.unlock() }

      guard var task = Self.tasks[taskId] else { return }
      task.progress = progress >= 0 ? progress : nil
      task.progressText = progressText.isEmpty ? nil : progressText
      task.state = "running"
      task.updatedAt = Date().timeIntervalSince1970 * 1000.0
      Self.tasks[taskId] = task
      Self.persistTasks()
    }

    AsyncFunction("updateCheckpoint") { (taskId: String, checkpoint: String) in
      Self.lock.lock()
      defer { Self.lock.unlock() }

      guard var task = Self.tasks[taskId] else { return }
      task.checkpoint = checkpoint
      task.updatedAt = Date().timeIntervalSince1970 * 1000.0
      Self.tasks[taskId] = task
      Self.persistTasks()
    }

    AsyncFunction("complete") { (taskId: String, completionText: String) in
      Self.lock.lock()
      defer { Self.lock.unlock() }

      guard var task = Self.tasks[taskId] else { return }
      task.state = "completed"
      task.progressText = completionText.isEmpty ? nil : completionText
      task.checkpoint = nil
      task.updatedAt = Date().timeIntervalSince1970 * 1000.0
      Self.tasks[taskId] = task
      Self.persistTasks()
    }

    AsyncFunction("fail") { (taskId: String, error: String, shouldRetry: Bool) in
      Self.lock.lock()
      defer { Self.lock.unlock() }

      guard var task = Self.tasks[taskId] else { return }
      task.state = "failed"
      task.progressText = error
      task.updatedAt = Date().timeIntervalSince1970 * 1000.0
      Self.tasks[taskId] = task
      Self.persistTasks()
    }

    AsyncFunction("scheduleLibraryUpdates") { (intervalHours: Double, title: String, description: String) in
      // iOS background task scheduling placeholder
    }

    AsyncFunction("cancelLibraryUpdates") {
      // iOS cancel background updates placeholder
    }

    AsyncFunction("scheduleAutomaticBackups") { (intervalHours: Double, title: String, description: String, directoryUri: String) in
      // iOS schedule backups placeholder
    }

    AsyncFunction("cancelAutomaticBackups") {
      // iOS cancel backups placeholder
    }
  }
}
