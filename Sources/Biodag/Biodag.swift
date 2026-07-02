//
//  Biodag
//  A Swift micro-library that provides lightweight dependency injection.
//
//  Inspired by:
//  https://dagger.dev
//  https://github.com/hmlongco/Resolver
//  https://github.com/InsertKoinIO/koin
//
//  Created by Basem Emara on 2019-09-06.
//  Copyright © 2019 Zamzam Inc. All rights reserved.
//

import Foundation

/// A dependency collection that provides resolutions for object instances.
final public class DependencyResolver {
    private let moduleArray: [Module]
    /// Stored object instance factories.
    private var modules = [String: Module]()
    private var instances = [String: Any]()

    /// Construct dependency resolutions.
    public init(@ModuleBuilder _ modules: () -> [Module]) {
        self.moduleArray = modules()
    }

    /// Construct dependency resolution.
    public init(@ModuleBuilder _ module: () -> Module) {
        self.moduleArray = [module()]
    }

    /// Assigns the current container to the composition root.
    public func build() {
        for module in moduleArray {
            Self.root.add(module: module)
        }
    }

    fileprivate init() {
        self.moduleArray = []
    }
}

private extension DependencyResolver {
    /// Composition root container of dependencies.
    static let root = DependencyResolver()

    /// Registers a specific type and its instantiating factory.
    func add(module: Module) {
        self.modules[module.name] = module
        // When we register a new module, if there is an instance with the same name we remove it
        self.instances[module.name] = nil
    }

    /// Resolves through inference and returns an instance of the given type from the current default container.
    ///
    /// If the dependency is not found, an exception will occur.
    func resolve<T>(for name: String? = nil) -> T {
        let name = name ?? String(describing: T.self)
        // First, make sure the module is available
        guard let module = modules[name] else {
            fatalError("Module '\(T.self)' not found!")
        }

        // Second, resolve the module as a dependency. If the module was registered as a
        // prototype, return the resolved instance.
        // If the module was registered as a singleton, return the cached instance if it exists,
        // or the resolved one after storing it in the dependency resolver.
        let component: T = {
            // Create a closure to lazily evaluate the resolution of the module
            let resolvedModuleClosure: () -> T = {
                guard let mod = module.resolve() as? T else {
                    fatalError("Dependency '\(T.self)' not resolved!")
                }
                return mod
            }

            switch module.scope {
            case .prototype:
                return resolvedModuleClosure()
            case .singleton:
                if let instance = instances[name] as? T {
                    return instance
                }
                let resolvedModule = resolvedModuleClosure()
                instances[name] = resolvedModule
                return resolvedModule
            }
        }()

        return component
    }

    /// Resolves through inference and returns an instance of the given type from the current default container.
    ///
    /// If the dependency is not found, an exception will occur.
    func resolveWithFallback<Preferred, Fallback>(for name: String? = nil) -> FallbackDependency<Preferred, Fallback> {
        let preferredName = name ?? String(describing: Preferred.self)
        let fallbackName = name ?? String(describing: Fallback.self)

        // Preferred is optional, so it may not be there, but we should still check
        let preferredModule = modules[preferredName]
        let fallbackModule = preferredModule == nil ? modules[fallbackName] : nil

        // First, make sure the module is available
        if preferredModule == nil && fallbackModule == nil {
            fatalError("Module for preferred '\(Preferred.self)' or fallback '\(Fallback.self)' not found!")
        }

        // Second, resolve the module as a dependency. If the module was registered as a
        // prototype, return the resolved instance.
        // If the module was registered as a singleton, return the cached instance if it exists,
        // or the resolved one after storing it in the dependency resolver.
        let component: FallbackDependency<Preferred, Fallback> = {
            // Create a closure to lazily evaluate the resolution of the module
            let resolvedModuleClosure: () -> Preferred? = {
                return preferredModule?.resolve() as? Preferred
            }

            let fallbackModuleClosure: () -> Fallback = {
                guard let mod = fallbackModule?.resolve() as? Fallback else {
                    fatalError("Dependency '\(Fallback.self)' not resolved!")
                }
                return mod
            }

            return self.buildFallbackDependency(preferredModule: preferredModule, resolvedModuleClosure: resolvedModuleClosure, preferredName: preferredName,
                                                fallbackModule: fallbackModule, fallbackModuleClosure: fallbackModuleClosure, fallbackName: fallbackName)

        }()

        return component
    }

    private func buildFallbackDependency<Preferred, Fallback>(preferredModule: Module?,
                                                              resolvedModuleClosure: () -> Preferred?,
                                                              preferredName: String,
                                                              fallbackModule: Module?,
                                                              fallbackModuleClosure: () -> Fallback,
                                                              fallbackName: String) -> FallbackDependency<Preferred, Fallback> {

        if let preferredModule {
            switch preferredModule.scope {
            case .prototype:
                return .preferred(resolvedModuleClosure()!)
            case .singleton:
                if let instance = instances[preferredName] as? Preferred {
                    return .preferred(instance)
                }
                let resolvedModule = resolvedModuleClosure()
                instances[preferredName] = resolvedModule
                return .preferred(resolvedModule!)
            }
        }

        if let fallbackModule {
            switch fallbackModule.scope {
            case .prototype:
                return .fallback(fallbackModuleClosure())
            case .singleton:
                if let instance = instances[preferredName] as? Fallback {
                    return .fallback(instance)
                }
                let resolvedModule = fallbackModuleClosure()
                instances[preferredName] = resolvedModule
                return .fallback(resolvedModule)
            }
        }

        fatalError("Preferred and fallback module not found")
    }
}

// MARK: Public API

public extension DependencyResolver {

    /// DSL for declaring modules within the container dependency initializer.
    @resultBuilder struct ModuleBuilder {
        public static func buildBlock(_ modules: Module...) -> [Module] { modules }
        public static func buildBlock(_ module: Module) -> Module { module }
    }
}

/// A type that contributes to the object graph.
public struct Module {
    fileprivate let name: String
    fileprivate let resolve: () -> Any
    fileprivate let scope: InjectionScope

    public init<T>(_ name: String? = nil, scope: InjectionScope = .prototype, _ resolve: @escaping () -> T) {
        self.name = name ?? String(describing: T.self)
        self.resolve = resolve
        self.scope = scope
    }
}

/// Resolves an instance from the dependency injection container.
@propertyWrapper
public struct Inject<Value> {
    private let name: String?
    private let resolutionClosure = memoize { name -> Value in
        return DependencyResolver.root.resolve(for: name)
    }

    public var wrappedValue: Value {
        return self.resolutionClosure(self.name)
    }

    public init() {
        self.name = nil
    }

    public init(_ name: String) {
        self.name = name
    }
}

/// Resolves an instance from the dependency injection container.
@propertyWrapper
public struct InjectWithFallback<Preferred, Fallback> {
    private let name: String?
    private let resolutionClosure = memoize { name -> FallbackDependency<Preferred, Fallback> in
        return DependencyResolver.root.resolveWithFallback(for: name)
    }

    public var wrappedValue: FallbackDependency<Preferred, Fallback> {
        return self.resolutionClosure(self.name)
    }

    public init() {
        self.name = nil
    }

    public init(_ name: String) {
        self.name = name
    }
}

public enum FallbackDependency<Preferred, Fallback> {
    case preferred(Preferred)
    case fallback(Fallback)
}

public enum InjectionScope {
    case singleton
    case prototype
}
