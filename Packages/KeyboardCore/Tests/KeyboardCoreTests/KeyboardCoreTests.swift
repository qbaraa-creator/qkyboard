import Testing
@testable import KeyboardCore

@Suite struct LayoutTests {
    @Test func numberRowIsPresentInBothLanguagesAndPages() {
        for language in KeyboardLanguage.allCases {
            for page in [KeyboardPage.letters, .symbols] {
                let rows = KeyboardLayout.rows(for: LayoutContext(language: language, page: page))
                let digits = rows[0].keys.map(\.id)
                #expect(digits == ["1", "2", "3", "4", "5", "6", "7", "8", "9", "0"])
            }
        }
    }

    @Test func arabicLayoutCoversEveryLetter() {
        let rows = KeyboardLayout.rows(for: LayoutContext(language: .arabic))
        var produced = Set<String>()
        for row in rows {
            for key in row.keys {
                if case .character(let c) = key.action { produced.insert(c) }
                produced.formUnion(key.alternates)
            }
        }
        let required = "ابتثجحخدذرزسشصضطظعغفقكلمنهويءئؤىةأإآ".map(String.init)
        let missing = required.filter { !produced.contains($0) }
        #expect(missing.isEmpty, "missing: \(missing)")
    }

    @Test func rowsFillWidthOrCenter() {
        let rows = KeyboardLayout.rows(for: LayoutContext(language: .english))
        for row in rows {
            let frames = row.frames(totalWidth: 375)
            let right = frames.last!.x + frames.last!.width
            #expect(right <= 375.0001)
            #expect(frames.first!.x >= 0)
        }
        // Bottom row has a flexible space bar, so it spans the full width.
        let bottom = rows.last!.frames(totalWidth: 375)
        #expect(abs(bottom.last!.x + bottom.last!.width - 375) < 0.001)
    }

    @Test func globeOnlyWhenRequired() {
        let with = KeyboardLayout.rows(for: LayoutContext(language: .english, needsGlobe: true))
        let without = KeyboardLayout.rows(for: LayoutContext(language: .english, needsGlobe: false))
        #expect(with.last!.keys.contains { $0.action == .globe })
        #expect(!without.last!.keys.contains { $0.action == .globe })
    }

    @Test func emailAndURLFieldsExposeTheirKeys() {
        let email = KeyboardLayout.rows(for: LayoutContext(language: .arabic, field: .email)).last!
        #expect(email.keys.contains { $0.action == .character("@") })
        let url = KeyboardLayout.rows(for: LayoutContext(language: .english, field: .url)).last!
        #expect(url.keys.contains { $0.action == .character("/") })
        #expect(url.keys.contains { $0.action == .text(".com") })
    }

    @Test func numberFieldUsesPad() {
        let rows = KeyboardLayout.rows(for: LayoutContext(language: .arabic, field: .number))
        #expect(rows.count == 4)
        #expect(rows.allSatisfy { $0.gridUnits == 3 })
    }

    @Test func returnLabelFollowsLanguage() {
        let ar = KeyboardLayout.rows(for: LayoutContext(language: .arabic, returnKind: .search)).last!.keys.last!
        #expect(ar.label == .text("بحث"))
        #expect(ar.style == .primary)
        let en = KeyboardLayout.rows(for: LayoutContext(language: .english)).last!.keys.last!
        #expect(en.label == .symbol("return"))
    }

    @Test func bottomRowFollowsSpecOrder() {
        let ar = KeyboardLayout.rows(for: LayoutContext(language: .arabic)).last!.keys
        #expect(Array(ar.map(\.id).prefix(4)) == ["globe", "page", "lang", "space"])
        #expect(ar[2].label == .text("EN"))
        let en = KeyboardLayout.rows(for: LayoutContext(language: .english)).last!.keys
        #expect(en[2].label == .text("AR"))
    }

    @Test func arabicSymbolsExposeArabicPunctuation() {
        let rows = KeyboardLayout.rows(for: LayoutContext(language: .arabic, page: .symbols))
        let ids = Set(rows.flatMap { $0.keys.map(\.id) })
        #expect(ids.isSuperset(of: ["؟", "،", "؛", "…"]))
        let en = Set(KeyboardLayout.rows(for: LayoutContext(language: .english, page: .symbols)).flatMap { $0.keys.map(\.id) })
        #expect(en.isSuperset(of: ["?", ",", ";"]))
    }

    @Test func shiftedLabelsAreUppercase() {
        let rows = KeyboardLayout.rows(for: LayoutContext(language: .english, shift: .on))
        #expect(rows[1].keys.first!.label == .text("Q"))
    }
}

@Suite struct EngineTests {
    let ctx = TextContext(before: "", autocap: .sentences)

