# TS-01 — Keyboard Foundation

المرجع: PRD v0.1 §47 (TS-01) و§50 (Phase 0)، وUX Spec v0.1 §50–52 (First Prototype Scope).
الهدف: إثبات أن Custom Keyboard عربية/إنجليزية مبنية بـNative Swift يمكن أن تكون سريعة ومستقرة بما يكفي لاستخدامها يوميًا بدل Apple Keyboard في الكتابة الأساسية.

الناتج المطلوب: قرار **Go / Modify architecture / Stop** لكل افتراض أدناه.

## ما تم بناؤه

| البند | الحالة | الموقع |
|---|---|---|
| Arabic layout: تخطيط PC المألوف على 12 عمودًا (UX §3). `أ إ آ` بالضغط المطوّل على `ا`، و`ذ` بالضغط المطوّل على `د` | ✅ | `KeyboardLayout.swift` |
| English QWERTY + Shift + Caps Lock (double tap) + Auto-capitalization | ✅ | `KeyboardLayout.swift`, `KeyboardEngine.swift` |
| Permanent number row (الضغط المطوّل ← ١٢٣) | ✅ | `numberRow` |
| AR ⇄ EN بضغطة واحدة (`EN` / `AR`) + حفظ آخر لغة، والصف السفلي `🌐 · #+= · AR/EN · space · ↵` | ✅ | `languageToggle`, `bottomRow` |
| Symbols page حسب UX §16، والعربية تستبدل `؛ ، ؟` | ✅ | `symbolPageRows` |
| System globe فقط عند `needsInputModeSwitchKey` + `handleInputModeList` | ✅ | `KeyboardView.rebuildGlobeButton` |
| Delete: tap + hold بتسارع تدريجي ثم كلمة كلمة بعد ~24 تكرارًا | ✅ | `DeleteRepeatSchedule` |
| Space + double space ← `. `: الإنجليزية مفعّلة افتراضيًا، والعربية إعداد منفصل معطّل افتراضيًا (UX §19) | ✅ | `KeyboardEngine` |
| keyboardType: Email (`@` `.`)، URL (`/` `.` `.com`)، Search، Number/Decimal pad | ✅ | `bottomRow`, `numberPadRows` |
| returnKeyType labels بالعربية والإنجليزية | ✅ | `ReturnKind` |
| Light / Dark / keyboardAppearance | ✅ | `KeyboardTheme` |
| Key preview + long-press alternates + rollover + sliding | ✅ | `KeyboardView` |
| Haptics (تحتاج Full Access) + key click | ✅ | `KeyboardViewController` |
| Mock Prediction Bar: `⌘ │ 3 candidates`. الكلمة المكتوبة تظهر بين علامتي تنصيص، والإنجليزية تُقترح داخل السياق العربي. الضغط على اقتراح يستبدل الكلمة الحالية ويضيف مسافة دون تغيير الـlayout | ✅ قائمة كلمات ثابتة | `MockPredictor` |
| ⌘ ← Productivity Mode (`‹ Keyboard` · Clipboard / Snippets) مع حفظ آخر تبويب | ✅ Clipboard فارغ، وSnippets بعينات ثابتة | `ProductivityView` |
| Prototype options (ضغط مطوّل على ⌘): Key preview (PT-03)، Haptics، مسافتان EN/AR، وقياس latency (P50/P95) | ✅ Debug فقط | `PrototypeOptionsView` |
| Personal prediction / learning / Clipboard storage | ⛔ خارج الـPrototype حسب UX §50 | Phase 2–3 |
| Space swipe cursor | ⛔ مؤجل حسب PRD §13 | — |

جميع قواعد الكتابة موجودة في `Packages/KeyboardCore` دون أي اعتماد على UIKit، ولها 34 unit test.

## التشغيل

1. ثبّت Xcode 26، ثم نفّذ: `sudo xcode-select -s /Applications/Xcode.app`
2. افتح `BKeyboard.xcodeproj`.
3. اختر Team في Signing لكلٍّ من `BKeyboard` و`KeyboardExtension`. قد تحتاج إلى تغيير الـBundle IDs من `com.baraaqassam.bkeyboard*`.
4. شغّل scheme `BKeyboard` على iPhone فعلي، ثم فعّل اللوحة من Settings › General › Keyboard › Keyboards.
5. اختبارات النواة: `swift test` داخل `Packages/KeyboardCore`. مع Command Line Tools فقط أضف: `-Xswiftc -plugin-path -Xswiftc /Library/Developer/CommandLineTools/usr/lib/swift/host/plugins/testing`

## مصفوفة الاختبار على الجهاز

نفّذ كل اختبار مرتين: مرة مع Full Access **OFF**، ثم مرة مع **ON**.

