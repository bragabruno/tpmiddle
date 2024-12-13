import Foundation

/// Property wrapper for UserDefaults storage with type safety and default values
@propertyWrapper
public struct UserDefaultsStorage<T> {
    private let key: String
    private let defaultValue: T
    private let storage: UserDefaults
    
    public init(key: String, defaultValue: T, storage: UserDefaults = .standard) {
        self.key = key
        self.defaultValue = defaultValue
        self.storage = storage
    }
    
    public var wrappedValue: T {
        get {
            storage.object(forKey: key) as? T ?? defaultValue
        }
        set {
            if let optional = newValue as? AnyOptional, optional.isNil {
                storage.removeObject(forKey: key)
            } else {
                storage.set(newValue, forKey: key)
            }
            storage.synchronize()
        }
    }
    
    public var projectedValue: UserDefaultsStorage<T> {
        return self
    }
    
    /// Reset the value to its default
    public mutating func reset() {
        wrappedValue = defaultValue
    }
}

// MARK: - Optional Support

private protocol AnyOptional {
    var isNil: Bool { get }
}

extension Optional: AnyOptional {
    var isNil: Bool { self == nil }
}

// MARK: - Property Wrapper Extensions

extension UserDefaultsStorage where T: ExpressibleByNilLiteral {
    /// Initialize without a default value for optional types
    public init(key: String, storage: UserDefaults = .standard) {
        self.init(key: key, defaultValue: nil, storage: storage)
    }
}

// MARK: - RawRepresentable Support

extension UserDefaultsStorage where T: RawRepresentable {
    /// Get the raw value from UserDefaults and convert it to the RawRepresentable type
    public var wrappedValue: T {
        get {
            guard let rawValue = storage.object(forKey: key) as? T.RawValue,
                  let value = T(rawValue: rawValue) else {
                return defaultValue
            }
            return value
        }
        set {
            if let optional = newValue as? AnyOptional, optional.isNil {
                storage.removeObject(forKey: key)
            } else {
                storage.set(newValue.rawValue, forKey: key)
            }
            storage.synchronize()
        }
    }
}

// MARK: - Codable Support

extension UserDefaultsStorage where T: Codable {
    /// Get the encoded data from UserDefaults and decode it to the Codable type
    public var wrappedValue: T {
        get {
            guard let data = storage.data(forKey: key),
                  let value = try? JSONDecoder().decode(T.self, from: data) else {
                return defaultValue
            }
            return value
        }
        set {
            if let optional = newValue as? AnyOptional, optional.isNil {
                storage.removeObject(forKey: key)
            } else if let encoded = try? JSONEncoder().encode(newValue) {
                storage.set(encoded, forKey: key)
            }
            storage.synchronize()
        }
    }
}