    @Test func languageToggleIsSingleTap() {
        let engine = KeyboardEngine(language: .arabic)
        _ = engine.handle(.languageToggle, context: ctx, time: 0)
        #expect(engine.language == .english)
        _ = engine.handle(.languageToggle, context: ctx, time: 1)
        #expect(engine.language == .arabic)
    }

    @Test func toggleResetsSymbolsPage() {
        let engine = KeyboardEngine(language: .arabic)
        _ = engine.handle(.page(.symbols), context: ctx, time: 0)
        _ = engine.handle(.languageToggle, context: ctx, time: 1)
        #expect(engine.page == .letters)
    }

    @Test func englishAutoCapitalizesAtSentenceStart() {
        let engine = KeyboardEngine(language: .english)
        engine.updateAutoShift(context: TextContext(before: "", autocap: .sentences))
        #expect(engine.shift == .on)
        #expect(engine.handle(.character("h"), context: ctx, time: 0) == [.insert("H")])
        #expect(engine.shift == .off)
        engine.updateAutoShift(context: TextContext(before: "Hi", autocap: .sentences))
        #expect(engine.shift == .off)
        engine.updateAutoShift(context: TextContext(before: "Hi. ", autocap: .sentences))
        #expect(engine.shift == .on)
    }

    @Test func arabicNeverShifts() {
        let engine = KeyboardEngine(language: .arabic)
        engine.updateAutoShift(context: TextContext(before: "", autocap: .sentences))
        #expect(engine.shift == .off)
        _ = engine.handle(.shift, context: ctx, time: 0)
        #expect(engine.shift == .off)
    }

    @Test func shiftDoubleTapLocks() {
        let engine = KeyboardEngine(language: .english)
        _ = engine.handle(.shift, context: ctx, time: 0)
        _ = engine.handle(.shift, context: ctx, time: 0.2)
        #expect(engine.shift == .locked)
        #expect(engine.handle(.character("a"), context: ctx, time: 1) == [.insert("A")])
        #expect(engine.handle(.character("b"), context: ctx, time: 1.1) == [.insert("B")])
        engine.updateAutoShift(context: TextContext(before: "AB", autocap: .sentences))
        #expect(engine.shift == .locked)
        _ = engine.handle(.shift, context: ctx, time: 2)
        #expect(engine.shift == .off)
    }

    @Test func slowSecondShiftTapTurnsOff() {
        let engine = KeyboardEngine(language: .english)
        _ = engine.handle(.shift, context: ctx, time: 0)
        _ = engine.handle(.shift, context: ctx, time: 1)
        #expect(engine.shift == .off)
    }

    @Test func doubleSpaceInsertsPeriod() {
        let engine = KeyboardEngine(language: .english)
        #expect(engine.handle(.space, context: TextContext(before: "hello"), time: 0) == [.insert(" ")])
        #expect(engine.handle(.space, context: TextContext(before: "hello "), time: 0.2)
                == [.deleteBackward(1), .insert(". ")])
    }

    @Test func arabicDoubleSpaceIsSeparateAndOffByDefault() {
        let engine = KeyboardEngine(language: .arabic)
        _ = engine.handle(.space, context: TextContext(before: "مرحبا"), time: 0)
        #expect(engine.handle(.space, context: TextContext(before: "مرحبا "), time: 0.2) == [.insert(" ")])

        var settings = EngineSettings()
        settings.doubleSpacePeriodArabic = true
        let enabled = KeyboardEngine(language: .arabic, settings: settings)
        _ = enabled.handle(.space, context: TextContext(before: "مرحبا"), time: 0)
        #expect(enabled.handle(.space, context: TextContext(before: "مرحبا "), time: 0.2)
                == [.deleteBackward(1), .insert(". ")])
    }

    @Test func candidateReplacesTokenAndKeepsLayout() {
        let engine = KeyboardEngine(language: .arabic)
        let ops = engine.acceptCandidate("forecast", context: TextContext(before: "راجع الـ fore"))
        #expect(ops == [.deleteBackward(4), .insert("forecast ")])
        #expect(engine.language == .arabic)
        #expect(engine.acceptCandidate("التركيب", context: TextContext(before: "متى سيتم "))
                == [.insert("التركيب ")])
    }

    @Test func slowDoubleSpaceIsTwoSpaces() {
        let engine = KeyboardEngine(language: .english)
        _ = engine.handle(.space, context: TextContext(before: "hello"), time: 0)
        #expect(engine.handle(.space, context: TextContext(before: "hello "), time: 2) == [.insert(" ")])
    }

    @Test func doubleSpaceCanBeDisabled() {
        var settings = EngineSettings()
        settings.doubleSpacePeriod = false
        let engine = KeyboardEngine(language: .english, settings: settings)
        _ = engine.handle(.space, context: TextContext(before: "hello"), time: 0)
        #expect(engine.handle(.space, context: TextContext(before: "hello "), time: 0.1) == [.insert(" ")])
    }

    @Test func spaceReturnsFromSymbols() {
        let engine = KeyboardEngine(language: .english)
        _ = engine.handle(.page(.symbols), context: ctx, time: 0)
        _ = engine.handle(.character("$"), context: ctx, time: 0.1)
        #expect(engine.page == .symbols)
        _ = engine.handle(.space, context: ctx, time: 0.2)
        #expect(engine.page == .letters)
    }

    @Test func symbolsAreNotUppercased() {
        let engine = KeyboardEngine(language: .english)
        _ = engine.handle(.shift, context: ctx, time: 0)
        #expect(engine.handle(.text(".com"), context: ctx, time: 1) == [.insert(".com")])
    }
}