| # | الاختبار | معيار النجاح |
|---|---|---|
| 1 | Latency: اكتب فقرة عربية وأخرى إنجليزية بسرعتك الطبيعية، ثم اضغط مطولًا على ⌘ | P95 ≤ 50 ms |
| 2 | Keystroke loss: اكتب جملة 50 حرفًا بسرعة 5 مرات | صفر حروف مفقودة أو مكررة |
| 3 | AR ⇄ EN: بدّل 20 مرة أثناء كتابة نص مختلط | التبديل فوري، ولا يمر عبر Emoji أو لوحات أخرى |
| 4 | Globe: اضغط، ثم اضغط مطولًا | الضغط ينتقل للوحة التالية، والمطوّل يعرض قائمة النظام |
| 5 | Number row: اكتب `راجع 3 طلبات قبل 10:30` | كل الأرقام من الصف الدائم دون تغيير الصفحة |
| 6 | اكتب `أإآ` بالضغط المطوّل على `ا`، و`ذ` من `د`، و`ئ ء ؤ لا` مباشرة | صحيحة، والاختيار بالسحب يعمل باتجاه RTL |
| 7 | Delete hold على فقرة طويلة | تسارع ملحوظ دون قفزة مفاجئة، ويتوقف فور رفع الإصبع |
| 8 | Orientation: portrait ثم landscape ثم العودة | الارتفاع يتكيف، ولا تتداخل المفاتيح |
| 9 | Dark / Light + حقل بـ`keyboardAppearance = .dark` | الألوان صحيحة ومقروءة |
| 10 | التطبيقات: WhatsApp وNotes وMail وSafari وMessages وChatGPT وClaude | الكتابة تعمل، ويُسجَّل أي تطبيق يمنع اللوحة |
| 11 | Secure field وPhone pad (في Test bench) | iOS يستبدل اللوحة بلوحة النظام تلقائيًا |
| 12 | Email وURL وSearch وNumber في Test bench | المفاتيح المناسبة تظهر، وزر Return يحمل التسمية الصحيحة |
| 13 | Full Access OFF | كل ما سبق يعمل، ولوحة الخيارات تعرض `Full Access OFF` |
| 14 | الذاكرة: Instruments › Allocations أثناء 5 دقائق كتابة | لا نمو مستمر، والاستهلاك أقل بكثير من حد الـextension |
| 15 | الصفوف السفلية: اكتب مسافات بسرعة | لا تأخير من إيماءة حافة الشاشة |
| 16 | Prediction: اكتب `المح` ثم `راجع الـ fore` ثم `متى سيتم ` | الاقتراحات تتغير، والإدراج يستبدل الكلمة ويضيف مسافة، والـlayout يبقى عربيًا |
| 17 | ⌘: افتح Snippets، أدرج عنصرًا، ثم أعد فتح ⌘ | الإدراج يعود للكتابة بنفس اللغة، ويُفتح آخر تبويب |

قراءة الـsignposts: Instruments › Points of Interest، ثم فلتر `com.baraaqassam.bkeyboard.keyboard`. الضغطات الأبطأ من 50 ms تُسجَّل في Console تحت category `typing`.

## قرارات الـPrototype المفتوحة (UX §49)

| القرار | الوضع الحالي في الـbuild | كيف نختبره |
|---|---|---|
| PT-01 الصف العربي الثالث | `ئ ء ؤ ر لا ى ة و ز ظ ⌫`، ومفاتيح بعرض 1/12. رسم الـspec يُسقط `د ط ظ ذ`، فوضعتها في أماكنها من تخطيط PC | أخطاء اللمس مقارنةً بالإنجليزية |
| PT-02 موقع `،` و`؟` | Option A+B: مفتاح `،` بجوار المسافة و`؟` بالضغط المطوّل عليه، إضافةً إلى صفحة الرموز | هل `؟` بالضغط المطوّل بطيء؟ |
| PT-03 Popup أو Haptic فقط | Popup مفعّل، ويُطفأ من لوحة الخيارات | أسبوع لكل خيار |
| PT-04/05 Space swipe / trackpad | غير منفّذ | بعد اجتياز البوابة |
| PT-06 تسارع الحذف | 0.45s ثم 100→50 ms، ثم كلمة كلمة بعد 24 تكرارًا | هل يُفقد نص عن غير قصد؟ |
| PT-07 شكل الاقتراح | نص عادي، والكلمة المكتوبة بين علامتي تنصيص | — |
| PT-09 ارتفاع اللوحة | 40 + 5×50 pt في الوضع العمودي | هل يستحق صف الأرقام ارتفاعه؟ |
| PT-10 موضع ⌘ | يسار شريط الاقتراحات | هل هو واضح؟ |

## بوابة الانتقال إلى Prediction Engine (UX §52)

لا نبدأ Phase 2 قبل أن تكون الإجابة: «نعم، أستطيع استخدام هذه اللوحة للكتابة اليومية حتى لو كانت الاقتراحات مجرد Mock».
