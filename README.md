# Biodag

Biodag: [pit̪akˈ] - [dirk](https://en.wikipedia.org/wiki/Dirk) in Scottish Gaelic, a long thrusting dagger.

A Swift micro-library that provides lightweight dependency injection, originally forked from [Shank](https://github.com/ZamzamInc/Shank)

Inject dependencies via property wrappers:
```swift
final class ViewController: UIViewController {
    
    @Inject private var widgetModule: WidgetModuleType
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        widgetModule.test()
    }
}
```

Register modules early in your app:
```swift
class AppDelegate: UIResponder, UIApplicationDelegate {

    private let dependencies = DependencyResolver {
        // A prototype dependency (i.e. one per @Inject)
        Module { WidgetModule() as WidgetModuleType }
        // A dependency that's scoped to be a singleton
        Module(scope: .singleton) { SingletonModule() as SingletonModuleType }
    }
    
    override init() {
        super.init()
        dependencies.build()
    }
}
```

If you forget to `build` the dependency container, it will result in a run-time exception. 

# Installation

The easiest way to install this is via SPM. Add a dependency for Biodag like:

```
.package(url: "https://github.com/kerrmarin/biodag.git", from: "0.3.0")
```

# Contributing

To run the tests, run `swift test`.

To open in Xcode, open the package workspace file inside the `.swiftpm/xcode` folder.

If you find a bug or want to suggest an improvement, open an issue and, optionally (but encouraged!), make a PR :)
