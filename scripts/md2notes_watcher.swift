import Foundation

let watchPath = (("~/Documents/Claude-OCR-Notes" as NSString).expandingTildeInPath)
let convertScript = (("~/Library/Scripts/md2notes_convert.sh" as NSString).expandingTildeInPath)
let fm = FileManager.default

try? fm.createDirectory(atPath: watchPath, withIntermediateDirectories: true)

let lock = NSLock()
var inProgress = Set<String>()
var knownFiles = Set<String>()

func processFile(_ fullPath: String) {
    let fileName = (fullPath as NSString).lastPathComponent
    guard fileName.hasSuffix(".md"), !fileName.hasPrefix(".") else { return }
    lock.lock()
    guard !inProgress.contains(fileName) else {
        lock.unlock()
        print("md2notes_watcher: skip duplicate → \(fileName)")
        fflush(stdout)
        return
    }
    guard fm.fileExists(atPath: fullPath) else { lock.unlock(); return }
    inProgress.insert(fileName)
    knownFiles.insert(fileName)
    lock.unlock()
    print("md2notes_watcher: processing → \(fileName)")
    fflush(stdout)
    let task = Process()
    task.executableURL = URL(fileURLWithPath: "/bin/bash")
    task.arguments = [convertScript, fullPath]
    try? task.run()
    task.waitUntilExit()
    print("md2notes_watcher: done (exit \(task.terminationStatus))")
    fflush(stdout)
    lock.lock(); inProgress.remove(fileName); lock.unlock()
}

let queue = DispatchQueue(label: "com.pipeline.md2notes.fsevents")

if let existing = try? fm.contentsOfDirectory(atPath: watchPath) {
    let mdFiles = existing.filter { $0.hasSuffix(".md") }
    lock.lock(); knownFiles = Set(mdFiles); lock.unlock()
    for f in mdFiles { processFile((watchPath as NSString).appendingPathComponent(f)) }
}

let callback: FSEventStreamCallback = { _, _, _, _, _, _ in
    let current = Set((try? fm.contentsOfDirectory(atPath: watchPath))?.filter { $0.hasSuffix(".md") } ?? [])
    lock.lock(); let newFiles = current.subtracting(knownFiles); lock.unlock()
    for f in newFiles { processFile((watchPath as NSString).appendingPathComponent(f)) }
}

var ctx = FSEventStreamContext(version: 0, info: nil, retain: nil, release: nil, copyDescription: nil)
let stream = FSEventStreamCreate(
    nil, callback, &ctx, [watchPath] as CFArray,
    FSEventStreamEventId(kFSEventStreamEventIdSinceNow), 0.3,
    FSEventStreamCreateFlags(kFSEventStreamCreateFlagFileEvents | kFSEventStreamCreateFlagUseCFTypes | kFSEventStreamCreateFlagNoDefer))!

FSEventStreamSetDispatchQueue(stream, queue)
FSEventStreamStart(stream)

let pollTimer = DispatchSource.makeTimerSource(queue: queue)
pollTimer.schedule(deadline: .now() + 5, repeating: 5.0)
pollTimer.setEventHandler {
    guard let current = try? fm.contentsOfDirectory(atPath: watchPath) else { return }
    let mdFiles = Set(current.filter { $0.hasSuffix(".md") })
    lock.lock(); let missed = mdFiles.subtracting(knownFiles).subtracting(inProgress); lock.unlock()
    if !missed.isEmpty {
        print("md2notes_watcher: polling caught \(missed.count) missed file(s)")
        fflush(stdout)
        for f in missed { processFile((watchPath as NSString).appendingPathComponent(f)) }
    }
}
pollTimer.resume()

print("md2notes_watcher: started — FSEvents + polling on \(watchPath)")
fflush(stdout)
dispatchMain()
