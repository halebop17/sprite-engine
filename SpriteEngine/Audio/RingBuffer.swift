import os.lock

// Lock-free single-producer / single-consumer ring buffer using os_unfair_lock.
// T must be zero-initializable via ExpressibleByIntegerLiteral (Float, Int16, etc.).
final class RingBuffer<T: ExpressibleByIntegerLiteral> {

    private var storage:    [T]
    private var readIndex   = 0
    private var writeIndex  = 0
    private var filled      = 0
    private var lock        = os_unfair_lock_s()
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
        for i in 0..<n {
            storage[writeIndex] = ptr[i]
            writeIndex = (writeIndex + 1) % capacity
        }
        filled += n
        os_unfair_lock_unlock(&lock)
    }

    // Reads exactly `count` elements into `ptr`; pads with 0 on underrun.
    func read(_ ptr: UnsafeMutablePointer<T>, count: Int) {
        os_unfair_lock_lock(&lock)
        let n = min(count, filled)
        for i in 0..<n {
            ptr[i] = storage[readIndex]
            readIndex = (readIndex + 1) % capacity
        }
        filled -= n
        os_unfair_lock_unlock(&lock)
        if n < count {
            ptr.advanced(by: n).initialize(repeating: 0, count: count - n)
        }
    }
}
