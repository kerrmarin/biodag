import XCTest
import Biodag

//swiftlint:disable identifier_name force_cast

@MainActor
final class DependencyTests: XCTestCase {

    private static let dependencies = DependencyResolver {
        Module { WidgetModule() as WidgetModuleType }
        Module { SampleModule() as SampleModuleType }
        Module("abc") { SampleModule(value: "123") as SampleModuleType }
        Module("singleton", scope: .singleton) { SampleModule(value: "singleton") as SampleModuleType }
    }

    @Inject private var widgetModule: WidgetModuleType
    @Inject private var sampleModule: SampleModuleType
    @Inject("abc") private var sampleModule2: SampleModuleType
    @Inject("singleton") private var singletonModule: SampleModuleType

    private lazy var widgetWorker: WidgetWorkerType = widgetModule.component()
    private lazy var someObject: SomeObjectType = sampleModule.component()
    private lazy var anotherObject: AnotherObjectType = sampleModule.component()
    private lazy var viewModelObject: ViewModelObjectType = sampleModule.component()
    private lazy var viewControllerObject: ViewControllerObjectType = sampleModule.component()

    override class func setUp() {
        super.setUp()
        Task.immediate { @MainActor in
            Self.dependencies.build()
        }

    }
}

@MainActor
final class DependencyScopeHelper {
    @Inject("abc") var sampleModule2: SampleModuleType
    @Inject("singleton") var singletonModule: SampleModuleType
}

// MARK: - Test Cases

extension DependencyTests {

    func testResolver() {
        // Given
        let widgetModuleResult = widgetModule.test()
        let sampleModuleResult = sampleModule.test()
        let sampleModule2Result = sampleModule2.test()
        let widgetResult = widgetWorker.fetch(id: 3)
        let someResult = someObject.testAbc()
        let anotherResult = anotherObject.testXyz()
        let viewModelResult = viewModelObject.testLmn()
        let viewModelNestedResult = viewModelObject.testLmnNested()
        let viewControllerResult = viewControllerObject.testRst()
        let viewControllerNestedResult = viewControllerObject.testRstNested()

        // Then
        XCTAssertEqual(widgetModuleResult, "WidgetModule.test()")
        XCTAssertEqual(sampleModuleResult, "SampleModule.test()")
        XCTAssertEqual(sampleModule2Result, "SampleModule.test()123")
        XCTAssertEqual(widgetResult, "|MediaRealmStore.3||MediaNetworkRemote.3|")
        XCTAssertEqual(someResult, "SomeObject.testAbc")
        XCTAssertEqual(anotherResult, "AnotherObject.testXyz|SomeObject.testAbc")
        XCTAssertEqual(viewModelResult, "SomeViewModel.testLmn|SomeObject.testAbc")
        XCTAssertEqual(viewModelNestedResult, "SomeViewModel.testLmnNested|AnotherObject.testXyz|SomeObject.testAbc")
        XCTAssertEqual(viewControllerResult, "SomeViewController.testRst|SomeObject.testAbc")
        XCTAssertEqual(viewControllerNestedResult,
                       "SomeViewController.testRstNested|AnotherObject.testXyz|SomeObject.testAbc")
    }

    func testSameInstanceAskedTwice() {
        let widgetModuleResult1 = self.widgetModule as! WidgetModule
        let widgetModuleResult2 = self.widgetModule as! WidgetModule
        XCTAssertTrue(widgetModuleResult1 === widgetModuleResult2)
    }

    func testSingletonScope() {
        let helper = DependencyScopeHelper()
        let helperPrototype = helper.sampleModule2 as! SampleModule
        let helperSingleton = helper.singletonModule as! SampleModule
        let sampleModule = self.sampleModule2 as! SampleModule
        let singletonModule = self.singletonModule as! SampleModule
        // The prototypes are different instances
        XCTAssertFalse(sampleModule === helperPrototype)
        // The singletons are the same instance
        XCTAssertTrue(singletonModule === helperSingleton)
    }

    func testAddingDependencies() {
        struct Added { }
        struct NotAdded { }

        let newResolver = DependencyResolver({
            Module { Added() as Added }
        })
        newResolver.build()


        @Inject var widgetModule: WidgetModuleType
        @Inject var added: Added
        @Inject var notAdded: NotAdded

        XCTAssertNotNil(widgetModule)
        XCTAssertNotNil(added)
    }

    func testRegisteringDependenciesTwice() {
        class Added { }

        let first = Added()
        let second = Added()

        let newResolver = DependencyResolver({
            Module(scope: .singleton) { first as Added }
        })
        newResolver.build()

        @Inject var added: Added
        XCTAssertTrue(added === first)

        let newResolver2 = DependencyResolver({
            Module(scope: .singleton) { second as Added }
        })
        newResolver2.build()

        @Inject var added2: Added

        XCTAssertTrue(added2 === second)
    }
}

