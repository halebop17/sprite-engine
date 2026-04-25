import os.lock

final class RingBuffer<T: ExpressibleByIntegerLiteral> {

    private var storage:   [T]
    private var readIndex  = 0
    private var writeIndex = 0
    private var filled     = 0
    private var lock       = os_unfair_lock_s()
    let capacity: Int

    init(capacity: Int) {
        self.capacity = capacity
        storage = [T](repeating: 0, count: capacity)
    }

    var availableToRead: Int {
        os_unfair_lock_lock(&lock)
        defer { os_unfair_lock_unlock(&lock) }
        return filled
    }

    // Writes up to `count` elements from `ptr`; silently drops overflow.
    func write(_ ptr: UnsafePointer<T>, count: Int) {
        os_unfair_lock_lock(&lock)
        let n = min(count, capacity - filled)
        if n > 0 {
            let stride = MemoryLayout<T>.stride
            storage.withUnsafeMutableBufferPointer { buf in
                let dst = UnsafeMutableRawPointer(buf.baseAddress!)
                let src = UnsafeRawPointer(ptr)
                let first = min(n, capacity - writeIndex)
                dst.advanced(by: writeIndex * stride).copyMemory(from: src, byteCount: first * stride)
                if first < n {
                    dst.copyMemory(from: src.advanced(by: first * stride), byteCount: (n - first) * stride)
                }
            }
            writeIndex = (writeIndex + n) % capacity
            filled += n
        }
        os_unfair_lock_unlock(&lock)
    }

    // Reads exactly `count` elements into `ptr`; pads with 0 on underrun.
    func read(_ ptr: UnsafeMutablePointer<T>, count: Int) {
        os_unfair_lock_lock(&lock)
        let n = min(count, filled)
        if n > 0 {
            let stride = MemoryLayout<T>.stride
            storage.withUnsafeMutableBufferPointer { buf in
                let src = UnsafeRawPointer(buf.baseAddress!)
                let dst = UnsafeMutableRawPointer(ptr)
                let first = min(n, capacity - readIndex)
                dst.copyMemory(from: src.advanced(by: readIndex * stride), byteCount: first * stride)
                if first < n {
                    dst.advanced(by: first * stride).copyMemory(from: src, byteCount: (n - first) * stride)
                }
            }
            readIndex = (readIndex + n) % capacity
            filled -= n
        }
        os_unfair_lock_unlock(&lock)
        if n < count {
            ptr.advanced(by: n).initialize(repeating: 0, count: count - n)
        }
    }
}
