import Foundation
import CoreServices

public final class FileSystemWatcher: @unchecked Sendable {
    private var streamRef: FSEventStreamRef?
    private let pathsToWatch: [String]
    private let latency: TimeInterval
    private let onChange: @Sendable () -> Void
    private let queue = DispatchQueue(label: "com.tahoelaunchpad.fswatcher", qos: .utility)

    public init(
        paths: [String] = ApplicationScanner.defaultSearchDirectories.map(\.path),
        latency: TimeInterval = 1.0,
        onChange: @escaping @Sendable () -> Void
    ) {
        self.pathsToWatch = paths
        self.latency = latency
        self.onChange = onChange
    }

    deinit {
        stop()
    }

    public func start() {
        stop()

        var context = FSEventStreamContext(
            version: 0,
            info: Unmanaged.passUnretained(self).toOpaque(),
            retain: nil,
            release: nil,
            copyDescription: nil
        )

        let callback: FSEventStreamCallback = { (
            streamRef,
            clientCallBackInfo,
            numEvents,
            eventPaths,
            eventFlags,
            eventIds
        ) in
            guard let clientInfo = clientCallBackInfo else { return }
            let watcher = Unmanaged<FileSystemWatcher>.fromOpaque(clientInfo).takeUnretainedValue()
            watcher.onChange()
        }

        let flags = UInt32(kFSEventStreamCreateFlagUseCFTypes | kFSEventStreamCreateFlagFileEvents)

        guard let stream = FSEventStreamCreate(
            kCFAllocatorDefault,
            callback,
            &context,
            pathsToWatch as CFArray,
            FSEventStreamEventId(kFSEventStreamEventIdSinceNow),
            latency,
            flags
        ) else {
            print("[FileSystemWatcher] Failed to create FSEventStream")
            return
        }

        self.streamRef = stream
        FSEventStreamSetDispatchQueue(stream, queue)
        FSEventStreamStart(stream)
    }

    public func stop() {
        guard let stream = streamRef else { return }
        FSEventStreamStop(stream)
        FSEventStreamInvalidate(stream)
        FSEventStreamRelease(stream)
        self.streamRef = nil
    }
}