// MARK: - Subtypes

extension DependencyTests {

    final class WidgetModule: WidgetModuleType {

        func component() -> WidgetWorkerType {
            WidgetWorker(
                store: component(),
                remote: component()
            )
        }

        func component() -> WidgetRemote {
            WidgetNetworkRemote(httpService: component())
        }

        func component() -> WidgetStore {
            WidgetRealmStore()
        }

        func component() -> HTTPServiceType {
            HTTPService()
        }

        func test() -> String {
            "WidgetModule.test()"
        }
    }

    @MainActor
    final class SampleModule: SampleModuleType {
        let value: String?

        init(value: String? = nil) {
            self.value = value
        }

        func component() -> SomeObjectType {
            SomeObject()
        }

        func component() -> AnotherObjectType {
            AnotherObject(someObject: component())
        }

        func component() -> ViewModelObjectType {
            SomeViewModel(
                someObject: component(),
                anotherObject: component()
            )
        }

        func component() -> ViewControllerObjectType {
            SomeViewController()
        }

        func test() -> String {
            "SampleModule.test()\(value ?? "")"
        }
    }

    struct SomeObject: SomeObjectType {
        func testAbc() -> String {
            "SomeObject.testAbc"
        }
    }

    struct AnotherObject: AnotherObjectType {
        private let someObject: SomeObjectType

        init(someObject: SomeObjectType) {
            self.someObject = someObject
        }

        func testXyz() -> String {
            "AnotherObject.testXyz|" + someObject.testAbc()
        }
    }

    struct SomeViewModel: ViewModelObjectType {
        private let someObject: SomeObjectType
        private let anotherObject: AnotherObjectType

        init(someObject: SomeObjectType, anotherObject: AnotherObjectType) {
            self.someObject = someObject
            self.anotherObject = anotherObject
        }

        func testLmn() -> String {
            "SomeViewModel.testLmn|" + someObject.testAbc()
        }

        func testLmnNested() -> String {
            "SomeViewModel.testLmnNested|" + anotherObject.testXyz()
        }
    }

    @MainActor
    class SomeViewController: ViewControllerObjectType {
        @Inject private var module: SampleModuleType

        private lazy var someObject: SomeObjectType = module.component()
        private lazy var anotherObject: AnotherObjectType = module.component()

        func testRst() -> String {
            "SomeViewController.testRst|" + someObject.testAbc()
        }

        func testRstNested() -> String {
            "SomeViewController.testRstNested|" + anotherObject.testXyz()
        }
    }

    struct WidgetWorker: WidgetWorkerType {
        private let store: WidgetStore
        private let remote: WidgetRemote

        init(store: WidgetStore, remote: WidgetRemote) {
            self.store = store
            self.remote = remote
        }

        func fetch(id: Int) -> String {
            store.fetch(id: id)
                + remote.fetch(id: id)
        }
    }

    struct WidgetNetworkRemote: WidgetRemote {
        private let httpService: HTTPServiceType

        init(httpService: HTTPServiceType) {
            self.httpService = httpService
        }

        func fetch(id: Int) -> String {
            "|MediaNetworkRemote.\(id)|"
        }
    }

    struct WidgetRealmStore: WidgetStore {

        func fetch(id: Int) -> String {
            "|MediaRealmStore.\(id)|"
        }

        func createOrUpdate(_ request: String) -> String {
            "MediaRealmStore.createOrUpdate\(request)"
        }
    }

    struct HTTPService: HTTPServiceType {

        func get(url: String) -> String {
            "HTTPService.get"
        }

        func post(url: String) -> String {
            "HTTPService.post"
        }
    }
}

// MARK: API

protocol WidgetModuleType {
    func component() -> WidgetWorkerType
    func component() -> WidgetRemote
    func component() -> WidgetStore
    func component() -> HTTPServiceType
    func test() -> String
}

@MainActor
protocol SampleModuleType {
    func component() -> SomeObjectType
    func component() -> AnotherObjectType
    func component() -> ViewModelObjectType
    func component() -> ViewControllerObjectType
    func test() -> String
}

protocol SomeObjectType {
    func testAbc() -> String
}

protocol AnotherObjectType {
    func testXyz() -> String
}

protocol ViewModelObjectType {
    func testLmn() -> String
    func testLmnNested() -> String
}

@MainActor
protocol ViewControllerObjectType {
    func testRst() -> String
    func testRstNested() -> String
}

protocol WidgetStore {
    func fetch(id: Int) -> String
    func createOrUpdate(_ request: String) -> String
}

protocol WidgetRemote {
    func fetch(id: Int) -> String
}

protocol WidgetWorkerType {
    func fetch(id: Int) -> String
}

protocol HTTPServiceType {
    func get(url: String) -> String
    func post(url: String) -> String
}
