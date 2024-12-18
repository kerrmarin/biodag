//Copyright © 2024 kerrmarin. All rights reserved.

import Foundation
import Biodag
import Testing

@MainActor struct FallbackTests {

    @Test
    private func testFallbackInjection() {
        struct Preferred { }
        struct Fallback { }

        let newResolver = DependencyResolver({
            Module { Fallback() }
        })
        newResolver.build()

        @InjectWithFallback var added: FallbackDependency<Preferred, Fallback>

        #expect(added != nil)
        switch added {
            case .preferred:
            Issue.record("Preferred should not be selected")
        case .fallback:
            break
        }
    }

    @Test
    private func testPreferredInjection() {
        struct Preferred1 { }
        struct Fallback1 { }

        let newResolver = DependencyResolver({
            Module { Preferred1() }
        })
        newResolver.build()

        @InjectWithFallback var added: FallbackDependency<Preferred1, Fallback1>

        #expect(added != nil)
        switch added {
        case .preferred:
            break
        case .fallback:
            Issue.record("Preferred should not be selected")
        }
    }

    @Test
    private func testPreferredAndFallbackInjection() {
        struct Preferred2 { }
        struct Fallback2 { }

        let newResolver = DependencyResolver({
            Module { Preferred2() }
        })
        newResolver.build()

        @InjectWithFallback var added: FallbackDependency<Preferred2, Fallback2>

        #expect(added != nil)
        switch added {
        case .preferred:
            break
        case .fallback:
            Issue.record("Preferred should not be selected")
        }
    }
}