@Suite struct TextEditingTests {
    @Test func wordDeletion() {
        #expect(TextEditing.wordDeletionLength(before: "hello world") == 5)
        #expect(TextEditing.wordDeletionLength(before: "hello world  ") == 7)
        #expect(TextEditing.wordDeletionLength(before: "راجع forecast") == 8)
        #expect(TextEditing.wordDeletionLength(before: "أرسل التقرير") == 7)
        #expect(TextEditing.wordDeletionLength(before: "hello,") == 1)
        #expect(TextEditing.wordDeletionLength(before: "") == 1)
        #expect(TextEditing.wordDeletionLength(before: nil) == 1)
    }

    @Test func currentToken() {
        #expect(TextEditing.currentToken(before: "راجع الـ fore") == "fore")
        #expect(TextEditing.currentToken(before: "الـfore") == "fore")
        #expect(TextEditing.currentToken(before: "The المح") == "المح")
        #expect(TextEditing.currentToken(before: "hello, ") == "")
        #expect(TextEditing.currentToken(before: "(inv") == "inv")
        #expect(TextEditing.currentToken(before: nil) == "")
    }

    @Test func periodOnlyAfterWords() {
        #expect(TextEditing.canInsertPeriodOnDoubleSpace(before: "hi "))
        #expect(TextEditing.canInsertPeriodOnDoubleSpace(before: "رقم 5 "))
        #expect(!TextEditing.canInsertPeriodOnDoubleSpace(before: "hi. "))
        #expect(!TextEditing.canInsertPeriodOnDoubleSpace(before: "hi  "))
        #expect(!TextEditing.canInsertPeriodOnDoubleSpace(before: " "))
    }

    @Test func autocapModes() {
        #expect(TextEditing.shouldAutoCapitalize(before: nil, mode: .sentences))
        #expect(TextEditing.shouldAutoCapitalize(before: "Done!\n", mode: .sentences))
        #expect(TextEditing.shouldAutoCapitalize(before: "تم؟ ", mode: .sentences))
        #expect(!TextEditing.shouldAutoCapitalize(before: "e.g", mode: .sentences))
        #expect(TextEditing.shouldAutoCapitalize(before: "john ", mode: .words))
        #expect(!TextEditing.shouldAutoCapitalize(before: "", mode: .none))
    }

    @Test func deleteRepeatAcceleratesGradually() {
        let schedule = DeleteRepeatSchedule()
        var previous = Double.infinity
        for tick in 0..<schedule.wordModeAfterTicks {
            let step = schedule.step(tick: tick)
            #expect(step.unit == .character)
            #expect(step.interval <= previous)
            previous = step.interval
        }
        #expect(schedule.step(tick: schedule.wordModeAfterTicks).unit == .word)
    }
}

@Suite struct LatencyTests {
    @Test func percentiles() {
        var tracker = LatencyTracker(capacity: 100)
        for i in 1...100 { tracker.record(milliseconds: Double(i)) }
        #expect(tracker.percentile(50) == 50)
        #expect(tracker.percentile(95) == 95)
        tracker.record(milliseconds: 1000)
        #expect(tracker.samples.count == 100)
        #expect(tracker.totalCount == 101)
    }
}

@Suite struct MockPredictorTests {
    let predictor = MockPredictor()

    @Test func partialArabicWord() {
        let c = predictor.candidates(before: "المح")
        #expect(c.first == "المح")
        #expect(Set(c.dropFirst()) == ["المحصول", "المحمصة"])
    }

    @Test func englishInsideArabicContext() {
        let c = predictor.candidates(before: "راجع الـ fore")
        #expect(c.first == "fore")
        #expect(c.contains("forecast"))
    }

    @Test func nextWordWhenTokenEmpty() {
        #expect(predictor.candidates(before: "متى سيتم ") == ["التركيب", "التنفيذ", "الاستلام"])
        #expect(predictor.candidates(before: "") == [])
    }

    @Test func matchingIgnoresHamzaVariants() {
        #expect(predictor.candidates(before: "ارس").contains("إرسال"))
    }

    @Test func keepsCapitalization() {
        #expect(predictor.candidates(before: "Fore").contains("Forecast"))
    }
}
